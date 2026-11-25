// The saved library must still load after an app update, so tests cover versions 1 through 6.
import Foundation
import Testing
import TocaCore

private let copyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
private let pageID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

private let copy = Macro(id: copyID, name: "Copy", speed: .double, steps: [
    MacroStep(.press, KeyChord(0, .leftControl)), MacroStep(.press, KeyChord(0x06), after: 200),
    MacroStep(.release, KeyChord(0x06), after: 50), MacroStep(.release, KeyChord(0, .leftControl), after: 250),
])

@Suite struct MacroLibraryTests {
    @Test func aSavedLibraryLoadsBackTheSame() throws {
        var page = MacroPage(id: pageID, title: "Mine", shape: GridShape(columns: 5, rows: 3))
        page.assign(copyID, at: Cell(1, 1))
        page.resize(at: Cell(1, 1), to: ButtonSpan(columns: 3, rows: 1))
        let library = MacroLibrary(macros: [copy], pages: [page])

        #expect(try MacroLibrary(data: library.encoded()) == library)
    }

    @Test func readsAVersion1FileAsSmallButtons() throws {
        let json = """
            {"version": 1,
             "macros": [{"id": "11111111-2222-3333-4444-555555555555", "name": "Copy", "speed": "double",
                         "steps": [{"action": "press", "usage": 0, "modifiers": 1, "delay": 0},
                                   {"action": "press", "usage": 6, "modifiers": 0, "delay": 200},
                                   {"action": "release", "usage": 6, "modifiers": 0, "delay": 50},
                                   {"action": "release", "usage": 0, "modifiers": 1, "delay": 250}]}],
             "pages": [{"id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "title": "Mine",
                        "slots": [null, null, null, null, null, "11111111-2222-3333-4444-555555555555",
                                  null, null, null, null, null, null]}]}
            """
        let library = try MacroLibrary(data: Data(json.utf8))

        #expect(library.macros == [copy])
        #expect(library.pages.map(\.title) == ["Mine"])
        #expect(library.macro(on: library.pages[0], at: Cell(1, 1)) == copy)
        #expect(library.pages[0].button(at: Cell(1, 1))?.span == .small)
        #expect(library.macro(on: library.pages[0], at: Cell(0, 0)) == nil)
    }

    @Test func readsVersion5ButtonsWithLegacySizeStrings() throws {
        let json = """
            {"version": 5,
             "macros": [{"id": "11111111-2222-3333-4444-555555555555", "name": "Copy", "speed": "normal",
                         "actions": [{"type": "shortcut", "usage": 6, "modifiers": 1}]}],
             "pages": [{"id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "title": "Mine",
                        "shape": {"columns": 3, "rows": 4},
                        "buttons": [{"macro": "11111111-2222-3333-4444-555555555555",
                                     "column": 0, "row": 1, "size": "tall",
                                     "appearance": {"tint": "blue", "typeface": "mono", "textSize": "large", "caption": "Ctrl+C"}}]}]}
            """
        let library = try MacroLibrary(data: Data(json.utf8))
        let btn = library.pages[0].button(at: Cell(0, 2))

        #expect(btn?.origin == Cell(0, 1))
        #expect(btn?.span == ButtonSpan(columns: 1, rows: 2))
        #expect(btn?.appearance == ButtonAppearance(tint: .blue, typeface: .mono, textSize: .large, caption: "Ctrl+C"))
    }

    @Test func deletingAMacroEmptiesItsButtons() {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.assign(copyID, at: Cell(3, 1))
        var library = MacroLibrary(macros: [copy], pages: [page])

        library.deleteMacro(copyID)

        #expect(library.macros.isEmpty)
        #expect(library.pages[0].buttons.isEmpty)
    }

    @Test func aButtonResizedToArbitrarySpanCoversItsCells() {
        var page = MacroPage(id: pageID, title: "Mine", shape: GridShape(columns: 5, rows: 4))
        page.assign(copyID, at: Cell(1, 0))

        let resized = page.resize(at: Cell(1, 0), to: ButtonSpan(columns: 3, rows: 2))
        #expect(resized)
        let library = MacroLibrary(macros: [copy], pages: [page])

        for r in 0..<2 {
            for c in 1..<4 {
                #expect(library.macro(on: page, at: Cell(c, r)) == copy)
                #expect(page.button(at: Cell(c, r))?.span == ButtonSpan(columns: 3, rows: 2))
            }
        }
        #expect(library.macro(on: page, at: Cell(0, 0)) == nil)
        #expect(library.macro(on: page, at: Cell(4, 0)) == nil)
        #expect(library.macro(on: page, at: Cell(1, 2)) == nil)
    }

