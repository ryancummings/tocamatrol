import XCTest

/// The screenshot catalog and UI regression tests: every screen, on each Snapfile device,
/// captured with fastlane's `snapshot()`. The app runs in `-UITestMode`.
final class ScreenshotCatalogUITests: XCTestCase {
    private static let quickPage = "0CA7E000-0000-4000-8000-000000000001"
    private static let devPage = "0CA7E000-0000-4000-8000-000000000002"
    private static let deckPage = "0CA7E000-0000-4000-8000-000000000003"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Macro pad

    @MainActor
    func testMacroPad() {
        let app = launch(page: Self.quickPage)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        capture("01_MacroPad")
    }

    @MainActor
    func testWorkspaceWideAndTallButtons() {
        let app = launch(page: Self.devPage)
        XCTAssertTrue(app.buttons["Open Terminal"].waitForExistence(timeout: 5))
        capture("02_WorkspacePage")
    }

    /// A full 7x4 page of small keys, for the App Store header art (creative_assets.py).
    @MainActor
    func testDenseDeck() {
        let app = launch(page: Self.deckPage, extraArguments: ["-UITestDenseDeck"])
        XCTAssertTrue(app.buttons["Switch App"].waitForExistence(timeout: 5))
        capture("11_DenseDeck")
    }

    @MainActor
    func testAssignMacro() {
        let app = launch(page: Self.quickPage)
        let empty = app.buttons["Empty button: choose a macro"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        XCTAssertTrue(app.navigationBars["Choose a Macro"].waitForExistence(timeout: 5))
        capture("03_AssignMacro")
    }

    // MARK: - Pages and macros

    @MainActor
    func testPagesAndMacros() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        capture("04_PagesAndMacros")
    }

