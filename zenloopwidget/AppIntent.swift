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
    static var openAppWhenRun: Bool { false }
    
    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int
    
    func perform() async throws -> some IntentResult {
        // Execute in background via deep link
        await executeBackgroundAction(deepLink: "zenloop://quickfocus?duration=\(duration)")
        
        // Update widget data and start session (with Premium check)
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: duration)
        return .result(dialog: IntentDialog("🚀 Session de \(duration) min démarrée !"))
    }
}

struct PauseSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Pause Session" }
    static var description: IntentDescription { "Pause the current focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://pause")
        ZenloopWidgetDataProvider.shared.pauseSession()
        return .result(dialog: IntentDialog("⏸️ Session mise en pause"))
    }
}

struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Resume Session" }
    static var description: IntentDescription { "Resume the paused focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://resume")
        ZenloopWidgetDataProvider.shared.resumeSession()
        return .result(dialog: IntentDialog("▶️ Session reprise"))
    }
}

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Session" }
    static var description: IntentDescription { "Stop the current focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://stop")
        ZenloopWidgetDataProvider.shared.stopSession()
        return .result(dialog: IntentDialog("⏹️ Session arrêtée"))
    }
}

struct StartNewSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Start New Session" }
    static var description: IntentDescription { "Start a new focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://newsession")
        ZenloopWidgetDataProvider.shared.startNewSession()
        return .result(dialog: IntentDialog("✨ Nouvelle session démarrée"))
    }
}

// MARK: - Helper Functions

private func executeBackgroundAction(deepLink: String) async {
    guard let url = URL(string: deepLink) else {
        print("❌ [WIDGET_INTENT] Invalid deep link: \(deepLink)")
        return
    }
    
    // Store the action in App Group for the main app to process
    let suite = UserDefaults(suiteName: "group.com.app.zenloop")
    
    // Create a widget action request
    let widgetAction = [
        "action": "deep_link",
        "url": deepLink,
        "timestamp": Date().timeIntervalSince1970,
        "source": "widget"
    ] as [String: Any]
    
    // Store in App Group
    suite?.set(widgetAction, forKey: "widget_pending_action")
    suite?.synchronize()
    
    print("✅ [WIDGET_INTENT] Stored background action: \(deepLink)")
    
    // Note: The app will process the action from the App Group UserDefaults when it becomes active
    print("✅ [WIDGET_INTENT] Background action queued for main app: \(deepLink)")
}
