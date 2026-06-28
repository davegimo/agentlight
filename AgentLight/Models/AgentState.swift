import Foundation

enum AgentState: String, Codable, CaseIterable, Sendable {
    case working
    case done
    case needsInput
    case failed
    case stopped

    var displayName: String {
        switch self {
        case .working: return "Running"
        case .done: return "Done"
        case .needsInput: return "Needs input"
        case .failed: return "Failed"
        case .stopped: return "Stopped"
        }
    }

    var emoji: String {
        switch self {
        case .working: return "🟡"
        case .done: return "🟢"
        case .needsInput: return "🔴"
        case .failed: return "🔴"
        case .stopped: return "⚪"
        }
    }

    var priority: Int {
        switch self {
        case .needsInput, .failed: return 3
        case .done: return 2
        case .working: return 1
        case .stopped: return 0
        }
    }
}

enum AggregateState: Sendable {
    case idle
    case working
    case ready
    case needsAttention

    var emoji: String {
        switch self {
        case .idle: return "⚪"
        case .working: return "🟡"
        case .ready: return "🟢"
        case .needsAttention: return "🔴"
        }
    }

    var label: String {
        "AgentLight"
    }
}
