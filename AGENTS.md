# StreakMed — Codex Handoff Document

Written for the next Codex instance working on this project. Read it fully before touching code. Last refreshed 2026-11-02 against commit `cf5d120`.

---

## Project Overview

StreakMed is a live iOS medication tracking app (SwiftUI + CoreData), published on the App Store. Core concept: habit-building through streaks — take your meds daily, build consecutive-day streaks, earn milestone badges, see history on a calendar. Everything is on-device: no accounts, no analytics, no server.

- **Bundle ID:** `com.zacharyhuff.StreakMed`
- **App Group ID:** `group.com.zacharyhuff.StreakMed` (widget data sharing)
- **Dev Team:** `M747DGA4CZ`
- **GitHub:** `https://github.com/zhuff99/StreakMed`
- **Privacy Policy (public, linked from ASC):** `https://notion.so/StreakMed-Privacy-Policy-323dc81e319480a5b5aae7e30543a7f2` — a mirror lives in the user's Obsidian vault; policy edits must go to both
- **Deployment Target:** iOS 16.6+ (both targets). Newer-OS features are availability-gated, never raise the target.
- **Toolchain:** Xcode 27.x, Swift 5

## Release State

- **App Store:** 1.1 (build 3). Shipped June 2026.
- **`main`:** contains the unreleased v1.2 "giga update" (everything in *What Was Built Since 1.1* below). Project version numbers have **not** been bumped yet.
- **Before v1.2 can submit:** StoreKit paywall (not started), ASC App Privacy declarations for the scanner + HealthKit, screenshots, release notes. `RELEASE_GUIDE.md` (local, gitignored) has the full process.

---

## Architecture

### Data Layer
- **CoreData** for medications + dose logs. Model is versioned: `StreakMed.xcdatamodeld/` has `StreakMed.xcdatamodel` (v1) and `StreakMed 2.xcdatamodel` (v2, current — added `Medication.shape`). Lightweight migration. **Any future attribute change gets a new model version**; never edit a shipped version in place.
- **`MedicationStore`** is the single source of truth — `ObservableObject` injected as `@EnvironmentObject`. All business logic lives there.
- **`UserDefaults.standard`** for settings; **App Group UserDefaults** for widget data.
- **Keychain** (`APIKeyStore`) for the user's Claude API key — never UserDefaults.
- `PersistenceController` falls back to an in-memory store in Release if the SQLite store fails to open (`loadFailed` flag) so a medication app never crash-loops; DEBUG still `fatalError`s.

### Key Patterns
- `store.refresh()` is the main reload trigger. Order matters:
  `fetchMedications()` → `fetchTodayLogs()` → `processWidgetActions()` → `updateBestStreak()` → `updateWidgetSnapshot()`.
  `fetchTodayLogs()` **must** precede `processWidgetActions()` — `markTaken`'s double-log guard reads `todayLogs`, and stale logs silently dropped widget actions once (fixed June 2026).
- `updateBestStreak()` → `computeStreak()` once → sets `currentStreak`, `streakShields`, `bestStreak`, then `checkAndAwardBadges(streak:)`. `computeStreak()` walks a full year — never call it from a view body; read `currentStreak`.
- **Never use `Date()` for business logic.** Use `DebugDateManager.shared.currentDate` so the dev-tools date simulator works. (Views that only format display times are fine.)
- **Never hardcode colors.** `AppTheme.*` are dynamic (`UIColor { traits in }`). Exception: the widget target mirrors a fixed dark palette because it can't import the app.
- `.onChange` must use the single-parameter closure form (two-parameter is iOS 17+).

### Notification ID Pattern
- Regular dose: `{baseID}_dose_{index}`
- Missed-dose follow-up: `{baseID}_dose_{index}_followup`
- Refill: `{baseID}_refill`
- Snooze: `{originalID}_snooze`

Dose reminders + follow-ups use `.timeSensitive` interruption level (entitlement present). Refill stays default.

---

## File Map

