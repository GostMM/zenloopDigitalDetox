//
//  SessionDetailView.swift
//  zenloop
//
//  Vue détaillée d'une session (Lobby + Active)
//  Affiche différents contenus selon le statut de la session
//  Style: HomeView avec real-time updates
//

import SwiftUI
import FamilyControls

struct SessionDetailView: View {
    let session: Session

    // ✅ FIX: @ObservedObject pour les singletons (pas @StateObject)
    @ObservedObject private var sessionManager = SessionManager.shared
    @EnvironmentObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) var dismiss

    @State private var showContent = false
    @State private var showAppPicker = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isReady = false
    @State private var messageText = ""
    @State private var showLeaveAlert = false
    @State private var showDissolveAlert = false

    private var isLeader: Bool {
        sessionManager.currentUser?.id == session.leaderId
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var currentMemberIsPaused: Bool {
        guard let userId = sessionManager.currentUser?.id else { return false }
        return sessionManager.currentSessionMembers.first(where: { $0.id == userId })?.status == .paused
    }

    var body: some View {
        ZStack {
            // Background optimisé
            OptimizedBackground(currentState: currentZenloopState)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                // Header dynamique selon statut
                SessionDetailHeader(
                    session: sessionManager.currentSession ?? session,
                    isLeader: isLeader,
                    showContent: showContent,
                    onBack: { dismiss() }
                )
                .padding(.horizontal, 20)

                // Contenu selon statut
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        switch sessionManager.currentSession?.status ?? session.status {
                        case .lobby:
                            LobbyContent(
                                session: sessionManager.currentSession ?? session,
                                members: sessionManager.currentSessionMembers,
                                isLeader: isLeader,
                                isReady: $isReady,
                                selectedAppsCount: selectedAppsCount,
                                showContent: showContent,
                                onSelectApps: { showAppPicker = true },
                                onMarkReady: markAsReady,
                                onStartSession: startSession,
                                onDissolve: { showDissolveAlert = true }
                            )

                        case .active:
                            ActiveContent(
                                session: sessionManager.currentSession ?? session,
                                members: sessionManager.currentSessionMembers,
                                messages: sessionManager.currentSessionMessages,
                                pauseRequests: sessionManager.pendingPauseRequests,
                                isLeader: isLeader,
                                isPaused: currentMemberIsPaused,
                                messageText: $messageText,
                                showContent: showContent,
                                onSendMessage: sendMessage,
                                onPause: pauseSession,
                                onResume: resumeSession,
                                onExtend: extendSession,
                                onRequestPause: requestPause,
                                onApprovePause: approvePauseRequest,
                                onDenyPause: denyPauseRequest,
                                onStop: stopSession,
                                onLeave: { showLeaveAlert = true }
                            )

                        case .completed:
                            CompletedContent(
                                session: sessionManager.currentSession ?? session,
                                showContent: showContent
                            )

                        case .dissolved:
                            DissolvedContent(
                                session: sessionManager.currentSession ?? session,
                                showContent: showContent
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                showContent = true
            }

            // ✅ FIX: Always start listener when entering detail view
            if let sessionId = session.id {
                sessionManager.startSessionListener(sessionId: sessionId)
            }

            // Load local apps if they exist
            if let sessionId = session.id,
               let localApps = sessionManager.getLocalApps(sessionId: sessionId) {
                if let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {
                    selectedApps = selection
                    isReady = localApps.selectedAppsCount > 0
                }
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selectedApps)
        .alert("Quitter la Session", isPresented: $showLeaveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Quitter", role: .destructive) {
                leaveSession()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir quitter? Vos blocages seront retirés.")
        }
        .alert("Dissoudre la Session", isPresented: $showDissolveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Dissoudre", role: .destructive) {
                dissolveSession()
            }
        } message: {
            Text("Cela terminera la session pour tous les membres. Cette action est irréversible.")
        }
    }

    private var currentZenloopState: ZenloopState {
        if sessionManager.currentSession?.status == .active {
            return .active
        }
        return .idle
    }

    // MARK: - Actions

    private func markAsReady() {
        guard selectedAppsCount > 0 else { return }

        Task {
            do {
                // Save apps locally
                if let tokenData = try? JSONEncoder().encode(selectedApps) {
                    sessionManager.saveLocalApps(
                        sessionId: session.id!,
                        appTokens: tokenData,
                        count: selectedAppsCount
                    )
                }

                // Mark as ready in Firestore
                try await sessionManager.markAsReady(
                    sessionId: session.id!,
                    appsCount: selectedAppsCount
                )

                await MainActor.run {
                    isReady = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                print("❌ Error marking as ready: \(error)")
            }
        }
    }

    private func startSession() {
        Task {
            do {
                try await sessionManager.startSession(sessionId: session.id!)

                await MainActor.run {
                    // Apply blocks via GlobalShieldManager
                    applySessionBlocks()

                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                print("❌ Error starting session: \(error)")
            }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let content = messageText
        messageText = ""

        Task {
            do {
                try await sessionManager.sendMessage(
                    sessionId: session.id!,
                    content: content
                )
            } catch {
                print("❌ Error sending message: \(error)")
            }
        }
    }

    private func pauseSession() {
        Task {
            do {
                try await sessionManager.pauseSession(sessionId: session.id!)

                await MainActor.run {
                    // TODO: Temporarily remove blocks via GlobalShieldManager
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                print("❌ Error pausing session: \(error)")
            }
        }
    }

    private func resumeSession() {
        Task {
            do {
                try await sessionManager.resumeSession(sessionId: session.id!)

                await MainActor.run {
                    // TODO: Re-apply blocks via GlobalShieldManager
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                print("❌ Error resuming session: \(error)")
            }
        }
    }

    private func extendSession(byMinutes: Int) {
        Task {
            do {
                try await sessionManager.extendSession(sessionId: session.id!, byMinutes: byMinutes)

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                print("❌ Error extending session: \(error)")
            }
        }
    }

    private func requestPause(durationMinutes: Int, reason: String?) {
        Task {
            do {
                try await sessionManager.requestPause(sessionId: session.id!, durationMinutes: durationMinutes, reason: reason)

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                print("❌ Error requesting pause: \(error)")
            }
        }
    }

    private func approvePauseRequest(requestId: String) {
        Task {
            do {
                try await sessionManager.approvePauseRequest(sessionId: session.id!, requestId: requestId)

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                print("❌ Error approving pause request: \(error)")
            }
        }
    }

    private func denyPauseRequest(requestId: String) {
        Task {
            do {
                try await sessionManager.denyPauseRequest(sessionId: session.id!, requestId: requestId)

                await MainActor.run {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                print("❌ Error denying pause request: \(error)")
            }
        }
    }

    private func stopSession() {
        Task {
            do {
                try await sessionManager.stopSession(sessionId: session.id!)

                await MainActor.run {
                    removeSessionBlocks()
                    dismiss()
                }
            } catch {
                print("❌ Error stopping session: \(error)")
            }
        }
    }

    private func leaveSession() {
        Task {
            do {
                try await sessionManager.leaveSession(sessionId: session.id!)

                await MainActor.run {
                    // Remove blocks
                    removeSessionBlocks()

                    dismiss()
                }
            } catch {
                print("❌ Error leaving session: \(error)")
            }
        }
    }

    private func dissolveSession() {
        Task {
            do {
                try await sessionManager.dissolveSession(sessionId: session.id!)

                await MainActor.run {
                    // Remove blocks
                    removeSessionBlocks()

                    dismiss()
                }
            } catch {
                print("❌ Error dissolving session: \(error)")
            }
        }
    }

    // MARK: - Block Management

    private func applySessionBlocks() {
        guard let localApps = sessionManager.getLocalApps(sessionId: session.id!),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) else {
            return
        }

        #if os(iOS)
        // Apply blocks via GlobalShieldManager
        for token in selection.applicationTokens {
            GlobalShieldManager.shared.addBlock(
                token: token,
                blockId: "session_\(session.id!)_\(UUID().uuidString)",
                appName: "Session App"
            )
        }
        #endif
    }

    private func removeSessionBlocks() {
        // Remove all session-related blocks via GlobalShieldManager
        // TODO: Track block IDs to remove them properly
    }
}

// MARK: - Session Detail Header

struct SessionDetailHeader: View {
    let session: Session
    let isLeader: Bool
    let showContent: Bool
    let onBack: () -> Void

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .completed: return .blue
        case .dissolved: return .gray
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "EN ATTENTE"
        case .active: return "EN COURS"
        case .completed: return "TERMINÉE"
        case .dissolved: return "DISSOUTE"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back button + Status
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.2))
                )
            }

            // Title
            Text(session.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            // Description
            Text(session.description)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            // Info row
            HStack(spacing: 16) {
                if isLeader {
                    Label("Leader", systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.yellow)
                } else {
                    Label("Membre", systemImage: "person.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Label("Code: \(session.inviteCode)", systemImage: "key.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: showContent)
    }
}

// MARK: - Lobby Content

struct LobbyContent: View {
    let session: Session
    let members: [SessionMember]
    let isLeader: Bool
    @Binding var isReady: Bool
    let selectedAppsCount: Int
    let showContent: Bool
    let onSelectApps: () -> Void
    let onMarkReady: () -> Void
    let onStartSession: () -> Void
    let onDissolve: () -> Void

    private var readyMembersCount: Int {
        members.filter { $0.isReady }.count
    }

    private var canStart: Bool {
        readyMembersCount > 0
    }

    var body: some View {
        VStack(spacing: 20) {
            // Member selection (if not leader and not ready)
            if !isLeader && !isReady {
                MemberAppSelectionCard(
                    selectedCount: selectedAppsCount,
                    showContent: showContent,
                    onSelect: onSelectApps,
                    onReady: onMarkReady
                )
            }

            // Members list
            MembersListSection(
                members: members,
                showContent: showContent
            )

            // Leader controls
            if isLeader {
                LeaderControlsSection(
                    canStart: canStart,
                    readyCount: readyMembersCount,
                    totalCount: members.count,
                    showContent: showContent,
                    onStart: onStartSession,
                    onDissolve: onDissolve
                )
            }
        }
    }
}

// MARK: - Member App Selection Card

struct MemberAppSelectionCard: View {
    let selectedCount: Int
    let showContent: Bool
    let onSelect: () -> Void
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // App selection button
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                        .font(.system(size: 24))
                        .foregroundColor(selectedCount > 0 ? .green : .blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vos Apps à Bloquer")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text(selectedCount > 0 ? "\(selectedCount) app(s) sélectionnée(s)" : "Choisir les apps")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            selectedCount > 0 ? Color.green.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: selectedCount > 0 ? 2 : 1
                        )
                )
            }

            // Ready button
            if selectedCount > 0 {
                Button(action: onReady) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))

                        Text("Je suis Prêt")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Members List Section

struct MembersListSection: View {
    let members: [SessionMember]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Membres (\(members.count))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            ForEach(members) { member in
                MemberRow(member: member)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

struct MemberRow: View {
    let member: SessionMember

    private var statusIcon: String {
        switch member.status {
        case .joined: return "circle"
        case .ready: return "checkmark.circle.fill"
        case .active: return "bolt.circle.fill"
        case .paused: return "pause.circle.fill"
        case .left: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch member.status {
        case .joined: return .gray
        case .ready: return .green
        case .active: return .blue
        case .paused: return .orange
        case .left: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(statusColor)

            // Username + role
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if member.role == .leader {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }

                Text(member.status.rawValue.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Apps count (without showing which apps - Apple restriction)
            if member.hasSelectedApps {
                Text("\(member.selectedAppsCount) app(s)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Leader Controls Section

struct LeaderControlsSection: View {
    let canStart: Bool
    let readyCount: Int
    let totalCount: Int
    let showContent: Bool
    let onStart: () -> Void
    let onDissolve: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Start button
            Button(action: onStart) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .bold))

                        Text("Démarrer la Session")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)

                    Text(readyCount == 1 && totalCount == 1 ?
                         "Démarrer seul ou attendre d'autres membres" :
                         "\(readyCount)/\(totalCount) membres prêts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: canStart ? [.green, .green.opacity(0.8)] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .disabled(!canStart)

            // Dissolve button
            Button(action: onDissolve) {
                Text("Dissoudre la Session")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

// MARK: - Active Content

struct ActiveContent: View {
    let session: Session
    let members: [SessionMember]
    let messages: [SessionMessage]
    let pauseRequests: [PauseRequest]
    let isLeader: Bool
    let isPaused: Bool
    @Binding var messageText: String
    let showContent: Bool
    let onSendMessage: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onExtend: (Int) -> Void
    let onRequestPause: (Int, String?) -> Void
    let onApprovePause: (String) -> Void
    let onDenyPause: (String) -> Void
    let onStop: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Active members
            MembersListSection(
                members: members.filter { $0.status == .active || $0.status == .paused },
                showContent: showContent
            )

            // Session Controls (Pause/Resume/Extend)
            SessionControlsSection(
                isPaused: isPaused,
                isLeader: isLeader,
                showContent: showContent,
                onPause: onPause,
                onResume: onResume,
                onExtend: onExtend,
                onRequestPause: onRequestPause
            )

            // Pause Requests (Leader only)
            if isLeader && !pauseRequests.isEmpty {
                PauseRequestsSection(
                    requests: pauseRequests,
                    showContent: showContent,
                    onApprove: onApprovePause,
                    onDeny: onDenyPause
                )
            }

            // Chat section
            ChatSection(
                messages: messages,
                messageText: $messageText,
                showContent: showContent,
                onSend: onSendMessage
            )

            // Leave/Stop Controls
            HStack(spacing: 12) {
                Button(action: onLeave) {
                    Text("Quitter")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                }

                if isLeader {
                    Button(action: onStop) {
                        Text("Arrêter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Chat Section

struct ChatSection: View {
    let messages: [SessionMessage]
    @Binding var messageText: String
    let showContent: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat du Groupe")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // Messages list
            VStack(spacing: 8) {
                ForEach(messages.suffix(10)) { message in
                    MessageRow(message: message)
                }
            }

            // Input
            HStack(spacing: 8) {
                TextField("Message...", text: $messageText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

struct MessageRow: View {
    let message: SessionMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.username)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.blue)

            Text(message.content)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Completed Content

struct CompletedContent: View {
    let session: Session
    let showContent: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Session Terminée!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Félicitations à tous les participants")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(showContent ? 1 : 0)
    }
}

// MARK: - Session Controls Section

struct SessionControlsSection: View {
    let isPaused: Bool
    let isLeader: Bool
    let showContent: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onExtend: (Int) -> Void
    let onRequestPause: (Int, String?) -> Void

    @State private var showExtendOptions = false
    @State private var showRequestPauseSheet = false

    var body: some View {
        VStack(spacing: 12) {
            // Pause/Resume button (Leaders only can pause directly)
            if isLeader {
                Button(action: isPaused ? onResume : onPause) {
                    HStack {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 20, weight: .bold))

                        Text(isPaused ? "Reprendre" : "Pause")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: isPaused ? [.green, .green.opacity(0.8)] : [.orange, .orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else if !isPaused {
                // Members can request pause
                Button(action: { showRequestPauseSheet = true }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18, weight: .bold))

                        Text("Demander une Pause")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                // Member is paused - show resume button
                Button(action: onResume) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20, weight: .bold))

                        Text("Reprendre")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // Extend button
            Button(action: { showExtendOptions = true }) {
                HStack {
                    Image(systemName: "clock.badge.plus.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text("Prolonger")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.15), value: showContent)
        .actionSheet(isPresented: $showExtendOptions) {
            ActionSheet(
                title: Text("Prolonger la Session"),
                message: Text("De combien de temps?"),
                buttons: [
                    .default(Text("+ 5 minutes")) {
                        onExtend(5)
                    },
                    .default(Text("+ 10 minutes")) {
                        onExtend(10)
                    },
                    .default(Text("+ 15 minutes")) {
                        onExtend(15)
                    },
                    .cancel(Text("Annuler"))
                ]
            )
        }
        .actionSheet(isPresented: $showRequestPauseSheet) {
            ActionSheet(
                title: Text("Demander une Pause"),
                message: Text("Pour combien de temps?"),
                buttons: [
                    .default(Text("5 minutes")) {
                        onRequestPause(5, nil)
                    },
                    .default(Text("10 minutes")) {
                        onRequestPause(10, nil)
                    },
                    .default(Text("15 minutes")) {
                        onRequestPause(15, nil)
                    },
                    .cancel(Text("Annuler"))
                ]
            )
        }
    }
}

// MARK: - Pause Requests Section

struct PauseRequestsSection: View {
    let requests: [PauseRequest]
    let showContent: Bool
    let onApprove: (String) -> Void
    let onDeny: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demandes de Pause")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            ForEach(requests) { request in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.requesterUsername)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(request.durationMinutes) minutes")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        if let reason = request.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { onApprove(request.id!) }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                        }

                        Button(action: { onDeny(request.id!) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

// MARK: - Dissolved Content

struct DissolvedContent: View {
    let session: Session
    let showContent: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Session Dissoute")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Cette session a été fermée par le leader")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(showContent ? 1 : 0)
    }
}

#Preview {
    SessionDetailView(session: Session(
        id: "preview",
        title: "Focus Marathon",
        description: "Session de concentration intense",
        leaderId: "user1",
        leaderUsername: "Alice",
        visibility: .publicSession,
        inviteCode: "ABC123",
        maxParticipants: 10,
        status: .lobby,
        createdAt: .init(),
        memberIds: ["user1"],
        suggestedAppsCount: 3
    ))
    .environmentObject(ZenloopManager.shared)
}