    /// Touch and hold a macro, Duplicate…, and name the copy.
    @MainActor
    func testDuplicateMacro() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        app.staticTexts["Open Terminal"].firstMatch.press(forDuration: 1)
        app.buttons["Duplicate…"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Open Terminal copy")
        capture("04b_DuplicateMacro")
        field.clearAndType("Open Terminal (Build)")
        app.alerts.buttons["confirmMacroName"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Open Terminal (Build)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open Terminal"].exists)
    }

    @MainActor
    func testPageEditor() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        app.staticTexts["Quick Actions"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Quick Actions"].waitForExistence(timeout: 5))
        capture("05_PageEditor")
    }

    /// A button's size steppers, colour, typeface and caption, set in the page editor.
    @MainActor
    func testPageButtonLook() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        app.staticTexts["Quick Actions"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Quick Actions"].waitForExistence(timeout: 5))
        let editor = app.scrollViews["pageEditorScroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.buttons["Save & Build"].firstMatch.tap()
        let caption = app.textFields["caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertTrue(caption.isHittable)
        capture("05c_PageButtonLook")
    }

    /// Press and hold a button in the page editor, drag it onto an empty cell, and it moves there.
    @MainActor
    func testDragMovesAButton() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        app.staticTexts["Quick Actions"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Quick Actions"].waitForExistence(timeout: 5))
        let editor = app.scrollViews["pageEditorScroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let button = editor.buttons["Toggle Comment"].firstMatch
        let empty = editor.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Empty cell'")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(empty.exists)
        let target = empty.frame
        button.press(forDuration: 0.6, thenDragTo: empty)
        let moved = editor.buttons["Toggle Comment"].firstMatch
        XCTAssertTrue(moved.waitForExistence(timeout: 2))
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, abs(moved.frame.midX - target.midX) > 4 || abs(moved.frame.midY - target.midY) > 4 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(moved.frame.midX, target.midX, accuracy: 4)
        XCTAssertEqual(moved.frame.midY, target.midY, accuracy: 4)
        capture("05b_PageEditorMoved")
    }

    @MainActor
    func testResizeGridAndButton() {
        let app = launch(page: Self.quickPage)
        app.buttons["Pages and macros"].tap()
        XCTAssertTrue(app.navigationBars["Quick Actions"].waitForExistence(timeout: 5))
        let editor = app.scrollViews["pageEditorScroll"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.buttons["Increase Cols"].tap()
        editor.buttons["Save & Build"].firstMatch.tap()
        sleep(1)
        let growWidth = editor.buttons["Increase button width"]
        XCTAssertTrue(growWidth.waitForExistence(timeout: 5))
        growWidth.tap()
        XCTAssertTrue(editor.staticTexts["3 × 1"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openMacroEditor(_ app: XCUIApplication) {
        openPagesAndMacros(app)
        app.staticTexts["Open Terminal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Open Terminal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMacroEditor() {
        let app = launch(page: Self.quickPage)
        openMacroEditor(app)
        capture("06_MacroEditor")
    }

    @MainActor
    func testSetSeveralPauses() {
        let app = launch(page: Self.quickPage)
        openMacroEditor(app)
        app.buttons["selectPauses"].tap()
        app.buttons["selectAllPauses"].tap()
        capture("07_SelectPauses")
        app.buttons["setPauses"].tap()
        XCTAssertTrue(app.navigationBars["3 Pauses"].waitForExistence(timeout: 5))
        capture("07b_SetPauses")
    }

    @MainActor
    func testShortcutStep() {
        let app = launch(page: Self.quickPage)
        openMacroEditor(app)
        app.buttons["step-0"].tap()
        XCTAssertTrue(app.navigationBars["Shortcut"].waitForExistence(timeout: 5))
        capture("07c_ShortcutStep")
    }

    @MainActor
    func testTextStep() {
        let app = launch(page: Self.quickPage)
        openMacroEditor(app)
        app.buttons["step-2"].tap()
        XCTAssertTrue(app.navigationBars["Text"].waitForExistence(timeout: 5))
        capture("07d_TextStep")
    }

    // MARK: - Connection, settings, trackpad

    @MainActor
    func testConnections() {
        let app = launch(page: Self.quickPage)
        let badge = app.buttons["connection"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        badge.tap()
        XCTAssertTrue(app.navigationBars["Dongle"].waitForExistence(timeout: 5))
        capture("08_Connections")
    }

    @MainActor
    func testSettings() {
        let app = launch(page: Self.quickPage)
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("09_Settings")
    }

    @MainActor
    func testTrackpad() {
        launch(page: Self.quickPage, settings: ["inputMode": "trackpad"])
        capture("10_Trackpad")
    }

    // MARK: - Layout & privacy regressions

    @MainActor
    func testPadLayoutInvariants() {
        let app = launch(page: Self.quickPage)
        let quickTab = app.buttons["Quick Actions"].firstMatch
        XCTAssertTrue(quickTab.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(quickTab.frame.minX, 0, "First page tab should not clip off the left edge")
        XCTAssertTrue(quickTab.isHittable)

        let addPage = app.buttons["addPageButton"].firstMatch
        XCTAssertTrue(addPage.waitForExistence(timeout: 5))
        XCTAssertTrue(addPage.isHittable)
        XCTAssertGreaterThanOrEqual(addPage.frame.minX, quickTab.frame.maxX - 1)

        let readout = app.descendants(matching: .any).matching(identifier: "readoutPanel").firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        let screenshot = app.buttons["Screenshot"].firstMatch
        let comment = app.buttons["Toggle Comment"].firstMatch
        XCTAssertTrue(screenshot.waitForExistence(timeout: 5))
        XCTAssertTrue(comment.exists)
        XCTAssertLessThanOrEqual(screenshot.frame.maxY, readout.frame.minY + 0.5)
        XCTAssertLessThanOrEqual(comment.frame.maxY, readout.frame.minY + 0.5)
    }

    @MainActor
    func testSensitiveMacroMasksReadout() {
        let app = launch(page: Self.quickPage)
        openPagesAndMacros(app)
        app.staticTexts["Open Terminal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Open Terminal"].waitForExistence(timeout: 5))

        let toggle = app.switches["sensitiveMacroToggle"].firstMatch
        for _ in 0..<6 where !toggle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        if (toggle.value as? String) != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["Save"].tap()

        let navBar = app.navigationBars["Pages & Macros"]
        let done = navBar.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        let copyButton = app.buttons["Copy"].firstMatch
        let sheetGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: navBar)
        let padReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true && hittable == true"), object: copyButton)
        XCTAssertEqual(XCTWaiter.wait(for: [sheetGone, padReady], timeout: 5), .completed)

        let workspace = app.buttons["Workspace"].firstMatch
        XCTAssertTrue(workspace.waitForExistence(timeout: 5))
        workspace.tap()

        let terminal = app.buttons["Open Terminal"].firstMatch
        XCTAssertTrue(terminal.waitForExistence(timeout: 5))
        terminal.tap()

        let readout = app.descendants(matching: .any).matching(identifier: "readoutPanel").firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline && !readout.label.contains("*********") {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(readout.label.contains("*********"), "Expected masked output in readout, got: \(readout.label)")
        XCTAssertFalse(readout.label.contains("Typed text"))
        XCTAssertFalse(readout.label.contains("terminal"))
        XCTAssertFalse(readout.label.contains("git status"))
    }

    // MARK: - Helpers

    @MainActor @discardableResult
    private func launch(page: String, settings: [String: String] = [:],
                        extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-UITestMode", "-UITestResetState"] + extraArguments
        let defaults = ["macroPage": page, "inputMode": "keys"].merging(settings) { $1 }
        for (key, value) in defaults.sorted(by: { $0.key < $1.key }) {
            app.launchArguments += ["-UITestDefault:\(key)", value]
        }
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func openPagesAndMacros(_ app: XCUIApplication) {
        app.buttons["Pages and macros"].tap()
        let back = app.navigationBars.buttons["Pages & Macros"]
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
        XCTAssertTrue(app.navigationBars["Pages & Macros"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String) {
        snapshot(name, timeWaitingForIdle: 2)
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        let current = value as? String ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
