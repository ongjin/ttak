import AppKit
import ApplicationServices
import Foundation

enum Permissions {
    /// Check if Accessibility permission is granted without showing any dialog.
    static func checkAccessibilitySilent() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Show an alert explaining that Accessibility permission is needed.
    /// Returns true if the user chose "Open System Settings", false if "Quit".
    @discardableResult
    static func showPermissionAlert() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Ttak needs Accessibility permission to intercept keyboard events and switch input sources.\n\nPlease grant permission in System Settings, then Ttak will activate automatically."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
            return true
        } else {
            NSApplication.shared.terminate(nil)
            return false
        }
    }

    /// Open the Accessibility pane in System Settings.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Poll for Accessibility permission every 2 seconds.
    /// Calls onGranted when permission is detected.
    static func startPermissionPolling(onGranted: @escaping () -> Void) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if checkAccessibilitySilent() {
                timer.invalidate()
                onGranted()
            }
        }
    }
}
