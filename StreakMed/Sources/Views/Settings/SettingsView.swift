import SwiftUI
import UserNotifications
import CoreData

struct SettingsView: View {
    @EnvironmentObject var store: MedicationStore

    // All persisted with @AppStorage so they survive app restarts
    @AppStorage("notificationsEnabled")  var notificationsEnabled  = true
    @AppStorage("snoozeEnabled")         var snoozeEnabled          = false
    @AppStorage("reminderLeadMinutes")   var reminderLeadMinutes    = 0   // minutes before scheduled time to notify
    @AppStorage("appTheme")              var appTheme               = "dark"

    @State private var notifStatus: UNAuthorizationStatus = .notDetermined  // live iOS permission status
    @State private var showPermissionAlert = false  // shown when toggling on but permission is denied
    @State private var showExportPicker    = false  // confirmation dialog: CSV vs PDF
    @State private var isExporting        = false  // prevents double-taps while generating
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false

    /// Options for the "remind me X minutes early" preference.
    private let leadOptions: [(label: String, value: Int)] = [
        ("At scheduled time", 0),
        ("5 min early",        5),
        ("10 min early",      10),
        ("15 min early",      15),
        ("30 min early",      30),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.text)
                    .tracking(-0.5)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                // ── Appearance ────────────────────────────────────────────
                SettingsCard(title: "Appearance") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Theme")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.text)
                            Text(appTheme == "system" ? "Follows your device setting" : "Always uses dark mode")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textDim)
                        }
                        Spacer()
                        Picker("", selection: $appTheme) {
                            Text("System").tag("system")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // ── Notifications ─────────────────────────────────────────
                SettingsCard(title: "Notifications") {
                    SettingsToggleRow(
                        label: "Reminders",
                        sub:   "Get notified when it's time",
                        isOn: Binding(
                            get: { notificationsEnabled },
                            set: { newVal in
                                if newVal && notifStatus == .denied {
                                    showPermissionAlert = true
                                } else {
                                    notificationsEnabled = newVal
                                    if newVal {
                                        NotificationManager.shared.rescheduleAll(medications: store.medications)
                                    } else {
                                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                    }
                                }
                            }
                        )
                    )

                    if notificationsEnabled {
                        Divider().background(AppTheme.border)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind me")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.text)
                                Text(leadOptions.first { $0.value == reminderLeadMinutes }?.label ?? "At scheduled time")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textDim)
                            }
                            Spacer()
                            Menu {
                                ForEach(leadOptions, id: \.value) { opt in
                                    Button {
                                        reminderLeadMinutes = opt.value
                                        NotificationManager.shared.rescheduleAll(medications: store.medications)
                                    } label: {
                                        HStack {
                                            Text(opt.label)
                                            if opt.value == reminderLeadMinutes {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(leadOptions.first { $0.value == reminderLeadMinutes }?.label ?? "At scheduled time")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.accent)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.accent)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.accentDim)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Divider().background(AppTheme.border)
                    SettingsToggleRow(
                        label: "Snooze",
                        sub:   "Remind again after 10 minutes",
                        isOn: $snoozeEnabled
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // ── Privacy ───────────────────────────────────────────────
                SettingsCard(title: "Privacy") {
                    SettingsToggleRow(
                        label: "Require Face ID / Passcode",
                        sub:   "Lock the app when it goes to the background",
                        isOn:  $biometricLockEnabled
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // ── Data ──────────────────────────────────────────────────
                SettingsCard(title: "Data") {
                    SettingsInfoRow(label: "Medications tracked",   value: "\(store.medications.count)")
                    Divider().background(AppTheme.border)
                    SettingsInfoRow(label: "Current streak",        value: "\(store.calculateStreak()) days")
                    Divider().background(AppTheme.border)
                    SettingsInfoRow(label: "Best streak",           value: "\(store.bestStreak) days")
                    Divider().background(AppTheme.border)
                    SettingsInfoRow(label: "Adherence this month",  value: "\(store.adherenceRateThisMonth())%")
                    Divider().background(AppTheme.border)
                    SettingsLinkRow(
                        label: isExporting ? "Preparing export…" : "Export History",
                        icon:  "arrow.up.doc.fill",
                        color: AppTheme.accent
                    ) {
                        guard !isExporting else { return }
                        showExportPicker = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // ── Scanning ──────────────────────────────────────────────
                ScanningSettingsCard()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // ── About ─────────────────────────────────────────────────
                SettingsCard(title: "About") {
                    SettingsLinkRow(label: "Rate StreakMed", icon: "star.fill", color: AppTheme.partial) {
                        // Replace with your App Store ID once published
                        if let url = URL(string: "https://apps.apple.com/app/id000000000") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(AppTheme.border)
                    SettingsLinkRow(label: "Send Feedback", icon: "envelope.fill", color: AppTheme.blue) {
                        if let url = URL(string: "mailto:feedback@streakmed.app?subject=StreakMed%20Feedback") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(AppTheme.border)
                    SettingsLinkRow(label: "Privacy Policy", icon: "lock.shield.fill", color: AppTheme.textMuted) {
                        if let url = URL(string:"https://www.notion.so/StreakMed-Privacy-Policy-323dc81e319480a5b5aae7e30543a7f2") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(AppTheme.border)
                    HStack {
                        Text("Version")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.text)
                        Spacer()
                        Text(appVersion)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textDim)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // ── Dev Tools (DEBUG only) ────────────────────────────────
                #if DEBUG
                DevToolsCard()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                #endif

                Spacer(minLength: 16)
            }
        }
        .background(AppTheme.bg)
        .onAppear {
            NotificationManager.shared.checkPermissionStatus { status in
                notifStatus = status
            }
        }
        .confirmationDialog("Export History", isPresented: $showExportPicker, titleVisibility: .visible) {
            Button("Export as CSV") { exportHistory(format: "csv") }
            Button("Export as PDF") { exportHistory(format: "pdf") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your full dose history will be saved to a file you can share or save.")
        }
        .alert("Notifications Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications for StreakMed in Settings to receive medication reminders.")
        }
    }

    /// Reads the version and build number from the app bundle (set in Xcode project settings).
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Generates the chosen export format then shares it.
    /// CSV runs on a background thread (pure string work).
    /// PDF must run on the main thread — UIMarkupTextPrintFormatter uses WebKit
    /// internally, and WebKit crashes if first accessed off the main thread.
    private func exportHistory(format: String) {
        isExporting = true
        let context = store.viewContext
        if format == "csv" {
            DispatchQueue.global(qos: .userInitiated).async {
                let url = HistoryExporter.makeCSV(context: context)
                DispatchQueue.main.async {
                    isExporting = false
                    if let url { shareFile(url) }
                }
            }
        } else {
            let url = HistoryExporter.makePDF(context: context)
            isExporting = false
            if let url { shareFile(url) }
        }
    }

    /// Presents the iOS share sheet for the given file URL.
    private func shareFile(_ url: URL) {
        guard let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let root   = window.rootViewController else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // On iPad the share sheet needs a source rect
        av.popoverPresentationController?.sourceView = window
        av.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX,
                                                              y: window.bounds.midY,
                                                              width: 0, height: 0)
        root.present(av, animated: true)
    }
}

// MARK: - Section card wrapper

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.8)
                .padding(.bottom, 14)

            VStack(spacing: 0) { content }
                .padding(20)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 1))
        }
    }
}

