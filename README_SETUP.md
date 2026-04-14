<div align="center">

# StreakMed

An iOS medication tracking app built with SwiftUI and CoreData. Helps users build consistent medication habits through streak tracking, flexible scheduling, per-dose notifications, and a clean dark-mode interface.

</div>

---

<div align="center">

## Screenshots
  
<table>
  <tr>
    <td align="center">
      <img src="StreakMed/Screenshots/Opening.png" width="160"/><br/>
      <sub><b>Welcome</b></sub>
    </td>
    <td align="center">
      <img src="StreakMed/Screenshots/Today_empty.png" width="160"/><br/>
      <sub><b>Today — Empty State</b></sub>
    </td>
    <td align="center">
      <img src="StreakMed/Screenshots/Today_Filled.png" width="160"/><br/>
      <sub><b>Today — Active</b></sub>
    </td>
    <td align="center">
      <img src="StreakMed/Screenshots/Add_Medication.png" width="160"/><br/>
      <sub><b>Add Medication</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="StreakMed/Screenshots/History.png" width="160"/><br/>
      <sub><b>History</b></sub>
    </td>
    <td align="center">
      <img src="StreakMed/Screenshots/Setting.png" width="160"/><br/>
      <sub><b>Settings</b></sub>
    </td>
    <td align="center">
      <img src="StreakMed/Screenshots/FaceID.png" width="160"/><br/>
      <sub><b>Face ID Lock</b></sub>
    </td>
  </tr>
</table>
</div>

---

# Project Setup

## 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Fill in the following:
    - **Product Name:** StreakMed
    - **Team:** your team / personal team
    - **Organization ID:** com.yourname
    - **Interface:** SwiftUI
    - **Language:** Swift
    - **Storage:** None (CoreData is added manually)
4. Uncheck **Include Tests**
5. Click **Next** and save inside this folder

## 2. Add Source Files

1. Drag the entire `Sources/` folder into the Xcode project navigator
2. Drop it on the **StreakMed** group (yellow folder icon)
3. In the dialog: check **Copy items if needed**, **Create groups**, target **StreakMed**
4. Delete the boilerplate files Xcode created automatically:
    - `ContentView.swift`
    - `StreakMedApp.swift`

Keep `Assets.xcassets` — only delete the two Swift files above, not the asset catalog.

## 3. Add the CoreData Model

1. Copy the entire `CoreData/StreakMed.xcdatamodeld` folder
2. Drag it into the Xcode project navigator alongside Sources
3. In the dialog: check **Copy items if needed**, target **StreakMed**

The `.xcdatamodeld` should appear as a blue stacked icon in Xcode's navigator. If it shows as a plain folder, right-click → **Show in Finder** and confirm the folder name ends in `.xcdatamodeld`.

## 4. Add Notification Capabilities

1. Select the **StreakMed** target → **Signing & Capabilities** tab
2. Click **+ Capability** and add:
    - **Push Notifications**
    - **Background Modes** → check Remote notifications

## 5. Update Info.plist

Right-click `Info.plist` → **Open As → Source Code**, then add:

```xml
<key>NSUserNotificationUsageDescription</key>
<string>StreakMed uses notifications to remind you when it's time to take your medications.</string>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## 6. Accent Color

In `Assets.xcassets → AccentColor`, set any appearance to `#4FFFB0` (R: 79, G: 255, B: 176).

## 7. Build Settings

- **Deployment Target:** iOS 16.6+
- **Swift Language Version:** Swift 5
- **Targeted Device Family:** iPhone, iPad

iOS 16.6 is required for `.presentationDetents`. All `.onChange` calls use the single-parameter form for compatibility — the two-parameter form is iOS 17+ only.

## 8. First Build

Hit **⌘R**. Common issues:

**Cannot find type 'Medication'**
Xcode hasn't generated CoreData subclasses. Select the `.xcdatamodeld` → Editor → **Create NSManagedObject Subclass**.

