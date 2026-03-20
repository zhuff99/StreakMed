import SwiftUI
import CoreData

// MARK: - Root Onboarding Container

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.managedObjectContext) private var viewContext

    @State private var step = 0

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            switch step {
            case 0:
                OnboardingWelcome { advance() }
                    .transition(forwardTransition)
            case 1:
                OnboardingNotifications { advance() }
                    .transition(forwardTransition)
            case 2:
                OnboardingMedsSetup(
                    context: viewContext,
                    onComplete: { completeOnboarding() }
                )
                .transition(forwardTransition)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private var forwardTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() { step += 1 }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Step 1: Welcome

struct OnboardingWelcome: View {
    let onNext: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPad: Bool { sizeClass == .regular }

    var body: some View {
        if isPad {
            // iPad: everything as one centered block, vertically and horizontally
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentDim)
                        .frame(width: 120, height: 120)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: 14) {
                    Text("StreakMed")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(AppTheme.text)
                        .tracking(-1.2)

                    Text("Never miss a dose.\nBuild a streak.")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Feature rows — intrinsic width, centered as a group
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingFeatureRow(icon: "checkmark.circle.fill",    text: "Track every medication daily",        isPad: true)
                    OnboardingFeatureRow(icon: "flame.fill",               text: "Build streaks and track your best",   isPad: true)
                    OnboardingFeatureRow(icon: "bell.badge.fill",          text: "Smart reminders that work",           isPad: true)
                    OnboardingFeatureRow(icon: "pills.fill",               text: "Refill alerts before you run out",    isPad: true)
                    OnboardingFeatureRow(icon: "chart.bar.fill",           text: "Full history and adherence reports",  isPad: true)
                    OnboardingFeatureRow(icon: "calendar.badge.checkmark", text: "Per-day scheduling for any routine",  isPad: true)
                }
                .fixedSize()   // shrink-wrap to content width so centering works
                .padding(.vertical, 4)

                OnboardingCTA(label: "Get Started", style: .primary, action: onNext)
                    .frame(maxWidth: 480)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // fills screen
        } else {
            // iPhone: CTA pinned to bottom, content centered above it
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentDim)
                            .frame(width: 90, height: 90)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }

                    VStack(spacing: 10) {
                        Text("StreakMed")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(AppTheme.text)
                            .tracking(-1.2)

                        Text("Never miss a dose.\nBuild a streak.")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        OnboardingFeatureRow(icon: "checkmark.circle.fill",    text: "Track every medication daily")
                        OnboardingFeatureRow(icon: "flame.fill",               text: "Build streaks and track your best")
                        OnboardingFeatureRow(icon: "bell.badge.fill",          text: "Smart reminders that work")
                        OnboardingFeatureRow(icon: "pills.fill",               text: "Refill alerts before you run out")
                        OnboardingFeatureRow(icon: "chart.bar.fill",           text: "Full history and adherence reports")
                        OnboardingFeatureRow(icon: "calendar.badge.checkmark", text: "Per-day scheduling for any routine")
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                OnboardingCTA(label: "Get Started", style: .primary, action: onNext)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Step 2: Notifications

struct OnboardingNotifications: View {
    let onNext: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPad: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: isPad ? 36 : 24) {

                ZStack {
                    Circle()
                        .fill(AppTheme.accentDim)
                        .frame(width: isPad ? 120 : 90, height: isPad ? 120 : 90)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: isPad ? 52 : 38, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: isPad ? 14 : 10) {
                    Text("Stay on Track")
                        .font(.system(size: isPad ? 44 : 32, weight: .bold))
                        .foregroundColor(AppTheme.text)
                        .tracking(-0.8)

                    Text("Enable notifications so StreakMed can remind you when it's time to take each medication.")
                        .font(.system(size: isPad ? 19 : 16))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: isPad ? 560 : .infinity)

            Spacer()

            VStack(spacing: 14) {
                OnboardingCTA(label: "Enable Notifications", style: .primary) {
                    NotificationManager.shared.requestPermission { _ in onNext() }
                }

                Button(action: onNext) {
                    Text("Not now")
                        .font(.system(size: isPad ? 17 : 15, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: isPad ? 480 : .infinity)
            .padding(.horizontal, 28)
            .padding(.bottom, isPad ? 64 : 52)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 3: Add medications (multi-add)

struct OnboardingMedsSetup: View {
    @StateObject private var store: MedicationStore
    let onComplete: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isPad: Bool { sizeClass == .regular }

    @State private var showAddSheet = false

    init(context: NSManagedObjectContext, onComplete: @escaping () -> Void) {
        _store      = StateObject(wrappedValue: MedicationStore(context: context))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            VStack(spacing: isPad ? 16 : 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentDim)
                        .frame(width: isPad ? 100 : 72, height: isPad ? 100 : 72)
                    Image(systemName: "pills.fill")
                        .font(.system(size: isPad ? 42 : 30, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }

                Text("Add Your Medications")
                    .font(.system(size: isPad ? 38 : 28, weight: .bold))
                    .foregroundColor(AppTheme.text)
                    .tracking(-0.6)

                Text("Add as many as you take. You can always add more or edit them later from the Meds tab.")
                    .font(.system(size: isPad ? 17 : 15))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, isPad ? 0 : 28)
            }
            .frame(maxWidth: isPad ? 560 : .infinity)
            .padding(.top, isPad ? 64 : 52)
            .padding(.bottom, 28)

            // ── Medication list ───────────────────────────────────────────
            ScrollView {
                VStack(spacing: 10) {
                    if store.medications.isEmpty {
                        VStack(spacing: 6) {
                            Text("No medications added yet")
                                .font(.system(size: isPad ? 17 : 15, weight: .medium))
                                .foregroundColor(AppTheme.textDim)
                            Text("Tap below to add your first one.")
                                .font(.system(size: isPad ? 15 : 13))
                                .foregroundColor(AppTheme.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(store.medications) { med in
                            OnboardingMedRow(med: med, isPad: isPad)
                        }
                    }

                    Button { showAddSheet = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: isPad ? 22 : 18))
                                .foregroundColor(AppTheme.accent)
                            Text(store.medications.isEmpty ? "Add Medication" : "Add Another")
                                .font(.system(size: isPad ? 17 : 15, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Spacer()
                        }
                        .padding(16)
                        .background(AppTheme.accentDim)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: isPad ? 560 : .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            // ── CTA ───────────────────────────────────────────────────────
            VStack(spacing: 14) {
                OnboardingCTA(
                    label: store.medications.isEmpty ? "Skip for Now" : "Get Started",
                    style: store.medications.isEmpty ? .secondary : .primary,
                    action: onComplete
                )

                if !store.medications.isEmpty {
                    Text("You can add more medications anytime in the Meds tab.")
                        .font(.system(size: isPad ? 14 : 12))
                        .foregroundColor(AppTheme.textDim)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: isPad ? 480 : .infinity)
            .padding(.horizontal, 28)
            .padding(.bottom, isPad ? 64 : 52)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.bg)
        // iPhone: present as a draggable bottom sheet
        .sheet(isPresented: Binding(
            get: { showAddSheet && sizeClass != .regular },
            set: { showAddSheet = $0 }
        )) {
            AddMedSheet { name, dose, type, color, times, days, pills, notes in
                store.addMedication(
                    name: name, dose: dose, type: type, color: color,
                    scheduledTimes: times, scheduledDays: days, pillsRemaining: pills, notes: notes
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // iPad: fullScreenCover fills the screen instead of the narrow centered modal sheet
        .fullScreenCover(isPresented: Binding(
            get: { showAddSheet && sizeClass == .regular },
            set: { showAddSheet = $0 }
        )) {
            AddMedSheet { name, dose, type, color, times, days, pills, notes in
                store.addMedication(
                    name: name, dose: dose, type: type, color: color,
                    scheduledTimes: times, scheduledDays: days, pillsRemaining: pills, notes: notes
                )
            }
        }
    }
}

// MARK: - Added medication preview row

private struct OnboardingMedRow: View {
    let med: Medication
    var isPad: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: med.color ?? "4FFFB0"))
                .frame(width: isPad ? 12 : 10, height: isPad ? 12 : 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(med.name ?? "")
                    .font(.system(size: isPad ? 17 : 15, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Text(med.dose ?? "")
                    .font(.system(size: isPad ? 15 : 13))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.system(size: isPad ? 22 : 18))
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Shared Onboarding Helpers

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    var isPad: Bool = false

    var body: some View {
        HStack(spacing: isPad ? 18 : 14) {
            Image(systemName: icon)
                .font(.system(size: isPad ? 22 : 18))
                .foregroundColor(AppTheme.accent)
                .frame(width: isPad ? 32 : 28)
            Text(text)
                .font(.system(size: isPad ? 18 : 15, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
            Spacer()
        }
    }
}

enum OnboardingCTAStyle { case primary, secondary }

struct OnboardingCTA: View {
    let label:  String
    let style:  OnboardingCTAStyle
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: sizeClass == .regular ? 20 : 17, weight: .bold))
                .foregroundColor(style == .primary ? AppTheme.accentFG : AppTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, sizeClass == .regular ? 22 : 18)
                .background(style == .primary ? AppTheme.accent : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(style == .secondary ? AppTheme.border : Color.clear, lineWidth: 1)
                )
                .cornerRadius(18)
        }
    }
}
