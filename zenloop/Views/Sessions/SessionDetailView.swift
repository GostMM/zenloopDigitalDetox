//
//  SessionDetailView.swift
//  zenloop
//
//  Vue detaillee d une session (Lobby + Active + Paused)
//  NEW: Pause/Resume/Stop controls, Pause request UI, Late join
//

import SwiftUI
import FamilyControls

struct SessionDetailView: View {
    let session: Session

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
    @State private var showStopAlert = false
    @State private var showPauseRequestSheet = false
    @State private var pauseRequestReason = ""
    @State private var showMemberPicker = false
    @State private var focusedField: Field? = nil

    enum Field {
        case messageInput
    }

    private var isLeader: Bool {
        sessionManager.currentUser?.id == (sessionManager.currentSession ?? session).leaderId
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var activeSession: Session {
        sessionManager.currentSession ?? session
    }

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: currentZenloopState)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                SessionDetailHeader(
                    session: activeSession,
                    isLeader: isLeader,
                    showContent: showContent,
                    onBack: { dismiss() }
                )
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        switch activeSession.status {
                        case .lobby:
                            lobbySection
                        case .active:
                            activeSection
                        case .paused:
                            pausedSection
                        case .completed:
                            CompletedContent(session: activeSession, showContent: showContent)
                        case .dissolved:
                            DissolvedContent(session: activeSession, showContent: showContent)
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
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { showContent = true }
            if let sessionId = session.id {
                sessionManager.startSessionListener(sessionId: sessionId)
            }
            if let sessionId = session.id,
               let localApps = sessionManager.getLocalApps(sessionId: sessionId),
               let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {
                selectedApps = selection
                isReady = localApps.selectedAppsCount > 0
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selectedApps)
        .alert("Quitter la Session", isPresented: $showLeaveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Quitter", role: .destructive) { leaveSession() }
        } message: { Text("Vos blocages seront retires.") }
        .alert("Dissoudre la Session", isPresented: $showDissolveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Dissoudre", role: .destructive) { dissolveSession() }
        } message: { Text("Cela terminera la session pour tous les membres.") }
        .alert("Arreter la Session", isPresented: $showStopAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Arreter", role: .destructive) { stopSession() }
        } message: { Text("La session sera marquee comme terminee pour tout le monde.") }
        .sheet(isPresented: $showPauseRequestSheet) {
            PauseRequestSheet(
                reason: $pauseRequestReason,
                onSubmit: { submitPauseRequest() }
            )
        }
    }

    // MARK: - Lobby Section

