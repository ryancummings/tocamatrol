import TocaCore

/// Every user setting, persisted with @AppStorage under these keys.
enum SettingsKey {
    static let pointerSpeed = "pointerSpeed"
    static let pointerAcceleration = "pointerAccelerationRatio"
    static let scrollSpeed = "scrollSpeed"
    static let scrollAcceleration = "scrollAccelerationRatio"
    static let scrollCoast = "scrollCoast"
    static let naturalScroll = "naturalScroll"
    static let showDebug = "showDebug"
    /// Macro pad or trackpad (InputMode).
    static let inputMode = "inputMode"
    static let macroPage = "macroPage"
    /// The macro recorder's Send to PC switch.
    static let recordSendsToPC = "recordSendsToPC"
    /// Biometric/passcode lock and how long the app may be away before it locks again.
    static let requireUnlock = "requireUnlock"
    static let unlockDelay = "unlockDelay"
}

/// What the screen is: the macro pad or the trackpad.
enum InputMode: String, CaseIterable, Identifiable {
    case keys, trackpad
    var id: String { rawValue }
}

/// A snapshot of the settings the input controller needs.
struct InputSettings: Equatable {
    /// Multiplier on the slow pointer gain of 6 counts per millimetre.
    var pointerSpeed = 1.0
    /// Fast pointer gain as a multiple of the slow gain. 1 turns acceleration off.
    var pointerAcceleration = 7.0
    /// Scroll ticks per centimetre of slow two-finger travel.
    var scrollSpeed = 5.0
    /// Fast scroll gain as a multiple of the slow gain. 1 turns acceleration off.
    var scrollAcceleration = 5.0
    var scrollCoast = true
    var naturalScroll = true

    /// Slow below 25 mm/s for precise pointer placement; fast from 400 mm/s to cross wide
    /// multi-monitor desktops in one or two strokes.
    var pointerCurve: AccelerationCurve {
        let slow = 6 * pointerSpeed
        return AccelerationCurve(slowGain: slow, fastGain: slow * max(pointerAcceleration, 1),
                                 slowSpeed: 25, fastSpeed: 400)
    }

    /// Slow below 20 mm/s for line-by-line control; fast from 250 mm/s for long documents.
    var scrollCurve: AccelerationCurve {
        let slow = scrollSpeed / 10
        return AccelerationCurve(slowGain: slow, fastGain: slow * max(scrollAcceleration, 1),
                                 slowSpeed: 20, fastSpeed: 250)
    }
}
