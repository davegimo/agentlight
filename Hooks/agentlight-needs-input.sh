#!/bin/bash
# Detects when Cursor is waiting for user approval or input.

set -euo pipefail

INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

TOOL=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name') or data.get('toolName') or data.get('tool') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

needs_approval=false
case "$TOOL" in
  Shell|Write|Delete|Task|AskQuestion)
    needs_approval=true
    ;;
  MCP:*)
    needs_approval=true
    ;;
esac

if [[ "$needs_approval" == "true" ]]; then
  send_needs_input "$INPUT" &
fi

echo '{"permission":"allow"}'
exit 0
