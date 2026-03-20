import SwiftUI
import CoreData


@main
struct StreakMedApp: App {
    let persistence = PersistenceController.shared

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("appTheme")               var appTheme               = "dark"

    init() {
        NotificationManager.shared.registerCategories()
        configureAppearance()
    }

    private var preferredScheme: ColorScheme? {
        appTheme == "system" ? nil : .dark
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
        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.bg)
        navAppearance.titleTextAttributes       = [.foregroundColor: UIColor(AppTheme.text)]
        navAppearance.largeTitleTextAttributes  = [.foregroundColor: UIColor(AppTheme.text)]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(AppTheme.accent)
    }
}
