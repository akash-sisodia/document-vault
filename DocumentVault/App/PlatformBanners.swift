import SwiftUI

struct HomeProBannerView: View {
    let accentColor: Color
    var onUpgrade: () -> Void

    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AppConstants.displayName) Pro")
                        .font(.subheadline.weight(.bold))
                    Text("Unlock family profiles")
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer()
                Text("Upgrade")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(accentColor.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsPremiumBannerView: View {
    let accentColor: Color
    var onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("\(AppConstants.displayName) Pro")
                    .font(.system(size: 18, weight: .heavy))
            }
            Text("Add family members and keep IDs, passports, and papers organized for everyone.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button(action: onUpgrade) {
                Text("Upgrade to Pro")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(4)
    }
}

struct DoksyGlassAddButton: View {
    var size: CGFloat = 34
    var iconSize: CGFloat = 15

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: iconSize, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.vaultAccent, in: Circle())
            .shadow(color: Color.vaultAccent.opacity(0.35), radius: 4, x: 0, y: 2)
            .accessibilityLabel("Add document")
    }
}

struct SettingsAppUpdateRow: View {
    let accentColor: Color
    let version: String
    var onUpdate: () -> Void

    var body: some View {
        Button(action: onUpdate) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.app.fill")
                    .foregroundStyle(accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Available")
                        .font(.body.weight(.semibold))
                    Text("Version \(version) is ready on the App Store")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("v\(version)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15), in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
