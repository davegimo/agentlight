#!/bin/bash
# Detects when Cursor is waiting for user approval or input.

set -euo pipefail

HOOK_NAME="preToolUse"
INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

result=$(echo "$INPUT" | python3 -c "
import json, sys

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

tool = data.get('tool_name') or data.get('toolName') or data.get('tool') or ''
command = data.get('command') or ''
if not command and isinstance(data.get('tool_input'), dict):
    command = data.get('tool_input', {}).get('command') or ''

tool_lower = tool.lower()
readonly_tools = {
    'read', 'grep', 'glob', 'semanticsearch', 'listmcpresources',
    'fetchmcpresource', 'readlints',
}
approval_tools = {
    'shell', 'write', 'delete', 'task', 'askquestion', 'applypatch',
    'editnotebook', 'switchmode', 'websearch', 'webfetch', 'fetch',
}

needs = False
if data.get('sandbox') is True:
    needs = False
elif tool_lower in approval_tools or tool.startswith('MCP:') or tool.startswith('mcp:'):
    needs = True
elif any(x in tool_lower for x in ('websearch', 'webfetch', 'search', 'fetch')):
    needs = True
elif tool and tool_lower not in readonly_tools:
    needs = True
elif command:
    needs = True

print(json.dumps({'needs_approval': needs, 'tool': tool}))
")

needs_approval=$(echo "$result" | python3 -c "import json,sys; print('true' if json.load(sys.stdin)['needs_approval'] else 'false')")
tool=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool',''))")

log_hook "$HOOK_NAME" "tool=$tool needs=$needs_approval"

if [[ "$needs_approval" == "true" ]]; then
  immediate="true"
  tool_lower=$(echo "$tool" | tr '[:upper:]' '[:lower:]')
  # Shell auto-run fires beforeShellExecution within ms; debounce avoids red flash.
  if [[ "$tool_lower" == "shell" ]]; then
    immediate="false"
  fi
  send_needs_input "$INPUT" "$immediate" "$HOOK_NAME"
fi

echo '{"permission":"allow"}'
exit 0
