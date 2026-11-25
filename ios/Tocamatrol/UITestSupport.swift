#if DEBUG
import Foundation
import TocaCore

/// Test mode (`TocamatrolUITests`): `-UITestMode` launches with a simulated dongle and
/// general-purpose demo pages so UI tests and App Store screenshots run without hardware.
/// `-UITestResetState` clears saved settings first. Debug builds only.
enum UITestSupport {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-UITestMode") }

    /// Runs before any view reads its settings.
    static func prepare() {
        guard isActive else { return }
        if ProcessInfo.processInfo.arguments.contains("-UITestResetState"),
           let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }

    static let currentDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-00000000566D")!
    static let otherDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-000000001F2B")!
    static let newDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-00000000A93C")!

    /// Fixed IDs, so tests can open a page with `-macroPage <id>`.
    static let quickPage = UUID(uuidString: "0CA7E000-0000-4000-8000-000000000001")!
    static let devPage = UUID(uuidString: "0CA7E000-0000-4000-8000-000000000002")!

    static var library: MacroLibrary {
        let copy = Macro(name: "Copy", speed: .instant, actions: [.shortcut(KeyChord(0x06, .leftControl))])
        let paste = Macro(name: "Paste", speed: .instant, actions: [.shortcut(KeyChord(0x19, .leftControl))])
        let undo = Macro(name: "Undo", speed: .instant, actions: [.shortcut(KeyChord(0x1D, .leftControl))])
        let saveAll = Macro(name: "Save & Build", speed: .double,
                            actions: [.shortcut(KeyChord(0x16, .leftControl)), .pause(800), .shortcut(KeyChord(0x05, [.leftControl, .leftShift]))])
        let screenshot = Macro(name: "Screenshot", speed: .instant,
                               actions: [.shortcut(KeyChord(0x16, [.leftGUI, .leftShift]))])
        let comment = Macro(name: "Toggle Comment", speed: .instant, actions: [.shortcut(KeyChord(0x38, .leftControl))])
        let terminal = Macro(name: "Open Terminal",
                             actions: [.shortcut(KeyChord(0x15, .leftGUI)), .pause(1400), .text("terminal\n"), .pause(2600),
                                       .shortcut(KeyChord(0x17, [.leftControl, .leftShift])), .pause(300), .text("git status")])
        let snippet = Macro(name: "Email Sign-Off", actions: [.text("Best regards,\n")])
        let lockPC = Macro(name: "Lock Screen", speed: .instant, actions: [.shortcut(KeyChord(0x0F, .leftGUI))])

        var quick = MacroPage(id: quickPage, title: "Quick Actions", shape: GridShape(columns: 4, rows: 3))
        quick.assign(copy.id, at: Cell(0, 0))
        quick.resize(at: Cell(0, 0), to: .large)
        quick.assign(paste.id, at: Cell(2, 0))
        quick.assign(undo.id, at: Cell(3, 0))
        quick.assign(saveAll.id, at: Cell(2, 1))
        quick.resize(at: Cell(2, 1), to: .wide)
        quick.assign(screenshot.id, at: Cell(0, 2))
        quick.resize(at: Cell(0, 2), to: .wide)
        quick.assign(comment.id, at: Cell(3, 2))
        quick.setAppearance(ButtonAppearance(tint: .blue, caption: "Ctrl+C"), at: Cell(0, 0))
        quick.setAppearance(ButtonAppearance(tint: .green, caption: "Ctrl+S, ⇧B"), at: Cell(2, 1))
        quick.setAppearance(ButtonAppearance(tint: .violet, typeface: .serif), at: Cell(0, 2))
        quick.setAppearance(ButtonAppearance(tint: .teal, typeface: .mono, caption: "Ctrl+/"), at: Cell(3, 2))

        var dev = MacroPage(id: devPage, title: "Workspace", shape: GridShape(columns: 4, rows: 3))
        dev.assign(terminal.id, at: Cell(0, 0))
        dev.resize(at: Cell(0, 0), to: ButtonSpan(columns: 3, rows: 1))
        dev.assign(snippet.id, at: Cell(0, 1))
        dev.assign(lockPC.id, at: Cell(1, 1))
        dev.resize(at: Cell(1, 1), to: .tall)
        dev.setAppearance(ButtonAppearance(tint: .amber, typeface: .mono, caption: "Run git status"), at: Cell(0, 0))
        dev.setAppearance(ButtonAppearance(tint: .teal, typeface: .rounded), at: Cell(0, 1))
        dev.setAppearance(ButtonAppearance(tint: .rose, typeface: .rounded, textSize: .large), at: Cell(1, 1))

        return MacroLibrary(macros: [terminal, copy, paste, undo, saveAll, screenshot, comment, snippet, lockPC],
                            pages: [quick, dev])
    }
}
#endif
