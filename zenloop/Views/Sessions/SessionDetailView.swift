//
//  SessionDetailView.swift
//  zenloop
//
//  Vue détaillée — design ouvert, sans cards, éléments disposés librement
//  Les apps bloquées sont des tokens flottants, les membres des avatars directs
//  Ambiance sociale organique, espace négatif généreux
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

            SessionParticlesOverlay(status: activeSession.status)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // — Header minimal ouvert —
                SessionDetailOpenHeader(
                    session: activeSession,
                    isLeader: isLeader,
                    showContent: showContent,
                    onBack: { dismiss() }
                )
                .padding(.horizontal, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
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

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 24)
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

    // MARK: - Lobby

    private var lobbySection: some View {
        VStack(alignment: .leading, spacing: 32) {

            InviteCodeOpen(code: activeSession.inviteCode, showContent: showContent)

            if !isLeader && !isReady {
                AppSelectionOpen(
                    selectedApps: selectedApps,
                    selectedCount: selectedAppsCount,
                    showContent: showContent,
                    onSelect: { showAppPicker = true },
                    onReady: markAsReady
                )
            }

            MembersAvatarStrip(
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
        .padding(.top, 20)
    }

    // MARK: - Active

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 28) {

            LiveIndicatorOpen(
                memberCount: sessionManager.currentSessionMembers.filter { $0.status == .active }.count,
                showContent: showContent
            )

            if selectedAppsCount > 0 {
                BlockedAppsOpen(
                    selectedApps: selectedApps,
                    showContent: showContent
                )
            }

            if isLeader && !sessionManager.pendingPauseRequests.isEmpty {
                PauseRequestsOpen(
                    requests: sessionManager.pendingPauseRequests,
                    onAccept: { req in acceptPauseRequest(req) },
                    onDecline: { req in declinePauseRequest(req) }
                )
            }

            MembersAvatarStrip(
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
        .padding(.top, 20)
    }

    // MARK: - Paused

    private var pausedSection: some View {
        VStack(alignment: .leading, spacing: 28) {

            PausedIndicatorOpen(
                pausedBy: activeSession.pausedBy,
                members: sessionManager.currentSessionMembers,
                showContent: showContent
            )

            MembersAvatarStrip(
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
                    .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Actions

    private var currentZenloopState: ZenloopState {
        activeSession.status == .active ? .active : .idle
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
        Task { try? await sessionManager.respondToPauseRequest(requestId: request.id!, sessionId: session.id!, accept: true) }
    }

    private func declinePauseRequest(_ request: PauseRequest) {
        Task { try? await sessionManager.respondToPauseRequest(requestId: request.id!, sessionId: session.id!, accept: false) }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let content = messageText
        messageText = ""
        Task {
            do {
                try await sessionManager.sendMessage(sessionId: session.id!, content: content)
                if content.contains("@") {
                    try await SocialNotificationManager.shared.createMentionNotifications(
                        messageContent: content, sessionId: session.id!, sessionTitle: session.title,
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

    private func removeSessionBlocks() {}
}


// MARK: - Session Particles Overlay

struct SessionParticlesOverlay: View {
    let status: SessionStatus
    @State private var animate = false

    private var particleColor: Color {
        switch status {
        case .active: return .green; case .paused: return .orange
        case .lobby: return .cyan; case .completed: return .blue; case .dissolved: return .gray
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
                    let dotSize: CGFloat = [3, 4, 5, 6, 4, 5, 3, 6][i]
                    let rect = CGRect(x: x, y: wrappedY, width: dotSize, height: dotSize)
                    context.opacity = 0.18
                    context.fill(Circle().path(in: rect), with: .color(particleColor))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { animate = true }
        }
    }
}


// MARK: - Open Header (cardless)

struct SessionDetailOpenHeader: View {
    let session: Session
    let isLeader: Bool
    let showContent: Bool
    let onBack: () -> Void
    @State private var statusPulse = false

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange; case .active: return .green; case .paused: return .yellow
        case .completed: return .cyan; case .dissolved: return .gray
        }
    }

    private var statusLabel: String {
        switch session.status {
        case .lobby: return "En attente"; case .active: return "En cours"; case .paused: return "En pause"
        case .completed: return "Terminée"; case .dissolved: return "Dissoute"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row — back + pills
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                }
                .buttonStyle(BounceButtonStyle())

                Spacer()

                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                        .scaleEffect(statusPulse ? 1.5 : 1.0)
                        .shadow(color: statusColor.opacity(statusPulse ? 0.5 : 0), radius: 4)
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(0.8)
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(Capsule().fill(statusColor.opacity(0.1)))

                if isLeader {
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill").font(.system(size: 9))
                        Text("LEADER").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6)
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(Color.yellow.opacity(0.1)))
                }
            }

            // Title
            Text(session.title)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2).minimumScaleFactor(0.7)

            if !session.description.isEmpty {
                Text(session.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }

            // Meta inline
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill").font(.system(size: 11))
                    Text("\(session.memberIds.count)").font(.system(size: 13, weight: .bold, design: .rounded))
                }.foregroundColor(.white.opacity(0.35))

                HStack(spacing: 5) {
                    Image(systemName: "key.fill").font(.system(size: 10))
                    Text(session.inviteCode).font(.system(size: 13, weight: .bold, design: .monospaced))
                }.foregroundColor(.white.opacity(0.35))
            }

            // Thin gradient separator
            Rectangle()
                .fill(LinearGradient(colors: [statusColor.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .padding(.top, 20).padding(.bottom, 8)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -15)
        .animation(.spring(response: 0.9, dampingFraction: 0.8), value: showContent)
        .onAppear {
            if session.status == .active || session.status == .lobby {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { statusPulse = true }
            }
        }
    }
}


// MARK: - Invite Code Open (no card — individual letter tiles)

struct InviteCodeOpen: View {
    let code: String
    let showContent: Bool
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CODE D'INVITATION")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundColor(.cyan.opacity(0.6))

            Button(action: {
                UIPasteboard.general.string = code
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { copied = true }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copied = false } }
            }) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(Array(code.enumerated()), id: \.offset) { index, char in
                            Text(String(char))
                                .font(.system(size: 36, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                                )
                                .scaleEffect(showContent ? 1 : 0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.05 + 0.2), value: showContent)
                        }
                    }
                    Spacer()
                    ZStack {
                        Image(systemName: "doc.on.doc").opacity(copied ? 0 : 1)
                        Image(systemName: "checkmark").foregroundColor(.green).opacity(copied ? 1 : 0).scaleEffect(copied ? 1 : 0.3)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                }
            }

            if copied {
                Text("Copié dans le presse-papier")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.green.opacity(0.7))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}


