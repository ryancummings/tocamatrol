import SwiftUI
import TocaCore

/// Makes or changes a macro: its name, its steps (text, shortcuts, pauses, and
/// recorded keys), and how fast it plays. How its buttons look is set in the page editor. Each step is edited on its own,
/// so a slip costs one step, not the whole macro. Changes apply on Save.
struct MacroEditorView: View {
    /// The macro being changed, or nil for a new one.
    let original: Macro?
    let onSave: (Macro) -> Void
    /// Offered for an existing macro.
    var onDelete: (() -> Void)?

    @EnvironmentObject private var store: MacroStore
    @EnvironmentObject private var controller: InputController
    @EnvironmentObject private var link: DongleLink
    @Environment(\.dismiss) private var dismiss

    @State private var id = UUID()
    @State private var name = ""
    @State private var speed = MacroSpeed.normal
    @State private var steps: [EditableStep] = []
    @State private var loaded = false
    @State private var editing: StepEdit?
    @State private var recording: RecordTarget?
    @State private var reordering = false
    /// Choosing pauses to set together, such as waits recorded longer than meant.
    @State private var selecting = false
    @State private var selected: Set<UUID> = []
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                preview
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("macroName")
            } header: {
                SectionLabel(text: "Name")
            }
            .consoleRows()

            stepsSection

            Section {
                ConsoleSegmented(options: MacroSpeed.allCases, selection: $speed) {
                    Text($0.label).frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel(text: "Speed")
            } footer: {
                Text(speedFooter).foregroundStyle(Theme.dim)
            }
            .consoleRows()

            if original != nil, onDelete != nil {
                Section {
                    Button("Delete Macro", role: .destructive) { confirmingDelete = true }
                        .foregroundStyle(Theme.red)
                }
                .consoleRows()
            }
        }
        .consoleForm()
        .environment(\.editMode, .constant(reordering ? .active : .inactive))
        // Pinned while choosing pauses, so it stays in reach however long the list is.
        .safeAreaInset(edge: .bottom) {
            if selecting {
                selectionBar
                    .padding(.horizontal, Theme.margin)
                    .padding(.vertical, 10)
                    .background(Theme.surface.ignoresSafeArea())
                    .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(original == nil ? "New Macro" : name.isEmpty ? "Macro" : name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(steps.isEmpty)
            }
        }
        .onAppear(perform: load)
        .sheet(item: $editing) { edit in
            StepEditorSheet(action: edit.action, title: edit.title) { action in apply(action, to: edit.targets) }
        }
        .fullScreenCover(item: $recording) { target in
            MacroRecorderView(doneTitle: target.replacing == nil ? "Add" : "Replace") { recorded in
                insert(MacroAction.actions(from: recorded), replacing: target.replacing)
            }
        }
        .alert("Delete \(name)?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dismiss()
                onDelete?()
            }
        } message: {
            Text("Buttons that play it become empty.")
        }
    }

    // MARK: - Preview

    private var preview: some View {
        let macro = draft
        return HStack(alignment: .center, spacing: 16) {
            MacroCap(title: name.isEmpty ? "Macro" : name, span: .small,
                     details: speed == .normal ? [] : [speed.label],
                     lit: controller.playingMacro == macro.id, ringed: controller.playingMacro == macro.id)
                .frame(width: ScreenMetrics.isPad ? 150 : 112, height: ScreenMetrics.isPad ? 160 : 120)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(steps.isEmpty ? "No steps yet" : MacroDescription.text(macro.actions))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.dim)
                    .lineLimit(3)
                if controller.playingMacro == macro.id {
                    Button("Stop", systemImage: "stop.fill") { controller.stopMacro() }
                        .buttonStyle(ConsoleTileButtonStyle(size: 36, active: true))
                } else {
                    Button("Play on PC", systemImage: "play.fill") { controller.play(macro) }
                        .buttonStyle(ConsoleTileButtonStyle(size: 36, active: true))
                        .disabled(steps.isEmpty || link.state != .ready)
                        .opacity(steps.isEmpty || link.state != .ready ? 0.45 : 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        Section {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let isPause = if case .pause = step.action { true } else { false }
                Button {
                    if selecting {
                        if isPause { selected.formSymmetricDifference([step.id]) }
                    } else {
                        open(step)
                    }
                } label: {
                    HStack(spacing: 10) {
                        if selecting {
                            Image(systemName: selected.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isPause ? Theme.amber : Theme.hairline)
                        }
                        StepRow(number: index + 1, action: step.action, showsChevron: !selecting)
                            .opacity(selecting && !isPause ? 0.4 : 1)
                    }
                }
                .disabled(selecting && !isPause)
                .accessibilityIdentifier("step-\(index)")
                .accessibilityAddTraits(selected.contains(step.id) ? .isSelected : [])
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { open(step) }
                    Button("Play This Step", systemImage: "play") {
                        controller.play(Macro(name: "", speed: speed, actions: [step.action]))
                    }
                    .disabled(link.state != .ready)
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        steps.insert(EditableStep(action: step.action), at: index + 1)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        steps.removeAll { $0.id == step.id }
                    }
                }
            }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { steps.remove(atOffsets: $0) }
            if !selecting, !reordering { addRow }
        } header: {
            HStack(spacing: 14) {
                SectionLabel(text: "Steps")
                Spacer()
                if !reordering, pauseIDs.count > 0 {
                    Button(selecting ? "Done" : "Select Pauses") {
                        withAnimation {
                            selecting.toggle()
                            selected = []
                        }
                    }
                    .accessibilityIdentifier("selectPauses")
                }
                if !selecting, steps.count > 1 {
                    Button(reordering ? "Done" : "Reorder") { withAnimation { reordering.toggle() } }
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .textCase(nil)
            .tint(Theme.amber)
        } footer: {
            Text(selecting ? "Tick the pauses to change, then set them all to one length."
                 : "Steps play top to bottom. Tap one to change it, swipe left to delete it, or hold it for more.")
                .foregroundStyle(Theme.dim)
        }
        .consoleRows()
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            AddStepButton(title: "Text", systemImage: "text.cursor", id: "addText") {
                editing = StepEdit(action: .text(""))
            }
            AddStepButton(title: "Shortcut", systemImage: "command", id: "addShortcut") {
                editing = StepEdit(action: .shortcut(KeyChord(0, .leftControl)))
            }
            AddStepButton(title: "Pause", systemImage: "timer", id: "addPause") {
                editing = StepEdit(action: .pause(500))
            }
            AddStepButton(title: "Record", systemImage: "record.circle", id: "addRecording") {
                recording = RecordTarget(replacing: nil)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
    }

    /// Below the steps while choosing pauses: all or none, and set the chosen ones.
    private var selectionBar: some View {
        HStack(spacing: 8) {
            Button {
                selected = selected.count == pauseIDs.count ? [] : Set(pauseIDs)
            } label: {
                Text(selected.count == pauseIDs.count ? "None" : "All").padding(.horizontal, 10)
            }
            .buttonStyle(ConsoleTileButtonStyle(size: 44))
            .accessibilityIdentifier("selectAllPauses")
            Button {
                let first = steps.first { selected.contains($0.id) }?.action ?? .pause(500)
                editing = StepEdit(targets: steps.map(\.id).filter(selected.contains), action: first,
                                   title: selected.count == 1 ? "Pause" : "\(selected.count) Pauses")
            } label: {
                Text(selected.isEmpty ? "Choose pauses above"
                     : selected.count == 1 ? "Set 1 Pause…" : "Set \(selected.count) Pauses…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ConsoleTileButtonStyle(size: 44, active: !selected.isEmpty))
            .disabled(selected.isEmpty)
            .accessibilityIdentifier("setPauses")
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    // MARK: - State

    private var pauseIDs: [UUID] {
        steps.compactMap { if case .pause = $0.action { $0.id } else { nil } }
    }

    private var draft: Macro {
        Macro(id: id, name: name, speed: speed, actions: steps.map(\.action))
    }

    private var speedFooter: String {
        switch speed {
        case .instant: "Instant leaves out the pauses. Each key still takes one send tick (15 ms)."
        case .normal: String(format: "Plays in about %.1f s.", Self.duration(draft))
        default: String(format: "Pauses are cut to 1/%d. Plays in about %.1f s.", Int(speed.factor), Self.duration(draft))
        }
    }

    /// Pauses at its speed plus one 15 ms send tick per key change.
    private static func duration(_ macro: Macro) -> Double {
        MacroDescription.duration(macro) + Double(macro.steps.count) * 0.015
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let original {
            id = original.id
            name = original.name
            speed = original.speed
            steps = original.actions.map { EditableStep(action: $0) }
        } else {
            name = store.nextMacroName
        }
    }

    private func open(_ step: EditableStep) {
        if case .recorded = step.action {
            recording = RecordTarget(replacing: step.id)
        } else {
            editing = StepEdit(targets: [step.id], action: step.action)
        }
    }

    /// The edited step in place of each target, or added at the end when there is none.
    private func apply(_ action: MacroAction, to targets: [UUID]) {
        guard !targets.isEmpty else { return steps.append(EditableStep(action: action)) }
        for index in steps.indices where targets.contains(steps[index].id) { steps[index].action = action }
        if selecting {
            selecting = false
            selected = []
        }
    }

    /// Recorded keys, as steps: in place of the step they replace, or at the end.
    private func insert(_ actions: [MacroAction], replacing target: UUID?) {
        let new = actions.map { EditableStep(action: $0) }
        if let target, let index = steps.firstIndex(where: { $0.id == target }) {
            steps.replaceSubrange(index...index, with: new)
        } else {
            steps.append(contentsOf: new)
        }
    }

    private func save() {
        var macro = draft
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        macro.name = trimmed.isEmpty ? store.nextMacroName : trimmed
        // A text step emptied while editing types nothing.
        macro.actions.removeAll { $0 == .text("") }
        onSave(macro)
        dismiss()
    }
}

private struct EditableStep: Identifiable {
    let id = UUID()
    var action: MacroAction
}

/// A step sheet: the steps it changes (several chosen pauses), or none for a new step to add
/// at the end.
private struct StepEdit: Identifiable {
    let id = UUID()
    var targets: [UUID] = []
    let action: MacroAction
    var title: String?
}

/// Recording keys: to add at the end, or in place of a recorded step.
private struct RecordTarget: Identifiable {
    let id = UUID()
    let replacing: UUID?
}

private struct AddStepButton: View {
    let title: String
    let systemImage: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 16, weight: .medium))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.amberLabel)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.amber.opacity(0.4), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(title)")
        .accessibilityIdentifier(id)
    }
}

/// One step in the editor's list: its number, kind and what it does.
private struct StepRow: View {
    let number: Int
    let action: MacroAction
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", number))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.dim)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.amber)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.dim)
                summary
                if case let .text(text) = action, !USKeyboard.untypable(in: text).isEmpty {
                    Label("Leaves out \(String(USKeyboard.untypable(in: text)))", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.amber)
                }
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var summary: some View {
        switch action {
        case let .text(text):
            Text(text.isEmpty ? "Nothing to type" : MacroDescription.text(action))
                .font(.body.monospaced())
                .foregroundStyle(text.isEmpty ? Theme.dim : Theme.amberLabel)
                .lineLimit(3)
        case let .shortcut(chord):
            ChordView(chord: chord)
        case let .pause(ms):
            Text(String(format: "%.2f s", Double(ms) / 1000)).font(.body.monospaced()).foregroundStyle(Theme.text)
        case let .recorded(steps):
            Text(MacroDescription.text(steps)).font(.body.monospaced()).foregroundStyle(Theme.text).lineLimit(2)
        }
    }

    private var icon: String {
        switch action {
        case .text: "text.cursor"
        case .shortcut: "command"
        case .pause: "timer"
        case .recorded: "record.circle"
        }
    }

    private var kind: String {
        switch action {
        case .text: "Type"
        case .shortcut: "Shortcut"
        case .pause: "Pause"
        case .recorded: "Recorded keys"
        }
    }
}

/// A shortcut as little keycaps: [Ctrl] + [S].
struct ChordView: View {
    let chord: KeyChord
    var large = false

    var body: some View {
        let names = MacroDescription.modifierList(chord.modifiers)
            + (chord.usage == 0 ? [] : [MacroDescription.keyName(chord.usage)])
        HStack(spacing: large ? 8 : 5) {
            if names.isEmpty {
                Text("Choose a key").font(.body).foregroundStyle(Theme.dim)
            }
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                if index > 0 { Text("+").font(large ? .title3 : .caption).foregroundStyle(Theme.dim) }
                Text(name)
                    .font(.system(size: large ? 20 : 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, large ? 12 : 7)
                    .frame(minWidth: large ? 48 : 28, minHeight: large ? 44 : 24)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.strongBorder, lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MacroDescription.chordName(chord))
    }
}

// MARK: - Button look

/// A page button's colour, typeface, text size and caption, set in the page editor.
struct ButtonLookControls: View {
    @Binding var appearance: ButtonAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: ButtonAppearance.Tint.allCases.count),
                      spacing: 6) {
                ForEach(ButtonAppearance.Tint.allCases, id: \.self) { tint in
                    let style = KeyStyle.tint(tint)
                    let on = appearance.tint == tint
                    Button {
                        appearance.tint = tint
                    } label: {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(colors: [style.top, style.bottom], startPoint: .top, endPoint: .bottom))
                            .overlay { Circle().fill(style.label).frame(width: 6, height: 6).opacity(0.9) }
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(on ? Theme.amber : Theme.strongBorder, lineWidth: on ? 2 : 1)
                            }
                            .frame(height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tint.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: appearance.tint)

            ConsoleSegmented(options: ButtonAppearance.Typeface.allCases, selection: $appearance.typeface, height: 50) { face in
                VStack(spacing: 2) {
                    Text("Aa").font(.system(size: 17, weight: .semibold, design: face.design))
                    Text(face.name).font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 10) {
                ConsoleSegmented(options: ButtonAppearance.TextSize.allCases, selection: $appearance.textSize) {
                    Text($0.shortName)
                }
                .fixedSize()
                .accessibilityLabel("Text size")
                TextField("Caption (optional)", text: $appearance.caption)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Theme.well, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
                    }
                    .accessibilityIdentifier("caption")
            }
        }
    }
}

