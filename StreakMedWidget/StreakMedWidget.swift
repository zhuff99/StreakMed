import WidgetKit
import SwiftUI

// MARK: - Shared constants

private let widgetGroupID = "group.com.zacharyhuff.StreakMed"

// MARK: - Colours (mirrors AppTheme without importing the main-app target)

private extension Color {
    static let smBg      = Color(red: 0.051, green: 0.051, blue: 0.051)   // #0D0D0D
    static let smSurface = Color(red: 0.102, green: 0.102, blue: 0.102)   // #1A1A1A
    static let smAccent  = Color(red: 0.310, green: 1.000, blue: 0.690)   // #4FFFB0
    static let smText    = Color.white
    static let smMuted   = Color(white: 0.55)
    static let smDim     = Color(white: 0.25)
}

// MARK: - Timeline Entry

struct StreakMedEntry: TimelineEntry {
    let date:        Date
    let takenCount:  Int
    let totalCount:  Int
    let streak:      Int
    let nextMedName: String?
    let nextMedTime: Date?

    static var placeholder: StreakMedEntry {
        StreakMedEntry(
            date:        Date(),
            takenCount:  2,
            totalCount:  5,
            streak:      7,
            nextMedName: "Lisinopril",
            nextMedTime: Date().addingTimeInterval(3600)
        )
    }

    static var empty: StreakMedEntry {
        StreakMedEntry(date: Date(), takenCount: 0, totalCount: 0, streak: 0, nextMedName: nil, nextMedTime: nil)
    }
}

// MARK: - UserDefaults snapshot reader

private func readSnapshot() -> StreakMedEntry {
    guard let defaults = UserDefaults(suiteName: widgetGroupID) else { return .empty }
    let taken   = defaults.integer(forKey: "widget_taken")
    let total   = defaults.integer(forKey: "widget_total")
    let streak  = defaults.integer(forKey: "widget_streak")
    let name    = defaults.string(forKey: "widget_next_name")
    let timeTI  = defaults.double(forKey: "widget_next_time")
    let time: Date? = timeTI > 0 ? Date(timeIntervalSince1970: timeTI) : nil
    return StreakMedEntry(
        date:        Date(),
        takenCount:  taken,
        totalCount:  total,
        streak:      streak,
        nextMedName: name,
        nextMedTime: time
    )
}

// MARK: - Timeline Provider

struct StreakMedProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakMedEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StreakMedEntry) -> Void) {
        completion(context.isPreview ? .placeholder : readSnapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakMedEntry>) -> Void) {
        let entry      = readSnapshot()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Progress bar helper

private struct ProgressBar: View {
    let progress: Double
    let color:    Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.smDim)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * progress), height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Small Widget (2 × 2)

struct SmallWidgetView: View {
    let entry: StreakMedEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.takenCount) / Double(entry.totalCount)
    }
    private var allDone: Bool { entry.totalCount > 0 && entry.takenCount >= entry.totalCount }

    var body: some View {
        ZStack {
            Color.smBg
            VStack(alignment: .leading, spacing: 0) {
                Text("StreakMed")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.smMuted)
                    .padding(.bottom, 10)

                Spacer()

                if allDone {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.smAccent)
                        Text("All done!")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.smAccent)
                    }
                } else if entry.totalCount == 0 {
                    Text("No meds\ntoday")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.smMuted)
                        .multilineTextAlignment(.leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(entry.takenCount)")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.smAccent)
                                .tracking(-1)
                            Text("/\(entry.totalCount)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.smMuted)
                        }
                        Text("taken today")
                            .font(.system(size: 11))
                            .foregroundColor(.smMuted)
                    }
                }

                Spacer()

                ProgressBar(progress: progress, color: .smAccent)
                    .padding(.bottom, 8)

                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 10))
                    Text("\(entry.streak) day streak")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.smMuted)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Medium Widget (4 × 2)

struct MediumWidgetView: View {
    let entry: StreakMedEntry

    private var progress: Double {
        guard entry.totalCount > 0 else { return 0 }
        return Double(entry.takenCount) / Double(entry.totalCount)
    }
    private var allDone: Bool { entry.totalCount > 0 && entry.takenCount >= entry.totalCount }

    var body: some View {
        ZStack {
            Color.smBg
            HStack(spacing: 0) {

                // Left: progress + streak
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.smMuted)

                    Spacer()

                    if allDone {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.smAccent)
                            Text("All done!")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.smAccent)
                        }
                    } else if entry.totalCount == 0 {
                        Text("No meds\nscheduled")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.smMuted)
                            .multilineTextAlignment(.leading)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(entry.takenCount)")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.smAccent)
                                    .tracking(-1)
                                Text("/\(entry.totalCount)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.smMuted)
                            }
                            Text("doses taken")
                                .font(.system(size: 11))
                                .foregroundColor(.smMuted)
                        }
                    }

                    Spacer()

                    ProgressBar(progress: progress, color: .smAccent)
                        .padding(.bottom, 6)

                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 10))
                        Text("\(entry.streak) day streak")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.smMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)

                // Divider
                Rectangle()
                    .fill(Color.smDim.opacity(0.6))
                    .frame(width: 1)
                    .padding(.vertical, 14)

                // Right: next med
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.smMuted)

                    Spacer()

                    if let name = entry.nextMedName, let time = entry.nextMedTime {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.smText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(time, style: .time)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.smAccent)
                        }
                    } else {
                        Text(entry.totalCount == 0 ? "No meds\nscheduled" : "Nothing\nleft today ✓")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.smMuted)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }
}

// MARK: - Lock Screen Views (iOS 16+)

@available(iOSApplicationExtension 16.0, *)
struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakMedEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        default: EmptyView()
        }
    }

    private var circularView: some View {
        ZStack {
            if entry.takenCount >= entry.totalCount && entry.totalCount > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .bold))
            } else {
                VStack(spacing: 0) {
                    Text("\(entry.takenCount)")
                        .font(.system(size: 18, weight: .bold))
                    Text("/\(entry.totalCount)")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 6) {
            Image(systemName: "pills.fill")
                .font(.system(size: 13))
            if entry.takenCount >= entry.totalCount && entry.totalCount > 0 {
                Text("All doses taken ✓")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            } else if entry.totalCount == 0 {
                Text("No meds scheduled today")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            } else {
                Text("\(entry.takenCount)/\(entry.totalCount) taken  ·  🔥\(entry.streak)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Widget Definitions

struct StreakMedSmallWidget: Widget {
    let kind = "StreakMedSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakMedProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                SmallWidgetView(entry: entry)
                    .containerBackground(Color.smBg, for: .widget)
            } else {
                SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Today's Meds")
        .description("See your daily medication progress at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakMedMediumWidget: Widget {
    let kind = "StreakMedMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakMedProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                MediumWidgetView(entry: entry)
                    .containerBackground(Color.smBg, for: .widget)
            } else {
                MediumWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Today's Meds")
        .description("See your progress and next upcoming dose.")
        .supportedFamilies([.systemMedium])
    }
}

@available(iOSApplicationExtension 16.0, *)
struct StreakMedLockWidget: Widget {
    let kind = "StreakMedLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakMedProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Meds (Lock Screen)")
        .description("Quick glance at today's medication progress.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Bundle

@main
struct StreakMedWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakMedSmallWidget()
        StreakMedMediumWidget()
        if #available(iOSApplicationExtension 16.0, *) {
            StreakMedLockWidget()
        }
    }
}
