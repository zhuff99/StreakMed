import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var debug = DebugDateManager.shared
    @State private var weekOffset:  Int             = 0     // 0 = current week, -1 = last week, etc.
    @State private var showCalendar: Bool           = false // controls the full month calendar sheet
    @State private var detailDay:   IdentifiableDate? = nil // non-nil opens the day detail sheet

    /// Builds the array of 7 WeekDay models (Sun–Sat) for the currently selected week.
    /// weekOffset = 0 → this week, -1 → last week, and so on.
    /// Finds this week's Sunday first, then shifts by the offset to get the target Sunday.
    private var weekDays: [WeekDay] {
        let cal     = Calendar.current
        let today   = DebugDateManager.shared.currentDate
        let weekday = cal.component(.weekday, from: today)          // 1 = Sunday, 7 = Saturday
        let thisSunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
        let sunday  = cal.date(byAdding: .weekOfYear, value: weekOffset, to: thisSunday)!

        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: sunday)!
            return WeekDay(date: date, status: store.dayStatus(for: date))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("History")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.text)
                            .tracking(-0.5)
                        Text(monthYearString)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    Button { showCalendar = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                            .padding(8)
                            .background(AppTheme.accentDim)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Week strip
                WeekStrip(days: weekDays, weekOffset: $weekOffset) { tapped in
                    detailDay = IdentifiableDate(date: tapped)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Stats grid
                StatsGrid()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                // Badge shelf
                BadgeShelf()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                // Today's log
                SectionHeader(title: "Today's Log")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                if store.medications.isEmpty {
                    Text("No medications tracked yet.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textDim)
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.medications.enumerated()), id: \.element.objectID) { i, med in
                            TodayLogRow(med: med)
                                .padding(.horizontal, 24)
                            if i < store.medications.count - 1 {
                                Divider()
                                    .background(AppTheme.border)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                }

                Spacer(minLength: 32)
            }
        }
        .background(AppTheme.bg)
        .sheet(isPresented: $showCalendar) {
            MonthCalendarView()
                .environmentObject(store)
        }
        .sheet(item: $detailDay) { wrapper in
            DayDetailSheet(date: wrapper.date)
                .environmentObject(store)
        }
    }

    private var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: DebugDateManager.shared.currentDate)
    }
}

// MARK: - WeekDay model

struct WeekDay {
    let date: Date
    let status: DayStatus

    var shortDay: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }
    var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
}

// MARK: - WeekStrip

struct WeekStrip: View {
    let days:       [WeekDay]
    @Binding var weekOffset: Int
    let onDayTap:   (Date) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var weekLabel: String {
        switch weekOffset {
        case 0:  return "THIS WEEK"
        case -1: return "LAST WEEK"
        default: return "\(-weekOffset) WEEKS AGO"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Navigation row
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceAlt)
                        .cornerRadius(8)
                }

                Spacer()

                Text(weekLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .tracking(0.8)
                    .animation(.none, value: weekLabel)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset = min(weekOffset + 1, 0) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(weekOffset < 0 ? AppTheme.textMuted : AppTheme.textDim.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceAlt)
                        .cornerRadius(8)
                }
                .disabled(weekOffset >= 0)
            }

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Button { onDayTap(day.date) } label: {
                        VStack(spacing: isIPad ? 12 : 8) {
                            Text(day.shortDay)
                                .font(.system(size: isIPad ? 16 : 11, weight: .medium))
                                .foregroundColor(AppTheme.textDim)

                            dayDot(day: day)

                            Text(day.dayNumber)
                                .font(.system(size: isIPad ? 16 : 11))
                                .foregroundColor(AppTheme.textDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(AppTheme.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 1))
    }

    @ViewBuilder
    private func dayDot(day: WeekDay) -> some View {
        let color = day.status.accentColor
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.5), lineWidth: 2)
                )
                .frame(width: isIPad ? 64 : 32, height: isIPad ? 64 : 32)

            switch day.status {
            case .today:
                Circle()
                    .fill(AppTheme.blue)
                    .frame(width: isIPad ? 16 : 8, height: isIPad ? 16 : 8)
            case .future:
                EmptyView()
            default:
                Image(systemName: day.status.sfSymbol)
                    .font(.system(size: isIPad ? 20 : 11, weight: .bold))
                    .foregroundColor(day.status.accentColor)
            }
        }
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var debug = DebugDateManager.shared

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                label: "This Month",
                value: "\(store.adherenceRateThisMonth())%",
                sub:   "adherence rate",
                color: AppTheme.accent
            )
            StatCard(
                label: "Streak",
                value: "\(store.calculateStreak())",
                sub:   "days in a row",
                color: AppTheme.blue
            )
            StatCard(
                label: "Best Streak",
                value: "\(max(store.bestStreak, store.calculateStreak()))",
                sub:   "days",
                color: AppTheme.partial
            )
            StatCard(
                label: "Missed",
                value: "\(store.missedDaysThisMonth())",
                sub:   "days this month",
                color: AppTheme.missed
            )
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let sub:   String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
                .tracking(-1)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
    }
}

