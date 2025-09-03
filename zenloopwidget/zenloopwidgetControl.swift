//
//  zenloopwidgetControl.swift
//  zenloopwidget
//
//  Created by MROIVILI MOUSTOIFA on 28/08/2025.
//

import AppIntents
import SwiftUI
import WidgetKit

struct zenloopwidgetControl: ControlWidget {
    static let kind: String = "com.app.zenloop.zenloopwidget.control"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: ZenloopControlProvider()
        ) { value in
            ControlWidgetToggle(
                "Focus Session",
                isOn: value.isSessionActive,
                action: ToggleFocusSessionIntent()
            ) { isActive in
                Label(
                    isActive ? "Active" : "Start", 
                    systemImage: isActive ? "pause.circle.fill" : "play.circle.fill"
                )
                .foregroundColor(isActive ? .orange : .blue)
            }
        }
        .displayName("Focus Session")
        .description("Start or pause your Zenloop focus session")
    }
}

extension zenloopwidgetControl {
    struct Value {
        var isSessionActive: Bool
        var sessionTitle: String
        var timeRemaining: String?
    }

    struct ZenloopControlProvider: AppIntentControlValueProvider {
        func previewValue(configuration: FocusSessionConfiguration) -> Value {
            zenloopwidgetControl.Value(
                isSessionActive: false, 
                sessionTitle: "Focus Session",
                timeRemaining: nil
            )
        }

        func currentValue(configuration: FocusSessionConfiguration) async throws -> Value {
            let currentData = ZenloopWidgetDataProvider.shared.getCurrentData()
            return zenloopwidgetControl.Value(
                isSessionActive: currentData.isSessionActive,
                sessionTitle: currentData.currentSessionTitle.isEmpty ? "Focus Session" : currentData.currentSessionTitle,
                timeRemaining: currentData.timeRemaining
            )
        }
    }
}

struct FocusSessionConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Session Configuration"

    @Parameter(title: "Session Type", default: "Focus")
    var sessionType: String
}

struct ToggleFocusSessionIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus Session"

    @Parameter(title: "Session Active")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        let currentData = ZenloopWidgetDataProvider.shared.getCurrentData()
        
        if currentData.currentState == .active {
            // Pause or stop current session
            if currentData.currentState == .active {
                ZenloopWidgetDataProvider.shared.pauseSession()
            }
        } else {
            // Start new 25-minute session
            ZenloopWidgetDataProvider.shared.startSession(duration: 25, origin: .quickStart)
        }
        
        return .result()
    }
}
