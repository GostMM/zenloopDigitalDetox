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
//  ✅ FIX: checkPendingScheduledActions() appelé dans loadUserSessions
//  ✅ FIX: scenePhaseHandler pour détecter le retour en foreground
//  ✅ FIX: Utilisation des safe accessors pour les champs optionnels
//  ✅ FIX: Meilleure gestion d'erreurs de décodage
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FamilyControls
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
    @Published var pendingJoinRequests: [JoinRequest] = []

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
                sessionLogger.error("❌ Failed to decode existing user, recreating: \(error.localizedDescription)")
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

        await loadActiveSession()
        await checkPendingScheduledActions()
    }

    func handleAppBecameActive() async {
        sessionLogger.info("📱 App became active — checking pending actions")
        await checkPendingScheduledActions()

        if currentSession == nil {
            await loadActiveSession()
        }
    }

    private func checkPendingScheduledActions() async {
        await ScheduledSessionCoordinator.shared.checkPendingActions()
    }

    func loadActiveSession() async {
        guard let uid = currentUser?.id else { return }

        do {
            let snapshot = try await db.collection("sessions")
                .whereField("memberIds", arrayContains: uid)
                .whereField("status", in: [SessionStatus.lobby.rawValue, SessionStatus.active.rawValue, SessionStatus.paused.rawValue])
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            if let sessionDoc = snapshot.documents.first,
               let session = try? sessionDoc.data(as: Session.self),
               let sessionId = session.id {
                startSessionListener(sessionId: sessionId)
                sessionLogger.info("✅ Auto-loaded current session (\(session.status.rawValue)): \(sessionId)")
            } else {
                sessionLogger.info("ℹ️ No current session found for user")
            }
        } catch {
            sessionLogger.error("❌ Failed to load current session: \(error.localizedDescription)")
        }
    }

    // MARK: - ✅ FIX V3: Force refresh bypassing Firestore cache

    /// Force une relecture du document session depuis le serveur (pas le cache)
    /// Appelé quand une session programmée devrait avoir démarré mais le listener n'a pas capté le changement
    func forceRefreshCurrentSession(sessionId: String) async {
        sessionLogger.info("🔄 [FORCE_REFRESH] Fetching session \(sessionId) from SERVER (bypassing cache)...")

        do {
            let sessionRef = db.collection("sessions").document(sessionId)

            // ✅ CRUCIAL: .source(.server) force Firestore à aller chercher sur le serveur
            // au lieu d'utiliser le cache local (qui peut être stale)
            let snapshot = try await sessionRef.getDocument(source: .server)

            guard snapshot.exists else {
                sessionLogger.warning("⚠️ [FORCE_REFRESH] Session document not found on server")
                return
            }

            if let session = try? snapshot.data(as: Session.self) {
                let oldStatus = self.currentSession?.status.rawValue ?? "nil"
                let newStatus = session.status.rawValue

                if oldStatus != newStatus {
                    sessionLogger.critical("🔄 [FORCE_REFRESH] STATUS CHANGED! \(oldStatus) → \(newStatus)")
                    // Mettre à jour immédiatement
                    await MainActor.run {
                        self.currentSession = session
                    }
                } else {
                    sessionLogger.info("🔄 [FORCE_REFRESH] Status unchanged: \(newStatus)")
                }
            } else {
                sessionLogger.error("❌ [FORCE_REFRESH] Failed to decode session document")
            }
        } catch {
            sessionLogger.error("❌ [FORCE_REFRESH] Server fetch failed: \(error.localizedDescription)")

            // Fallback: essayer depuis le cache
            do {
                let snapshot = try await db.collection("sessions").document(sessionId).getDocument()
                if let session = try? snapshot.data(as: Session.self) {
                    await MainActor.run {
                        self.currentSession = session
                    }
                    sessionLogger.info("🔄 [FORCE_REFRESH] Fallback to cache successful")
                }
            } catch {
                sessionLogger.error("❌ [FORCE_REFRESH] Cache fallback also failed: \(error.localizedDescription)")
            }
        }
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
        suggestedAppsCount: Int,
        durationMinutes: Int? = nil,
        scheduledStartTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        backgroundImageUrl: String? = nil
    ) async throws -> Session {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let inviteCode = generateInviteCode()
        let isScheduled = scheduledStartTime != nil

        var newSession = Session(
            id: nil, title: title, description: description,
            leaderId: currentUser.id!, leaderUsername: currentUser.username,
            visibility: visibility, inviteCode: inviteCode,
            maxParticipants: maxParticipants, status: .lobby,
            createdAt: Timestamp(date: Date()),
            startedAt: nil, endedAt: nil, pausedAt: nil, pausedBy: nil,
            memberIds: [currentUser.id!],
            durationMinutes: durationMinutes,
            scheduledEndTime: scheduledEndTime != nil ? Timestamp(date: scheduledEndTime!) : nil,
            scheduledStartTime: scheduledStartTime != nil ? Timestamp(date: scheduledStartTime!) : nil,
            isScheduled: isScheduled,
            suggestedAppsCount: suggestedAppsCount,
            backgroundImageUrl: backgroundImageUrl
        )

        let sessionRef = try db.collection("sessions").addDocument(from: newSession)
        newSession.id = sessionRef.documentID

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

    // MARK: - Session Finding (Preview only)

    func findSession(inviteCode: String) async throws -> Session {
        let query = db.collection("sessions")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .whereField("status", in: [
                SessionStatus.lobby.rawValue,
                SessionStatus.active.rawValue,
                SessionStatus.paused.rawValue
            ])
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let sessionDoc = snapshot.documents.first else {
            throw SessionError.sessionNotFound
        }

        // ✅ FIX: Meilleure gestion de l'erreur de décodage
        do {
            var session = try sessionDoc.data(as: Session.self)
            session.id = sessionDoc.documentID
            return session
        } catch {
            sessionLogger.error("❌ Failed to decode session: \(error.localizedDescription)")
            // Tentative de décodage manuel des champs essentiels
            let data = sessionDoc.data()
            throw SessionError.decodingFailed(details: "Impossible de lire la session. Champs manquants possibles. Erreur: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Joining (Late join support)

    func joinSession(inviteCode: String) async throws -> Session {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        // ÉTAPE 1: Trouver la session cible
        let query = db.collection("sessions")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .whereField("status", in: [
                SessionStatus.lobby.rawValue,
                SessionStatus.active.rawValue,
                SessionStatus.paused.rawValue
            ])
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let sessionDoc = snapshot.documents.first else {
            throw SessionError.sessionNotFound
        }

        // ✅ FIX: Décodage protégé
        var session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
            session.id = sessionDoc.documentID
        } catch {
            sessionLogger.error("❌ Failed to decode session for joining: \(error.localizedDescription)")
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        // ✅ FIX: Utiliser safeMemberIds
        if session.safeMemberIds.contains(currentUser.id!) {
            // Déjà membre, retourner la session directement
            sessionLogger.info("ℹ️ User already a member of this session")
            return session
        }

        if let max = session.maxParticipants, session.safeMemberIds.count >= max {
            throw SessionError.sessionFull
        }

        // ÉTAPE 2: Vérifier si l'utilisateur est déjà dans une session active/paused
        let activeSession = try await findUserActiveSession(userId: currentUser.id!)

        if let activeSession = activeSession {
            // ✅ FIX: Vérifier que ce n'est pas la même session
            if activeSession.id == session.id {
                sessionLogger.info("ℹ️ User is already in this session")
                return session
            }

            // L'utilisateur est dans une autre session active -> créer une demande
            try await createJoinRequest(
                targetSession: session,
                currentSession: activeSession
            )
            throw SessionError.requiresLeaderApproval
        }

        // ÉTAPE 3: Pas de session active -> rejoindre directement
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

        // ✅ FIX: Mettre à jour memberIds localement
        if session.memberIds != nil {
            session.memberIds!.append(currentUser.id!)
        } else {
            session.memberIds = [currentUser.id!]
        }

        // Notifier tous les membres
        await SessionEventNotificationManager.shared.notifyMemberJoined(
            session: session,
            newMemberUsername: currentUser.username,
            currentUserId: currentUser.id!
        )

        return session
    }

    // MARK: - Join Request Management

    /// Vérifie si l'utilisateur est déjà dans une session active, pausée ou en lobby
    private func findUserActiveSession(userId: String) async throws -> Session? {
        // ✅ FIX: Inclure aussi lobby pour éviter les conflits
        let query = db.collection("sessions")
            .whereField("memberIds", arrayContains: userId)
            .whereField("status", in: [
                SessionStatus.active.rawValue,
                SessionStatus.paused.rawValue
            ])
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        guard let sessionDoc = snapshot.documents.first else { return nil }

        // ✅ FIX: Décodage protégé
        do {
            var session = try sessionDoc.data(as: Session.self)
            session.id = sessionDoc.documentID
            return session
        } catch {
            sessionLogger.error("❌ Failed to decode active session: \(error.localizedDescription)")
            return nil  // Ne pas bloquer le join si l'ancienne session est mal formée
        }
    }

    /// Crée une demande de join qui sera envoyée au leader
    private func createJoinRequest(targetSession: Session, currentSession: Session) async throws {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let joinRequest = JoinRequest(
            id: nil,
            userId: currentUser.id!,
            username: currentUser.username,
            targetSessionId: targetSession.id!,
            targetSessionTitle: targetSession.title,
            currentSessionId: currentSession.id,
            currentSessionTitle: currentSession.title,
            leaderId: targetSession.leaderId,
            status: .pending,
            createdAt: Timestamp(date: Date()),
            respondedAt: nil,
            message: nil
        )

        try await db.collection("joinRequests").addDocument(from: joinRequest)

        sessionLogger.info("✅ Join request created for user \(currentUser.username) to session \(targetSession.title)")

        await SessionEventNotificationManager.shared.notifyJoinRequest(
            request: joinRequest,
            targetSession: targetSession
        )
    }

    /// Approuver une demande de join (appelé par le leader)
    func approveJoinRequest(requestId: String) async throws {
        guard !requestId.isEmpty else {
            throw SessionError.decodingFailed(details: "Request ID is empty")
        }
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let requestRef = db.collection("joinRequests").document(requestId)
        let requestDoc = try await requestRef.getDocument()
        guard requestDoc.exists else { throw SessionError.sessionNotFound }

        var request: JoinRequest
        do {
            request = try requestDoc.data(as: JoinRequest.self)
            request.id = requestId
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        guard request.leaderId == currentUser.id else { throw SessionError.notAuthorized }

        // ÉTAPE 1: Retirer l'utilisateur de sa session actuelle
        if let currentSessionId = request.currentSessionId {
            try await forceLeaveSession(userId: request.userId, sessionId: currentSessionId)
        }

        // ÉTAPE 2: Ajouter l'utilisateur à la nouvelle session
        try await addMemberToSession(userId: request.userId, username: request.username, sessionId: request.targetSessionId)

        // ÉTAPE 3: Marquer la demande comme approuvée
        try await requestRef.updateData([
            "status": JoinRequestStatus.approved.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ])

        sessionLogger.info("✅ Join request approved for user \(request.username)")

        await SessionEventNotificationManager.shared.notifyJoinRequestApproved(request: request)
    }

    /// Rejeter une demande de join (appelé par le leader)
    func rejectJoinRequest(requestId: String) async throws {
        guard !requestId.isEmpty else {
            throw SessionError.decodingFailed(details: "Request ID is empty")
        }
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let requestRef = db.collection("joinRequests").document(requestId)
        let requestDoc = try await requestRef.getDocument()
        guard requestDoc.exists else { throw SessionError.sessionNotFound }

        let request: JoinRequest
        do {
            request = try requestDoc.data(as: JoinRequest.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        guard request.leaderId == currentUser.id else { throw SessionError.notAuthorized }

        try await requestRef.updateData([
            "status": JoinRequestStatus.rejected.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ])

        sessionLogger.info("❌ Join request rejected for user \(request.username)")

        await SessionEventNotificationManager.shared.notifyJoinRequestRejected(request: request)
    }

    /// Force un utilisateur à quitter une session
    private func forceLeaveSession(userId: String, sessionId: String) async throws {
        let batch = db.batch()
        let sessionRef = db.collection("sessions").document(sessionId)

        batch.updateData(["memberIds": FieldValue.arrayRemove([userId])], forDocument: sessionRef)

        let memberRef = sessionRef.collection("members").document(userId)
        batch.updateData([
            "status": MemberStatus.left.rawValue,
            "leftAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef)

        let event = SessionEvent(
            id: nil, userId: userId, username: nil,
            eventType: .memberLeft, timestamp: Timestamp(date: Date()),
            metadata: ["reason": "switched_session"]
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        try await batch.commit()
        sessionLogger.info("✅ User \(userId) removed from session \(sessionId)")
    }

    /// Ajoute un membre à une session
    private func addMemberToSession(userId: String, username: String, sessionId: String) async throws {
        let batch = db.batch()
        let sessionRef = db.collection("sessions").document(sessionId)

        batch.updateData(["memberIds": FieldValue.arrayUnion([userId])], forDocument: sessionRef)

        let sessionDoc = try await sessionRef.getDocument()

        // ✅ FIX: Décodage protégé avec fallback
        let sessionStatus: SessionStatus
        if let session = try? sessionDoc.data(as: Session.self) {
            sessionStatus = session.status
        } else {
            // Fallback: lire le status directement
            let data = sessionDoc.data()
            let statusRaw = data?["status"] as? String ?? "lobby"
            sessionStatus = SessionStatus(rawValue: statusRaw) ?? .lobby
            sessionLogger.warning("⚠️ Could not decode session, falling back to raw status: \(statusRaw)")
        }

        let memberStatus: MemberStatus
        let memberIsReady: Bool
        switch sessionStatus {
        case .active:  memberStatus = .active; memberIsReady = true
        case .paused:  memberStatus = .paused; memberIsReady = true
        default:       memberStatus = .joined; memberIsReady = false
        }

        let newMember = SessionMember(
            id: userId, username: username,
            role: .member, status: memberStatus,
            joinedAt: Timestamp(date: Date()), leftAt: nil,
            isReady: memberIsReady, bypassAttempts: 0, messagesCount: 0,
            hasSelectedApps: false, selectedAppsCount: 0
        )
        let memberRef = sessionRef.collection("members").document(userId)
        try batch.setData(from: newMember, forDocument: memberRef)

        let event = SessionEvent(
            id: nil, userId: userId, username: username,
            eventType: .memberJoined, timestamp: Timestamp(date: Date()),
            metadata: ["via": "join_request_approved"]
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        try await batch.commit()
        sessionLogger.info("✅ User \(username) added to session \(sessionId)")
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

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .memberLeft, timestamp: Timestamp(date: Date()), metadata: nil
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "\(currentUser?.username ?? "Quelqu'un") a quitte la session",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        // Notifier
        let sessionDoc = try await sessionRef.getDocument()
        if let session = try? sessionDoc.data(as: Session.self) {
            await SessionEventNotificationManager.shared.notifyMemberLeft(
                session: session,
                leftMemberUsername: currentUser?.username ?? "Membre",
                currentUserId: uid
            )
        }

        stopCurrentSessionListeners()
        removeLocalApps(sessionId: sessionId)

        ScheduledSessionCoordinator.shared.cancelScheduledSession(sessionId: sessionId)
    }

    // MARK: - Leader: Start

    func startSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()

        // ✅ FIX: Décodage protégé
        let session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        guard session.leaderId == uid else { throw SessionError.notAuthorized }
        guard session.status == .lobby else {
            sessionLogger.warning("⚠️ Session \(sessionId) already in state: \(session.status.rawValue)")
            return
        }

        let batch = db.batch()

        var updateData: [String: Any] = [
            "status": SessionStatus.active.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ]

        if let durationMinutes = session.durationMinutes {
            let scheduledEnd = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
            updateData["scheduledEndTime"] = Timestamp(date: scheduledEnd)
        }

        batch.updateData(updateData, forDocument: sessionRef)

        let membersSnapshot = try await sessionRef.collection("members")
            .whereField("status", in: [MemberStatus.ready.rawValue, MemberStatus.joined.rawValue])
            .getDocuments()

        for memberDoc in membersSnapshot.documents {
            let mRef = sessionRef.collection("members").document(memberDoc.documentID)
            batch.updateData(["status": MemberStatus.active.rawValue, "isReady": true], forDocument: mRef)
        }

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .sessionStarted, timestamp: Timestamp(date: Date()),
            metadata: ["memberCount": "\(membersSnapshot.documents.count)"]
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "La session a demarre ! Focus time !",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        // Notifications
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

        var updatedSession = session
        updatedSession.status = .active
        await SessionEventNotificationManager.shared.notifySessionStarted(
            session: updatedSession,
            startedByUsername: currentUser?.username ?? "Leader",
            currentUserId: uid
        )

        // ✅ NEW: Si la session a une durée, programmer le monitoring automatique de fin
        if let durationMinutes = session.durationMinutes,
           let localApps = getLocalApps(sessionId: sessionId),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {

            let endTime = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
            sessionLogger.critical("⏰ [AUTO_STOP] Scheduling end monitoring for session with duration")
            sessionLogger.info("   → Duration: \(durationMinutes) minutes")
            sessionLogger.info("   → End time: \(endTime.formatted())")

            do {
                try await ScheduledSessionCoordinator.shared.scheduleSessionEndMonitoring(
                    sessionId: sessionId,
                    endTime: endTime,
                    apps: selection
                )
                sessionLogger.info("✅ [AUTO_STOP] End monitoring scheduled successfully")
            } catch {
                sessionLogger.error("❌ [AUTO_STOP] Failed to schedule end monitoring: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Leader: Pause

    func pauseSession(sessionId: String, reason: String? = nil) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()

        let session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

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

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .sessionPaused, timestamp: Timestamp(date: Date()),
            metadata: reason != nil ? ["reason": reason!] : nil
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let reasonText = reason != nil ? " - Raison : \(reason!)" : ""
        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "Session mise en pause par \(currentUser?.username ?? "le leader")\(reasonText)",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        var updatedSession = session
        updatedSession.status = .paused
        await SessionEventNotificationManager.shared.notifySessionPaused(
            session: updatedSession,
            pausedByUsername: currentUser?.username ?? "Leader",
            currentUserId: uid
        )

        // ✅ NEW: Annuler le monitoring de fin pendant la pause
        if session.durationMinutes != nil {
            sessionLogger.info("⏸️ [AUTO_STOP] Cancelling end monitoring during pause")
            ScheduledSessionCoordinator.shared.cancelSessionEndMonitoring(sessionId: sessionId)
        }
    }

    // MARK: - Leader: Resume

    func resumeSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()

        let session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

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

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .sessionResumed, timestamp: Timestamp(date: Date()), metadata: nil
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "Session reprise ! C'est reparti !",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        var updatedSession = session
        updatedSession.status = .active
        await SessionEventNotificationManager.shared.notifySessionResumed(
            session: updatedSession,
            resumedByUsername: currentUser?.username ?? "Leader",
            currentUserId: uid
        )

        // ✅ NEW: Recréer le monitoring de fin après resume avec nouveau scheduledEndTime
        if let scheduledEndTime = session.scheduledEndTime?.dateValue(),
           let pausedAt = session.pausedAt?.dateValue(),
           let localApps = getLocalApps(sessionId: sessionId),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {

            // Calculer la durée de pause
            let pauseDuration = Date().timeIntervalSince(pausedAt)

            // Nouveau temps de fin = ancien temps de fin + durée de pause
            let newEndTime = scheduledEndTime.addingTimeInterval(pauseDuration)

            sessionLogger.critical("▶️ [AUTO_STOP] Rescheduling end monitoring after resume")
            sessionLogger.info("   → Pause duration: \(Int(pauseDuration))s")
            sessionLogger.info("   → New end time: \(newEndTime.formatted())")

            do {
                try await ScheduledSessionCoordinator.shared.updateSessionEndMonitoring(
                    sessionId: sessionId,
                    newEndTime: newEndTime,
                    apps: selection
                )

                // Mettre à jour scheduledEndTime dans Firestore
                try await sessionRef.updateData([
                    "scheduledEndTime": Timestamp(date: newEndTime)
                ])

                sessionLogger.info("✅ [AUTO_STOP] End monitoring rescheduled successfully")
            } catch {
                sessionLogger.error("❌ [AUTO_STOP] Failed to reschedule end monitoring: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Leader: Stop

    func stopSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()

        let session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        guard session.leaderId == uid else { throw SessionError.notAuthorized }
        guard session.status == .active || session.status == .paused else {
            sessionLogger.warning("⚠️ Session \(sessionId) already in state: \(session.status.rawValue)")
            return
        }

        let batch = db.batch()

        batch.updateData([
            "status": SessionStatus.completed.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ], forDocument: sessionRef)

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .sessionStopped, timestamp: Timestamp(date: Date()), metadata: nil
        )
        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "Session terminee ! Bravo a tous !",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        let msgRef = sessionRef.collection("messages").document()
        try batch.setData(from: sysMsg, forDocument: msgRef)

        try await batch.commit()

        var updatedSession = session
        updatedSession.status = .completed
        await SessionEventNotificationManager.shared.notifySessionEnded(
            session: updatedSession,
            endedByUsername: currentUser?.username ?? "Leader",
            currentUserId: uid
        )

        ScheduledSessionCoordinator.shared.cancelScheduledSession(sessionId: sessionId)
        ScheduledSessionCoordinator.shared.cancelSessionEndMonitoring(sessionId: sessionId)
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

        let event = SessionEvent(
            id: nil, userId: currentUser.id, username: currentUser.username,
            eventType: .pauseRequested, timestamp: Timestamp(date: Date()),
            metadata: reason != nil ? ["reason": reason!] : nil
        )
        try sessionRef.collection("events").addDocument(from: event)

        let reasonText = reason != nil ? " : \"\(reason!)\"" : ""
        let sysMsg = SessionMessage(
            id: nil, userId: "system", username: "Systeme",
            content: "\(currentUser.username) demande une pause\(reasonText)",
            messageType: .systemAlert, timestamp: Timestamp(date: Date())
        )
        try sessionRef.collection("messages").addDocument(from: sysMsg)

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
        guard let pauseReq = try? requestDoc.data(as: PauseRequest.self) else {
            sessionLogger.error("❌ Failed to decode pause request")
            return
        }

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: accept ? .pauseRequestAccepted : .pauseRequestDeclined,
            timestamp: Timestamp(date: Date()),
            metadata: ["requesterId": pauseReq.requesterId, "requesterUsername": pauseReq.requesterUsername]
        )
        try sessionRef.collection("events").addDocument(from: event)

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
            let sysMsg = SessionMessage(
                id: nil, userId: "system", username: "Systeme",
                content: "Demande de pause de \(pauseReq.requesterUsername) refusee",
                messageType: .systemAlert, timestamp: Timestamp(date: Date())
            )
            try sessionRef.collection("messages").addDocument(from: sysMsg)
        }
    }

    // MARK: - Dissolve

    func dissolveSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else { throw SessionError.notAuthenticated }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()

        // ✅ FIX: Décodage protégé
        let session: Session
        do {
            session = try sessionDoc.data(as: Session.self)
        } catch {
            throw SessionError.decodingFailed(details: error.localizedDescription)
        }

        guard session.leaderId == uid else { throw SessionError.notAuthorized }

        try await sessionRef.updateData([
            "status": SessionStatus.dissolved.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ])

        let event = SessionEvent(
            id: nil, userId: uid, username: currentUser?.username,
            eventType: .sessionDissolved, timestamp: Timestamp(date: Date()), metadata: nil
        )
        try sessionRef.collection("events").addDocument(from: event)

        stopCurrentSessionListeners()
        removeLocalApps(sessionId: sessionId)

        ScheduledSessionCoordinator.shared.cancelScheduledSession(sessionId: sessionId)
    }

    // MARK: - Messaging

    func sendMessage(sessionId: String, content: String, type: MessageType = .text) async throws {
        guard let currentUser = currentUser else { throw SessionError.notAuthenticated }

        let message = SessionMessage(
            id: nil, userId: currentUser.id!, username: currentUser.username,
            content: content, messageType: type, timestamp: Timestamp(date: Date())
        )
        try db.collection("sessions").document(sessionId).collection("messages").addDocument(from: message)

        if let session = currentSession {
            await SessionEventNotificationManager.shared.notifyNewMessage(
                session: session,
                senderUsername: currentUser.username,
                messagePreview: content,
                currentUserId: currentUser.id!
            )
        }
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
                self.publicSessions = allPublic.filter { !$0.safeMemberIds.contains(uid) }
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

        // ✅ NEW: Listen to join requests where currentUser is the leader
        let jL = db.collection("joinRequests")
            .whereField("leaderId", isEqualTo: currentUser?.id ?? "")
            .whereField("status", isEqualTo: JoinRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self, let snapshot = snapshot else { return }
                self.pendingJoinRequests = snapshot.documents.compactMap { try? $0.data(as: JoinRequest.self) }
                sessionLogger.info("📥 Join requests updated: \(self.pendingJoinRequests.count) pending")
            }

        currentSessionListeners = [sL, mL, msgL, pL, jL]
    }

    private func stopCurrentSessionListeners() {
        currentSessionListeners.forEach { $0.remove() }
        currentSessionListeners.removeAll()
        currentSession = nil
        currentSessionMembers = []
        currentSessionMessages = []
        pendingPauseRequests = []
        pendingJoinRequests = []
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
        let localApps = LocalSessionApps(
            sessionId: sessionId, userId: currentUser?.id ?? "",
            selectedAppTokens: appTokens, selectedAppsCount: count, lastUpdated: Date()
        )
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

// MARK: - Session Error

enum SessionError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case sessionNotFound
    case sessionFull
    case noReadyMembers
    case invalidSessionState
    case requiresLeaderApproval
    case decodingFailed(details: String)    // ✅ NEW

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non connecté"
        case .notAuthorized: return "Action non autorisée"
        case .sessionNotFound: return "Session introuvable avec ce code"
        case .sessionFull: return "La session est pleine"
        case .noReadyMembers: return "Aucun membre prêt pour démarrer"
        case .invalidSessionState: return "La session n'est pas dans le bon état pour cette action"
        case .requiresLeaderApproval: return "Demande envoyée au leader. Tu es déjà dans une session active."
        case .decodingFailed(let details): return "Erreur de lecture des données: \(details)"
        }
    }
}