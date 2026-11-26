import SwiftUI
import TocaCore

/// One page: its name, its grid dimensions, and its button layout scaled to fit. Tap a button
/// or empty cell to edit or resize it; hold and drag to move; drag the corner handle to resize.
struct PageEditorView: View {
    let pageID: UUID
    let onDone: () -> Void
    @EnvironmentObject private var store: MacroStore
    @State private var selection: Cell?
    @State private var creatingCell: CellID?
    @State private var dragging = false
    /// Where a drag just dropped a button: selected, but not scrolled to.
    @State private var droppedAt: Cell?

    var body: some View {
        if let index = store.library.pages.firstIndex(where: { $0.id == pageID }) {
            let page = store.library.pages[index]
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Name", text: $store.library.pages[index].title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .comicPanel(fill: Theme.surface, cornerRadius: 10, borderWidth: 2, shadowOffset: 2)
                    GridSizeBar(page: page) { newShape in
                        let changed = store.setGridShape(newShape, on: pageID)
                        if changed, let sel = selection, !newShape.contains(sel) {
                            selection = nil
                        }
                    }
                    HStack {
                        SectionLabel(text: "Buttons")
                        Spacer()
                        Text(countText(page))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                    }
                    EditorGrid(page: page, selection: $selection, dragging: $dragging, onMove: { from, to in
                        let moved = store.move(from, to: to, on: pageID)
                        if moved {
                            droppedAt = to
                            selection = to
                        }
                        return moved
                    }, onResize: { at, span in
                        guard page.canResize(at: at, to: span) else { return false }
                        store.resize(at, to: span, on: pageID)
                        return true
                    })
                    Text("Tap a button or empty cell to edit. Hold and drag to move; drag the bottom-right grip on a selected button to resize.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    if let selection {
                        Inspector(page: page, cell: selection, creatingCell: $creatingCell) { self.selection = nil }
                            .id("inspector")
                    }
                }
                .padding(Theme.margin)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(dragging)
            .accessibilityIdentifier("pageEditorScroll")
            .onChange(of: selection) { _, cell in
                guard let cell, cell != droppedAt else { return droppedAt = nil }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !dragging, selection == cell, droppedAt != cell else { return }
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("inspector", anchor: .top) }
                }
            }
            }
            .background {
                ZStack {
                    Theme.ground.ignoresSafeArea()
                    HalftoneBackground().ignoresSafeArea()
                }
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .sheet(item: $creatingCell) { cell in
                NavigationStack {
                    MacroEditorView(original: nil) { macro in
                        store.save(macro)
                        store.assign(macro.id, to: cell.cell, on: pageID)
                    }
                }
                .tint(Theme.tint)
            }
        } else {
            ContentUnavailableView("Page deleted", systemImage: "square.grid.3x3")
        }
    }

    private func countText(_ page: MacroPage) -> String {
        let free = page.cells.filter { page.button(at: $0) == nil }.count
        return "\(page.buttons.count) BUTTON\(page.buttons.count == 1 ? "" : "S") · \(free) FREE"
    }
}

/// Grid columns and rows controls plus quick density presets.
private struct GridSizeBar: View {
    let page: MacroPage
    let onChange: (GridShape) -> Void

    private static var presets: [GridShape] {
        ScreenMetrics.isPad
            ? [GridShape(columns: 4, rows: 3), GridShape(columns: 5, rows: 3), GridShape(columns: 6, rows: 4), GridShape(columns: 8, rows: 4)]
            : [GridShape(columns: 2, rows: 3), GridShape(columns: 3, rows: 4), GridShape(columns: 4, rows: 5), GridShape(columns: 4, rows: 6)]
    }