// MARK: - App Selection Open (no card — tokens laid out freely)

struct AppSelectionOpen: View {
    let selectedApps: FamilyActivitySelection
    let selectedCount: Int
    let showContent: Bool
    let onSelect: () -> Void
    let onReady: () -> Void
    @State private var readyPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("APPS À BLOQUER")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundColor(.purple.opacity(0.6))

            if selectedCount == 0 {
                Button(action: onSelect) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                                .foregroundColor(.white.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Choisir les apps")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Sélectionne les apps à bloquer pendant la session")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Spacer()
                    }
                }
                .buttonStyle(BounceButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Button(action: onSelect) {
                        HStack(spacing: 0) {
                            AppTokensFlow(selectedApps: selectedApps, maxToShow: 12)
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.25))
                                Text("Modifier").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.25))
                            }
                        }
                    }
                    .buttonStyle(BounceButtonStyle())

                    Button(action: onReady) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .scaleEffect(readyPulse ? 1.12 : 1.0)
                            Text("Je suis Prêt")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [.green, Color(red: 0.2, green: 0.8, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: .green.opacity(0.3), radius: 16, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(BounceButtonStyle())
                    .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { readyPulse = true } }
                }
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.15), value: showContent)
    }
}


// MARK: - App Tokens Flow (wrapping row of app icons — no container)

