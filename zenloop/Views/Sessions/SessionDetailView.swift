//
//  SessionDetailView.swift
//  zenloop
//
//  Vue détaillée d'une session — redesign social & animé
//  Lobby + Active + Paused + Completed + Dissolved
//  Animations fluides, avatars, micro-interactions, ambiance vivante
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

    enum Field { case messageInput }

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

            // Particules d'ambiance (même style que SocialTab)
            SessionParticlesOverlay(status: activeSession.status)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                SessionDetailMinimalHeader(
                    session: activeSession,
                    isLeader: isLeader,
                    showContent: showContent,
                    isPremium: PurchaseManager.shared.isPremium,
                    unreadCount: SocialNotificationManager.shared.unreadCount,
                    onBack: { dismiss() },
                    onNotificationTap: { /* TODO: open notifications */ }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

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
                    .padding(.top, 16)
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
        } message: { Text("Vos blocages seront retirés.") }
        .alert("Dissoudre la Session", isPresented: $showDissolveAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Dissoudre", role: .destructive) { dissolveSession() }
        } message: { Text("Cela terminera la session pour tous les membres.") }
        .alert("Arrêter la Session", isPresented: $showStopAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Arrêter", role: .destructive) { stopSession() }
        } message: { Text("La session sera marquée comme terminée pour tout le monde.") }
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
            // Invite code card prominent
            InviteCodeCard(code: activeSession.inviteCode, showContent: showContent)

            if !isLeader && !isReady {
                MemberAppSelectionCard(
                    selectedCount: selectedAppsCount, showContent: showContent,
                    onSelect: { showAppPicker = true }, onReady: markAsReady
                )
            }

            MembersListSection(
                members: sessionManager.currentSessionMembers,
                showContent: showContent
            )

            if isLeader {
                LeaderLobbyControls(
                    readyCount: sessionManager.currentSessionMembers.filter { $0.isReady }.count,
                    totalCount: sessionManager.currentSessionMembers.count,
                    showContent: showContent,
                    onStart: startSession,
                    onDissolve: { showDissolveAlert = true }
                )
            }
        }
    }

    // MARK: - Active Session Section

    private var activeSection: some View {
        VStack(spacing: 20) {
            // Live pulse banner
            LiveSessionBanner(
                memberCount: sessionManager.currentSessionMembers.filter { $0.status == .active }.count,
                showContent: showContent
            )

            // Pause requests (leader only)
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

            if isLeader {
                LeaderActiveControls(
                    onPause: { pauseSession() },
                    onStop: { showStopAlert = true },
                    onDissolve: { showDissolveAlert = true }
                )
            } else {
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
            PausedBanner(
                pausedBy: activeSession.pausedBy,
                members: sessionManager.currentSessionMembers,
                showContent: showContent
            )

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

            if isLeader {
                LeaderPausedControls(
                    onResume: { resumeSession() },
                    onStop: { showStopAlert = true }
                )
            } else {
                Button(action: { showLeaveAlert = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .bold))
                        Text("Quitter la Session")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())
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
                try await sessionManager.sendMessage(sessionId: session.id!, content: content)
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
            } catch { print("Error sending message: \(error)") }
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


// MARK: - Session Particles Overlay (contextual ambiance)

struct SessionParticlesOverlay: View {
    let status: SessionStatus
    @State private var animate = false

    private var particleColor: Color {
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .lobby: return .cyan
        case .completed: return .blue
        case .dissolved: return .gray
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { _ in
            Canvas { context, size in
                for i in 0..<8 {
                    let seed = CGFloat(i)
                    let x = (seed / 8.0 + 0.06 * seed) * size.width
                    let baseY = seed / 8.0 * size.height
                    let y = animate ? baseY - size.height * 0.15 : baseY + size.height * 0.15
                    let wrappedY = ((y.truncatingRemainder(dividingBy: size.height)) + size.height)
                        .truncatingRemainder(dividingBy: size.height)
                    let dotSize = CGFloat.random(in: 3...6)
                    let rect = CGRect(x: x, y: wrappedY, width: dotSize, height: dotSize)
                    context.opacity = 0.2
                    context.fill(Circle().path(in: rect), with: .color(particleColor))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}


// MARK: - Session Detail Header (redesigné)

struct SessionDetailHeader: View {
    let session: Session
    let isLeader: Bool
    let showContent: Bool
    let onBack: () -> Void
    @State private var glowPulse = false

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .yellow
        case .completed: return .cyan
        case .dissolved: return .gray
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "EN ATTENTE"
        case .active: return "EN COURS"
        case .paused: return "EN PAUSE"
        case .completed: return "TERMINÉE"
        case .dissolved: return "DISSOUTE"
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .lobby: return "hourglass"
        case .active: return "bolt.fill"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .dissolved: return "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top bar
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(BounceButtonStyle())

                Spacer()

                // Status pill animé
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(glowPulse ? 1.4 : 1.0)
                        .shadow(color: statusColor.opacity(glowPulse ? 0.6 : 0), radius: 6)

                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .bold))

                    Text(statusText)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.12))
                        .overlay(
                            Capsule().stroke(statusColor.opacity(0.25), lineWidth: 1)
                        )
                )

                // Role badge
                if isLeader {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("LEADER")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.12))
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.2), lineWidth: 1))
                    )
                }
            }

            // Session title
            Text(session.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(2)

            // Description
            if !session.description.isEmpty {
                Text(session.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }

            // Meta row: members count + code
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(session.memberIds.count) membres")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.45))

                HStack(spacing: 5) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(session.inviteCode)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.45))

                Spacer()
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 12)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 0.9, dampingFraction: 0.8), value: showContent)
        .onAppear {
            if session.status == .active || session.status == .lobby {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
    }
}

