import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var debug = DebugDateManager.shared

    @State private var showConfirmSheet  = false
    @State private var justTakenID: UUID?        // set briefly when a Take button is pressed — drives the scale animation
    @State private var showAllDoneBanner = false // shown for 2.5 s after "Mark All Taken"

    // Undo state
    @State private var undoItems: [(med: Medication, doseIndex: Int)] = []
    @State private var showUndoToast = false
    @State private var undoWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HomeHeader()
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    // Progress Card
                    ProgressCard(
                        taken:      store.takenTodayCount,
                        total:      store.scheduledTodayCount,
                        streak:     store.calculateStreak(),
                        bestStreak: store.bestStreak
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                    // Upcoming meds
                    if !store.pendingDoseItems.isEmpty {
                        SectionHeader(title: "Upcoming")
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)

                        VStack(spacing: 10) {
                            ForEach(store.pendingDoseItems) { item in
                                MedCard(med: item.medication, doseIndex: item.doseIndex, justTakenID: $justTakenID) {
                                    handleTake(item)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }

                    // Taken meds
                    if !store.takenDoseItems.isEmpty {
                        SectionHeader(title: "Taken")
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)

                        VStack(spacing: 10) {
                            ForEach(store.takenDoseItems) { item in
                                MedCard(med: item.medication, doseIndex: item.doseIndex, justTakenID: $justTakenID, onTake: nil)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }

                    // Empty state
                    if store.medications.isEmpty {
                        HomeEmptyState()
                            .padding(.top, 60)
                    }

                    // Spacer so content clears the floating button
                    Spacer(minLength: 80)
                }
            }
            .background(AppTheme.bg)

            // Floating CTA / banner
            floatingOverlay
        }
        .sheet(isPresented: $showConfirmSheet) {
            MarkAllSheet(pendingItems: store.pendingDoseItems) {
                handleMarkAll()
            }
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            store.refresh()
        }
    }

    // MARK: - Floating overlay (Mark All button / Undo toast / All Done banner)

    @ViewBuilder
    private var floatingOverlay: some View {
        if showUndoToast {
            // Undo toast — shown for 4 s after taking a dose or marking all
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(undoItems.count == 1 ? "Dose taken" : "\(undoItems.count) doses taken")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Spacer()
                Button { performUndo() } label: {
                    Text("Undo")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accentFG)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 6)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        } else if !store.pendingDoseItems.isEmpty {
            Button { showConfirmSheet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Mark All Taken")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(store.pendingDoseItems.count)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.15))
                        .clipShape(Capsule())
                }
                .foregroundColor(AppTheme.accentFG)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accent, Color(hex: "2BDEAA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, x: 0, y: 8)
            }
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.pendingDoseItems.count)

        } else if showAllDoneBanner {
            HStack(spacing: 8) {
                Text("🎉")
                Text("All done for today!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(AppTheme.accentDim)
            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.4), lineWidth: 1))
            .clipShape(Capsule())
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    /// Handles a single "Take" button tap.
    /// Fires haptic feedback, briefly scales the button via justTakenID,
    /// then after a short delay marks the dose, resets the animation state,
    /// and shows an undo toast.
    private func handleTake(_ item: DoseItem) {
        guard let id = item.medication.id else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) { justTakenID = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                store.markTaken(item.medication, doseIndex: item.doseIndex)
                justTakenID = nil
                showUndoToast(for: [(item.medication, item.doseIndex)])
            }
        }
    }

    /// Handles "Mark All Taken" confirmation.
    /// Fires a success haptic, marks all pending doses, and shows an undo toast.
    private func handleMarkAll() {
        let items = store.pendingDoseItems.map { ($0.medication, $0.doseIndex) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            store.markAllTaken()
            showUndoToast(for: items)
        }
    }

    // MARK: - Undo

    /// Shows the undo toast for the given items, auto-dismissing after 4 seconds.
    private func showUndoToast(for items: [(Medication, Int)]) {
        // Cancel any existing undo timer
        undoWorkItem?.cancel()
        undoItems = items
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showUndoToast = true
            showAllDoneBanner = false
        }
        // Auto-dismiss after 4 seconds
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                showUndoToast = false
                undoItems = []
                // Show "All done" banner if everything is taken
                if store.pendingDoseItems.isEmpty && !store.medications.isEmpty {
                    withAnimation { showAllDoneBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showAllDoneBanner = false }
                    }
                }
            }
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }

    /// Undoes the last take action — restores all doses in the undo buffer.
    private func performUndo() {
        undoWorkItem?.cancel()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for (med, idx) in undoItems {
                store.undoTaken(med, doseIndex: idx)
            }
            undoItems = []
            showUndoToast = false
        }
    }
}

// MARK: - Home Header

struct HomeHeader: View {
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: DebugDateManager.shared.currentDate)
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: DebugDateManager.shared.currentDate).uppercased()
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: DebugDateManager.shared.currentDate)
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                Text("Your Meds")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.text)
                    .tracking(-0.5)
            }
            Spacer()
            // Date — top right
            VStack(alignment: .trailing, spacing: 2) {
                Text(dayString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textDim)
                Text(dateString)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }
}

// MARK: - Empty State

struct HomeEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentDim)
                    .frame(width: 90, height: 90)
                Image(systemName: "pills.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(AppTheme.accent.opacity(0.6))
            }
            VStack(spacing: 8) {
                Text("No medications yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                Text("Add your medications to start tracking your doses and building your streak.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Takes the user straight to the Meds tab so they don't have to hunt for it
            Button {
                NotificationCenter.default.post(name: .navigateToMeds, object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Medications")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(AppTheme.accentFG)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .cornerRadius(14)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
