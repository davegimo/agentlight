import AppKit
import Foundation

enum WorkspaceOpener {
    private static let cursorAppPaths = [
        "/Applications/Cursor.app",
        "/Applications/Cursor Dev.app",
    ]

    private static let cursorBundleIDs = [
        "com.todesktop.230313mzl4w92u",
        "com.cursor.app",
    ]

    static func open(agent: Agent) {
        guard let workspace = agent.workspacePath, !workspace.isEmpty else { return }
        open(providerID: agent.providerID, workspacePath: workspace)
    }

    static func open(context: AgentFocusContext) {
        open(providerID: context.providerID, workspacePath: context.workspacePath)
    }

    static func open(providerID: String, workspacePath: String) {
        switch providerID {
        case "cursor":
            openCursor(workspacePath: workspacePath)
        default:
            NSLog("AgentLight: no opener for provider \(providerID)")
        }
    }

    private static func openCursor(workspacePath: String) {
        let expanded = (workspacePath as NSString).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expanded, isDirectory: true)

        guard FileManager.default.fileExists(atPath: expanded) else {
            NSLog("AgentLight: workspace not found at \(expanded)")
            activateCursorOnly()
            return
        }

        guard let appURL = resolveCursorAppURL() else {
            NSLog("AgentLight: Cursor.app not found")
            NSWorkspace.shared.open(workspaceURL)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.promptsUserIfNeeded = false

        NSWorkspace.shared.open(
            [workspaceURL],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if let error {
                NSLog("AgentLight: failed to open Cursor — \(error.localizedDescription)")
                activateCursorOnly()
            }
        }
    }

    private static func resolveCursorAppURL() -> URL? {
        for bundleID in cursorBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }
        for path in cursorAppPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                return url
            }
        }
        return nil
    }

    private static func activateCursorOnly() {
        guard let appURL = resolveCursorAppURL() else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
    }
}