struct AppTokensFlow: View {
    let selectedApps: FamilyActivitySelection
    let maxToShow: Int

    var body: some View {
        let appCount = selectedApps.applicationTokens.count
        let catCount = selectedApps.categoryTokens.count
        let total = appCount + catCount
        let showCount = min(total, maxToShow)
        let overflow = total - showCount

        HStack(spacing: -6) {
            ForEach(0..<min(appCount, showCount), id: \.self) { index in
                let token = Array(selectedApps.applicationTokens)[index]
                Label(token).labelStyle(.iconOnly).font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.2), lineWidth: 1))
            }

            let remainingSlots = max(0, showCount - appCount)
            ForEach(0..<min(catCount, remainingSlots), id: \.self) { index in
                let token = Array(selectedApps.categoryTokens)[index]
                Label(token).labelStyle(.iconOnly).font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            }
        }
    }
}


// MARK: - Blocked Apps Open (active session — floating tokens, no card)

struct BlockedAppsOpen: View {
    let selectedApps: FamilyActivitySelection
    let showContent: Bool
    @State private var shieldPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.purple.opacity(0.7))
                    .scaleEffect(shieldPulse ? 1.1 : 1.0)

                Text("BLOQUÉES")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.5).foregroundColor(.purple.opacity(0.5))

                let total = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
                Text("\(total)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.purple.opacity(0.12)))
            }

            AppTokensFlow(selectedApps: selectedApps, maxToShow: 10)
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 15)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.15), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { shieldPulse = true } }
    }
}


// MARK: - Members Avatar Strip (horizontal scroll — no cards)

struct MembersAvatarStrip: View {
    let members: [SessionMember]
    let showContent: Bool

    private let avatarColors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.7), Color(red: 1.0, green: 0.5, blue: 0.4),
        Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("MEMBRES").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.5).foregroundColor(.white.opacity(0.35))
                Text("\(members.count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.cyan.opacity(0.7))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        MemberAvatarOpen(member: member, color: avatarColors[index % avatarColors.count], index: index)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

struct MemberAvatarOpen: View {
    let member: SessionMember
    let color: Color
    let index: Int
    @State private var appeared = false

    private var statusColor: Color {
        switch member.status {
        case .joined: return .gray; case .ready: return .green
        case .active: return .green; case .paused: return .orange; case .left: return .red
        }
    }

    private var statusIcon: String {
        switch member.status {
        case .joined: return "circle"; case .ready: return "checkmark"
        case .active: return "bolt.fill"; case .paused: return "pause.fill"; case .left: return "xmark"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(String(member.username.prefix(1)).uppercased())
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)

                ZStack {
                    Circle().fill(statusColor).frame(width: 16, height: 16)
                    Image(systemName: statusIcon).font(.system(size: 7, weight: .black)).foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color(red: 0.06, green: 0.06, blue: 0.08), lineWidth: 2.5))
                .offset(x: 2, y: 2)
            }

            Text(member.username)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1).frame(maxWidth: 60)

            if member.role == .leader {
                Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(.yellow)
            } else if member.hasSelectedApps {
                Text("\(member.selectedAppsCount) apps")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .scaleEffect(appeared ? 1 : 0).opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(Double(index) * 0.06)) { appeared = true }
        }
    }
}


// MARK: - Live Indicator Open (just text + dot, no card)

struct LiveIndicatorOpen: View {
    let memberCount: Int
    let showContent: Bool
    @State private var livePulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 28, height: 28)
                    .scaleEffect(livePulse ? 1.6 : 1.0).opacity(livePulse ? 0 : 0.5)
                Circle().fill(Color.green).frame(width: 10, height: 10).shadow(color: .green.opacity(0.5), radius: 4)
            }
            Text("Session en cours").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.8))
            Text("·").foregroundColor(.white.opacity(0.2))
            Text("\(memberCount) en focus").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.green.opacity(0.7))
        }
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { livePulse = true } }
    }
}


