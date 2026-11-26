import SwiftUI
import TocaCore
import UIKit

/// The macro pad: user-arranged pages of customizable macro buttons, rendered full-width on
/// both iPhone and iPad. Height not needed by the grid goes to the readout of the last macro sent.
struct MacroPadView: View {
    @EnvironmentObject private var store: MacroStore
    @AppStorage(SettingsKey.macroPage) private var pageID = ""
    @StateObject private var readout = PadReadout()
    @State private var editing: MacrosView.Start?
    @State private var addingPage = false
    @State private var draftPageName = ""

    var body: some View {
        Group {
            if store.library.pages.isEmpty {
                EmptyPadView { editing = .list }
            } else {
                let pages = store.library.pages
                let current = page(in: pages)
                VStack(spacing: 10) {
                    pageBar(pages, current: current)
                    PadArea(columns: current.columns, rows: current.rows) {
                        MacroPageView(page: current)
                    }
                }
            }
        }
        .environmentObject(readout)
        .sheet(item: $editing) { start in MacrosView(start: start) }
        .alert("New Page", isPresented: $addingPage) {
            TextField("Page name", text: $draftPageName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = draftPageName.trimmingCharacters(in: .whitespacesAndNewlines)
                let newPage = MacroPage(title: trimmed.isEmpty ? store.nextPageName : trimmed,
                                        shape: .deviceDefault)
                store.library.pages.append(newPage)
                pageID = newPage.id.uuidString
            }
        } message: {
            Text("Create a new macro page on your pad.")
        }
    }

    private func page(in pages: [MacroPage]) -> MacroPage {
        pages.first { $0.id.uuidString == pageID } ?? pages[0]
    }

    private func pageBar(_ pages: [MacroPage], current: MacroPage) -> some View {
        let height: CGFloat = ScreenMetrics.isPad ? 40 : 36
        return HStack(spacing: 8) {
            PageTabs(
                pages: pages.map { ($0.id.uuidString, $0.title) },
                selection: Binding(get: { current.id.uuidString }, set: { pageID = $0 }),
                onAddPage: {
                    draftPageName = store.nextPageName
                    addingPage = true
                }
            )
            Button {
                editing = .page(current.id)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.pencil")
                    Text("Edit")
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(ConsoleTileButtonStyle(size: height))
            .accessibilityLabel("Pages and macros")
        }
    }
}

/// Empty state shown when the user deletes every page.
private struct EmptyPadView: View {
    let onManage: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.inkShadow)
                    .frame(width: 72, height: 72)
                    .offset(x: 3, y: 4)
                Circle()
                    .fill(Theme.popYellow)
                    .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 2.5) }
                    .frame(width: 72, height: 72)
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.popInk)
            }
            Text("No macro pages yet")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Create a page to arrange custom macro buttons for your computer.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Manage Pages & Macros", action: onManage)
                .buttonStyle(ConsoleTileButtonStyle(size: 44, active: true))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The page tabs: one strip that scrolls sideways when the pages do not fit, with an inline `+`
/// button to add another page right beside the existing ones.
private struct PageTabs: View {
    let pages: [(id: String, title: String)]
    @Binding var selection: String
    let onAddPage: () -> Void

