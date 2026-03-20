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

    var permissionStatus: UNAuthorizationStatus = .notDetermined

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionStatus = settings.authorizationStatus
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule

    /// Schedules one daily repeating notification per dose time for the given medication.
    func scheduleNotification(for med: Medication) {
        guard let name = med.name, let baseID = med.notificationID else { return }

        let leadMinutes = UserDefaults.standard.integer(forKey: "reminderLeadMinutes")
        let cal         = Calendar.current
        let times       = med.doseTimesArray.isEmpty
            ? (med.scheduledTime.map { [$0] } ?? [])
            : med.doseTimesArray

        guard !times.isEmpty else { return }

        for (index, time) in times.enumerated() {
            let fireTime = leadMinutes > 0
                ? (cal.date(byAdding: .minute, value: -leadMinutes, to: time) ?? time)
                : time

            let content        = UNMutableNotificationContent()
            content.title      = notifTitle(name: name, doseIndex: index,
                                            totalDoses: times.count, leadMinutes: leadMinutes)
            content.body       = med.dose.map { "Take \($0)" } ?? "Don't forget your medication."
            content.sound      = .default
            content.badge      = 1
            content.categoryIdentifier = "MEDICATION_REMINDER"

            let comps   = cal.dateComponents([.hour, .minute], from: fireTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: doseNotifID(baseID: baseID, doseIndex: index),
                content:    content,
                trigger:    trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[StreakMed] Notification schedule error (dose \(index)): \(error)")
                }
            }
        }
    }

    /// Cancels today's notification for a specific dose and reschedules it for tomorrow.
    /// Call this as soon as the user marks that individual dose as taken.
    func cancelTodayNotification(for med: Medication, doseIndex: Int = 0) {
        guard let name = med.name, let baseID = med.notificationID else { return }

        let notifID = doseNotifID(baseID: baseID, doseIndex: doseIndex)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])

        let times = med.doseTimesArray.isEmpty
            ? (med.scheduledTime.map { [$0] } ?? [])
            : med.doseTimesArray

        guard doseIndex < times.count else { return }

        let leadMinutes = UserDefaults.standard.integer(forKey: "reminderLeadMinutes")
        let time        = times[doseIndex]
        let fireTime    = leadMinutes > 0
            ? (Calendar.current.date(byAdding: .minute, value: -leadMinutes, to: time) ?? time)
            : time

        let content        = UNMutableNotificationContent()
        content.title      = notifTitle(name: name, doseIndex: doseIndex,
                                        totalDoses: times.count, leadMinutes: leadMinutes)
        content.body       = med.dose.map { "Take \($0)" } ?? "Don't forget your medication."
        content.sound      = .default
        content.badge      = 1
        content.categoryIdentifier = "MEDICATION_REMINDER"

        let cal       = Calendar.current
        let fireComps = cal.dateComponents([.hour, .minute], from: fireTime)
        let fireHour   = fireComps.hour   ?? 8
        let fireMinute = fireComps.minute ?? 0

        // If today's fire time hasn't passed yet, the repeating trigger would fire AGAIN today.
        // Instead, schedule a one-shot explicitly for tomorrow so the user isn't reminded
        // about a dose they already took.
        let now        = Date()
        let todayFire  = cal.date(bySettingHour: fireHour, minute: fireMinute, second: 0, of: now) ?? now

        let trigger: UNCalendarNotificationTrigger
        if now >= todayFire {
            // Fire time already passed — repeating trigger safely fires next at tomorrow
            trigger = UNCalendarNotificationTrigger(dateMatching: fireComps, repeats: true)
        } else {
            // Fire time is still ahead today — pin to tomorrow's explicit date
            let tomorrow      = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
            var tomorrowComps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            tomorrowComps.hour   = fireHour
            tomorrowComps.minute = fireMinute
            trigger = UNCalendarNotificationTrigger(dateMatching: tomorrowComps, repeats: false)
        }

        let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Cancels ALL notifications for a medication (e.g. when deleting or editing it).
    func cancelAllNotifications(for med: Medication) {
        guard let baseID = med.notificationID else { return }
        // Cancel legacy single-dose ID + per-dose IDs (cover up to 10 doses)
        var ids = [baseID]
        for i in 0..<10 { ids.append(doseNotifID(baseID: baseID, doseIndex: i)) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Fires a one-time refill reminder when pills on hand drop to or below 7.
    func scheduleRefillNotification(for med: Medication, remaining: Int) {
        guard let name = med.name else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Low Supply: \(name)"
        content.body      = "Only \(remaining) pill\(remaining == 1 ? "" : "s") left. Time to refill!"
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
            actions: [takenAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Helpers

    private func doseNotifID(baseID: String, doseIndex: Int) -> String {
        "\(baseID)_dose_\(doseIndex)"
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

// MARK: - Notification name
extension Notification.Name {
    static let didReceiveMarkTakenAction = Notification.Name("StreakMed.didReceiveMarkTakenAction")
}
