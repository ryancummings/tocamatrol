import SwiftUI

@main
struct TocamatrolApp: App {
    @StateObject private var controller = InputController()
    @StateObject private var macros = MacroStore()
    @StateObject private var lock = AppLock()
    @AppStorage(SettingsKey.appearanceMode) private var appearanceMode = AppearanceMode.system
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        UITestSupport.prepare()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .environmentObject(controller.link)
                .environmentObject(macros)
                .environmentObject(lock)
                .overlay {
                    // Locked, or away with the lock on: hidden, and in the app switcher too.
                    if lock.locked || (AppLock.enabled && scenePhase != .active) {
                        LockCover().environmentObject(lock)
                    }
                }
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            let active = phase == .active
            // Keep the screen awake while the trackpad is in use.
            UIApplication.shared.isIdleTimerDisabled = active
            if active { controller.start() } else { controller.stop() }
            switch phase {
            case .active: lock.didReturn()
            case .background: lock.didLeave()
            default: break
            }
        }
    }
}
