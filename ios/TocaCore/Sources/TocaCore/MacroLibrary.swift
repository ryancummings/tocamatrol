import Foundation

/// A macro: its name, how fast it plays, and its steps. How its buttons look belongs to each
/// button (`MacroButton.appearance`).
public struct Macro: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var speed: MacroSpeed
    public var actions: [MacroAction]

    public init(id: UUID = UUID(), name: String, speed: MacroSpeed = .normal, actions: [MacroAction]) {
        self.id = id
        self.name = name
        self.speed = speed
        self.actions = actions
    }

    /// A macro from recorded key changes, put as steps where they allow it.
    public init(id: UUID = UUID(), name: String, speed: MacroSpeed = .normal, steps: [MacroStep]) {
        self.init(id: id, name: name, speed: speed, actions: MacroAction.actions(from: steps))
    }

    /// The key changes it plays.
    public var steps: [MacroStep] { MacroAction.steps(for: actions) }
}

/// A cell of a page's grid, counted from the top left.
public struct Cell: Hashable, Sendable {
    public var column: Int
    public var row: Int

    public init(_ column: Int, _ row: Int) {
        self.column = column
        self.row = row
    }
}

/// How many columns and rows a button covers on a page's grid.
public struct ButtonSpan: Hashable, Sendable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int = 1, rows: Int = 1) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    public static let small = ButtonSpan(columns: 1, rows: 1)
    public static let wide = ButtonSpan(columns: 2, rows: 1)
    public static let tall = ButtonSpan(columns: 1, rows: 2)
    public static let large = ButtonSpan(columns: 2, rows: 2)

    public static let commonPresets: [ButtonSpan] = [.small, .wide, .tall, .large]

    /// The span turned on its side: 2 × 1 becomes 1 × 2.
    public var transposed: ButtonSpan { ButtonSpan(columns: rows, rows: columns) }

    public var label: String { "\(columns) × \(rows)" }
}

extension ButtonSpan: Codable {
    private enum CodingKeys: String, CodingKey { case columns, rows }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let legacy = try? single.decode(String.self) {
            switch legacy {
            case "small": self.init(columns: 1, rows: 1)
            case "wide": self.init(columns: 2, rows: 1)
            case "tall": self.init(columns: 1, rows: 2)
            case "large": self.init(columns: 2, rows: 2)
            default:
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "unknown button size \(legacy)")
            }
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(columns: try container.decode(Int.self, forKey: .columns),
                  rows: try container.decode(Int.self, forKey: .rows))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
    }
}

/// A button on a page: the macro it plays, its top-left cell, its span, and how it looks.
public struct MacroButton: Hashable, Sendable {
    public var macro: UUID
    public var origin: Cell
    public var span: ButtonSpan
    public var appearance: ButtonAppearance

    public init(macro: UUID, origin: Cell, span: ButtonSpan = .small, appearance: ButtonAppearance = ButtonAppearance()) {
        self.macro = macro
        self.origin = origin
        self.span = span
        self.appearance = appearance
    }

    public var cells: [Cell] { Self.cells(from: origin, span) }

    public func covers(_ cell: Cell) -> Bool {
        (origin.column..<origin.column + span.columns).contains(cell.column)
            && (origin.row..<origin.row + span.rows).contains(cell.row)
    }

    static func cells(from origin: Cell, _ span: ButtonSpan) -> [Cell] {
        (0..<span.rows).flatMap { r in (0..<span.columns).map { Cell(origin.column + $0, origin.row + r) } }
    }
}

/// How many columns and rows a page has.
public struct GridShape: Hashable, Codable, Sendable {
    public static let minColumns = 2
    public static let maxColumns = 8
    public static let minRows = 2
    public static let maxRows = 6

    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = min(max(columns, Self.minColumns), Self.maxColumns)
        self.rows = min(max(rows, Self.minRows), Self.maxRows)
    }

    public static let landscape = GridShape(columns: 4, rows: 3)
    public static let portrait = GridShape(columns: 3, rows: 4)
    public static let phoneDefault = GridShape(columns: 3, rows: 4)
    public static let padDefault = GridShape(columns: 5, rows: 3)

    public var transposed: GridShape { GridShape(columns: rows, rows: columns) }

    /// Every cell, row by row.
    public var cells: [Cell] {
        (0..<rows).flatMap { r in (0..<columns).map { Cell($0, r) } }
    }

    public func contains(_ cell: Cell) -> Bool {
        (0..<columns).contains(cell.column) && (0..<rows).contains(cell.row)
    }
}

