import SwiftUI

struct AppLockView: View {
    @ObservedObject var lockManager: AppLockManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.doksyPrimary, Color(red: 0.91, green: 0.35, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text(AppConstants.displayName)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Locked with \(lockManager.biometryName)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                if let error = lockManager.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    Task { await lockManager.unlockIfNeeded() }
                } label: {
                    HStack {
                        if lockManager.isAuthenticating {
                            ProgressView()
                                .tint(.vaultAccent)
                        } else {
                            Image(systemName: "faceid")
                        }
                        Text("Unlock with \(lockManager.biometryName)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.vaultAccent)
                }
                .disabled(lockManager.isAuthenticating)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}

struct AppLockOverlayModifier: ViewModifier {
    @ObservedObject private var lockManager = AppLockManager.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(lockManager.isEnabled && lockManager.isLocked)

            if lockManager.isEnabled && lockManager.isLocked {
                AppLockView(lockManager: lockManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
        .task {
            await lockManager.unlockIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lockManager.lockIfNeeded()
            case .active:
                Task { await lockManager.unlockIfNeeded() }
            default:
                break
            }
        }
    }
}

extension View {
    func appLockOverlay() -> some View {
        modifier(AppLockOverlayModifier())
    }
}