```
StreakMed/Sources/
├── StreakMedApp.swift               Entry point, onboarding gate, color scheme
├── ContentView.swift                Tab bar, badge overlay, Face ID lock, privacy shield, foreground refresh
├── Theme.swift                      AppTheme, shared components, medColorPalette (7 hexes)
├── Resources/
│   └── meds_db.json                 Bundled RxTerms-derived autocomplete DB (~490 KB)
├── Persistence/
│   └── PersistenceController.swift
├── Models/
│   ├── MedicationStore.swift        ALL business logic
│   ├── DebugDateManager.swift       overrideDate / currentDate / advanceDays / reset
│   ├── MedDatabase.swift            MedDBEntry + MedDatabase.search(); strength → dose parsing
│   ├── PillShape.swift              6 shapes, SF Symbol + label, PillShape.from(String?)
│   └── APIKeyStore.swift            Keychain CRUD + one-time migration from UserDefaults
├── Notifications/
│   └── NotificationManager.swift
└── Views/
    ├── LockScreenView.swift         Face ID / passcode gate
    ├── Home/        HomeView (undo toast), MedCard, ProgressCard (streak + shields), MarkAllSheet, BadgeUnlockOverlay
    ├── History/     HistoryView (stats, badge shelf, calendar), DayDetailSheet
    ├── Meds/        MedsView, AddMedSheet, EditMedSheet, HealthImportSheet, PrescriptionScanner
    ├── Settings/    SettingsView (DevToolsCard under #if DEBUG), HistoryExporter (CSV/PDF)
    └── Onboarding/  OnboardingView (4 steps: welcome, notifications, meds setup, Face ID)

StreakMedWidget/
└── StreakMedWidget.swift            Small/medium/lock-screen widgets + MarkDoseTakenIntent (iOS 17+)
```

`Sources/` and `StreakMedWidget/` are Xcode **folder-synced groups**: any file dropped in compiles automatically. Xcode template files left in `StreakMedWidget/` once broke the iOS 16 build — delete anything you didn't write.

---

## MedicationStore — Critical API

```swift
// State
@Published var medications: [Medication]
@Published var todayLogs: [DoseLog]
@Published var bestStreak: Int
@Published var currentStreak: Int              // cached by updateBestStreak(); views read THIS, never calculateStreak()
@Published var streakShields: Int              // banked shields after any spends
@Published var skippedDays: Set<String>        // "yyyy-MM-dd" user-marked skip days
@Published var earnedBadges: [Int: Date]
@Published var newlyUnlockedBadge: Int?        // triggers overlay in ContentView

// Today
var scheduledTodayMeds: [Medication]
var scheduledTodayDoseItems: [DoseItem]        // one per dose slot, sorted by time
var pendingDoseItems / takenDoseItems: [DoseItem]
var takenTodayCount / scheduledTodayCount: Int

// Mutations (all call save → refetch → snapshot → notifications)
func markTaken(_ med: Medication, doseIndex: Int = 0, at time: Date? = nil)   // `at` = widget replay timestamp
func undoTaken(_ med: Medication, doseIndex: Int = 0)
func markAllTaken()
func addMedication(name:dose:type:color:scheduledTimes:scheduledDays:pillsRemaining:notes:shape:)
func updateMedication(_:name:dose:type:color:scheduledTimes:scheduledDays:pillsRemaining:notes:shape:)
func deleteMedication(_:)

// Streak
func calculateStreak() -> Int                  // = computeStreak().streak
func computeStreak() -> StreakResult           // forward walk, see Streak section
static let shieldEarnInterval = 30, shieldCap = 2
static let badgeMilestones = [3, 7, 14, 30, 60, 90, 180, 365]

// Widget
func updateWidgetSnapshot()
private func processWidgetActions()            // replays widget "Take" taps
```

`Medication` helpers: `doseTimesArray` (always use this, not `scheduledTime`), `quantityPerDose`, `isScheduled(on:)`, `scheduledWeekdays`.

---

## Streak Engine

`computeStreak()` walks **forward** from a 1-year cutoff to today (one bucketed fetch of taken logs, no per-day queries):

