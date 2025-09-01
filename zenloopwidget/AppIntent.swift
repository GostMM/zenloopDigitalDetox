//
//  AppIntent.swift
//  zenloopwidget
//
//  Created by MROIVILI MOUSTOIFA on 28/08/2025.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

// MARK: - Session Control Intents

struct StartQuickSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Start Quick Session" }
    static var description: IntentDescription { "Start a quick focus session" }
    
    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int
    
    init() {}
    
    init(duration: Int) {
        self.duration = duration
    }
    
    func perform() async throws -> some IntentResult {
        // Update widget data and start session (with Premium check)
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: duration)
        return .result()
    }
}

struct PauseSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Pause Session" }
    static var description: IntentDescription { "Pause the current focus session" }
    
    func perform() async throws -> some IntentResult {
        ZenloopWidgetDataProvider.shared.pauseSession()
        return .result()
    }
}

struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Resume Session" }
    static var description: IntentDescription { "Resume the paused focus session" }
    
    func perform() async throws -> some IntentResult {
        ZenloopWidgetDataProvider.shared.resumeSession()
        return .result()
    }
}

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Session" }
    static var description: IntentDescription { "Stop the current focus session" }
    
    func perform() async throws -> some IntentResult {
        ZenloopWidgetDataProvider.shared.stopSession()
        return .result()
    }
}

struct StartNewSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Start New Session" }
    static var description: IntentDescription { "Start a new focus session" }
    
    func perform() async throws -> some IntentResult {
        ZenloopWidgetDataProvider.shared.startNewSessionIfPremium()
        return .result()
    }
}
