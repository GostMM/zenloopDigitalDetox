//
//  ZenloopAppIntents.swift
//  zenloopwidget
//
//  Created by Claude on 03/09/2025.
//

import AppIntents
import WidgetKit
import UIKit

// MARK: - Quick Focus Intents

struct QuickFocusIntent: AppIntent {
    static var title: LocalizedStringResource { "Quick Focus 25min" }
    static var description: IntentDescription { "Start a 25-minute focus session instantly" }
    static var openAppWhenRun: Bool { false } // Run in background!
    
    func perform() async throws -> some IntentResult {
        // Execute in background via deep link
        await executeBackgroundAction(deepLink: "zenloop://quickfocus")
        
        // Update widget data
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: 25)
        
        return .result(dialog: IntentDialog("🚀 Session focus de 25 min démarrée !"))
    }
}

struct QuickFocus5Intent: AppIntent {
    static var title: LocalizedStringResource { "Quick Focus 5min" }
    static var description: IntentDescription { "Start a 5-minute focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://quickfocus?duration=5")
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: 5)
        return .result(dialog: IntentDialog("⚡ Session focus de 5 min démarrée !"))
    }
}

struct QuickFocus50Intent: AppIntent {
    static var title: LocalizedStringResource { "Deep Focus 50min" }
    static var description: IntentDescription { "Start a 50-minute deep focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://quickfocus?duration=50")
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: 50)
        return .result(dialog: IntentDialog("🎯 Session focus profonde de 50 min démarrée !"))
    }
}

// MARK: - Scheduled Session Intents

struct StartScheduledSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Start Scheduled" }
    static var description: IntentDescription { "Start your next scheduled session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://startscheduled")
        return .result(dialog: IntentDialog("⏰ Session programmée démarrée !"))
    }
}

// MARK: - Emergency Actions

struct EmergencyBreakIntent: AppIntent {
    static var title: LocalizedStringResource { "Emergency Break" }
    static var description: IntentDescription { "Pause current session for an emergency break" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://emergency")
        ZenloopWidgetDataProvider.shared.pauseSession()
        return .result(dialog: IntentDialog("🛟 Pause d'urgence activée !"))
    }
}

// MARK: - Stats & Navigation Intents

struct ViewStatsIntent: AppIntent {
    static var title: LocalizedStringResource { "View Stats" }
    static var description: IntentDescription { "Open app and view your statistics" }
    static var openAppWhenRun: Bool { true } // This one opens the app
    
    func perform() async throws -> some IntentResult {
        await executeBackgroundAction(deepLink: "zenloop://stats")
        return .result(dialog: IntentDialog("📊 Ouverture des statistiques..."))
    }
}

// MARK: - Premium Features

struct StartCustomSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Custom Session" }
    static var description: IntentDescription { "Start a custom focus session with specific duration" }
    static var openAppWhenRun: Bool { false }
    
    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int
    
    @Parameter(title: "Session Name", default: "Focus Session")
    var sessionName: String
    
    func perform() async throws -> some IntentResult {
        // Check premium status
        let isPremium = checkPremiumStatus()
        
        if !isPremium {
            return .result(dialog: IntentDialog("🔒 Fonctionnalité Premium requise"))
        }
        
        let deepLink = "zenloop://quickfocus?duration=\(duration)&name=\(sessionName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sessionName)"
        await executeBackgroundAction(deepLink: deepLink)
        
        ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: duration)
        return .result(dialog: IntentDialog("✨ Session '\(sessionName)' de \(duration) min démarrée !"))
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
    
    // Note: UIApplication is not available in widget extensions
    // The app will process the action from the App Group UserDefaults when it becomes active
    print("✅ [WIDGET_INTENT] Background action queued for main app: \(deepLink)")
}

private func checkPremiumStatus() -> Bool {
    // Check premium status from App Group
    let suite = UserDefaults(suiteName: "group.com.app.zenloop")
    return suite?.bool(forKey: "is_premium") ?? false
}

// MARK: - Widget Control Intents (iOS 17+)

@available(iOS 17.0, *)
struct ToggleSessionIntent: AppIntent {
    static var title: LocalizedStringResource { "Toggle Session" }
    static var description: IntentDescription { "Start or stop focus session" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        // Get current session state
        let currentData = ZenloopWidgetDataProvider.shared.getCurrentData()
        
        if currentData.isSessionActive {
            // Stop current session
            await executeBackgroundAction(deepLink: "zenloop://emergency")
            ZenloopWidgetDataProvider.shared.stopSession()
            return .result(dialog: IntentDialog("⏹️ Session arrêtée"))
        } else {
            // Start new session
            await executeBackgroundAction(deepLink: "zenloop://quickfocus")
            ZenloopWidgetDataProvider.shared.startSessionIfPremium(duration: 25)
            return .result(dialog: IntentDialog("▶️ Session démarrée"))
        }
    }
}

// MARK: - Motivational Intents

struct MotivationBoostIntent: AppIntent {
    static var title: LocalizedStringResource { "Motivation Boost" }
    static var description: IntentDescription { "Get a quick motivation boost" }
    static var openAppWhenRun: Bool { false }
    
    func perform() async throws -> some IntentResult {
        let motivations = [
            "🔥 Tu peux le faire !",
            "💪 Reste concentré·e !",
            "🎯 Focus sur tes objectifs !",
            "⚡ Tu es plus fort·e que les distractions !",
            "🚀 Continue comme ça !",
            "✨ Chaque minute compte !"
        ]
        
        let randomMotivation = motivations.randomElement() ?? motivations[0]
        
        // Store motivation in App Group for potential display
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(randomMotivation, forKey: "latest_widget_motivation")
        suite?.set(Date().timeIntervalSince1970, forKey: "motivation_timestamp")
        suite?.synchronize()
        
        return .result(dialog: IntentDialog(stringLiteral: randomMotivation))
    }
}