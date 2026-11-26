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
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITestResetState"),
           let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        // Seed initial @AppStorage defaults into the standard domain rather than passing
        // `-<key>` on the command line, which would lock NSArgumentDomain against UI changes.
        for index in args.indices {
            let arg = args[index]
            guard arg.hasPrefix("-UITestDefault:"), args.indices.contains(index + 1) else { continue }
            let key = String(arg.dropFirst("-UITestDefault:".count))
            UserDefaults.standard.set(args[index + 1], forKey: key)
        }
    }

    static let currentDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-00000000566D")!
    static let otherDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-000000001F2B")!
    static let newDongle = UUID(uuidString: "6D1A0C5E-0000-4000-8000-00000000A93C")!

    /// Fixed IDs, so tests can open a page with `-UITestDefault:macroPage <id>`.
    static let quickPage = UUID(uuidString: "0CA7E000-0000-4000-8000-000000000001")!
    static let devPage = UUID(uuidString: "0CA7E000-0000-4000-8000-000000000002")!
    /// A full 7x4 deck for the iPad promo art; added only with `-UITestDenseDeck`, so the
    /// other screenshots keep their two pages.
    static let deckPage = UUID(uuidString: "0CA7E000-0000-4000-8000-000000000003")!

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

        var macros = [terminal, copy, paste, undo, saveAll, screenshot, comment, snippet, lockPC]
        var pages = [quick, dev]
        if ProcessInfo.processInfo.arguments.contains("-UITestDenseDeck") {
            let (deckMacros, deck) = denseDeck(copy: copy, paste: paste, screenshot: screenshot, lockPC: lockPC)
            macros += deckMacros
            pages.append(deck)
        }
        return MacroLibrary(macros: macros, pages: pages)
    }

    private typealias Key = (name: String, chord: KeyChord, caption: String, tint: ButtonAppearance.Tint)

    /// 7 columns x 4 rows of everyday shortcuts, every cell filled.
    private static func denseDeck(copy: Macro, paste: Macro, screenshot: Macro,
                                  lockPC: Macro) -> ([Macro], MacroPage) {
        let ctrl = KeyModifiers.leftControl, shift = KeyModifiers.leftShift
        let gui = KeyModifiers.leftGUI, alt = KeyModifiers.leftAlt
        let rows: [[Key]] = [
            [("Cut", KeyChord(0x1B, ctrl), "Ctrl+X", .blue),
             ("Redo", KeyChord(0x1C, ctrl), "Ctrl+Y", .sand),
             ("Find", KeyChord(0x09, ctrl), "Ctrl+F", .teal),
             ("Save", KeyChord(0x16, ctrl), "Ctrl+S", .green),
             ("Select All", KeyChord(0x04, ctrl), "Ctrl+A", .sand)],
            [("New Tab", KeyChord(0x17, ctrl), "Ctrl+T", .violet),
             ("Close Tab", KeyChord(0x1A, ctrl), "Ctrl+W", .violet),
             ("Reopen Tab", KeyChord(0x17, [ctrl, shift]), "Ctrl+⇧T", .violet),
             ("Prev Tab", KeyChord(0x2B, [ctrl, shift]), "Ctrl+⇧Tab", .graphite),
             ("Next Tab", KeyChord(0x2B, ctrl), "Ctrl+Tab", .graphite),
             ("Zoom In", KeyChord(0x2E, ctrl), "Ctrl+=", .amber),
             ("Zoom Out", KeyChord(0x2D, ctrl), "Ctrl+-", .amber)],
            [("Mute Mic", KeyChord(0x10, [ctrl, shift]), "Ctrl+⇧M", .rose),
             ("Camera", KeyChord(0x08, [ctrl, shift]), "Ctrl+⇧E", .rose),
             ("Desktop", KeyChord(0x07, gui), "Win+D", .graphite),
             ("Search", KeyChord(0x2C, gui), "Win+Space", .teal),
             ("Emoji", KeyChord(0x37, gui), "Win+.", .amber),
             ("Task View", KeyChord(0x2B, gui), "Win+Tab", .graphite),
             ("Switch App", KeyChord(0x2B, alt), "Alt+Tab", .graphite)],
            [("Refresh", KeyChord(0x3E), "F5", .teal),
             ("Full Screen", KeyChord(0x44), "F11", .teal),
             ("Rename", KeyChord(0x3B), "F2", .sand),
             ("History", KeyChord(0x0B, ctrl), "Ctrl+H", .violet),
             ("Print", KeyChord(0x13, ctrl), "Ctrl+P", .sand)],
        ]
        var deck = MacroPage(id: deckPage, title: "Everyday", shape: GridShape(columns: 7, rows: 4))
        var made: [Macro] = []
        func place(_ macro: Macro, _ column: Int, _ row: Int, _ look: ButtonAppearance) {
            deck.assign(macro.id, at: Cell(column, row))
            deck.setAppearance(look, at: Cell(column, row))
        }
        // The first row opens with the Quick Actions basics.
        place(copy, 0, 0, ButtonAppearance(tint: .blue, caption: "Ctrl+C"))
        place(paste, 1, 0, ButtonAppearance(tint: .blue, caption: "Ctrl+V"))
        for (row, keys) in rows.enumerated() {
            var column = row == 0 ? 2 : 0
            for key in keys {
                let macro = Macro(name: key.name, speed: .instant, actions: [.shortcut(key.chord)])
                made.append(macro)
                place(macro, column, row, ButtonAppearance(tint: key.tint, caption: key.caption))
                column += 1
            }
        }
        place(screenshot, 5, 3, ButtonAppearance(tint: .violet, caption: "Win+⇧S"))
        place(lockPC, 6, 3, ButtonAppearance(tint: .rust, caption: "Win+L"))
        return (made, deck)
    }
}
#endif
