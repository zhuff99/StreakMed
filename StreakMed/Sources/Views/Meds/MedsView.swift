import SwiftUI

struct MedsView: View {
    @EnvironmentObject var store: MedicationStore
    @State private var showAddSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("My Meds")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.text)
                            .tracking(-0.5)
                        Text(subtitleText)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    if !store.medications.isEmpty {
                        Button { showAddSheet = true } label: {
                            Text("+ Add")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(AppTheme.accentDim)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1.5)
                                )
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Medication list
                if store.medications.isEmpty {
                    MedsEmptyState { showAddSheet = true }
                        .padding(.top, 60)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.medications) { med in
                            MedManageRow(med: med)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 32)
            }
        }
        .background(AppTheme.bg)
        .sheet(isPresented: Binding(
            get: { showAddSheet && sizeClass != .regular },
            set: { showAddSheet = $0 }
        )) {
            AddMedSheet { name, dose, type, color, times, days, pills, notes in
                store.addMedication(
                    name: name, dose: dose,
                    type: type, color: color,
                    scheduledTimes: times,
                    scheduledDays: days,
                    pillsRemaining: pills,
                    notes: notes
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showAddSheet && sizeClass == .regular },
            set: { showAddSheet = $0 }
        )) {
            AddMedSheet { name, dose, type, color, times, days, pills, notes in
                store.addMedication(
                    name: name, dose: dose,
                    type: type, color: color,
                    scheduledTimes: times,
                    scheduledDays: days,
                    pillsRemaining: pills,
                    notes: notes
                )
            }
        }
    }

    private var subtitleText: String {
        let n = store.medications.count
        return n == 1 ? "1 medication" : "\(n) medications"
    }
}

// MARK: - Manage Row

struct MedManageRow: View {
    let med: Medication
    @EnvironmentObject var store: MedicationStore
    @State private var showDeleteConfirm = false
    @State private var showEditSheet     = false
    @State private var swipeOffset: CGFloat = 0      // negative = card slid left to reveal delete button
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let deleteButtonWidth: CGFloat = 80      // width of the red trash button behind the card

    var body: some View {
        ZStack(alignment: .trailing) {

            // ── Delete button (revealed behind card) ───────────────────
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    swipeOffset = 0
                }
                showDeleteConfirm = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: deleteButtonWidth)
                .frame(maxHeight: .infinity)
                .background(AppTheme.missed)
                .cornerRadius(16)
            }
            .opacity(swipeOffset < -8 ? 1 : 0)

            // ── Card ───────────────────────────────────────────────────
            HStack(spacing: 14) {
                // Icon
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(hex: med.color ?? "4FFFB0").opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color(hex: med.color ?? "4FFFB0").opacity(0.4), lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .fill(Color(hex: med.color ?? "4FFFB0"))
                            .frame(width: 12, height: 12)
                    )
                    .frame(width: 44, height: 44)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(med.name ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.text)

                    Text("\(med.dose ?? "") · \(med.type ?? "General") · \(scheduledTimeStr)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textDim)

                    if let n = med.pillsRemaining?.intValue {
                        let isLow = n <= 7
                        HStack(spacing: 4) {
                            Image(systemName: isLow ? "exclamationmark.triangle.fill" : "pills.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isLow ? AppTheme.warn : AppTheme.textDim)
                            Text("\(n) left")
                                .font(.system(size: 11, weight: isLow ? .semibold : .regular))
                                .foregroundColor(isLow ? AppTheme.warn : AppTheme.textDim)
                        }
                    }

                    if let notes = med.notes, !notes.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppTheme.textDim)
                            Text(notes)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                    }

                    if med.scheduledWeekdays.count < 7 {
                        ScheduledDaysChip(weekdays: med.scheduledWeekdays)
                    }
                }

                Spacer()

                // Edit button
                Button("Edit") { showEditSheet = true }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }
            .padding(16)
            .background(AppTheme.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
            .offset(x: swipeOffset)
            // .simultaneousGesture allows this drag to coexist with the parent ScrollView's
            // scroll gesture — using plain .gesture would cause the scroll to freeze while
            // SwiftUI decides which gesture wins.
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        // Only activate for strongly horizontal drags (ratio 2.5:1) to avoid
                        // accidentally triggering while the user is scrolling vertically.
                        guard abs(dx) > abs(dy) * 2.5 else { return }
                        if dx < 0 {
                            // Swiping left — clamp so the card never slides further than the button width
                            swipeOffset = max(dx, -deleteButtonWidth)
                        } else {
                            // Swiping right — close the revealed button
                            swipeOffset = min(0, swipeOffset + dx)
                        }
                    }
                    .onEnded { value in
                        // Snap: if dragged past 40pt → lock open; otherwise spring back closed
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            swipeOffset = value.translation.width < -40 ? -deleteButtonWidth : 0
                        }
                    }
            )
        }
        // Reset the swipe offset whenever the Edit sheet opens so the card closes cleanly.
        .onChange(of: showEditSheet) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { swipeOffset = 0 }
        }
        .sheet(isPresented: Binding(
            get: { showEditSheet && sizeClass != .regular },
            set: { showEditSheet = $0 }
        )) {
            EditMedSheet(med: med) { name, dose, type, color, times, days, pills, notes in
                store.updateMedication(
                    med,
                    name: name, dose: dose, type: type, color: color,
                    scheduledTimes: times, scheduledDays: days, pillsRemaining: pills, notes: notes
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showEditSheet && sizeClass == .regular },
            set: { showEditSheet = $0 }
        )) {
            EditMedSheet(med: med) { name, dose, type, color, times, days, pills, notes in
                store.updateMedication(
                    med,
                    name: name, dose: dose, type: type, color: color,
                    scheduledTimes: times, scheduledDays: days, pillsRemaining: pills, notes: notes
                )
            }
        }
        .alert("Delete \(med.name ?? "medication")?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { store.deleteMedication(med) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the medication and stop all reminders. Your dose history will be preserved.")
        }
    }

    private var scheduledTimeStr: String {
        let f = DateFormatter(); f.timeStyle = .short
        let times = med.doseTimesArray
        if times.isEmpty { return med.scheduledTime.map { f.string(from: $0) } ?? "" }
        return times.map { f.string(from: $0) }.joined(separator: ", ")
    }
}

// MARK: - Scheduled days chip (used in MedManageRow)

struct ScheduledDaysChip: View {
    let weekdays: Set<Int>

    // Calendar.weekday order: 1=Sun, 2=Mon … 7=Sat  → display S M T W T F S
    private let order: [(id: Int, label: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(order, id: \.id) { item in
                let active = weekdays.contains(item.id)
                Text(item.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(active ? AppTheme.accent : AppTheme.textDim.opacity(0.5))
                    .frame(width: 14, height: 14)
                    .background(active ? AppTheme.accentDim : Color.clear)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Empty state

struct MedsEmptyState: View {
    let onAdd: () -> Void
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
                Text("Add the medications you take daily and start building your streak.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button(action: onAdd) {
                Text("+ Add your first medication")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentDim)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}
