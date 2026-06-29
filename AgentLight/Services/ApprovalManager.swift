import Foundation

final class ApprovalManager: @unchecked Sendable {
    static let shared = ApprovalManager()

    private let lock = NSLock()
    private var timeoutTasks: [String: Task<Void, Never>] = [:]
    private let timeoutSeconds: TimeInterval = 600

    var onPending: (@Sendable (PendingApproval) -> Void)?
    var onResolved: (@Sendable (String) -> Void)?

    private init() {}

    @discardableResult
    func register(request: ApprovalRequest) -> PendingApproval {
        let id = UUID().uuidString
        let pending = makePendingApproval(id: id, request: request)

        onPending?(pending)

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
            self.dismiss(id: id)
        }
        lock.lock()
        timeoutTasks[id] = timeoutTask
        lock.unlock()

        return pending
    }

    func dismiss(id: String) {
        lock.lock()
        let timeoutTask = timeoutTasks.removeValue(forKey: id)
        lock.unlock()
        timeoutTask?.cancel()
        onResolved?(id)
    }

    private func makePendingApproval(id: String, request: ApprovalRequest) -> PendingApproval {
        let kind: ApprovalKind
        switch request.hook {
        case "beforeShellExecution": kind = .shell
        case "beforeMCPExecution": kind = .mcp
        case "subagentStart": kind = .subagent
        case "preToolUse": kind = .tool
        default: kind = .tool
        }

        let detail = request.task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? request.tool ?? "Action requires approval"
        let title: String
        if request.hook == "preToolUse", let tool = request.tool, !tool.isEmpty {
            title = tool
        } else if let tool = request.tool, !tool.isEmpty {
            title = "\(kind.displayName): \(tool)"
        } else {
            title = kind.displayName
        }

        return PendingApproval(
            id: id,
            agentID: request.agentID,
            providerID: "cursor",
            kind: kind,
            title: title,
            detail: String(detail.prefix(280)),
            workspacePath: request.workspace,
            createdAt: Date()
        )
    }
}