// MARK: - Toggle row

struct SettingsToggleRow: View {
    let label: String
    let sub:   String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.text)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textDim)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(StreakToggle())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Scanning Settings

/// Card that lets the user enter their Claude API key for prescription scanning.
/// The key is stored in @AppStorage (UserDefaults) so it persists across launches.
/// isRevealed toggles between SecureField (hidden) and TextField (visible).
struct ScanningSettingsCard: View {
    @AppStorage("claudeApiKey") private var apiKey: String = ""
    @State private var isRevealed = false

    var body: some View {
        SettingsCard(title: "Prescription Scanning") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter your Claude API key to enable AI-powered prescription label scanning.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                    Button {
                        if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Get a free API key →")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Group {
                        if isRevealed {
                            TextField("sk-ant-...", text: $apiKey)
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .padding(12)
                .background(AppTheme.surfaceAlt)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))

                if !apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accent)
                        Text("API key saved")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Dev Tools (DEBUG only)

#if DEBUG
struct DevToolsCard: View {
    @ObservedObject private var debug = DebugDateManager.shared
    @EnvironmentObject var store: MedicationStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showFullResetConfirm = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        SettingsCard(title: "🛠 Dev Tools") {
            // Current simulated date
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulated Date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.text)
                    Text(debug.isOverriding ? "Override active" : "Using real date")
                        .font(.system(size: 11))
                        .foregroundColor(debug.isOverriding ? AppTheme.warn : AppTheme.textDim)
                }
                Spacer()
                Text(dateFormatter.string(from: debug.currentDate))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(debug.isOverriding ? AppTheme.warn : AppTheme.accent)
            }
            .padding(.vertical, 8)

            Divider().background(AppTheme.border)

            // Controls
            HStack(spacing: 10) {
                // Back 1 day
                DevButton(label: "← Day", color: AppTheme.blue) {
                    debug.advanceDays(-1)
                    clearLogsForDate(debug.currentDate)
                    store.refresh()
                }
                // Forward 1 day — also wipes any stale logs on the target date so
                // the simulated day always starts clean (stale logs accumulate when
                // the same debug date is visited across multiple test sessions).
                DevButton(label: "Day →", color: AppTheme.accent) {
                    debug.advanceDays(1)
                    clearLogsForDate(debug.currentDate)
                    store.refresh()
                }
                // Forward 1 week
                DevButton(label: "+7 Days", color: AppTheme.partial) {
                    debug.advanceDays(7)
                    clearLogsForDate(debug.currentDate)
                    store.refresh()
                }
                // Reset to today
                DevButton(label: "Reset", color: AppTheme.missed) {
                    debug.reset()
                    store.refresh()
                }
            }
            .padding(.vertical, 8)

            Divider().background(AppTheme.border)

            // Seed sample medications
            Button { seedSampleMedications() } label: {
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 13))
                    Text("Seed Sample Medications")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Divider().background(AppTheme.border)

            // Clear all medications + logs
            Button { clearAllMedications() } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                    Text("Clear all medications")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.warn)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Divider().background(AppTheme.border)

            // Clear today's logs
            Button { clearTodayLogs() } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                    Text("Clear today's dose logs")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.missed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Divider().background(AppTheme.border)

            // Full reset — wipes everything and returns to onboarding
            Button { showFullResetConfirm = true } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 13))
                    Text("Full Reset (return to onboarding)")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.missed)
                .cornerRadius(10)
            }
            .padding(.top, 4)
        }
        .alert("Full Reset?", isPresented: $showFullResetConfirm) {
            Button("Reset Everything", role: .destructive) { fullReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all medications, dose history, and logs, cancel all notifications, and return the app to the first-launch screen.")
        }
    }

    // MARK: - Seed helpers

    private struct SeedMed {
        let name: String; let dose: String; let type: String
        let hour: Int; let days: Set<Int>; let pills: Int?
    }

    private let colorPalette: [String] = [
        "5BA4FF", "4FFFB0", "C9B1FF", "FFD166", "FF9F43",
        "FF6B6B", "48DBFB", "FF9FF3", "54A0FF", "00D2D3",
        "EE5A24", "009432", "1289A7", "C4E538", "FDA7DF",
        "ED4C67", "F79F1F", "A3CB38", "12CBC4", "D980FA",
        "9980FA", "FFC312", "06C0B0", "B53471", "833471",
    ]

    private let medPool: [SeedMed] = [
        // Heart & Blood Pressure
        SeedMed(name: "Lisinopril",          dose: "10 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Amlodipine",          dose: "5 mg",     type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Metoprolol",          dose: "25 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Losartan",            dose: "50 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Atenolol",            dose: "50 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Ramipril",            dose: "5 mg",     type: "Heart",         hour: 8,  days: Set(1...7),       pills: 28),
        SeedMed(name: "Carvedilol",          dose: "6.25 mg",  type: "Heart",         hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Valsartan",           dose: "80 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Furosemide",          dose: "40 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Hydrochlorothiazide", dose: "25 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Spironolactone",      dose: "25 mg",    type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Diltiazem",           dose: "120 mg",   type: "Heart",         hour: 8,  days: Set(1...7),       pills: 30),
        // Diabetes
        SeedMed(name: "Metformin",           dose: "500 mg",   type: "Diabetes",      hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Glipizide",           dose: "5 mg",     type: "Diabetes",      hour: 7,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Glimepiride",         dose: "2 mg",     type: "Diabetes",      hour: 7,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Sitagliptin",         dose: "100 mg",   type: "Diabetes",      hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Empagliflozin",       dose: "10 mg",    type: "Diabetes",      hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Pioglitazone",        dose: "15 mg",    type: "Diabetes",      hour: 8,  days: Set(1...7),       pills: 30),
        // Cholesterol
        SeedMed(name: "Atorvastatin",        dose: "20 mg",    type: "Cholesterol",   hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Rosuvastatin",        dose: "10 mg",    type: "Cholesterol",   hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Simvastatin",         dose: "20 mg",    type: "Cholesterol",   hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Pravastatin",         dose: "40 mg",    type: "Cholesterol",   hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Ezetimibe",           dose: "10 mg",    type: "Cholesterol",   hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Fenofibrate",         dose: "145 mg",   type: "Cholesterol",   hour: 8,  days: Set(1...7),       pills: 30),
        // Thyroid
        SeedMed(name: "Levothyroxine",       dose: "50 mcg",   type: "Thyroid",       hour: 7,  days: Set([2,3,4,5,6]), pills: 20),
        SeedMed(name: "Methimazole",         dose: "10 mg",    type: "Thyroid",       hour: 8,  days: Set(1...7),       pills: 30),
        // Mental Health
        SeedMed(name: "Sertraline",          dose: "50 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Fluoxetine",          dose: "20 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Escitalopram",        dose: "10 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Venlafaxine",         dose: "75 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Bupropion",           dose: "150 mg",   type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Duloxetine",          dose: "30 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Quetiapine",          dose: "50 mg",    type: "Mental Health", hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Aripiprazole",        dose: "10 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Buspirone",           dose: "10 mg",    type: "Mental Health", hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Mirtazapine",         dose: "15 mg",    type: "Mental Health", hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Clonazepam",          dose: "0.5 mg",   type: "Mental Health", hour: 21, days: Set(1...7),       pills: 30),
        // Vitamins & Supplements
        SeedMed(name: "Vitamin D3",          dose: "2000 IU",  type: "General",       hour: 9,  days: Set([1,7]),       pills: nil),
        SeedMed(name: "Vitamin B12",         dose: "1000 mcg", type: "General",       hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Omega-3",             dose: "1000 mg",  type: "General",       hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Magnesium",           dose: "400 mg",   type: "General",       hour: 21, days: Set(1...7),       pills: nil),
        SeedMed(name: "Zinc",               dose: "50 mg",    type: "General",       hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Iron",               dose: "325 mg",   type: "General",       hour: 8,  days: Set([2,3,4,5,6]), pills: 30),
        SeedMed(name: "Folate",             dose: "400 mcg",  type: "General",       hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Calcium",            dose: "500 mg",   type: "General",       hour: 12, days: Set(1...7),       pills: nil),
        // Pain & Inflammation
        SeedMed(name: "Celecoxib",           dose: "200 mg",   type: "Pain",          hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Meloxicam",           dose: "15 mg",    type: "Pain",          hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Prednisone",          dose: "10 mg",    type: "Pain",          hour: 8,  days: Set(1...7),       pills: 21),
        SeedMed(name: "Naproxen",            dose: "500 mg",   type: "Pain",          hour: 8,  days: Set(1...7),       pills: 30),
        // Respiratory
        SeedMed(name: "Montelukast",         dose: "10 mg",    type: "Respiratory",   hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Fluticasone",         dose: "50 mcg",   type: "Respiratory",   hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Tiotropium",          dose: "18 mcg",   type: "Respiratory",   hour: 8,  days: Set(1...7),       pills: nil),
        SeedMed(name: "Budesonide",          dose: "180 mcg",  type: "Respiratory",   hour: 8,  days: Set(1...7),       pills: nil),
        // Digestive
        SeedMed(name: "Omeprazole",          dose: "20 mg",    type: "Digestive",     hour: 7,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Pantoprazole",        dose: "40 mg",    type: "Digestive",     hour: 7,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Famotidine",          dose: "20 mg",    type: "Digestive",     hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Ondansetron",         dose: "4 mg",     type: "Digestive",     hour: 8,  days: Set(1...7),       pills: 20),
        // Blood Thinners
        SeedMed(name: "Warfarin",            dose: "5 mg",     type: "Blood Thinner", hour: 17, days: Set(1...7),       pills: 30),
        SeedMed(name: "Apixaban",            dose: "5 mg",     type: "Blood Thinner", hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Rivaroxaban",         dose: "20 mg",    type: "Blood Thinner", hour: 19, days: Set(1...7),       pills: 30),
        SeedMed(name: "Clopidogrel",         dose: "75 mg",    type: "Blood Thinner", hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Aspirin",             dose: "81 mg",    type: "Blood Thinner", hour: 8,  days: Set(1...7),       pills: 90),
        // Neurological
        SeedMed(name: "Gabapentin",          dose: "300 mg",   type: "Neurological",  hour: 21, days: Set(1...7),       pills: 90),
        SeedMed(name: "Pregabalin",          dose: "75 mg",    type: "Neurological",  hour: 21, days: Set(1...7),       pills: 60),
        SeedMed(name: "Topiramate",          dose: "25 mg",    type: "Neurological",  hour: 21, days: Set(1...7),       pills: 60),
        SeedMed(name: "Lamotrigine",         dose: "100 mg",   type: "Neurological",  hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Levetiracetam",       dose: "500 mg",   type: "Neurological",  hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Donepezil",           dose: "5 mg",     type: "Neurological",  hour: 21, days: Set(1...7),       pills: 30),
        // Bone Health
        SeedMed(name: "Alendronate",         dose: "70 mg",    type: "Bone Health",   hour: 7,  days: Set([2]),         pills: 4),
        SeedMed(name: "Risedronate",         dose: "35 mg",    type: "Bone Health",   hour: 7,  days: Set([2]),         pills: 4),
        // Hormones
        SeedMed(name: "Estradiol",           dose: "1 mg",     type: "Hormones",      hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Progesterone",        dose: "100 mg",   type: "Hormones",      hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Finasteride",         dose: "1 mg",     type: "Hormones",      hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Tamoxifen",           dose: "20 mg",    type: "Hormones",      hour: 8,  days: Set(1...7),       pills: 30),
        // Immune & Rheumatology
        SeedMed(name: "Hydroxychloroquine",  dose: "200 mg",   type: "Immune",        hour: 8,  days: Set(1...7),       pills: 60),
        SeedMed(name: "Methotrexate",        dose: "10 mg",    type: "Immune",        hour: 8,  days: Set([2]),         pills: 4),
        SeedMed(name: "Azathioprine",        dose: "50 mg",    type: "Immune",        hour: 8,  days: Set(1...7),       pills: 30),
        // Urology
        SeedMed(name: "Tamsulosin",          dose: "0.4 mg",   type: "Urology",       hour: 21, days: Set(1...7),       pills: 30),
        SeedMed(name: "Oxybutynin",          dose: "5 mg",     type: "Urology",       hour: 8,  days: Set(1...7),       pills: 30),
        SeedMed(name: "Solifenacin",         dose: "5 mg",     type: "Urology",       hour: 8,  days: Set(1...7),       pills: 30),
    ]

    private func seedSampleMedications() {
        let cal = Calendar.current
        let selected = Array(medPool.shuffled().prefix(6))
        var palette = colorPalette.shuffled()
        for (i, s) in selected.enumerated() {
            let color = palette[i % palette.count]
            let time = cal.date(from: DateComponents(hour: s.hour, minute: 0)) ?? Date()
            store.addMedication(
                name: s.name, dose: s.dose, type: s.type, color: color,
                scheduledTimes: [time], scheduledDays: s.days, pillsRemaining: s.pills
            )
        }
        store.refresh()
    }

    private func clearAllMedications() {
        store.medications.forEach { store.deleteMedication($0) }
        store.refresh()
    }

    private func clearTodayLogs() {
        clearLogsForDate(debug.currentDate)
        store.refresh()
    }

    /// Deletes all DoseLogs whose scheduledDate falls on the given day.
    /// Used by "Clear today's dose logs" and by the date-advance buttons to
    /// wipe stale logs that may have accumulated from previous test sessions.
    private func clearLogsForDate(_ date: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            start as NSDate, end as NSDate
        )
        let logs = (try? store.viewContext.fetch(req)) ?? []
        logs.forEach { store.viewContext.delete($0) }
        try? store.viewContext.save()
    }

    private func fullReset() {
        // 1. Cancel all scheduled notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // 2. Hard-delete every DoseLog
        let logReq: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        let logs = (try? store.viewContext.fetch(logReq)) ?? []
        logs.forEach { store.viewContext.delete($0) }

        // 3. Hard-delete every Medication (both active and soft-deleted)
        let medReq: NSFetchRequest<Medication> = Medication.fetchRequest()
        let meds = (try? store.viewContext.fetch(medReq)) ?? []
        meds.forEach { store.viewContext.delete($0) }

        // 4. Save CoreData
        try? store.viewContext.save()

        // 5. Reset debug date to real today
        debug.reset()

        // 6. Flip back to onboarding — triggers root view swap
        hasCompletedOnboarding = false
    }
}

struct DevButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
                .cornerRadius(10)
        }
    }
}
#endif

// MARK: - Link row

struct SettingsLinkRow: View {
    let label:  String
    let icon:   String
    let color:  Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textDim)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Info row

struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.text)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.accent)
        }
        .padding(.vertical, 8)
    }
}
