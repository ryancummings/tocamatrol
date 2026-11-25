import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MacroStore

    @AppStorage(SettingsKey.appearanceMode) private var appearanceMode = AppearanceMode.system
    @AppStorage(SettingsKey.pointerSpeed) private var pointerSpeed = InputSettings().pointerSpeed
    @AppStorage(SettingsKey.pointerAcceleration) private var pointerAcceleration = InputSettings().pointerAcceleration
    @AppStorage(SettingsKey.scrollSpeed) private var scrollSpeed = InputSettings().scrollSpeed
    @AppStorage(SettingsKey.scrollAcceleration) private var scrollAcceleration = InputSettings().scrollAcceleration
    @AppStorage(SettingsKey.scrollCoast) private var scrollCoast = InputSettings().scrollCoast
    @AppStorage(SettingsKey.naturalScroll) private var naturalScroll = InputSettings().naturalScroll
    @AppStorage(SettingsKey.showDebug) private var showDebug = false
    @AppStorage(SettingsKey.requireUnlock) private var requireUnlock = false
    @AppStorage(SettingsKey.unlockDelay) private var unlockDelay = AppLock.Delay.immediately.rawValue

    @State private var exportingDocument: MacroLibraryDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var transferAlert: TransferAlert?

    private struct TransferAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Theme")
                            .foregroundStyle(Theme.text)
                        Spacer()
                        ConsoleSegmented(options: AppearanceMode.allCases, selection: $appearanceMode) { mode in
                            Text(mode.label)
                        }
                        .fixedSize()
                    }
                } header: {
                    SectionLabel(text: "Appearance")
                } footer: {
                    Text("Auto follows iOS Dark Mode. Paper uses warm comic newsprint; Midnight uses electric indigo.")
                        .foregroundStyle(Theme.dim)
                }
                .consoleRows()

                Section {
                    slider("Pointer speed", value: $pointerSpeed, in: 0.5...3, format: "%.1f×")
                    slider("Pointer acceleration", value: $pointerAcceleration, in: 1...12, format: "%.1f× when fast")
                    slider("Scroll speed", value: $scrollSpeed, in: 2...15, format: "%.0f steps per cm")
                    slider("Scroll acceleration", value: $scrollAcceleration, in: 1...10, format: "%.1f× when fast")
                    Toggle("Natural scrolling", isOn: $naturalScroll)
                    Toggle("Flick to coast", isOn: $scrollCoast)
                } header: {
                    SectionLabel(text: "Trackpad")
                } footer: {
                    Text("Two fingers scroll both vertically and horizontally. Speeds govern slow, precise movement; acceleration scales fast swipes. 1× turns acceleration off.")
                        .foregroundStyle(Theme.dim)
                }
                .consoleRows()

                librarySection
                privacySection
                hardwareSection

                Section {
                    Toggle("Debug overlay", isOn: $showDebug)
                    Button("Reset trackpad to defaults", role: .destructive, action: resetDefaults)
                        .foregroundStyle(Theme.red)
                }
                .consoleRows()
            }
            .consoleForm()
            .tint(Theme.tint)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(isPresented: $isExporting, document: exportingDocument, contentType: .json,
                          defaultFilename: "tocamatrol-macros.json") { result in
                if case let .failure(error) = result {
                    transferAlert = TransferAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case let .success(url):
                    do {
                        let added = try store.importLibrary(from: url)
                        transferAlert = TransferAlert(
                            title: "Imported Library",
                            message: "Added \(added.pages) page(s) and \(added.macros) macro(s).")
                    } catch {
                        transferAlert = TransferAlert(title: "Import Failed", message: error.localizedDescription)
                    }
                case let .failure(error):
                    transferAlert = TransferAlert(title: "Import Failed", message: error.localizedDescription)
                }
            }
            .alert(item: $transferAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var librarySection: some View {
        Section {
            Button {
                do {
                    exportingDocument = MacroLibraryDocument(data: try store.exportData())
                    isExporting = true
                } catch {
                    transferAlert = TransferAlert(title: "Export Failed", message: error.localizedDescription)
                }
            } label: {
                Label("Export Macros & Pages…", systemImage: "square.and.arrow.up")
            }
            Button {
                isImporting = true
            } label: {
                Label("Import Macros & Pages…", systemImage: "square.and.arrow.down")
            }
        } header: {
            SectionLabel(text: "Library")
        } footer: {
            Text("Back up your pages as JSON or share them between iPhone and iPad. Imported pages are added alongside existing ones.")
                .foregroundStyle(Theme.dim)
        }
        .consoleRows()
    }

    private var privacySection: some View {
        Section {
            Toggle("Require \(AppLock.methodName)", isOn: Binding(get: { requireUnlock }, set: { on in
                Task {
                    if await AppLock.authenticate(reason: on ? "Turn on the lock for Tocamatrol." : "Turn off the lock for Tocamatrol.") {
                        requireUnlock = on
                    }
                }
            }))
            .disabled(!AppLock.available)
            .accessibilityIdentifier("requireUnlock")
            if requireUnlock {
                HStack {
                    Text("Lock after")
                    Spacer()
                    ConsoleSegmented(options: AppLock.Delay.allCases.map(\.rawValue), selection: $unlockDelay) {
                        Text(AppLock.Delay(rawValue: $0)?.label ?? "")
                    }
                    .fixedSize()
                }
            }
        } header: {
            SectionLabel(text: "Privacy")
        } footer: {
            Text(AppLock.available
                 ? "Macros can hold passwords and other private text. With this on, Tocamatrol opens locked and locks again when it has been away, and the app switcher shows it covered. Macros are stored encrypted while the device is locked."
                 : "Set up Face ID or a passcode in the Settings app to lock Tocamatrol.")
                .foregroundStyle(Theme.dim)
        }
        .consoleRows()
    }

    private var hardwareSection: some View {
        Section {
            Link(destination: URL(string: "https://ryancummings.github.io/tocamatrol/")!) {
                externalRow("Web Flasher & Hardware Guide", systemImage: "cpu")
            }
            Link(destination: URL(string: "https://github.com/ryancummings/tocamatrol")!) {
                externalRow("Source Code (MIT)", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: URL(string: "https://ryancummings.github.io/tocamatrol/privacy/")!) {
                externalRow("Privacy Policy", systemImage: "hand.raised")
            }
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Theme.muted)
            }
        } header: {
            SectionLabel(text: "Hardware & About")
        }
        .consoleRows()
    }

    private func externalRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                        format: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(Theme.highlightLabel)
            }
            Slider(value: value, in: range)
        }
    }

    private func resetDefaults() {
        let d = InputSettings()
        pointerSpeed = d.pointerSpeed
        pointerAcceleration = d.pointerAcceleration
        scrollSpeed = d.scrollSpeed
        scrollAcceleration = d.scrollAcceleration
        scrollCoast = d.scrollCoast
        naturalScroll = d.naturalScroll
    }
}

private struct MacroLibraryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
