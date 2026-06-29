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

    var workspaceFolderName: String {
        if let path = workspacePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        if !name.isEmpty, name != providerDisplayName {
            return name
        }
        return providerDisplayName
    }

    var statusLine: String {
        "\(workspaceFolderName) — \(state.emoji) \(state.displayName)"
    }
}