- Rest days (no meds scheduled) and user-skipped days neither count nor break.
- A complete day: `streak += 1`, `perfectRun += 1`; every `shieldEarnInterval` perfect days banks a shield up to `shieldCap`.
- An incomplete **past** day: spend a shield if one is banked (streak survives, `perfectRun` resets) else `streak = 0`.
- **Today incomplete:** stop without penalty — the streak never drops mid-day.
- Shields are fully derived from log history; no separate persistence. The History calendar still shows shielded misses honestly.

Badges: `checkAndAwardBadges()` awards any milestone ≤ current streak not yet earned; sets `newlyUnlockedBadge` → `ContentView` shows `BadgeUnlockOverlay` (auto-dismiss 5s). Badge shelf is in `HistoryView`.

---

## Widget System

The extension cannot import the app target. Communication is via App Group `UserDefaults`:

**App → widget (written by `updateWidgetSnapshot()`):**
```
widget_taken, widget_total, widget_streak   Int
widget_next_name                             String
widget_next_time                             Double (epoch)
widget_pending                               Data (JSON [{id, idx, name, time}]) — full pending list
```

**Widget → app (iOS 17+ interactive "Take" button):**
```
widget_actions   Data (JSON [{medID, doseIndex, takenAt}])
```
`MarkDoseTakenIntent` (in the widget file) appends an action, optimistically updates the snapshot (removes from `widget_pending`, bumps `widget_taken`), reloads timelines. The app replays the queue in `refresh()` → `processWidgetActions()` through the real `markTaken(at:)` path, with a CoreData duplicate check. Under the debug date override, replayed timestamps are remapped onto the simulated day.

**Known limitation (notifications):** a dose taken *before* its reminder time gets its reminder and follow-up pinned as one-shots for tomorrow (iOS has no "daily repeat starting tomorrow"); the daily repeats are restored by `rescheduleAll` on the first foreground of each day. A user who takes doses early and doesn't open the app for 2+ days loses reminders until they do — candidate fix: a `BGAppRefreshTask` that calls `rescheduleAll`.

**Known limitation (widget):** the extension can't cancel notifications, so a dose taken via widget may still get its reminder/follow-up until the app next opens.

Widget files: `StreakMedWidget/StreakMedWidgetExtension.entitlements` (App Group). Widget target min iOS must stay 16.6 — Xcode defaults new extension targets to the latest OS, which silently hides the widget from older devices.

---

## Feature Notes

- **Autocomplete:** `MedDatabase.search()` over the bundled JSON (`n` name, `s` strengths, `f` form). `AddMedSheet` shows suggestions under the name field and strength chips (`tappableStrengths` only — strengths that parse via `doseComponents(for:)`, which handles mg/mcg/g/mL/IU/units/% and ranges). To refresh the DB, re-derive from the NLM RxTerms release (public domain).
- **Apple Health import (iOS 26+):** `HealthMedImporter` uses `requestPerObjectReadAuthorization` (the standard `requestAuthorization` throws an uncatchable NSException for medication types). Read-only — the Medications API doesn't allow third-party dose writes. Maps `generalForm` → `PillShape`. Entry points: My Meds header button + onboarding meds step.
- **Prescription scanner:** Vision OCR on-device → `PIIRedactor` strips phones/dates/Rx numbers/addresses/patient markers → redacted text only goes to the Claude API with the user's own key. First-scan disclosure alert (`hasAcknowledgedScanPrivacy`). Never send the image. Raw API error bodies are logged only in DEBUG.
- **Face ID lock:** `LockScreenView` on `.background`; a logo-only privacy shield covers content whenever `scenePhase != .active` so the app-switcher snapshot never shows meds.
- **Pill shapes:** `Medication.shape` string → `PillShape.from()`, nil defaults to capsule. Rendered on `MedCard` and `MedManageRow` in the med color.
- **Undo toast (HomeView):** 4-second toast after mark/mark-all; `undoItems` accumulate; `performUndo()` calls `undoTaken` per item.
- **Export:** `HistoryExporter.makeCSV/makePDF` → share sheet. PDF must run on main thread (WebKit).

---

