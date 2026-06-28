# AgentLight

> Your AI agents, at a glance.

AgentLight is a lightweight macOS menu bar application that monitors the status of your AI coding agents — starting with Cursor — so you never have to keep switching back to your editor to check if an agent is done or waiting for input.

## Features

- **Traffic light menu bar icon** — 🟡 Working, 🟢 Done, 🔴 Needs you, ⚪ Idle
- **Agent list** — provider, task, status, and last update time
- **Native notifications** — configurable alerts for completion, input requests, and failures
- **Provider architecture** — Cursor today; Claude Code, Codex, Gemini, and others later
- **Launch at login** — optional startup via System Settings
- **Minimal footprint** — menu bar only, no dock icon

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ to build
- Cursor with hooks support

## Build & Run

```bash
cd agentlight
open AgentLight.xcodeproj
```

Build and run with **⌘R**, or from the terminal:

```bash
xcodebuild -project AgentLight.xcodeproj -scheme AgentLight -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/AgentLight.app
```

Grant notification permissions when prompted.

## Cursor Integration

Install user-level hooks so Cursor reports agent lifecycle events to AgentLight:

```bash
cd Hooks
chmod +x install.sh agentlight-event.sh agentlight-common.sh agentlight-needs-input.sh test-event.sh
./install.sh
```

Then restart Cursor.

Hooks are installed to `~/.cursor/hooks/` and merged into `~/.cursor/hooks.json`.

### Event mapping

| Cursor hook | AgentLight state |
|---|---|
| `sessionStart` | 🟡 Agent started |
| `postToolUse`, `afterAgentResponse`, etc. | 🟡 Running |
| `preToolUse` (AskQuestion) | 🔴 Needs input |
| `stop` | 🟢 Completed |
| `sessionEnd` | Removed |
| `postToolUseFailure` | 🔴 Failed |

## Test Without Cursor

With AgentLight running:

```bash
cd Hooks
./test-event.sh agent_started demo "Refactoring API layer"
./test-event.sh agent_completed demo "Refactoring API layer"
./test-event.sh agent_needs_input demo "File deletion approval"
```

## Architecture

```text
AgentProvider
 ├── CursorProvider (MVP)
 ├── ClaudeProvider (future)
 ├── CodexProvider (future)
 └── GeminiProvider (future)
```

```
Cursor Hooks → HTTP POST :47831/event → EventServer → AgentStore → MenuBarExtra
                                                      ↘ NotificationService
```

Server config is written to:

`~/Library/Application Support/AgentLight/server.json`

## Settings

Open **AgentLight → Settings** from the menu bar to configure:

- Notifications (complete / needs input / failed)
- Launch at login

## Tagline

**AgentLight** — Never wait for your AI agents again.

## License

MIT
