// //
// //  OptionsWidgetLiveActivity.swift
// //  OptionsWidget
// //
// //  Created by Quino on 3/2/24.
// //

// import ActivityKit
// import WidgetKit
// import SwiftUI

// struct OptionsWidgetAttributes: ActivityAttributes {
//     public struct ContentState: Codable, Hashable {
//         // Dynamic stateful properties about your activity go here!
//         var emoji: String
//     }

//     // Fixed non-changing properties about your activity go here!
//     var name: String
// }

// struct OptionsWidgetLiveActivity: Widget {
//     var body: some WidgetConfiguration {
//         ActivityConfiguration(for: OptionsWidgetAttributes.self) { context in
//             // Lock screen/banner UI goes here
//             VStack {
//                 Text("Hello \(context.state.emoji)")
//             }
//             .activityBackgroundTint(Color.cyan)
//             .activitySystemActionForegroundColor(Color.black)

//         } dynamicIsland: { context in
//             DynamicIsland {
//                 // Expanded UI goes here.  Compose the expanded UI through
//                 // various regions, like leading/trailing/center/bottom
//                 DynamicIslandExpandedRegion(.leading) {
//                     Text("Leading")
//                 }
//                 DynamicIslandExpandedRegion(.trailing) {
//                     Text("Trailing")
//                 }
//                 DynamicIslandExpandedRegion(.bottom) {
//                     Text("Bottom \(context.state.emoji)")
//                     // more content
//                 }
//             } compactLeading: {
//                 Text("L")
//             } compactTrailing: {
//                 Text("T \(context.state.emoji)")
//             } minimal: {
//                 Text(context.state.emoji)
//             }
//             .widgetURL(URL(string: "http://www.apple.com"))
//             .keylineTint(Color.red)
//         }
//     }
// }

// extension OptionsWidgetAttributes {
//     fileprivate static var preview: OptionsWidgetAttributes {
//         OptionsWidgetAttributes(name: "World")
//     }
// }

// extension OptionsWidgetAttributes.ContentState {
//     fileprivate static var smiley: OptionsWidgetAttributes.ContentState {
//         OptionsWidgetAttributes.ContentState(emoji: "😀")
//      }
     
//      fileprivate static var starEyes: OptionsWidgetAttributes.ContentState {
//          OptionsWidgetAttributes.ContentState(emoji: "🤩")
//      }
// }

// #Preview("Notification", as: .content, using: OptionsWidgetAttributes.preview) {
//    OptionsWidgetLiveActivity()
// } contentStates: {
//     OptionsWidgetAttributes.ContentState.smiley
//     OptionsWidgetAttributes.ContentState.starEyes
// }
