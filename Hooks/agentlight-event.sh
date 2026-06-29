#!/bin/bash
# AgentLight Cursor hook — forwards lifecycle events to the menu bar app.

set -euo pipefail

HOOK_NAME="${1:-unknown}"
INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

emit_permission() {
  emit_permission_response "$1"
}

handle_permission_hook() {
  local hook_name="$1"
  local input="$2"

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
      send_event "agent_running" "$input" "executing" "false" "$hook_name"
      emit_permission_response "allow"
      exit 0
    fi
  fi

  if should_use_menu_bar_approval; then
    notify_menu_bar_approval "$hook_name" "$input"
    send_event "agent_needs_input" "$input" "" "true" "$hook_name" &
    emit_permission_response "ask"
    exit 0
  fi

  send_event "agent_needs_input" "$input" "" "true" "$hook_name" &
  emit_permission_response "allow"
  exit 0
}

case "$HOOK_NAME" in
  beforeShellExecution|beforeMCPExecution|subagentStart)
    handle_permission_hook "$HOOK_NAME" "$INPUT"
    ;;
esac

AGENTLIGHT_EVENT=$(resolve_hook_event "$HOOK_NAME" "$INPUT")

phase=""
case "$HOOK_NAME" in
  postToolUse|afterShellExecution|afterMCPExecution)
    phase="executing"
    ;;
esac

if [[ -n "$AGENTLIGHT_EVENT" ]]; then
  immediate="false"
  if [[ "$AGENTLIGHT_EVENT" == "agent_needs_input" ]]; then
    immediate="true"
  fi

  log_hook "$HOOK_NAME" "event=$AGENTLIGHT_EVENT phase=$phase immediate=$immediate"

  if [[ "$AGENTLIGHT_EVENT" == "agent_needs_input" ]] || [[ "$phase" == "executing" ]]; then
    send_event "$AGENTLIGHT_EVENT" "$INPUT" "$phase" "$immediate" "$HOOK_NAME"
  else
    send_event "$AGENTLIGHT_EVENT" "$INPUT" "$phase" "false" "$HOOK_NAME" &
  fi
else
  tool_name=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print('')
    raise SystemExit
print(data.get('tool_name') or data.get('toolName') or data.get('tool') or '')
" 2>/dev/null || echo "")
  log_hook "$HOOK_NAME" "no_event tool=$tool_name"
fi

case "$HOOK_NAME" in
  preToolUse)
    echo '{"permission":"allow"}'
    ;;
  stop|subagentStop)
    echo '{}'
    ;;
  *)
    echo '{}'
    ;;
esac

exit 0
