# StreakMed — Claude Handoff Document

This document is written for the next Claude instance working on this project. Read it fully before touching any code.

---

## Project Overview

StreakMed is a live iOS medication tracking app built with SwiftUI and CoreData. It is published on the App Store. The core concept is habit-building through streak tracking — users take their meds daily and build consecutive day streaks, earn milestone badges, and see their history on a calendar.

- **Bundle ID:** `com.zacharyhuff.StreakMed`
- **App Group ID:** `group.com.zacharyhuff.StreakMed` (used for widget data sharing)
- **Dev Team:** `M747DGA4CZ`
- **GitHub:** `https://github.com/zhuff99/StreakMed`
- **Privacy Policy:** `https://notion.so/StreakMed-Privacy-Policy-323dc81e319480a5b5aae7e30543a7f2`
- **Deployment Target:** iOS 16.6+
- **Language:** Swift 5, SwiftUI, CoreData

---

## Architecture

### Data Layer
- **CoreData** for all persistent medication and dose log data
- **`MedicationStore.swift`** is the single source of truth — an `ObservableObject` injected as an `@EnvironmentObject` throughout the app
- **`UserDefaults`** for lightweight settings (theme, notification prefs, best streak, earned badges)
- **App Groups UserDefaults** (`group.com.zacharyhuff.StreakMed`) for sharing data with the widget extension

### Key Patterns
- `store.refresh()` is the main reload trigger — call it after any data change. It runs: `fetchMedications()` → `fetchTodayLogs()` → `updateBestStreak()` → `updateWidgetSnapshot()`
- `updateBestStreak()` calls `checkAndAwardBadges()` — badges are awarded automatically whenever streak data changes
- `DebugDateManager.shared.currentDate` is used everywhere instead of `Date()` — this allows the dev tools date simulator to work. Never use `Date()` directly for business logic.
- Dynamic colors use `UIColor { traits in }` pattern in `Theme.swift` — colors resolve automatically for light/dark mode. Never hardcode colors.

### Notification ID Pattern
- Regular dose: `{baseID}_dose_{index}`
- Missed dose follow-up: `{baseID}_dose_{index}_followup`
- Refill reminder: `{baseID}_refill`
- Snooze: `{originalID}_snooze`

---

## File Map

```
StreakMed/Sources/
├── StreakMedApp.swift               Entry point, onboarding gate, color scheme binding
├── ContentView.swift                Custom tab bar, badge unlock overlay wiring
├── Theme.swift                      AppTheme (all dynamic colors), shared UI components
│
├── Persistence/
│   └── PersistenceController.swift  CoreData stack setup
│
├── Models/
│   └── MedicationStore.swift        ALL business logic lives here
│
├── Notifications/
│   └── NotificationManager.swift    All notification scheduling/cancellation
│
└── Views/
    ├── Home/
    │   ├── HomeView.swift           Today tab, undo toast system
    │   ├── MedCard.swift            Individual dose card
    │   ├── ProgressCard.swift       Top progress ring + streak counter
    │   ├── MarkAllSheet.swift       "Mark All Taken" confirmation sheet
    │   └── BadgeUnlockOverlay.swift Full-screen badge celebration with confetti
    ├── History/
    │   ├── HistoryView.swift        Stats grid, badge shelf, week strip
    │   └── DayDetailSheet.swift     Tap-a-day dose breakdown
    ├── Meds/
    │   ├── MedsView.swift
    │   ├── AddMedSheet.swift
    │   ├── EditMedSheet.swift
    │   └── PrescriptionScanner.swift
    ├── Settings/
    │   └── SettingsView.swift       Includes DevToolsCard (#if DEBUG)
    └── Onboarding/
        └── OnboardingView.swift     4-step flow

StreakMedWidget/
└── StreakMedWidget.swift            Widget extension — small, medium, lock screen circular/rectangular
```

---

## MedicationStore — Critical Properties & Methods

```swift
// State
@Published var medications: [Medication]
@Published var todayLogs: [DoseLog]
@Published var bestStreak: Int
@Published var earnedBadges: [Int: Date]      // milestone → date earned
@Published var newlyUnlockedBadge: Int?        // triggers overlay in ContentView

// Key computed properties
var scheduledTodayMeds: [Medication]           // meds scheduled for today
var scheduledTodayDoseItems: [DoseItem]        // all dose slots for today
var takenTodayCount: Int                       // dose items taken today
var scheduledTodayCount: Int                   // total dose items today

// Key methods
func refresh()                                 // main reload — call after any change
func markTaken(_ med: Medication, doseIndex: Int)
func undoTaken(_ med: Medication, doseIndex: Int)
func calculateStreak() -> Int                  // reads from CoreData, uses DebugDateManager
func checkAndAwardBadges()                     // called automatically from updateBestStreak()
func saveBadgesPublic()                        // public wrapper for UserDefaults badge persistence
func updateWidgetSnapshot()                    // writes to App Group UserDefaults + reloads widget

// Badge milestones
static let badgeMilestones = [3, 7, 14, 30, 60, 90, 180, 365]
static func badgeInfo(for milestone: Int) -> (name: String, icon: String)
```

