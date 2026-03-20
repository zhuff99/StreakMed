import SwiftUI

// MARK: - Identifiable date wrapper (used by HistoryView + MonthCalendarView)

struct IdentifiableDate: Identifiable {
    let id   = UUID()
    let date: Date
}

// MARK: - DayDetailSheet

struct DayDetailSheet: View {
    let date: Date
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) private var dismiss

    private var cal:   Calendar { Calendar.current }
    private var today: Date     { cal.startOfDay(for: DebugDateManager.shared.currentDate) }
    private var dayStart: Date  { cal.startOfDay(for: date) }

    private var isToday:  Bool { dayStart == today }
    private var isPast:   Bool { dayStart <  today }
    private var isFuture: Bool { dayStart >  today }

    private var isPreRegistration: Bool {
        guard let earliest = store.medications.compactMap({ $0.createdAt }).min() else { return false }
        return dayStart < cal.startOfDay(for: earliest)
    }

    private var scheduledMeds: [Medication] {
        store.medications.filter { $0.isScheduled(on: date) }
    }

    private var isSkipped: Bool { store.isSkipped(date) }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Date header ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sectionLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                            .tracking(0.8)

                        HStack(spacing: 10) {
                            Text(dateString)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppTheme.text)

                            Spacer()

                            // Skip button — visible for today and past non-pre-registration days
                            if !isFuture && !isPreRegistration {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        store.toggleSkipDay(date)
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: isSkipped ? "moon.slash.fill" : "moon.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(isSkipped ? "Unskip" : "Skip Day")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(isSkipped ? AppTheme.textMuted : Color(hex: "7B68EE"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSkipped
                                                ? AppTheme.surfaceAlt
                                                : Color(hex: "7B68EE").opacity(0.15))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSkipped
                                                    ? AppTheme.border
                                                    : Color(hex: "7B68EE").opacity(0.4),
                                                    lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().background(AppTheme.border)

                    // ── Medication list ───────────────────────────────────
                    if scheduledMeds.isEmpty {
                        Text(isPreRegistration
                             ? "The app wasn't installed yet on this date."
                             : "No medications scheduled for this day.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textDim)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(scheduledMeds) { med in
                                DayDetailMedRow(med: med, date: date)
                            }
                        }
                    }


                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private var sectionLabel: String {
        if isToday   { return "TODAY" }
        if isFuture  { return "UPCOMING" }
        return "HISTORY"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - DayDetailMedRow

private struct DayDetailMedRow: View {
    let med:  Medication
    let date: Date
    @EnvironmentObject var store: MedicationStore

    private var takenLog:    DoseLog? { store.logForMed(med, on: date) }
    private var isTaken:     Bool     { takenLog != nil }
    private var isSkippedDay: Bool    { store.isSkipped(date) }
    private var medColor:    Color    { Color(hex: med.color ?? "4FFFB0") }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: date)
    }
    private var today: Date {
        Calendar.current.startOfDay(for: DebugDateManager.shared.currentDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(statusColor.opacity(0.4), lineWidth: 1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: statusSymbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusColor)
                )

            // Name + dose + notes
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isTaken ? AppTheme.text : AppTheme.textMuted)
                Text(med.dose ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                if let notes = med.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textDim.opacity(0.7))
                        .italic()
                }
            }

            Spacer()

            // Time badge
            if let log = takenLog, let t = log.takenAt {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Taken")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                    Text(formatted(t))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textDim)
                }
            } else {
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusColor)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.border, lineWidth: 1))
    }

    // MARK: - Status helpers

    private var statusColor: Color {
        if isTaken       { return AppTheme.accent }
        if isSkippedDay  { return Color(hex: "7B68EE") }
        if dayStart < today { return AppTheme.missed }
        if dayStart == today { return AppTheme.textMuted }
        return AppTheme.textDim
    }

    private var statusSymbol: String {
        if isTaken       { return "checkmark" }
        if isSkippedDay  { return "moon.fill" }
        if dayStart < today { return "xmark" }
        return "clock"
    }

    private var statusLabel: String {
        if isSkippedDay  { return "Skipped" }
        if dayStart < today { return "Missed" }
        if dayStart == today { return "Pending" }
        return "Scheduled"
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: d)
    }
}
