import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Biometric Authentication Service

/// Manages Face ID / Touch ID authentication for app lock.
/// Toggles are stored in @AppStorage; the lock state is published
/// so the App struct can show / hide the lock overlay reactively.
@MainActor
@Observable
final class NABiometricAuth {
    static let shared = NABiometricAuth()

    // MARK: Settings
    static let appLockEnabledKey = "naice_app_lock_enabled"

    /// Persisted via @AppStorage — the owning view (Settings) binds to this.
    /// The App struct reads it to decide whether to lock on background.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.appLockEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.appLockEnabledKey) }
    }

    // MARK: Runtime state

    /// true = app content is hidden behind the lock overlay.
    private(set) var isLocked = false

    /// The last auth error, shown in the lock overlay.
    private(set) var lastError: String?

    private init() {}

    // MARK: Public API

    /// Checks whether biometrics are enrolled on this device.
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// The human-readable biometry type (Face ID / Touch ID).
    var biometryTypeLabel: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometrie"
        }
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Biometrie"
        }
    }

    /// Prompts the system biometric dialog. Returns true on success.
    @discardableResult
    func authenticate(reason: String = "nAIce entsperren") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""  // hide the "Enter Password" fallback

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lastError = error?.localizedDescription ?? "Biometrie nicht verfügbar"
            return false
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            lastError = nil
            isLocked = false
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Locks the app when it goes to background (if enabled).
    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }
}

// MARK: - App Lock Overlay View

struct NAAppLockView: View {
    @State private var biometricAuth = NABiometricAuth.shared
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.ncCyan, .ncPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("nAIce gesperrt")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)

                Text("Entsperre mit \(biometricAuth.biometryTypeLabel)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                if let error = biometricAuth.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.ncRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    isAuthenticating = true
                    Task {
                        await biometricAuth.authenticate()
                        isAuthenticating = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometricAuth.biometryTypeLabel == "Face ID"
                              ? "faceid" : "touchid")
                        Text("Entsperren")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.ncCyan, .ncPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .disabled(isAuthenticating)

                if isAuthenticating {
                    ProgressView()
                        .tint(.ncCyan)
                }

                Spacer()
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }
}