// MARK: - Step editors

/// Changes one text, shortcut or pause step. Done hands back the step.
private struct StepEditorSheet: View {
    let action: MacroAction
    /// "3 Pauses" when it sets several.
    var title: String?
    let onDone: (MacroAction) -> Void

    var body: some View {
        NavigationStack {
            switch action {
            case let .text(text): TextStepEditor(text: text, onDone: onDone)
            case let .shortcut(chord): ShortcutStepEditor(chord: chord, onDone: onDone)
            case let .pause(ms): PauseStepEditor(ms: ms, title: title ?? "Pause", onDone: onDone)
            case .recorded: EmptyView()
            }
        }
        .tint(Theme.amber)
    }
}

/// Typed text, entered on the iOS keyboard, with its spelling help and the system's editing.
private struct TextStepEditor: View {
    @State var text: String
    let onDone: (MacroAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        let untypable = USKeyboard.untypable(in: text)
        Form {
            Section {
                TextField("Text to type on the PC", text: $text, axis: .vertical)
                    .lineLimit(4...12)
                    .font(.body.monospaced())
                    .focused($focused)
                    .accessibilityIdentifier("stepText")
            } header: {
                SectionLabel(text: "Type")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Return types Enter. The PC gets the keys of a US keyboard, so curly quotes and dashes become plain ones.")
                        .foregroundStyle(Theme.dim)
                    if !untypable.isEmpty {
                        Label("A US keyboard cannot type \(String(untypable)); they are left out.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.amber)
                    }
                }
            }
            .consoleRows()
        }
        .consoleForm()
        .navigationTitle("Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone(.text(text))
                    dismiss()
                }
                .disabled(text.isEmpty)
            }
        }
        .onAppear { focused = true }
    }
}

