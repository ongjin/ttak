import Foundation

// MARK: - Argument Parsing

var configPath = TtakConstants.configDefaultPath
var verbose = false

var args = CommandLine.arguments.dropFirst()
while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "--version":
        print("ttak v\(TtakConstants.version)")
        exit(0)
    case "--help":
        print("""
        ttak - Zero-delay Korean/English input source switcher for macOS

        USAGE: ttak [OPTIONS]

        OPTIONS:
          --version          Print version and exit
          --help             Print help and exit
          --config <path>    Config file path (default: \(TtakConstants.configDefaultPath))
          --verbose          Enable debug logging to stderr
        """)
        exit(0)
    case "--config":
        guard let next = args.first else {
            fputs("ERROR: --config requires a path argument\n", stderr)
            exit(1)
        }
        configPath = next
        args = args.dropFirst()
    case "--verbose":
        verbose = true
    default:
        fputs("ERROR: Unknown argument '\(arg)'. Use --help for usage.\n", stderr)
        exit(1)
    }
}

// MARK: - Configuration

var config = Config.load(from: configPath)
if verbose {
    config.verbose = true
}

// MARK: - Permissions Check

if !Permissions.checkAccessibility() {
    Permissions.printPermissionError()
    exit(1)
}

// MARK: - Initialize Components

let inputSourceManager = InputSourceManager(config: config)
let interceptor = KeyInterceptor.shared
interceptor.setup(config: config, inputSourceManager: inputSourceManager)

// MARK: - Signal Handling

// Use DispatchSourceSignal for async-signal-safe shutdown
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)

let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

sigTermSource.setEventHandler {
    KeyInterceptor.shared.teardown()
    CFRunLoopStop(CFRunLoopGetMain())
}
sigIntSource.setEventHandler {
    KeyInterceptor.shared.teardown()
    CFRunLoopStop(CFRunLoopGetMain())
}

sigTermSource.resume()
sigIntSource.resume()

// MARK: - Startup Banner

fputs("ttak v\(TtakConstants.version) started\n", stderr)
fputs("Trigger key: \(config.triggerKey)\n", stderr)
let src1 = config.inputSources.count > 0 ? config.inputSources[0] : "N/A"
let src2 = config.inputSources.count > 1 ? config.inputSources[1] : "N/A"
fputs("Input sources: \(src1) <-> \(src2)\n", stderr)
fputs("Hold threshold: \(config.holdThreshold)ms, Debounce: \(config.debounceInterval)ms\n", stderr)
if config.verbose {
    fputs("Verbose mode enabled\n", stderr)
}
fputs("Listening for key events...\n", stderr)

// MARK: - Run Loop (blocks forever)

CFRunLoopRun()

// Run loop stopped by signal handler
exit(0)
