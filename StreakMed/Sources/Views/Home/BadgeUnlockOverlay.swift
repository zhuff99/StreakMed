import SwiftUI

/// Full-screen celebration overlay shown when the user earns a new streak badge.
/// Displays the badge icon, name, and milestone with a confetti-burst animation.
/// Auto-dismisses after 5 seconds or on tap.
struct BadgeUnlockOverlay: View {
    let milestone: Int
    let onDismiss: () -> Void

    @State private var showContent  = false
    @State private var showBadge    = false
    @State private var showConfetti = false
    @State private var pulseScale: CGFloat = 1.0

    private var info: (name: String, icon: String) {
        MedicationStore.badgeInfo(for: milestone)
    }

    private var badgeColor: Color {
        switch milestone {
        case 3:   return Color(hex: "5BC0EB")   // sky blue
        case 7:   return Color(hex: "FF6B35")   // warm orange
        case 14:  return Color(hex: "FFD166")   // gold
        case 30:  return AppTheme.accent        // mint
        case 60:  return AppTheme.blue          // blue
        case 90:  return Color(hex: "C97BFF")   // purple
        case 180: return Color(hex: "FF4F8A")   // pink
        case 365: return Color(hex: "FFD700")   // champion gold
        default:  return AppTheme.accent
        }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .opacity(showContent ? 1 : 0)
                .onTapGesture { dismiss() }

            // Confetti particles
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Badge content
            VStack(spacing: 0) {
                Spacer()

                // Glow ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(badgeColor.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)

                    // Inner ring
                    Circle()
                        .fill(badgeColor.opacity(0.25))
                        .frame(width: 130, height: 130)

                    // Badge circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [badgeColor, badgeColor.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: badgeColor.opacity(0.5), radius: 20)

                    // Icon
                    Image(systemName: info.icon)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showBadge ? 1.0 : 0.3)
                .opacity(showBadge ? 1.0 : 0)

                // Badge name
                Text(info.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                    .padding(.top, 28)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Streak milestone
                Text("\(milestone) Day Streak!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(badgeColor)
                    .padding(.top, 8)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Subtitle
                Text("Keep up the great work")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.top, 16)
                    .opacity(showContent ? 1 : 0)

                Spacer()

                // Dismiss hint
                Text("Tap anywhere to continue")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            // Staggered entrance animation
            withAnimation(.easeOut(duration: 0.4)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
                showBadge = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                showConfetti = true
            }
            // Pulsing glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                pulseScale = 1.15
            }
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            showContent = false
            showBadge = false
            showConfetti = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Confetti

/// Simple particle system that launches coloured circles upward from the bottom.
private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let elapsed = now - p.start
                    guard elapsed < p.lifetime else { continue }
                    let progress = elapsed / p.lifetime
                    let x = p.x * size.width + p.drift * CGFloat(elapsed) * 30
                    let y = size.height - CGFloat(elapsed) * p.speed + CGFloat(progress * progress) * 200
                    let opacity = 1.0 - progress
                    let sz = p.size * (1.0 - CGFloat(progress) * 0.5)
                    let rect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(p.color)
                    )
                }
            }
        }
        .onAppear { spawnParticles() }
    }

    private func spawnParticles() {
        let colors: [Color] = [
            Color(hex: "4FFFB0"), Color(hex: "5B8BFF"), Color(hex: "FFD166"),
            Color(hex: "FF7A50"), Color(hex: "C97BFF"), Color(hex: "FF4F8A"),
            .white
        ]
        let now = Date().timeIntervalSinceReferenceDate
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.1...0.9),
                speed: CGFloat.random(in: 150...350),
                drift: CGFloat.random(in: -1.5...1.5),
                size: CGFloat.random(in: 4...10),
                color: colors.randomElement()!,
                lifetime: Double.random(in: 1.5...3.0),
                start: now + Double.random(in: 0...0.5)
            )
        }
    }
}

private struct ConfettiParticle {
    let x:        CGFloat
    let speed:    CGFloat
    let drift:    CGFloat
    let size:     CGFloat
    let color:    Color
    let lifetime: Double
    let start:    Double
}
