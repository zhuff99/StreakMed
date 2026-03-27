import SwiftUI

struct ProgressCard: View {
    let taken:      Int
    let total:      Int
    let streak:     Int
    let bestStreak: Int
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(taken) / Double(total)
    }
    private var isComplete: Bool { taken == total && total > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(alignment: .top) {
                // Count
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY'S PROGRESS")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .tracking(0.8)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(taken)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.text)
                        Text("/\(total)")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                // Status badge
                Text(isComplete ? "✓ Complete" : "\(total - taken) pending")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isComplete ? AppTheme.accent : AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isComplete ? AppTheme.accentDim : AppTheme.surfaceAlt)
                    .cornerRadius(12)
            }
            .padding(.bottom, 16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppTheme.surfaceAlt)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.blue],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(.easeInOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.bottom, 10)

            // Footer row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(streak > 0 ? AppTheme.partial : AppTheme.textDim)
                    Text("\(streak) day streak")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                if bestStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.partial)
                        Text("Best: \(bestStreak)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                }

                Text("\(Int(progress * 100))% done")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accentText)
            }
        }
        .padding(22)
        .background(AppTheme.surface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
