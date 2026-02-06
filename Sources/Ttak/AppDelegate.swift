import AppKit
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var inputSourceManager: InputSourceManager?
    private var preferencesController: PreferencesWindowController?
    private var config: Config!
    private var permissionTimer: Timer?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load configuration
        config = Config.load(from: TtakConstants.configDefaultPath)

        // Create status bar UI
        statusBarController = StatusBarController(config: config)
        statusBarController.onOpenPreferences = { [weak self] in
            self?.showPreferences()
        }

        // Observe config changes from Preferences window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange(_:)),
            name: .ttakConfigChanged,
            object: nil
        )

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

    private func showPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController(config: config)
        } else {
            preferencesController?.updateConfig(config)
        }
        preferencesController?.showWindow(nil)
        preferencesController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func configDidChange(_ notification: Notification) {
        guard let newConfig = notification.object as? Config else { return }
        config = newConfig

        // Restart interceptor with new config
        KeyInterceptor.shared.teardown()
        inputSourceManager = InputSourceManager(config: config)
        let success = KeyInterceptor.shared.setup(config: config, inputSourceManager: inputSourceManager!)

        if success {
            statusBarController.updateStatus(.active)
        } else {
            statusBarController.updateStatus(.error)
        }

        // Reload menu to reflect new settings
        statusBarController.reloadMenu(config: config)
    }
}
