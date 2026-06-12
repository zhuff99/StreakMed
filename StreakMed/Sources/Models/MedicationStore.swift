import CoreData
import SwiftUI
import Combine
import WidgetKit

// MARK: - Day Status

/// Represents how well a user did on a given calendar day.
/// Used to colour the week strip squares and the month calendar cells.
enum DayStatus: Equatable {
    case perfect, partial, missed, today, future, skipped

    var accentColor: Color {
        switch self {
        case .perfect: return AppTheme.accent
        case .partial:  return AppTheme.partial
        case .missed:   return AppTheme.missed
        case .today:    return AppTheme.blue
        case .future:   return AppTheme.textDim
        case .skipped:  return Color(hex: "7B68EE")
        }
    }

    var sfSymbol: String {
        switch self {
        case .perfect: return "checkmark"
        case .partial:  return "minus"
        case .missed:   return "xmark"
        case .today:    return "circle.fill"
        case .future:   return ""
        case .skipped:  return "moon.fill"
        }
    }
}

// MARK: - DoseItem

/// Represents a single dose event — one medication at one specific time index.
struct DoseItem: Identifiable {
    let medication: Medication
    let doseIndex: Int

    var id: String { (medication.id?.uuidString ?? UUID().uuidString) + "-\(doseIndex)" }

    var scheduledTime: Date? {
        let times = medication.doseTimesArray
        guard doseIndex < times.count else { return medication.scheduledTime }
        return times[doseIndex]
    }
}

// MARK: - Medication scheduling helpers

/// Shared formatter used to serialise/deserialise dose times as "HH:mm" strings
/// stored in CoreData's `doseTimes` field (e.g. "08:00,14:00,20:00").
private let doseTimeFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
}()

extension Medication {
    /// Number of pills consumed per dose, extracted from the dose string.
    /// "2 × 10 mg" → 2, "10 mg" → 1
    var quantityPerDose: Int {
        guard let d = dose else { return 1 }
        if let crossRange = d.range(of: " × "),
           let qty = Int(d[d.startIndex..<crossRange.lowerBound]) {
            return qty
        }
        return 1
    }

    /// Weekday integers (Calendar.weekday: 1=Sun … 7=Sat) on which this med is taken.
    /// Returns all 7 days if scheduledDays is unset (backwards-compatible default).
    var scheduledWeekdays: Set<Int> {
        guard let s = scheduledDays, !s.isEmpty else { return Set(1...7) }
        return Set(s.split(separator: ",").compactMap { Int($0) })
    }

    /// Returns true if this medication is scheduled to be taken on the given date,
    /// based on its day-of-week settings (e.g. Mon/Wed/Fri only).
    func isScheduled(on date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return scheduledWeekdays.contains(weekday)
    }

    /// All scheduled dose times as Date objects (time components only, anchored to today).
    /// Falls back to `scheduledTime` for legacy single-dose medications.
    var doseTimesArray: [Date] {
        let cal = Calendar.current
        let anchor = Date()
        if let raw = doseTimes, !raw.isEmpty {
            return raw.split(separator: ",").compactMap { part -> Date? in
                guard let base = doseTimeFmt.date(from: String(part)) else { return nil }
                let comps = cal.dateComponents([.hour, .minute], from: base)
                return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: anchor)
            }
        }
        return scheduledTime.map { [$0] } ?? []
    }
}

// MARK: - MedicationStore

final class MedicationStore: ObservableObject {
    let viewContext: NSManagedObjectContext

    @Published var medications:  [Medication] = []
    @Published var todayLogs:    [DoseLog]    = []
    @Published var bestStreak:   Int          = UserDefaults.standard.integer(forKey: "bestStreak")
    @Published var streakShields: Int         = 0
    @Published var skippedDays:  Set<String>  = Set(UserDefaults.standard.stringArray(forKey: "skippedDays") ?? [])
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Streak badges

    /// All streak milestones in ascending order.
    static let badgeMilestones = [3, 7, 14, 30, 60, 90, 180, 365]

