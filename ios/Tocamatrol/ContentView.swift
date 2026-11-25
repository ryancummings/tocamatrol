import SwiftUI
import TocaCore

struct ContentView: View {
    @EnvironmentObject private var controller: InputController
    @EnvironmentObject private var link: DongleLink
    @State private var showSettings = false
    @State private var showConnections = false

    @AppStorage(SettingsKey.pointerSpeed) private var pointerSpeed = InputSettings().pointerSpeed
    @AppStorage(SettingsKey.pointerAcceleration) private var pointerAcceleration = InputSettings().pointerAcceleration
    @AppStorage(SettingsKey.scrollSpeed) private var scrollSpeed = InputSettings().scrollSpeed
    @AppStorage(SettingsKey.scrollAcceleration) private var scrollAcceleration = InputSettings().scrollAcceleration
    @AppStorage(SettingsKey.scrollCoast) private var scrollCoast = InputSettings().scrollCoast
    @AppStorage(SettingsKey.naturalScroll) private var naturalScroll = InputSettings().naturalScroll
    @AppStorage(SettingsKey.showDebug) private var showDebug = false
    @AppStorage(SettingsKey.inputMode) private var mode = InputMode.keys

    private var settings: InputSettings {
        InputSettings(pointerSpeed: pointerSpeed, pointerAcceleration: pointerAcceleration,
                      scrollSpeed: scrollSpeed, scrollAcceleration: scrollAcceleration,
                      scrollCoast: scrollCoast, naturalScroll: naturalScroll)
    }

    var body: some View {
        VStack(spacing: 10) {
            TopBar(showSettings: $showSettings, showConnections: $showConnections, mode: $mode)
            switch mode {
            case .keys:
                MacroPadView()
            case .trackpad:
                trackpad
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, ScreenMetrics.isPad ? Theme.margin : 4)
        // Edge swipes reach the keys and trackpad first; the system gesture needs a second swipe.
        .defersSystemGestures(on: .all)
        .persistentSystemOverlays(ScreenMetrics.isPad ? .hidden : .automatic)
        .background {
            ZStack {
                Theme.ground.ignoresSafeArea()
                HalftoneBackground().ignoresSafeArea()
            }
        }
        .tint(Theme.tint)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showConnections) { ConnectionManagerView() }
        .onAppear { controller.apply(settings) }
        .onChange(of: settings) { _, new in controller.apply(new) }
    }

    private var trackpad: some View {
        TrackpadView(controller: controller)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.inkShadow)
                    .offset(x: 3, y: 4)
            }
            .padding(.trailing, 3)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Text("1 finger moves · tap clicks · tap-hold drags\n2 fingers scroll · 2-finger tap right-clicks · 3-finger middle-clicks")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Theme.inkBorder, lineWidth: 1.5)
                    }
                    .padding(16)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                if showDebug { DebugOverlay().padding(12) }
            }
    }
}

private struct TopBar: View {
    @EnvironmentObject private var link: DongleLink
    @Binding var showSettings: Bool
    @Binding var showConnections: Bool
    @Binding var mode: InputMode

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showConnections = true
            } label: {
                ConnectionChip(state: link.state, name: link.currentID.map { link.name(of: $0) }, rssi: link.rssi)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Connect, switch or forget a dongle")
            .accessibilityIdentifier("connection")
            Spacer(minLength: 4)
            ConsoleSegmented(options: InputMode.allCases, selection: $mode) { mode in
                switch mode {
                case .keys:
                    Label(ScreenMetrics.isPad ? "Macros" : "Keys", systemImage: "square.grid.3x3.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .accessibilityLabel("Macro pad")
                case .trackpad:
                    Label(ScreenMetrics.isPad ? "Trackpad" : "Pad", systemImage: "rectangle.and.hand.point.up.left.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .accessibilityLabel("Trackpad")
                }
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(ConsoleTileButtonStyle())
            .accessibilityLabel("Settings")
        }
        .frame(height: 44)
    }
}

/// The dongle in use: an ink-ringed status light, its code on iPhone, and its name + signal on iPad.
private struct ConnectionChip: View {
    let state: DongleLink.State
    /// "Tocamatrol A1B2"; nil when no dongle is chosen.
    let name: String?
    let rssi: Int?

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(state.color)
                .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 1.5) }
                .frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            if ScreenMetrics.isPad, state == .ready, let rssi {
                Text("\(rssi) dBm").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .black)).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .comicPanel(fill: Theme.surface, cornerRadius: Theme.radius, borderWidth: 2, shadowOffset: 2)
        .fixedSize()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dongle: \(state.title)")
    }

    private var label: String {
        guard let name, state == .ready || state == .connecting || state == .securing else { return state.title }
        let code = name.hasPrefix("Tocamatrol ") ? String(name.dropFirst("Tocamatrol ".count)) : name
        return ScreenMetrics.isPad ? name.uppercased() : code
    }
}

private struct DebugOverlay: View {
    @EnvironmentObject private var controller: InputController
    @EnvironmentObject private var link: DongleLink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("link: \(String(describing: link.state))")
            if let info = link.dongleInfo { Text("dongle: \(info)") }
            Text("packets/s: \(controller.stats.packetsPerSecond)")
        }
        .font(.caption.monospaced())
        .foregroundStyle(Theme.text)
        .padding(8)
        .comicPanel(fill: Theme.surface.opacity(0.95), cornerRadius: 8, borderWidth: 1.5, shadowOffset: 2)
        .allowsHitTesting(false)
    }
}
