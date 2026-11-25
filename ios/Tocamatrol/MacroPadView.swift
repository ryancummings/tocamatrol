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
    }

    private func page(in pages: [MacroPage]) -> MacroPage {
        pages.first { $0.id.uuidString == pageID } ?? pages[0]
    }

    private func pageBar(_ pages: [MacroPage], current: MacroPage) -> some View {
        HStack(spacing: 8) {
            PageTabs(pages: pages.map { ($0.id.uuidString, $0.title) },
                     selection: Binding(get: { current.id.uuidString }, set: { pageID = $0 }))
            Button {
                editing = .page(current.id)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(ConsoleTileButtonStyle(size: ScreenMetrics.isPad ? 40 : 36))
            .accessibilityLabel("Pages and macros")
        }
    }
}

/// Empty state shown when the user deletes every page.
private struct EmptyPadView: View {
    let onManage: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.amber.opacity(0.8))
            Text("No macro pages yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
            Text("Create a page to arrange custom macro buttons for your computer.")
                .font(.subheadline)
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Manage Pages & Macros", action: onManage)
                .buttonStyle(ConsoleTileButtonStyle(size: 44, active: true))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The page tabs: one strip that scrolls sideways when the pages do not fit.
private struct PageTabs: View {
    let pages: [(id: String, title: String)]
    @Binding var selection: String

    var body: some View {
        let height: CGFloat = ScreenMetrics.isPad ? 40 : 36
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ConsoleSegmented(options: pages.map(\.id), selection: $selection, height: height) { id in
                    Text(pages.first { $0.id == id }?.title ?? "").id(id)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(height: height)
            // Fade the ends, so a tab cut by the edge reads as scrolled, not broken.
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 12)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, id in withAnimation { proxy.scrollTo(id, anchor: .center) } }
        }
    }
}

/// Sizes a page's grid so keys stay proportional across grid densities, and allocates remaining
/// height below the grid to the readout panel.
struct PadArea<Grid: View>: View {
    let columns: Int
    let rows: Int
    @ViewBuilder let grid: () -> Grid

    /// Tallest key aspect ratio (height / width).
    static var maxAspect: CGFloat { ScreenMetrics.isPad ? 1.15 : 1.15 }
    private static var readoutMinimum: CGFloat { 64 }

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
            let gridSize = Self.gridSize(for: GridShape(columns: columns, rows: rows), in: geometry.size)
            let left = geometry.size.height - gridSize.height - 12
            VStack(spacing: 12) {
                grid()
                    .frame(height: gridSize.height)
                    .background {
                        Color.clear
                            .onAppear { PadShape.recordCanvas(geometry.size) }
                            .onChange(of: geometry.size) { _, size in PadShape.recordCanvas(size) }
                    }
                if left >= Self.readoutMinimum {
                    ReadoutPanel().frame(height: min(left, ScreenMetrics.isPad ? 140 : 120))
                }
                Spacer(minLength: 0)
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
        let at: Date
    }

    @Published private(set) var last: Entry?

    func show(_ title: String, detail: String?, sent: Bool) {
        last = Entry(title: title, detail: detail, sent: sent, at: Date())
    }
}

/// The console readout under the keys: the last macro sent, and the link.
private struct ReadoutPanel: View {
    @EnvironmentObject private var readout: PadReadout
    @EnvironmentObject private var link: DongleLink

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: readout.last?.sent == false ? "Not sent" : "Last sent",
                             color: readout.last?.sent == false ? Theme.red : Theme.amber.opacity(0.7))
                if let last = readout.last {
                    Text(last.title)
                        .font(.system(size: ScreenMetrics.isPad ? 26 : 20, weight: .semibold))
                        .foregroundStyle(last.sent ? Theme.amberLabel : Theme.red)
                        .shadow(color: Theme.amber.opacity(last.sent ? 0.35 : 0), radius: 6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(last.sent ? (last.detail ?? " ") : notSentMessage)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                } else {
                    Text("Ready")
                        .font(.system(size: ScreenMetrics.isPad ? 26 : 20, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                    Text(link.state == .noDongle ? "Tap Dongle above to pair an ESP32-S3 dongle." : "Macros fire on touch.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                SectionLabel(text: "Link", color: Theme.dim)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1).fill(link.state.color).frame(width: 7, height: 7)
                    Text(link.state.title).font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.text)
                if link.state == .ready, let rssi = link.rssi {
                    Text("\(rssi) dBm").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.well, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var notSentMessage: String {
        link.state == .noDongle ? "Tap Dongle above to pair an ESP32-S3 dongle." : "No dongle ready: nothing reached the PC."
    }
}

/// A console section label: mono, dim amber, after "// ".
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.amber.opacity(0.7)

    var body: some View {
        Text("// \(text)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(color)
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
                    readout.show(macro.name, detail: MacroDescription.text(macro.actions), sent: link.state == .ready)
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
        .sheet(isPresented: $creating, onDismiss: { if created { dismiss() } }) {
            NavigationStack {
                MacroEditorView(original: nil) { macro in
                    store.save(macro)
                    store.assign(macro.id, to: cell, on: pageID)
                    created = true
                }
            }
            .tint(Theme.amber)
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
