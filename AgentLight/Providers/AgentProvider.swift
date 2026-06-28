import Foundation

protocol AgentProvider: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    func start()
    func stop()
    func handle(event: AgentEvent)
}