    @Test func aButtonCannotGrowOverAnotherOrOffTheGrid() {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.assign(copyID, at: Cell(1, 1))
        page.assign(copyID, at: Cell(3, 2))

        #expect(page.canResize(at: Cell(0, 0), to: .wide))
        #expect(page.canResize(at: Cell(0, 0), to: .tall))
        #expect(page.canResize(at: Cell(0, 0), to: ButtonSpan(columns: 4, rows: 1)))
        #expect(!page.canResize(at: Cell(0, 0), to: .large))  // (1, 1) is taken
        #expect(!page.canResize(at: Cell(3, 2), to: .wide))   // off the right edge
        #expect(!page.canResize(at: Cell(3, 2), to: .tall))   // off the bottom
        #expect(!page.canResize(at: Cell(2, 0), to: .small))  // no button there

        let before = page
        let resized = page.resize(at: Cell(0, 0), to: .large)
        #expect(!resized)
        #expect(page == before)
    }

    @Test func gridResizeSucceedsOnlyWhenAllButtonsFit() {
        var page = MacroPage(id: pageID, title: "Mine", shape: GridShape(columns: 4, rows: 3))
        page.assign(copyID, at: Cell(2, 1))
        page.resize(at: Cell(2, 1), to: .wide)  // covers (2,1) and (3,1)

        #expect(!page.canResizeGrid(to: GridShape(columns: 3, rows: 3)))
        let shrunk = page.resizeGrid(to: GridShape(columns: 3, rows: 3))
        #expect(!shrunk)
        #expect(page.shape == GridShape(columns: 4, rows: 3))

        #expect(page.canResizeGrid(to: GridShape(columns: 4, rows: 2)))
        let expanded = page.resizeGrid(to: GridShape(columns: 6, rows: 4))
        #expect(expanded)
        #expect(page.shape == GridShape(columns: 6, rows: 4))
        #expect(page.button(at: Cell(3, 1))?.span == .wide)
    }

    @Test func shrinkingFreesCellsAndEmptyingRemovesTheButton() {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.resize(at: Cell(0, 0), to: .large)

        page.resize(at: Cell(1, 1), to: .small)
        #expect(page.button(at: Cell(1, 1)) == nil)
        #expect(page.button(at: Cell(0, 0))?.span == .small)

        page.assign(nil, at: Cell(0, 0))
        #expect(page.buttons.isEmpty)
    }

    @Test func aButtonMovesIntoEmptyCells() {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.resize(at: Cell(0, 0), to: .wide)

        // Dragged by its right half: the button's top left still lands where asked.
        let moved = page.move(from: Cell(1, 0), to: Cell(2, 1))
        #expect(moved)
        #expect(page.button(at: Cell(0, 0)) == nil)
        #expect(page.button(at: Cell(2, 1))?.origin == Cell(2, 1))
        #expect(page.button(at: Cell(3, 1))?.span == .wide)
    }

    @Test func aButtonMovesOverPartOfItself() {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.resize(at: Cell(0, 0), to: .large)

        let moved = page.move(from: Cell(0, 0), to: Cell(1, 0))
        #expect(moved)
        #expect(page.button(at: Cell(0, 0)) == nil)
        #expect(page.button(at: Cell(2, 1))?.origin == Cell(1, 0))
    }

    @Test func buttonsOfTheSameSpanSwapPlaces() {
        let other = UUID(uuidString: "99999999-2222-3333-4444-555555555555")!
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.resize(at: Cell(0, 0), to: ButtonSpan(columns: 1, rows: 2))
        page.assign(other, at: Cell(3, 1))
        page.resize(at: Cell(3, 1), to: ButtonSpan(columns: 1, rows: 2))

        let swapped = page.move(from: Cell(0, 0), to: Cell(3, 1))
        #expect(swapped)
        #expect(page.button(at: Cell(3, 1))?.macro == copyID)
        #expect(page.button(at: Cell(0, 0))?.macro == other)
        #expect(page.buttons.count == 2)
    }

    @Test func aMoveThatWouldOverlapOrLeaveTheGridChangesNothing() {
        let other = UUID(uuidString: "99999999-2222-3333-4444-555555555555")!
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(0, 0))
        page.resize(at: Cell(0, 0), to: .wide)
        page.assign(other, at: Cell(3, 0))
        let before = page

