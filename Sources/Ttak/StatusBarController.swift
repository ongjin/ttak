import AppKit
import ServiceManagement

enum AppStatus {
    case active
    case noPermission
    case error
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    var config: Config
    private var statusMenuItem: NSMenuItem!
    var onOpenPreferences: (() -> Void)?

    init(config: Config) {
        self.config = config
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Ttak")
        }

        setupMenu()
    }

    func reloadMenu(config: Config) {
        self.config = config
        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // App title
        let titleItem = NSMenuItem(title: "Ttak v\(TtakConstants.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        statusMenuItem = NSMenuItem(title: "Status: Starting...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Input sources
        let src1 = shortName(config.inputSources.count > 0 ? config.inputSources[0] : "N/A")
        let src2 = shortName(config.inputSources.count > 1 ? config.inputSources[1] : "N/A")
        let sourceItem = NSMenuItem(title: "\(src1) ↔ \(src2)", action: nil, keyEquivalent: "")
        sourceItem.isEnabled = false
        menu.addItem(sourceItem)

        menu.addItem(NSMenuItem.separator())

        // Trigger key
        let triggerName = Config.keyName(forKeyCode: config.resolvedKeyCode)
        let triggerItem = NSMenuItem(title: "Trigger: \(triggerName)", action: nil, keyEquivalent: "")
        triggerItem.isEnabled = false
        menu.addItem(triggerItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Ttak", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatus(_ status: AppStatus) {
        switch status {
        case .active:
            statusMenuItem.title = "Status: Active"
        case .noPermission:
            statusMenuItem.title = "Status: Waiting for Permission"
        case .error:
            statusMenuItem.title = "Status: Error"
        }
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            fputs("WARNING: Launch at Login toggle failed: \(error)\n", stderr)
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func shortName(_ sourceID: String) -> String {
        let last = sourceID.components(separatedBy: ".").last ?? sourceID
        switch last {
        case "2SetKorean": return "Korean"
        case "ABC": return "English"
        default: return last
        }
    }
}
