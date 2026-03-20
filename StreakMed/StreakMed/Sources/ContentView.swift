import SwiftUI
import CoreData

// MARK: - Tab Definition

enum AppTab: String, CaseIterable {
    case home, history, meds, settings

    var title: String {
        switch self {
        case .home:     return "Today"
        case .history:  return "History"
        case .meds:     return "Meds"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .history:  return "calendar"
        case .meds:     return "pills.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var store: MedicationStore
    @State private var selectedTab: AppTab = .home

    init() {
        _store = StateObject(
            wrappedValue: MedicationStore(context: PersistenceController.shared.container.viewContext)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.bg.ignoresSafeArea()

            // Screen content — bottom-padded to clear the tab bar
            Group {
                switch selectedTab {
                case .home:     HomeView()
                case .history:  HistoryView()
                case .meds:     MedsView()
                case .settings: SettingsView()
                }
            }
            .environmentObject(store)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)   // room for custom tab bar

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        // Refresh store data when app becomes active
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            store.refresh()
            // Once per day: reschedule all notifications so any one-shot "tomorrow" triggers
            // (created when a dose is taken before its fire time) get converted back to
            // proper repeating daily reminders.
            let cal   = Calendar.current
            let today = cal.startOfDay(for: Date())
            let lastKey      = "lastNotifRescheduleDate"
            let lastSchedule = UserDefaults.standard.object(forKey: lastKey) as? Date ?? .distantPast
            if !cal.isDate(lastSchedule, inSameDayAs: today) {
                NotificationManager.shared.rescheduleAll(medications: store.medications)
                UserDefaults.standard.set(today, forKey: lastKey)
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedTab == tab ? AppTheme.accentDim : Color.clear)
                                    .frame(width: 44, height: 28)

                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(
                                        selectedTab == tab ? AppTheme.accent : AppTheme.textDim
                                    )
                            }

                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(
                                    selectedTab == tab ? AppTheme.accent : AppTheme.textDim
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                AppTheme.bg
                    .opacity(0.97)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}