    var body: some View {
        let shrinkBlocked = !page.canResizeGrid(to: GridShape(columns: max(GridShape.minColumns, page.columns - 1), rows: page.rows))
            || !page.canResizeGrid(to: GridShape(columns: page.columns, rows: max(GridShape.minRows, page.rows - 1)))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Grid")
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Self.presets, id: \.self) { preset in
                            let active = page.shape == preset
                            let allowed = page.canResizeGrid(to: preset)
                            Button("\(preset.columns)×\(preset.rows)") { onChange(preset) }
                                .buttonStyle(ConsoleTileButtonStyle(size: 28, active: active))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .disabled(!allowed)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                axisStepper(title: "Cols", value: page.columns, range: GridShape.minColumns...GridShape.maxColumns) { next in
                    onChange(GridShape(columns: next, rows: page.rows))
                } canStep: { next in
                    page.canResizeGrid(to: GridShape(columns: next, rows: page.rows))
                }
                axisStepper(title: "Rows", value: page.rows, range: GridShape.minRows...GridShape.maxRows) { next in
                    onChange(GridShape(columns: page.columns, rows: next))
                } canStep: { next in
                    page.canResizeGrid(to: GridShape(columns: page.columns, rows: next))
                }
            }
            if shrinkBlocked {
                Text("Move or shrink edge buttons before making the grid smaller.")
                    .font(.caption)
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(12)
        .comicPanel(fill: Theme.surface, cornerRadius: 12, borderWidth: 2, shadowOffset: 3)
    }

