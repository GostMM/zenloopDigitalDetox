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
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
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