import SwiftUI
import CoreData
import Combine

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
    @Environment(\.scenePhase)          private var scenePhase
    @StateObject private var store: MedicationStore
    @State private var selectedTab: AppTab = .home

    // Tracks the last date the store was refreshed so we can detect midnight rollover
    // even if the app is left open in the foreground all night (didBecomeActive never fires).
    @State private var lastKnownDay = Calendar.current.startOfDay(for: Date())

    // Biometric / passcode lock
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @State private var isLocked = false

    // Badge unlock overlay
    @State private var showBadgeUnlock = false
    @State private var unlockedMilestone: Int = 0

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

            // Badge unlock overlay — shown when a new streak milestone is reached.
            if showBadgeUnlock {
                BadgeUnlockOverlay(milestone: unlockedMilestone) {
                    showBadgeUnlock = false
                    store.newlyUnlockedBadge = nil
                }
                .transition(.opacity)
                .zIndex(9)
            }

            // Lock screen overlay — sits above everything so no medication
            // data is visible until the user authenticates.
            if isLocked && biometricLockEnabled {
                LockScreenView { isLocked = false }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.keyboard)
        // Lock when the app moves to the background; the lock screen will
        // appear automatically the next time scenePhase becomes .active.
        .onChange(of: scenePhase) { phase in
            if phase == .background && biometricLockEnabled {
                withAnimation(.easeIn(duration: 0.15)) { isLocked = true }
            }
        }
        // Lock on first launch if the feature is enabled.
        .onAppear {
            if biometricLockEnabled { isLocked = true }
        }
        // Refresh store data when app returns from background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshAndReschedule()
        }
        // Midnight-rollover guard: fires every 60 seconds while the app is in the foreground.
        // If the user leaves the app open overnight, didBecomeActiveNotification never fires,
        // so without this timer yesterday's logs would remain "today's" state all morning.
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            let today = Calendar.current.startOfDay(for: Date())
            if today != lastKnownDay {
                lastKnownDay = today
                store.refresh()
            }
        }
        // Show badge unlock overlay when a new milestone is reached
        .onChange(of: store.newlyUnlockedBadge) { milestone in
            if let milestone = milestone {
                unlockedMilestone = milestone
                withAnimation(.easeOut(duration: 0.3)) { showBadgeUnlock = true }
            }
        }
        // Navigate to the Meds tab when the empty-state "Add Medications" button is tapped
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMeds)) { _ in
            selectedTab = .meds
        }
        // Handle "Mark as Taken" tapped directly on the notification banner.
        // NotificationManager posts this event with the notification identifier as its object;
        // we look up the matching medication + dose index and record it as taken.
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveMarkTakenAction)) { note in
            guard let notifID = note.object as? String else { return }
            // Notification IDs are formatted as "\(baseID)_dose_\(index)"
            for med in store.medications {
                guard let baseID = med.notificationID else { continue }
                let doseCount = med.doseTimesArray.isEmpty ? 1 : med.doseTimesArray.count
                for i in 0..<doseCount {
                    if notifID == "\(baseID)_dose_\(i)" {
                        store.markTaken(med, doseIndex: i)
                        return
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Refreshes store data and, once per day, converts any one-shot "tomorrow" notification
    /// triggers back into proper repeating daily reminders.
    private func refreshAndReschedule() {
        store.refresh()
        let cal          = Calendar.current
        let today        = cal.startOfDay(for: Date())
        let lastKey      = "lastNotifRescheduleDate"
        let lastSchedule = UserDefaults.standard.object(forKey: lastKey) as? Date ?? .distantPast
        if !cal.isDate(lastSchedule, inSameDayAs: today) {
            NotificationManager.shared.rescheduleAll(medications: store.medications)
            // rescheduleAll blindly sets up repeating daily triggers for every dose.
            // Re-apply the "tomorrow only" suppression for any doses already taken today
            // so the user doesn't get a notification for a dose they've already logged.
            for med in store.medications {
                let doseCount = med.doseTimesArray.isEmpty ? 1 : med.doseTimesArray.count
                for i in 0..<doseCount {
                    if store.isTaken(med, doseIndex: i) {
                        NotificationManager.shared.cancelTodayNotification(for: med, doseIndex: i)
                    }
                }
            }
            UserDefaults.standard.set(today, forKey: lastKey)
        }
        lastKnownDay = today
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
