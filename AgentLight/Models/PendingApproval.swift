import Foundation

enum ApprovalKind: String, Codable, Sendable {
    case shell
    case mcp
    case tool
    case subagent

    var displayName: String {
        switch self {
        case .shell: return "Shell command"
        case .mcp: return "MCP tool"
        case .tool: return "Tool"
        case .subagent: return "Subagent"
        }
    }
}

enum ApprovalDecision: String, Codable, Sendable {
    case allow
    case deny
}

struct ApprovalRequest: Codable, Sendable {
    let hook: String
    let agentID: String
    let task: String?
    let workspace: String?
    let tool: String?

    enum CodingKeys: String, CodingKey {
        case hook
        case agentID = "agent_id"
        case task
        case workspace
        case tool
    }
}

struct PendingApproval: Identifiable, Equatable, Sendable {
    let id: String
    let agentID: String
    let providerID: String
    let kind: ApprovalKind
    let title: String
    let detail: String
    let workspacePath: String?
    let createdAt: Date

    var workspaceFolderName: String {
        if let path = workspacePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return "Cursor"
    }
}