    var body: some View {
        let height: CGFloat = ScreenMetrics.isPad ? 40 : 36
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ConsoleSegmented(options: pages.map(\.id), selection: $selection, height: height) { id in
                        Text(pages.first { $0.id == id }?.title ?? "")
                            .fixedSize(horizontal: true, vertical: false)
                            .id(id)
                    }
                    Button(action: onAddPage) {
                        Image(systemName: "plus")
                            .font(.system(size: height > 36 ? 15 : 14, weight: .black))
                    }
                    .buttonStyle(ConsoleTileButtonStyle(size: height))
                    .accessibilityLabel("Add page")
                    .accessibilityIdentifier("addPageButton")
                }
                .padding(.leading, 1)
                .padding(.trailing, 4)
                .padding(.vertical, 2)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(height: height + 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: selection) { _, id in
                guard pages.count > 2 else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// Sizes a page's grid so keys stay proportional across grid densities, always reserving
/// dedicated space below for the bottom readout and link panel so keys never crowd it.
struct PadArea<Grid: View>: View {
    let columns: Int
    let rows: Int
    @ViewBuilder let grid: () -> Grid

    /// Tallest key aspect ratio (height / width).
    static var maxAspect: CGFloat { 1.15 }
    static var readoutHeight: CGFloat { ScreenMetrics.isPad ? 114 : 104 }
    static var readoutGap: CGFloat { 14 }

    static func gridSize(for shape: GridShape, in available: CGSize) -> CGSize {
        let spacing = Theme.padSpacing
        let cols = CGFloat(max(shape.columns, 1))
        let rows = CGFloat(max(shape.rows, 1))
        let width = max(1, (available.width - spacing * (cols - 1)) / cols)
        let fullHeight = max(1, (available.height - spacing * (rows - 1)) / rows)
        let keyHeight = min(fullHeight, width * maxAspect)
        let gridHeight = keyHeight * rows + spacing * (rows - 1)
        return CGSize(width: available.width, height: gridHeight)
    }

    var body: some View {
        GeometryReader { geometry in
            let gridAvailable = CGSize(
                width: geometry.size.width,
                height: max(120, geometry.size.height - Self.readoutHeight - Self.readoutGap)
            )
            let gridSize = Self.gridSize(for: GridShape(columns: columns, rows: rows), in: gridAvailable)
            VStack(spacing: 0) {
                grid()
                    .frame(height: gridSize.height)
                    .background {
                        Color.clear
                            .onAppear { PadShape.recordCanvas(gridAvailable) }
                            .onChange(of: gridAvailable) { _, size in PadShape.recordCanvas(size) }
                    }
                Spacer(minLength: Self.readoutGap)
                ReadoutPanel()
                    .frame(height: Self.readoutHeight)
            }
        }
    }
}

/// What the readout shows: the last macro sent, and whether it reached the dongle.
final class PadReadout: ObservableObject {
    struct Entry: Equatable {
        let title: String
        let detail: String?
        let sent: Bool
        let isSensitive: Bool
        let at: Date
    }

    @Published private(set) var last: Entry?

    func show(_ title: String, detail: String?, sent: Bool, isSensitive: Bool = false) {
        last = Entry(title: title, detail: detail, sent: sent, isSensitive: isSensitive, at: Date())
    }
}

/// The comic panel readout under the keys: the last macro sent and dongle status.
private struct ReadoutPanel: View {
    @EnvironmentObject private var readout: PadReadout
    @EnvironmentObject private var link: DongleLink

    var body: some View {
        let failed = readout.last?.sent == false
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(
                    text: failed ? "Not sent" : "Last sent",
                    color: failed ? Theme.red : Theme.popYellow,
                    foreground: failed ? .white : Theme.popInk
                )
                if let last = readout.last {
                    HStack(spacing: 6) {
                        if last.isSensitive {
                            Image(systemName: "lock.fill")
                                .font(.system(size: ScreenMetrics.isPad ? 16 : 14, weight: .bold))
                                .foregroundStyle(last.sent ? Theme.highlightLabel : Theme.red)
                        }
                        Text(last.title)
                            .font(.system(size: ScreenMetrics.isPad ? 24 : 19, weight: .black, design: .rounded))
                            .foregroundStyle(last.sent ? Theme.highlightLabel : Theme.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(last.sent ? (last.isSensitive ? MacroDescription.maskedText : (last.detail ?? "Sent")) : notSentMessage)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                } else {
                    Text("Ready")
                        .font(.system(size: ScreenMetrics.isPad ? 24 : 19, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(link.state == .noDongle ? "Tap Dongle above to pair an ESP32-S3 dongle." : "Macros fire on touch.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                SectionLabel(text: "Link", color: Theme.raised, foreground: Theme.text)
                HStack(spacing: 6) {
                    Circle()
                        .fill(link.state.color)
                        .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 1.5) }
                        .frame(width: 9, height: 9)
                    Text(link.state.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Theme.text)
                if link.state == .ready, let rssi = link.rssi {
                    Text("\(rssi) dBm")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .comicPanel(fill: Theme.surface, cornerRadius: 12, borderWidth: 2, shadowOffset: 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("readoutPanel")
    }

    private var notSentMessage: String {
        link.state == .noDongle ? "Tap Dongle above to pair an ESP32-S3 dongle." : "No dongle ready: nothing reached the PC."
    }
}

/// Bold comic section stamp label used across panels and grouped forms.
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.popYellow
    var foreground: Color = Theme.popInk

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.inkBorder, lineWidth: 1.5)
            }
    }
}

/// A page on the macro pad. An empty cell opens the macro picker.
private struct MacroPageView: View {
    let page: MacroPage
    @EnvironmentObject private var store: MacroStore
    @State private var assigning: CellID?

    var body: some View {
        MacroPageGrid(page: page, spacing: Theme.padSpacing) { cell in
            if let macro = store.library.macro(on: page, at: cell), let button = page.button(at: cell) {
                MacroKey(macro: macro, span: button.span, appearance: button.appearance)
            } else {
                Button {
                    assigning = CellID(cell: cell)
                } label: {
                    Socket(addable: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Empty button: choose a macro")
            }
        }
        .id(page.id)
        .sheet(item: $assigning) { cell in
            AssignMacroView(pageID: page.id, cell: cell.cell)
        }
    }
}

/// The available pad canvas size, so the page editor renders any GridShape at the exact
/// proportions it has on the live macro pad.
enum PadShape {
    private static let widthKey = "padCanvasWidth"
    private static let heightKey = "padCanvasHeight"

    static func recordCanvas(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        UserDefaults.standard.set(Double(size.width), forKey: widthKey)
        UserDefaults.standard.set(Double(size.height), forKey: heightKey)
    }

    static var canvasSize: CGSize {
        let width = UserDefaults.standard.double(forKey: widthKey)
        let height = UserDefaults.standard.double(forKey: heightKey)
        if width > 0, height > 0 { return CGSize(width: width, height: height) }
        let screen = UIScreen.main.bounds.size
        return CGSize(width: screen.width - 2 * Theme.margin, height: screen.height * 0.68)
    }

    static func size(for shape: GridShape) -> CGSize {
        PadArea<EmptyView>.gridSize(for: shape, in: canvasSize)
    }
}

/// A macro button. Touch down plays the macro; touching it again while it plays stops it.
private struct MacroKey: View {
    let macro: Macro
    let span: ButtonSpan
    let appearance: ButtonAppearance
    @EnvironmentObject private var controller: InputController
    @EnvironmentObject private var link: DongleLink
    @EnvironmentObject private var readout: PadReadout
    @State private var pressed = false

    var body: some View {
        let playing = controller.playingMacro == macro.id
        MacroCap(title: macro.name, appearance: appearance, span: span,
                 details: playing ? ["tap to stop"] : macro.speed == .normal ? [] : [macro.speed.label],
                 pressed: pressed, lit: playing, ringed: playing)
        .overlay {
            KeyTouchArea(onDown: {
                pressed = true
                if controller.playingMacro == macro.id {
                    controller.stopMacro()
                } else {
                    controller.play(macro)
                    readout.show(macro.name, detail: MacroDescription.readoutDetail(for: macro),
                                 sent: link.state == .ready, isSensitive: macro.isSensitive)
                }
            }, onUp: { pressed = false })
        }
        .accessibilityElement()
        .accessibilityLabel(macro.name)
        .accessibilityAddTraits(.isButton)
    }
}

extension ButtonSpan {
    /// How much larger a label scales on a multi-cell button compared to 1 × 1.
    var labelScale: CGFloat {
        min(1 + 0.18 * CGFloat(columns - 1) + 0.14 * CGFloat(rows - 1), 1.8)
    }
}

/// Puts a macro on an empty button: pick one, or make a new one.
private struct AssignMacroView: View {
    let pageID: UUID
    let cell: Cell
    @EnvironmentObject private var store: MacroStore
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var created = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        creating = true
                    } label: {
                        Label("New Macro…", systemImage: "plus")
                            .fontWeight(.semibold)
                    }
                }
                .consoleRows()
                if !store.library.macros.isEmpty {
                    Section {
                        ForEach(store.library.macros) { macro in
                            Button {
                                store.assign(macro.id, to: cell, on: pageID)
                                dismiss()
                            } label: {
                                MacroRow(macro: macro)
                            }
                            .tint(Theme.text)
                        }
                    } header: {
                        SectionLabel(text: "Macros")
                    }
                    .consoleRows()
                }
            }
            .consoleForm()
            .navigationTitle("Choose a Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.tint)
        .sheet(isPresented: $creating, onDismiss: { if created { dismiss() } }) {
            NavigationStack {
                MacroEditorView(original: nil) { macro in
                    store.save(macro)
                    store.assign(macro.id, to: cell, on: pageID)
                    created = true
                }
            }
            .tint(Theme.tint)
        }
    }
}

/// Raw UIKit touches, so several keys can be held at once and each lift is seen, even when the
/// touch is cancelled by the system.
struct KeyTouchArea: UIViewRepresentable {
    let onDown: () -> Void
    let onUp: () -> Void

    func makeUIView(context: Context) -> TouchView {
        TouchView()
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onDown = onDown
        view.onUp = onUp
    }

    final class TouchView: UIView {
        var onDown: () -> Void = {}
        var onUp: () -> Void = {}
        private var touching = 0

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            if touching == 0 { onDown() }
            touching += touches.count
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            lift(touches.count)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            lift(touches.count)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Taken off screen while held: let go.
            if window == nil, touching > 0 { lift(touching) }
        }

        private func lift(_ count: Int) {
            touching = max(0, touching - count)
            if touching == 0 { onUp() }
        }
    }
}
