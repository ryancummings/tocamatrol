import SwiftUI
import TocaCore

/// The dongle connection manager: the dongle in use and its state, the dongles this
/// phone has paired with, nearby dongles, and setup instructions.
struct ConnectionManagerView: View {
    @EnvironmentObject private var link: DongleLink
    @Environment(\.dismiss) private var dismiss
    @State private var forgetting: DongleLink.KnownDongle?
    /// Bumped after each forget, for the haptic.
    @State private var forgotCount = 0
    @State private var renaming = false
    @State private var newName = ""

    private static let flasherURL = URL(string: "https://ryancummings.github.io/tocamatrol/#flash")!

    var body: some View {
        NavigationStack {
            Form {
                currentSection
                pairedSection
                nearbySection
                Section {
                    Link(destination: Self.flasherURL) {
                        HStack {
                            Label("Flash an ESP32-S3 Dongle", systemImage: "cpu")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text("Forget removes a dongle from this list. iOS keeps its pairing until you forget it in Settings → Bluetooth, and the dongle keeps it until its BOOT button is held for 5 seconds, which makes it forget every phone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dim)
                } header: {
                    SectionLabel(text: "Hardware setup")
                }
                .consoleRows()
            }
            .consoleForm()
            .tint(Theme.tint)
            .navigationTitle("Dongle")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Forget \(forgetting.map { link.name(of: $0.id) } ?? "dongle")?", isPresented: Binding(
                get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }), presenting: forgetting
            ) { dongle in
                Button("Cancel", role: .cancel) {}
                Button("Forget Device", role: .destructive) {
                    withAnimation { link.forget(dongle.id) }
                    forgotCount += 1
                }
            } message: { _ in
                Text("To use it again, pair it again with its pairing window open.")
            }
            .sensoryFeedback(.success, trigger: forgotCount)
            .alert("Rename Dongle", isPresented: $renaming) {
                TextField("Name", text: $newName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Rename") { link.rename(to: newName) }
            } message: {
                Text("Up to \(DongleName.maxLength) letters, digits and punctuation. Leave empty to restore the default name.")
            }
        }
        .onAppear { link.startBrowsing() }
        .onDisappear { link.stopBrowsing() }
    }

    // MARK: - In use

    @ViewBuilder private var currentSection: some View {
        Section {
            if let id = link.currentID {
                HStack(alignment: .firstTextBaseline) {
                    Text(link.name(of: id)).font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    StatusLabel(state: link.state)
                }
                Text(link.state.explanation).font(.subheadline).foregroundStyle(Theme.muted)
                if link.canRename {
                    Button("Rename…") {
                        newName = link.name(of: id)
                        renaming = true
                    }
                }
                if link.state == .ready {
                    LabeledContent("Signal") {
                        Text(signalText(link.rssi))
                            .font(.subheadline.monospaced())
                            .foregroundStyle(Theme.muted)
                    }
                    if let info = link.dongleInfo {
                        LabeledContent("Dongle") {
                            Text(info)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                switch link.state {
                case .refused:
                    Button("Try again", action: link.retry)
                case .bondLost:
                    PairingSteps(forgetInSettings: link.name(of: id))
                default:
                    EmptyView()
                }
                if let dongle = link.known.first(where: { $0.id == id }) {
                    Button("Forget This Device", role: .destructive) { forgetting = dongle }
                }
            } else {
                Text("No dongle in use. Pick one from the list below.")
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            SectionLabel(text: "In use")
        }
        .consoleRows()
    }

    // MARK: - Paired

    @ViewBuilder private var pairedSection: some View {
        let others = link.known.filter { $0.id != link.currentID }
        if !others.isEmpty {
            Section {
                ForEach(others) { dongle in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.name(of: dongle.id))
                                .fontWeight(.semibold)
                            Text(link.nearbyDongle(dongle.id).map { "Nearby · \(signalText($0.rssi))" } ?? "Not nearby")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button("Use") { link.use(dongle.id) }
                            .buttonStyle(ConsoleTileButtonStyle(active: true))
                    }
                    .swipeActions {
                        Button("Forget") { forgetting = dongle }
                            .tint(.red)
                    }
                }
            } header: {
                SectionLabel(text: "Paired with this \(deviceWord)")
            } footer: {
                Text("A paired dongle connects without pressing its button. Swipe left to forget one.")
                    .foregroundStyle(Theme.dim)
            }
            .consoleRows()
        }
    }

    // MARK: - Nearby

    @ViewBuilder private var nearbySection: some View {
        let knownIDs = Set(link.known.map(\.id))
        let newOnes = link.nearby.filter { !knownIDs.contains($0.id) && $0.id != link.currentID }
        Section {
            if newOnes.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking for dongles… Is the new one plugged in?").foregroundStyle(Theme.muted)
                }
            }
            ForEach(newOnes) { dongle in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dongle.name)
                            .fontWeight(.semibold)
                        Text(signalText(dongle.rssi)).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    switch dongle.pairingWindowOpen {
                    case true?:
                        Button("Pair") { link.use(dongle.id) }
                            .buttonStyle(ConsoleTileButtonStyle(active: true))
                    case false?:
                        Text("Press BOOT button")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    case nil:
                        Button("Pair") { link.use(dongle.id) }
                            .buttonStyle(ConsoleTileButtonStyle())
                    }
                }
            }
        } header: {
            SectionLabel(text: "New dongles nearby")
        } footer: {
            PairingSteps(forgetInSettings: nil).foregroundStyle(Theme.dim)
        }
        .consoleRows()
    }

    private var deviceWord: String { ScreenMetrics.isPad ? "iPad" : "iPhone" }

    private func signalText(_ rssi: Int?) -> String {
        guard let rssi else { return "signal unknown" }
        let word = rssi >= -60 ? "strong" : rssi >= -75 ? "good" : "weak"
        return "\(word) signal (\(rssi) dBm)"
    }
}