/// A key and its modifiers, picked from short lists rather than typed on a keyboard.
private struct ShortcutStepEditor: View {
    let onDone: (MacroAction) -> Void
    @State private var modifiers: KeyModifiers
    @State private var usage: UInt8
    @State private var group: KeyGroup
    @Environment(\.dismiss) private var dismiss

    init(chord: KeyChord, onDone: @escaping (MacroAction) -> Void) {
        self.onDone = onDone
        _modifiers = State(initialValue: chord.modifiers)
        _usage = State(initialValue: chord.usage)
        _group = State(initialValue: KeyGroup.allCases.first { $0.keys.contains(chord.usage) } ?? .letters)
    }

    private static let modifierOptions: [(String, KeyModifiers)] = [
        ("Ctrl", .leftControl), ("Shift", .leftShift), ("Alt", .leftAlt), ("Win", .leftGUI),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ChordView(chord: KeyChord(usage, modifiers), large: true)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Theme.well, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
                    }

                SectionLabel(text: "Hold")
                HStack(spacing: 8) {
                    ForEach(Self.modifierOptions, id: \.0) { name, modifier in
                        let on = !modifiers.isDisjoint(with: Self.both(modifier))
                        Button(name) {
                            if on { modifiers.subtract(Self.both(modifier)) } else { modifiers.insert(modifier) }
                        }
                        .buttonStyle(ConsoleTileButtonStyle(size: 44, active: on))
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: modifiers)

                SectionLabel(text: "Then press")
                ScrollView(.horizontal, showsIndicators: false) {
                    ConsoleSegmented(options: KeyGroup.allCases, selection: $group) { Text($0.title) }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: group.minimumWidth), spacing: 8)], spacing: 8) {
                    ForEach(group.keys, id: \.self) { key in
                        let on = key == usage
                        Button {
                            usage = key
                        } label: {
                            Text(MacroDescription.keyName(key))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(on ? Theme.amberLabel : Theme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(on ? Theme.amber.opacity(0.15) : Theme.raised,
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(on ? Theme.amber : Theme.hairline, lineWidth: on ? 2 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(MacroDescription.keyName(key))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: usage)
            }
            .padding(Theme.margin)
        }
        .background(Theme.ground)
        .navigationTitle("Shortcut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone(.shortcut(KeyChord(usage, modifiers)))
                    dismiss()
                }
                .disabled(usage == 0)
            }
        }
    }

    /// Left and right forms of a modifier, so a recorded right Ctrl shows as Ctrl.
    private static func both(_ modifier: KeyModifiers) -> KeyModifiers {
        KeyModifiers(rawValue: modifier.rawValue | modifier.rawValue << 4)
    }
}