// MARK: - Month Calendar Sheet

struct MonthCalendarView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var monthOffset = 0          // 0 = current month, -1 = last month, etc.
    @State private var detailDay: IdentifiableDate? = nil

    private let cal        = Calendar.current
    private let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]   // column header labels
    private let columns    = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    /// The first day (midnight) of whichever month is currently displayed.
    private var firstOfMonth: Date {
        let today      = DebugDateManager.shared.currentDate
        let shifted    = cal.date(byAdding: .month, value: monthOffset, to: today)!
        let comps      = cal.dateComponents([.year, .month], from: shifted)
        return cal.date(from: comps)!
    }

    /// All dates within the displayed month, used to populate the calendar grid cells.
    private var daysInMonth: [Date] {
        let range = cal.range(of: .day, in: .month, for: firstOfMonth)!
        return range.compactMap { day in
            cal.date(bySetting: .day, value: day, of: firstOfMonth)
        }
    }

    /// Number of empty grid cells to insert before the 1st of the month so the
    /// grid aligns correctly (e.g. if the month starts on Wednesday, insert 3 blanks).
    private var leadingBlanks: Int {
        cal.component(.weekday, from: firstOfMonth) - 1
    }

    private var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: firstOfMonth)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Month navigation ──────────────────────────────────
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { monthOffset -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(10)
                        }

                        Spacer()

                        Text(monthYearString)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.text)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                monthOffset = min(monthOffset + 1, 0)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(monthOffset < 0 ? AppTheme.textMuted : AppTheme.textDim.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(10)
                        }
                        .disabled(monthOffset >= 0)
                    }

                    // ── Calendar grid ─────────────────────────────────────
                    LazyVGrid(columns: columns, spacing: 6) {

                        // Day-of-week headers (use index as ID to avoid duplicate "S"/"T" warnings)
                        ForEach(Array(dayHeaders.enumerated()), id: \.offset) { _, h in
                            Text(h)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                                .frame(maxWidth: .infinity)
                        }

                        // Leading blank cells
                        ForEach(0..<leadingBlanks, id: \.self) { _ in
                            Color.clear.frame(height: 40)
                        }

                        // Day cells (tappable)
                        ForEach(daysInMonth, id: \.self) { date in
                            Button {
                                detailDay = IdentifiableDate(date: date)
                            } label: {
                                CalendarDayCell(
                                    date:   date,
                                    status: store.dayStatus(for: date)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // ── Legend ────────────────────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 10) {
                            CalendarLegendItem(color: AppTheme.blue,        label: "Today")
                            CalendarLegendItem(color: AppTheme.accent,      label: "Complete")
                            CalendarLegendItem(color: AppTheme.missed,      label: "Missed")
                            CalendarLegendItem(color: AppTheme.partial,     label: "Partial")
                            CalendarLegendItem(color: Color(hex: "7B68EE"), label: "Skipped")
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .sheet(item: $detailDay) { wrapper in
            DayDetailSheet(date: wrapper.date)
                .environmentObject(store)
        }
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date:   Date
    let status: DayStatus

    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cellBorder, lineWidth: status == .today ? 1.5 : 0)
                )
                .frame(height: 40)

            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 13, weight: status == .today ? .bold : .medium))
                    .foregroundColor(cellFg)

                // Status dot for non-future, non-today days
                if status != .future && status != .today {
                    Circle()
                        .fill(status.accentColor)
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    private var cellBg: Color {
        switch status {
        case .perfect: return AppTheme.accent.opacity(0.18)
        case .partial:  return AppTheme.partial.opacity(0.18)
        case .missed:   return AppTheme.missed.opacity(0.15)
        case .today:    return AppTheme.blue.opacity(0.18)
        case .future:   return AppTheme.surfaceAlt.opacity(0.4)
        case .skipped:  return Color(hex: "7B68EE").opacity(0.15)
        }
    }

    private var cellFg: Color {
        switch status {
        case .perfect: return AppTheme.accent
        case .partial:  return AppTheme.partial
        case .missed:   return AppTheme.missed
        case .today:    return AppTheme.blue
        case .future:   return AppTheme.textDim
        case .skipped:  return Color(hex: "7B68EE")
        }
    }

    private var cellBorder: Color {
        status == .today ? AppTheme.blue : .clear
    }
}

