#!/bin/bash
# Detects when Cursor is waiting for user approval or input.

set -euo pipefail

INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

eval "$(echo "$INPUT" | python3 -c "
import json, sys

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

tool = data.get('tool_name') or data.get('toolName') or data.get('tool') or ''
command = data.get('command') or ''
if not command and isinstance(data.get('tool_input'), dict):
    command = data.get('tool_input', {}).get('command') or ''

readonly_tools = {
    'Read', 'Grep', 'Glob', 'SemanticSearch', 'ListMcpResources',
    'FetchMcpResource', 'ReadLints', 'WebSearch', 'WebFetch',
}
approval_tools = {
    'Shell', 'Write', 'Delete', 'Task', 'AskQuestion', 'ApplyPatch',
    'EditNotebook', 'SwitchMode',
}

needs = False
if data.get('sandbox') is True:
    needs = False
elif tool in approval_tools or tool.startswith('MCP:'):
    needs = True
elif tool and tool not in readonly_tools:
    needs = True
elif command:
    needs = True

print(f'needs_approval={'true' if needs else 'false'}')
")"

if [[ "$needs_approval" == "true" ]]; then
  send_needs_input "$INPUT"
fi

echo '{"permission":"allow"}'
exit 0
