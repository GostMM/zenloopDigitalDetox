//
//  SocialNotificationManager.swift
//  zenloop
//
//  Gestionnaire de notifications pour les sessions sociales
//  Gère les mentions, messages, demandes de pause, etc.
//

import Foundation
import FirebaseFirestore
import os.log

private let socialNotifLogger = Logger(subsystem: "com.app.zenloop", category: "SocialNotification")

// MARK: - Social Notification Types

enum SocialNotificationType: String, Codable {
    case message = "message"                    // Nouveau message dans une session
    case mention = "mention"                    // Mention dans un message
    case pauseRequest = "pause_request"         // Demande de pause
    case pauseAccepted = "pause_accepted"       // Demande de pause acceptée
    case pauseDeclined = "pause_declined"       // Demande de pause refusée
    case sessionStarted = "session_started"     // Session démarrée
    case sessionPaused = "session_paused"       // Session mise en pause
    case sessionResumed = "session_resumed"     // Session reprise
    case sessionCompleted = "session_completed" // Session terminée
    case memberJoined = "member_joined"         // Nouveau membre
    case memberLeft = "member_left"             // Membre parti
    case invitation = "invitation"              // Invitation à rejoindre
}

struct SocialNotification: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String                  // Destinataire
    var type: SocialNotificationType
    var sessionId: String?
    var sessionTitle: String?
    var fromUserId: String?
    var fromUsername: String?
    var message: String
    var messageId: String?              // Pour les mentions
    var isRead: Bool
    var timestamp: Timestamp
    var actionUrl: String?              // Pour navigation (ex: zenloop://session/abc123)

    enum CodingKeys: String, CodingKey {
        case id, userId, type, sessionId, sessionTitle
        case fromUserId, fromUsername, message, messageId
        case isRead, timestamp, actionUrl
    }
}

// MARK: - Social Notification Manager

@MainActor
class SocialNotificationManager: ObservableObject {
    static let shared = SocialNotificationManager()

    @Published var notifications: [SocialNotification] = []
    @Published var unreadCount: Int = 0

    private let db = Firestore.firestore()
    private var notificationsListener: ListenerRegistration?

    private init() {
        socialNotifLogger.info("SocialNotificationManager initialized")
    }

    // MARK: - Listener

    func startListening(userId: String) {
        stopListening()

        notificationsListener = db.collection("socialNotifications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    socialNotifLogger.error("❌ Error listening to notifications: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.notifications = snapshot.documents.compactMap { doc in
                    try? doc.data(as: SocialNotification.self)
                }

                self.unreadCount = self.notifications.filter { !$0.isRead }.count

                socialNotifLogger.info("✅ Loaded \(self.notifications.count) notifications (\(self.unreadCount) unread)")
            }
    }

    func stopListening() {
        notificationsListener?.remove()
        notificationsListener = nil
    }

    // MARK: - Create Notifications

    func createNotification(
        userId: String,
        type: SocialNotificationType,
        sessionId: String? = nil,
        sessionTitle: String? = nil,
        fromUserId: String? = nil,
        fromUsername: String? = nil,
        message: String,
        messageId: String? = nil,
        actionUrl: String? = nil
    ) async throws {
        let notification = SocialNotification(
            id: nil,
            userId: userId,
            type: type,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            fromUserId: fromUserId,
            fromUsername: fromUsername,
            message: message,
            messageId: messageId,
            isRead: false,
            timestamp: Timestamp(date: Date()),
            actionUrl: actionUrl
        )

        try db.collection("socialNotifications").addDocument(from: notification)
        socialNotifLogger.info("📨 Created \(type.rawValue) notification for user \(userId)")
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: String) async throws {
        try await db.collection("socialNotifications")
            .document(notificationId)
            .updateData(["isRead": true])

        socialNotifLogger.info("✅ Marked notification \(notificationId) as read")
    }

    func markAllAsRead(userId: String) async throws {
        let batch = db.batch()

        let unreadNotifs = try await db.collection("socialNotifications")
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        for doc in unreadNotifs.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }

        try await batch.commit()
        socialNotifLogger.info("✅ Marked all notifications as read for user \(userId)")
    }

    // MARK: - Delete Notification

    func deleteNotification(notificationId: String) async throws {
        try await db.collection("socialNotifications")
            .document(notificationId)
            .delete()

        socialNotifLogger.info("🗑️ Deleted notification \(notificationId)")
    }

    func clearAllNotifications(userId: String) async throws {
        let batch = db.batch()

        let allNotifs = try await db.collection("socialNotifications")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for doc in allNotifs.documents {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()
        socialNotifLogger.info("🗑️ Cleared all notifications for user \(userId)")
    }

    // MARK: - Helper: Create Mention Notifications

    func createMentionNotifications(
        messageContent: String,
        sessionId: String,
        sessionTitle: String,
        messageId: String,
        fromUserId: String,
        fromUsername: String,
        sessionMembers: [SessionMember]
    ) async throws {
        // Détecter les mentions (@username)
        let mentions = extractMentions(from: messageContent)

        for mention in mentions {
            // Trouver le membre mentionné
            if let mentionedMember = sessionMembers.first(where: { $0.username.lowercased() == mention.lowercased() }),
               let mentionedUserId = mentionedMember.id,
               mentionedUserId != fromUserId { // Ne pas notifier l'auteur

                let actionUrl = "zenloop://session/\(sessionId)?message=\(messageId)"

                try await createNotification(
                    userId: mentionedUserId,
                    type: .mention,
                    sessionId: sessionId,
                    sessionTitle: sessionTitle,
                    fromUserId: fromUserId,
                    fromUsername: fromUsername,
                    message: "\(fromUsername) vous a mentionné : \(messageContent)",
                    messageId: messageId,
                    actionUrl: actionUrl
                )
            }
        }
    }

    // MARK: - Helper: Extract Mentions

    private func extractMentions(from text: String) -> [String] {
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        return results.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }
    }

    // MARK: - Helper: Create Pause Request Notification

    func notifyPauseRequest(
        leaderId: String,
        sessionId: String,
        sessionTitle: String,
        requesterId: String,
        requesterUsername: String,
        reason: String?
    ) async throws {
        let reasonText = reason != nil ? " : \"\(reason!)\"" : ""
        let message = "\(requesterUsername) demande une pause\(reasonText)"
        let actionUrl = "zenloop://session/\(sessionId)?tab=pauseRequests"

        try await createNotification(
            userId: leaderId,
            type: .pauseRequest,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            fromUserId: requesterId,
            fromUsername: requesterUsername,
            message: message,
            actionUrl: actionUrl
        )
    }

    // MARK: - Helper: Notify Pause Response

    func notifyPauseResponse(
        requesterId: String,
        sessionId: String,
        sessionTitle: String,
        leaderId: String,
        leaderUsername: String,
        accepted: Bool
    ) async throws {
        let type: SocialNotificationType = accepted ? .pauseAccepted : .pauseDeclined
        let message = accepted
            ? "\(leaderUsername) a accepté votre demande de pause"
            : "\(leaderUsername) a refusé votre demande de pause"
        let actionUrl = "zenloop://session/\(sessionId)"

        try await createNotification(
            userId: requesterId,
            type: type,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            fromUserId: leaderId,
            fromUsername: leaderUsername,
            message: message,
            actionUrl: actionUrl
        )
    }
}
