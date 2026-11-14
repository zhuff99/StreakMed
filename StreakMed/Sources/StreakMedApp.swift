import SwiftUI
import CoreData
import UserNotifications


@main
struct StreakMedApp: App {
    let persistence = PersistenceController.shared

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("appTheme")               var appTheme               = "dark"

    init() {
        // Match the @AppStorage defaults in SettingsView so raw UserDefaults reads
        // (NotificationManager) agree with what Settings shows. Without this, the
        // missed-dose follow-up showed ON but was never scheduled until toggled.
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled":      true,
            "missedDoseReminderEnabled": true,
            "missedDoseFollowUpHours":   2,
            "snoozeEnabled":             true,   // the Snooze button always showed before 1.2.1
        ])
        NotificationManager.shared.registerCategories()
        APIKeyStore.purgeRemovedScannerData()
        #if DEBUG
        // `-dumpNotifs`: print every pending reminder + trigger a few seconds
        // after launch (headless check of the schedule from the simulator).
        if ProcessInfo.processInfo.arguments.contains("-dumpNotifs") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                    for r in reqs.sorted(by: { $0.identifier < $1.identifier }) {
                        let t = (r.trigger as? UNCalendarNotificationTrigger)
                        print("NOTIF \(r.identifier.split(separator: "_").dropFirst().joined(separator: "_")) | \(r.content.title) | \(t?.dateComponents.description ?? "-") repeats=\(t?.repeats ?? false)")
                    }
                    print("NOTIF total=\(reqs.count)")
                }
            }
        }
        #endif
        configureAppearance()
    }

    private var preferredScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // "system" — follow device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                }
            }
            .preferredColorScheme(preferredScheme)
        }
    }

    // MARK: - Global UIKit appearance tweaks
    private func configureAppearance() {
        // Navigation bar — uses dynamic colours that resolve per-trait automatically
        let dynamicBg = UIColor(AppTheme.bg)
        let dynamicText = UIColor(AppTheme.text)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor              = dynamicBg
        navAppearance.titleTextAttributes          = [.foregroundColor: dynamicText]
        navAppearance.largeTitleTextAttributes     = [.foregroundColor: dynamicText]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(AppTheme.accent)
    }
}