// MARK: - Paused Indicator Open

struct PausedIndicatorOpen: View {
    let pausedBy: String?
    let members: [SessionMember]
    let showContent: Bool
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.08)).frame(width: 72, height: 72).scaleEffect(breathe ? 1.15 : 1.0)
                Image(systemName: "pause.circle.fill").font(.system(size: 40, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text("Session en pause").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
            if let pausedBy = pausedBy {
                let name = members.first(where: { $0.id == pausedBy })?.username ?? "Leader"
                Text("par \(name)").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { breathe = true } }
    }
}


// MARK: - Pause Requests Open (minimal list, no card wrapper)

struct PauseRequestsOpen: View {
    let requests: [PauseRequest]
    let onAccept: (PauseRequest) -> Void
    let onDecline: (PauseRequest) -> Void
    @State private var alertPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.orange).scaleEffect(alertPulse ? 1.15 : 1.0)
                Text("DEMANDES DE PAUSE").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.2).foregroundColor(.orange.opacity(0.6))
                Text("\(requests.count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.orange)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color.orange.opacity(0.12)))
            }

            ForEach(requests) { request in
                HStack(spacing: 12) {
                    Circle().fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 36, height: 36)
                        .overlay(Text(String(request.requesterUsername.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.requesterUsername).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                        if let reason = request.reason, !reason.isEmpty {
                            Text("« \(reason) »").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.4)).italic().lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { onAccept(request) }) {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                .frame(width: 34, height: 34).background(Circle().fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)))
                        }.buttonStyle(BounceButtonStyle())
                        Button(action: { onDecline(request) }) {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.5))
                                .frame(width: 34, height: 34).background(Circle().fill(Color.white.opacity(0.06)))
                        }.buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.vertical, 6)
            }

            Rectangle().fill(Color.orange.opacity(0.15)).frame(height: 1)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { alertPulse = true } }
    }
}


// MARK: - Leader Lobby Controls

struct LeaderLobbyControls: View {
    let readyCount: Int; let totalCount: Int; let showContent: Bool
    let onStart: () -> Void; let onDissolve: () -> Void
    @State private var startGlow = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(readyCount)/\(totalCount) prêts").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(Int(totalCount > 0 ? Double(readyCount) / Double(totalCount) * 100 : 0))%").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.green.opacity(0.7))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: totalCount > 0 ? geo.size.width * CGFloat(readyCount) / CGFloat(totalCount) : 0, height: 5)
                            .animation(.spring(response: 0.6), value: readyCount)
                    }
                }.frame(height: 5)
            }

            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold))
                    Text("Démarrer").font(.system(size: 18, weight: .bold, design: .rounded))
                }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [.green, Color(red: 0.2, green: 0.75, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .green.opacity(startGlow ? 0.5 : 0.15), radius: startGlow ? 20 : 8, x: 0, y: 6)
                )
            }.buttonStyle(BounceButtonStyle())

            Button(action: onDissolve) {
                Text("Dissoudre la session").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.red.opacity(0.5))
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { startGlow = true } }
    }
}


// MARK: - Leader Active Controls

struct LeaderActiveControls: View {
    let onPause: () -> Void; let onStop: () -> Void; let onDissolve: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPause) {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.fill").font(.system(size: 15, weight: .bold))
                        Text("Pause").font(.system(size: 15, weight: .bold, design: .rounded))
                    }.foregroundColor(.orange).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                }.buttonStyle(BounceButtonStyle())

                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill").font(.system(size: 15, weight: .bold))
                        Text("Arrêter").font(.system(size: 15, weight: .bold, design: .rounded))
                    }.foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
                }.buttonStyle(BounceButtonStyle())
            }
            Button(action: onDissolve) { Text("Dissoudre").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.25)) }
        }
    }
}


