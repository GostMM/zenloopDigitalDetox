//
//  SessionModels.swift
//  zenloop
//
//  Modèles pour les sessions sociales avec Firebase
//  ⚠️ IMPORTANT: Les apps sélectionnées restent PRIVÉES (Apple FamilyControls)
//
//  ✅ NEW: SessionStatus.paused, PauseRequest model, new event types
//

import Foundation
import FirebaseFirestore

// MARK: - Session User

struct SessionUser: Codable, Identifiable {
    @DocumentID var id: String?  // Firebase UID
    var username: String
    var appleUserId: String
    var createdAt: Timestamp
    var sessionHistory: [String] // Session IDs
    var pushToken: String?
    var totalSessionsJoined: Int
    var totalSessionsCreated: Int
    var currentStreak: Int
    var lastSeen: Timestamp?

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
    case paused = "paused"         // ✅ NEW: Session en pause
    case completed = "completed"   // Terminée avec succès
    case dissolved = "dissolved"   // Dissoute par le leader
}

enum SessionVisibility: String, Codable {
    case publicSession = "public"
    case privateSession = "private"
}

struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var leaderId: String
    var leaderUsername: String
    var visibility: SessionVisibility
    var inviteCode: String  // 6 caractères
    var maxParticipants: Int?
    var status: SessionStatus
    var createdAt: Timestamp
    var startedAt: Timestamp?
    var endedAt: Timestamp?
    var pausedAt: Timestamp?          // ✅ NEW: Quand la session a été mise en pause
    var pausedBy: String?             // ✅ NEW: UID de celui qui a déclenché la pause
    var memberIds: [String]  // Pour queries Firestore

    // ✅ NEW: Durée de session
    var durationMinutes: Int?        // Durée en minutes (nil = manuel)
    var scheduledEndTime: Timestamp? // Heure de fin prévue (calculée au démarrage)

    // ⚠️ IMPORTANT: PAS de liste d'apps car Apple ne permet pas de partager ça
    // Chaque membre choisit ses apps en privé
    var suggestedAppsCount: Int  // Nombre d'apps suggérées par le leader (sans détails)

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
        case suggestedAppsCount
    }
}

// MARK: - Session Member

enum MemberStatus: String, Codable {
    case joined = "joined"   // Vient de rejoindre
    case ready = "ready"     // Prêt à démarrer
    case active = "active"   // Session active
    case paused = "paused"   // ✅ NEW: En pause avec la session
    case left = "left"       // A quitté la session
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
    var isReady: Bool
    var bypassAttempts: Int
    var messagesCount: Int

    // ⚠️ APPLE RESTRICTION: Pas de selectedApps visible par les autres
    // Les apps restent sur l'appareil local uniquement
    var hasSelectedApps: Bool  // Booléen pour savoir s'il a choisi au moins 1 app
    var selectedAppsCount: Int  // Juste le nombre, pas les détails

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
    case sessionPaused = "session_paused"           // ✅ NEW
    case sessionResumed = "session_resumed"         // ✅ NEW
    case sessionStopped = "session_stopped"         // ✅ NEW
    case sessionCompleted = "session_completed"
    case sessionDissolved = "session_dissolved"
    case memberJoined = "member_joined"
    case memberReady = "member_ready"
    case memberLeft = "member_left"
    case memberBypassAttempt = "member_bypass_attempt"
    case pauseRequested = "pause_requested"         // ✅ NEW
    case pauseRequestAccepted = "pause_request_accepted" // ✅ NEW
    case pauseRequestDeclined = "pause_request_declined" // ✅ NEW
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

// MARK: - Pause Request ✅ NEW

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
    var respondedBy: String?  // UID du leader qui a répondu

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
    var sessionDescription: String

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