// MARK: - Session Detail Minimal Header

struct SessionDetailMinimalHeader: View {
    let session: Session
    let isLeader: Bool
    let showContent: Bool
    let isPremium: Bool
    let unreadCount: Int
    let onBack: () -> Void
    let onNotificationTap: () -> Void

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .yellow
        case .completed: return .cyan
        case .dissolved: return .gray
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "En attente"
        case .active: return "En cours"
        case .paused: return "En pause"
        case .completed: return "Terminée"
        case .dissolved: return "Dissoute"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top row: back button, notification, pro badge, status indicator
            HStack(alignment: .center, spacing: 8) {
                // Back button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                // Cloche de notification
                Button(action: onNotificationTap) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))

                        if unreadCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 18, height: 18)
                                Text("\(unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 8, y: -8)
                        }
                    }
                }

                // Badge PRO si premium
                if isPremium {
                    ProBadge()
                }

                // Leader badge
                if isLeader {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("LEADER")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.12))
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.2), lineWidth: 1))
                    )
                }

                // Indicateur d'état de session
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(session.status == .active ? 1.3 : 1.0)
                    .animation(
                        session.status == .active ?
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                        .easeOut(duration: 0.3),
                        value: session.status
                    )
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -10)

            // Session title and subtitle
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }

                Spacer()
            }
        }
        .padding(.bottom, 10)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}


// MARK: - Invite Code Card (prominent in lobby)

struct InviteCodeCard: View {
    let code: String
    let showContent: Bool
    @State private var copied = false
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cyan)

                Text("Code d'invitation")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.0)

                Spacer()
            }

            Button(action: {
                UIPasteboard.general.string = code
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { copied = true }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            }) {
                HStack(spacing: 12) {
                    Text(code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)

                    Spacer()

                    ZStack {
                        Image(systemName: "doc.on.doc.fill")
                            .opacity(copied ? 0 : 1)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .opacity(copied ? 1 : 0)
                            .scaleEffect(copied ? 1 : 0.5)
                    }
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                }
            }

            if copied {
                Text("Copié !")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.green)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(shimmer ? 0.4 : 0.15),
                            Color.cyan.opacity(shimmer ? 0.1 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 25)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}


