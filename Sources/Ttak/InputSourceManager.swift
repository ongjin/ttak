import Carbon
import CoreGraphics
import Foundation

struct InputSourceInfo {
    let id: String
    let source: TISInputSource
}

final class InputSourceManager {
    private let source1ID: String
    private let source2ID: String
    private var source1: TISInputSource?
    private var source2: TISInputSource?
    private let verbose: Bool

    init(config: Config) {
        guard config.inputSources.count >= 2 else {
            fputs("ERROR: inputSources must contain at least 2 IDs\n", stderr)
            self.source1ID = TtakConstants.defaultInputSource1
            self.source2ID = TtakConstants.defaultInputSource2
            self.verbose = config.verbose
            discoverInputSources()
            return
        }
        self.source1ID = config.inputSources[0]
        self.source2ID = config.inputSources[1]
        self.verbose = config.verbose

        discoverInputSources()
    }

    private func discoverInputSources() {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            fputs("ERROR: Could not list input sources\n", stderr)
            return
        }

        for source in sourceList {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
                continue
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

            if id == source1ID {
                self.source1 = source
            } else if id == source2ID {
                self.source2 = source
            }
        }

        if source1 == nil {
            fputs("WARNING: Input source '\(source1ID)' not found\n", stderr)
        }
        if source2 == nil {
            fputs("WARNING: Input source '\(source2ID)' not found\n", stderr)
        }
    }

    func currentInputSourceID() -> String {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idPtr = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            return ""
        }
        return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }

    func toggle() {
        let currentID = currentInputSourceID()

        // Determine target: if current is source1, switch to source2, and vice versa
        // If current is neither, switch to source1
        let targetSource: TISInputSource?
        let targetID: String

        if currentID == source1ID {
            targetSource = source2
            targetID = source2ID
        } else {
            targetSource = source1
            targetID = source1ID
        }

        guard let target = targetSource else {
            if verbose {
                fputs("Target source not available, using fallback\n", stderr)
            }
            simulateInputSourceToggle()
            return
        }

        let status = TISSelectInputSource(target)
        if status == noErr {
            if verbose {
                fputs("Toggle (TIS): \(currentID) -> \(targetID)\n", stderr)
            }
        } else {
            if verbose {
                fputs("TISSelectInputSource failed (status \(status)), using fallback\n", stderr)
            }
            simulateInputSourceToggle()
        }
    }

    private func simulateInputSourceToggle() {
        // Simulate Fn+Space (macOS 13+ default for "Select next input source")
        let spaceKeyCode: CGKeyCode = 49

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: spaceKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: spaceKeyCode, keyDown: false) else {
            fputs("ERROR: Could not create CGEvent for input source toggle\n", stderr)
            return
        }

        // Use Fn modifier (secondaryFn) for macOS 13+
        keyDown.flags = .maskSecondaryFn
        keyUp.flags = .maskSecondaryFn

        // Post to cgAnnotatedSessionEventTap to avoid our own event tap catching it
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
