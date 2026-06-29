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
        case .needsInput: return "Return to Cursor — waiting for approval ↩"
        case .completed: return "Return to Cursor — task finished ↩"
        case .failed: return "Return to Cursor — check the error ↩"
        }
    }
}