**Module 'StreakMed' not found**
Clean the build folder with **⇧⌘K**, then rebuild.

**Duplicate ContentView or StreakMedApp**
Delete Xcode's boilerplate versions and keep only the files from `Sources/`.

---

# File Structure

```
Sources/
├── StreakMedApp.swift               Entry point, onboarding gate, color scheme
├── ContentView.swift                Custom tab bar and screen switcher
├── Theme.swift                      AppTheme colors, shared components, Color+toHex()
│
├── Persistence/
│   └── PersistenceController.swift  CoreData stack
│
├── Models/
│   └── MedicationStore.swift        All business logic, DoseItem, per-dose tracking
│
├── Notifications/
│   └── NotificationManager.swift    Per-dose scheduling, lead time, cancellation
│
└── Views/
    ├── Home/
    │   ├── HomeView.swift
    │   ├── MedCard.swift
    │   ├── ProgressCard.swift
    │   └── MarkAllSheet.swift
    ├── History/
    │   ├── HistoryView.swift
    │   └── DayDetailSheet.swift
    ├── Meds/
    │   ├── MedsView.swift
    │   ├── AddMedSheet.swift
    │   └── EditMedSheet.swift
    ├── Settings/
    │   └── SettingsView.swift
    └── Onboarding/
        └── OnboardingView.swift

CoreData/
└── StreakMed.xcdatamodeld/
    └── StreakMed.xcdatamodel/
        └── contents

StreakMedWidget/
└── StreakMedWidget.swift             Widget extension (small, medium, lock screen)
```

---

# CoreData Schema

## Medication Entity

- **id** — UUID, primary key
- **name** — String, e.g. "Lisinopril"
- **dose** — String, e.g. "10 mg"
- **type** — String, e.g. "Heart"
- **color** — String, hex without #, e.g. "4FFFB0"
- **scheduledTime** — Date, hour and minute only (primary or first dose)
- **doseTimes** — String, optional, comma-separated "HH:mm" values for multi-dose meds
- **isActive** — Bool, soft-delete flag
- **notificationID** — String, base UUID used to derive per-dose notification IDs
- **sortOrder** — Int32, display order
- **pillsRemaining** — Int16, optional
- **createdAt** — Date

## DoseLog Entity

- **id** — UUID
- **status** — String: "taken", "missed", or "skipped"
- **takenAt** — Date, actual time the dose was taken
- **scheduledDate** — Date, normalized to start of day
- **doseIndex** — Int16, zero-based index for multi-dose meds, default 0
- **medication** — Relationship to Medication, many-to-one

---

# Features

## Today Tab

- All pending and taken dose cards for the current day, sorted by time
- Multi-dose medications generate one card per dose, each with its own Take button
- Card subtitle shows dose and time on line one, and a "Dose N of M" badge on line two
- Taking a dose immediately cancels that dose's notification and re-queues it for tomorrow
- **Undo toast** — after taking a dose (or Mark All Taken), a 4-second toast appears with an Undo button that restores the dose, re-increments pill count, and re-schedules the notification
- Progress ring and streak counter use SF Symbols
- Empty state shows a centered SF Symbol illustration

## Meds Tab

- Full list of active medications with color indicators
- Pill count shown as a dedicated row with SF Symbol icon
- Swipe left on any medication to reveal a Delete button with confirmation
- Tap any medication to open the edit sheet
- Empty state shows a centered SF Symbol illustration

## Add and Edit Medication

- Fields: name, dose, type, color, scheduled days, pill count
- Multi-dose support — select 1 to 4 doses per day, each with its own scheduled time
    - Single dose uses an inline scroll wheel time picker
    - Multiple doses use compact tappable rows that open a focused bottom sheet picker
- Color picker has 8 preset swatches plus a rainbow circle that opens the system color picker on first tap
- Custom colors are saved as hex and restored correctly on edit

## History Tab

