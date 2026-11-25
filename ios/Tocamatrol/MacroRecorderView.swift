import QuartzCore
import SwiftUI
import TocaCore

/// Records keys on the virtual keyboard for one part of a macro: the editor turns
/// them into steps, so a slip means recording that part again, not the whole macro.
/// With Send to PC on, each key also reaches the PC as it is typed.
struct MacroRecorderView: View {
    /// "Add" or "Replace": what Done does with the keys.
    var doneTitle = "Add"
    let onFinish: ([MacroStep]) -> Void

    @EnvironmentObject private var controller: InputController
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.recordSendsToPC) private var sendToPC = true
    @State private var recorder = MacroRecorder()
    /// Bumped on Clear, so the keyboard is rebuilt with nothing held or latched.
    @State private var keyboardID = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                details
                VStack(alignment: .leading, spacing: 4) {
                    Text(recorder.steps.isEmpty ? "Type on the keyboard below." : MacroDescription.text(recorder.steps))
                        .font(recorder.steps.isEmpty ? .callout : .body.monospaced().weight(.semibold))
                        .foregroundStyle(recorder.steps.isEmpty ? Theme.dim : Theme.highlightLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    if !recorder.steps.isEmpty {
                        Text("\(recorder.steps.count) KEY CHANGES")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(12)
                // On the iPad the transcript takes the room above a fixed-height keyboard.
                .frame(maxHeight: ScreenMetrics.isPad ? .infinity : 160)
                .comicPanel(fill: Theme.well, cornerRadius: 12, borderWidth: 2, shadowOffset: 2)
                VirtualKeyboardView(onPress: press, onRelease: release)
                    .id(keyboardID)
                    .frame(maxHeight: ScreenMetrics.isPad ? 440 : .infinity)
            }
            .padding(Theme.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Theme.ground.ignoresSafeArea()
                    HalftoneBackground().ignoresSafeArea()
                }
            }
            .navigationTitle("Record Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle, action: finish).disabled(recorder.steps.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") {
                        recorder = MacroRecorder()
                        keyboardID += 1
                    }
                    .disabled(recorder.steps.isEmpty)
                }
            }
        }
        .tint(Theme.tint)
        // A full-screen cover on the iPad otherwise hides the status bar and lets the
        // navigation bar ride up under it.
        .statusBarHidden(false)
    }

    private var details: some View {
        HStack {
            Text("Keys become steps you can edit. Hold a modifier with one finger, or tap it to hold it for the next key.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            Toggle("Send to PC", isOn: $sendToPC).fixedSize().font(.subheadline.weight(.semibold))
        }
    }

    private func press(_ chord: KeyChord) {
        recorder.press(chord, at: CACurrentMediaTime())
        if sendToPC { controller.pressKey(chord) }
    }

    private func release(_ chord: KeyChord) {
        recorder.release(chord, at: CACurrentMediaTime())
        // Unconditional: Send to PC may have been switched off while the key was down.
        controller.releaseKey(chord)
    }

    private func finish() {
        onFinish(recorder.finish())
        dismiss()
    }
}