---

## AppTheme Colors

All colors are dynamic (light/dark adaptive). Always use these — never hardcode.

```swift
AppTheme.bg          // background
AppTheme.surface     // card surface
AppTheme.surfaceAlt  // alternate card surface
AppTheme.border      // dividers and strokes
AppTheme.accent      // primary green (#4FFFB0 dark / #34D88F light)
AppTheme.accentDim   // accent background tint
AppTheme.accentText  // accent for text contexts
AppTheme.accentFG    // foreground on accent (near-black in dark, white in light)
AppTheme.blue        // blue accent
AppTheme.blueDim     // blue background tint
AppTheme.warn        // orange warning
AppTheme.warnDim     // orange background tint
AppTheme.missed      // red for missed doses
AppTheme.missedDim   // red background tint
AppTheme.text        // primary text
AppTheme.textMuted   // secondary text
AppTheme.textDim     // tertiary / disabled text
AppTheme.partial     // gold for partial days
```

---

## UserDefaults Keys

```
"notificationsEnabled"       Bool    — master notification toggle
"reminderLeadMinutes"        Int     — 0, 5, 10, 15, or 30
"missedDoseReminderEnabled"  Bool    — follow-up notification toggle
"missedDoseFollowUpHours"    Int     — 1, 2, 3, or 4
"snoozeEnabled"              Bool    — snooze action toggle
"appTheme"                   String  — "light", "dark", or "system"
"bestStreak"                 Int     — all-time best streak
"earnedBadges"               Data    — JSONEncoded [Int: Double] (milestone → timeIntervalSince1970)
"hasCompletedOnboarding"     Bool    — gates onboarding display
"biometricLockEnabled"       Bool    — Face ID lock
```

---

## Badge System

Badges are awarded when `calculateStreak()` returns a value >= a milestone that hasn't been earned yet. This check runs automatically after every state change via `updateBestStreak() → checkAndAwardBadges()`.

The unlock animation is triggered by `store.newlyUnlockedBadge` being set to a non-nil Int. `ContentView` watches this with `.onChange` and shows `BadgeUnlockOverlay`. The overlay auto-dismisses after 5 seconds or on tap, and sets `newlyUnlockedBadge = nil` when dismissed.

Badge shelf lives in `HistoryView` — a 4-column `LazyVGrid` showing all 8 milestones, earned ones in full color with their date, locked ones greyed out with a lock icon.

Each milestone has a unique overlay color defined in `BadgeUnlockOverlay.badgeColor`.

---

## Widget System

The widget extension (`StreakMedWidget` target) cannot import the main app target. It reads data from App Group UserDefaults:

```
"widget_taken"      Int     — doses taken today
"widget_total"      Int     — total doses scheduled today  
"widget_streak"     Int     — current streak
"widget_next_name"  String  — next upcoming med name
"widget_next_time"  String  — next upcoming med time string
```

`updateWidgetSnapshot()` in `MedicationStore` writes these keys and calls `WidgetCenter.shared.reloadAllTimelines()`. It is called from `refresh()`, `markTaken()`, `addMedication()`, `updateMedication()`, `deleteMedication()`.

Widget entitlements file: `StreakMedWidget/StreakMedWidgetExtension.entitlements`
The "Code Signing Entitlements" build setting for the widget target must point to this file.

---

## Undo System (HomeView)

When a dose is marked taken, a 4-second toast appears with an Undo button. Implementation:

- `undoItems: [(med: Medication, doseIndex: Int)]` — accumulates doses from the same Mark All action
- `undoWorkItem: DispatchWorkItem?` — cancellable timer, replaced on each new dose
- `showUndoToast(for:)` — starts the 4-second timer
- `performUndo()` — calls `store.undoTaken()` for each item
- The toast sits at higher z-order than the Mark All button and All Done banner

---

## Dev Tools (DEBUG only)

Located in `SettingsView.swift` inside `#if DEBUG` → `DevToolsCard`. Includes:

