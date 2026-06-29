import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var settings: AppSettings
    @Binding var showSettings: Bool

    var body: some View {
        if !store.pendingApprovals.isEmpty {
            ForEach(store.pendingApprovals) { approval in
                approvalSection(approval)
            }
            Divider()
        }

        if store.canOpenFocusTarget {
            Button(store.focusActionLabel) {
                store.openFocusTarget()
            }
            Divider()
        }

        if store.agents.isEmpty {
            if store.aggregateState == .ready {
                Text("Ready for next request")
                    .foregroundStyle(.secondary)
            } else {
                Text("No active agents")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(store.agents) { agent in
                if agent.workspacePath != nil {
                    Button {
                        store.openWorkspace(for: agent)
                    } label: {
                        agentRow(agent)
                    }
                } else {
                    agentRow(agent)
                }
            }
        }

        Divider()

        Button("Clear completed") {
            store.clearCompleted()
        }
        .disabled(!store.agents.contains(where: { $0.state == .done }))

        Button("Settings…") {
            showSettings = true
        }

        Divider()

        Button("Quit AgentLight") {
            NSApplication.shared.terminate(nil)
        }
    }

    @ViewBuilder
    private func approvalSection(_ approval: PendingApproval) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🔴 \(approval.workspaceFolderName) — approval needed")
                .font(.system(size: 13, weight: .semibold))
            Text(approval.title)
                .font(.caption)
            Text(approval.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("Also visible in Cursor — Allow clicks Run there")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack {
                Button("Allow") {
                    store.approve(approval)
                }
                Button("Deny") {
                    store.deny(approval)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func agentRow(_ agent: Agent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(agent.statusLine)
                .font(.system(size: 13))
            HStack(spacing: 6) {
                Text(relativeTime(agent.lastUpdated))
                if agent.workspacePath != nil {
                    Text("↩ Return to project")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Agent completed", isOn: $settings.notifyOnComplete)
                Toggle("Needs your input", isOn: $settings.notifyOnNeedsInput)
                Toggle("Agent failed", isOn: $settings.notifyOnFailed)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Cursor Integration") {
                Toggle("Approve from menu bar", isOn: $settings.approveFromMenuBar)
                Text("Shell (non-sandbox), MCP, Write, Delete, Task, WebSearch, WebFetch, and other tools that need approval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Install hooks with:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("cd Hooks && ./install.sh")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("Click “Return to Cursor” to jump back to the project window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("AgentLight")
                    .font(.headline)
                Text("Your AI agents, at a glance.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 340)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
