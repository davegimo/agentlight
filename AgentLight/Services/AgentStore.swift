import Foundation

@MainActor
final class AgentStore: ObservableObject {
    static let shared = AgentStore()

    @Published private(set) var agents: [Agent] = []
    @Published private(set) var aggregateState: AggregateState = .idle
    @Published private(set) var focusContext: AgentFocusContext?

    private var providers: [String: any AgentProvider] = [:]
    private var isReadyForNextRequest = false
    private let focusContextKey = "AgentLight.lastFocusContext"
    private var pendingNeedsInputTasks: [String: Task<Void, Never>] = [:]
    private let needsInputDebounceNs: UInt64 = 450_000_000

    private init() {
        focusContext = loadFocusContext()
    }

    var canOpenFocusTarget: Bool {
        primaryLinkableAgent() != nil || focusContext != nil
    }

    var focusActionLabel: String {
        if let agent = primaryLinkableAgent() {
            switch agent.state {
            case .needsInput, .failed: return "Open in Cursor — needs you ↩"
            case .done: return "Open in Cursor — continue ↩"
            default: return "Open in Cursor ↩"
            }
        }
        return focusContext?.openLabel ?? "Open in Cursor ↩"
    }

    func openFocusTarget() {
        if let agent = primaryLinkableAgent() {
            openWorkspace(for: agent)
        } else if let focusContext {
            WorkspaceOpener.open(context: focusContext)
        }
    }

    func openWorkspace(for agent: Agent) {
        WorkspaceOpener.open(agent: agent)
    }

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
            cancelPendingNeedsInput(for: event.agentID)
            isReadyForNextRequest = false
            upsertAgent(from: event, state: .working, setStartedAt: true)
        case .agentRunning:
            if event.metadata?["phase"] == "executing" {
                cancelPendingNeedsInput(for: event.agentID)
            }
            upsertAgent(from: event, state: .working, setStartedAt: false, allowFromDone: false, allowFromNeedsInput: event.metadata?["phase"] == "executing")
        case .agentCompleted:
            cancelPendingNeedsInput(for: event.agentID)
            isReadyForNextRequest = true
            upsertAgent(from: event, state: .done, setStartedAt: false)
        case .agentNeedsInput:
            if event.metadata?["auto_executed"] == "true" {
                return
            }
            scheduleNeedsInput(from: event)
            return
        case .agentStopped:
            cancelPendingNeedsInput(for: event.agentID)
            removeAgent(id: event.agentID)
            recalculateAggregate()
            return
        case .agentFailed:
            cancelPendingNeedsInput(for: event.agentID)
            isReadyForNextRequest = false
            upsertAgent(from: event, state: .failed, setStartedAt: false)
        }

        recalculateAggregate()
        updateFocusContext(from: event)

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
        focusContext = nil
        saveFocusContext()
        recalculateAggregate()
    }

    private func scheduleNeedsInput(from event: AgentEvent) {
        cancelPendingNeedsInput(for: event.agentID)
        let agentID = event.agentID

        pendingNeedsInputTasks[agentID] = Task {
            try? await Task.sleep(nanoseconds: needsInputDebounceNs)
            guard !Task.isCancelled else { return }
            applyNeedsInput(from: event)
            pendingNeedsInputTasks.removeValue(forKey: agentID)
        }
    }

    private func applyNeedsInput(from event: AgentEvent) {
        let previousState = agents.first(where: { $0.id == event.agentID })?.state
        isReadyForNextRequest = false
        upsertAgent(from: event, state: .needsInput, setStartedAt: false)
        recalculateAggregate()
        updateFocusContext(from: event)

        if let agent = agents.first(where: { $0.id == event.agentID }),
           agent.state != previousState {
            NotificationService.shared.notify(agent: agent, settings: AppSettings.shared)
        }
    }

    private func cancelPendingNeedsInput(for agentID: String) {
        pendingNeedsInputTasks[agentID]?.cancel()
        pendingNeedsInputTasks.removeValue(forKey: agentID)
    }

    private func primaryLinkableAgent() -> Agent? {
        let linkable = agents.filter { agent in
            guard let path = agent.workspacePath, !path.isEmpty else { return false }
            return FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
        }

        return linkable.first(where: { $0.state == .needsInput || $0.state == .failed })
            ?? linkable.first(where: { $0.state == .done })
            ?? linkable.first
    }

    private func updateFocusContext(from event: AgentEvent) {
        guard let workspace = event.metadata?["workspace"], !workspace.isEmpty else { return }

        let reason: AgentFocusContext.FocusReason?
        switch event.event {
        case .agentNeedsInput: reason = .needsInput
        case .agentCompleted: reason = .completed
        case .agentFailed: reason = .failed
        default: reason = nil
        }

        guard let reason else { return }

        focusContext = AgentFocusContext(
            providerID: event.provider,
            agentID: event.agentID,
            workspacePath: workspace,
            taskDescription: event.task,
            reason: reason
        )
        saveFocusContext()
    }

    private func loadFocusContext() -> AgentFocusContext? {
        guard let data = UserDefaults.standard.data(forKey: focusContextKey) else { return nil }
        return try? JSONDecoder().decode(AgentFocusContext.self, from: data)
    }

    private func saveFocusContext() {
        if let focusContext, let data = try? JSONEncoder().encode(focusContext) {
            UserDefaults.standard.set(data, forKey: focusContextKey)
        } else {
            UserDefaults.standard.removeObject(forKey: focusContextKey)
        }
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
