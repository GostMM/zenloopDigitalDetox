//
//  ZenloopAppDelegate.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import UIKit
import SwiftUI
import UserNotifications
import FirebaseMessaging

class ZenloopAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 [APP_DELEGATE] App launched")

        // ✅ Configurer le delegate pour les notifications push
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared

        // Check if app was launched via quick action
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            print("🚀 [APP_DELEGATE] Launched with shortcut: \(shortcutItem.type)")
            // Store the shortcut to be processed when the app is ready
            QuickActionsBridge.shared.handleShortcutItem(shortcutItem)
            return false // Indicate that we handled the quick action
        }

        return true
    }

    // MARK: - Remote Notifications

    /// Appelé quand l'app s'enregistre avec succès aux remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 [APP_DELEGATE] Registered for remote notifications")

        // Transmettre le device token à Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken

        // ✅ Maintenant qu'on a le token APNs, récupérer le token FCM
        Task { @MainActor in
            await PushNotificationManager.shared.retrieveAndSaveFCMToken()
        }
    }

    /// Appelé si l'enregistrement aux remote notifications échoue
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [APP_DELEGATE] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Appelé quand une remote notification est reçue (background/killed)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 [APP_DELEGATE] Remote notification received")
        print("Data: \(userInfo)")

        // Traiter la notification
        // Par exemple, rafraîchir les données de session

        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ZenloopSceneDelegate.self
        return configuration
    }
}

// MARK: - Scene Delegate will be imported from QuickActionsBridge.swift