// MARK: - Live Session Banner (during active)

struct LiveSessionBanner: View {
    let memberCount: Int
    let showContent: Bool
    @State private var livePulse = false

    var body: some View {
        HStack(spacing: 14) {
            // Live dot
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .scaleEffect(livePulse ? 1.4 : 1.0)
                    .opacity(livePulse ? 0 : 0.6)

                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .shadow(color: .green.opacity(0.6), radius: 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Session en cours")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(memberCount) membre\(memberCount > 1 ? "s" : "") en focus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
            }

            Spacer()

            // Timer placeholder
            Image(systemName: "timer")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
    }
}


// MARK: - Paused Banner

struct PausedBanner: View {
    let pausedBy: String?
    let members: [SessionMember]
    let showContent: Bool
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 90, height: 90)
                    .scaleEffect(breathe ? 1.15 : 1.0)

                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Session en Pause")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let pausedBy = pausedBy {
                let pauserName = members.first(where: { $0.id == pausedBy })?.username ?? "Leader"
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                    Text("Mise en pause par \(pauserName)")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
        )
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}


// MARK: - Members List Section (redesigné)

struct MembersListSection: View {
    let members: [SessionMember]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.8))

                Text("Membres")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(members.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.12)))

                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                MemberRow(member: member, index: index)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}


// MARK: - Member Row (redesigné avec avatar)

struct MemberRow: View {
    let member: SessionMember
    var index: Int = 0
    @State private var appeared = false

    private let avatarGradients: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.3, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.3, green: 0.8, blue: 0.7), Color(red: 0.2, green: 0.6, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.4), Color(red: 0.9, green: 0.3, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    private var statusColor: Color {
        switch member.status {
        case .joined: return .gray
        case .ready: return .green
        case .active: return .green
        case .paused: return .orange
        case .left: return .red
        }
    }

    private var statusText: String {
        switch member.status {
        case .joined: return "Rejoint"
        case .ready: return "Prêt"
        case .active: return "En focus"
        case .paused: return "En pause"
        case .left: return "Parti"
        }
    }

    private var statusIcon: String {
        switch member.status {
        case .joined: return "circle"
        case .ready: return "checkmark.circle.fill"
        case .active: return "bolt.circle.fill"
        case .paused: return "pause.circle.fill"
        case .left: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar avec indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(avatarGradients[index % avatarGradients.count])
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(member.username.prefix(1)).uppercased())
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )

                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().stroke(Color(red: 0.1, green: 0.1, blue: 0.12), lineWidth: 2.5)
                    )
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.username)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if member.role == .leader {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                            Text("LEADER")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.5)
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.yellow.opacity(0.15)))
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(statusColor.opacity(0.8))
            }

            Spacer()

            if member.hasSelectedApps {
                HStack(spacing: 4) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                    Text("\(member.selectedAppsCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}


// MARK: - Member App Selection Card (redesigné)

struct MemberAppSelectionCard: View {
    let selectedCount: Int
    let showContent: Bool
    let onSelect: () -> Void
    let onReady: () -> Void
    @State private var readyPulse = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                selectedCount > 0
                                ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.3, green: 0.5, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 48, height: 48)
                            .shadow(
                                color: (selectedCount > 0 ? Color.green : Color.blue).opacity(0.3),
                                radius: 10, x: 0, y: 4
                            )

                        Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apps à Bloquer")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(selectedCount > 0 ? "\(selectedCount) app\(selectedCount > 1 ? "s" : "") sélectionnée\(selectedCount > 1 ? "s" : "")" : "Choisir les apps à bloquer")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            selectedCount > 0 ? Color.green.opacity(0.4) : Color.white.opacity(0.06),
                            lineWidth: selectedCount > 0 ? 1.5 : 1
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())

            if selectedCount > 0 {
                Button(action: onReady) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .scaleEffect(readyPulse ? 1.15 : 1.0)

                        Text("Je suis Prêt")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.green, Color(red: 0.2, green: 0.8, blue: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.35), radius: 14, x: 0, y: 6)
                    )
                }
                .buttonStyle(BounceButtonStyle())
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        readyPulse = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}