- **Date controls** — advance/retreat by day or week, reset to real today
- **Seed medications** — 6 random picks from a pool of 75+ real meds
- **Clear today's logs** / **Clear all medications** / **Full Reset**
- **Badge testing** — Next Badge (awards next unearned in order), All Badges, Clear Badges
- **Simulate Streak** — picks a day count (3/7/14/30/60/90/180/365), advances debug date forward by N days, backfills "taken" DoseLogs for all days leading up to the new today, then runs the real streak/badge detection path. Stacks — call twice to double the streak.
- **Clear Logs** — wipes all DoseLogs, badges, bestStreak, and resets debug date to real today

**Important:** `DebugDateManager.shared` is used everywhere for "today". Always use it instead of `Date()` in business logic so the simulator works.

---

## Known Quirks & Gotchas

1. **`calculateStreak()` skips today if `takenTodayCount < scheduledTodayCount`** — this is intentional so the streak doesn't drop to 0 mid-day. Fixed comparison to use dose item count on both sides (was incorrectly comparing to `scheduledTodayMeds.count` which counts meds not dose slots).

2. **`dayStatus(for:)` returns `.future` for dates before `medication.createdAt`** — the calendar won't show those days as missed even if there are no logs. The simulate function backdates `createdAt` when needed.

3. **Widget "Failed to show" error** — usually means the App Group entitlement isn't provisioned. Both the main app and widget extension targets need the App Group capability with green checkmarks in the Apple Developer Portal.

4. **Xcode may overwrite `StreakMedWidget.swift`** when adding the Widget Extension target — if it does, the file needs to be restored from the repo.

5. **`.preferredColorScheme` removed from all sheets** — previously several sheets had `.preferredColorScheme(.dark)` hardcoded. All have been removed so they respect the user's theme selection.

6. **Multi-dose vs single-dose** — `doseTimesArray` returns multiple times if `doseTimes` field is set (comma-separated "HH:mm"). Falls back to `scheduledTime` for legacy single-dose meds. Always use `doseTimesArray` not `scheduledTime` directly.

---

## Notification Architecture

`NotificationManager.shared` is a singleton. Key methods:

- `scheduleNotification(for:)` — schedules repeating daily reminder(s) + missed-dose follow-ups
- `cancelTodayNotification(for:doseIndex:)` — cancels today's reminder + follow-up, reschedules both for tomorrow
- `cancelAllNotifications(for:)` — full cancel for a med (used on delete/edit)
- `scheduleRefillNotification(for:remaining:)` — one-shot low supply alert
- `rescheduleAll(medications:)` — wipes all pending and reschedules everything (used when settings change)
- `registerCategories()` — registers "Mark as Taken" and "Snooze 10 min" action buttons, called at app launch

---

## What Was Built in the Last Session

This session added the following (all fully implemented and tested):

1. **Home/lock screen widgets** — small (2×2), medium (4×2), lock screen circular and rectangular. Requires App Group entitlement on both targets.

2. **Undo Mark Taken** — 4-second toast after marking a dose or using Mark All. Restores pill count and re-schedules notification.

3. **Light mode** — full adaptive color palette. `AppTheme` uses `UIColor { traits in }` pattern. Settings has Light / System / Dark picker.

4. **Streak milestone badges** — 8 milestones (3, 7, 14, 30, 60, 90, 180, 365 days). Full-screen confetti overlay on unlock. Badge shelf in History tab (4-column grid). Badges persist via `UserDefaults` JSON encoding.

5. **Missed dose follow-up notifications** — second notification fires X hours after scheduled time if dose not logged. Cancelled when dose is taken. Configurable delay (1–4 hours) in Settings. Toggle in Settings to enable/disable.

6. **Dev tools enhancements** — badge testing buttons (Next Badge, All Badges, Clear Badges), streak simulator (advances debug clock forward, backfills real CoreData logs, runs real badge detection path).

7. **Bug fixes** — streak off-by-one (wrong count comparison), best streak not clearing on Full Reset, calendar not showing simulated days.

---

## Next Features (Discussed, Not Started)

- **Adherence score** — a quietly incrementing score displayed on the Today tab. Intentionally understated, not gamey.
- **Apple Health integration** — write taken dose events to HealthKit
- **Siri Shortcuts** — mark doses by voice
- **Interactive widgets** (iOS 17+) — mark doses directly from home screen widget
- **iCloud sync**, **Watch app**, **Caregiver mode** — longer term backlog

---

## App Store Status

Published. First update planned to include: widgets, light mode, badges, missed dose follow-up, undo toast. Screenshots in `StreakMed/Screenshots/` need updating to show new features before submitting the update.
