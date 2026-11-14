import SwiftUI
import CoreData
import Combine
import StoreKit

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
    @Environment(\.requestReview)       private var requestReview
    @StateObject private var store: MedicationStore
    @State private var selectedTab: AppTab = .home

    // Tracks the last date the store was refreshed so we can detect midnight rollover
    // even if the app is left open in the foreground all night (didBecomeActive never fires).
    @State private var lastKnownDay = Calendar.current.startOfDay(for: Date())

    // Biometric / passcode lock
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage(AppPalette.storageKey)  private var paletteRaw = AppPalette.midnight.rawValue
    @State private var isLocked = false
    // Database didn't open — warn instead of silently losing new entries
    @State private var showStoreWarning = PersistenceController.shared.loadFailed

    // Badge unlock overlay
    @State private var showBadgeUnlock = false
    @State private var unlockedMilestone: Int = 0

    init() {
        _store = StateObject(
            wrappedValue: MedicationStore(context: PersistenceController.shared.container.viewContext)
        )
        #if DEBUG
        // `-tab settings` launch argument opens the app on a given tab (headless UI checks).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count,
           let tab = AppTab(rawValue: args[i + 1]) {
            _selectedTab = State(initialValue: tab)
        }
        #endif
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
            .id(paletteRaw)     // theme switch: rebuild screens so every colour re-resolves
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)   // room for custom tab bar

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
                .id(paletteRaw)

            // Badge unlock overlay — shown when a new streak milestone is reached.
            if showBadgeUnlock {
                BadgeUnlockOverlay(milestone: unlockedMilestone) {
                    showBadgeUnlock = false
                    store.newlyUnlockedBadge = nil
                    // Ask for a rating right after the first real milestone —
                    // the user just saw confetti for a week of consistency.
                    // iOS rate-limits the prompt (3/year), so this is safe to
                    // call unconditionally here.
                    if unlockedMilestone == 7 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { requestReview() }
                    }
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

            // Privacy shield — iOS captures the app-switcher snapshot while the
            // app is .inactive, before .background ever fires, so locking on
            // .background alone still leaks the med list into the switcher.
            if biometricLockEnabled && !isLocked && scenePhase != .active {
                ZStack {
                    AppTheme.bg.ignoresSafeArea()
                    Image(systemName: "pills.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.accent)
                }
                .zIndex(11)
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
            // Cold launch from a notification action / badge earned during init
            handlePendingMarkTaken()
            if let m = store.newlyUnlockedBadge {
                unlockedMilestone = m
                showBadgeUnlock = true
            }
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
        .alert("Couldn't Open Your Data", isPresented: $showStoreWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("StreakMed couldn't load your saved medications this time. Your data is still on your phone. Please close the app fully and reopen it — anything you change right now won't be saved.")
        }
        // Handle "Mark as Taken" tapped directly on the notification banner.
        // NotificationManager posts this event with the notification identifier as its object;
        // we look up the matching medication + dose index and record it as taken.
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveMarkTakenAction)) { _ in
            handlePendingMarkTaken()
        }
    }

    // MARK: - Helpers

    /// Refreshes store data and, once per day, converts any one-shot "tomorrow" notification
    /// triggers back into proper repeating daily reminders.
    /// "Mark as Taken" from a reminder, follow-up or snoozed copy.
    private func handlePendingMarkTaken() {
        guard let id = NotificationManager.shared.pendingMarkTakenID else { return }
        NotificationManager.shared.pendingMarkTakenID = nil
        store.refresh()   // the app may have been asleep since yesterday
        if let (med, i) = NotificationManager.shared.doseFor(notificationID: id, in: store.medications) {
            store.markTaken(med, doseIndex: i)
        }
    }

    private func refreshAndReschedule() {
        store.refresh()
        NotificationManager.shared.clearBadge()
        let cal          = Calendar.current
        let today        = cal.startOfDay(for: Date())
        // "_v2": 1.2.1 changed trigger IDs (weekday-aware), so every install
        // reschedules once on first launch instead of waiting for tomorrow.
        let lastKey      = "lastNotifRescheduleDate_v2"
        let lastSchedule = UserDefaults.standard.object(forKey: lastKey) as? Date ?? .distantPast
        if !cal.isDate(lastSchedule, inSameDayAs: today) {
            rescheduleNotifications()
            UserDefaults.standard.set(today, forKey: lastKey)
        }
        lastKnownDay = today

        // Reminders on but iOS never asked (e.g. "Not now" in onboarding) → ask once.
        NotificationManager.shared.requestIfNeeded { granted in
            if granted { rescheduleNotifications() }
        }
    }

    private func rescheduleNotifications() {
        NotificationManager.shared.rescheduleAll(medications: store.medications)
        // rescheduleAll blindly sets up repeating daily triggers for every dose.
        // Re-apply the "tomorrow only" suppression for any doses already taken today
        // so the user doesn't get a notification for a dose they've already logged.
        store.medications.forEach { store.requietTakenDoses(of: $0) }
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
