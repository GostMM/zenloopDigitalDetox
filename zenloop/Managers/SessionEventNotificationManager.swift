//
//  SessionEventNotificationManager.swift
//  zenloop
//
//  Gère les notifications push pour les événements de sessions sociales
//

import Foundation
import UserNotifications
import FirebaseFirestore
import os.log

private let eventLogger = Logger(subsystem: "com.app.zenloop", category: "SessionEvents")

@MainActor
class SessionEventNotificationManager {
    static let shared = SessionEventNotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()

    /// Garde une trace des notifications récemment envoyées pour éviter les doublons
    private var recentNotificationKeys = Set<String>()
    private let throttleInterval: TimeInterval = 5.0 // secondes

    private init() {
        eventLogger.info("✅ SessionEventNotificationManager initialized")
    }

    // MARK: - Session Event Notifications

    /// Notifie tous les membres qu'un nouveau membre a rejoint
    func notifyMemberJoined(session: Session, newMemberUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: \(newMemberUsername) joined session \(sessionId)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "new_member_joined"),
            body: String(format: String(localized: "member_joined_session"), newMemberUsername, session.title),
            sessionId: sessionId,
            eventType: "member_joined"
        )
    }

    /// Notifie tous les membres qu'un membre a quitté
    func notifyMemberLeft(session: Session, leftMemberUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: \(leftMemberUsername) left session \(sessionId)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "member_left"),
            body: String(format: String(localized: "member_left_session"), leftMemberUsername, session.title),
            sessionId: sessionId,
            eventType: "member_left"
        )
    }

    /// Notifie tous les membres que la session a démarré
    func notifySessionStarted(session: Session, startedByUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: Session started by \(startedByUsername)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "session_has_started"),
            body: String(format: String(localized: "session_started_by"), session.title, startedByUsername),
            sessionId: sessionId,
            eventType: "session_started"
        )
    }

    /// Notifie tous les membres qu'une pause a été demandée
    func notifyPauseRequested(session: Session, requestedByUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: Pause requested by \(requestedByUsername)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "pause_requested"),
            body: String(format: String(localized: "pause_requested_by"), requestedByUsername, session.title),
            sessionId: sessionId,
            eventType: "pause_requested"
        )
    }

    /// Notifie tous les membres que la session a été mise en pause
    func notifySessionPaused(session: Session, pausedByUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: Session paused by \(pausedByUsername)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "session_paused"),
            body: String(format: String(localized: "session_paused_by"), session.title, pausedByUsername),
            sessionId: sessionId,
            eventType: "session_paused"
        )
    }

    /// Notifie tous les membres que la session a repris
    func notifySessionResumed(session: Session, resumedByUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: Session resumed by \(resumedByUsername)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "session_resumed"),
            body: String(format: String(localized: "session_resumed_by"), session.title, resumedByUsername),
            sessionId: sessionId,
            eventType: "session_resumed"
        )
    }

    /// Notifie tous les membres qu'un nouveau message a été envoyé dans le chat
    func notifyNewMessage(session: Session, senderUsername: String, messagePreview: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: New message from \(senderUsername)")

        // Ne pas notifier l'expéditeur du message
        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        // Limiter le preview à 100 caractères
        let preview = messagePreview.count > 100 ? String(messagePreview.prefix(97)) + "..." : messagePreview

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: "\(senderUsername) • \(session.title)",
            body: preview,
            sessionId: sessionId,
            eventType: "new_message"
        )
    }

    /// Notifie tous les membres que la session est terminée
    func notifySessionEnded(session: Session, endedByUsername: String, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: Session ended by \(endedByUsername)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "session_ended"),
            body: String(format: String(localized: "session_ended_by"), session.title, endedByUsername),
            sessionId: sessionId,
            eventType: "session_ended"
        )
    }

    /// Notifie tous les membres qu'un membre a des difficultés (tentatives d'ouverture d'apps)
    func notifyMemberStruggling(session: Session, memberUsername: String, attemptCount: Int, currentUserId: String) async {
        guard let sessionId = session.id, !sessionId.isEmpty else {
            eventLogger.warning("⚠️ Cannot notify: session has no ID")
            return
        }

        eventLogger.info("📢 Notifying members: \(memberUsername) is struggling (\(attemptCount) attempts)")

        let recipientIds = (session.memberIds ?? []).filter { $0 != currentUserId }

        await sendNotificationToMembers(
            recipientIds: recipientIds,
            title: String(localized: "member_needs_support"),
            body: String(format: String(localized: "member_struggling"), memberUsername, attemptCount),
            sessionId: sessionId,
            eventType: "member_struggling"
        )
    }

    // MARK: - Send Notifications

    /// HYBRID: Envoie via Firestore (pour push FCM) + notification locale (si app ouverte)
    private func sendNotificationToMembers(
        recipientIds: [String],
        title: String,
        body: String,
        sessionId: String,
        eventType: String
    ) async {
        guard !recipientIds.isEmpty else {
            eventLogger.info("ℹ️ No recipients for notification")
            return
        }

        // Throttle: éviter les doublons rapides
        let throttleKey = "\(sessionId)_\(eventType)"
        guard !recentNotificationKeys.contains(throttleKey) else {
            eventLogger.info("⏳ Notification throttled (duplicate): \(eventType)")
            return
        }

        recentNotificationKeys.insert(throttleKey)

        // Nettoyer la clé après le délai de throttle
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.throttleInterval ?? 5.0) * 1_000_000_000)
            self?.recentNotificationKeys.remove(throttleKey)
        }

        // ÉTAPE 1: Écrire dans Firestore (déclenchera Cloud Function → push FCM)
        for userId in recipientIds {
            await createFirestoreNotification(
                userId: userId,
                title: title,
                body: body,
                sessionId: sessionId,
                eventType: eventType
            )
        }

        // ÉTAPE 2: Notification locale pour les membres connectés sur CE device
        // BUG FIX: On vérifie si le currentUser fait partie des recipientIds
        // (cas rare, mais possible si la logique de filtrage évolue)
        // + On envoie la notification locale aux destinataires qui sont sur ce device
        await scheduleLocalNotificationForCurrentDevice(
            recipientIds: recipientIds,
            title: title,
            body: body,
            sessionId: sessionId,
            eventType: eventType
        )

        eventLogger.info("✅ Created \(recipientIds.count) Firestore notification(s) for event: \(eventType)")
    }

    /// Crée une notification dans Firestore (déclenchera Cloud Function pour push FCM)
    private func createFirestoreNotification(
        userId: String,
        title: String,
        body: String,
        sessionId: String,
        eventType: String
    ) async {
        do {
            let notificationRef = db.collection("socialNotifications").document()

            let notificationData: [String: Any] = [
                "userId": userId,
                "type": eventType,
                "sessionId": sessionId,
                "message": body,
                "isRead": false,
                "timestamp": FieldValue.serverTimestamp(),
                "actionUrl": "zenloop://session/\(sessionId)",
                // Champs pour la Cloud Function FCM
                "pushTitle": title,
                "pushBody": body,
                "needsPush": true
            ]

            try await notificationRef.setData(notificationData)
            eventLogger.info("✅ Firestore notification created for user \(userId)")

        } catch {
            eventLogger.error("❌ Failed to create Firestore notification: \(error.localizedDescription)")
        }
    }

    /// Notification locale pour l'utilisateur actuel s'il fait partie des destinataires
    /// BUG FIX: L'ancienne version comparait userId == currentUserId dans une boucle
    /// mais les recipientIds excluaient déjà le currentUserId → la notification locale
    /// ne se déclenchait JAMAIS. Maintenant on vérifie correctement.
    private func scheduleLocalNotificationForCurrentDevice(
        recipientIds: [String],
        title: String,
        body: String,
        sessionId: String,
        eventType: String
    ) async {
        // Vérifier que l'utilisateur actuel est bien un destinataire
        guard let currentUserId = SessionManager.shared.currentUser?.id,
              recipientIds.contains(currentUserId) else {
            return
        }

        // Vérifier que les notifications sont autorisées
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            eventLogger.info("ℹ️ Notifications not authorized, skipping local notification")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SESSION_EVENT"
        content.threadIdentifier = sessionId // Regrouper par session
        content.userInfo = [
            "sessionId": sessionId,
            "eventType": eventType
        ]

        // Délai minimal pour la notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let identifier = "\(sessionId)_\(eventType)_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            eventLogger.info("✅ Local notification scheduled for immediate display")
        } catch {
            eventLogger.error("❌ Local notification failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Push Token Management

    /// Sauvegarde le push token d'un utilisateur dans Firestore
    func savePushToken(userId: String, token: String) async throws {
        guard !userId.isEmpty, !token.isEmpty else {
            eventLogger.warning("⚠️ Cannot save push token: empty userId or token")
            return
        }

        eventLogger.info("💾 Saving push token for user \(userId)")

        try await db.collection("users").document(userId).updateData([
            "pushToken": token,
            "pushTokenUpdatedAt": Timestamp(date: Date())
        ])

        eventLogger.info("✅ Push token saved successfully")
    }

    /// Supprime le push token d'un utilisateur (lors de la déconnexion)
    func removePushToken(userId: String) async throws {
        guard !userId.isEmpty else {
            eventLogger.warning("⚠️ Cannot remove push token: empty userId")
            return
        }

        eventLogger.info("🗑️ Removing push token for user \(userId)")

        try await db.collection("users").document(userId).updateData([
            "pushToken": FieldValue.delete(),
            "pushTokenUpdatedAt": FieldValue.delete()
        ])

        eventLogger.info("✅ Push token removed successfully")
    }

    // MARK: - Join Request Notifications

    /// Notifie le leader qu'un utilisateur veut rejoindre sa session (mais est déjà dans une autre)
    func notifyJoinRequest(request: JoinRequest, targetSession: Session) async {
        eventLogger.info("📢 Notifying leader about join request from \(request.username)")

        let title = "Demande de rejoindre la session"
        let body = "\(request.username) veut rejoindre \"\(targetSession.title)\" mais est déjà dans \"\(request.currentSessionTitle ?? "une autre session")\""

        await sendNotificationToMembers(
            recipientIds: [request.leaderId],
            title: title,
            body: body,
            sessionId: targetSession.id ?? "",
            eventType: "join_request"
        )
    }

    /// Notifie l'utilisateur que sa demande a été approuvée
    func notifyJoinRequestApproved(request: JoinRequest) async {
        eventLogger.info("✅ Notifying user \(request.username) that join request was approved")

        let title = "Demande acceptée ✅"
        let body = "Tu as été accepté dans \"\(request.targetSessionTitle)\". Tu as été retiré de ton ancienne session."

        await sendNotificationToMembers(
            recipientIds: [request.userId],
            title: title,
            body: body,
            sessionId: request.targetSessionId,
            eventType: "join_request_approved"
        )
    }

    /// Notifie l'utilisateur que sa demande a été rejetée
    func notifyJoinRequestRejected(request: JoinRequest) async {
        eventLogger.info("❌ Notifying user \(request.username) that join request was rejected")

        let title = "Demande refusée"
        let body = "Ta demande pour rejoindre \"\(request.targetSessionTitle)\" a été refusée. Tu restes dans ta session actuelle."

        await sendNotificationToMembers(
            recipientIds: [request.userId],
            title: title,
            body: body,
            sessionId: request.currentSessionId ?? "",
            eventType: "join_request_rejected"
        )
    }
}