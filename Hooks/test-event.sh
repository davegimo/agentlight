#!/bin/bash
# Sends a test event to AgentLight for manual verification.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agentlight-common.sh
source "$SCRIPT_DIR/agentlight-common.sh"

EVENT="${1:-agent_started}"
AGENT_ID="${2:-test-agent}"
TASK="${3:-Test authentication feature}"

PORT=$(read_port)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'event': '$EVENT',
    'provider': 'cursor',
    'agent_id': '$AGENT_ID',
    'task': '$TASK',
    'timestamp': '$TIMESTAMP',
    'metadata': {'workspace': 'test-workspace'}
}))
")

echo "Sending $EVENT to http://127.0.0.1:${PORT}/event"
curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "http://127.0.0.1:${PORT}/event"
echo ""
