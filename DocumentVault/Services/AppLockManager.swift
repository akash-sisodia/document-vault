import Foundation
import LocalAuthentication
import Combine

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    private static let enabledKey = "isAppLockEnabled"

    @Published var isLocked = false
    @Published var isAuthenticating = false
    @Published var lastError: String?
    @Published private(set) var isEnabled: Bool

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if isEnabled {
            isLocked = true
        }
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Device Passcode"
        }
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let succeeded = await authenticate(reason: "Turn on \(biometryName) lock for \(AppConstants.displayName).")
            guard succeeded else { return false }
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            isEnabled = true
            isLocked = false
            return true
        } else {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            isEnabled = false
            isLocked = false
            lastError = nil
            return true
        }
    }

    func lockIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlockIfNeeded() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        _ = await authenticate(reason: "Unlock \(AppConstants.displayName) to view your documents.")
    }

    func authenticate(reason: String) async -> Bool {
        guard canUseBiometrics else {
            lastError = "\(biometryName) is not available on this device. Set up Face ID or a passcode in iOS Settings."
            return false
        }

        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isLocked = false
                lastError = nil
            }
            return success
        } catch {
            let laError = error as? LAError
            if laError?.code == .userCancel || laError?.code == .appCancel || laError?.code == .systemCancel {
                lastError = nil
            } else {
                lastError = error.localizedDescription
            }
            return false
        }
    }
}
