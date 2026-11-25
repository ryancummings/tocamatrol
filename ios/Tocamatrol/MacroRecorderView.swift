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
                        .font(recorder.steps.isEmpty ? .callout : .body.monospaced())
                        .foregroundStyle(recorder.steps.isEmpty ? Theme.dim : Theme.amberLabel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    if !recorder.steps.isEmpty {
                        Text("\(recorder.steps.count) KEY CHANGES")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Theme.dim)
                    }
                }
                .padding(12)
                // On the iPad the transcript takes the room above a fixed-height keyboard.
                .frame(maxHeight: ScreenMetrics.isPad ? .infinity : 160)
                .background(Theme.well, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1)
                }
                VirtualKeyboardView(onPress: press, onRelease: release)
                    .id(keyboardID)
                    .frame(maxHeight: ScreenMetrics.isPad ? 440 : .infinity)
            }
            .padding(Theme.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ground.ignoresSafeArea())
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
        .tint(Theme.amber)
        // A full-screen cover on the iPad otherwise hides the status bar and lets the
        // navigation bar ride up under it.
        .statusBarHidden(false)
    }

    private var details: some View {
        HStack {
            Text("Keys become steps you can edit. Hold a modifier with one finger, or tap it to hold it for the next key.")
                .font(.footnote)
                .foregroundStyle(Theme.dim)
            Spacer(minLength: 12)
            Toggle("Send to PC", isOn: $sendToPC).fixedSize().font(.subheadline)
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