/// The keys a shortcut can end in, in short lists.
private enum KeyGroup: CaseIterable, Hashable {
    case letters, numbers, function, moreFunction, navigation, symbols

    var title: String {
        switch self {
        case .letters: "A–Z"
        case .numbers: "0–9"
        case .function: "F1–F12"
        case .moreFunction: "F13–F24"
        case .navigation: "Enter, arrows…"
        case .symbols: "Symbols"
        }
    }

    var keys: [UInt8] {
        switch self {
        case .letters: Array(0x04...0x1D)
        case .numbers: Array(0x1E...0x27)
        case .function: Array(0x3A...0x45)
        case .moreFunction: Array(0x68...0x73)
        case .navigation: [0x28, 0x29, 0x2B, 0x2C, 0x2A, 0x4C, 0x49, 0x4A, 0x4D, 0x4B, 0x4E, 0x50, 0x52, 0x51, 0x4F]
        case .symbols: [0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38]
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .letters, .numbers, .symbols: 44
        case .function, .moreFunction: 58
        case .navigation: 86
        }
    }
}

/// A wait between steps, to the hundredth of a second.
private struct PauseStepEditor: View {
    @State var ms: Int
    var title = "Pause"
    let onDone: (MacroAction) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let presets = [100, 250, 500, 1000, 2000, 5000]

    var body: some View {
        Form {
            Section {
                Text(String(format: "%.2f s", Double(ms) / 1000))
                    .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.amberLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentTransition(.numericText())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                    ForEach(Self.presets, id: \.self) { preset in
                        Button(preset >= 1000 ? "\(preset / 1000) s" : String(format: "%.2g s", Double(preset) / 1000)) {
                            withAnimation { ms = preset }
                        }
                        .buttonStyle(ConsoleTileButtonStyle(size: 40, active: ms == preset))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
                Stepper("Fine: 0.05 s steps", value: $ms, in: 0...30_000, step: 50)
                    .foregroundStyle(Theme.text)
                Slider(value: Binding(get: { Double(min(ms, 10_000)) }, set: { ms = Int(($0 / 50).rounded()) * 50 }),
                       in: 0...10_000)
            } header: {
                SectionLabel(text: "Wait")
            } footer: {
                Text("Gives the PC time to catch up, such as for a window to open. 2× and 4× shorten it; Instant leaves it out.")
                    .foregroundStyle(Theme.dim)
            }
            .consoleRows()
        }
        .consoleForm()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone(.pause(ms))
                    dismiss()
                }
                .disabled(ms == 0)
            }
        }
    }
}