    private func axisStepper(title: String, value: Int, range: ClosedRange<Int>,
                             set: @escaping (Int) -> Void, canStep: @escaping (Int) -> Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 2)
            Button {
                set(value - 1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(ConsoleTileButtonStyle(size: 30))
            .disabled(value <= range.lowerBound || !canStep(value - 1))
            .accessibilityLabel("Decrease \(title)")

            Text("\(value)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.highlightLabel)
                .frame(minWidth: 20)

            Button {
                set(value + 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(ConsoleTileButtonStyle(size: 30))
            .disabled(value >= range.upperBound || !canStep(value + 1))
            .accessibilityLabel("Increase \(title)")
        }
        .frame(maxWidth: .infinity)
    }
}

/// The page editor's grid: the pad's grid at the pad's proportions, scaled down to fit.
private struct EditorGrid: View {
    let page: MacroPage
    @Binding var selection: Cell?
    @Binding var dragging: Bool
    let onMove: (Cell, Cell) -> Bool
    let onResize: (Cell, ButtonSpan) -> Bool

    @EnvironmentObject private var store: MacroStore
    @State private var drag: Drag?
    @State private var resizeDrag: ResizeDrag?
    @State private var lifts = 0
    @State private var drops = 0
    @State private var refusals = 0

    private struct Drag: Equatable {
        let origin: Cell
        var translation: CGSize
    }

    private struct ResizeDrag: Equatable {
        let origin: Cell
        var translation: CGSize
    }

    private static let maxHeightShare: CGFloat = 0.5

    var body: some View {
        let pad = PadShape.size(for: page.shape)
        GeometryReader { geometry in
            let scale = min(geometry.size.width / pad.width, 1)
            let spacing = Theme.padSpacing * scale
            let cell = CGSize(width: (pad.width * scale - spacing * CGFloat(page.columns - 1)) / CGFloat(page.columns),
                              height: (pad.height * scale - spacing * CGFloat(page.rows - 1)) / CGFloat(page.rows))
            let step = CGSize(width: cell.width + spacing, height: cell.height + spacing)
            ZStack(alignment: .topLeading) {
                ForEach(page.cells, id: \.self) { c in
                    let empty = page.button(at: c) == nil
                    Socket(addable: empty)
                        .overlay { selectionRing(selection == c && empty) }
                        .frame(width: cell.width, height: cell.height)
                        .offset(x: CGFloat(c.column) * step.width, y: CGFloat(c.row) * step.height)
                        .onTapGesture { if empty { selection = c } }
                        .accessibilityLabel("Empty cell, column \(c.column + 1), row \(c.row + 1)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHidden(!empty)
                }
                if let drag, let button = page.button(at: drag.origin) {
                    let target = target(for: button, drag: drag, step: step)
                    let ok = page.canMove(from: button.origin, to: target)
                    footprintPreview(origin: target, span: button.span, valid: ok, cell: cell, spacing: spacing, step: step)
                }
                if let resizeDrag, let button = page.button(at: resizeDrag.origin) {
                    let span = targetSpan(for: button, resize: resizeDrag, step: step)
                    let ok = page.canResize(at: button.origin, to: span)
                    footprintPreview(origin: button.origin, span: span, valid: ok, cell: cell, spacing: spacing, step: step)
                        .overlay(alignment: .bottomTrailing) {
                            Text(span.label)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(ok ? Theme.popYellow : Theme.red, in: Capsule())
                                .overlay { Capsule().strokeBorder(Theme.popInk, lineWidth: 1.5) }
                                .foregroundStyle(ok ? Theme.popInk : .white)
                                .offset(x: CGFloat(button.origin.column) * step.width + spanLength(span.columns, cell.width, spacing) - 4,
                                        y: CGFloat(button.origin.row) * step.height + spanLength(span.rows, cell.height, spacing) - 4)
                        }
                }
                ForEach(page.buttons, id: \.origin) { button in
                    buttonView(button, scale: scale, cell: cell, spacing: spacing, step: step)
                }
            }
            .coordinateSpace(.named("editorGrid"))
        }
        .aspectRatio(pad.width / pad.height, contentMode: .fit)
        .frame(maxHeight: UIScreen.main.bounds.height * Self.maxHeightShare)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: lifts)
        .sensoryFeedback(.success, trigger: drops)
        .sensoryFeedback(.error, trigger: refusals)
        .onChange(of: drag == nil && resizeDrag == nil) { _, idle in dragging = !idle }
    }

    private func footprintPreview(origin: Cell, span: ButtonSpan, valid: Bool,
                                  cell: CGSize, spacing: CGFloat, step: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill((valid ? Theme.tint : Theme.red).opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(valid ? Theme.tint : Theme.red, lineWidth: 2.5)
            }
            .frame(width: spanLength(span.columns, cell.width, spacing),
                   height: spanLength(span.rows, cell.height, spacing))
            .offset(x: CGFloat(origin.column) * step.width, y: CGFloat(origin.row) * step.height)
            .allowsHitTesting(false)
    }

    private func buttonView(_ button: MacroButton, scale: CGFloat, cell: CGSize, spacing: CGFloat,
                            step: CGSize) -> some View {
        let full = CGSize(width: spanLength(button.span.columns, cell.width, spacing),
                          height: spanLength(button.span.rows, cell.height, spacing))
        let lifted = drag?.origin == button.origin
        let selected = selection == button.origin && !lifted
        let macro = store.library.macro(on: page, at: button.origin)
        let title = macro?.name ?? "Deleted"
        return MacroCap(title: title, appearance: button.appearance, span: button.span, lit: lifted)
            .frame(width: full.width / scale, height: full.height / scale)
            .scaleEffect(scale)
            .frame(width: full.width, height: full.height)
            .overlay { selectionRing(selected) }
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    resizeGrip(button, step: step)
                }
            }
            .scaleEffect(lifted ? 1.06 : 1)
            .rotationEffect(.degrees(lifted ? -2 : 0))
            .shadow(color: .black.opacity(lifted ? 0.45 : 0), radius: lifted ? 14 : 0, y: lifted ? 9 : 0)
            .offset(x: CGFloat(button.origin.column) * step.width + (lifted ? drag!.translation.width : 0),
                    y: CGFloat(button.origin.row) * step.height + (lifted ? drag!.translation.height : 0))
            .zIndex(lifted || resizeDrag?.origin == button.origin ? 2 : selected ? 1 : 0)
            .animation(.spring(duration: 0.25), value: lifted)
            .onTapGesture { selection = button.origin }
            .gesture(moveGesture(button, step: step))
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityValue(button.span.label)
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                ForEach(Direction.allCases, id: \.self) { direction in
                    Button("Move \(direction.rawValue)") { _ = onMove(button.origin, direction.step(button.origin)) }
                }
            }
    }

