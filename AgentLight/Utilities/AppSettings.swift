import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let notifyOnComplete = "notifyOnComplete"
        static let notifyOnNeedsInput = "notifyOnNeedsInput"
        static let notifyOnFailed = "notifyOnFailed"
        static let launchAtLogin = "launchAtLogin"
        static let approveFromMenuBar = "approveFromMenuBar"
    }

    @Published var notifyOnComplete: Bool {
        didSet { defaults.set(notifyOnComplete, forKey: Keys.notifyOnComplete) }
    }

    @Published var notifyOnNeedsInput: Bool {
        didSet { defaults.set(notifyOnNeedsInput, forKey: Keys.notifyOnNeedsInput) }
    }

    @Published var notifyOnFailed: Bool {
        didSet { defaults.set(notifyOnFailed, forKey: Keys.notifyOnFailed) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    @Published var approveFromMenuBar: Bool {
        didSet {
            defaults.set(approveFromMenuBar, forKey: Keys.approveFromMenuBar)
            writeServerConfig()
        }
    }

    private init() {
        notifyOnComplete = defaults.object(forKey: Keys.notifyOnComplete) as? Bool ?? true
        notifyOnNeedsInput = defaults.object(forKey: Keys.notifyOnNeedsInput) as? Bool ?? true
        notifyOnFailed = defaults.object(forKey: Keys.notifyOnFailed) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        approveFromMenuBar = defaults.object(forKey: Keys.approveFromMenuBar) as? Bool ?? true
    }

    func writeServerConfig(port: UInt16 = EventServer.defaultPort) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AgentLight", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let config: [String: Any] = [
            "port": port,
            "socket_path": dir.appendingPathComponent("agentlight.sock").path,
            "approve_from_menu_bar": approveFromMenuBar,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("server.json"), options: .atomic)
        }
    }
}
