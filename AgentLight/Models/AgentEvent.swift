import Foundation

enum AgentEventType: String, Codable, Sendable {
    case agentStarted = "agent_started"
    case agentRunning = "agent_running"
    case agentCompleted = "agent_completed"
    case agentNeedsInput = "agent_needs_input"
    case agentStopped = "agent_stopped"
    case agentFailed = "agent_failed"
}

struct AgentEvent: Codable, Sendable {
    let event: AgentEventType
    let provider: String
    let agentID: String
    let task: String?
    let timestamp: Date
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case event
        case provider
        case agentID = "agent_id"
        case task
        case timestamp
        case metadata
    }
}
