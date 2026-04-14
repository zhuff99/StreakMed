//
//  StreakMedWidgetLiveActivity.swift
//  StreakMedWidget
//
//  Created by Zach Huff on 4/6/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StreakMedWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StreakMedWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreakMedWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension StreakMedWidgetAttributes {
    fileprivate static var preview: StreakMedWidgetAttributes {
        StreakMedWidgetAttributes(name: "World")
    }
}

extension StreakMedWidgetAttributes.ContentState {
    fileprivate static var smiley: StreakMedWidgetAttributes.ContentState {
        StreakMedWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StreakMedWidgetAttributes.ContentState {
         StreakMedWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StreakMedWidgetAttributes.preview) {
   StreakMedWidgetLiveActivity()
} contentStates: {
    StreakMedWidgetAttributes.ContentState.smiley
    StreakMedWidgetAttributes.ContentState.starEyes
}