## AppTheme Colors

All dynamic. Always use these — never hardcode (widget target excepted).

```
bg, surface, surfaceAlt, border
accent (#4FFFB0 dark / #34D88F light), accentDim, accentText, accentFG
blue, blueDim, warn, warnDim, missed, missedDim, partial (gold)
text, textMuted, textDim
```
`medColorPalette`: 7 preset hexes + system color wheel in Add/Edit sheets (row is even full-width distribution).

---

## UserDefaults Keys

```
notificationsEnabled, reminderLeadMinutes (0/5/10/15/30), missedDoseReminderEnabled,
missedDoseFollowUpHours (1–4), snoozeEnabled, appTheme ("light"/"dark"/"system"),
bestStreak, earnedBadges (JSON [Int: Double]), skippedDays ([String]),
hasCompletedOnboarding, biometricLockEnabled, hasAcknowledgedScanPrivacy,
lastNotifRescheduleDate (ContentView daily reschedule guard)
```
Legacy `claudeApiKey` is migrated to Keychain on first read and removed.

---

## Entitlements (StreakMed.entitlements)

App Groups · HealthKit · Time-Sensitive Notifications. Widget: App Groups only.
Info.plist keys are generated from build settings (`INFOPLIST_KEY_*` in the pbxproj): camera, Face ID, Health share usage descriptions.

---

## Dev Tools (DEBUG only, SettingsView → DevToolsCard)

Date controls (advance/retreat, reset) · Seed 6 random meds · Clear today's logs / all meds / Full Reset · Badge testing (Next / All / Clear) · **Simulate Streak** (3…365 days: advances debug date, backfills taken logs, runs real streak/badge path; stacks) · Clear Logs.

Testing streak shields: Simulate 30 days → advance 2 days → streak survives, shield count drops.

---

## Known Quirks & Gotchas

1. `computeStreak()` ignores an incomplete *today* on purpose. Compare dose-item counts, never med counts.
2. `dayStatus(for:)` returns `.future` for dates before `medication.createdAt`; simulate backdates `createdAt`.
3. Widget "Failed to show" → App Group entitlement not provisioned in the Developer Portal for both targets.
4. Xcode may overwrite `StreakMedWidget.swift` or drop template files when re-adding the widget target — restore from git, delete templates.
5. No sheet may set `.preferredColorScheme` — theme is user-controlled.
6. Always `doseTimesArray`, never `scheduledTime` directly.
7. Build with plain `xcodebuild` (xcode-select points at Xcode.app). Xcode 27 treats missing-module-import warnings as errors (`MemberImportVisibility`) — add the import.
8. `print()` of medication data must be `#if DEBUG`.

---

## What Was Built Since 1.1 (unreleased, on `main`)

Interactive widgets · Apple Health import (+ onboarding) · RxTerms autocomplete · time-sensitive notifications · pill shapes (model v2) · streak shields · 7th preset color · security hardening (PII redaction, Keychain, privacy shield, scan disclosure, friendly API errors, no crash-loop) · widget deployment-target fix (was 26.4 → 16.6).

## Next (agreed, not started)

1. **StoreKit 2 paywall "StreakMed Plus"** — $1.99/mo · $14.99/yr + 7-day trial (featured) · $29.99 lifetime. Free keeps everything health-critical. Plus gates: export, adherence reports, scanner without own API key (needs a key-proxy backend — decide), themes. Requires Paid Apps Agreement in ASC.
2. Test pass (CoreData v2 upgrade-in-place, widget replay overnight, Health import on iOS 26 sim, iPad pass), version bump, screenshots, ASC privacy declarations, `ITSAppUsesNonExemptEncryption=false` on both targets, submit.
3. Backlog: adherence score, med info lookup (links only — never author medical content), iCloud sync, overdue-dose state, review prompt, Watch/caregiver/Siri. Drug interactions parked (licensing + liability).

## Decisions

- Name stays StreakMed. No in-app ads, no analytics SDK, ever. Freemium subscription is the model.
- Medical content is never authored in-app — link out or display verbatim licensed/public sources only.
