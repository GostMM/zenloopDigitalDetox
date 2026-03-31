//
//  PushNotificationManager.swift
//  zenloop
//
//  Created by Claude on 30/03/2026.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.app.zenloop", category: "PushNotificationManager")

/// Gestionnaire des notifications push FCM (Firebase Cloud Messaging)
/// Enregistre le token push de l'appareil dans Firestore pour permettre l'envoi de notifications
@MainActor
class PushNotificationManager: NSObject {

    static let shared = PushNotificationManager()

    private lazy var db = Firestore.firestore()
    private var currentToken: String?

    private override init() {
        super.init()
    }

    /// Configure Firebase Messaging et demande les permissions de notification
    func setup() async {
        logger.info("🔔 Setting up push notifications...")

        await requestNotificationPermissions()

        Messaging.messaging().delegate = self

        await registerForRemoteNotifications()
    }

    /// Demande les permissions de notification à l'utilisateur
    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                logger.info("✅ Notification permissions granted")
            } else {
                logger.warning("⚠️ Notification permissions denied")
            }
        } catch {
            logger.error("❌ Failed to request notification permissions: \(error.localizedDescription)")
        }
    }

    /// Enregistre l'app pour recevoir les remote notifications
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
        logger.info("📱 Registered for remote notifications")
    }

    /// Récupère et sauvegarde le token FCM (à appeler après réception du token APNs)
    func retrieveAndSaveFCMToken() async {
        logger.info("🔄 Retrieving FCM token...")

        do {
            let token = try await Messaging.messaging().token()
            logger.info("✅ FCM Token retrieved: \(token)")
            self.currentToken = token

            await saveTokenToFirestore(token)
        } catch {
            logger.error("❌ Failed to get FCM token: \(error.localizedDescription)")
        }
    }

    /// Sauvegarde le token FCM dans Firestore (champ pushToken dans users/{userId})
    private func saveTokenToFirestore(_ token: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            logger.warning("⚠️ No authenticated user, cannot save push token")
            return
        }

        logger.info("💾 Saving push token to Firestore for user: \(userId)")

        do {
            try await db.collection("users").document(userId).updateData([
                "pushToken": token,
                "pushTokenUpdatedAt": FieldValue.serverTimestamp(),
                "platform": "ios"
            ])
            logger.info("✅ Push token saved successfully")
        } catch {
            logger.error("❌ Failed to save push token to Firestore: \(error.localizedDescription)")
        }
    }

    /// Supprime le token FCM de Firestore (appeler lors de la déconnexion)
    func removeTokenFromFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        logger.info("🗑️ Removing push token from Firestore for user: \(userId)")

        do {
            try await db.collection("users").document(userId).updateData([
                "pushToken": FieldValue.delete(),
                "pushTokenUpdatedAt": FieldValue.delete()
            ])
            logger.info("✅ Push token removed successfully")
        } catch {
            logger.error("❌ Failed to remove push token: \(error.localizedDescription)")
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            logger.warning("⚠️ FCM token is nil")
            return
        }

        logger.info("🔄 FCM token refreshed: \(token)")

        Task { @MainActor in
            self.currentToken = token
            await self.saveTokenToFirestore(token)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        logger.info("📬 Notification received in foreground")
        logger.debug("Notification data: \(userInfo)")

        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        logger.info("👆 User tapped on notification")
        logger.debug("Notification data: \(userInfo)")

        if let sessionId = userInfo["sessionId"] as? String {
            logger.info("🎯 Opening session from notification: \(sessionId)")

            // ✅ Construction sûre de l'URL (pas de force unwrap)
            Task { @MainActor in
                if let url = DeepLinkCoordinator.buildSessionURL(sessionId: sessionId) {
                    DeepLinkCoordinator.shared.handleDeepLink(url: url)
                } else {
                    logger.error("❌ Failed to build deep link URL for session: \(sessionId)")
                }
            }
        }

        completionHandler()
    }
}