    /// Dictionary of earned badges: milestone → date earned.
    @Published var earnedBadges: [Int: Date] = {
        guard let data = UserDefaults.standard.data(forKey: "earnedBadges"),
              let decoded = try? JSONDecoder().decode([Int: Double].self, from: data)
        else { return [:] }
        return decoded.mapValues { Date(timeIntervalSince1970: $0) }
    }()

    /// Set by `checkAndAwardBadges` when a new badge is unlocked; the UI clears it after showing.
    @Published var newlyUnlockedBadge: Int? = nil

    /// Persists the earned badges dictionary to UserDefaults.
    /// Public wrapper for debug/testing access.
    func saveBadgesPublic() { saveBadges() }

    /// Persists the earned badges dictionary to UserDefaults.
    private func saveBadges() {
        let encoded = earnedBadges.mapValues { $0.timeIntervalSince1970 }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: "earnedBadges")
        }
    }

    /// Checks the current streak against milestones and awards any newly reached badges.
    /// Called from `updateBestStreak()` after every state change.
    func checkAndAwardBadges() {
        let streak = calculateStreak()
        for milestone in Self.badgeMilestones {
            if streak >= milestone && earnedBadges[milestone] == nil {
                earnedBadges[milestone] = Date()
                saveBadges()
                newlyUnlockedBadge = milestone
                // Only announce the highest new badge (they unlock in order)
            }
        }
    }

    /// Returns display info for a badge milestone.
    static func badgeInfo(for milestone: Int) -> (name: String, icon: String) {
        switch milestone {
        case 3:   return ("First Steps",      "star.fill")
        case 7:   return ("Week Warrior",     "flame.fill")
        case 14:  return ("Two Week Streak",  "bolt.fill")
        case 30:  return ("Month Master",     "trophy.fill")
        case 60:  return ("Two Month Run",    "medal.fill")
        case 90:  return ("Quarter Strong",   "shield.fill")
        case 180: return ("Half Year Hero",   "crown.fill")
        case 365: return ("Year Champion",    "diamond.fill")
        default:  return ("Streak",           "star.fill")
        }
    }

    // MARK: - Widget snapshot

    /// App Group suite shared with the StreakMedWidget extension.
    private static let widgetGroupID = "group.com.zacharyhuff.StreakMed"

    /// Writes a lightweight snapshot of today's progress to the shared App Group
    /// UserDefaults so the home/lock-screen widget can read live data, then asks
    /// WidgetKit to reload its timelines immediately.
    func updateWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: Self.widgetGroupID) else { return }
        defaults.set(takenTodayCount,     forKey: "widget_taken")
        defaults.set(scheduledTodayCount, forKey: "widget_total")
        defaults.set(calculateStreak(),   forKey: "widget_streak")
        if let next = pendingDoseItems.first {
            defaults.set(next.medication.name ?? "",                           forKey: "widget_next_name")
            defaults.set(next.scheduledTime?.timeIntervalSince1970 ?? 0,       forKey: "widget_next_time")
        } else {
            defaults.removeObject(forKey: "widget_next_name")
            defaults.removeObject(forKey: "widget_next_time")
        }

        // Full pending-dose list so the interactive widget (iOS 17+) can offer
        // a "Take" button and advance to the following dose after a tap.
        let pending: [[String: Any]] = pendingDoseItems.compactMap { item in
            guard let id = item.medication.id?.uuidString else { return nil }
            return [
                "id":   id,
                "idx":  item.doseIndex,
                "name": item.medication.name ?? "",
                "time": item.scheduledTime?.timeIntervalSince1970 ?? 0,
            ]
        }
        defaults.set(try? JSONSerialization.data(withJSONObject: pending), forKey: "widget_pending")

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Replays dose actions queued by the widget's "Take" button (iOS 17+).
    /// The widget extension never writes to CoreData directly — it records
    /// {medID, doseIndex, takenAt} in the App Group and we run each action
    /// through the normal markTaken() path here, preserving the tap timestamp.
    private func processWidgetActions() {
        guard let defaults = UserDefaults(suiteName: Self.widgetGroupID),
              let data     = defaults.data(forKey: "widget_actions"),
              let actions  = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
              !actions.isEmpty
        else { return }

        defaults.removeObject(forKey: "widget_actions")

        for action in actions {
            guard let idString = action["medID"] as? String,
                  let medID    = UUID(uuidString: idString),
                  let med      = medications.first(where: { $0.id == medID })
            else { continue }

            let doseIndex = action["doseIndex"] as? Int ?? 0
            // The widget always records real-world time. If the dev-tools date
            // simulator is active, remap onto the simulated "today" so the
            // replayed dose appears on the day the app is displaying.
            let takenAt: Date
            if DebugDateManager.shared.overrideDate != nil {
                takenAt = DebugDateManager.shared.currentDate
            } else {
                takenAt = (action["takenAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
                          ?? DebugDateManager.shared.currentDate
            }

            // Skip if a log already exists for this med+dose on that day
            // (e.g. the user also marked it in-app before this replay ran).
            let day = Calendar.current.startOfDay(for: takenAt)
            let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
            req.predicate = NSPredicate(
                format: "medication == %@ AND doseIndex == %d AND scheduledDate == %@ AND status == %@",
                med, doseIndex, day as NSDate, "taken"
            )
            req.fetchLimit = 1
            if let existing = try? viewContext.fetch(req), !existing.isEmpty { continue }

            markTaken(med, doseIndex: doseIndex, at: takenAt)
        }
    }

    // MARK: - Skip-day helpers

    /// Formats dates as "yyyy-MM-dd" strings for use as skip-day keys in UserDefaults.
    private static let skipFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.calendar = Calendar.current; return f
    }()

    /// Converts a Date to a stable string key for the skipped-days set (e.g. "2024-03-15").
    private func skipKey(for date: Date) -> String { Self.skipFmt.string(from: date) }

    /// Returns true if the user has manually marked this date as skipped.
    /// Skipped days don't count as missed and don't break the streak.
    func isSkipped(_ date: Date) -> Bool { skippedDays.contains(skipKey(for: date)) }

    /// Adds or removes a date from the skipped-days set and immediately persists it to UserDefaults.
    func toggleSkipDay(_ date: Date) {
        let key = skipKey(for: date)
        if skippedDays.contains(key) { skippedDays.remove(key) } else { skippedDays.insert(key) }
        UserDefaults.standard.set(Array(skippedDays), forKey: "skippedDays")
        // Manually fire objectWillChange because Set mutations don't always trigger @Published
        objectWillChange.send()
    }

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        refresh()

        // Auto-refresh when the debug date changes so Today/History
        // update immediately without needing a manual store.refresh() call.
        DebugDateManager.shared.$overrideDate
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Refresh whenever the app returns to the foreground.
        // Registered here (on the model) rather than in a SwiftUI view so it
        // can never be missed due to view lifecycle timing issues.
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    // MARK: - Refresh

    func refresh() {
        fetchMedications()
        fetchTodayLogs()         // must precede replay — markTaken's double-log
        processWidgetActions()   // guard reads todayLogs, which would otherwise
        updateBestStreak()       // be stale and silently drop widget actions
        updateWidgetSnapshot()
    }

    /// Recalculates the streak, updates the all-time best if it's been beaten,
    /// and checks whether any new badge milestones have been reached.
    private func updateBestStreak() {
        let result = computeStreak()
        streakShields = result.shields
        if result.streak > bestStreak {
            bestStreak = result.streak
            UserDefaults.standard.set(result.streak, forKey: "bestStreak")
        }
        checkAndAwardBadges()
    }

    /// Fetches all active medications from CoreData, sorted by the user's drag-reorder position.
    private func fetchMedications() {
        let req: NSFetchRequest<Medication> = Medication.fetchRequest()
        req.predicate       = NSPredicate(format: "isActive == YES")
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        medications = (try? viewContext.fetch(req)) ?? []
    }

    /// Fetches all DoseLog entries whose scheduledDate falls within "today"
    /// (midnight–midnight of the debug/real current date). This powers the
    /// isTaken checks and the Today tab's taken/pending lists.
    private func fetchTodayLogs() {
        let cal    = Calendar.current
        let start  = cal.startOfDay(for: DebugDateManager.shared.currentDate)
        let end    = cal.date(byAdding: .day, value: 1, to: start)!

        #if DEBUG
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        print("🗓 fetchTodayLogs: range \(fmt.string(from: start)) → \(fmt.string(from: end))")
        print("🗓 currentDate = \(fmt.string(from: DebugDateManager.shared.currentDate)), overrideDate = \(DebugDateManager.shared.overrideDate.map { fmt.string(from: $0) } ?? "nil")")
        #endif

        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            start as NSDate, end as NSDate
        )
        let result = (try? viewContext.fetch(req)) ?? []

        #if DEBUG
        print("🗓 fetchTodayLogs: found \(result.count) logs, meds count = \(medications.count)")
        for log in result {
            print("   → log scheduledDate=\(log.scheduledDate.map { fmt.string(from: $0) } ?? "nil") status=\(log.status ?? "nil") med=\(log.medication?.name ?? "nil")")
        }
        #endif

        todayLogs = result
    }

    // MARK: - Today helpers

    /// Check if a specific dose (by index) has been taken today.
    func isTaken(_ med: Medication, doseIndex: Int) -> Bool {
        todayLogs.contains {
            $0.medication == med && $0.status == "taken" && Int($0.doseIndex) == doseIndex
        }
    }

    /// True only when ALL doses for a medication are taken today.
    func isTakenToday(_ med: Medication) -> Bool {
        let count = med.doseTimesArray.count
        guard count > 0 else { return false }
        return (0..<count).allSatisfy { isTaken(med, doseIndex: $0) }
    }

    /// Returns the time any dose of this medication was taken today (used for the single-dose display).
    func takenTimeToday(_ med: Medication) -> Date? {
        todayLogs.first { $0.medication == med && $0.status == "taken" }?.takenAt
    }

    /// Returns the exact time a specific dose index was taken today (used for multi-dose display).
    func takenTime(_ med: Medication, doseIndex: Int) -> Date? {
        todayLogs.first {
            $0.medication == med && $0.status == "taken" && Int($0.doseIndex) == doseIndex
        }?.takenAt
    }

    /// Only meds scheduled for today (respects day-of-week settings).
    var scheduledTodayMeds: [Medication] {
        medications.filter { $0.isScheduled(on: DebugDateManager.shared.currentDate) }
    }

    /// All individual dose items scheduled for today, sorted by time.
    var scheduledTodayDoseItems: [DoseItem] {
        scheduledTodayMeds
            .flatMap { med in med.doseTimesArray.indices.map { DoseItem(medication: med, doseIndex: $0) } }
            .sorted { ($0.scheduledTime ?? .distantPast) < ($1.scheduledTime ?? .distantPast) }
    }

    /// Doses the user still needs to take today (drives the "Upcoming" list on the Today tab).
    var pendingDoseItems: [DoseItem] { scheduledTodayDoseItems.filter { !isTaken($0.medication, doseIndex: $0.doseIndex) } }
    /// Doses already taken today (drives the "Taken" list on the Today tab).
    var takenDoseItems:   [DoseItem] { scheduledTodayDoseItems.filter {  isTaken($0.medication, doseIndex: $0.doseIndex) } }

    var takenTodayCount: Int { takenDoseItems.count }
    /// Total dose items scheduled for today (used by ProgressCard).
    var scheduledTodayCount: Int { scheduledTodayDoseItems.count }

    // MARK: - Mark taken

    /// Records a dose as taken: creates a DoseLog entry, decrements pills on hand,
    /// fires a low-supply notification if needed, and cancels today's reminder.
    /// `at` overrides the log timestamp — used when replaying widget actions so
    /// the recorded time is the moment the user tapped, not when the app opened.
    func markTaken(_ med: Medication, doseIndex: Int = 0, at time: Date? = nil) {
        guard !isTaken(med, doseIndex: doseIndex) else { return }   // prevent double-logging

        let log = DoseLog(context: viewContext)
        log.id            = UUID()
        log.medication    = med
        log.doseIndex     = Int16(doseIndex)
        let now           = time ?? DebugDateManager.shared.currentDate
        log.takenAt       = now
        log.scheduledDate = Calendar.current.startOfDay(for: now)
        log.status        = "taken"

        // Decrement pill count once per dose taken
        if let remaining = med.pillsRemaining?.intValue {
            let newRemaining = max(0, remaining - med.quantityPerDose)
            med.pillsRemaining = NSNumber(value: newRemaining)
            if newRemaining <= 7 {
                NotificationManager.shared.scheduleRefillNotification(for: med, remaining: newRemaining)
            }
        }

        save()
        fetchTodayLogs()
        updateBestStreak()
        updateWidgetSnapshot()

        // Cancel this dose's notification for today and reschedule for tomorrow
        NotificationManager.shared.cancelTodayNotification(for: med, doseIndex: doseIndex)
    }

    /// Marks every pending dose for today as taken in one batch (called by "Mark All Taken").
    func markAllTaken() {
        pendingDoseItems.forEach { markTaken($0.medication, doseIndex: $0.doseIndex) }
    }

    // MARK: - Undo taken

    /// Reverses a single markTaken: deletes the DoseLog, restores pill count,
    /// re-schedules the notification, and refreshes state.
    func undoTaken(_ med: Medication, doseIndex: Int = 0) {
        guard let log = todayLogs.first(where: {
            $0.medication == med && $0.status == "taken" && Int($0.doseIndex) == doseIndex
        }) else { return }

        // Restore pill count
        if let remaining = med.pillsRemaining?.intValue {
            med.pillsRemaining = NSNumber(value: remaining + med.quantityPerDose)
        }

        viewContext.delete(log)
        save()
        fetchTodayLogs()
        updateBestStreak()
        updateWidgetSnapshot()

        // Re-schedule the notification for this dose
        NotificationManager.shared.scheduleNotification(for: med)
    }

    // MARK: - Streak
    // A "rest day" (no meds scheduled) is skipped — it neither counts nor breaks the streak.

    /// Walks backwards day-by-day from today (or yesterday if today isn't complete yet),
    /// counting consecutive "perfect" days. Rest days (no meds scheduled) and intentionally
    /// skipped days are silently stepped over — they don't add to the count but they also
    /// don't break it. Stops as soon as a non-perfect day is found or the 1-year lookback
    /// limit is hit.
    // MARK: - Streak shields

    /// One shield is earned per `shieldEarnInterval` consecutive perfect days,
    /// banked up to `shieldCap`. A missed day silently consumes a shield and
    /// the streak survives; the History calendar still shows the miss honestly.
    static let shieldEarnInterval = 30
    static let shieldCap          = 2

    struct StreakResult {
        let streak:  Int
        let shields: Int   // currently banked, after any spends
    }

    func calculateStreak() -> Int { computeStreak().streak }

    /// Walks forward from the lookback cutoff so shields are always earned
    /// chronologically before the miss they absorb. Fully derived from the
    /// log history — no separate shield persistence to drift out of sync.
    func computeStreak() -> StreakResult {
        guard !medications.isEmpty else { return StreakResult(streak: 0, shields: 0) }

        let cal    = Calendar.current
        let today  = cal.startOfDay(for: DebugDateManager.shared.currentDate)
        // Cap lookback at 1 year to avoid iterating indefinitely on old accounts
        let cutoff = cal.date(byAdding: .year, value: -1, to: today)!

        // One fetch for the whole window, bucketed by day — the forward walk
        // visits every day of the year, so per-day count queries would be slow.
        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND status == 'taken'", cutoff as NSDate
        )
        var takenByDay: [Date: Int] = [:]
        for log in (try? viewContext.fetch(req)) ?? [] {
            guard let day = log.scheduledDate.map({ cal.startOfDay(for: $0) }) else { continue }
            takenByDay[day, default: 0] += 1
        }

        var streak     = 0
        var perfectRun = 0   // consecutive perfect days since the last shield was earned
        var shields    = 0
        var day        = cutoff

        while day <= today {
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let scheduledForDay = medications.filter { $0.isScheduled(on: day) }

            // Rest days and intentionally-skipped days neither break nor count
            if scheduledForDay.isEmpty || isSkipped(day) {
                day = next
                continue
            }

            let totalDoses = scheduledForDay.reduce(0) { $0 + max(1, $1.doseTimesArray.count) }
            let complete   = takenByDay[day, default: 0] >= totalDoses

            if complete {
                streak     += 1
                perfectRun += 1
                if perfectRun >= Self.shieldEarnInterval && shields < Self.shieldCap {
                    shields    += 1
                    perfectRun  = 0
                }
            } else if day == today {
                // Doses still pending today — never breaks the streak or spends
                // a shield mid-day; today simply doesn't count yet.
                break
            } else if shields > 0 {
                shields    -= 1   // shield absorbs the miss, streak survives
                perfectRun  = 0
            } else {
                streak     = 0
                perfectRun = 0
            }
            day = next
        }

        return StreakResult(streak: streak, shields: shields)
    }

    // MARK: - Log lookup

    /// Returns the taken DoseLog for a specific medication on a specific day, or nil.
    func logForMed(_ med: Medication, on date: Date) -> DoseLog? {
        let cal      = Calendar.current
        let startDay = cal.startOfDay(for: date)
        let endDay   = cal.date(byAdding: .day, value: 1, to: startDay)!
        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "medication == %@ AND scheduledDate >= %@ AND scheduledDate < %@ AND status == 'taken'",
            med, startDay as NSDate, endDay as NSDate
        )
        return (try? viewContext.fetch(req))?.first
    }

    // MARK: - History

    /// Determines the colour/icon status of any given calendar date for display
    /// in the week strip and month calendar. Handles: future, today, pre-registration,
    /// skipped, rest days, and partial/perfect/missed past days.
    func dayStatus(for date: Date) -> DayStatus {
        let cal      = Calendar.current
        let startDay = cal.startOfDay(for: date)
        let today    = cal.startOfDay(for: DebugDateManager.shared.currentDate)

        if startDay > today  { return .future }
        if startDay == today { return .today  }

        // Dates before the earliest medication was added have no data — show as neutral
        if let earliestCreated = medications.compactMap({ $0.createdAt }).min() {
            let appStartDay = cal.startOfDay(for: earliestCreated)
            if startDay < appStartDay { return .future }
        }

        // Intentionally skipped day — neutral, doesn't break streak
        if isSkipped(date) { return .skipped }

        // Meds scheduled for this specific weekday
        let scheduledForDay = medications.filter { $0.isScheduled(on: date) }
        // Rest day — show as neutral (future styling)
        if scheduledForDay.isEmpty { return .future }

        let endDay = cal.date(byAdding: .day, value: 1, to: startDay)!
        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@ AND status == 'taken'",
            startDay as NSDate, endDay as NSDate
        )
        let taken = (try? viewContext.count(for: req)) ?? 0
        let total = scheduledForDay.reduce(0) { $0 + max(1, $1.doseTimesArray.count) }
        if taken == 0     { return .missed  }
        if taken >= total { return .perfect }
        return .partial
    }

    /// Returns adherence % for the current calendar month (0–100),
    /// counting only days on which at least one med was scheduled.
    func adherenceRateThisMonth() -> Int {
        let cal = Calendar.current
        let now = DebugDateManager.shared.currentDate
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))
        else { return 0 }

        let daysPassed = cal.dateComponents([.day], from: monthStart, to: cal.startOfDay(for: now)).day ?? 0
        guard daysPassed > 0, !medications.isEmpty else { return 0 }

        var totalScheduled = 0
        var totalTaken     = 0

        for offset in 0..<daysPassed {
            let day = cal.date(byAdding: .day, value: offset, to: monthStart)!
            let scheduledForDay = medications.filter { $0.isScheduled(on: day) }
            guard !scheduledForDay.isEmpty else { continue }
            totalScheduled += scheduledForDay.count

            let nextDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day))!
            let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
            req.predicate = NSPredicate(
                format: "scheduledDate >= %@ AND scheduledDate < %@ AND status == 'taken'",
                cal.startOfDay(for: day) as NSDate, nextDay as NSDate
            )
            totalTaken += (try? viewContext.count(for: req)) ?? 0
        }

        return totalScheduled > 0 ? Int((Double(totalTaken) / Double(totalScheduled)) * 100) : 0
    }

    /// Count missed days this month (scheduled days with 0 taken)
    func missedDaysThisMonth() -> Int {
        let cal   = Calendar.current
        let now   = DebugDateManager.shared.currentDate
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return 0 }
        let daysPassed = cal.dateComponents([.day], from: monthStart, to: cal.startOfDay(for: now)).day ?? 0

        var missed = 0
        for offset in 0..<daysPassed {
            let day = cal.date(byAdding: .day, value: offset, to: monthStart)!
            if dayStatus(for: day) == .missed { missed += 1 }
        }
        return missed
    }

    // MARK: - CRUD

    func addMedication(
        name: String, dose: String, type: String,
        color: String, scheduledTimes: [Date], scheduledDays: Set<Int> = Set(1...7),
        pillsRemaining: Int? = nil, notes: String? = nil,
        shape: String = PillShape.capsule.rawValue
    ) {
        let med            = Medication(context: viewContext)
        med.id             = UUID()
        med.name           = name
        med.dose           = dose
        med.type           = type
        med.color          = color
        med.shape          = shape
        med.notes          = notes?.isEmpty == true ? nil : notes
        med.scheduledTime  = scheduledTimes.first
        med.doseTimes      = scheduledTimes.map { doseTimeFmt.string(from: $0) }.joined(separator: ",")
        med.scheduledDays  = scheduledDays.sorted().map { String($0) }.joined(separator: ",")
        med.pillsRemaining = pillsRemaining.map { NSNumber(value: $0) }
        med.isActive       = true
        med.createdAt      = Date()
        med.notificationID = UUID().uuidString
        med.sortOrder      = Int32(medications.count)

        save()
        fetchMedications()
        updateWidgetSnapshot()
        NotificationManager.shared.scheduleNotification(for: med)
    }

    func updateMedication(
        _ med: Medication,
        name: String, dose: String, type: String,
        color: String, scheduledTimes: [Date],
        scheduledDays: Set<Int>, pillsRemaining: Int?, notes: String? = nil,
        shape: String = PillShape.capsule.rawValue
    ) {
        med.name           = name
        med.dose           = dose
        med.type           = type
        med.color          = color
        med.shape          = shape
        med.notes          = notes?.isEmpty == true ? nil : notes
        med.scheduledTime  = scheduledTimes.first
        med.doseTimes      = scheduledTimes.map { doseTimeFmt.string(from: $0) }.joined(separator: ",")
        med.scheduledDays  = scheduledDays.sorted().map { String($0) }.joined(separator: ",")
        med.pillsRemaining = pillsRemaining.map { NSNumber(value: $0) }

        save()
        fetchMedications()
        updateWidgetSnapshot()
        NotificationManager.shared.cancelAllNotifications(for: med)
        NotificationManager.shared.scheduleNotification(for: med)
    }

    /// Soft-deletes a medication by setting isActive = false rather than removing
    /// the CoreData object, so historical DoseLogs for it are preserved in the database.
    func deleteMedication(_ med: Medication) {
        NotificationManager.shared.cancelAllNotifications(for: med)
        med.isActive = false
        save()
        fetchMedications()
        updateWidgetSnapshot()
    }

    // MARK: - Persistence

    /// Saves any pending CoreData changes to disk. Called after every mutation.
    private func save() {
        guard viewContext.hasChanges else { return }
        do    { try viewContext.save() }
        catch {
            // Validation NSErrors embed full object descriptions (med names),
            // so only log the details in debug builds.
            #if DEBUG
            print("[StreakMed] CoreData save error: \(error)")
            #endif
        }
    }
}
