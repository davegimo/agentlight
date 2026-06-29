import Foundation

@MainActor
final class AgentStore: ObservableObject {
    static let shared = AgentStore()

    @Published private(set) var agents: [Agent] = []
    @Published private(set) var aggregateState: AggregateState = .idle

    private var providers: [String: any AgentProvider] = [:]
    private var isReadyForNextRequest = false

    private init() {}

    func register(provider: any AgentProvider) {
        providers[provider.id] = provider
    }

    func startProviders() {
        for provider in providers.values {
            provider.start()
        }
    }

    func stopProviders() {
        for provider in providers.values {
            provider.stop()
        }
    }

    func handle(event: AgentEvent) {
        providers[event.provider]?.handle(event: event)

        let previousState = agents.first(where: { $0.id == event.agentID })?.state

        switch event.event {
        case .agentStarted:
            isReadyForNextRequest = false
            upsertAgent(from: event, state: .working, setStartedAt: true)
        case .agentRunning:
            upsertAgent(from: event, state: .working, setStartedAt: false, allowFromDone: false, allowFromNeedsInput: event.metadata?["phase"] == "executing")
        case .agentCompleted:
            isReadyForNextRequest = true
            upsertAgent(from: event, state: .done, setStartedAt: false)
        case .agentNeedsInput:
            isReadyForNextRequest = false
            upsertAgent(from: event, state: .needsInput, setStartedAt: false)
        case .agentStopped:
            removeAgent(id: event.agentID)
            recalculateAggregate()
            return
        case .agentFailed:
            isReadyForNextRequest = false
            upsertAgent(from: event, state: .failed, setStartedAt: false)
        }

        recalculateAggregate()

        if let agent = agents.first(where: { $0.id == event.agentID }),
           agent.state != previousState {
            NotificationService.shared.notify(agent: agent, settings: AppSettings.shared)
        }
    }

    func clearCompleted() {
        agents.removeAll { $0.state == .done || $0.state == .stopped }
        recalculateAggregate()
    }

    func clearAll() {
        agents.removeAll()
        isReadyForNextRequest = false
        recalculateAggregate()
    }

    private func upsertAgent(
        from event: AgentEvent,
        state: AgentState,
        setStartedAt: Bool,
        allowFromDone: Bool = true,
        allowFromNeedsInput: Bool = true
    ) {
        let now = event.timestamp
        if let index = agents.firstIndex(where: { $0.id == event.agentID }) {
            var agent = agents[index]
            if agent.state == .done && state == .working && !allowFromDone {
                agent.lastUpdated = now
                if let task = event.task, !task.isEmpty {
                    agent.taskDescription = task
                }
                mergeMetadata(from: event, into: &agent)
                agents[index] = agent
                agents.sort { $0.lastUpdated > $1.lastUpdated }
                return
            }
            if agent.state == .needsInput && state == .working && !allowFromNeedsInput {
                agent.lastUpdated = now
                if let task = event.task, !task.isEmpty {
                    agent.taskDescription = task
                }
                mergeMetadata(from: event, into: &agent)
                agents[index] = agent
                agents.sort { $0.lastUpdated > $1.lastUpdated }
                return
            }
            agent.state = state
            agent.lastUpdated = now
            if let task = event.task, !task.isEmpty {
                agent.taskDescription = task
            }
            mergeMetadata(from: event, into: &agent)
            if setStartedAt && agent.startedAt == nil {
                agent.startedAt = now
            }
            agents[index] = agent
        } else {
            let agent = Agent(
                id: event.agentID,
                providerID: event.provider,
                name: displayName(for: event),
                taskDescription: event.task,
                workspacePath: event.metadata?["workspace"],
                state: state,
                lastUpdated: now,
                startedAt: setStartedAt ? now : nil
            )
            agents.append(agent)
        }
        agents.sort { $0.lastUpdated > $1.lastUpdated }
    }

    private func mergeMetadata(from event: AgentEvent, into agent: inout Agent) {
        if let workspace = event.metadata?["workspace"], !workspace.isEmpty {
            agent.workspacePath = workspace
            agent.name = (workspace as NSString).lastPathComponent
        }
    }

    private func displayName(for event: AgentEvent) -> String {
        if let workspace = event.metadata?["workspace"], !workspace.isEmpty {
            return (workspace as NSString).lastPathComponent
        }
        return event.provider.capitalized
    }

    private func removeAgent(id: String) {
        agents.removeAll { $0.id == id }
    }

    private func recalculateAggregate() {
        let active = agents.filter { $0.state != .stopped }

        guard !active.isEmpty else {
            aggregateState = isReadyForNextRequest ? .ready : .idle
            return
        }

        if active.contains(where: { $0.state == .needsInput || $0.state == .failed }) {
            aggregateState = .needsAttention
        } else if active.contains(where: { $0.state == .working }) {
            aggregateState = .working
        } else if active.contains(where: { $0.state == .done }) {
            aggregateState = .ready
        } else {
            aggregateState = isReadyForNextRequest ? .ready : .idle
        }
    }
}
