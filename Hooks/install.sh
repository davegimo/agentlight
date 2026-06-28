#!/bin/bash
# Installs AgentLight hooks into ~/.cursor for global Cursor integration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_DIR="${HOME}/.cursor"
HOOKS_DIR="${CURSOR_DIR}/hooks"
TARGET_HOOKS_JSON="${CURSOR_DIR}/hooks.json"

echo "AgentLight — Cursor hook installer"
echo "==================================="

mkdir -p "$HOOKS_DIR"

for script in agentlight-event.sh agentlight-common.sh agentlight-needs-input.sh; do
  cp "$SCRIPT_DIR/$script" "$HOOKS_DIR/$script"
  chmod +x "$HOOKS_DIR/$script"
  echo "Installed $script"
done

if [[ -f "$TARGET_HOOKS_JSON" ]]; then
  echo ""
  echo "Existing hooks.json found at $TARGET_HOOKS_JSON"
  echo "Merging AgentLight hooks..."

  TARGET_HOOKS_JSON="$TARGET_HOOKS_JSON" SCRIPT_DIR="$SCRIPT_DIR" python3 <<'PY'
import json
import os
from pathlib import Path

target = Path(os.environ["TARGET_HOOKS_JSON"])
source = Path(os.environ["SCRIPT_DIR"]) / "hooks.json"

with open(target) as f:
    existing = json.load(f)
with open(source) as f:
    incoming = json.load(f)

existing.setdefault("version", 1)
existing.setdefault("hooks", {})

for event, defs in incoming.get("hooks", {}).items():
    existing["hooks"].setdefault(event, [])
    existing_commands = {
        d.get("command") for d in existing["hooks"][event] if isinstance(d, dict)
    }
    for definition in defs:
        if definition.get("command") not in existing_commands:
            existing["hooks"][event].append(definition)

with open(target, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")

print("Merged hooks.json successfully.")
PY
else
  cp "$SCRIPT_DIR/hooks.json" "$TARGET_HOOKS_JSON"
  echo "Installed hooks.json"
fi

echo ""
echo "Done! Restart Cursor to load the hooks."
echo "Make sure AgentLight is running in the menu bar."