// MARK: - Calendar Legend Item

private struct CalendarLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.6), lineWidth: 1))
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
    }
}

// MARK: - Today Log Row

struct TodayLogRow: View {
    let med: Medication
    @EnvironmentObject var store: MedicationStore
    @ObservedObject private var debug = DebugDateManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(store.isTakenToday(med) ? AppTheme.accent : AppTheme.textDim)
                .frame(width: 8, height: 8)

            Text("\(med.name ?? "") \(med.dose ?? "")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(store.isTakenToday(med) ? AppTheme.text : AppTheme.textMuted)

            Spacer()

            Text(timeText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(store.isTakenToday(med) ? AppTheme.accentText : AppTheme.textDim)
        }
        .padding(.vertical, 12)
    }

    private var timeText: String {
        let f = DateFormatter(); f.timeStyle = .short
        if let t = store.takenTimeToday(med) { return f.string(from: t) }
        return med.scheduledTime.map { f.string(from: $0) } ?? "—"
    }
}

// MARK: - Badge Shelf

struct BadgeShelf: View {
    @EnvironmentObject var store: MedicationStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BADGES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.8)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MedicationStore.badgeMilestones, id: \.self) { milestone in
                    BadgeTile(
                        milestone: milestone,
                        earnedDate: store.earnedBadges[milestone]
                    )
                }
            }
        }
        .padding(18)
        .background(AppTheme.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 1))
    }
}

// MARK: - Badge Tile

private struct BadgeTile: View {
    let milestone: Int
    let earnedDate: Date?

    private var isEarned: Bool { earnedDate != nil }
    private var info: (name: String, icon: String) { MedicationStore.badgeInfo(for: milestone) }

    private var badgeColor: Color {
        switch milestone {
        case 7:   return Color(hex: "FF6B35")
        case 14:  return Color(hex: "FFD166")
        case 30:  return Color(hex: "4FFFB0")
        case 60:  return Color(hex: "5B8BFF")
        case 90:  return Color(hex: "C97BFF")
        case 180: return Color(hex: "FF4F8A")
        case 365: return Color(hex: "FFD700")
        default:  return AppTheme.accent
        }
    }

    private var earnedDateString: String {
        guard let date = earnedDate else { return "" }
        let f = DateFormatter(); f.dateFormat = "M/d/yy"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isEarned ? badgeColor.opacity(0.18) : AppTheme.surfaceAlt)
                    .overlay(
                        Circle()
                            .stroke(isEarned ? badgeColor.opacity(0.5) : AppTheme.border, lineWidth: 1.5)
                    )
                    .frame(width: 52, height: 52)

                if isEarned {
                    Image(systemName: info.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(badgeColor)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.textDim)
                }
            }

            // Label
            Text(isEarned ? info.name : "\(milestone)d")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isEarned ? AppTheme.text : AppTheme.textDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Date or target
            Text(isEarned ? earnedDateString : "\(milestone) days")
                .font(.system(size: 8))
                .foregroundColor(isEarned ? AppTheme.textMuted : AppTheme.textDim)
                .lineLimit(1)
        }
    }
}
