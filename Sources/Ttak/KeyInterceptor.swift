import CoreGraphics
import Foundation
import Darwin.Mach

final class KeyInterceptor {
    static let shared = KeyInterceptor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var inputSourceManager: InputSourceManager?

    // Configuration
    private var triggerKeyCode: UInt16 = KeyCode.rightCommand.rawValue
    private var holdThresholdTicks: UInt64 = 300_000_000  // Will be converted from ms to ticks
    private var debounceIntervalTicks: UInt64 = 100_000_000  // Will be converted from ms to ticks
    private var isCapsLockMode: Bool = false
    private var verbose: Bool = false
    private var timebase = mach_timebase_info_data_t()

    // State machine
    private var modifierIsDown = false
    private var modifierDownTime: UInt64 = 0
    private var otherKeyPressed = false
    private var lastToggleTime: UInt64 = 0

    private init() {}

    func setup(config: Config, inputSourceManager: InputSourceManager) {
        self.inputSourceManager = inputSourceManager
        self.triggerKeyCode = config.triggerKeyCode.rawValue
        self.isCapsLockMode = (config.triggerKey == "capsLock")
        self.verbose = config.verbose

        // Get timebase for proper tick-to-nanosecond conversion
        mach_timebase_info(&timebase)

        let holdNs = UInt64(config.holdThreshold) * 1_000_000
        let debounceNs = UInt64(config.debounceInterval) * 1_000_000
        holdThresholdTicks = holdNs &* UInt64(timebase.denom) / UInt64(timebase.numer)
        debounceIntervalTicks = debounceNs &* UInt64(timebase.denom) / UInt64(timebase.numer)

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
                                   | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            fputs("ERROR: Could not create event tap. Is Accessibility permission granted?\n", stderr)
            exit(1)
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = self.runLoopSource else {
            fputs("ERROR: Could not create run loop source\n", stderr)
            exit(1)
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        if verbose {
            fputs("Event tap installed. Trigger key: \(config.triggerKey) (keycode \(triggerKeyCode))\n", stderr)
        }
    }

    func teardown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled — re-enable
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if verbose {
                    fputs("WARNING: Event tap was disabled, re-enabling\n", stderr)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Track other key presses during modifier hold
        if type == .keyDown {
            if modifierIsDown {
                otherKeyPressed = true
            }
            return Unmanaged.passUnretained(event)
        }

        // Handle flagsChanged (modifier key events)
        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Only process our trigger key
        guard keycode == triggerKeyCode else {
            // Another modifier pressed during our trigger hold
            if modifierIsDown {
                otherKeyPressed = true
            }
            return Unmanaged.passUnretained(event)
        }

        let now = mach_absolute_time()

        // Detect key down vs key up based on flags
        let isKeyDown = isModifierDown(event: event)

        if isKeyDown {
            // Modifier key pressed down
            modifierIsDown = true
            modifierDownTime = now
            otherKeyPressed = false

            if verbose {
                fputs("Trigger key down (keycode \(keycode))\n", stderr)
            }

            // For Caps Lock mode, suppress the event to prevent LED toggle
            if isCapsLockMode {
                return nil
            }
        } else {
            // Modifier key released
            if modifierIsDown {
                modifierIsDown = false
                let elapsed = now - modifierDownTime

                if verbose {
                    fputs("Trigger key up: otherKeyPressed=\(otherKeyPressed), elapsed=\(ticksToMs(elapsed))ms\n", stderr)
                }

                // Check conditions for toggle:
                // 1. No other key was pressed during hold
                // 2. Hold duration is within threshold (tap, not hold)
                // 3. Debounce: enough time since last toggle
                if !otherKeyPressed
                    && elapsed < holdThresholdTicks
                    && (now - lastToggleTime) > debounceIntervalTicks
                {
                    lastToggleTime = now
                    inputSourceManager?.toggle()
                }

                // For Caps Lock mode, suppress the release event too
                if isCapsLockMode {
                    return nil
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isModifierDown(event: CGEvent) -> Bool {
        let flags = event.flags

        switch KeyCode(rawValue: triggerKeyCode) {
        case .rightCommand, .leftCommand:
            return flags.contains(.maskCommand)
        case .capsLock:
            return flags.contains(.maskAlphaShift)
        case .rightOption, .leftOption:
            return flags.contains(.maskAlternate)
        case .none:
            return false
        }
    }

    private func ticksToMs(_ ticks: UInt64) -> String {
        // Use Double to prevent overflow on long uptimes
        let nanos = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
        let ms = nanos / 1_000_000.0
        return String(format: "%.1f", ms)
    }
}

// Global C callback function for CGEventTap
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    return interceptor.handleEvent(proxy: proxy, type: type, event: event)
}
