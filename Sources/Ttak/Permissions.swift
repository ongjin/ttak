import ApplicationServices
import Foundation

enum Permissions {
    /// Check if Accessibility permission is granted.
    /// If not granted, macOS will show the permission dialog automatically.
    /// Returns true if permission is already granted.
    static func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Print a helpful error message when permission is not granted.
    static func printPermissionError() {
        fputs("""
        ERROR: Accessibility permission required.

        Please grant permission in:
          System Settings > Privacy & Security > Accessibility

        Add 'ttak' to the list of allowed applications, then restart ttak.

        """, stderr)
    }
}