/// A macro pad page arranged by the user: a configurable grid of macro buttons, each
/// spanning one or more cells. Cells no button covers are empty sockets.
public struct MacroPage: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public private(set) var shape: GridShape
    /// No two buttons share a cell.
    public private(set) var buttons: [MacroButton] = []

    public init(id: UUID = UUID(), title: String, shape: GridShape = .landscape) {
        self.id = id
        self.title = title
        self.shape = shape
    }

    public var columns: Int { shape.columns }
    public var rows: Int { shape.rows }

    /// Every cell, row by row.
    public var cells: [Cell] { shape.cells }

    /// Whether the page's grid can change to `newShape` without clipping any existing button.
    public func canResizeGrid(to newShape: GridShape) -> Bool {
        buttons.allSatisfy { button in
            button.cells.allSatisfy(newShape.contains)
        }
    }

    /// Resizes the page's grid to `newShape` if every existing button fits inside it.
    @discardableResult
    public mutating func resizeGrid(to newShape: GridShape) -> Bool {
        guard canResizeGrid(to: newShape) else { return false }
        shape = newShape
        return true
    }

    /// The page turned on its side for the transposed shape.
    public func reshaped(to shape: GridShape) -> MacroPage {
        guard shape != self.shape, shape == self.shape.transposed else { return self }
        var page = self
        page.shape = shape
        page.buttons = buttons.map { button in
            MacroButton(macro: button.macro, origin: Cell(button.origin.row, button.origin.column),
                        span: button.span.transposed, appearance: button.appearance)
        }
        return page
    }

    /// The button covering `cell`, if any.
    public func button(at cell: Cell) -> MacroButton? {
        buttons.first { $0.covers(cell) }
    }

    /// Puts a macro on the button covering `cell`, or on a new 1 × 1 button there; nil removes
    /// the button.
    public mutating func assign(_ macro: UUID?, at cell: Cell) {
        guard shape.contains(cell) || macro == nil else { return }
        let index = buttons.firstIndex { $0.covers(cell) }
        switch (macro, index) {
        case let (macro?, index?): buttons[index].macro = macro
        case let (macro?, nil): buttons.append(MacroButton(macro: macro, origin: cell))
        case let (nil, index?): buttons.remove(at: index)
        case (nil, nil): break
        }
    }

    /// Sets how the button covering `cell` looks; no change for an empty cell.
    public mutating func setAppearance(_ appearance: ButtonAppearance, at cell: Cell) {
        guard let index = buttons.firstIndex(where: { $0.covers(cell) }) else { return }
        buttons[index].appearance = appearance
    }

    /// Whether the button covering `cell` can take `span`, growing right and down from its top
    /// left: it must stay on the grid and clear of other buttons.
    public func canResize(at cell: Cell, to span: ButtonSpan) -> Bool {
        guard let button = button(at: cell) else { return false }
        return MacroButton.cells(from: button.origin, span).allSatisfy { targetCell in
            shape.contains(targetCell) && buttons.allSatisfy { $0 == button || !$0.covers(targetCell) }
        }
    }

    /// Resizes the button covering `cell`; false, and no change, when `canResize` is false.
    @discardableResult
    public mutating func resize(at cell: Cell, to span: ButtonSpan) -> Bool {
        guard canResize(at: cell, to: span), let index = buttons.firstIndex(where: { $0.covers(cell) }) else {
            return false
        }
        buttons[index].span = span
        return true
    }

    /// Whether the button covering `cell` can move so that its top left is `origin`. It must
    /// stay on the grid, and land on empty cells, on cells it covers itself, or exactly on a
    /// button of the same span, which then takes its old place.
    public func canMove(from cell: Cell, to origin: Cell) -> Bool {
        guard let button = button(at: cell) else { return false }
        let target = MacroButton.cells(from: origin, button.span)
        guard target.allSatisfy(shape.contains) else { return false }
        let others = Set(target.compactMap { self.button(at: $0) }.filter { $0 != button })
        guard let other = others.first else { return true }
        return others.count == 1 && other.span == button.span && other.origin == origin
    }

    /// Moves the button covering `cell` to `origin`; false, and no change, when `canMove` is
    /// false.
    @discardableResult
    public mutating func move(from cell: Cell, to origin: Cell) -> Bool {
        guard canMove(from: cell, to: origin), let index = buttons.firstIndex(where: { $0.covers(cell) })
        else { return false }
        let from = buttons[index].origin
        if let other = buttons.firstIndex(where: { $0.origin == origin && $0 != buttons[index] }) {
            buttons[other].origin = from
        }
        buttons[index].origin = origin
        return true
    }

    mutating func removeButtons(playing macro: UUID) {
        buttons.removeAll { $0.macro == macro }
    }
}

