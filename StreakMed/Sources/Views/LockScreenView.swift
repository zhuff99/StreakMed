import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    let onUnlock: () -> Void

    @State private var biometryType: LABiometryType = .none

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Lock icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accentDim)
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.bottom, 24)

                Text("StreakMed")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.text)
                    .tracking(-0.5)
                    .padding(.bottom, 8)

                Text("Unlock to view your medications")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)

                Spacer()

                // Unlock button
                Button { authenticate() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometryIcon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(biometryLabel)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.accentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            detectBiometryType()
            authenticate()
        }
    }

    // MARK: - Helpers

    private var biometryIcon: String {
        switch biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.open.fill"
        }
    }

    private var biometryLabel: String {
        switch biometryType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default:       return "Unlock with Passcode"
        }
    }

    private func detectBiometryType() {
        let ctx = LAContext()
        var err: NSError?
        ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        biometryType = ctx.biometryType
    }

    /// Uses .deviceOwnerAuthentication so Face ID / Touch ID automatically
    /// falls back to the device passcode if biometrics fail or aren't set up.
    private func authenticate() {
        let ctx = LAContext()
        ctx.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock StreakMed to view your medications"
        ) { success, _ in
            DispatchQueue.main.async {
                if success { onUnlock() }
            }
        }
    }
}
