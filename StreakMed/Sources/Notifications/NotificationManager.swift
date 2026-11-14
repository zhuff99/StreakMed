import UserNotifications
import CoreData

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Asks iOS for permission if it has never been asked and the in-app Reminders
    /// toggle is on. Before 1.2.1 the only prompt lived in onboarding, so anyone who
    /// tapped "Not now" there had Reminders showing ON in Settings while iOS had never
    /// been asked — nothing was delivered and StreakMed didn't appear in iOS Settings.
    /// `completion(true)` only when permission was just granted (caller reschedules).
    func requestIfNeeded(completion: @escaping (Bool) -> Void) {
        guard Self.remindersEnabled else { completion(false); return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.requestPermission(completion: completion)
        }
    }

    /// The in-app "Reminders" toggle. Default (true) is registered in StreakMedApp.init.
    static var remindersEnabled: Bool {
        UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }

    var permissionStatus: UNAuthorizationStatus = .notDetermined

    /// "Mark as Taken" tapped while the app wasn't running: the response can
    /// arrive before ContentView is listening, so it's parked here too.
    var pendingMarkTakenID: String?

    /// Clears the red app-icon badge (every reminder sets it to 1).
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    /// Maps any reminder ID ("…_dose_1", "…_dose_1_followup", "…_dose_1_snooze")
    /// back to its medication + dose index.
    func doseFor(notificationID id: String, in meds: [Medication]) -> (Medication, Int)? {
        var base = id
        while base.hasSuffix("_snooze") { base = String(base.dropLast("_snooze".count)) }
        if let r = base.range(of: #"_wd[1-7]$"#, options: .regularExpression) { base.removeSubrange(r) }
        if base.hasSuffix("_followup") { base = String(base.dropLast("_followup".count)) }
        for med in meds {
            guard let medBase = med.notificationID else { continue }
            for i in 0..<med.doseSlots where base == doseNotifID(baseID: medBase, doseIndex: i) {
                return (med, i)
            }
        }
        return nil
    }

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionStatus = settings.authorizationStatus
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule
    //
    // Every dose has two reminder streams: the reminder (dose time − lead) and
    // the missed-dose follow-up (dose time + N hours). A daily med gets one
    // repeating [hour, minute] trigger per stream (ID "…_dose_i"). A med on
    // specific weekdays gets one repeating [weekday, hour, minute] trigger per
    // weekday (ID "…_dose_i_wdN", N = dose weekday) — before 1.2.1 those meds
    // were reminded and nagged every day of the week.

    private func reminderContent(for med: Medication, name: String, doseIndex: Int,
                                 totalDoses: Int, leadMinutes: Int) -> UNMutableNotificationContent {
        let content        = UNMutableNotificationContent()
        content.title      = notifTitle(name: name, doseIndex: doseIndex,
                                        totalDoses: totalDoses, leadMinutes: leadMinutes)
        content.body       = med.dose == nil ? "Don't forget your medication." : "Take \(med.doseLabel)"
        content.sound      = .default
        content.badge      = 1
        // Dose times are exactly what Apple's time-sensitive level is
        // for — these break through Focus modes (user-revocable per app).
        content.interruptionLevel  = .timeSensitive
        content.categoryIdentifier = "MEDICATION_REMINDER"
        return content
    }

    private func followUpContent(name: String, doseIndex: Int, totalDoses: Int) -> UNMutableNotificationContent {
        let content   = UNMutableNotificationContent()
        content.title = totalDoses > 1
            ? "Still haven't taken \(name) · Dose \(doseIndex + 1)"
            : "Still haven't taken \(name)"
        content.body  = "Don't let your streak slip — log your dose when you're ready."
        content.sound = .default
        content.badge = 1
        content.interruptionLevel  = .timeSensitive
        content.categoryIdentifier = "MEDICATION_REMINDER"   // Mark as Taken works here too
        return content
    }

    private var followUpMinutes: Int? {
        guard UserDefaults.standard.bool(forKey: "missedDoseReminderEnabled") else { return nil }
        let h = UserDefaults.standard.integer(forKey: "missedDoseFollowUpHours")
        return max(1, h == 0 ? 2 : h) * 60
    }

    /// Adds one reminder stream firing `offsetMinutes` from `doseTime` on every
    /// day the med is scheduled. `quietToday`: today's dose is already logged,
    /// so if today's occurrence is still ahead, that one entry becomes a
    /// one-shot at its next occurrence (rescheduleAll restores the repeat the
    /// next day the app opens).
    private func addStream(id: String, content: UNNotificationContent, med: Medication,
                           doseTime: Date, offsetMinutes: Int, quietToday: Bool) {
        let cal   = Calendar.current
        let now   = Date()
        let today = cal.startOfDay(for: now)
        let dc    = cal.dateComponents([.hour, .minute], from: doseTime)
        func fire(onDoseDay day: Date) -> Date {
            let dose = cal.date(bySettingHour: dc.hour ?? 8, minute: dc.minute ?? 0, second: 0, of: day) ?? day
            return dose.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        }
        func add(_ id: String, _ trigger: UNNotificationTrigger) {
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req) { error in
                #if DEBUG
                if let error { print("[StreakMed] Notification schedule error \(id): \(error)") }
                #endif
            }
        }
        func oneShot(_ id: String, at date: Date) {
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            add(id, UNCalendarNotificationTrigger(dateMatching: c, repeats: false))
        }

        let days  = med.scheduledWeekdays
        let todayW = cal.component(.weekday, from: today)
        let skipTodaysOccurrence = quietToday && days.contains(todayW) && fire(onDoseDay: today) > now

        if days.count == 7 {
            if skipTodaysOccurrence {
                oneShot(id, at: fire(onDoseDay: cal.date(byAdding: .day, value: 1, to: today)!))
            } else {
                let c = cal.dateComponents([.hour, .minute], from: fire(onDoseDay: today))
                add(id, UNCalendarNotificationTrigger(dateMatching: c, repeats: true))
            }
            return
        }
        for w in days {
            let wid = "\(id)_wd\(w)"
            // Next date (from today) that falls on weekday w
            let ahead = (w - todayW + 7) % 7
            let doseDay = cal.date(byAdding: .day, value: ahead, to: today)!
            if w == todayW && skipTodaysOccurrence {
                oneShot(wid, at: fire(onDoseDay: cal.date(byAdding: .day, value: 7, to: today)!))
            } else {
                let c = cal.dateComponents([.weekday, .hour, .minute], from: fire(onDoseDay: doseDay))
                add(wid, UNCalendarNotificationTrigger(dateMatching: c, repeats: true))
            }
        }
    }

    /// Schedules reminders (and follow-ups) for every dose of `med`.
    func scheduleNotification(for med: Medication) {
        guard Self.remindersEnabled else { return }
        for i in 0..<med.doseTimesArray.count { scheduleDose(med, doseIndex: i, quietToday: false) }
    }

    private func scheduleDose(_ med: Medication, doseIndex: Int, quietToday: Bool) {
        guard Self.remindersEnabled, let name = med.name, let baseID = med.notificationID else { return }
        let times = med.doseTimesArray
        guard doseIndex < times.count else { return }
        let lead = UserDefaults.standard.integer(forKey: "reminderLeadMinutes")
        addStream(id: doseNotifID(baseID: baseID, doseIndex: doseIndex),
                  content: reminderContent(for: med, name: name, doseIndex: doseIndex,
                                           totalDoses: times.count, leadMinutes: lead),
                  med: med, doseTime: times[doseIndex], offsetMinutes: -lead, quietToday: quietToday)
        if let follow = followUpMinutes {
            addStream(id: followUpNotifID(baseID: baseID, doseIndex: doseIndex),
                      content: followUpContent(name: name, doseIndex: doseIndex, totalDoses: times.count),
                      med: med, doseTime: times[doseIndex], offsetMinutes: follow, quietToday: quietToday)
        }
    }

    /// Every pending/delivered ID that can belong to one dose.
    private func allIDs(baseID: String, doseIndex: Int) -> [String] {
        let roots = [doseNotifID(baseID: baseID, doseIndex: doseIndex),
                     followUpNotifID(baseID: baseID, doseIndex: doseIndex)]
        var ids: [String] = []
        for r in roots {
            ids.append(r)
            for w in 1...7 { ids.append("\(r)_wd\(w)") }
        }
        // Snoozed copies (snoozes of snoozes too)
        return ids + ids.map { $0 + "_snooze" } + ids.map { $0 + "_snooze_snooze" }
    }

    /// The dose was logged (or the day skipped): clear its reminder, follow-up
    /// and snoozes for today, then re-arm them from the next occurrence on.
    func cancelTodayNotification(for med: Medication, doseIndex: Int = 0) {
        guard let baseID = med.notificationID else { return }
        let ids = allIDs(baseID: baseID, doseIndex: doseIndex)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        scheduleDose(med, doseIndex: doseIndex, quietToday: true)
    }

    /// Cancels ALL notifications for a medication (e.g. when deleting or editing it).
    func cancelAllNotifications(for med: Medication) {
        guard let baseID = med.notificationID else { return }
        // Legacy single-dose ID + every per-dose variant (cover up to 10 doses)
        var ids = [baseID, baseID + "_refill"]
        for i in 0..<10 { ids += allIDs(baseID: baseID, doseIndex: i) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Fires a one-time refill reminder when the supply on hand drops to or below 7.
    func scheduleRefillNotification(for med: Medication, remaining: Int) {
        guard Self.remindersEnabled, let name = med.name else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Low Supply: \(name)"
        content.body      = "Only \(remaining) \(med.unitNoun(remaining)) left. Time to refill!"
        content.sound     = .default
        content.badge     = 1

        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let refillID = (med.notificationID ?? UUID().uuidString) + "_refill"
        let request  = UNNotificationRequest(identifier: refillID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Re-schedules all active medications (e.g. after settings change).
    func rescheduleAll(medications: [Medication]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        medications.forEach { scheduleNotification(for: $0) }
    }

    // MARK: - Notification Actions

    /// Registers the action buttons that appear when the user long-presses a medication notification.
    /// "Mark as Taken" opens the app and marks the dose; "Snooze 10 min" fires a one-off reminder.
    /// Must be called at app launch (before any notifications are displayed).
    func registerCategories() {
        let snoozeOn = UserDefaults.standard.bool(forKey: "snoozeEnabled")
        let takenAction = UNNotificationAction(
            identifier: "MARK_TAKEN",
            title: "Mark as Taken",
            options: [.foreground]  // .foreground brings the app to the front when tapped
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 10 min",
            options: []             // background action — no need to open the app
        )
        let category = UNNotificationCategory(
            identifier: "MEDICATION_REMINDER",
            actions: snoozeOn ? [takenAction, snoozeAction] : [takenAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Helpers

    private func doseNotifID(baseID: String, doseIndex: Int) -> String {
        "\(baseID)_dose_\(doseIndex)"
    }

    private func followUpNotifID(baseID: String, doseIndex: Int) -> String {
        "\(baseID)_dose_\(doseIndex)_followup"
    }

    private func notifTitle(name: String, doseIndex: Int, totalDoses: Int, leadMinutes: Int) -> String {
        if leadMinutes > 0 {
            return totalDoses > 1
                ? "\(name) (dose \(doseIndex + 1)) in \(leadMinutes) min"
                : "\(name) in \(leadMinutes) min"
        }
        return totalDoses > 1
            ? "Time for \(name) · Dose \(doseIndex + 1) of \(totalDoses)"
            : "Time for \(name)"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Shows notification banners even when the app is open in the foreground.
    /// Without this, iOS silently drops notifications while the app is active.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handles the user tapping a notification or one of its action buttons.
    /// "MARK_TAKEN" posts a NotificationCenter event so HomeView can mark the dose.
    /// "SNOOZE" schedules a one-off follow-up 10 minutes later.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "MARK_TAKEN":
            // Broadcast the notification identifier so the correct medication can be looked up
            // A stale banner from a previous day would log *today's* dose;
            // just open the app instead.
            if Calendar.current.isDateInToday(response.notification.date) {
                pendingMarkTakenID = response.notification.request.identifier
            }
            NotificationCenter.default.post(
                name: .didReceiveMarkTakenAction,
                object: response.notification.request.identifier
            )
        case "SNOOZE":
            scheduleSnooze(for: response.notification.request)
        default:
            break
        }
        completionHandler()
    }

    /// Clones the original notification content and fires it again after 600 seconds (10 min).
    private func scheduleSnooze(for original: UNNotificationRequest) {
        let content  = original.content.mutableCopy() as! UNMutableNotificationContent
        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let snoozeID = original.identifier + "_snooze"   // unique ID so it doesn't replace the original
        let request  = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let didReceiveMarkTakenAction = Notification.Name("StreakMed.didReceiveMarkTakenAction")
    /// Posted by HomeEmptyState's "Add Medications" button to switch the root tab to Meds
    static let navigateToMeds = Notification.Name("StreakMed.navigateToMeds")
}