/// Every macro and page, saved as one JSON file.
public struct MacroLibrary: Equatable, Codable, Sendable {
    /// 2 added button sizes; 3 added page shapes; 4 saved macros as steps with an appearance;
    /// 5 moved the appearance onto each button; 6 replaced fixed sizes with arbitrary spans.
    public static let version = 6

    public var macros: [Macro]
    public var pages: [MacroPage]

    public init(macros: [Macro] = [], pages: [MacroPage] = []) {
        self.macros = macros
        self.pages = pages
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Pretty-printed JSON suitable for backup or sharing between devices.
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func importJSON(_ data: Data) throws -> MacroLibrary {
        try MacroLibrary(data: data)
    }

    /// Merges another library into this one, minting fresh IDs so nothing collides.
    @discardableResult
    public mutating func merge(_ other: MacroLibrary) -> (macros: Int, pages: Int) {
        var idMap: [UUID: UUID] = [:]
        for var macro in other.macros {
            let newID = UUID()
            idMap[macro.id] = newID
            macro.id = newID
            macros.append(macro)
        }
        var addedPages = 0
        for page in other.pages {
            var copy = MacroPage(id: UUID(), title: page.title, shape: page.shape)
            for button in page.buttons {
                guard let mapped = idMap[button.macro] else { continue }
                copy.assign(mapped, at: button.origin)
                copy.resize(at: button.origin, to: button.span)
                copy.setAppearance(button.appearance, at: button.origin)
            }
            pages.append(copy)
            addedPages += 1
        }
        return (other.macros.count, addedPages)
    }

    /// An editable starter library created on first launch so new users can explore right away.
    public static func starter(for shape: GridShape) -> MacroLibrary {
        let copy = Macro(name: "Copy", speed: .instant, actions: [.shortcut(KeyChord(0x06, .leftControl))])
        let paste = Macro(name: "Paste", speed: .instant, actions: [.shortcut(KeyChord(0x19, .leftControl))])
        let cut = Macro(name: "Cut", speed: .instant, actions: [.shortcut(KeyChord(0x1B, .leftControl))])
        let undo = Macro(name: "Undo", speed: .instant, actions: [.shortcut(KeyChord(0x1D, .leftControl))])
        let redo = Macro(name: "Redo", speed: .instant,
                         actions: [.shortcut(KeyChord(0x1D, [.leftControl, .leftShift]))])
        let selectAll = Macro(name: "Select All", speed: .instant,
                              actions: [.shortcut(KeyChord(0x04, .leftControl))])
        let save = Macro(name: "Save", speed: .instant, actions: [.shortcut(KeyChord(0x16, .leftControl))])
        let find = Macro(name: "Find", speed: .instant, actions: [.shortcut(KeyChord(0x09, .leftControl))])
        let screenshot = Macro(name: "Screenshot", speed: .instant,
                               actions: [.shortcut(KeyChord(0x16, [.leftGUI, .leftShift]))])

        let macros = [copy, paste, cut, undo, redo, selectAll, save, find, screenshot]
        var page = MacroPage(title: "Quick Actions", shape: shape)

        func place(_ macro: Macro, at origin: Cell, span: ButtonSpan = .small, appearance: ButtonAppearance) {
            let cells = MacroButton.cells(from: origin, span)
            guard cells.allSatisfy(shape.contains) else { return }
            page.assign(macro.id, at: origin)
            page.resize(at: origin, to: span)
            page.setAppearance(appearance, at: origin)
        }

        if shape.columns >= 5 && shape.rows >= 3 {
            place(copy, at: Cell(0, 0), appearance: ButtonAppearance(tint: .blue, caption: "Ctrl+C"))
            place(paste, at: Cell(1, 0), appearance: ButtonAppearance(tint: .green, caption: "Ctrl+V"))
            place(cut, at: Cell(2, 0), appearance: ButtonAppearance(tint: .rust, caption: "Ctrl+X"))
            place(save, at: Cell(3, 0), span: ButtonSpan(columns: 2, rows: 1),
                  appearance: ButtonAppearance(tint: .teal, caption: "Ctrl+S"))

            place(undo, at: Cell(0, 1), appearance: ButtonAppearance(tint: .amber, caption: "Ctrl+Z"))
            place(redo, at: Cell(1, 1), appearance: ButtonAppearance(tint: .amber, caption: "Ctrl+Shift+Z"))
            place(selectAll, at: Cell(2, 1), appearance: ButtonAppearance(tint: .violet, caption: "Ctrl+A"))
            place(find, at: Cell(3, 1), span: ButtonSpan(columns: 2, rows: 1),
                  appearance: ButtonAppearance(tint: .sand, caption: "Ctrl+F"))

            place(screenshot, at: Cell(0, 2), span: ButtonSpan(columns: 3, rows: 1),
                  appearance: ButtonAppearance(tint: .graphite, caption: "Win+Shift+S"))
        } else {
            place(copy, at: Cell(0, 0), appearance: ButtonAppearance(tint: .blue, caption: "Ctrl+C"))
            place(paste, at: Cell(1, 0), appearance: ButtonAppearance(tint: .green, caption: "Ctrl+V"))
            place(cut, at: Cell(2, 0), appearance: ButtonAppearance(tint: .rust, caption: "Ctrl+X"))

            place(undo, at: Cell(0, 1), appearance: ButtonAppearance(tint: .amber, caption: "Ctrl+Z"))
            place(redo, at: Cell(1, 1), appearance: ButtonAppearance(tint: .amber, caption: "Ctrl+Shift+Z"))
            place(selectAll, at: Cell(2, 1), appearance: ButtonAppearance(tint: .violet, caption: "Ctrl+A"))

            place(save, at: Cell(0, 2), span: ButtonSpan(columns: shape.columns >= 3 ? 2 : 1, rows: 1),
                  appearance: ButtonAppearance(tint: .teal, caption: "Ctrl+S"))
            if shape.columns >= 3 {
                place(find, at: Cell(2, 2), appearance: ButtonAppearance(tint: .sand, caption: "Ctrl+F"))
            }
            if shape.rows >= 4 {
                place(screenshot, at: Cell(0, 3), span: ButtonSpan(columns: shape.columns, rows: 1),
                      appearance: ButtonAppearance(tint: .graphite, caption: "Win+Shift+S"))
            }
        }

        return MacroLibrary(macros: macros, pages: [page])
    }

    /// Every page in `shape`, turning over those saved in the other one.
    public func reshaped(to shape: GridShape) -> MacroLibrary {
        var library = self
        library.pages = pages.map { $0.reshaped(to: shape) }
        return library
    }

    /// The macro on the button covering `cell`, or nil for an empty cell or a deleted macro.
    public func macro(on page: MacroPage, at cell: Cell) -> Macro? {
        guard let id = page.button(at: cell)?.macro else { return nil }
        return macros.first { $0.id == id }
    }

    /// Adds a copy of the macro, with a new ID, just after it in the list. The copy is on no
    /// buttons. Returns nil when there is no such macro.
    @discardableResult
    public mutating func duplicateMacro(_ id: UUID, named name: String? = nil) -> Macro? {
        guard let index = macros.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = macros[index]
        copy.id = UUID()
        copy.name = name ?? copyName(for: copy.name)
        macros.insert(copy, at: index + 1)
        return copy
    }

    /// "Name copy", or "Name copy 2" and on when that is taken.
    public func copyName(for name: String) -> String {
        let names = Set(macros.map(\.name))
        let base = "\(name) copy"
        guard names.contains(base) else { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    /// Removes the macro and empties every button that played it.
    public mutating func deleteMacro(_ id: UUID) {
        macros.removeAll { $0.id == id }
        for p in pages.indices {
            pages[p].removeButtons(playing: id)
        }
    }

    private enum CodingKeys: String, CodingKey { case version, macros, pages }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        macros = try container.decode([Macro].self, forKey: .macros)
        pages = try container.decode([MacroPage].self, forKey: .pages)
        // Version 4 kept the look on the macro: its buttons take it.
        if try container.decodeIfPresent(Int.self, forKey: .version) == 4 {
            let looks = Dictionary(
                try container.decode([MacroLook].self, forKey: .macros).compactMap { look in look.appearance.map { (look.id, $0) } },
                uniquingKeysWith: { a, _ in a })
            for p in pages.indices {
                for b in pages[p].buttons.indices {
                    if let look = looks[pages[p].buttons[b].macro] { pages[p].setAppearance(look, at: pages[p].buttons[b].origin) }
                }
            }
        }
    }

    /// A version 4 macro's look.
    private struct MacroLook: Decodable {
        let id: UUID
        let appearance: ButtonAppearance?
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .version)
        try container.encode(macros, forKey: .macros)
        try container.encode(pages, forKey: .pages)
    }
}

/// Saved as {"action", "usage", "modifiers", "delay"}.
extension MacroStep: Codable {
    private enum CodingKeys: String, CodingKey { case action, usage, modifiers, delay }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            try container.decode(Action.self, forKey: .action),
            KeyChord(try container.decode(UInt8.self, forKey: .usage),
                     KeyModifiers(rawValue: try container.decode(UInt8.self, forKey: .modifiers))),
            after: try container.decode(Int.self, forKey: .delay))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(key.usage, forKey: .usage)
        try container.encode(key.modifiers.rawValue, forKey: .modifiers)
        try container.encode(delay, forKey: .delay)
    }
}

