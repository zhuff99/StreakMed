import SwiftUI
import CoreData


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
