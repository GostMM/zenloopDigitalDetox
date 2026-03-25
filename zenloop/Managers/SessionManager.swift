//
//  SessionManager.swift
//  zenloop
//
//  Gère les sessions sociales avec Firebase Firestore
//  Real-time listeners pour synchronisation instantanée
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

    // ✅ FIX: Separate listener tracking for proper cleanup
    private var userListener: ListenerRegistration?
    private var mySessionsListener: ListenerRegistration?
    private var publicSessionsListener: ListenerRegistration?
    private var invitationsListener: ListenerRegistration?
    private var currentSessionListeners: [ListenerRegistration] = []

    // Local storage for selected apps (Apple restriction)
    private let localAppsKey = "local_session_apps"

    private init() {
        sessionLogger.info("🔥 SessionManager initialized")
    }

    // MARK: - Authentication & User Setup

    func setupUser(uid: String, username: String, appleUserId: String) async throws {
        sessionLogger.critical("👤 Setting up user: \(username)")

        let userRef = db.collection("users").document(uid)

        // Check if user exists
        let snapshot = try await userRef.getDocument()

        if snapshot.exists {
            // Load existing user
            do {
                currentUser = try snapshot.data(as: SessionUser.self)
                sessionLogger.info("✅ User loaded from Firestore")
            } catch {
                // Document exists but has invalid data, recreate it
                sessionLogger.warning("⚠️ Existing user document is invalid, recreating: \(error.localizedDescription)")
                try await userRef.delete()
                currentUser = nil
            }
        }

        // Create new user if not loaded
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
            sessionLogger.critical("✅ New user created in Firestore")
        }

        // Start listening to user updates
        startUserListener(uid: uid)
    }

    // ✅ NEW: Load all sessions for the current user
    func loadUserSessions() async {
        guard let uid = currentUser?.id else {
            sessionLogger.warning("⚠️ Cannot load sessions — no current user")
            return
        }

        sessionLogger.info("📡 Loading sessions for user: \(uid)")

        // Start real-time listeners for user's sessions and public sessions
        startMySessionsListener(uid: uid)
        startPublicSessionsListener()
        startInvitationsListener(uid: uid)

        sessionLogger.info("✅ Session listeners started")
    }

    // ✅ NEW: Clear all local state on sign-out
    func clearLocalState() {
        currentUser = nil
        mySessions = []
        publicSessions = []
        currentSession = nil
        currentSessionMembers = []
        currentSessionMessages = []
        pendingInvitations = []

        sessionLogger.info("🧹 Local state cleared")
    }

    func updateLastSeen() async {
        guard let uid = currentUser?.id else { return }

        let userRef = db.collection("users").document(uid)
        try? await userRef.updateData([
            "lastSeen": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Session Creation

    func createSession(
        title: String,
        description: String,
        visibility: SessionVisibility,
        maxParticipants: Int?,
        suggestedAppsCount: Int
    ) async throws -> Session {
        guard let currentUser = currentUser else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.critical("📝 Creating session: \(title)")

        let inviteCode = generateInviteCode()

        var newSession = Session(
            id: nil,
            title: title,
            description: description,
            leaderId: currentUser.id!,
            leaderUsername: currentUser.username,
            visibility: visibility,
            inviteCode: inviteCode,
            maxParticipants: maxParticipants,
            status: .lobby,
            createdAt: Timestamp(date: Date()),
            startedAt: nil,
            endedAt: nil,
            memberIds: [currentUser.id!],
            suggestedAppsCount: suggestedAppsCount
        )

        // Create session document
        let sessionRef = try db.collection("sessions").addDocument(from: newSession)
        newSession.id = sessionRef.documentID

        // Add leader as first member (auto-ready)
        let leaderMember = SessionMember(
            id: currentUser.id,
            username: currentUser.username,
            role: .leader,
            status: .ready,  // ✅ Leader is automatically ready
            joinedAt: Timestamp(date: Date()),
            leftAt: nil,
            isReady: true,  // ✅ Leader can start without waiting
            bypassAttempts: 0,
            messagesCount: 0,
            hasSelectedApps: suggestedAppsCount > 0,
            selectedAppsCount: suggestedAppsCount
        )

        try sessionRef.collection("members").document(currentUser.id!).setData(from: leaderMember)

        // Create session_created event
        let event = SessionEvent(
            id: nil,
            userId: currentUser.id,
            username: currentUser.username,
            eventType: .sessionCreated,
            timestamp: Timestamp(date: Date()),
            metadata: ["sessionId": sessionRef.documentID]
        )

        try sessionRef.collection("events").addDocument(from: event)

        // ✅ FIX: Update user's session history
        let userRef = db.collection("users").document(currentUser.id!)
        try await userRef.updateData([
            "sessionHistory": FieldValue.arrayUnion([sessionRef.documentID]),
            "totalSessionsCreated": FieldValue.increment(Int64(1))
        ])

        sessionLogger.critical("✅ Session created with code: \(inviteCode), ID: \(sessionRef.documentID)")

        return newSession
    }

    // MARK: - Session Joining

    func joinSession(inviteCode: String) async throws -> Session {
        guard let currentUser = currentUser else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("🔍 Searching for session with code: \(inviteCode)")

        // Query for session with invite code
        let query = db.collection("sessions")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .whereField("status", in: [SessionStatus.lobby.rawValue, SessionStatus.active.rawValue])
            .limit(to: 1)

        let snapshot = try await query.getDocuments()

        guard let sessionDoc = snapshot.documents.first else {
            throw SessionError.sessionNotFound
        }

        var session = try sessionDoc.data(as: Session.self)

        // Check if already a member
        if session.memberIds.contains(currentUser.id!) {
            sessionLogger.warning("⚠️ User already in session")
            return session
        }

        // Check max participants
        if let max = session.maxParticipants, session.memberIds.count >= max {
            throw SessionError.sessionFull
        }

        sessionLogger.info("✅ Joining session: \(session.title)")

        // Add member to session
        let batch = db.batch()

        // Update session memberIds
        let sessionRef = db.collection("sessions").document(sessionDoc.documentID)
        batch.updateData([
            "memberIds": FieldValue.arrayUnion([currentUser.id!])
        ], forDocument: sessionRef)

        // Add member document
        let memberStatus: MemberStatus = (session.status == .active) ? .active : .joined
        let newMember = SessionMember(
            id: currentUser.id,
            username: currentUser.username,
            role: .member,
            status: memberStatus,
            joinedAt: Timestamp(date: Date()),
            leftAt: nil,
            isReady: false,
            bypassAttempts: 0,
            messagesCount: 0,
            hasSelectedApps: false,
            selectedAppsCount: 0
        )

        let memberRef = sessionRef.collection("members").document(currentUser.id!)
        try batch.setData(from: newMember, forDocument: memberRef)

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: currentUser.id,
            username: currentUser.username,
            eventType: .memberJoined,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        // ✅ FIX: Update user's session history
        let userRef = db.collection("users").document(currentUser.id!)
        batch.updateData([
            "sessionHistory": FieldValue.arrayUnion([sessionDoc.documentID]),
            "totalSessionsJoined": FieldValue.increment(Int64(1))
        ], forDocument: userRef)

        try await batch.commit()

        session.memberIds.append(currentUser.id!)

        sessionLogger.critical("✅ Successfully joined session")

        return session
    }

    // MARK: - Member Actions

    func markAsReady(sessionId: String, appsCount: Int) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("✅ Marking as ready with \(appsCount) apps")

        let memberRef = db.collection("sessions").document(sessionId)
            .collection("members").document(uid)

        try await memberRef.updateData([
            "isReady": true,
            "status": MemberStatus.ready.rawValue,
            "hasSelectedApps": appsCount > 0,
            "selectedAppsCount": appsCount
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .memberReady,
            timestamp: Timestamp(date: Date()),
            metadata: ["appsCount": "\(appsCount)"]
        )

        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)
    }

    func leaveSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.warning("🚪 Leaving session")

        let batch = db.batch()
        let sessionRef = db.collection("sessions").document(sessionId)
        let memberRef = sessionRef.collection("members").document(uid)

        // Update member status
        batch.updateData([
            "status": MemberStatus.left.rawValue,
            "leftAt": FieldValue.serverTimestamp()
        ], forDocument: memberRef)

        // ✅ FIX: Remove user from memberIds array
        batch.updateData([
            "memberIds": FieldValue.arrayRemove([uid])
        ], forDocument: sessionRef)

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .memberLeft,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        try await batch.commit()

        // ✅ FIX: Stop current session listeners
        stopCurrentSessionListeners()

        // Remove local apps data
        removeLocalApps(sessionId: sessionId)
    }

    // MARK: - Session Control Actions

    func pauseSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("⏸️ Pausing session")

        // Update member status to paused
        let memberRef = db.collection("sessions").document(sessionId)
            .collection("members").document(uid)

        try await memberRef.updateData([
            "status": MemberStatus.paused.rawValue,
            "pausedAt": FieldValue.serverTimestamp()
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .memberPaused,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)

        sessionLogger.info("✅ Session paused")
    }

    func resumeSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("▶️ Resuming session")

        // Update member status back to active
        let memberRef = db.collection("sessions").document(sessionId)
            .collection("members").document(uid)

        try await memberRef.updateData([
            "status": MemberStatus.active.rawValue,
            "pausedAt": FieldValue.delete()
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .memberResumed,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)

        sessionLogger.info("✅ Session resumed")
    }

    func extendSession(sessionId: String, byMinutes: Int) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("⏰ Extending session by \(byMinutes) minutes")

        // This would need to be tracked in session metadata
        // For now, just create an event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .sessionExtended,
            timestamp: Timestamp(date: Date()),
            metadata: ["minutes": "\(byMinutes)"]
        )

        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)

        sessionLogger.info("✅ Session extended")
    }

    // MARK: - Leader Actions

    func startSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        // Verify is leader
        guard session.leaderId == uid else {
            throw SessionError.notAuthorized
        }

        // Get all ready members (leader can start alone)
        let membersSnapshot = try await sessionRef.collection("members")
            .whereField("isReady", isEqualTo: true)
            .getDocuments()

        sessionLogger.critical("🚀 Starting session: \(session.title) with \(membersSnapshot.documents.count) ready member(s)")

        let batch = db.batch()

        // Update session status
        batch.updateData([
            "status": SessionStatus.active.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ], forDocument: sessionRef)

        // Update all ready members to active
        for memberDoc in membersSnapshot.documents {
            let memberRef = sessionRef.collection("members").document(memberDoc.documentID)
            batch.updateData([
                "status": MemberStatus.active.rawValue
            ], forDocument: memberRef)
        }

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .sessionStarted,
            timestamp: Timestamp(date: Date()),
            metadata: ["memberCount": "\(membersSnapshot.documents.count)"]
        )

        let eventRef = sessionRef.collection("events").document()
        try batch.setData(from: event, forDocument: eventRef)

        try await batch.commit()

        sessionLogger.critical("✅ Session started successfully")
    }

    func dissolveSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        // Verify is leader
        guard session.leaderId == uid else {
            throw SessionError.notAuthorized
        }

        sessionLogger.warning("🗑️ Dissolving session")

        try await sessionRef.updateData([
            "status": SessionStatus.dissolved.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .sessionDissolved,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        try sessionRef.collection("events").addDocument(from: event)

        // ✅ FIX: Stop current session listeners
        stopCurrentSessionListeners()

        // Remove local apps data
        removeLocalApps(sessionId: sessionId)
    }

    func stopSession(sessionId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        // Verify is leader
        guard session.leaderId == uid else {
            throw SessionError.notAuthorized
        }

        sessionLogger.warning("🛑 Stopping session early")

        try await sessionRef.updateData([
            "status": SessionStatus.completed.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .sessionStopped,
            timestamp: Timestamp(date: Date()),
            metadata: nil
        )

        try sessionRef.collection("events").addDocument(from: event)

        sessionLogger.info("✅ Session stopped")
    }

    // MARK: - Pause Requests

    func requestPause(sessionId: String, durationMinutes: Int, reason: String?) async throws {
        guard let uid = currentUser?.id,
              let username = currentUser?.username else {
            throw SessionError.notAuthenticated
        }

        sessionLogger.info("⏸️ Requesting pause for \(durationMinutes) minutes")

        let request = PauseRequest(
            id: nil,
            sessionId: sessionId,
            requesterId: uid,
            requesterUsername: username,
            reason: reason,
            durationMinutes: durationMinutes,
            status: .pending,
            requestedAt: Timestamp(date: Date()),
            respondedAt: nil,
            respondedBy: nil
        )

        try db.collection("sessions").document(sessionId)
            .collection("pauseRequests").addDocument(from: request)

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: username,
            eventType: .pauseRequested,
            timestamp: Timestamp(date: Date()),
            metadata: ["duration": "\(durationMinutes)", "reason": reason ?? ""]
        )

        try db.collection("sessions").document(sessionId)
            .collection("events").addDocument(from: event)

        sessionLogger.info("✅ Pause request sent")
    }

    func approvePauseRequest(sessionId: String, requestId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        // Verify is leader
        guard session.leaderId == uid else {
            throw SessionError.notAuthorized
        }

        sessionLogger.info("✅ Approving pause request")

        let requestRef = sessionRef.collection("pauseRequests").document(requestId)
        let requestDoc = try await requestRef.getDocument()
        let request = try requestDoc.data(as: PauseRequest.self)

        // Update request status
        try await requestRef.updateData([
            "status": PauseRequestStatus.approved.rawValue,
            "respondedAt": FieldValue.serverTimestamp(),
            "respondedBy": uid
        ])

        // Pause the requesting member
        let memberRef = sessionRef.collection("members").document(request.requesterId)
        try await memberRef.updateData([
            "status": MemberStatus.paused.rawValue
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .pauseApproved,
            timestamp: Timestamp(date: Date()),
            metadata: ["requesterId": request.requesterId, "requesterUsername": request.requesterUsername]
        )

        try sessionRef.collection("events").addDocument(from: event)

        sessionLogger.info("✅ Pause request approved")
    }

    func denyPauseRequest(sessionId: String, requestId: String) async throws {
        guard let uid = currentUser?.id else {
            throw SessionError.notAuthenticated
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDoc = try await sessionRef.getDocument()
        let session = try sessionDoc.data(as: Session.self)

        // Verify is leader
        guard session.leaderId == uid else {
            throw SessionError.notAuthorized
        }

        sessionLogger.info("❌ Denying pause request")

        let requestRef = sessionRef.collection("pauseRequests").document(requestId)
        let requestDoc = try await requestRef.getDocument()
        let request = try requestDoc.data(as: PauseRequest.self)

        // Update request status
        try await requestRef.updateData([
            "status": PauseRequestStatus.denied.rawValue,
            "respondedAt": FieldValue.serverTimestamp(),
            "respondedBy": uid
        ])

        // Create event
        let event = SessionEvent(
            id: nil,
            userId: uid,
            username: currentUser?.username,
            eventType: .pauseDenied,
            timestamp: Timestamp(date: Date()),
            metadata: ["requesterId": request.requesterId, "requesterUsername": request.requesterUsername]
        )

        try sessionRef.collection("events").addDocument(from: event)

        sessionLogger.info("✅ Pause request denied")
    }

    // MARK: - Messaging

    func sendMessage(sessionId: String, content: String, type: MessageType = .text) async throws {
        guard let currentUser = currentUser else {
            throw SessionError.notAuthenticated
        }

        let message = SessionMessage(
            id: nil,
            userId: currentUser.id!,
            username: currentUser.username,
            content: content,
            messageType: type,
            timestamp: Timestamp(date: Date())
        )

        try db.collection("sessions").document(sessionId)
            .collection("messages").addDocument(from: message)
    }

    // MARK: - Real-time Listeners

    private func startUserListener(uid: String) {
        // ✅ FIX: Remove existing listener before adding a new one
        userListener?.remove()

        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ User listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else { return }

                do {
                    self.currentUser = try snapshot.data(as: SessionUser.self)
                } catch {
                    sessionLogger.error("❌ Failed to decode user: \(error.localizedDescription)")
                }
            }
    }

    // ✅ NEW: Listen to user's own sessions (where they are a member)
    private func startMySessionsListener(uid: String) {
        mySessionsListener?.remove()

        mySessionsListener = db.collection("sessions")
            .whereField("memberIds", arrayContains: uid)
            .whereField("status", in: [
                SessionStatus.lobby.rawValue,
                SessionStatus.active.rawValue
            ])
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ My sessions listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.mySessions = snapshot.documents.compactMap {
                    try? $0.data(as: Session.self)
                }
                sessionLogger.info("📡 My sessions updated: \(self.mySessions.count)")
            }
    }

    // ✅ NEW: Listen to public sessions (excluding user's own)
    private func startPublicSessionsListener() {
        publicSessionsListener?.remove()

        publicSessionsListener = db.collection("sessions")
            .whereField("visibility", isEqualTo: SessionVisibility.publicSession.rawValue)
            .whereField("status", in: [
                SessionStatus.lobby.rawValue,
                SessionStatus.active.rawValue
            ])
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Public sessions listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                let allPublic = snapshot.documents.compactMap {
                    try? $0.data(as: Session.self)
                }

                // ✅ Filter out sessions the user is already in
                let uid = self.currentUser?.id ?? ""
                self.publicSessions = allPublic.filter { session in
                    !session.memberIds.contains(uid)
                }

                sessionLogger.info("📡 Public sessions updated: \(self.publicSessions.count)")
            }
    }

    // ✅ NEW: Listen to pending invitations for the user
    private func startInvitationsListener(uid: String) {
        invitationsListener?.remove()

        invitationsListener = db.collection("invitations")
            .whereField("toUserId", isEqualTo: uid)
            .whereField("status", isEqualTo: InvitationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Invitations listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.pendingInvitations = snapshot.documents.compactMap {
                    try? $0.data(as: SessionInvitation.self)
                }
                sessionLogger.info("📡 Invitations updated: \(self.pendingInvitations.count)")
            }
    }

    // ✅ FIX: Separate listener for a specific session detail view
    func startSessionListener(sessionId: String) {
        // Stop any previous session detail listeners
        stopCurrentSessionListeners()

        // Listen to session document
        let sessionListener = db.collection("sessions").document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Session listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else { return }

                do {
                    self.currentSession = try snapshot.data(as: Session.self)
                    sessionLogger.info("📡 Session updated: \(self.currentSession?.status.rawValue ?? "unknown")")
                } catch {
                    sessionLogger.error("❌ Failed to decode session: \(error.localizedDescription)")
                }
            }

        // Listen to members
        let membersListener = db.collection("sessions").document(sessionId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Members listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.currentSessionMembers = snapshot.documents.compactMap {
                    try? $0.data(as: SessionMember.self)
                }
                sessionLogger.info("📡 Members updated: \(self.currentSessionMembers.count)")
            }

        // Listen to messages
        let messagesListener = db.collection("sessions").document(sessionId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Messages listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.currentSessionMessages = snapshot.documents.compactMap {
                    try? $0.data(as: SessionMessage.self)
                }
            }

        // Listen to pause requests (only pending ones)
        let pauseRequestsListener = db.collection("sessions").document(sessionId)
            .collection("pauseRequests")
            .whereField("status", isEqualTo: PauseRequestStatus.pending.rawValue)
            .order(by: "requestedAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    sessionLogger.error("❌ Pause requests listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else { return }

                self.pendingPauseRequests = snapshot.documents.compactMap {
                    try? $0.data(as: PauseRequest.self)
                }
                sessionLogger.info("📡 Pause requests updated: \(self.pendingPauseRequests.count)")
            }

        currentSessionListeners = [sessionListener, membersListener, messagesListener, pauseRequestsListener]
    }

    // ✅ NEW: Stop only the current session detail listeners
    private func stopCurrentSessionListeners() {
        currentSessionListeners.forEach { $0.remove() }
        currentSessionListeners.removeAll()
        currentSession = nil
        currentSessionMembers = []
        currentSessionMessages = []
        pendingPauseRequests = []
        sessionLogger.info("🔇 Current session listeners stopped")
    }

    func stopListeners() {
        userListener?.remove()
        userListener = nil

        mySessionsListener?.remove()
        mySessionsListener = nil

        publicSessionsListener?.remove()
        publicSessionsListener = nil

        invitationsListener?.remove()
        invitationsListener = nil

        stopCurrentSessionListeners()

        sessionLogger.info("🔇 All listeners stopped")
    }

    // MARK: - Local Apps Storage (Apple Restriction)

    func saveLocalApps(sessionId: String, appTokens: Data, count: Int) {
        let localApps = LocalSessionApps(
            sessionId: sessionId,
            userId: currentUser?.id ?? "",
            selectedAppTokens: appTokens,
            selectedAppsCount: count,
            lastUpdated: Date()
        )

        guard let data = try? JSONEncoder().encode(localApps) else { return }

        UserDefaults.standard.set(data, forKey: "\(localAppsKey)_\(sessionId)")
        UserDefaults.standard.synchronize()

        sessionLogger.info("💾 Local apps saved: \(count) apps")
    }

    func getLocalApps(sessionId: String) -> LocalSessionApps? {
        guard let data = UserDefaults.standard.data(forKey: "\(localAppsKey)_\(sessionId)"),
              let localApps = try? JSONDecoder().decode(LocalSessionApps.self, from: data) else {
            return nil
        }

        return localApps
    }

    func removeLocalApps(sessionId: String) {
        UserDefaults.standard.removeObject(forKey: "\(localAppsKey)_\(sessionId)")
        UserDefaults.standard.synchronize()
        sessionLogger.info("🗑️ Local apps removed")
    }

    // MARK: - Helper Methods

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case sessionNotFound
    case sessionFull
    case noReadyMembers

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .notAuthorized:
            return "Not authorized for this action"
        case .sessionNotFound:
            return "Session not found with this invite code"
        case .sessionFull:
            return "Session is full"
        case .noReadyMembers:
            return "No ready members to start session"
        }
    }
}