import SwiftUI
import TocaCore

/// Pages and macros: add, rename, reorder and delete pages, configure grids, lay out and
/// resize buttons, and record, edit and delete macros.
struct MacrosView: View {
    /// Where the sheet opens: the list, or straight on one page's editor.
    enum Start: Identifiable, Hashable {
        case list
        case page(UUID)

        var id: Self { self }
    }

    var start: Start = .list
    @EnvironmentObject private var store: MacroStore
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []
    @State private var editMode = EditMode.inactive
    /// The macro being copied or renamed, and the name being typed for it.
    @State private var naming: Naming?
    @State private var draftName = ""

    struct Naming {
        let macro: UUID
        let copying: Bool
    }

    enum Route: Hashable {
        case page(UUID)
        case macro(UUID)
        case newMacro
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(store.library.pages) { page in
                        NavigationLink(value: Route.page(page.id)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title).foregroundStyle(Theme.text)
                                    Text("\(page.columns) × \(page.rows) grid")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Theme.dim)
                                }
                                Spacer()
                                Text(page.buttons.count == 1 ? "1 BUTTON" : "\(page.buttons.count) BUTTONS")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(Theme.dim)
                            }
                        }
                    }
                    .onDelete { store.library.pages.remove(atOffsets: $0) }
                    .onMove { store.library.pages.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        let page = MacroPage(title: store.nextPageName, shape: .deviceDefault)
                        store.library.pages.append(page)
                        path.append(.page(page.id))
                    } label: {
                        Label("Add Page", systemImage: "plus")
                    }
                } header: {
                    SectionLabel(text: "Pages")
                } footer: {
                    Text("Drag to reorder pages or swipe to delete.")
                        .foregroundStyle(Theme.dim)
                }
                .consoleRows()

                Section {
                    ForEach(store.library.macros) { macro in
                        NavigationLink(value: Route.macro(macro.id)) {
                            MacroRow(macro: macro)
                        }
                        .contextMenu {
                            Button { name(macro, copying: true) } label: {
                                Label("Duplicate…", systemImage: "plus.square.on.square")
                            }
                            Button { name(macro, copying: false) } label: {
                                Label("Rename…", systemImage: "pencil")
                            }
                            Button(role: .destructive) { store.library.deleteMacro(macro.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { name(macro, copying: true) } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(Theme.tint)
                        }
                    }
                    .onDelete { offsets in
                        for id in offsets.map({ store.library.macros[$0].id }) { store.library.deleteMacro(id) }
                    }
                    Button {
                        path.append(.newMacro)
                    } label: {
                        Label("New Macro", systemImage: "plus")
                    }
                    .accessibilityIdentifier("newMacro")
                } header: {
                    SectionLabel(text: "Macros")
                } footer: {
                    Text("Touch and hold a macro to duplicate or rename it. Deleting a macro empties every button it is on.")
                        .foregroundStyle(Theme.dim)
                }
                .consoleRows()
            }
            .consoleForm()
            .environment(\.editMode, $editMode)
            .navigationTitle("Pages & Macros")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .page(id): PageEditorView(pageID: id) { dismiss() }
                case let .macro(id):
                    if let macro = store.macro(id) {
                        MacroEditorView(original: macro, onSave: { store.save($0) },
                                        onDelete: { store.library.deleteMacro(id) })
                    } else {
                        ContentUnavailableView("Macro deleted", systemImage: "keyboard")
                    }
                case .newMacro:
                    MacroEditorView(original: nil, onSave: { store.save($0) })
                }
            }
            .toolbar {
                if editMode.isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { withAnimation { editMode = .inactive } }
                            .accessibilityIdentifier("endEditing")
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Edit") { withAnimation { editMode = .active } }
                            .accessibilityIdentifier("editList")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { path.append(.newMacro) } label: { Image(systemName: "plus") }
                            .accessibilityLabel("New Macro")
                            .accessibilityIdentifier("newMacroToolbar")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .tint(Theme.tint)
        .alert(naming?.copying == true ? "Duplicate Macro" : "Rename Macro",
               isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } }),
               presenting: naming) { naming in
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button(naming.copying ? "Duplicate" : "Rename") { finishNaming(naming) }
                .accessibilityIdentifier("confirmMacroName")
        } message: { naming in
            Text(naming.copying ? "The copy starts on no buttons." : "Buttons show the new name unless they have their own caption.")
        }
        .onAppear {
            if case let .page(id) = start, path.isEmpty { path = [.page(id)] }
        }
    }

    private func name(_ macro: Macro, copying: Bool) {
        draftName = copying ? store.library.copyName(for: macro.name) : macro.name
        naming = Naming(macro: macro.id, copying: copying)
    }

    private func finishNaming(_ naming: Naming) {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if naming.copying {
            store.library.duplicateMacro(naming.macro, named: name.isEmpty ? nil : name)
        } else if !name.isEmpty, var macro = store.macro(naming.macro) {
            macro.name = name
            store.save(macro)
        }
    }
}

struct MacroRow: View {
    let macro: Macro

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if macro.isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                Text(macro.name)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                Spacer()
                if macro.speed != .normal { MonoTag(text: macro.speed.label) }
            }
            Text(MacroDescription.summary(for: macro))
                .font(.caption.monospaced())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }
}

/// A macro button as the pad shows it, in its chosen colour, typeface and span, without the
/// touch handling.
struct MacroCap: View {
    let title: String
    var appearance = ButtonAppearance()
    let span: ButtonSpan
    /// Lines under the caption, such as "tap to stop".
    var details: [String] = []
    var pressed = false
    /// The active badge: lifted in the editor, or playing on the pad.
    var lit = false
    var ringed = false

    var body: some View {
        let caption = appearance.caption.trimmingCharacters(in: .whitespaces)
        Keycap(style: .tint(appearance.tint), pressed: pressed, lit: lit, ringed: ringed) {
            KeyLabel(title: title, details: (caption.isEmpty ? [] : [caption]) + details,
                     scale: span.labelScale * appearance.textSize.factor, design: appearance.typeface.design)
        }
    }
}

struct CellID: Identifiable {
    let cell: Cell
    var id: Int { cell.row * 100 + cell.column }
}

/// A page's grid: each button sized to the cells it covers, and each cell no button
/// covers shown on its own.
struct MacroPageGrid<Content: View>: View {
    let page: MacroPage
    var spacing: CGFloat = 10
    @ViewBuilder let content: (Cell) -> Content

    var body: some View {
        GeometryReader { geometry in
            let width = (geometry.size.width - spacing * CGFloat(page.columns - 1)) / CGFloat(page.columns)
            let height = (geometry.size.height - spacing * CGFloat(page.rows - 1)) / CGFloat(page.rows)
            ZStack(alignment: .topLeading) {
                ForEach(areas, id: \.origin) { area in
                    content(area.origin)
                        .frame(width: width * CGFloat(area.columns) + spacing * CGFloat(area.columns - 1),
                               height: height * CGFloat(area.rows) + spacing * CGFloat(area.rows - 1))
                        .offset(x: CGFloat(area.origin.column) * (width + spacing),
                                y: CGFloat(area.origin.row) * (height + spacing))
                }
            }
        }
    }

    private struct Area {
        let origin: Cell
        let columns: Int
        let rows: Int
    }

    private var areas: [Area] {
        page.buttons.map { Area(origin: $0.origin, columns: $0.span.columns, rows: $0.span.rows) }
            + page.cells.filter { page.button(at: $0) == nil }.map { Area(origin: $0, columns: 1, rows: 1) }
    }
}