/// How to pair a dongle, step by step.
private struct PairingSteps: View {
    /// When set, iOS still holds an old pairing with this dongle that must go first.
    let forgetInSettings: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("To pair a dongle:").fontWeight(.semibold)
            if let forgetInSettings {
                Text("1. In iOS Settings → Bluetooth, tap ⓘ next to \(forgetInSettings) and Forget This Device.")
                Text("2. Press the dongle's BOOT button briefly (60 s pairing window; LED blinks fast or screen shows Pair now).")
                Text("3. Return here and tap Pair, then accept the iOS Bluetooth Pairing Request.")
            } else {
                Text("1. Plug in the dongle or briefly press its BOOT button. The pairing window stays open for 60 seconds (fast amber blink or Pair now on screen).")
                Text("2. Tap Pair next to the dongle, then tap Pair on the iOS prompt.")
                Text("3. Steady green means connected and ready.")
            }
        }
        .font(.footnote)
    }
}

/// The link state as an ink-ringed status light and a label.
struct StatusLabel: View {
    let state: DongleLink.State

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.color)
                .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 1.5) }
                .frame(width: 9, height: 9)
            Text(state.title)
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
    }
}

extension DongleLink.State {
    var title: String {
        switch self {
        case .bluetoothOff: "Bluetooth off"
        case .unauthorized: "Bluetooth not allowed"
        case .unsupported: "No Bluetooth LE"
        case .noDongle: "No dongle"
        case .connecting: "Connecting"
        case .securing: "Pairing"
        case .ready: "Connected"
        case .refused: "Not paired"
        case .bondLost: "Pairing lost"
        }
    }

    var explanation: String {
        switch self {
        case .bluetoothOff: "Turn on Bluetooth in Control Center."
        case .unauthorized: "Allow Bluetooth for Tocamatrol in iOS Settings → Tocamatrol."
        case .unsupported: "This device has no Bluetooth LE."
        case .noDongle: "Choose a dongle to connect to."
        case .connecting: "Waiting for the dongle. Is it plugged in and in range?"
        case .securing: "If a Bluetooth Pairing Request appears, tap Pair."
        case .ready: "Keys and pointer go to the PC."
        case .refused: "The dongle's pairing window was closed. Press its BOOT button briefly; this connects again as soon as its pairing window opens."
        case .bondLost: "The dongle has forgotten this device (its BOOT button was held for 5 seconds), but iOS still remembers the dongle."
        }
    }

    var color: Color {
        switch self {
        case .ready: Theme.green
        case .connecting, .securing: Theme.popYellow
        case .noDongle: Theme.dim
        default: Theme.red
        }
    }
}