extension MacroStep.Action: Codable {}

/// Saved as {"id", "name", "speed", "actions"}. Before version 4 a macro saved recorded "steps"
/// instead, which load as steps where they can. Version 4's "appearance" is read by the library.
extension Macro: Codable {
    private enum CodingKeys: String, CodingKey { case id, name, speed, actions, steps }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actions = try container.decodeIfPresent([MacroAction].self, forKey: .actions)
            ?? MacroAction.actions(from: try container.decode([MacroStep].self, forKey: .steps))
        self.init(id: try container.decode(UUID.self, forKey: .id),
                  name: try container.decode(String.self, forKey: .name),
                  speed: try container.decodeIfPresent(MacroSpeed.self, forKey: .speed) ?? .normal,
                  actions: actions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(speed, forKey: .speed)
        try container.encode(actions, forKey: .actions)
    }
}

/// Saved as {"macro", "column", "row", "span", "appearance"}; reads legacy "size" strings
/// from versions 2–5 and defaults missing "appearance" (before version 5).
extension MacroButton: Codable {
    private enum CodingKeys: String, CodingKey { case macro, column, row, span, size, appearance }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let span = try container.decodeIfPresent(ButtonSpan.self, forKey: .span)
            ?? (try container.decodeIfPresent(ButtonSpan.self, forKey: .size))
            ?? .small
        self.init(macro: try container.decode(UUID.self, forKey: .macro),
                  origin: Cell(try container.decode(Int.self, forKey: .column), try container.decode(Int.self, forKey: .row)),
                  span: span,
                  appearance: try container.decodeIfPresent(ButtonAppearance.self, forKey: .appearance) ?? ButtonAppearance())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(macro, forKey: .macro)
        try container.encode(origin.column, forKey: .column)
        try container.encode(origin.row, forKey: .row)
        try container.encode(span, forKey: .span)
        try container.encode(appearance, forKey: .appearance)
    }
}

/// Saved as {"id", "title", "shape", "buttons"}; a page without "shape" is 4 × 3. Version 1
/// saved "slots" instead: 12 macro IDs or nulls, row by row, each a small button.
extension MacroPage: Codable {
    private enum CodingKeys: String, CodingKey { case id, title, shape, buttons, slots }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        shape = try container.decodeIfPresent(GridShape.self, forKey: .shape) ?? .landscape
        if container.contains(.buttons) {
            buttons = try container.decode([MacroButton].self, forKey: .buttons)
        } else {
            let slots = try container.decode([UUID?].self, forKey: .slots)
            buttons = zip(GridShape.landscape.cells, slots).compactMap { cell, macro in
                macro.map { MacroButton(macro: $0, origin: cell) }
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(shape, forKey: .shape)
        try container.encode(buttons, forKey: .buttons)
    }
}