// MARK: - Member Active Controls

struct MemberActiveControls: View {
    let onRequestPause: () -> Void; let onLeave: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRequestPause) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 15, weight: .bold))
                    Text("Pause").font(.system(size: 14, weight: .bold, design: .rounded))
                }.foregroundColor(.orange).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
            }.buttonStyle(BounceButtonStyle())

            Button(action: onLeave) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 15, weight: .bold))
                    Text("Quitter").font(.system(size: 14, weight: .bold, design: .rounded))
                }.foregroundColor(.red.opacity(0.7)).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.15), lineWidth: 1))
            }.buttonStyle(BounceButtonStyle())
        }
    }
}


// MARK: - Leader Paused Controls

struct LeaderPausedControls: View {
    let onResume: () -> Void; let onStop: () -> Void
    @State private var resumeGlow = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onResume) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold))
                    Text("Reprendre").font(.system(size: 17, weight: .bold, design: .rounded))
                }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [.green, Color(red: 0.2, green: 0.8, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .green.opacity(resumeGlow ? 0.5 : 0.15), radius: resumeGlow ? 18 : 6, x: 0, y: 5)
                )
            }.buttonStyle(BounceButtonStyle())

            Button(action: onStop) {
                Text("Arrêter la session").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.red.opacity(0.5))
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { resumeGlow = true } }
    }
}


// MARK: - Chat Section

struct ChatSection: View {
    let messages: [SessionMessage]; @Binding var messageText: String
    let showContent: Bool; let onSend: () -> Void; let members: [SessionMember]
    @State private var showMentionPicker = false; @State private var mentionSearchText = ""
    @FocusState private var isInputFocused: Bool

    var filteredMentionMembers: [SessionMember] {
        mentionSearchText.isEmpty ? members : members.filter { $0.username.lowercased().contains(mentionSearchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.25))
                Text("CHAT").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.5).foregroundColor(.white.opacity(0.3))
                if !messages.isEmpty {
                    Text("\(messages.count)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.cyan.opacity(0.6))
                }
            }

            if messages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 16, weight: .light)).foregroundColor(.white.opacity(0.12))
                    Text("Aucun message").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.2))
                }.padding(.vertical, 12)
            } else {
                VStack(spacing: 4) { ForEach(messages.suffix(12)) { message in MessageRowOpen(message: message) } }
            }

            if showMentionPicker && !filteredMentionMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(filteredMentionMembers) { m in MentionChip(member: m) { insertMention(m.username) } } }
                }.frame(height: 36).transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { showMentionPicker.toggle() } }) {
                        Image(systemName: "at").font(.system(size: 15, weight: .bold))
                            .foregroundColor(showMentionPicker ? .cyan : .white.opacity(0.3)).frame(width: 30, height: 30)
                    }
                    TextField("Message...", text: $messageText).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                        .focused($isInputFocused)
                        .onChange(of: messageText) { _, v in checkForMentionTrigger(v) }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isInputFocused ? Color.cyan.opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1))

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                        .foregroundStyle(messageText.isEmpty ? LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                }.disabled(messageText.isEmpty).buttonStyle(BounceButtonStyle())
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: showContent)
    }

    private func checkForMentionTrigger(_ text: String) {
        if text.hasSuffix("@") { withAnimation(.spring(response: 0.3)) { showMentionPicker = true }; mentionSearchText = "" }
        else if let idx = text.lastIndex(of: "@") {
            let after = String(text[text.index(after: idx)...])
            if !after.contains(" ") { withAnimation(.spring(response: 0.3)) { showMentionPicker = true }; mentionSearchText = after }
        } else { withAnimation(.spring(response: 0.3)) { showMentionPicker = false } }
    }

    private func insertMention(_ username: String) {
        if let idx = messageText.lastIndex(of: "@") { messageText = String(messageText[..<idx]) + "@\(username) " }
        else { messageText += "@\(username) " }
        withAnimation(.spring(response: 0.3)) { showMentionPicker = false }; mentionSearchText = ""; isInputFocused = true
    }
}

