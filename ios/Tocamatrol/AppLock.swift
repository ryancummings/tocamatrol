import LocalAuthentication
import SwiftUI

/// Face ID lock: macros can hold passwords and other private text, so with the lock
/// on, the app opens locked and locks again after it has been away for the chosen time. Face ID
/// falls back to the device passcode. While the app is not in front, a cover hides it from the
/// app switcher.
@MainActor
final class AppLock: ObservableObject {
    /// How long the app may be away before it locks again.
    enum Delay: Int, CaseIterable, Identifiable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .immediately: "Immediately"
            case .oneMinute: "1 min"
            case .fiveMinutes: "5 min"
            case .fifteenMinutes: "15 min"
            }
        }
    }

    @Published private(set) var locked: Bool
    @Published private(set) var authenticating = false
    @Published private(set) var failure: String?
    /// The last time the app left the front, while unlocked.
    private var leftAt: Date?

    init() {
        locked = Self.enabled
    }

    static var enabled: Bool {
        #if DEBUG
        if UITestSupport.isActive { return false }
        #endif
        return UserDefaults.standard.bool(forKey: SettingsKey.requireUnlock)
    }

    static var delay: Delay {
        Delay(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.unlockDelay)) ?? .immediately
    }

    /// "Face ID", "Touch ID", "Optic ID", or "Passcode" on a device without biometrics.
    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    /// Face ID or a passcode is set up, so the lock can be turned on.
    static var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func didLeave() {
        guard Self.enabled, !locked else { return }
        if Self.delay == .immediately { locked = true } else { leftAt = Date() }
    }

    func didReturn() {
        guard Self.enabled else {
            locked = false
            return
        }
        if let leftAt, Date().timeIntervalSince(leftAt) >= Double(Self.delay.rawValue) { locked = true }
        leftAt = nil
        if locked { Task { await unlock() } }
    }

    /// Asks for Face ID, or the passcode. True once the person is checked.
    @discardableResult
    func unlock() async -> Bool {
        guard locked else { return true }
        guard !authenticating else { return false }
        authenticating = true
        defer { authenticating = false }
        if await Self.authenticate(reason: "Unlock Tocamatrol to use your macros.") {
            locked = false
            failure = nil
            return true
        }
        failure = "Not unlocked."
        return false
    }

    /// Checks the person now, as before the lock is turned on or off.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Over everything while locked, and over the app while it is not in front.
struct LockCover: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            HalftoneBackground().ignoresSafeArea()
            if lock.locked {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Theme.inkShadow)
                            .frame(width: 72, height: 72)
                            .offset(x: 3, y: 4)
                        Circle()
                            .fill(Theme.popYellow)
                            .overlay { Circle().strokeBorder(Theme.popInk, lineWidth: 2.5) }
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.popInk)
                    }
                    Text("Tocamatrol is locked")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    if let failure = lock.failure {
                        Text(failure).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Unlock with \(AppLock.methodName)",
                              systemImage: AppLock.methodName == "Face ID" ? "faceid" : "lock.open")
                            .font(.headline)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(ConsoleTileButtonStyle(size: 48, active: true))
                    .disabled(lock.authenticating)
                }
            } else {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.inkBorder.opacity(0.45))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
