//
//  zenloopwidgetLiveActivity.swift
//  zenloopwidget
//
//  Created by MROIVILI MOUSTOIFA on 28/08/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ZenloopFocusSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about focus session
        var timeRemaining: String
        var progress: Double
        var sessionState: String // active, paused, completing
        var blockedAppsCount: Int
    }

    // Fixed non-changing properties about the session
    var sessionTitle: String
    var originalDuration: TimeInterval
    var difficulty: String
}

struct zenloopwidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZenloopFocusSessionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(spacing: 12) {
                // Header with session info
                HStack {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(context.state.sessionState.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(context.state.sessionState == "active" ? Color.orange : Color.cyan)
                        .cornerRadius(8)
                }
                
                // Progress and time
                VStack(spacing: 8) {
                    Text(context.state.timeRemaining)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 2)
                }
                
                // Stats
                HStack {
                    Text("🛡️ \(context.state.blockedAppsCount) apps blocked")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text(context.attributes.difficulty)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.orange)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.sessionTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(context.state.sessionState.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.timeRemaining)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        
                        HStack {
                            Text("🛡️ \(context.state.blockedAppsCount)")
                                .font(.caption2)
                            
                            Spacer()
                            
                            Text(context.attributes.difficulty)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Text(context.state.sessionState == "active" ? "⚡" : "⏸️")
                    .font(.caption2)
            } compactTrailing: {
                Text(context.state.timeRemaining)
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                Text(context.state.sessionState == "active" ? "⚡" : "⏸️")
            }
            .widgetURL(URL(string: "zenloop://session"))
            .keylineTint(Color.orange)
        }
    }
}

extension ZenloopFocusSessionAttributes {
    fileprivate static var preview: ZenloopFocusSessionAttributes {
        ZenloopFocusSessionAttributes(
            sessionTitle: "Deep Focus Session",
            originalDuration: 1500, // 25 minutes
            difficulty: "Medium"
        )
    }
}

extension ZenloopFocusSessionAttributes.ContentState {
    fileprivate static var active: ZenloopFocusSessionAttributes.ContentState {
        ZenloopFocusSessionAttributes.ContentState(
            timeRemaining: "18:45",
            progress: 0.25,
            sessionState: "active",
            blockedAppsCount: 8
        )
    }
     
    fileprivate static var paused: ZenloopFocusSessionAttributes.ContentState {
        ZenloopFocusSessionAttributes.ContentState(
            timeRemaining: "12:30",
            progress: 0.5,
            sessionState: "paused",
            blockedAppsCount: 8
        )
    }
}

#Preview("Notification", as: .content, using: ZenloopFocusSessionAttributes.preview) {
   zenloopwidgetLiveActivity()
} contentStates: {
    ZenloopFocusSessionAttributes.ContentState.active
    ZenloopFocusSessionAttributes.ContentState.paused
}
