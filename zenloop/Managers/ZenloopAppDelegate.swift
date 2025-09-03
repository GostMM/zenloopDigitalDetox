//
//  ZenloopAppDelegate.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import UIKit
import SwiftUI

class ZenloopAppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 [APP_DELEGATE] App launched")
        
        // Check if app was launched via quick action
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            print("🚀 [APP_DELEGATE] Launched with shortcut: \(shortcutItem.type)")
            // Store the shortcut to be processed when the app is ready
            QuickActionsBridge.shared.handleShortcutItem(shortcutItem)
            return false // Indicate that we handled the quick action
        }
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ZenloopSceneDelegate.self
        return configuration
    }
}

// MARK: - Scene Delegate will be imported from QuickActionsBridge.swift