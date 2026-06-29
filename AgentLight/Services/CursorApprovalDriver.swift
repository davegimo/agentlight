import AppKit
import Foundation

enum CursorApprovalDriver {
    private static let cursorProcessNames = ["Cursor", "Cursor Dev"]

    static func approve() {
        runCursorAutomation(action: "approve")
    }

    static func deny() {
        runCursorAutomation(action: "deny")
    }

    private static func runCursorAutomation(action: String) {
        activateCursor()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let script: String
            switch action {
            case "approve":
                script = """
                tell application "System Events"
                  repeat with processName in {"Cursor", "Cursor Dev"}
                    if exists process processName then
                      tell process processName
                        repeat with w in windows
                          repeat with b in buttons of w
                            set buttonName to name of b
                            if buttonName is "Run" or buttonName contains "Run" or buttonName is "Approve" or buttonName contains "Allow" then
                              click b
                              return
                            end if
                          end repeat
                        end repeat
                      end tell
                    end if
                  end repeat
                end tell
                """
            default:
                script = """
                tell application "System Events"
                  repeat with processName in {"Cursor", "Cursor Dev"}
                    if exists process processName then
                      tell process processName
                        repeat with w in windows
                          repeat with b in buttons of w
                            set buttonName to name of b
                            if buttonName is "Skip" or buttonName contains "Skip" or buttonName is "Deny" or buttonName contains "Reject" then
                              click b
                              return
                            end if
                          end repeat
                        end repeat
                      end tell
                    end if
                  end repeat
                end tell
                """
            }

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error {
                    NSLog("AgentLight: Cursor approval automation failed — \(error)")
                    pressReturnKey()
                }
            }
        }
    }

    private static func activateCursor() {
        for bundleID in ["com.todesktop.230313mzl4w92u", "com.cursor.app"] {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }
        for name in cursorProcessNames {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }
    }

    private static func pressReturnKey() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
