import Foundation

struct Agent: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let providerID: String
    var name: String
    var taskDescription: String?
    var workspacePath: String?
    var state: AgentState
    var lastUpdated: Date
    var startedAt: Date?

    var providerDisplayName: String {
        switch providerID {
        case "cursor": return "Cursor"
        default: return providerID.capitalized
        }
    }

    var statusLine: String {
        let task = taskDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskPart = (task?.isEmpty == false) ? " — \(task!)" : ""
        return "\(providerDisplayName)\(taskPart) — \(state.emoji) \(state.displayName)"
    }
}
