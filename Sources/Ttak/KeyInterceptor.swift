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
    private var triggerIsModifier: Bool = true
    private var holdThresholdTicks: UInt64 = 300_000_000
    private var debounceIntervalTicks: UInt64 = 100_000_000
    private var isCapsLockMode: Bool = false
    private var verbose: Bool = false
    private var timebase = mach_timebase_info_data_t()

    // State machine
    private var triggerIsDown = false
    private var triggerDownTime: UInt64 = 0
    private var otherKeyPressed = false
    private var lastToggleTime: UInt64 = 0

    // Recording mode: captures the next key press (modifier or regular)
    var isRecording = false
    var onKeyRecorded: ((UInt16) -> Void)?

    private static let modifierKeycodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private init() {}

    func setup(config: Config, inputSourceManager: InputSourceManager) -> Bool {
        self.inputSourceManager = inputSourceManager
        self.triggerKeyCode = config.resolvedKeyCode
        self.triggerIsModifier = Self.modifierKeycodes.contains(config.resolvedKeyCode)
        self.isCapsLockMode = config.isCapsLock
        self.verbose = config.verbose

        mach_timebase_info(&timebase)

        let holdNs = UInt64(config.holdThreshold) * 1_000_000
        let debounceNs = UInt64(config.debounceInterval) * 1_000_000
        holdThresholdTicks = holdNs &* UInt64(timebase.denom) / UInt64(timebase.numer)
        debounceIntervalTicks = debounceNs &* UInt64(timebase.denom) / UInt64(timebase.numer)

        // Capture flagsChanged, keyDown, and keyUp
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
                                   | (1 << CGEventType.keyDown.rawValue)
                                   | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            fputs("ERROR: Could not create event tap. Is Accessibility permission granted?\n", stderr)
            return false
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = self.runLoopSource else {
            fputs("ERROR: Could not create run loop source\n", stderr)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
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
        let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Handle tap disabled — re-enable
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Recording mode: capture any key press
        if isRecording {
            if type == .flagsChanged && Self.modifierKeycodes.contains(keycode) && event.flags.rawValue > 256 {
                isRecording = false
                DispatchQueue.main.async { [self] in
                    onKeyRecorded?(keycode)
                    onKeyRecorded = nil
                }
                return nil
            }
            if type == .keyDown {
                isRecording = false
                DispatchQueue.main.async { [self] in
                    onKeyRecorded?(keycode)
                    onKeyRecorded = nil
                }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // === Modifier-key trigger path (flagsChanged) ===
        if triggerIsModifier {
            if type == .keyDown || type == .keyUp {
                // Track other key presses during trigger hold
                if triggerIsDown && type == .keyDown {
                    otherKeyPressed = true
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .flagsChanged else {
                return Unmanaged.passUnretained(event)
            }

            guard keycode == triggerKeyCode else {
                if triggerIsDown { otherKeyPressed = true }
                return Unmanaged.passUnretained(event)
            }

            let now = mach_absolute_time()
            let isDown = isModifierDown(event: event)

            if isDown {
                triggerIsDown = true
                triggerDownTime = now
                otherKeyPressed = false
                if isCapsLockMode { return nil }
            } else {
                if triggerIsDown {
                    triggerIsDown = false
                    let elapsed = now - triggerDownTime
                    if !otherKeyPressed
                        && elapsed < holdThresholdTicks
                        && (now - lastToggleTime) > debounceIntervalTicks
                    {
                        lastToggleTime = now
                        inputSourceManager?.toggle()
                    }
                    if isCapsLockMode { return nil }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // === Regular-key trigger path (keyDown/keyUp) ===
        if type == .flagsChanged {
            // Modifier changes during trigger hold count as "other key"
            if triggerIsDown { otherKeyPressed = true }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if keycode == triggerKeyCode {
                if !triggerIsDown {
                    triggerIsDown = true
                    triggerDownTime = mach_absolute_time()
                    otherKeyPressed = false
                }
                return nil // suppress the trigger key
            }
            // Other key pressed during trigger hold
            if triggerIsDown { otherKeyPressed = true }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp {
            if keycode == triggerKeyCode {
                if triggerIsDown {
                    triggerIsDown = false
                    let now = mach_absolute_time()
                    // For regular keys (F18 etc.), always toggle on release
                    // No otherKeyPressed or holdThreshold check needed
                    if (now - lastToggleTime) > debounceIntervalTicks {
                        lastToggleTime = now
                        inputSourceManager?.toggle()
                    }
                }
                return nil // suppress the trigger key
            }
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func isModifierDown(event: CGEvent) -> Bool {
        let flags = event.flags

        switch triggerKeyCode {
        case 54, 55: return flags.contains(.maskCommand)
        case 57: return flags.contains(.maskAlphaShift)
        case 58, 61: return flags.contains(.maskAlternate)
        case 56, 60: return flags.contains(.maskShift)
        case 59, 62: return flags.contains(.maskControl)
        case 63: return flags.contains(.maskSecondaryFn)
        default: return false
        }
    }

    private func ticksToMs(_ ticks: UInt64) -> String {
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
