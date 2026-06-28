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

    private init() {
        notifyOnComplete = defaults.object(forKey: Keys.notifyOnComplete) as? Bool ?? true
        notifyOnNeedsInput = defaults.object(forKey: Keys.notifyOnNeedsInput) as? Bool ?? true
        notifyOnFailed = defaults.object(forKey: Keys.notifyOnFailed) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }
}
