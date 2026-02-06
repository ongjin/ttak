import Foundation

enum KeyCode: UInt16 {
    case rightCommand = 54
    case leftCommand  = 55
    case capsLock     = 57
    case leftOption   = 58
    case rightOption  = 61
}

enum TtakConstants {
    static let version = "2.0.0"
    static let configDefaultPath = "~/.config/ttak/config.json"
    static let bundleIdentifier = "com.ongjin.ttak"

    static let defaultInputSource1 = "com.apple.keylayout.ABC"
    static let defaultInputSource2 = "com.apple.inputmethod.Korean.2SetKorean"

    static let defaultHoldThreshold: Int = 300      // ms
    static let defaultDebounceInterval: Int = 100   // ms
}
