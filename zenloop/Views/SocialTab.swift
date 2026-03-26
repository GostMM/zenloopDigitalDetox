//
//  SocialTab.swift
//  zenloop
//
//  Onglet social pour les sessions de groupe
//  Updated: paused status support in session rows
//

import SwiftUI

struct SocialTab: View {
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var notificationManager = SocialNotificationManager.shared
    @ObservedObject private var deepLinkCoordinator = DeepLinkCoordinator.shared
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var showCreateSession = false
    @State private var showJoinSession = false
    @State private var showNotifications = false
    @State private var showSessionDetail = false
    @State private var inviteCode = ""
    @State private var selectedSessionId: String? = nil

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                SocialLoginView()
            }
        }
    }

    private var authenticatedContent: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                SocialMinimalHeader(
                    showContent: showContent,
                    unreadCount: notificationManager.unreadCount,
                    onNotificationTap: { showNotifications = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 60)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        QuickActionsCard(
                            showContent: showContent,
                            onCreateSession: { showCreateSession = true },
                            onJoinSession: { showJoinSession = true }
                        )
                        .padding(.top, 20)

                        if let currentSession = sessionManager.currentSession {
                            ActiveSessionCard(session: currentSession, showContent: showContent)
                        }

                        // Demandes de pause (leader seulement)
                        if let currentSession = sessionManager.currentSession,
                           let currentUserId = sessionManager.currentUser?.id,
                           currentSession.leaderId == currentUserId,
                           !sessionManager.pendingPauseRequests.isEmpty {
                            LeaderPauseRequestsCard(
                                requests: sessionManager.pendingPauseRequests,
                                session: currentSession,
                                showContent: showContent
                            )
                        }

                        if !sessionManager.mySessions.isEmpty {
                            MySessionsSection(sessions: sessionManager.mySessions, showContent: showContent)
                        }

                        PublicSessionsSection(sessions: sessionManager.publicSessions, showContent: showContent)

                        if !sessionManager.pendingInvitations.isEmpty {
                            InvitationsSection(invitations: sessionManager.pendingInvitations, showContent: showContent)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) { showContent = true }
            if let userId = sessionManager.currentUser?.id {
                notificationManager.startListening(userId: userId)
            }
        }
        .onDisappear {
            notificationManager.stopListening()
        }
        .onChange(of: deepLinkCoordinator.shouldNavigateToSession) { _, shouldNavigate in
            if shouldNavigate, let sessionId = deepLinkCoordinator.pendingSessionId {
                selectedSessionId = sessionId
                showSessionDetail = true
                deepLinkCoordinator.clearNavigation()
            }
        }
        .onChange(of: deepLinkCoordinator.shouldNavigateToNotifications) { _, shouldNavigate in
            if shouldNavigate {
                showNotifications = true
                deepLinkCoordinator.clearNavigation()
            }
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionView().environmentObject(zenloopManager)
        }
        .sheet(isPresented: $showJoinSession) {
            JoinSessionView(inviteCode: $inviteCode)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showSessionDetail) {
            if let sessionId = selectedSessionId,
               let session = findSession(byId: sessionId) {
                SessionDetailView(session: session)
            }
        }
    }

    private func findSession(byId id: String) -> Session? {
        sessionManager.mySessions.first(where: { $0.id == id })
            ?? sessionManager.publicSessions.first(where: { $0.id == id })
            ?? sessionManager.currentSession
    }
}

// MARK: - Social Minimal Header

struct SocialMinimalHeader: View {
    let showContent: Bool
    let unreadCount: Int
    let onNotificationTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sessions")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                Text("Focus ensemble")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }

            Spacer()

            // Cloche de notification
            Button(action: onNotificationTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))

                    if unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                            Text("\(unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
        }
        .padding(.bottom, 10)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}


struct QuickActionsCard: View {
    let showContent: Bool; let onCreateSession: () -> Void; let onJoinSession: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onCreateSession) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.3, green: 0.5, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                        Image(systemName: "plus.circle.fill").font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creer une Session").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        Text("Inviter des amis a focus ensemble").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.12, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            }.buttonStyle(ScaleButtonStyle())

            Button(action: onJoinSession) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                        Image(systemName: "person.2.fill").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rejoindre avec un Code").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        Text("Entrer le code d'invitation").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.12, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            }.buttonStyle(ScaleButtonStyle())
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

