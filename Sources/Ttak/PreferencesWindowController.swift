import AppKit
import Carbon

final class PreferencesWindowController: NSWindowController {
    private var triggerKeyPopUp: NSPopUpButton!
    private var source1PopUp: NSPopUpButton!
    private var source2PopUp: NSPopUpButton!
    private var holdSlider: NSSlider!
    private var holdLabel: NSTextField!
    private var debounceSlider: NSSlider!
    private var debounceLabel: NSTextField!

    private var availableSources: [InputSourceInfo] = []
    private var config: Config

    init(config: Config) {
        self.config = config

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ttak Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        availableSources = discoverKeyboardSources()
        setupUI()
        loadCurrentValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func updateConfig(_ config: Config) {
        self.config = config
        loadCurrentValues()
    }

    // MARK: - Input Source Discovery

    private func discoverKeyboardSources() -> [InputSourceInfo] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        var results: [InputSourceInfo] = []
        for source in list {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let catPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let enabledPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let category = Unmanaged<CFString>.fromOpaque(catPtr).takeUnretainedValue() as String
            let enabled = Unmanaged<CFBoolean>.fromOpaque(enabledPtr).takeUnretainedValue()

            if category == (kTISCategoryKeyboardInputSource as String) && CFBooleanGetValue(enabled) {
                results.append(InputSourceInfo(id: id, source: source))
            }
        }
        return results
    }

    private func displayName(for sourceID: String) -> String {
        if let source = availableSources.first(where: { $0.id == sourceID }),
           let namePtr = TISGetInputSourceProperty(source.source, kTISPropertyLocalizedName) {
            return Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        }
        return sourceID.components(separatedBy: ".").last ?? sourceID
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // Trigger key
        let triggerLabel = makeLabel("Trigger Key:")
        triggerKeyPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        triggerKeyPopUp.addItems(withTitles: [
            "Right Command", "Left Command", "Caps Lock", "Right Option", "Left Option"
        ])

        // Input source 1
        let src1Label = makeLabel("Input Source 1:")
        source1PopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        populateSourcePopUp(source1PopUp)

        // Input source 2
        let src2Label = makeLabel("Input Source 2:")
        source2PopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        populateSourcePopUp(source2PopUp)

        // Hold threshold
        let holdTitleLabel = makeLabel("Hold Threshold:")
        holdSlider = NSSlider(value: 300, minValue: 50, maxValue: 1000, target: self, action: #selector(holdSliderChanged))
        holdLabel = makeLabel("300 ms")
        holdLabel.alignment = .right

        // Debounce interval
        let debounceTitleLabel = makeLabel("Debounce Interval:")
        debounceSlider = NSSlider(value: 30, minValue: 20, maxValue: 500, target: self, action: #selector(debounceSliderChanged))
        debounceLabel = makeLabel("30 ms")
        debounceLabel.alignment = .right

        // Grid layout
        let grid = NSGridView(views: [
            [triggerLabel, triggerKeyPopUp],
            [src1Label, source1PopUp],
            [src2Label, source2PopUp],
            [holdTitleLabel, holdSlider, holdLabel],
            [debounceTitleLabel, debounceSlider, debounceLabel],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing

        // Buttons
        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetPressed))
        resetButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [resetButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(grid)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func populateSourcePopUp(_ popUp: NSPopUpButton) {
        popUp.removeAllItems()
        for source in availableSources {
            let name = displayName(for: source.id)
            popUp.addItem(withTitle: name)
            popUp.lastItem?.representedObject = source.id
        }
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }

    // MARK: - Load / Save

    private func loadCurrentValues() {
        // Trigger key
        let triggerIndex: Int
        switch config.triggerKey {
        case "leftCommand": triggerIndex = 1
        case "capsLock": triggerIndex = 2
        case "rightOption": triggerIndex = 3
        case "leftOption": triggerIndex = 4
        default: triggerIndex = 0 // rightCommand
        }
        triggerKeyPopUp.selectItem(at: triggerIndex)

        // Input sources
        selectSourcePopUp(source1PopUp, withID: config.inputSources.count > 0 ? config.inputSources[0] : "")
        selectSourcePopUp(source2PopUp, withID: config.inputSources.count > 1 ? config.inputSources[1] : "")

        // Sliders
        holdSlider.doubleValue = Double(config.holdThreshold)
        holdLabel.stringValue = "\(config.holdThreshold) ms"
        debounceSlider.doubleValue = Double(config.debounceInterval)
        debounceLabel.stringValue = "\(config.debounceInterval) ms"
    }

    private func selectSourcePopUp(_ popUp: NSPopUpButton, withID id: String) {
        for (index, item) in popUp.itemArray.enumerated() {
            if (item.representedObject as? String) == id {
                popUp.selectItem(at: index)
                return
            }
        }
    }

    private func triggerKeyName(at index: Int) -> String {
        switch index {
        case 1: return "leftCommand"
        case 2: return "capsLock"
        case 3: return "rightOption"
        case 4: return "leftOption"
        default: return "rightCommand"
        }
    }

    // MARK: - Actions

    @objc private func holdSliderChanged() {
        let val = Int(holdSlider.doubleValue)
        holdLabel.stringValue = "\(val) ms"
    }

    @objc private func debounceSliderChanged() {
        let val = Int(debounceSlider.doubleValue)
        debounceLabel.stringValue = "\(val) ms"
    }

    @objc private func savePressed() {
        var newConfig = Config()
        newConfig.triggerKey = triggerKeyName(at: triggerKeyPopUp.indexOfSelectedItem)

        let src1 = source1PopUp.selectedItem?.representedObject as? String ?? TtakConstants.defaultInputSource1
        let src2 = source2PopUp.selectedItem?.representedObject as? String ?? TtakConstants.defaultInputSource2
        newConfig.inputSources = [src1, src2]

        newConfig.holdThreshold = Int(holdSlider.doubleValue)
        newConfig.debounceInterval = Int(debounceSlider.doubleValue)
        newConfig.verbose = config.verbose

        newConfig.save(to: TtakConstants.configDefaultPath)
        NotificationCenter.default.post(name: .ttakConfigChanged, object: newConfig)
        window?.close()
    }

    @objc private func resetPressed() {
        let defaults = Config()
        config = defaults
        loadCurrentValues()
    }
}

extension Notification.Name {
    static let ttakConfigChanged = Notification.Name("TtakConfigChanged")
}
