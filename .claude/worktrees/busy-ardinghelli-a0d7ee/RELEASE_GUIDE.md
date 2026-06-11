# StreakMed — App Store Release Guide

Two parts: **Part 1** is the specific checklist for the v1.1 update (widgets + badges + light mode). **Part 2** is the reusable template for every future release. **Part 3** is the App Store page refresh kit with ready-to-paste copy.

---

# Part 1 — The v1.1 Release (do this now)

Current state: store has **1.0 (build 1)**. This update ships: widgets, badges, light mode, missed-dose follow-ups, undo toast, snooze.

## 1. Bump versions in Xcode
- [ ] Open `StreakMed.xcodeproj`
- [ ] Project → **StreakMed** target → General → Version `1.1`, Build `2`
- [ ] Project → **StreakMedWidgetExtension** target → General → Version `1.1`, Build `2`
  - Both targets MUST match version, or upload fails with `CFBundleShortVersionString mismatch`

## 2. Pre-flight checks (v1.1-specific)
- [ ] **Signing & Capabilities** on BOTH targets: Team `M747DGA4CZ` resolves green
- [ ] **App Group** `group.com.zacharyhuff.StreakMed` checked on BOTH targets
- [ ] Verify in [developer.apple.com](https://developer.apple.com/account) → Identifiers that both App IDs show the App Group capability enabled (this is the source of the widget "Failed to show" bug)
- [ ] Widget target's "Code Signing Entitlements" build setting points to `StreakMedWidget/StreakMedWidgetExtension.entitlements`
- [ ] Scheme set to **Release** doesn't include leftover DEBUG behavior — Dev Tools card is `#if DEBUG` so it auto-strips, just confirm with a Release run

## 3. Device test pass
Run on a real iPhone (`⌘R`) and verify:
- [ ] Add small + medium widget to home screen, circular + rectangular to lock screen — data shows
- [ ] Mark a dose → widget updates
- [ ] Badge unlocks fire (use a fresh streak or check overlay manually)
- [ ] Light / Dark / System switch in Settings works everywhere (check all sheets)
- [ ] Missed-dose follow-up setting toggles
- [ ] Undo toast appears for 4s and restores state
- [ ] Upgrade path: install from TestFlight/App Store 1.0 first, then build 1.1 over it — confirm meds and history survive (CoreData schema unchanged, so should be clean)

## 4. Archive & upload
- [ ] Destination: **Any iOS Device (arm64)** (not a simulator)
- [ ] **Product → Archive**
- [ ] Organizer → select archive → **Distribute App** → **App Store Connect** → **Upload** → accept defaults
- [ ] Wait for "build processed" email (10–30 min)

## 5. App Store Connect
At [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → StreakMed:
- [ ] **+ Version** → `1.1`
- [ ] Paste **What's New** (release notes in Part 3)
- [ ] Attach **Build** 1.1 (2)
- [ ] Replace ALL screenshots — old 1.0 ones carry over silently (see Part 3 plan)
- [ ] Update **Description**, **Promotional Text**, **Keywords**, **Subtitle** (drafts in Part 3)
- [ ] **App Privacy**: no changes needed (still 100% on-device, no new data collection)
- [ ] Export Compliance: answer same as 1.0 (standard encryption exempt)
- [ ] **Add for Review** → **Submit for Review**
- [ ] Choose automatic or manual release

## 6. After approval (24–48h typical)
- [ ] If manual release: hit **Release This Version**
- [ ] Install the live update on your own phone, re-verify widgets work in production (entitlement provisioning differs from dev!)
- [ ] Tag the release in git: `git tag v1.1 && git push --tags`

---

# Part 2 — General Release Checklist (every future update)

## A. Code freeze
1. All features merged to `main`, app builds clean in Release config
2. Run a full manual test pass on a real device
3. If the CoreData model changed: test upgrade-in-place from the live store version (install old → install new → data intact). Use lightweight migration; never delete attributes on a shipped entity without a migration plan.

## B. Version bump
4. Bump **Version** (marketing, e.g. 1.2) and **Build** (always increases, never reuse — Apple rejects duplicate build numbers even across rejected submissions) on **every target** (app + widget + any future extensions). All targets must share the same Version.
5. Commit: `git commit -m "Bump to X.Y (build N)"`

## C. Archive & upload
6. Xcode destination → **Any iOS Device (arm64)**
7. **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload**
8. Wait for processing email. If rejected for a binary issue, fix, bump **build only** (not version), re-archive, re-upload.

## D. App Store Connect
9. **+ Version** → new version number
10. Write **What's New** — lead with the most user-visible change, keep it scannable
11. Attach the processed build
12. Update screenshots ONLY if the UI changed visibly (they carry over otherwise, which is fine)
13. Refresh **Promotional Text** (this field is editable anytime without review — use it for seasonal messaging)
14. Re-check **App Privacy** if you added any data collection, network calls, or third-party SDKs
15. New permission prompts (HealthKit, camera, etc.)? → Info.plist usage strings must be filled, and the App Review notes should explain the feature
16. **Submit for Review**

## E. Post-release
17. Install the live version on your own device, smoke test
18. `git tag vX.Y && git push --tags`
19. Check Analytics in a week: impressions → product page views → downloads. If impressions are flat, iterate keywords; if views are high but downloads low, iterate screenshots/subtitle.

## Recurring gotchas
- **Build numbers are monotonic forever.** When in doubt, bump.
- **Screenshots are sticky** across versions — stale ones make new features invisible.
- **Both targets need matching versions** and their own correct entitlements.
- **Widget entitlement** must be provisioned in the Developer Portal, not just checked in Xcode.
- **App Review can take 24h–5 days.** Don't submit the day before you want to launch something time-sensitive.
- **Expedited review** exists for critical bug fixes: App Store Connect → Contact Us → request expedite (use sparingly).

---

# Part 3 — App Store Page Refresh Kit (v1.1)

## What's New (release notes) — ready to paste

```
StreakMed 1.1 is here — the biggest update yet:

• Widgets — see today's progress, your streak, and your next dose right on your Home Screen and Lock Screen
• Streak badges — earn milestone badges at 3, 7, 14, 30, 60, 90, 180, and 365 days, with a celebration when you unlock one
• Light mode — choose Light, Dark, or follow your system setting
• Missed-dose follow-ups — get a gentle second reminder if you haven't logged a dose
• Undo — accidentally marked a dose? Tap undo
• Snooze — push a reminder back 10 minutes right from the notification

As always: everything stays on your device. No accounts, no tracking, ever.
```

## Subtitle (30 char max) — pick one

| Option | Chars |
|---|---|
| `Daily meds, streaks & widgets` | 29 |
| `Pill reminders that stick` | 25 |
| `Build your medication habit` | 27 |

Recommendation: option 1 — "meds," "streaks," and "widgets" are all indexed for search and showcase the update.

## Keywords (100 char max, comma-separated, no spaces)

```
pill,reminder,medicine,tracker,dose,habit,health,rx,prescription,refill,adherence,medication,alarm
```
(98 chars.) Rules baked in:
- Don't repeat words already in the app **name or subtitle** (they're indexed automatically — repeating wastes characters)
- No spaces after commas, no plurals needed (Apple matches stems)
- Iterate every release: drop terms that don't move impressions

## Promotional Text (170 char max — editable anytime, no review needed)

```
New: Home & Lock Screen widgets, milestone badges, light mode, and missed-dose follow-ups. Build your streak — one dose at a time. Private, on-device, no account.
```
(~163 chars.)

## Description — refreshed draft

```
StreakMed makes taking your medication a habit you can see.

Mark each dose with a tap, watch your streak grow day by day, and earn milestone badges along the way. Miss a dose? You'll get a gentle follow-up reminder — and your history calendar always shows the full picture.

WIDGETS
Glance at today's progress, your current streak, and your next dose — right from your Home Screen or Lock Screen.

STREAKS & BADGES
Every full day adds to your streak. Hit 3, 7, 14, 30, 60, 90, 180, and 365 days to unlock badges worth celebrating.

FLEXIBLE SCHEDULING
Up to 4 doses per day per medication, each with its own reminder. Custom colors, pill counts, and refill alerts keep everything organized.

SMART REMINDERS
Per-dose notifications with optional early lead time, snooze, and missed-dose follow-ups. Mark a dose as taken straight from the notification.

YOUR HISTORY
A color-coded calendar shows complete, partial, and missed days at a glance. Tap any day for a full dose breakdown.

PRIVATE BY DESIGN
Everything stays on your device. No account, no cloud, no analytics, no tracking. Deleting the app deletes your data. Optional Face ID lock keeps it yours.

Light and dark mode included. Designed for iPhone and iPad, iOS 16.6 or later.
```

## Screenshot plan

Required sizes (upload at least the largest; ASC scales down where allowed):
- **iPhone 6.9"** — 1320 × 2868 (iPhone 16 Pro Max simulator)
- **iPhone 6.5"** — 1284 × 2778 or 1242 × 2688 (11 Pro Max / XS Max)
- **iPad 13"** — 2064 × 2752 (if iPad is supported — it is)

Shot list (order matters — first 3 show in search results):
1. **Today tab, mid-day state** — some doses taken, progress ring partly filled, streak counter visible. Caption: "Build your streak, one dose at a time"
2. **Widgets** — home screen with small + medium widget installed. Caption: "Your meds, at a glance"
3. **Badge unlock overlay** — the confetti moment. Caption: "Celebrate every milestone"
4. **History calendar** — a believable month with mostly-complete days. Caption: "See your whole month"
5. **Add medication sheet** — multi-dose setup. Caption: "Up to 4 doses a day, each with its own reminder"
6. **Light mode Today tab** — same as #1 but light. Caption: "Light or dark — your choice"

Capture workflow:
1. Use Dev Tools (DEBUG build) → Seed medications + Simulate Streak to stage believable data
2. Set the iOS status bar clean: `xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4`
3. `⌘S` in Simulator saves a properly-sized PNG to Desktop
4. Optional: frame with captions using a tool like Screenshots Pro, AppMockUp, or Fastlane frameit

## ASO iteration loop (check monthly)
1. App Store Connect → Analytics → note **Impressions**, **Product Page Views**, **Conversion Rate**
2. Impressions low → keyword/subtitle problem
3. Views high but conversion low → screenshots/description problem
4. Change ONE variable per release so you can attribute the effect
```