struct MentionChip: View {
    let member: SessionMember; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle().fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 18, height: 18)
                    .overlay(Text(String(member.username.prefix(1)).uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.white))
                Text("@\(member.username)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.8))
            }.padding(.horizontal, 9).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.1)))
        }.buttonStyle(BounceButtonStyle())
    }
}

struct MessageRowOpen: View {
    let message: SessionMessage
    private var isSystem: Bool { message.messageType == .systemAlert }
    @State private var appeared = false

    var body: some View {
        Group {
            if isSystem {
                Text(message.content).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.3)).italic().frame(maxWidth: .infinity).padding(.vertical, 6)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 24, height: 24)
                        .overlay(Text(String(message.username.prefix(1)).uppercased()).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.username).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan.opacity(0.7))
                        Text(message.content).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }.padding(.vertical, 6)
            }
        }
        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 6)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appeared = true } }
    }
}


// MARK: - Completed Content

struct CompletedContent: View {
    let session: Session; let showContent: Bool
    @State private var confetti = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().fill(Color.green.opacity(0.06)).frame(width: 110, height: 110).scaleEffect(confetti ? 1.1 : 1.0)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .scaleEffect(confetti ? 1.0 : 0.7)
            }
            Text("Session Terminée").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.white)
            Text("Félicitations à tous").font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.4))

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(session.memberIds.count)").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("membres").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.35))
                }
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 36)
                VStack(spacing: 4) {
                    Text("—").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("durée").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 48).opacity(showContent ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.3)) { confetti = true } }
    }
}


// MARK: - Dissolved Content

struct DissolvedContent: View {
    let session: Session; let showContent: Bool
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 52, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Session Dissoute").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.6))
            Text("Fermée par le leader").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.3))
        }.frame(maxWidth: .infinity).padding(.vertical, 48).opacity(showContent ? 1 : 0)
    }
}


// MARK: - Pause Request Sheet

struct PauseRequestSheet: View {
    @Binding var reason: String; let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var iconBreathe = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea()
                VStack(spacing: 28) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.08)).frame(width: 90, height: 90).scaleEffect(iconBreathe ? 1.1 : 1.0)
                        Image(systemName: "hand.raised.fill").font(.system(size: 40, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    VStack(spacing: 8) {
                        Text("Demander une Pause").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text("Le leader devra accepter").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.45))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RAISON (OPTIONNEL)").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.0).foregroundColor(.white.opacity(0.35))
                        TextField("Ex: Besoin d'une pause", text: $reason).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                            .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    Button(action: onSubmit) {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill").font(.system(size: 16, weight: .bold))
                            Text("Envoyer").font(.system(size: 17, weight: .bold, design: .rounded))
                        }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.orange, Color(red: 1.0, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .orange.opacity(0.3), radius: 14, x: 0, y: 6))
                    }.buttonStyle(BounceButtonStyle())
                    Spacer()
                }.padding(.horizontal, 24).padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.white.opacity(0.3)) }
                }
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { iconBreathe = true } }
    }
}


// MARK: - Preview

#Preview {
    SessionDetailView(session: Session(
        id: "preview", title: "Focus Marathon",
        description: "Session de concentration intense",
        leaderId: "user1", leaderUsername: "Alice",
        visibility: .publicSession, inviteCode: "ZEN42X",
        maxParticipants: 10, status: .lobby,
        createdAt: .init(), startedAt: nil, endedAt: nil,
        pausedAt: nil, pausedBy: nil,
        memberIds: ["user1", "user2", "user3"], suggestedAppsCount: 3
    ))
    .environmentObject(ZenloopManager.shared)
}