    private func resizeGrip(_ button: MacroButton, step: CGSize) -> some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(Theme.popInk)
            .frame(width: 24, height: 24)
            .background(Theme.popYellow, in: Circle())
            .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 2) }
            .background { Circle().fill(Theme.inkShadow).offset(x: 2, y: 2) }
            .padding(4)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("editorGrid"))
                    .onChanged { value in
                        if resizeDrag == nil { lifts += 1 }
                        resizeDrag = ResizeDrag(origin: button.origin, translation: value.translation)
                    }
                    .onEnded { value in
                        defer { resizeDrag = nil }
                        let span = targetSpan(for: button, resize: ResizeDrag(origin: button.origin, translation: value.translation), step: step)
                        guard span != button.span else { return }
                        withAnimation(.spring(duration: 0.25)) {
                            if onResize(button.origin, span) { drops += 1 } else { refusals += 1 }
                        }
                    }
            )
            .accessibilityLabel("Resize \(button.span.label)")
    }

    private func moveGesture(_ button: MacroButton, step: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("editorGrid")))
            .onChanged { value in
                guard case let .second(true, moved) = value else { return }
                if drag == nil {
                    lifts += 1
                    selection = button.origin
                }
                drag = Drag(origin: button.origin, translation: moved?.translation ?? .zero)
            }
            .onEnded { value in
                defer { drag = nil }
                guard case let .second(true, moved?) = value, let drag else { return }
                let target = target(for: button, drag: Drag(origin: drag.origin, translation: moved.translation), step: step)
                guard target != button.origin else { return }
                withAnimation(.spring(duration: 0.3)) {
                    if onMove(button.origin, target) { drops += 1 } else { refusals += 1 }
                }
            }
    }

    private func target(for button: MacroButton, drag: Drag, step: CGSize) -> Cell {
        let column = (CGFloat(button.origin.column) + drag.translation.width / step.width).rounded()
        let row = (CGFloat(button.origin.row) + drag.translation.height / step.height).rounded()
        return Cell(min(max(Int(column), 0), page.columns - button.span.columns),
                    min(max(Int(row), 0), page.rows - button.span.rows))
    }

    private func targetSpan(for button: MacroButton, resize: ResizeDrag, step: CGSize) -> ButtonSpan {
        let maxCols = page.columns - button.origin.column
        let maxRows = page.rows - button.origin.row
        let cols = (CGFloat(button.span.columns) + resize.translation.width / step.width).rounded()
        let rows = (CGFloat(button.span.rows) + resize.translation.height / step.height).rounded()
        return ButtonSpan(columns: min(max(Int(cols), 1), maxCols),
                          rows: min(max(Int(rows), 1), maxRows))
    }

    private func spanLength(_ count: Int, _ length: CGFloat, _ spacing: CGFloat) -> CGFloat {
        length * CGFloat(count) + spacing * CGFloat(count - 1)
    }

    @ViewBuilder private func selectionRing(_ on: Bool) -> some View {
        if on {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.tint, lineWidth: 3.5)
                .padding(-3.5)
                .allowsHitTesting(false)
        }
    }

    private enum Direction: String, CaseIterable {
        case left, right, up, down

        func step(_ cell: Cell) -> Cell {
            switch self {
            case .left: Cell(cell.column - 1, cell.row)
            case .right: Cell(cell.column + 1, cell.row)
            case .up: Cell(cell.column, cell.row - 1)
            case .down: Cell(cell.column, cell.row + 1)
            }
        }
    }
}

/// Below the editor's grid: the selected button's macro, span, look, and removal, or for an
/// empty cell, a macro to put there.
private struct Inspector: View {
    let page: MacroPage
    let cell: Cell
    @Binding var creatingCell: CellID?
    let onDeselect: () -> Void
    @EnvironmentObject private var store: MacroStore

