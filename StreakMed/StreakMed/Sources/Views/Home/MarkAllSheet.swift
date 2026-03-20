import SwiftUI

struct MarkAllSheet: View {
    let pendingItems: [DoseItem]
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // ── Scrollable content ─────────────────────────────────────
            ScrollView {
                VStack(spacing: 0) {
                    // Handle bar
                    Capsule()
                        .fill(AppTheme.border)
                        .frame(width: 36, height: 4)
                        .padding(.top, 14)
                        .padding(.bottom, 24)

                    // Icon
                    Circle()
                        .fill(AppTheme.accentDim)
                        .overlay(Circle().stroke(AppTheme.accent.opacity(0.4), lineWidth: 2))
                        .overlay(
                            Image(systemName: "pills.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppTheme.accent)
                        )
                        .frame(width: 56, height: 56)
                        .padding(.bottom, 16)

                    // Title
                    Text("Mark all as taken?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.text)
                        .padding(.bottom, 8)

                    // Subtitle
                    Text(
                        "This will mark all \(pendingItems.count) remaining dose\(pendingItems.count == 1 ? "" : "s") as taken right now."
                    )
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                    // Med pills preview
                    MedPillsFlow(items: pendingItems)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }

            // ── Buttons — always pinned at bottom ─────────────────────
            Divider()
                .background(AppTheme.border)

            VStack(spacing: 12) {
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Yes, mark all taken")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.accentFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .cornerRadius(16)
                }

                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.surface.ignoresSafeArea())
    }
}

// MARK: - Pill row (wrapping)

struct MedPillsFlow: View {
    let items: [DoseItem]

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
            spacing: 8
        ) {
            ForEach(items) { item in
                let med      = item.medication
                let colorHex = med.color ?? "4FFFB0"
                let times    = med.doseTimesArray
                let label: String = {
                    let name = med.name ?? ""
                    if times.count > 1, item.doseIndex < times.count {
                        return "\(name) (\(Self.timeFmt.string(from: times[item.doseIndex])))"
                    }
                    return name
                }()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: colorHex).opacity(0.08))
                .overlay(Capsule().stroke(Color(hex: colorHex).opacity(0.4), lineWidth: 1))
                .clipShape(Capsule())
            }
        }
    }
}
