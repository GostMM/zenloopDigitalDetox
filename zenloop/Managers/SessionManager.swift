//
//  SessionManager.swift
//  zenloop
//
//  Gère les sessions sociales avec Firebase Firestore
//  Real-time listeners pour synchronisation instantanée
//
//  NEW: Pause/Resume/Stop session
//  NEW: Pause requests (member -> leader)
//  NEW: Leader auto-ready at creation
//  NEW: Late join (members join active session directly)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import os.log

private let sessionLogger = Logger(subsystem: "com.app.zenloop", category: "SessionManager")

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // MARK: - Published Properties

    @Published var currentUser: SessionUser?
    @Published var mySessions: [Session] = []
    @Published var publicSessions: [Session] = []
    @Published var currentSession: Session?
    @Published var currentSessionMembers: [SessionMember] = []
    @Published var currentSessionMessages: [SessionMessage] = []
    @Published var pendingInvitations: [SessionInvitation] = []
    @Published var pendingPauseRequests: [PauseRequest] = []

    // MARK: - Private Properties

    private let db = Firestore.firestore()

    private var userListener: ListenerRegistration?
    private var mySessionsListener: ListenerRegistration?
    private var publicSessionsListener: ListenerRegistration?
    private var invitationsListener: ListenerRegistration?
    private var currentSessionListeners: [ListenerRegistration] = []

    private let localAppsKey = "local_session_apps"

    private init() {
        sessionLogger.info("SessionManager initialized")
    }

    // MARK: - Authentication & User Setup

    func setupUser(uid: String, username: String, appleUserId: String) async throws {
        sessionLogger.critical("Setting up user: \(username)")

        let userRef = db.collection("users").document(uid)
        let snapshot = try await userRef.getDocument()

        if snapshot.exists {
            do {
                currentUser = try snapshot.data(as: SessionUser.self)
            } catch {
                try await userRef.delete()
                currentUser = nil
            }
        }

        if currentUser == nil {
            let newUser = SessionUser(
                id: uid,
                username: username,
                appleUserId: appleUserId,
                createdAt: Timestamp(date: Date()),
                sessionHistory: [],
                pushToken: nil,
                totalSessionsJoined: 0,
                totalSessionsCreated: 0,
                currentStreak: 0,
                lastSeen: Timestamp(date: Date())
            )
            try userRef.setData(from: newUser)
            currentUser = newUser
        }

        startUserListener(uid: uid)
    }

    func loadUserSessions() async {
        guard let uid = currentUser?.id else { return }
        startMySessionsListener(uid: uid)
        startPublicSessionsListener()
        startInvitationsListener(uid: uid)
    }

    func clearLocalState() {
        currentUser = nil
        mySessions = []
        publicSessions = []
        currentSession = nil
        currentSessionMembers = []
        currentSessionMessages = []
        pendingInvitations = []
        pendingPauseRequests = []
    }

    func updateLastSeen() async {
        guard let uid = currentUser?.id else { return }
        let userRef = db.collection("users").document(uid)
        try? await userRef.updateData(["lastSeen": FieldValue.serverTimestamp()])
    }

    // MARK: - Session Creation (Leader auto-ready)

    func createSession(
        title: String,
        description: String,
        visibility: SessionVisibility,
        maxParticipants: Int?,
        suggestedAppsCount: Int
    ) async throws -> Session {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let inviteCode = generateInviteCode()

        var newSession = Session(
            id: nil, title: title, description: description,
            leaderId: currentUser.id!, leaderUsername: currentUser.username,
            visibility: visibility, inviteCode: inviteCode,
            maxParticipants: maxParticipants, status: .lobby,
            createdAt: Timestamp(date: Date()),
            startedAt: nil, endedAt: nil, pausedAt: nil, pausedBy: nil,
            memberIds: [currentUser.id!], suggestedAppsCount: suggestedAppsCount
        )

        let sessionRef = try db.collection("sessions").addDocument(from: newSession)
        newSession.id = sessionRef.documentID

        // Leader is auto-ready
        let leaderMember = SessionMember(
            id: currentUser.id, username: currentUser.username,
            role: .leader, status: .ready,
            joinedAt: Timestamp(date: Date()), leftAt: nil,
            isReady: true, bypassAttempts: 0, messagesCount: 0,
            hasSelectedApps: suggestedAppsCount > 0,
            selectedAppsCount: suggestedAppsCount
        )
        try sessionRef.collection("members").document(currentUser.id!).setData(from: leaderMember)

        let event = SessionEvent(
            id: nil, userId: currentUser.id, username: currentUser.username,
            eventType: .sessionCreated, timestamp: Timestamp(date: Date()),
            metadata: ["sessionId": sessionRef.documentID]
        )
        try sessionRef.collection("events").addDocument(from: event)

        let userRef = db.collection("users").document(currentUser.id!)
        try await userRef.updateData([
            "sessionHistory": FieldValue.arrayUnion([sessionRef.documentID]),
            "totalSessionsCreated": FieldValue.increment(Int64(1))
        ])

        return newSession
    }

    // MARK: - Session Joining (Late join support)

    func joinSession(inviteCode: String) async throws -> Session {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let query = db.collection("sessions")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .whereField("status", in: [
                SessionStatus.lobby.rawValue,
                SessionStatus.active.rawValue,
                SessionStatus.paused.rawValue
            ])
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let sessionDoc = snapshot.documents.first else { throw SessionError.sessionNotFound }

        var session = try sessionDoc.data(as: Session.self)

        if session.memberIds.contains(currentUser.id!) { return session }
        if let max = session.maxParticipants, session.memberIds.count >= max { throw SessionError.sessionFull }

        let batch = db.batch()
        let sessionRef = db.collection("sessions").document(sessionDoc.documentID)

        batch.updateData(["memberIds": FieldValue.arrayUnion([currentUser.id!])], forDocument: sessionRef)

        // Late join logic
        let memberStatus: MemberStatus
        let memberIsReady: Bool
        switch session.status {
        case .active:  memberStatus = .active; memberIsReady = true
        case .paused:  memberStatus = .paused; memberIsReady = true
        default:       memberStatus = .joined; memberIsReady = false
        }

        let newMember = SessionMember(
            id: currentUser.id, username: currentUser.username,
            role: .member, status: memberStatus,
            joinedAt: Timestamp(date: Date()), leftAt: nil,
            isReady: memberIsReady, bypassAttempts: 0, messagesCount: 0,
            hasSelectedApps: false, selectedAppsCount: 0
        )
        let memberRef = sessionRef.collection("members").document(currentUser.id!)
        try batch.setData(from: newMember, forDocument: memberRef)

        let event = SessionEvent(
            id: nil, userId: currentUser.id, username: currentUser.username,
            eventType: .memberJoined, timestamp: Timestamp(date: Date()),
            metadata: ["lateJoin": (session.status != .lobby) ? "true" : "false"]
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let userRef = db.collection("users").document(currentUser.id!)
        batch.updateData([
            "sessionHistory": FieldValue.arrayUnion([sessionDoc.documentID]),
            "totalSessionsJoined": FieldValue.increment(Int64(1))
        ], forDocument: userRef)

        if session.status != .lobby {
            let sysMsg = SessionMessage(
                id: nil, userId: "system", username: "Systeme",
                content: "\(currentUser.username) a rejoint la session en cours",
                messageType: .systemAlert, timestamp: Timestamp(date: Date())
            )
            let msgRef = sessionRef.collection("messages").document()
            try batch.setData(from: sysMsg, forDocument: msgRef)
        }

        try await batch.commit()
        session.memberIds.append(currentUser.id!)
        return session
    }

    // MARK: - Member Actions

    func markAsReady(sessionId: String, appsCount: Int) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let memberRef = db.collection("sessions").document(sessionId)
            .collection("members").document(uid)

        try await memberRef.updateData([
            "isReady": true,
            "status": MemberStatus.ready.rawValue,
            "hasSelectedApps": appsCount > 0,
            "selectedAppsCount": appsCount
        ])

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .memberReady, timestamp: Timestamp(date: Date()),
            metadata: ["appsCount": "\(appsCount)"]
        )
        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)
    }

    func leaveSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let batch = db.batch()
        let sessionRef = db.collection("sessions").document(sessionId)
        let memberRef = sessionRef.collection("members").document(uid)

        batch.updateData(["status": MemberStatus.left.rawValue, "leftAt": FieldValue.serverTimestamp()], forDocument: memberRef)
        batch.updateData(["memberIds": FieldValue.arrayRemove([uid])], forDocument: sessionRef)

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .memberLeft, timestamp: Timestamp(date: Date()), metadata: nil)
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "\(currentUser?.username ?? "Quelqu'un") a quitte la session", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()
        stopCurrentSessionListeners()
        removeLocalApps(sessionId: sessionId)
    }

    // MARK: - Leader: Start (can start alone)

    func startSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        guard session.leaderId == uid else { throw SessionError.notAuthorized }

        let batch = db.batch()

        batch.updateData([
            "status": SessionStatus.active.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ], forDocument: sessionRef)

        let membersSnapshot = try await sessionRef.collection("members")
            .whereField("status", in: [MemberStatus.ready.rawValue, MemberStatus.joined.rawValue])
            .getDocuments()

        for memberDoc in membersSnapshot.documents {
            let mRef = sessionRef.collection("members").document(memberDoc.documentID)
            batch.updateData(["status": MemberStatus.active.rawValue, "isReady": true], forDocument: mRef)
        }

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .sessionStarted, timestamp: Timestamp(date: Date()), metadata: ["memberCount": "\(membersSnapshot.documents.count)"])
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "La session a demarre ! Focus time !", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        // Notifier tous les membres
        let notifManager = SocialNotificationManager.shared
        for memberDoc in membersSnapshot.documents where memberDoc.documentID != uid {
            try? await notifManager.createNotification(
                userId: memberDoc.documentID,
                type: .sessionStarted,
                sessionId: sessionId,
                sessionTitle: session.title,
                fromUserId: uid,
                fromUsername: currentUser?.username,
                message: "La session \(session.title) a démarré !",
                actionUrl: "zenloop://session/\(sessionId)"
            )
        }
    }

    // MARK: - Leader: Pause

    func pauseSession(sessionId: String, reason: String? = nil) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        guard session.leaderId == uid else { throw SessionError.notAuthorized }
        guard session.status == .active else { throw SessionError.invalidSessionState }

        let batch = db.batch()

        batch.updateData([
            "status": SessionStatus.paused.rawValue,
            "pausedAt": FieldValue.serverTimestamp(),
            "pausedBy": uid
        ], forDocument: sessionRef)

        let membersSnapshot = try await sessionRef.collection("members")
            .whereField("status", isEqualTo: MemberStatus.active.rawValue)
            .getDocuments()

        for memberDoc in membersSnapshot.documents {
            let mRef = sessionRef.collection("members").document(memberDoc.documentID)
            batch.updateData(["status": MemberStatus.paused.rawValue], forDocument: mRef)
        }

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .sessionPaused, timestamp: Timestamp(date: Date()), metadata: reason != nil ? ["reason": reason!] : nil)
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let reasonText = reason != nil ? " - Raison : \(reason!)" : ""
        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "Session mise en pause par \(currentUser?.username ?? "le leader")\(reasonText)", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()
    }

    // MARK: - Leader: Resume

    func resumeSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        guard session.leaderId == uid else { throw SessionError.notAuthorized }
        guard session.status == .paused else { throw SessionError.invalidSessionState }

        let batch = db.batch()

        batch.updateData([
            "status": SessionStatus.active.rawValue,
            "pausedAt": FieldValue.delete(),
            "pausedBy": FieldValue.delete()
        ], forDocument: sessionRef)

        let membersSnapshot = try await sessionRef.collection("members")
            .whereField("status", isEqualTo: MemberStatus.paused.rawValue)
            .getDocuments()

        for memberDoc in membersSnapshot.documents {
            let mRef = sessionRef.collection("members").document(memberDoc.documentID)
            batch.updateData(["status": MemberStatus.active.rawValue], forDocument: mRef)
        }

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .sessionResumed, timestamp: Timestamp(date: Date()), metadata: nil)
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "Session reprise ! C'est reparti !", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()
    }

    // MARK: - Leader: Stop

    func stopSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        guard session.leaderId == uid else { throw SessionError.notAuthorized }
        guard session.status == .active || session.status == .paused else { throw SessionError.invalidSessionState }

        let batch = db.batch()

        batch.updateData([
            "status": SessionStatus.completed.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ], forDocument: sessionRef)

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .sessionStopped, timestamp: Timestamp(date: Date()), metadata: nil)
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "Session terminee ! Bravo a tous !", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()
    }

    // MARK: - Pause Requests (Member -> Leader)

    func requestPause(sessionId: String, reason: String?) async throws {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let pauseRequest = PauseRequest(
            id: nil, sessionId: sessionId,
            requesterId: currentUser.id!, requesterUsername: currentUser.username,
            reason: reason, status: .pending,
            requestedAt: Timestamp(date: Date()),
            respondedAt: nil, respondedBy: nil
        )

        let sessionRef = db.collection("sessions").document(sessionId)
        try sessionRef.collection("pauseRequests").addDocument(from: pauseRequest)

        let event = SessionEvent(id: nil, userId: currentUser.id, username: currentUser.username, eventType: .pauseRequested, timestamp: Timestamp(date: Date()), metadata: reason != nil ? ["reason": reason!] : nil)
        try sessionRef.collection("events").addDocument(from: event)

        let reasonText = reason != nil ? " : \"\(reason!)\"" : ""
        let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "\(currentUser.username) demande une pause\(reasonText)", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
        try sessionRef.collection("messages").addDocument(from: sysMsg)

        // Notifier le leader
        let sessionDoc = try await sessionRef.getDocument()
        if let session = try? sessionDoc.data(as: Session.self) {
            let notifManager = SocialNotificationManager.shared
            try await notifManager.notifyPauseRequest(
                leaderId: session.leaderId,
                sessionId: sessionId,
                sessionTitle: session.title,
                requesterId: currentUser.id!,
                requesterUsername: currentUser.username,
                reason: reason
            )
        }
    }

    func respondToPauseRequest(requestId: String, sessionId: String, accept: Bool) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let requestRef = sessionRef.collection("pauseRequests").document(requestId)

        try await requestRef.updateData([
            "status": accept ? PauseRequestStatus.accepted.rawValue : PauseRequestStatus.declined.rawValue,
            "respondedAt": FieldValue.serverTimestamp(),
            "respondedBy": uid
        ])

        let requestDoc = try await requestRef.getDocument()
        let pauseReq = try requestDoc.data(as: PauseRequest.self)

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: accept ? .pauseRequestAccepted : .pauseRequestDeclined, timestamp: Timestamp(date: Date()), metadata: ["requesterId": pauseReq.requesterId, "requesterUsername": pauseReq.requesterUsername])
        try sessionRef.collection("events").addDocument(from: event)

        // Notifier le demandeur
        let sessionDoc = try await sessionRef.getDocument()
        if let session = try? sessionDoc.data(as: Session.self) {
            let notifManager = SocialNotificationManager.shared
            try await notifManager.notifyPauseResponse(
                requesterId: pauseReq.requesterId,
                sessionId: sessionId,
                sessionTitle: session.title,
                leaderId: uid,
                leaderUsername: currentUser?.username ?? "Leader",
                accepted: accept
            )
        }

        if accept {
            try await pauseSession(sessionId: sessionId, reason: "Demande de \(pauseReq.requesterUsername)")
        } else {
            let sysMsg = SessionMessage(id: nil, userId: "system", username: "Systeme", content: "Demande de pause de \(pauseReq.requesterUsername) refusee", messageType: .systemAlert, timestamp: Timestamp(date: Date()))
            try sessionRef.collection("messages").addDocument(from: sysMsg)
        }
    }

    // MARK: - Dissolve

    func dissolveSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        guard session.leaderId == uid else { throw SessionError.notAuthorized }

        try await sessionRef.updateData([
            "status": SessionStatus.dissolved.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ])

        let event = SessionEvent(id: nil, userId: uid, username: currentUser?.username, eventType: .sessionDissolved, timestamp: Timestamp(date: Date()), metadata: nil)
        try sessionRef.collection("events").addDocument(from: event)

        stopCurrentSessionListeners()
        removeLocalApps(sessionId: sessionId)
    }

    // MARK: - Messaging

    func sendMessage(sessionId: String, content: String, type: MessageType = .text) async throws {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let message = SessionMessage(id: nil, userId: currentUser.id!, username: currentUser.username, content: content, messageType: type, timestamp: Timestamp(date: Date()))
        try db.collection("sessions").document(sessionId).collection("messages").addDocument(from: message)
    }

    // MARK: - Real-time Listeners

    private func startUserListener(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
                self.currentUser = try? snapshot.data(as: SessionUser.self)
            }
    }

    private func startMySessionsListener(uid: String) {
        mySessionsListener?.remove()
        mySessionsListener = db.collection("sessions")
            .whereField("memberIds", arrayContains: uid)
            .whereField("status", in: [SessionStatus.lobby.rawValue, SessionStatus.active.rawValue, SessionStatus.paused.rawValue])
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.mySessions = snapshot.documents.compactMap { try? $0.data(as: Session.self) }
            }
    }

    private func startPublicSessionsListener() {
        publicSessionsListener?.remove()
        publicSessionsListener = db.collection("sessions")
            .whereField("visibility", isEqualTo: SessionVisibility.publicSession.rawValue)
            .whereField("status", in: [SessionStatus.lobby.rawValue, SessionStatus.active.rawValue, SessionStatus.paused.rawValue])
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                let allPublic = snapshot.documents.compactMap { try? $0.data(as: Session.self) }
                let uid = self.currentUser?.id ?? ""
                self.publicSessions = allPublic.filter { !$0.memberIds.contains(uid) }
            }
    }

    private func startInvitationsListener(uid: String) {
        invitationsListener?.remove()
        invitationsListener = db.collection("invitations")
            .whereField("toUserId", isEqualTo: uid)
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.pendingInvitations = snapshot.documents.compactMap { try? $0.data(as: SessionInvitation.self) }
            }
    }

    func startSessionListener(sessionId: String) {
        stopCurrentSessionListeners()

        let sL = db.collection("sessions").document(sessionId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot, snapshot.exists else { return }
                self.currentSession = try? snapshot.data(as: Session.self)
            }

        let mL = db.collection("sessions").document(sessionId).collection("members")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.currentSessionMembers = snapshot.documents.compactMap { try? $0.data(as: SessionMember.self) }
            }

        let msgL = db.collection("sessions").document(sessionId).collection("messages")
            .order(by: "timestamp", descending: false).limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.currentSessionMessages = snapshot.documents.compactMap { try? $0.data(as: SessionMessage.self) }
            }

        let pL = db.collection("sessions").document(sessionId).collection("pauseRequests")
            .whereField("status", isEqualTo: PauseRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.pendingPauseRequests = snapshot.documents.compactMap { try? $0.data(as: PauseRequest.self) }
            }

        currentSessionListeners = [sL, mL, msgL, pL]
    }

    private func stopCurrentSessionListeners() {
        currentSessionListeners.forEach { $0.remove() }
        currentSessionListeners.removeAll()
        currentSession = nil
        currentSessionMembers = []
        currentSessionMessages = []
        pendingPauseRequests = []
    }

    func stopListeners() {
        userListener?.remove(); userListener = nil
        mySessionsListener?.remove(); mySessionsListener = nil
        publicSessionsListener?.remove(); publicSessionsListener = nil
        invitationsListener?.remove(); invitationsListener = nil
        stopCurrentSessionListeners()
    }

    // MARK: - Local Apps Storage

    func saveLocalApps(sessionId: String, appTokens: Data, count: Int) {
        let localApps = LocalSessionApps(sessionId: sessionId, userId: currentUser?.id ?? "", selectedAppTokens: appTokens, selectedAppsCount: count, lastUpdated: Date())
        guard let data = try? JSONEncoder().encode(localApps) else { return }
        UserDefaults.standard.set(data, forKey: "\(localAppsKey)_\(sessionId)")
    }

    func getLocalApps(sessionId: String) -> LocalSessionApps? {
        guard let data = UserDefaults.standard.data(forKey: "\(localAppsKey)_\(sessionId)") else { return nil }
        return try? JSONDecoder().decode(LocalSessionApps.self, from: data)
    }

    func removeLocalApps(sessionId: String) {
        UserDefaults.standard.removeObject(forKey: "\(localAppsKey)_\(sessionId)")
    }

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

enum SessionError: LocalizedError {
    case notAuthenticated, notAuthorized, sessionNotFound, sessionFull, noReadyMembers, invalidSessionState

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        case .notAuthorized: return "Not authorized for this action"
        case .sessionNotFound: return "Session not found with this invite code"
        case .sessionFull: return "Session is full"
        case .noReadyMembers: return "No ready members to start session"
        case .invalidSessionState: return "Session is not in the correct state for this action"
        }
    }
}