// MARK: - Leader Lobby Controls

struct LeaderLobbyControls: View {
    let readyCount: Int
    let totalCount: Int
    let showContent: Bool
    let onStart: () -> Void
    let onDissolve: () -> Void
    @State private var startGlow = false

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onStart) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                        Text("Démarrer la Session")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)

                    // Progress bar
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: totalCount > 0 ? geo.size.width * CGFloat(readyCount) / CGFloat(totalCount) : 0,
                                        height: 6
                                    )
                                    .animation(.spring(response: 0.6), value: readyCount)
                            }
                        }
                        .frame(height: 6)

                        Text("\(readyCount)/\(totalCount) membres prêts")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.green, Color(red: 0.2, green: 0.75, blue: 0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(startGlow ? 0.5 : 0.2), radius: startGlow ? 20 : 10, x: 0, y: 6)
                )
            }
            .buttonStyle(BounceButtonStyle())

            Button(action: onDissolve) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Dissoudre la Session")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.red.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                startGlow = true
            }
        }
    }
}


// MARK: - Leader Active Controls (redesigné)

struct LeaderActiveControls: View {
    let onPause: () -> Void
    let onStop: () -> Void
    let onDissolve: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPause) {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Pause")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())

                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Arrêter")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())
            }

            Button(action: onDissolve) {
                Text("Dissoudre")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}


// MARK: - Member Active Controls (redesigné)

struct MemberActiveControls: View {
    let onRequestPause: () -> Void
    let onLeave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRequestPause) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Demander Pause")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(BounceButtonStyle())

            Button(action: onLeave) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                    Text("Quitter")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(BounceButtonStyle())
        }
    }
}


// MARK: - Leader Paused Controls

struct LeaderPausedControls: View {
    let onResume: () -> Void
    let onStop: () -> Void
    @State private var resumeGlow = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onResume) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Reprendre la Session")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [.green, Color(red: 0.2, green: 0.8, blue: 0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(resumeGlow ? 0.5 : 0.2), radius: resumeGlow ? 18 : 8, x: 0, y: 5)
                )
            }
            .buttonStyle(BounceButtonStyle())

            Button(action: onStop) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Arrêter la Session")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.red.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                resumeGlow = true
            }
        }
    }
}


// MARK: - Pause Requests Banner (redesigné)

struct PauseRequestsBanner: View {
    let requests: [PauseRequest]
    let onAccept: (PauseRequest) -> Void
    let onDecline: (PauseRequest) -> Void
    @State private var alertPulse = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 38, height: 38)
                        .scaleEffect(alertPulse ? 1.15 : 1.0)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Demandes de Pause")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(requests.count) en attente")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.8))
                }

                Spacer()
            }

            ForEach(requests) { request in
                HStack(spacing: 12) {
                    // Requester avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 34, height: 34)

                        Text(String(request.requesterUsername.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(request.requesterUsername)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let reason = request.reason, !reason.isEmpty {
                            Text("« \(reason) »")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { onAccept(request) }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                        .shadow(color: .green.opacity(0.35), radius: 6, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(BounceButtonStyle())

                        Button(action: { onDecline(request) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                )
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: .orange.opacity(0.08), radius: 14, x: 0, y: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                alertPulse = true
            }
        }
    }
}


// MARK: - Pause Request Sheet (redesigné)

struct PauseRequestSheet: View {
    @Binding var reason: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var iconBreathe = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .scaleEffect(iconBreathe ? 1.1 : 1.0)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Demander une Pause")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Le leader de la session devra accepter")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Raison (optionnel)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.8)

                        TextField("Ex: Besoin d'une pause", text: $reason)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }

                    Button(action: onSubmit) {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Envoyer la Demande")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, Color(red: 1.0, green: 0.6, blue: 0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .orange.opacity(0.35), radius: 14, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(BounceButtonStyle())

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
                            .font(.system(size: 26))
                            .foregroundStyle(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                iconBreathe = true
            }
        }
    }
}


