import Foundation
import Testing
import TocaCore

private let ctrl = KeyChord(0, .leftControl)
private let shift = KeyChord(0, .leftShift)

private func tap(_ usage: UInt8, _ modifiers: KeyModifiers = [], after delay: Int = 0) -> [MacroStep] {
    [MacroStep(.press, KeyChord(usage, modifiers), after: delay), MacroStep(.release, KeyChord(usage, modifiers), after: 40)]
}

@Suite struct MacroActionTests {
    @Test func textTypesEachCharacterWithShiftWhereNeeded() {
        let steps = MacroAction.steps(for: [.text("Hi!")])

        #expect(steps == [
            MacroStep(.press, KeyChord(0x0B, .leftShift)), MacroStep(.release, KeyChord(0x0B, .leftShift)),
            MacroStep(.press, KeyChord(0x0C)), MacroStep(.release, KeyChord(0x0C)),
            MacroStep(.press, KeyChord(0x1E, .leftShift)), MacroStep(.release, KeyChord(0x1E, .leftShift)),
        ])
    }

    @Test func aPauseDelaysTheNextStep() {
        let steps = MacroAction.steps(for: [.shortcut(KeyChord(0x16, .leftControl)), .pause(500), .shortcut(KeyChord(0x51))])

        #expect(steps.map(\.delay) == [0, 0, 500, 0])
        #expect(steps[2] == MacroStep(.press, KeyChord(0x51), after: 500))
    }

    @Test func newlinesTypeEnterAndCurlyQuotesTypePlainOnes() {
        #expect(USKeyboard.chord(for: "\n") == KeyChord(0x28))
        #expect(USKeyboard.chord(for: "\u{201C}") == KeyChord(0x34, .leftShift))
        #expect(USKeyboard.chord(for: "\u{2019}") == KeyChord(0x34))
        #expect(USKeyboard.untypable(in: "5 mm × 3 mm, 45°") == ["×", "°"])
    }

    @Test func typedCharactersReadBack() {
        #expect(USKeyboard.character(for: KeyChord(0x04)) == "a")
        #expect(USKeyboard.character(for: KeyChord(0x04, .rightShift)) == "A")
        #expect(USKeyboard.character(for: KeyChord(0x1F, .leftShift)) == "@")
        #expect(USKeyboard.character(for: KeyChord(0x04, .leftControl)) == nil)
        #expect(USKeyboard.character(for: KeyChord(0x28)) == nil)
    }

    @Test func aRecordingBecomesTextShortcutsAndPauses() {
        // "Ok", a second's wait, then Ctrl+S.
        let steps = [MacroStep(.press, shift)] + tap(0x12, after: 120) + [MacroStep(.release, shift, after: 30)]
            + tap(0x0E, after: 150)
            + [MacroStep(.press, ctrl, after: 1000)] + tap(0x16, after: 90) + [MacroStep(.release, ctrl, after: 60)]

        #expect(MacroAction.actions(from: steps) == [.text("Ok"), .pause(1000), .shortcut(KeyChord(0x16, .leftControl))])
    }

    @Test func shortWaitsInsideTextAreTypingSpeedNotPauses() {
        let steps = tap(0x04) + tap(0x05, after: 600) + tap(0x2C, after: 1200) + tap(0x06, after: 100)

        #expect(MacroAction.actions(from: steps) == [.text("ab"), .pause(1200), .text(" c")])
    }

    @Test func keysHeldTogetherStayRecorded() {
        let steps = [MacroStep(.press, KeyChord(0x04)), MacroStep(.press, KeyChord(0x05), after: 50),
                     MacroStep(.release, KeyChord(0x04), after: 50), MacroStep(.release, KeyChord(0x05), after: 50)]

        #expect(MacroAction.actions(from: steps) == [.recorded(steps)])
        #expect(MacroAction.steps(for: [.recorded(steps)]) == steps)
    }

    @Test func aModifierTappedAloneStaysRecorded() {
        let steps = [MacroStep(.press, ctrl), MacroStep(.release, ctrl, after: 80)]

        #expect(MacroAction.actions(from: steps) == [.recorded(steps)])
    }

    @Test func aRecordedStepAfterAPauseStartsLate() {
        let recorded = [MacroStep(.press, KeyChord(0x04), after: 0), MacroStep(.release, KeyChord(0x04), after: 40)]
        let steps = MacroAction.steps(for: [.text("b"), .pause(300), .recorded(recorded)])

        #expect(steps[2].delay == 300)
    }

    @Test func aVersion3MacroLoadsAsSteps() throws {
        let json = """
            {"id": "11111111-2222-3333-4444-555555555555", "name": "Save", "speed": "normal",
             "steps": [{"action": "press", "usage": 0, "modifiers": 1, "delay": 0},
                       {"action": "press", "usage": 22, "modifiers": 0, "delay": 120},
                       {"action": "release", "usage": 22, "modifiers": 0, "delay": 60},
                       {"action": "release", "usage": 0, "modifiers": 1, "delay": 40}]}
            """
        let macro = try JSONDecoder().decode(Macro.self, from: Data(json.utf8))

        #expect(macro.actions == [.shortcut(KeyChord(0x16, .leftControl))])
    }

    @Test func stepsSaveAndLoad() throws {
        let macro = Macro(name: "Report", actions: [.text("No change.\n"), .pause(250), .shortcut(KeyChord(0x3E))])
        let data = try JSONEncoder().encode(macro)

        #expect(try JSONDecoder().decode(Macro.self, from: data) == macro)
    }

    @Test func aButtonsLookSavesAndLoads() throws {
        var page = MacroPage(title: "Mine")
        let macro = Macro(name: "F5", actions: [.shortcut(KeyChord(0x3E))])
        page.assign(macro.id, at: Cell(0, 0))
        page.setAppearance(ButtonAppearance(tint: .teal, typeface: .mono, textSize: .large, caption: "F5"), at: Cell(0, 0))
        let library = MacroLibrary(macros: [macro], pages: [page])

        #expect(try MacroLibrary(data: library.encoded()) == library)
    }

    @Test func aButtonKeepsItsLookWhenMovedOrTurned() {
        var page = MacroPage(title: "Mine")
        let look = ButtonAppearance(tint: .rose)
        page.assign(UUID(), at: Cell(0, 0))
        page.setAppearance(look, at: Cell(0, 0))

        page.move(from: Cell(0, 0), to: Cell(2, 1))
        #expect(page.button(at: Cell(2, 1))?.appearance == look)
        #expect(page.reshaped(to: .portrait).button(at: Cell(1, 2))?.appearance == look)
    }

    @Test func aVersion4MacroLookMovesOntoItsButtons() throws {
        let json = """
            {"version": 4,
             "macros": [{"id": "11111111-2222-3333-4444-555555555555", "name": "Save", "speed": "normal",
                         "actions": [{"type": "shortcut", "usage": 22, "modifiers": 1}],
                         "appearance": {"tint": "violet", "typeface": "serif", "textSize": "large", "caption": "Ctrl+S"}}],
             "pages": [{"id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "title": "Mine", "shape": {"columns": 4, "rows": 3},
                        "buttons": [{"macro": "11111111-2222-3333-4444-555555555555", "column": 1, "row": 0, "size": "small"}]}]}
            """
        let library = try MacroLibrary(data: Data(json.utf8))

        #expect(library.pages[0].button(at: Cell(1, 0))?.appearance
                == ButtonAppearance(tint: .violet, typeface: .serif, textSize: .large, caption: "Ctrl+S"))
    }

    @Test func anUnknownTintLoadsAsTheDefault() throws {
        let appearance = try JSONDecoder().decode(ButtonAppearance.self,
                                                  from: Data(#"{"tint": "chartreuse", "typeface": "serif"}"#.utf8))

        #expect(appearance == ButtonAppearance(typeface: .serif))
    }

    @Test func aDuplicateIsANewMacroJustAfterTheOriginalOnNoButtons() throws {
        let save = Macro(name: "Save", speed: .double, actions: [.shortcut(KeyChord(0x16, .leftControl))])
        let other = Macro(name: "Other", actions: [.text("x")])
        var page = MacroPage(title: "Mine")
        page.assign(save.id, at: Cell(0, 0))
        var library = MacroLibrary(macros: [save, other], pages: [page])

        let duplicate = library.duplicateMacro(save.id)
        let copy = try #require(duplicate)

        #expect(copy.id != save.id)
        #expect(copy.name == "Save copy")
        #expect(copy.speed == .double && copy.actions == save.actions)
        #expect(library.macros.map(\.id) == [save.id, copy.id, other.id])
        #expect(library.pages[0].button(at: Cell(0, 0))?.macro == save.id)
        let second = library.duplicateMacro(save.id)
        let named = library.duplicateMacro(save.id, named: "Save as PDF")
        let missing = library.duplicateMacro(UUID())
        #expect(second?.name == "Save copy 2")
        #expect(named?.name == "Save as PDF")
        #expect(missing == nil)
    }
}
