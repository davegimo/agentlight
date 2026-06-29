#!/bin/bash
# Shared helpers for AgentLight Cursor hooks.

CONFIG_FILE="${HOME}/Library/Application Support/AgentLight/server.json"
DEFAULT_PORT=47831

map_hook_to_event() {
  case "$1" in
    sessionStart) echo "agent_started" ;;
    sessionEnd) echo "agent_stopped" ;;
    stop) echo "agent_completed" ;;
    postToolUseFailure) echo "agent_failed" ;;
    beforeShellExecution|beforeMCPExecution|subagentStart)
      echo "agent_needs_input"
      ;;
    postToolUse|afterShellExecution|afterMCPExecution)
      echo "agent_running"
      ;;
    afterAgentResponse|afterFileEdit|subagentStop)
      echo "agent_running"
      ;;
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

print(json.dumps({
    'agent_id': str(agent_id),
    'task': str(task)[:500],
    'workspace': str(workspace)[:200],
    'tool': str(tool)
}))
" <<< "$1"
}

send_event() {
  local event_type="$1"
  local input="$2"
  local phase="${3:-}"
  local port
  port=$(read_port)

  local fields
  fields=$(extract_fields "$input")

  local agent_id task workspace tool
  agent_id=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['agent_id'])")
  task=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['task'])")
  workspace=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace'])")
  tool=$(echo "$fields" | python3 -c "import json,sys; print(json.load(sys.stdin)['tool'])")

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local payload
  payload=$(python3 -c "
import json
metadata = {
    'workspace': '''${workspace//\'/}''',
    'tool': '''${tool//\'/}'''
}
phase = '''${phase}'''
if phase:
    metadata['phase'] = phase
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
  if [[ "$(is_auto_executed "$input")" == "true" ]]; then
    return
  fi
  send_event "agent_needs_input" "$input"
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