// MARK: - Chat Section (redesigné)

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
        if mentionSearchText.isEmpty { return members }
        return members.filter { $0.username.lowercased().contains(mentionSearchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.8))

                Text("Chat du Groupe")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !messages.isEmpty {
                    Text("\(messages.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.cyan.opacity(0.12)))
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            // Messages
            VStack(spacing: 6) {
                if messages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.white.opacity(0.15))
                        Text("Pas encore de messages")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(messages.suffix(15)) { message in
                        MessageRow(message: message)
                    }
                }
            }

            // Input area
            VStack(spacing: 8) {
                // Mention picker
                if showMentionPicker && !filteredMentionMembers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredMentionMembers) { member in
                                MentionChip(member: member) { insertMention(member.username) }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { showMentionPicker.toggle() } }) {
                            Image(systemName: "at")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(showMentionPicker ? .cyan : .white.opacity(0.4))
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
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isInputFocused ? Color.cyan.opacity(0.3) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )

                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(
                                messageText.isEmpty
                                ? LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .disabled(messageText.isEmpty)
                    .buttonStyle(BounceButtonStyle())
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }

    private func checkForMentionTrigger(_ text: String) {
        if text.hasSuffix("@") {
            withAnimation(.spring(response: 0.3)) { showMentionPicker = true }
            mentionSearchText = ""
        } else if let lastAtIndex = text.lastIndex(of: "@") {
            let afterAt = String(text[text.index(after: lastAtIndex)...])
            if !afterAt.contains(" ") {
                withAnimation(.spring(response: 0.3)) { showMentionPicker = true }
                mentionSearchText = afterAt
            }
        } else {
            withAnimation(.spring(response: 0.3)) { showMentionPicker = false }
        }
    }

    private func insertMention(_ username: String) {
        if let lastAtIndex = messageText.lastIndex(of: "@") {
            messageText = String(messageText[..<lastAtIndex]) + "@\(username) "
        } else {
            messageText += "@\(username) "
        }
        withAnimation(.spring(response: 0.3)) { showMentionPicker = false }
        mentionSearchText = ""
        isInputFocused = true
    }
}


// MARK: - Mention Chip (redesigné)

struct MentionChip: View {
    let member: SessionMember
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(String(member.username.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text("@\(member.username)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cyan.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}


// MARK: - Message Row (redesigné)

struct MessageRow: View {
    let message: SessionMessage
    private var isSystem: Bool { message.messageType == .systemAlert }
    @State private var appeared = false

    var body: some View {
        Group {
            if isSystem {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(message.content)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
                .italic()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    // Mini avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.7), .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(message.username.prefix(1)).uppercased())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(message.username)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.9))

                        Text(message.content)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}


// MARK: - Completed Content (redesigné)

struct CompletedContent: View {
    let session: Session
    let showContent: Bool
    @State private var confetti = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(confetti ? 1.1 : 1.0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(confetti ? 1.0 : 0.8)
            }

            VStack(spacing: 8) {
                Text("Session Terminée !")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Félicitations à tous les participants")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Stats
            HStack(spacing: 20) {
                StatBubble(icon: "person.2.fill", value: "\(session.memberIds.count)", label: "Membres")
                StatBubble(icon: "clock.fill", value: "—", label: "Durée")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.3)) {
                confetti = true
            }
        }
    }
}

struct StatBubble: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.cyan.opacity(0.8))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}


// MARK: - Dissolved Content (redesigné)

struct DissolvedContent: View {
    let session: Session
    let showContent: Bool

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.06))
                    .frame(width: 110, height: 110)

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.6), .gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Session Dissoute")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text("Cette session a été fermée par le leader")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .opacity(showContent ? 1 : 0)
    }
}


// MARK: - Preview

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