#!/bin/bash
# AgentLight Cursor hook — forwards lifecycle events to the menu bar app.
# Usage: agentlight-event.sh <hook_name>
# Reads JSON from stdin (Cursor hook payload).

set -euo pipefail

HOOK_NAME="${1:-unknown}"
INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

AGENTLIGHT_EVENT=$(map_hook_to_event "$HOOK_NAME")
if [[ -n "$AGENTLIGHT_EVENT" ]]; then
  phase=""
  case "$HOOK_NAME" in
    postToolUse|afterShellExecution|afterMCPExecution)
      phase="executing"
      ;;
  esac
  send_event "$AGENTLIGHT_EVENT" "$INPUT" "$phase" &
fi

# Hooks that require a response must still return valid JSON.
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
