import Foundation

final class CursorProvider: AgentProvider, @unchecked Sendable {
    let id = "cursor"
    let displayName = "Cursor"

    private var isRunning = false

    func start() {
        isRunning = true
        NSLog("AgentLight: Cursor provider started")
    }

    func stop() {
        isRunning = false
        NSLog("AgentLight: Cursor provider stopped")
    }

    func handle(event: AgentEvent) {
        guard isRunning, event.provider == id else { return }
        // Provider-specific enrichment can be added here in future versions.
    }
}