    private var lobbySection: some View {
        VStack(spacing: 20) {
            if !isLeader && !isReady {
                MemberAppSelectionCard(
                    selectedCount: selectedAppsCount, showContent: showContent,
                    onSelect: { showAppPicker = true }, onReady: markAsReady
                )
            }

            MembersListSection(members: sessionManager.currentSessionMembers, showContent: showContent)

            if isLeader {
                // Leader can start alone
                VStack(spacing: 12) {
                    Button(action: startSession) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Demarrer la Session")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.white)

                            let readyCount = sessionManager.currentSessionMembers.filter { $0.isReady }.count
                            let totalCount = sessionManager.currentSessionMembers.count
                            Text("\(readyCount)/\(totalCount) membres prets")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }

                    Button(action: { showDissolveAlert = true }) {
                        Text("Dissoudre la Session")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
            }
        }
    }

    // MARK: - Active Session Section

    private var activeSection: some View {
        VStack(spacing: 20) {
            // Pause requests banner (leader only)
            if isLeader && !sessionManager.pendingPauseRequests.isEmpty {
                PauseRequestsBanner(
                    requests: sessionManager.pendingPauseRequests,
                    onAccept: { req in acceptPauseRequest(req) },
                    onDecline: { req in declinePauseRequest(req) }
                )
            }

            MembersListSection(
                members: sessionManager.currentSessionMembers.filter { $0.status == .active },
                showContent: showContent
            )

            ChatSection(
                messages: sessionManager.currentSessionMessages,
                messageText: $messageText,
                showContent: showContent,
                onSend: sendMessage,
                members: sessionManager.currentSessionMembers
            )

            // Leader controls: Pause / Stop
            if isLeader {
                LeaderActiveControls(
                    onPause: { pauseSession() },
                    onStop: { showStopAlert = true },
                    onDissolve: { showDissolveAlert = true }
                )
            } else {
                // Member controls: Request pause / Leave
                MemberActiveControls(
                    onRequestPause: { showPauseRequestSheet = true },
                    onLeave: { showLeaveAlert = true }
                )
            }
        }
    }

    // MARK: - Paused Session Section

    private var pausedSection: some View {
        VStack(spacing: 20) {
            // Paused banner
            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("Session en Pause")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                if let pausedBy = activeSession.pausedBy {
                    let pauserName = sessionManager.currentSessionMembers.first(where: { $0.id == pausedBy })?.username ?? "Leader"
                    Text("Mise en pause par \(pauserName)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.orange.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(0.3), lineWidth: 1))

            MembersListSection(
                members: sessionManager.currentSessionMembers.filter { $0.status != .left },
                showContent: showContent
            )

            ChatSection(
                messages: sessionManager.currentSessionMessages,
                messageText: $messageText,
                showContent: showContent,
                onSend: sendMessage,
                members: sessionManager.currentSessionMembers
            )

            // Leader: Resume / Stop
            if isLeader {
                VStack(spacing: 12) {
                    Button(action: { resumeSession() }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Reprendre la Session")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: { showStopAlert = true }) {
                        Text("Arreter la Session")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                    }
                }
            } else {
                Button(action: { showLeaveAlert = true }) {
                    Text("Quitter la Session")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
                }
            }
        }
    }

    // MARK: - Actions

    private var currentZenloopState: ZenloopState {
        if activeSession.status == .active { return .active }
        return .idle
    }

    private func markAsReady() {
        guard selectedAppsCount > 0 else { return }
        Task {
            do {
                if let tokenData = try? JSONEncoder().encode(selectedApps) {
                    sessionManager.saveLocalApps(sessionId: session.id!, appTokens: tokenData, count: selectedAppsCount)
                }
                try await sessionManager.markAsReady(sessionId: session.id!, appsCount: selectedAppsCount)
                await MainActor.run { isReady = true; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } catch { print("Error marking as ready: \(error)") }
        }
    }

    private func startSession() {
        Task {
            do {
                try await sessionManager.startSession(sessionId: session.id!)
                await MainActor.run { applySessionBlocks(); UINotificationFeedbackGenerator().notificationOccurred(.success) }
            } catch { print("Error starting session: \(error)") }
        }
    }

    private func pauseSession() {
        Task {
            do {
                try await sessionManager.pauseSession(sessionId: session.id!)
                await MainActor.run { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } catch { print("Error pausing session: \(error)") }
        }
    }

    private func resumeSession() {
        Task {
            do {
                try await sessionManager.resumeSession(sessionId: session.id!)
                await MainActor.run { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } catch { print("Error resuming session: \(error)") }
        }
    }

    private func stopSession() {
        Task {
            do {
                try await sessionManager.stopSession(sessionId: session.id!)
                await MainActor.run { removeSessionBlocks(); UINotificationFeedbackGenerator().notificationOccurred(.success) }
            } catch { print("Error stopping session: \(error)") }
        }
    }

    private func submitPauseRequest() {
        let reason = pauseRequestReason.isEmpty ? nil : pauseRequestReason
        Task {
            do {
                try await sessionManager.requestPause(sessionId: session.id!, reason: reason)
                await MainActor.run { showPauseRequestSheet = false; pauseRequestReason = ""; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } catch { print("Error requesting pause: \(error)") }
        }
    }

    private func acceptPauseRequest(_ request: PauseRequest) {
        Task {
            do {
                try await sessionManager.respondToPauseRequest(requestId: request.id!, sessionId: session.id!, accept: true)
            } catch { print("Error accepting pause: \(error)") }
        }
    }

    private func declinePauseRequest(_ request: PauseRequest) {
        Task {
            do {
                try await sessionManager.respondToPauseRequest(requestId: request.id!, sessionId: session.id!, accept: false)
            } catch { print("Error declining pause: \(error)") }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let content = messageText
        messageText = ""

        Task {
            do {
                // Envoyer le message
                try await sessionManager.sendMessage(sessionId: session.id!, content: content)

                // Créer les notifications de mention si nécessaire
                if content.contains("@") {
                    let notifManager = SocialNotificationManager.shared
                    try await notifManager.createMentionNotifications(
                        messageContent: content,
                        sessionId: session.id!,
                        sessionTitle: session.title,
                        messageId: UUID().uuidString,
                        fromUserId: sessionManager.currentUser?.id ?? "",
                        fromUsername: sessionManager.currentUser?.username ?? "",
                        sessionMembers: sessionManager.currentSessionMembers
                    )
                }
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }

    private func leaveSession() {
        Task {
            do {
                try await sessionManager.leaveSession(sessionId: session.id!)
                await MainActor.run { removeSessionBlocks(); dismiss() }
            } catch { print("Error leaving session: \(error)") }
        }
    }

    private func dissolveSession() {
        Task {
            do {
                try await sessionManager.dissolveSession(sessionId: session.id!)
                await MainActor.run { removeSessionBlocks(); dismiss() }
            } catch { print("Error dissolving session: \(error)") }
        }
    }

    private func applySessionBlocks() {
        guard let localApps = sessionManager.getLocalApps(sessionId: session.id!),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) else { return }
        #if os(iOS)
        for token in selection.applicationTokens {
            GlobalShieldManager.shared.addBlock(token: token, blockId: "session_\(session.id!)_\(UUID().uuidString)", appName: "Session App")
        }
        #endif
    }

    private func removeSessionBlocks() {
        // TODO: Track block IDs to remove properly
    }
}

// MARK: - Leader Active Controls

struct LeaderActiveControls: View {
    let onPause: () -> Void
    let onStop: () -> Void
    let onDissolve: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPause) {
                    HStack {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Pause")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }

                Button(action: onStop) {
                    HStack {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Arreter")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                }
            }

            Button(action: onDissolve) {
                Text("Dissoudre")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Member Active Controls

struct MemberActiveControls: View {
    let onRequestPause: () -> Void
    let onLeave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRequestPause) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Demander Pause")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }

            Button(action: onLeave) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                    Text("Quitter")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
        }
    }
}

// MARK: - Pause Requests Banner (Leader sees this)

struct PauseRequestsBanner: View {
    let requests: [PauseRequest]
    let onAccept: (PauseRequest) -> Void
    let onDecline: (PauseRequest) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("Demandes de Pause")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(requests.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
            }

            ForEach(requests) { request in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.requesterUsername)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        if let reason = request.reason, !reason.isEmpty {
                            Text("\"\(reason)\"")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .italic()
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { onAccept(request) }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.green))
                        }

                        Button(action: { onDecline(request) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.red))
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Pause Request Sheet (Member fills this)

struct PauseRequestSheet: View {
    @Binding var reason: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Demander une Pause")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Le leader de la session devra accepter votre demande")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Raison (optionnel)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))

                        TextField("Ex: Besoin d'une pause toilettes", text: $reason)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                    }

                    Button(action: onSubmit) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Envoyer la Demande")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

// MARK: - Reused Components

struct SessionDetailHeader: View {
    let session: Session
    let isLeader: Bool
    let showContent: Bool
    let onBack: () -> Void

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .yellow
        case .completed: return .blue
        case .dissolved: return .gray
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "EN ATTENTE"
        case .active: return "EN COURS"
        case .paused: return "EN PAUSE"
        case .completed: return "TERMINEE"
        case .dissolved: return "DISSOUTE"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(statusColor.opacity(0.2)))
            }

            Text(session.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text(session.description)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

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
        .padding(.top, 60).padding(.bottom, 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: showContent)
    }
}

struct MembersListSection: View {
    let members: [SessionMember]; let showContent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Membres (\(members.count))")
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            ForEach(members) { member in MemberRow(member: member) }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

struct MemberRow: View {
    let member: SessionMember
    private var statusIcon: String {
        switch member.status {
        case .joined: return "circle"; case .ready: return "checkmark.circle.fill"
        case .active: return "bolt.circle.fill"; case .paused: return "pause.circle.fill"
        case .left: return "xmark.circle.fill"
        }
    }
    private var statusColor: Color {
        switch member.status {
        case .joined: return .gray; case .ready: return .green
        case .active: return .blue; case .paused: return .orange
        case .left: return .red
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon).font(.system(size: 16, weight: .semibold)).foregroundColor(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.username).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    if member.role == .leader {
                        Image(systemName: "crown.fill").font(.system(size: 12)).foregroundColor(.yellow)
                    }
                }
                Text(member.status.rawValue.capitalized)
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if member.hasSelectedApps {
                Text("\(member.selectedAppsCount) app(s)")
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }
}

struct MemberAppSelectionCard: View {
    let selectedCount: Int; let showContent: Bool; let onSelect: () -> Void; let onReady: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                        .font(.system(size: 24)).foregroundColor(selectedCount > 0 ? .green : .blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vos Apps a Bloquer").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        Text(selectedCount > 0 ? "\(selectedCount) app(s) selectionnee(s)" : "Choisir les apps")
                            .font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.15, green: 0.15, blue: 0.17)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedCount > 0 ? Color.green.opacity(0.5) : Color.white.opacity(0.1), lineWidth: selectedCount > 0 ? 2 : 1))
            }
            if selectedCount > 0 {
                Button(action: onReady) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .bold))
                        Text("Je suis Pret").font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                }.buttonStyle(ScaleButtonStyle())
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

struct ChatSection: View {
    let messages: [SessionMessage]
    @Binding var messageText: String
    let showContent: Bool
    let onSend: () -> Void
    let members: [SessionMember]

