//
//  SessionModels.swift
//  zenloop
//
//  Modèles pour les sessions sociales avec Firebase
//  ⚠️ IMPORTANT: Les apps sélectionnées restent PRIVÉES (Apple FamilyControls)
//
//  ✅ NEW: SessionStatus.paused, PauseRequest model, new event types
//  ✅ FIX: Tous les champs potentiellement absents rendus optionnels
//         pour éviter les erreurs de décodage Firestore
//

import Foundation
import FirebaseFirestore

// MARK: - Session User

struct SessionUser: Codable, Identifiable {
    @DocumentID var id: String?  // Firebase UID
    var username: String
    var appleUserId: String
    var createdAt: Timestamp
    var sessionHistory: [String]?       // ✅ FIX: Optionnel (peut être absent)
    var pushToken: String?
    var totalSessionsJoined: Int?       // ✅ FIX: Optionnel
    var totalSessionsCreated: Int?      // ✅ FIX: Optionnel
    var currentStreak: Int?             // ✅ FIX: Optionnel
    var lastSeen: Timestamp?

    // ✅ Helpers pour accès sûr
    var safeSessionHistory: [String] { sessionHistory ?? [] }
    var safeTotalSessionsJoined: Int { totalSessionsJoined ?? 0 }
    var safeTotalSessionsCreated: Int { totalSessionsCreated ?? 0 }
    var safeCurrentStreak: Int { currentStreak ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case appleUserId
        case createdAt
        case sessionHistory
        case pushToken
        case totalSessionsJoined
        case totalSessionsCreated
        case currentStreak
        case lastSeen
    }
}

// MARK: - Session

enum SessionStatus: String, Codable {
    case lobby = "lobby"           // En attente de démarrage
    case active = "active"         // Session en cours
    case paused = "paused"         // Session en pause
    case completed = "completed"   // Terminée avec succès
    case dissolved = "dissolved"   // Dissoute par le leader
}

// MARK: - Join Request (pour éviter le chevauchement de sessions)

enum JoinRequestStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case cancelled = "cancelled"
}

struct JoinRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var username: String
    var targetSessionId: String
    var targetSessionTitle: String
    var currentSessionId: String?
    var currentSessionTitle: String?
    var leaderId: String
    var status: JoinRequestStatus
    var createdAt: Timestamp
    var respondedAt: Timestamp?
    var message: String?

    enum CodingKeys: String, CodingKey {
        case id  // ✅ FIX: Nécessaire pour que @DocumentID soit décodé
        case userId
        case username
        case targetSessionId
        case targetSessionTitle
        case currentSessionId
        case currentSessionTitle
        case leaderId
        case status
        case createdAt
        case respondedAt
        case message
    }
}

enum SessionVisibility: String, Codable {
    case publicSession = "public"
    case privateSession = "private"
}

struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String?                // ✅ FIX: Optionnel
    var leaderId: String
    var leaderUsername: String
    var visibility: SessionVisibility?      // ✅ FIX: Optionnel
    var inviteCode: String
    var maxParticipants: Int?
    var status: SessionStatus
    var createdAt: Timestamp
    var startedAt: Timestamp?
    var endedAt: Timestamp?
    var pausedAt: Timestamp?
    var pausedBy: String?
    var memberIds: [String]?                // ✅ FIX: Optionnel (sécurité)

    // Durée de session
    var durationMinutes: Int?
    var scheduledEndTime: Timestamp?

    // Sessions programmées
    var scheduledStartTime: Timestamp?
    var isScheduled: Bool?                  // ✅ FIX: Bool? au lieu de Bool

    var suggestedAppsCount: Int?            // ✅ FIX: Int? au lieu de Int

    // Background image
    var backgroundImageUrl: String?

    // Sélection d'apps partagée — publiée par le leader, appliquée par tous les membres.
    // Encode un FamilyActivitySelection (Data base64 via Firestore).
    var sharedAppTokens: Data?
    var sharedAppsCount: Int?

    // ✅ Helpers pour accès sûr
    var safeDescription: String { description ?? "" }
    var safeVisibility: SessionVisibility { visibility ?? .privateSession }
    var safeMemberIds: [String] { memberIds ?? [] }
    var isScheduledSession: Bool { isScheduled ?? false }
    var safeAppsCount: Int { suggestedAppsCount ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case leaderId
        case leaderUsername
        case visibility
        case inviteCode
        case maxParticipants
        case status
        case createdAt
        case startedAt
        case endedAt
        case pausedAt
        case pausedBy
        case memberIds
        case durationMinutes
        case scheduledEndTime
        case scheduledStartTime
        case isScheduled
        case suggestedAppsCount
        case backgroundImageUrl
        case sharedAppTokens
        case sharedAppsCount
    }
}

