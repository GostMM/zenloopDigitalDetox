//
//  QuickActionsBridge.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import SwiftUI
import UIKit

// MARK: - UISceneDelegate Bridge for SwiftUI

class QuickActionsBridge: NSObject, ObservableObject {
    static let shared = QuickActionsBridge()
    
    @Published var pendingShortcutItem: UIApplicationShortcutItem?
    
    private override init() {
        super.init()
    }
    
    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        DispatchQueue.main.async {
            self.pendingShortcutItem = shortcutItem
            
            // Handle directly through QuickActionsManager
            // The deep link system is a backup for when this doesn't work
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
        }
    }
    
    private func triggerDeepLink(for shortcutItem: UIApplicationShortcutItem) {
        // Convert Quick Action type to deep link URL
        let urlString: String
        
        switch shortcutItem.type {
        case QuickActionType.quickFocus.rawValue:
            urlString = "zenloop://quickfocus"
        case QuickActionType.startScheduled.rawValue:
            urlString = "zenloop://startscheduled"
        case QuickActionType.viewStats.rawValue:
            urlString = "zenloop://stats"
        case QuickActionType.emergency.rawValue:
            urlString = "zenloop://emergency"
        case QuickActionType.dontDelete.rawValue:
            urlString = "zenloop://retention"
        default:
            print("❌ [QUICK_ACTIONS_BRIDGE] Unknown shortcut type: \(shortcutItem.type)")
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ [QUICK_ACTIONS_BRIDGE] Invalid URL: \(urlString)")
            return
        }
        
        // Trigger the deep link after a small delay to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.open(url, options: nil) { success in
                    print(success ? "✅ [DEEP_LINK] Triggered: \(urlString)" : "❌ [DEEP_LINK] Failed: \(urlString)")
                }
            }
        }
    }
    
    func clearPendingShortcut() {
        pendingShortcutItem = nil
    }
}

// MARK: - Scene Delegate for Quick Actions

class ZenloopSceneDelegate: NSObject, UIWindowSceneDelegate {
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🚀 [SCENE_DELEGATE] Scene connecting")
        
        // Handle quick action when app is launched from cold start
        if let shortcutItem = connectionOptions.shortcutItem {
            print("🚀 [SCENE_DELEGATE] Scene launched with shortcut: \(shortcutItem.type)")
            QuickActionsBridge.shared.handleShortcutItem(shortcutItem)
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // Handle quick action when app is already running or in background
        print("🚀 [SCENE_DELEGATE] Quick action performed: \(shortcutItem.type)")
        QuickActionsBridge.shared.handleShortcutItem(shortcutItem)
        completionHandler(true)
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Update quick actions when app goes to background
        print("🚀 [SCENE_DELEGATE] Scene will resign active - updating quick actions")
        QuickActionsManager.shared.updateQuickActions()
    }

    // ✅ CRUCIAL: Handle URL schemes (including unblock URLs from extension)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔗 [SCENE_DELEGATE] ========== URL RECEIVED IN SCENE ==========")
        print("🔗 [SCENE_DELEGATE] Received \(URLContexts.count) URL(s)")

        for context in URLContexts {
            let url = context.url
            print("🔗 [SCENE_DELEGATE] URL: \(url.absoluteString)")
            print("   → Scheme: \(url.scheme ?? "nil")")
            print("   → Host: \(url.host ?? "nil")")
            print("   → Options: \(context.options)")

            // Forward to handleURL in zenloopApp
            NotificationCenter.default.post(
                name: NSNotification.Name("HandleURLScheme"),
                object: nil,
                userInfo: ["url": url]
            )
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

// MARK: - SwiftUI App Configuration

extension zenloopApp {
    func configureScene(_ scene: UIScene) -> UIScene {
        if let windowScene = scene as? UIWindowScene {
            windowScene.delegate = ZenloopSceneDelegate()
        }
        return scene
    }
}

// MARK: - Environment Key for Quick Actions

struct QuickActionsBridgeKey: EnvironmentKey {
    static let defaultValue = QuickActionsBridge.shared
}

extension EnvironmentValues {
    var quickActionsBridge: QuickActionsBridge {
        get { self[QuickActionsBridgeKey.self] }
        set { self[QuickActionsBridgeKey.self] = newValue }
    }
}