    @State private var showMentionPicker = false
    @State private var mentionSearchText = ""
    @FocusState private var isInputFocused: Bool

    var filteredMentionMembers: [SessionMember] {
        if mentionSearchText.isEmpty {
            return members
        }
        return members.filter { $0.username.lowercased().contains(mentionSearchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat du Groupe").font(.system(size: 18, weight: .bold)).foregroundColor(.white)

            VStack(spacing: 8) {
                ForEach(messages.suffix(15)) { message in MessageRow(message: message) }
            }

            VStack(spacing: 8) {
                // Mention picker
                if showMentionPicker && !filteredMentionMembers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredMentionMembers) { member in
                                MentionChip(member: member) {
                                    insertMention(member.username)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }

                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { showMentionPicker.toggle() }) {
                            Image(systemName: "at")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                        }

                        TextField("Message...", text: $messageText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .focused($isInputFocused)
                            .onChange(of: messageText) { _, newValue in
                                checkForMentionTrigger(newValue)
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))

                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }

    private func checkForMentionTrigger(_ text: String) {
        // Détecter si l'utilisateur tape @ pour ouvrir le picker
        if text.hasSuffix("@") {
            showMentionPicker = true
            mentionSearchText = ""
        } else if let lastAtIndex = text.lastIndex(of: "@") {
            let afterAt = String(text[text.index(after: lastAtIndex)...])
            if !afterAt.contains(" ") {
                showMentionPicker = true
                mentionSearchText = afterAt
            }
        } else {
            showMentionPicker = false
        }
    }

    private func insertMention(_ username: String) {
        if let lastAtIndex = messageText.lastIndex(of: "@") {
            messageText = String(messageText[..<lastAtIndex]) + "@\(username) "
        } else {
            messageText += "@\(username) "
        }
        showMentionPicker = false
        mentionSearchText = ""
        isInputFocused = true
    }
}

struct MentionChip: View {
    let member: SessionMember
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text("@\(member.username)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
            )
        }
    }
}

struct MessageRow: View {
    let message: SessionMessage
    private var isSystem: Bool { message.messageType == .systemAlert }
    var body: some View {
        if isSystem {
            Text(message.content)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .italic()
                .frame(maxWidth: .infinity)
                .padding(8)
        } else {
            HStack(alignment: .top, spacing: 8) {
                Text(message.username).font(.system(size: 13, weight: .bold)).foregroundColor(.blue)
                Text(message.content).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
        }
    }
}

struct CompletedContent: View {
    let session: Session; let showContent: Bool
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.green)
            Text("Session Terminee!").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text("Felicitations a tous les participants").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7))
        }.frame(maxWidth: .infinity).padding(.vertical, 60).opacity(showContent ? 1 : 0)
    }
}

struct DissolvedContent: View {
    let session: Session; let showContent: Bool
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 64)).foregroundColor(.gray)
            Text("Session Dissoute").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text("Cette session a ete fermee par le leader").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 60).opacity(showContent ? 1 : 0)
    }
}

#Preview {
    SessionDetailView(session: Session(
        id: "preview", title: "Focus Marathon",
        description: "Session de concentration intense",
        leaderId: "user1", leaderUsername: "Alice",
        visibility: .publicSession, inviteCode: "ABC123",
        maxParticipants: 10, status: .lobby,
        createdAt: .init(), startedAt: nil, endedAt: nil,
        pausedAt: nil, pausedBy: nil,
        memberIds: ["user1"], suggestedAppsCount: 3
    ))
    .environmentObject(ZenloopManager.shared)
}