// MARK: - Session Member

enum MemberStatus: String, Codable {
    case joined = "joined"
    case ready = "ready"
    case active = "active"
    case paused = "paused"
    case left = "left"
}

enum MemberRole: String, Codable {
    case leader = "leader"
    case member = "member"
}

struct SessionMember: Codable, Identifiable {
    @DocumentID var id: String?  // User UID
    var username: String
    var role: MemberRole
    var status: MemberStatus
    var joinedAt: Timestamp
    var leftAt: Timestamp?
    var isReady: Bool?                  // ✅ FIX: Optionnel
    var bypassAttempts: Int?           // ✅ FIX: Optionnel
    var messagesCount: Int?            // ✅ FIX: Optionnel

    var hasSelectedApps: Bool?         // ✅ FIX: Optionnel
    var selectedAppsCount: Int?        // ✅ FIX: Optionnel

    // ✅ Helpers pour accès sûr
    var safeIsReady: Bool { isReady ?? false }
    var safeBypassAttempts: Int { bypassAttempts ?? 0 }
    var safeMessagesCount: Int { messagesCount ?? 0 }
    var safeHasSelectedApps: Bool { hasSelectedApps ?? false }
    var safeSelectedAppsCount: Int { selectedAppsCount ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case status
        case joinedAt
        case leftAt
        case isReady
        case bypassAttempts
        case messagesCount
        case hasSelectedApps
        case selectedAppsCount
    }
}

// MARK: - Session Message

enum MessageType: String, Codable {
    case text = "text"
    case encouragement = "encouragement"
    case systemAlert = "system"
}

struct SessionMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var username: String
    var content: String
    var messageType: MessageType
    var timestamp: Timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case content
        case messageType
        case timestamp
    }
}

// MARK: - Session Event

enum SessionEventType: String, Codable {
    case sessionCreated = "session_created"
    case sessionStarted = "session_started"
    case sessionPaused = "session_paused"
    case sessionResumed = "session_resumed"
    case sessionStopped = "session_stopped"
    case sessionCompleted = "session_completed"
    case sessionDissolved = "session_dissolved"
    case memberJoined = "member_joined"
    case memberReady = "member_ready"
    case memberLeft = "member_left"
    case memberBypassAttempt = "member_bypass_attempt"
    case pauseRequested = "pause_requested"
    case pauseRequestAccepted = "pause_request_accepted"
    case pauseRequestDeclined = "pause_request_declined"
}

struct SessionEvent: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String?
    var username: String?
    var eventType: SessionEventType
    var timestamp: Timestamp
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case eventType
        case timestamp
        case metadata
    }
}

// MARK: - Pause Request

enum PauseRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}

struct PauseRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var sessionId: String
    var requesterId: String
    var requesterUsername: String
    var reason: String?
    var status: PauseRequestStatus
    var requestedAt: Timestamp
    var respondedAt: Timestamp?
    var respondedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case requesterId
        case requesterUsername
        case reason
        case status
        case requestedAt
        case respondedAt
        case respondedBy
    }
}

// MARK: - Invitation

enum InvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}

struct SessionInvitation: Codable, Identifiable {
    @DocumentID var id: String?
    var sessionId: String
    var fromUserId: String
    var fromUsername: String
    var toUserId: String
    var toUsername: String
    var status: InvitationStatus
    var sentAt: Timestamp
    var respondedAt: Timestamp?
    var sessionTitle: String
    var sessionDescription: String?    // ✅ FIX: Optionnel

    // Helper
    var safeSessionDescription: String { sessionDescription ?? "" }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case fromUserId
        case fromUsername
        case toUserId
        case toUsername
        case status
        case sentAt
        case respondedAt
        case sessionTitle
        case sessionDescription
    }
}

// MARK: - Local-only Models (Not synced to Firebase)

/// ⚠️ IMPORTANT: Ce modèle reste LOCAL uniquement
/// Les apps sélectionnées ne sont JAMAIS envoyées à Firebase
struct LocalSessionApps: Codable {
    let sessionId: String
    let userId: String
    let selectedAppTokens: Data  // FamilyActivitySelection encodée
    let selectedAppsCount: Int
    let lastUpdated: Date
}