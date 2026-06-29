#!/bin/bash
# AgentLight Cursor hook — forwards lifecycle events to the menu bar app.

set -euo pipefail

HOOK_NAME="${1:-unknown}"
INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

AGENTLIGHT_EVENT=$(resolve_hook_event "$HOOK_NAME" "$INPUT")

phase=""
case "$HOOK_NAME" in
  postToolUse|afterShellExecution|afterMCPExecution|beforeShellExecution)
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
  beforeShellExecution|beforeMCPExecution|subagentStart|preToolUse)
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
