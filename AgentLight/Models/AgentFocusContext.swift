import Foundation

struct AgentFocusContext: Codable, Equatable, Sendable {
    let providerID: String
    let agentID: String
    let workspacePath: String
    let taskDescription: String?
    let reason: FocusReason

    enum FocusReason: String, Codable, Sendable {
        case needsInput
        case completed
        case failed
    }

    var openLabel: String {
        switch reason {
        case .needsInput: return "Open in Cursor — approval needed ↩"
        case .completed: return "Open in Cursor — continue ↩"
        case .failed: return "Open in Cursor — review error ↩"
        }
    }
}
