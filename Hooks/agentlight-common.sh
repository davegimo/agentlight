#!/bin/bash
# Shared helpers for AgentLight Cursor hooks.

CONFIG_FILE="${HOME}/Library/Application Support/AgentLight/server.json"
DEBUG_LOG="${HOME}/Library/Application Support/AgentLight/hook-debug.log"
DEFAULT_PORT=47831

log_hook() {
  local hook_name="$1"
  local message="$2"
  mkdir -p "$(dirname "$DEBUG_LOG")"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [$hook_name] $message" >> "$DEBUG_LOG"
  if [[ -f "$DEBUG_LOG" ]]; then
    tail -n 200 "$DEBUG_LOG" > "${DEBUG_LOG}.tmp" 2>/dev/null && mv "${DEBUG_LOG}.tmp" "$DEBUG_LOG"
  fi
}

resolve_hook_event() {
  local hook_name="$1"
  local input="$2"

  if [[ "$hook_name" == "postToolUseFailure" ]]; then
    local failure_type
    failure_type=$(echo "$input" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('')
    raise SystemExit
print(data.get('failure_type') or '')
" 2>/dev/null || echo "")
    if [[ "$failure_type" == "permission_denied" ]]; then
      echo "agent_needs_input"
      return
    fi
  fi

  if [[ "$hook_name" == "beforeShellExecution" ]]; then
    local sandbox
    sandbox=$(echo "$input" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('false')
    raise SystemExit
print('true' if data.get('sandbox') is True else 'false')
" 2>/dev/null || echo "false")
    log_hook "$hook_name" "sandbox=$sandbox"
    if [[ "$sandbox" == "true" ]]; then
      echo "agent_running"
    else
      echo "agent_needs_input"
    fi
    return
  fi

  map_hook_to_event "$hook_name"
}

map_hook_to_event() {
  case "$1" in
    sessionStart) echo "agent_started" ;;
    sessionEnd) echo "agent_stopped" ;;
    stop) echo "agent_completed" ;;
    postToolUseFailure) echo "agent_failed" ;;
    beforeMCPExecution)
      echo "agent_needs_input"
      ;;
    subagentStart)
      echo "agent_needs_input"
      ;;
    postToolUse|afterShellExecution|afterMCPExecution)
      echo "agent_running"
      ;;
    afterAgentResponse|afterFileEdit|subagentStop)
      echo "agent_running"
      ;;
    beforeSubmitPrompt) echo "agent_started" ;;
    preToolUse) echo "" ;;
    *) echo "" ;;
  esac
}

read_port() {
  if [[ -f "$CONFIG_FILE" ]]; then
    python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE') as f:
        print(json.load(f).get('port', $DEFAULT_PORT))
except Exception:
    print($DEFAULT_PORT)
" 2>/dev/null || echo "$DEFAULT_PORT"
  else
    echo "$DEFAULT_PORT"
  fi
}

extract_fields() {
  python3 -c "
import json, sys
from datetime import datetime, timezone

raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    data = {}

agent_id = (
    data.get('conversation_id')
    or data.get('conversationId')
    or data.get('generation_id')
    or data.get('generationId')
    or data.get('session_id')
    or data.get('sessionId')
    or data.get('chat_id')
    or data.get('chatId')
    or 'default'
)

task = (
    data.get('prompt')
    or data.get('user_prompt')
    or data.get('userPrompt')
    or data.get('agent_message')
    or data.get('agentMessage')
    or data.get('task')
    or data.get('message')
    or data.get('command')
    or (data.get('tool_input') or {}).get('command') if isinstance(data.get('tool_input'), dict) else None
    or data.get('tool_name')
    or data.get('toolName')
    or ''
)

roots = data.get('workspace_roots') or data.get('workspaceRoots') or []
workspace = (
    data.get('workspace')
    or data.get('workspace_path')
    or data.get('workspacePath')
    or data.get('cwd')
    or data.get('root')
    or (roots[0] if isinstance(roots, list) and roots else '')
    or (data.get('tool_input') or {}).get('working_directory') if isinstance(data.get('tool_input'), dict) else None
    or (data.get('tool_input') or {}).get('workingDirectory') if isinstance(data.get('tool_input'), dict) else None
    or ''
)

tool = data.get('tool_name') or data.get('toolName') or data.get('tool') or ''
failure_type = data.get('failure_type') or ''
immediate_tools = {
    'websearch', 'webfetch', 'fetch', 'askquestion', 'shell', 'write',
    'delete', 'task', 'applypatch', 'editnotebook', 'switchmode',
}
tool_lower = tool.lower()
immediate = 'true' if (tool_lower in immediate_tools or tool.startswith('MCP:') or tool.startswith('mcp:')) else 'false'

print(json.dumps({
    'agent_id': str(agent_id),
    'task': str(task)[:500],
    'workspace': str(workspace)[:200],
    'tool': str(tool),
    'failure_type': str(failure_type),
    'immediate': immediate
}))
" <<< "$1"
}

send_event() {
  local event_type="$1"
  local input="$2"
  local phase="${3:-}"
  local immediate="${4:-false}"
  local hook_name="${5:-unknown}"
  local port
  port=$(read_port)

  local fields
  fields=$(extract_fields "$input")

  local agent_id task workspace tool failure_type extracted_immediate
  agent_id=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['agent_id'])")
  task=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['task'])")
  workspace=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace'])")
  tool=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['tool'])")
  failure_type=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin).get('failure_type',''))")
  extracted_immediate=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin).get('immediate','false'))")
  if [[ "$immediate" != "true" ]]; then
    immediate="$extracted_immediate"
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local payload
  payload=$(python3 -c "
import json
metadata = {
    'workspace': '''${workspace//\'/}''',
    'tool': '''${tool//\'/}''',
    'hook': '''${hook_name}'''
}
phase = '''${phase}'''
if phase:
    metadata['phase'] = phase
failure_type = '''${failure_type}'''
if failure_type:
    metadata['failure_type'] = failure_type
immediate = '''${immediate}'''
if immediate == 'true':
    metadata['immediate'] = 'true'
print(json.dumps({
    'event': '$event_type',
    'provider': 'cursor',
    'agent_id': '''${agent_id//\'/}''',
    'task': '''${task//\'/}''' or None,
    'timestamp': '$timestamp',
    'metadata': metadata
}))
")

  curl -s -m 2 -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "http://127.0.0.1:${port}/event" >/dev/null 2>&1 || true
}

send_needs_input() {
  local input="$1"
  local immediate="${2:-false}"
  local hook_name="${3:-preToolUse}"
  if [[ "$(is_auto_executed "$input")" == "true" ]]; then
    log_hook "$hook_name" "skipped needs_input (sandbox)"
    return
  fi
  log_hook "$hook_name" "send needs_input immediate=$immediate"
  if [[ "$immediate" == "true" ]]; then
    send_event "agent_needs_input" "$input" "" "true" "$hook_name"
  else
    send_event "agent_needs_input" "$input" "" "false" "$hook_name"
  fi
}

is_auto_executed() {
  echo "$1" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('false')
    raise SystemExit
print('true' if data.get('sandbox') is True else 'false')
" 2>/dev/null || echo "false"
}