- Monthly calendar with color-coded day indicators
- Left-aligned vertical legend ordered: Today, Complete, Missed, Partial, Skipped
- Tap any day to see a full breakdown of every dose for that date

## Settings

- **Appearance** — Light, System, or Dark mode with fully adaptive color palette
- **Notifications** — enable/disable reminders with lead time options: At time, 5, 10, 15, or 30 min early; optional missed-dose follow-up fires 1–4 hours after the scheduled time if the dose hasn't been logged
- **Privacy** — optional Face ID / Passcode lock
- **Data** — Export dose history as CSV or PDF
- **About** — Rate StreakMed, Send Feedback, Privacy Policy link, app version

## Dev Tools

- Seed sample medications — randomly picks 6 from a pool of 75+ real medications with realistic doses, types, and schedules. New random selection every tap.
- Advance or reset the debug date
- Clear today's dose logs
- Full Reset — wipes all medications and history, cancels all notifications, returns to onboarding

## Notifications

- One notification scheduled per dose per medication
- Notification IDs follow the pattern baseID_dose_0, baseID_dose_1, etc.
- Taking a dose cancels that specific notification and reschedules it for the next day
- Configurable lead time offset applied to all triggers
- Multi-dose notification titles include "Dose N of M" for context

## Widgets

- **Small (2×2)** — today's dose count (X/Y taken), progress bar, and streak counter
- **Medium (4×2)** — split layout with progress + streak on the left, next upcoming medication on the right
- **Lock screen circular** — dose fraction or checkmark when all done
- **Lock screen rectangular** — single-line summary with dose count and streak
- Data shared via App Groups UserDefaults; main app writes a snapshot on every state change and triggers WidgetKit timeline reload

## Onboarding

- 4-step flow: Welcome, Notifications permission, Add first medication, Face ID opt-in
- Fully responsive on iPad 13-inch using horizontalSizeClass
- All icons use SF Symbols in tinted circles

---

# Privacy Policy

StreakMed stores all data on-device only using CoreData. Nothing is transmitted to any server, no analytics are collected, and no account is required.

The privacy policy is hosted at your Notion page URL. Enter this same URL in **App Store Connect → App Information → Privacy Policy URL** before submitting.

What the policy covers:

- No personal data collected or transmitted off-device
- All medication data stored locally via CoreData
- Notifications generated and delivered entirely on-device by iOS
- No advertising, no third-party SDKs, no tracking
- Deleting the app permanently removes all data

---

## Future Features

### Planned (discussed)

- [ ] **Adherence score** — a quietly incrementing score that goes up each time a dose is taken and when a full day is completed, displayed subtly on the Today tab (intentionally understated to suit the target audience rather than feeling like a video game)

### Completed

- [x] **Widget extension** — small, medium, and lock screen widgets with live data via App Groups
- [x] **Export history** — dose log as CSV or PDF for doctor visits
- [x] **Face ID / Passcode lock** — optional biometric lock with onboarding opt-in
- [x] **Undo mark taken** — 4-second undo toast for single doses and Mark All Taken
- [x] **Light mode** — full adaptive color palette with Light, System, and Dark options in Settings
- [x] **Streak milestone badges** — badges awarded at 3, 7, 14, 30, 60, 90, 180, 365 day streaks with full-screen unlock animation and badge shelf in History
- [x] **Missed dose follow-up notifications** — optional second reminder fires X hours after scheduled time if the dose hasn't been logged; cancelled automatically when dose is taken; configurable delay (1–4 hours) in Settings

### Backlog

- [ ] iCloud sync — sync medications and history across devices
- [ ] Apple Health integration — write dose events to HealthKit
- [ ] Siri Shortcuts — "Hey Siri, I took my morning meds"
- [ ] Lock screen and Dynamic Island — live activity showing next upcoming dose
- [ ] Apple Watch companion app — mark doses from the wrist
- [ ] Caregiver mode — manage medications for a family member
- [ ] Medication interactions — basic warnings for known interactions

