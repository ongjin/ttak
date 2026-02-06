import Foundation

struct Config: Codable {
    var triggerKey: String
    var triggerKeyRawCode: UInt16?
    var inputSources: [String]
    var holdThreshold: Int
    var debounceInterval: Int
    var verbose: Bool

    init() {
        self.triggerKey = "rightCommand"
        self.triggerKeyRawCode = nil
        self.inputSources = [
            TtakConstants.defaultInputSource1,
            TtakConstants.defaultInputSource2
        ]
        self.holdThreshold = TtakConstants.defaultHoldThreshold
        self.debounceInterval = TtakConstants.defaultDebounceInterval
        self.verbose = false
    }

    /// Returns the raw keycode to use for the trigger.
    /// Prefers triggerKeyRawCode if set, otherwise maps from triggerKey string.
    var resolvedKeyCode: UInt16 {
        if let raw = triggerKeyRawCode { return raw }
        switch triggerKey {
        case "leftCommand": return KeyCode.leftCommand.rawValue
        case "capsLock": return KeyCode.capsLock.rawValue
        case "leftOption": return KeyCode.leftOption.rawValue
        case "rightOption": return KeyCode.rightOption.rawValue
        default: return KeyCode.rightCommand.rawValue
        }
    }

    /// Whether the trigger key is Caps Lock (needs special event suppression).
    var isCapsLock: Bool {
        if let raw = triggerKeyRawCode { return raw == KeyCode.capsLock.rawValue }
        return triggerKey == "capsLock"
    }

    func save(to path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let dir = (expandedPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self) {
            FileManager.default.createFile(atPath: expandedPath, contents: data)
        }
    }

    static func load(from path: String) -> Config {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expandedPath) else {
            return Config()
        }
        do {
            let decoder = JSONDecoder()
            var config = try decoder.decode(Config.self, from: data)

            // Validate inputSources has exactly 2 entries
            if config.inputSources.count < 2 {
                fputs("Warning: inputSources must contain at least 2 IDs, using defaults\n", stderr)
                config.inputSources = [
                    TtakConstants.defaultInputSource1,
                    TtakConstants.defaultInputSource2
                ]
            }

            // Clamp threshold values to reasonable ranges
            config.holdThreshold = max(10, config.holdThreshold)
            config.debounceInterval = max(10, config.debounceInterval)

            return config
        } catch {
            fputs("Warning: Could not parse config file, using defaults\n", stderr)
            return Config()
        }
    }

    /// Human-readable name for the trigger key
    static func keyName(forKeyCode code: UInt16) -> String {
        switch code {
        case KeyCode.rightCommand.rawValue: return "Right Command"
        case KeyCode.leftCommand.rawValue: return "Left Command"
        case KeyCode.capsLock.rawValue: return "Caps Lock"
        case KeyCode.leftOption.rawValue: return "Left Option"
        case KeyCode.rightOption.rawValue: return "Right Option"
        case 56: return "Left Shift"
        case 60: return "Right Shift"
        case 58: return "Left Option"
        case 61: return "Right Option"
        case 59: return "Left Control"
        case 62: return "Right Control"
        case 63: return "Function (fn)"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"
        case 90: return "F20"
        default: return "Key \(code)"
        }
    }
}
