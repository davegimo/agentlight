import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NSLog("AgentLight: notification authorization error — \(error.localizedDescription)")
            } else if !granted {
                NSLog("AgentLight: notifications not granted")
            }
        }
    }

    func notify(agent: Agent, settings: AppSettings) {
        switch agent.state {
        case .done:
            guard settings.notifyOnComplete else { return }
            send(
                title: "\(agent.workspaceFolderName) — done",
                body: "Task finished in \(agent.workspaceFolderName). Click to return to Cursor.",
                agent: agent
            )
        case .needsInput:
            guard settings.notifyOnNeedsInput else { return }
            send(
                title: "\(agent.workspaceFolderName) — waiting for approval",
                body: "Cursor needs your approval on \(agent.workspaceFolderName). Click to open.",
                agent: agent
            )
        case .failed:
            guard settings.notifyOnFailed else { return }
            send(
                title: "\(agent.workspaceFolderName) — failed",
                body: "Something went wrong in \(agent.workspaceFolderName). Click to open.",
                agent: agent
            )
        default:
            break
        }
    }

    func notifyApprovalRequired(_ approval: PendingApproval) {
        send(
            title: "\(approval.workspaceFolderName) — approval needed",
            body: approval.detail,
            userInfo: [
                "workspace": approval.workspacePath ?? "",
                "provider": approval.providerID,
                "agent_id": approval.agentID,
                "approval_id": approval.id,
            ]
        )
    }

    private func send(title: String, body: String, agent: Agent) {
        var userInfo: [String: String] = [
            "provider": agent.providerID,
            "agent_id": agent.id,
        ]
        if let workspace = agent.workspacePath {
            userInfo["workspace"] = workspace
        }
        send(title: title, body: body, userInfo: userInfo)
    }

    private func send(title: String, body: String, userInfo: [String: String]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("AgentLight: notification delivery error — \(error.localizedDescription)")
            }
        }
    }
}
