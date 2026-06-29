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
            let task = agent.taskDescription ?? "task"
            send(
                title: "\(agent.providerDisplayName) completed",
                body: "\(agent.providerDisplayName) completed \(task). Click to open.",
                agent: agent
            )
        case .needsInput:
            guard settings.notifyOnNeedsInput else { return }
            let task = agent.taskDescription ?? "your agent"
            send(
                title: "\(agent.providerDisplayName) needs you",
                body: "\(agent.providerDisplayName) is waiting for approval on \(task). Click to open.",
                agent: agent
            )
        case .failed:
            guard settings.notifyOnFailed else { return }
            let task = agent.taskDescription ?? "task"
            send(
                title: "Agent failed",
                body: "\(agent.providerDisplayName) failed on \(task). Click to open.",
                agent: agent
            )
        default:
            break
        }
    }

    private func send(title: String, body: String, agent: Agent) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let workspace = agent.workspacePath {
            content.userInfo = [
                "workspace": workspace,
                "provider": agent.providerID,
                "agent_id": agent.id,
            ]
        }

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