    var body: some View {
        let button = page.button(at: cell)
        let macro = store.library.macro(on: page, at: cell)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if macro?.isSensitive == true {
                            Image(systemName: "lock.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                        Text(button == nil ? "Empty cell" : macro?.name ?? "Deleted macro")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.text)
                    }
                    Text(button == nil ? "No button here yet." : macro.map { MacroDescription.summary(for: $0) } ?? "")
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Menu {
                    Picker("Macro", selection: Binding(
                        get: { button?.macro }, set: { store.assign($0, to: cell, on: page.id) })
                    ) {
                        ForEach(store.library.macros) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    Button {
                        creatingCell = CellID(cell: cell)
                    } label: {
                        Label("New Macro…", systemImage: "plus")
                    }
                } label: {
                    Text(button == nil ? "Choose Macro" : "Change")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(ConsoleTileButtonStyle(active: true))
            }
            if let button {
                HStack {
                    SectionLabel(text: "Size")
                    Spacer()
                    Text(button.span.label)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Theme.highlightLabel)
                }
                HStack(spacing: 8) {
                    ForEach(ButtonSpan.commonPresets, id: \.self) { preset in
                        let active = button.span == preset
                        let allowed = active || page.canResize(at: cell, to: preset)
                        Button {
                            store.resize(cell, to: preset, on: page.id)
                        } label: {
                            VStack(spacing: 4) {
                                SpanGlyph(span: preset)
                                Text(preset.label).font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ConsoleTileButtonStyle(size: 50, active: active))
                        .disabled(!allowed)
                    }
                }
                HStack(spacing: 12) {
                    spanStepper(label: "Width", value: button.span.columns,
                                minusEnabled: button.span.columns > 1,
                                plusEnabled: page.canResize(at: cell, to: ButtonSpan(columns: button.span.columns + 1, rows: button.span.rows))) { delta in
                        store.resize(cell, to: ButtonSpan(columns: button.span.columns + delta, rows: button.span.rows), on: page.id)
                    }
                    spanStepper(label: "Height", value: button.span.rows,
                                minusEnabled: button.span.rows > 1,
                                plusEnabled: page.canResize(at: cell, to: ButtonSpan(columns: button.span.columns, rows: button.span.rows + 1))) { delta in
                        store.resize(cell, to: ButtonSpan(columns: button.span.columns, rows: button.span.rows + delta), on: page.id)
                    }
                }
                HStack(alignment: .bottom) {
                    SectionLabel(text: "Look")
                    Spacer()
                    MacroCap(title: macro?.name ?? "Deleted", appearance: button.appearance, span: .small)
                        .frame(width: ScreenMetrics.isPad ? 150 : 110, height: ScreenMetrics.isPad ? 90 : 76)
                        .accessibilityHidden(true)
                }
                ButtonLookControls(appearance: Binding(
                    get: { button.appearance }, set: { store.setAppearance($0, at: cell, on: page.id) }))
                Button(role: .destructive) {
                    store.assign(nil, to: cell, on: page.id)
                    onDeselect()
                } label: {
                    Label("Remove from Page", systemImage: "minus.circle")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Theme.red)
                        .background(Theme.red.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                                .strokeBorder(Theme.red, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .comicPanel(fill: Theme.surface, cornerRadius: 12, borderWidth: 2, shadowOffset: 3)
    }

    private func spanStepper(label: String, value: Int, minusEnabled: Bool, plusEnabled: Bool,
                             adjust: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Button { adjust(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(ConsoleTileButtonStyle(size: 30))
                .disabled(!minusEnabled)
                .accessibilityLabel("Decrease button \(label.lowercased())")
            Text("\(value)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.highlightLabel)
                .frame(minWidth: 16)
            Button { adjust(1) } label: { Image(systemName: "plus") }
                .buttonStyle(ConsoleTileButtonStyle(size: 30))
                .disabled(!plusEnabled)
                .accessibilityLabel("Increase button \(label.lowercased())")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.well, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.inkBorder, lineWidth: 1.5)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A button span drawn as filled cells of a 2 × 2 square.
private struct SpanGlyph: View {
    let span: ButtonSpan

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<2, id: \.self) { r in
                GridRow {
                    ForEach(0..<2, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(c < span.columns && r < span.rows ? AnyShapeStyle(.foreground) : AnyShapeStyle(.foreground.opacity(0.2)))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
    }
}