        #expect(!page.canMove(from: Cell(0, 0), to: Cell(3, 1)))  // off the right edge
        #expect(!page.canMove(from: Cell(0, 0), to: Cell(2, 0)))  // half over a small button
        #expect(!page.canMove(from: Cell(0, 0), to: Cell(0, 3)))  // below the grid
        #expect(!page.canMove(from: Cell(1, 2), to: Cell(0, 0)))  // no button there
        let moved = page.move(from: Cell(0, 0), to: Cell(2, 0))
        #expect(!moved)
        #expect(page == before)
    }

    @Test func aPageTurnsOnItsSideForTheOtherShape() throws {
        var page = MacroPage(id: pageID, title: "Mine")
        page.assign(copyID, at: Cell(1, 0))
        page.resize(at: Cell(1, 0), to: .wide)  // covers (1, 0) and (2, 0)
        page.assign(copyID, at: Cell(3, 1))
        page.resize(at: Cell(3, 1), to: .tall)  // covers (3, 1) and (3, 2)

        let phone = page.reshaped(to: .portrait)

        #expect(phone.columns == 3 && phone.rows == 4)
        #expect(phone.button(at: Cell(0, 1))?.span == .tall)
        #expect(phone.button(at: Cell(0, 2))?.origin == Cell(0, 1))
        #expect(phone.button(at: Cell(1, 3))?.span == .wide)
        #expect(phone.button(at: Cell(2, 3))?.origin == Cell(1, 3))
        #expect(phone.reshaped(to: .landscape) == page)
        #expect(try MacroLibrary(data: MacroLibrary(pages: [phone]).encoded()).pages == [phone])
    }

    @Test func aPageSavedWithoutAShapeIs4By3() throws {
        let json = """
            {"version": 2, "macros": [],
             "pages": [{"id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "title": "Mine",
                        "buttons": [{"macro": "11111111-2222-3333-4444-555555555555",
                                     "column": 3, "row": 2, "size": "small"}]}]}
            """
        let page = try MacroLibrary(data: Data(json.utf8)).pages[0]

        #expect(page.shape == .landscape)
        #expect(page.button(at: Cell(3, 2))?.macro == copyID)
    }

    @Test func starterLibraryCreatesValidNonOverlappingPage() {
        for shape in [GridShape.phoneDefault, GridShape.padDefault] {
            let starter = MacroLibrary.starter(for: shape)
            #expect(starter.pages.count == 1)
            #expect(!starter.macros.isEmpty)
            let page = starter.pages[0]
            #expect(page.shape == shape)
            #expect(!page.buttons.isEmpty)
            var covered = Set<Cell>()
            for button in page.buttons {
                #expect(starter.macros.contains { $0.id == button.macro })
                for cell in button.cells {
                    #expect(shape.contains(cell))
                    #expect(covered.insert(cell).inserted)
                }
            }
        }
    }

    @Test func exportAndMergeRemapsIDsWithoutColliding() throws {
        var page = MacroPage(id: pageID, title: "Shared")
        page.assign(copyID, at: Cell(0, 0))
        let incoming = MacroLibrary(macros: [copy], pages: [page])
        let data = try incoming.exportJSON()
        let decoded = try MacroLibrary.importJSON(data)

        var existing = MacroLibrary(macros: [copy], pages: [page])
        let added = existing.merge(decoded)

        #expect(added.macros == 1)
        #expect(added.pages == 1)
        #expect(existing.macros.count == 2)
        #expect(existing.pages.count == 2)
        #expect(existing.macros[0].id != existing.macros[1].id)
        #expect(existing.pages[0].id != existing.pages[1].id)
        #expect(existing.pages[1].buttons[0].macro == existing.macros[1].id)
    }

    @Test func sensitiveMacrosRoundTripDuplicateAndMergeSafely() throws {
        let secret = Macro(id: copyID, name: "Vault Login", speed: .double, isSensitive: true,
                           actions: [.text("hunter2"), .shortcut(KeyChord(0x28))])
        var page = MacroPage(id: pageID, title: "Logins")
        page.assign(copyID, at: Cell(0, 0))
        var library = MacroLibrary(macros: [secret], pages: [page])

        let decoded = try MacroLibrary(data: library.encoded())
        #expect(decoded.macros.first?.isSensitive == true)

        let imported = try MacroLibrary.importJSON(library.exportJSON())
        #expect(imported.macros.first?.isSensitive == true)

        let duplicated = library.duplicateMacro(copyID)
        #expect(duplicated?.isSensitive == true)

        var merged = MacroLibrary()
        _ = merged.merge(imported)
        #expect(merged.macros.first?.isSensitive == true)

        // Legacy JSON without "isSensitive" decodes as false.
        let legacyJSON = """
            {"version": 6,
             "macros": [{"id": "11111111-2222-3333-4444-555555555555", "name": "Copy", "speed": "normal",
                         "actions": [{"type": "text", "text": "hello"}]}],
             "pages": []}
            """
        let legacyDecoded = try MacroLibrary(data: Data(legacyJSON.utf8))
        #expect(legacyDecoded.macros.first?.isSensitive == false)
    }
}
