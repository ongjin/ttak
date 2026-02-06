import Foundation

struct Config: Codable {
    var triggerKey: String
    var inputSources: [String]
    var holdThreshold: Int
    var debounceInterval: Int
    var verbose: Bool

    init() {
        self.triggerKey = "rightCommand"
        self.inputSources = [
            TtakConstants.defaultInputSource1,
            TtakConstants.defaultInputSource2
        ]
        self.holdThreshold = TtakConstants.defaultHoldThreshold
        self.debounceInterval = TtakConstants.defaultDebounceInterval
        self.verbose = false
    }

    var triggerKeyCode: KeyCode {
        switch triggerKey {
        case "leftCommand": return .leftCommand
        case "capsLock": return .capsLock
        case "leftOption": return .leftOption
        case "rightOption": return .rightOption
        default: return .rightCommand
        }
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
}
