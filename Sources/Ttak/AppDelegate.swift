import AppKit
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var inputSourceManager: InputSourceManager?
    private var config: Config!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load configuration
        config = Config.load(from: TtakConstants.configDefaultPath)

        // Create status bar UI
        statusBarController = StatusBarController(config: config)

        // Check Accessibility permission and start interceptor
        if Permissions.checkAccessibilitySilent() {
            startInterceptor()
        } else {
            statusBarController.updateStatus(.noPermission)
            let userWantsToGrant = Permissions.showPermissionAlert()
            // Only start polling if user chose "Open System Settings"
            // If user chose "Quit", terminate() was already called above
            if userWantsToGrant {
                permissionTimer = Permissions.startPermissionPolling { [weak self] in
                    self?.permissionTimer = nil
                    self?.startInterceptor()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        KeyInterceptor.shared.teardown()
    }

    private func startInterceptor() {
        guard config.inputSources.count >= 2 else {
            fputs("ERROR: inputSources must contain at least 2 IDs\n", stderr)
            statusBarController.updateStatus(.error)
            return
        }

        inputSourceManager = InputSourceManager(config: config)
        let success = KeyInterceptor.shared.setup(config: config, inputSourceManager: inputSourceManager!)

        if success {
            statusBarController.updateStatus(.active)
        } else {
            statusBarController.updateStatus(.error)
            let alert = NSAlert()
            alert.messageText = "Failed to Start"
            alert.informativeText = "Could not create the event tap. Please check Accessibility permission and try again."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