struct ActiveSessionCard: View {
    let session: Session; let showContent: Bool
    private var statusColor: Color {
        switch session.status {
        case .active: return .green; case .paused: return .orange; default: return .blue
        }
    }
    private var statusLabel: String {
        switch session.status {
        case .active: return "SESSION ACTIVE"; case .paused: return "SESSION EN PAUSE"; default: return "SESSION"
        }
    }
    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(statusColor).frame(width: 10, height: 10)
                    Text(statusLabel).font(.system(size: 13, weight: .bold)).foregroundColor(statusColor)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                }
                Text(session.title).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text(session.description).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.7)).lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(session.memberIds.count) membres", systemImage: "person.2.fill").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    Label("Code: \(session.inviteCode)", systemImage: "key.fill").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.25, blue: 0.15), Color(red: 0.10, green: 0.20, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(statusColor.opacity(0.3), lineWidth: 2))
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

struct MySessionsSection: View {
    let sessions: [Session]; let showContent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mes Sessions").font(.system(size: 20, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4)
            ForEach(sessions) { session in SessionRow(session: session) }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
}

struct PublicSessionsSection: View {
    let sessions: [Session]; let showContent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions Publiques").font(.system(size: 20, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4)
            if sessions.isEmpty {
                EmptyStateView(icon: "person.3.fill", title: "Aucune session publique", subtitle: "Creez la premiere !")
            } else {
                ForEach(sessions) { session in SessionRow(session: session) }
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.5), value: showContent)
    }
}

struct InvitationsSection: View {
    let invitations: [SessionInvitation]; let showContent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitations").font(.system(size: 20, weight: .bold)).foregroundColor(.white).padding(.horizontal, 4)
            ForEach(invitations) { invitation in InvitationRow(invitation: invitation) }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
}

struct SessionRow: View {
    let session: Session
    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange; case .active: return .green; case .paused: return .yellow
        case .completed: return .blue; case .dissolved: return .gray
        }
    }
    private var statusText: String {
        switch session.status {
        case .lobby: return "En attente"; case .active: return "En cours"; case .paused: return "En pause"
        case .completed: return "Terminee"; case .dissolved: return "Dissoute"
        }
    }
    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            HStack(spacing: 12) {
                Circle().fill(statusColor).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text(statusText).font(.system(size: 13, weight: .medium)).foregroundColor(statusColor)
                        Text("•").foregroundColor(.white.opacity(0.4))
                        Text("\(session.memberIds.count) membres").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.12, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        }.buttonStyle(ScaleButtonStyle())
    }
}

struct InvitationRow: View {
    let invitation: SessionInvitation
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.sessionTitle).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text("De \(invitation.fromUsername)").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(Circle().fill(Color.green))
                }
                Button(action: {}) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(Circle().fill(Color.red))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.12, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

struct EmptyStateView: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48, weight: .light)).foregroundColor(.white.opacity(0.3))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.5))
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct LeaderPauseRequestsCard: View {
    let requests: [PauseRequest]
    let session: Session
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)

                Text("Demandes de Pause")
                    .font(.system(size: 18, weight: .bold))
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
                PauseRequestPreviewRow(request: request, sessionId: session.id ?? "")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.orange.opacity(0.4), lineWidth: 2)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: showContent)
    }
}

struct PauseRequestPreviewRow: View {
    let request: PauseRequest
    let sessionId: String
    @ObservedObject private var sessionManager = SessionManager.shared

    var body: some View {
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
                        .lineLimit(2)
                }

                Text(timeAgo(from: request.requestedAt.dateValue()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { acceptRequest() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.green))
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: { declineRequest() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func acceptRequest() {
        Task {
            try? await sessionManager.respondToPauseRequest(
                requestId: request.id ?? "",
                sessionId: sessionId,
                accept: true
            )
        }
    }

    private func declineRequest() {
        Task {
            try? await sessionManager.respondToPauseRequest(
                requestId: request.id ?? "",
                sessionId: sessionId,
                accept: false
            )
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "À l'instant" }
        if interval < 3600 { return "Il y a \(Int(interval / 60))min" }
        return "Il y a \(Int(interval / 3600))h"
    }
}

#Preview { SocialTab().environmentObject(ZenloopManager.shared) }