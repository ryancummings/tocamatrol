import Foundation
import TocaCore

/// The saved macros and pages, kept in Application Support/macros.json and written after every
/// change. On first launch, seeds an editable starter page.
final class MacroStore: ObservableObject {
    @Published var library: MacroLibrary {
        didSet { save() }
    }

    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "macros.json")
    }

    init() {
        #if DEBUG
        if UITestSupport.isActive {
            library = UITestSupport.library
            return
        }
        #endif
        let exists = FileManager.default.fileExists(atPath: Self.url.path)
        if !exists {
            let starter = MacroLibrary.starter(for: .deviceDefault)
            library = starter
            save()
            return
        }
        let data = try? Data(contentsOf: Self.url)
        if let data, let decoded = try? MacroLibrary(data: data) {
            library = decoded
        } else {
            // A file there but unreadable (the device locked, or a newer format) is never written
            // over with an empty library.
            library = MacroLibrary()
            readOnly = true
        }
    }

    private var readOnly = false

    func macro(_ id: UUID) -> Macro? {
        library.macros.first { $0.id == id }
    }

    /// Adds a new macro or replaces the one with the same ID.
    func save(_ macro: Macro) {
        if let index = library.macros.firstIndex(where: { $0.id == macro.id }) {
            library.macros[index] = macro
        } else {
            library.macros.append(macro)
        }
    }

    func assign(_ macroID: UUID?, to cell: Cell, on pageID: UUID) {
        guard let p = library.pages.firstIndex(where: { $0.id == pageID }) else { return }
        library.pages[p].assign(macroID, at: cell)
    }

    func resize(_ cell: Cell, to span: ButtonSpan, on pageID: UUID) {
        guard let p = library.pages.firstIndex(where: { $0.id == pageID }) else { return }
        library.pages[p].resize(at: cell, to: span)
    }

    @discardableResult
    func setGridShape(_ shape: GridShape, on pageID: UUID) -> Bool {
        guard let p = library.pages.firstIndex(where: { $0.id == pageID }) else { return false }
        return library.pages[p].resizeGrid(to: shape)
    }

    func setAppearance(_ appearance: ButtonAppearance, at cell: Cell, on pageID: UUID) {
        guard let p = library.pages.firstIndex(where: { $0.id == pageID }) else { return }
        library.pages[p].setAppearance(appearance, at: cell)
    }

    /// Moves the button covering `cell` so its top left is `origin`; false if it cannot go there.
    @discardableResult
    func move(_ cell: Cell, to origin: Cell, on pageID: UUID) -> Bool {
        guard let p = library.pages.firstIndex(where: { $0.id == pageID }) else { return false }
        return library.pages[p].move(from: cell, to: origin)
    }

    func exportData() throws -> Data {
        try library.exportJSON()
    }

    func importLibrary(from url: URL) throws -> (macros: Int, pages: Int) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let incoming = try MacroLibrary.importJSON(data)
        return library.merge(incoming)
    }

    /// "Macro 3": the first number not already used.
    var nextMacroName: String {
        let names = Set(library.macros.map(\.name))
        return (1...).lazy.map { "Macro \($0)" }.first { !names.contains($0) }!
    }

    var nextPageName: String {
        let names = Set(library.pages.map(\.title))
        return (1...).lazy.map { "Page \($0)" }.first { !names.contains($0) }!
    }

    private func save() {
        #if DEBUG
        // The demo library stays in memory.
        if UITestSupport.isActive { return }
        #endif
        guard !readOnly else { return }
        do {
            try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Unreadable while the device is locked: macros can hold passwords and private text.
            try library.encoded().write(to: Self.url, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("could not save macros: \(error)")
        }
    }
}

extension GridShape {
    /// Default page shape for a new page on this device.
    static var deviceDefault: GridShape { ScreenMetrics.isPad ? .padDefault : .phoneDefault }
}
