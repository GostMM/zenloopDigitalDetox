//
//  SocialTab.swift
//  zenloop
//
//  V3: Layout libre, organique — sessions en carousel horizontal,
//  éléments compacts qui respirent, plus d'énergie et de vie
//

import SwiftUI
import FamilyControls

// MARK: - Main Social Tab

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
            
            FloatingParticlesOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // — Header compact —
                SocialMinimalHeader(
                    showContent: showContent,
                    unreadCount: notificationManager.unreadCount,
                    sessionStatus: getSessionStatus(),
                    isPremium: PurchaseManager.shared.isPremium,
                    onNotificationTap: { showNotifications = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // — Top band : Online + Quick Actions fusionnés —
                        TopSocialBand(
                            showContent: showContent,
                            onCreateSession: { showCreateSession = true },
                            onJoinSession: { showJoinSession = true }
                        )
                        .padding(.top, 20)

                        // — Session active (carte hero — INTACT) —
                        if let currentSession = sessionManager.currentSession {
                            ActiveSessionCard(session: currentSession, showContent: showContent)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }

                        // — Demandes de pause (leader only) —
                        if let currentSession = sessionManager.currentSession,
                           let currentUserId = sessionManager.currentUser?.id,
                           currentSession.leaderId == currentUserId,
                           !sessionManager.pendingPauseRequests.isEmpty {
                            OpenPauseRequestsSection(
                                requests: sessionManager.pendingPauseRequests,
                                session: currentSession,
                                showContent: showContent
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        }

                        // — Invitations (compact inline) —
                        if !sessionManager.pendingInvitations.isEmpty {
                            InvitationsCarousel(
                                invitations: sessionManager.pendingInvitations,
                                showContent: showContent
                            )
                            .padding(.top, 28)
                        }

                        // — Mes Sessions (carousel horizontal) —
                        if !sessionManager.mySessions.isEmpty {
                            SessionCarousel(
                                title: "Mes Sessions",
                                icon: "rectangle.stack.fill",
                                sessions: sessionManager.mySessions,
                                accentColor: .cyan,
                                showContent: showContent
                            )
                            .padding(.top, 28)
                        }

                        // — Sessions Publiques (carousel horizontal) —
                        SessionCarousel(
                            title: "Découvrir",
                            icon: "globe",
                            sessions: sessionManager.publicSessions,
                            accentColor: Color(red: 0.6, green: 0.4, blue: 1.0),
                            showContent: showContent,
                            emptyMessage: "Crée la première session publique !"
                        )
                        .padding(.top, 28)

                        Spacer(minLength: 120)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                showContent = true
            }
            if let userId = sessionManager.currentUser?.id {
                notificationManager.startListening(userId: userId)
                // ✅ FIX: Force reload sessions on first appearance
                Task {
                    await sessionManager.loadUserSessions()
                }
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

    private func getSessionStatus() -> SocialSessionStatus {
        if let current = sessionManager.currentSession {
            switch current.status {
            case .active: return .active
            case .paused: return .paused
            case .lobby: return .lobby
            default: return .idle
            }
        }
        return .idle
    }
}


// MARK: - Social Session Status

enum SocialSessionStatus {
    case idle, lobby, active, paused

    var color: Color {
        switch self {
        case .idle: return .cyan
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .yellow
        }
    }

    var icon: String {
        switch self {
        case .idle: return "sparkles"
        case .lobby: return "hourglass"
        case .active: return "bolt.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var text: String {
        switch self {
        case .idle: return "Prêt à focus ensemble"
        case .lobby: return "Session en attente"
        case .active: return "Session active"
        case .paused: return "Session en pause"
        }
    }
}


// MARK: - Top Social Band (Online + Actions fusionnés en une seule bande)

struct TopSocialBand: View {
    let showContent: Bool
    let onCreateSession: () -> Void
    let onJoinSession: () -> Void
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                // Avatars en ligne (gauche)
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(breathe ? 1.3 : 0.8)
                        .padding(.trailing, 10)

                    let onlineMembers = getOnlineMembers()

                    if onlineMembers.isEmpty {
                        HStack(spacing: -6) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                    )
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.1))
                                    )
                            }
                        }

                        Text("Invite !")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.leading, 10)
                    } else {
                        HStack(spacing: -8) {
                            ForEach(Array(onlineMembers.prefix(6).enumerated()), id: \.offset) { index, member in
                                CompactOnlineAvatar(username: member, index: index)
                            }

                            if onlineMembers.count > 6 {
                                Text("+\(onlineMembers.count - 6)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2))
                                    )
                            }
                        }
                    }
                }

                Spacer(minLength: 12)

                // Boutons action compacts (droite)
                HStack(spacing: 10) {
                    Button(action: onCreateSession) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.25, green: 0.4, blue: 0.95)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.35), radius: 12, x: 0, y: 4)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(BounceButtonStyle())

                    Button(action: onJoinSession) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.6, green: 0.35, blue: 1.0), Color(red: 0.45, green: 0.2, blue: 0.9)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .shadow(color: Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.35), radius: 12, x: 0, y: 4)

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 25)
        .animation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.15), value: showContent)
        .onAppear { breathe = true }
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)
    }

    private func getOnlineMembers() -> [String] {
        guard let session = sessionManager.currentSession else { return [] }
        return session.memberIds.prefix(8).enumerated().map { index, _ in
            "Membre \(index + 1)"
        }
    }
}

struct CompactOnlineAvatar: View {
    let username: String
    let index: Int
    @State private var appeared = false

    private let gradients: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.3, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.3, green: 0.8, blue: 0.7), Color(red: 0.2, green: 0.6, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.4), Color(red: 0.9, green: 0.3, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(gradients[index % gradients.count])
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(username.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .overlay(Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2.5))

            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2))
                .offset(x: 1, y: 1)
        }
        .scaleEffect(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.06 + 0.3)) {
                appeared = true
            }
        }
    }
}


// MARK: - Session Carousel (horizontal scroll — vivant, avec énergie)

struct SessionCarousel: View {
    let title: String
    let icon: String
    let sessions: [Session]
    let accentColor: Color
    let showContent: Bool
    var emptyMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header avec accent couleur
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3, height: 18)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor.opacity(0.8))

                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                if !sessions.isEmpty {
                    Text("\(sessions.count)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            if sessions.isEmpty {
                CarouselEmptyState(message: emptyMessage ?? "Rien ici pour l'instant", accentColor: accentColor)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            SessionCarouselCard(
                                session: session,
                                accentColor: accentColor,
                                index: index,
                                showContent: showContent
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 25)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.35), value: showContent)
    }
}

struct SessionCarouselCard: View {
    let session: Session
    let accentColor: Color
    let index: Int
    let showContent: Bool
    @State private var appeared = false
    @ObservedObject private var sessionManager = SessionManager.shared

    private var isMember: Bool {
        guard let userId = sessionManager.currentUser?.id else { return false }
        return session.memberIds.contains(userId)
    }

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange; case .active: return .green; case .paused: return .yellow
        case .completed: return .cyan; case .dissolved: return .gray
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .lobby: return "hourglass"; case .active: return "bolt.fill"; case .paused: return "pause.fill"
        case .completed: return "checkmark.circle.fill"; case .dissolved: return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "En attente"; case .active: return "En cours"; case .paused: return "En pause"
        case .completed: return "Terminée"; case .dissolved: return "Dissoute"
        }
    }

    private var cardGradient: LinearGradient {
        let palettes: [(Color, Color)] = [
            (Color(red: 0.15, green: 0.18, blue: 0.28), Color(red: 0.08, green: 0.10, blue: 0.18)),
            (Color(red: 0.18, green: 0.14, blue: 0.26), Color(red: 0.10, green: 0.08, blue: 0.16)),
            (Color(red: 0.12, green: 0.20, blue: 0.22), Color(red: 0.06, green: 0.12, blue: 0.14)),
            (Color(red: 0.20, green: 0.14, blue: 0.14), Color(red: 0.12, green: 0.08, blue: 0.08)),
            (Color(red: 0.14, green: 0.18, blue: 0.14), Color(red: 0.08, green: 0.10, blue: 0.08)),
        ]
        let p = palettes[index % palettes.count]
        return LinearGradient(colors: [p.0, p.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        // 🔥 FIX: Si membre → direct vers SessionDetailView, sinon → SessionPreviewView
        Group {
            if isMember {
                NavigationLink(destination: SessionDetailView(session: session)) {
                    cardContent
                }
            } else {
                NavigationLink(destination: SessionPreviewView(session: session)) {
                    cardContent
                }
            }
        }
        .buttonStyle(BounceButtonStyle())
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.07 + 0.1)) {
                appeared = true
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top : status pill + membres count
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon).font(.system(size: 8, weight: .black))
                    Text(statusText).font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(0.5)
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.15)))

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill").font(.system(size: 9))
                    Text("\(session.memberIds.count)").font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.35))
            }
            .padding(.bottom, 12)

            // Titre
            Text(session.title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            // Description
            if !session.description.isEmpty {
                Text(session.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(2)
                    .padding(.bottom, 10)
            }

            Spacer(minLength: 0)

            // Bottom : avatars + code
            HStack(spacing: 0) {
                HStack(spacing: -8) {
                    ForEach(0..<min(session.memberIds.count, 4), id: \.self) { i in
                        CarouselMiniAvatar(index: i)
                    }

                    if session.memberIds.count > 4 {
                        Text("+\(session.memberIds.count - 4)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(Color.white.opacity(0.1))
                                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1.5))
                            )
                    }
                }

                Spacer()

                Text(session.inviteCode)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }

            // Barre d'énergie colorée
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(colors: [statusColor, statusColor.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 3)
                .padding(.top, 12)
        }
        .padding(16)
        .frame(width: 220, height: 200)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [statusColor.opacity(0.2), Color.white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: statusColor.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}

struct CarouselMiniAvatar: View {
    let index: Int
    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.7), Color(red: 1.0, green: 0.5, blue: 0.4),
        Color(red: 1.0, green: 0.7, blue: 0.3),
    ]

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [colors[index % colors.count], colors[index % colors.count].opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            )
            .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1.5))
    }
}

struct CarouselEmptyState: View {
    let message: String
    let accentColor: Color
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.06))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accentColor.opacity(0.4))
                    .scaleEffect(shimmer ? 1.15 : 0.9)
            }

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.3))

            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }
}


// MARK: - Invitations Carousel (compact, horizontal)

struct InvitationsCarousel: View {
    let invitations: [SessionInvitation]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: 3, height: 18)

                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple.opacity(0.8))

                Text("Invitations")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                ZStack {
                    Circle().fill(Color.purple).frame(width: 22, height: 22)
                        .shadow(color: .purple.opacity(0.4), radius: 6, x: 0, y: 2)
                    Text("\(invitations.count)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(invitations.enumerated()), id: \.element.id) { index, invitation in
                        InvitationCompactCard(invitation: invitation, index: index, showContent: showContent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 25)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

struct InvitationCompactCard: View {
    let invitation: SessionInvitation
    let index: Int
    let showContent: Bool
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header : avatar + from
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Text(String(invitation.fromUsername.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.fromUsername)
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.8))
                    Text("t'invite")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.35))
                }
            }

            Text(invitation.sessionTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white).lineLimit(2)

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: 8) {
                Button(action: { /* accept */ }) {
                    Text("Rejoindre")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(
                            Capsule().fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 2)
                        )
                }.buttonStyle(BounceButtonStyle())

                Button(action: { /* decline */ }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }.buttonStyle(BounceButtonStyle())
            }
        }
        .padding(14)
        .frame(width: 200, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.16, green: 0.12, blue: 0.24), Color(red: 0.08, green: 0.06, blue: 0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: .purple.opacity(0.1), radius: 10, x: 0, y: 5)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.07 + 0.1)) {
                appeared = true
            }
        }
    }
}


// MARK: - Floating Particles

struct FloatingParticlesOverlay: View {
    @State private var particles: [SocialParticle] = (0..<12).map { _ in SocialParticle() }
    @State private var animate = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let x = particle.x * size.width
                    let progress = animate ? 1.0 : 0.0
                    let y = particle.startY * size.height + (progress * particle.speed * size.height * 0.3)
                    let wrappedY = y.truncatingRemainder(dividingBy: size.height)
                    let alpha = particle.opacity * (1.0 - abs(wrappedY / size.height - 0.5) * 2)
                    let rect = CGRect(x: x - particle.size / 2, y: wrappedY - particle.size / 2, width: particle.size, height: particle.size)
                    context.opacity = alpha * 0.4
                    context.fill(Circle().path(in: rect), with: .color(particle.color))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { animate = true }
        }
    }
}

struct SocialParticle {
    let x: CGFloat = .random(in: 0...1)
    let startY: CGFloat = .random(in: 0...1)
    let size: CGFloat = .random(in: 3...8)
    let speed: CGFloat = .random(in: 0.5...2.0)
    let opacity: CGFloat = .random(in: 0.2...0.6)
    let color: Color = [
        Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0), Color.cyan, Color.mint
    ].randomElement()!
}


// MARK: - Social Minimal Header

struct SocialMinimalHeader: View {
    let showContent: Bool
    let unreadCount: Int
    let sessionStatus: SocialSessionStatus
    let isPremium: Bool
    let onNotificationTap: () -> Void
    @State private var statusPulse = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentGreeting)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    .lineLimit(1).minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Image(systemName: sessionStatus.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sessionStatus.color)
                        .scaleEffect(statusPulse ? 1.2 : 1.0)
                    Text(sessionStatus.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sessionStatus.color.opacity(0.9))
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    Capsule().fill(sessionStatus.color.opacity(0.12))
                        .overlay(Capsule().stroke(sessionStatus.color.opacity(0.2), lineWidth: 1))
                )
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -15)

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                if isPremium { ProBadge() }
                NotificationBell(unreadCount: unreadCount, onTap: onNotificationTap)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -10)
        }
        .frame(minHeight: 50)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear {
            if sessionStatus == .active {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { statusPulse = true }
            }
        }
    }

    private var currentGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "greeting_morning")
        case 12..<17: return String(localized: "greeting_afternoon")
        case 17..<21: return String(localized: "greeting_evening")
        default: return String(localized: "greeting_night")
        }
    }
}

struct NotificationBell: View {
    let unreadCount: Int
    let onTap: () -> Void
    @State private var shake = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .rotationEffect(.degrees(shake ? 15 : 0))

                if unreadCount > 0 {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 20, height: 20)
                            .shadow(color: .red.opacity(0.6), radius: 6, x: 0, y: 2)
                        Text("\(min(unreadCount, 99))")
                            .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    .offset(x: 6, y: -6).transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onChange(of: unreadCount) { oldValue, newValue in
            if newValue > oldValue {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 5)) { shake = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation(.spring()) { shake = false } }
            }
        }
    }
}


// MARK: - Active Session Card (hero — INTACT)

struct ActiveSessionCard: View {
    let session: Session
    let showContent: Bool
    @State private var glowPhase: CGFloat = 0
    @State private var memberAvatarsVisible = false

    private var statusColor: Color {
        switch session.status {
        case .active: return .green; case .paused: return .orange
        default: return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }
    private var statusLabel: String {
        switch session.status {
        case .active: return "EN COURS"; case .paused: return "EN PAUSE"; default: return "SESSION"
        }
    }
    private var statusIcon: String {
        switch session.status {
        case .active: return "bolt.fill"; case .paused: return "pause.fill"; default: return "circle.fill"
        }
    }

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon).font(.system(size: 10, weight: .bold))
                        Text(statusLabel).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.5)
                    }
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(statusColor.opacity(0.15)))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 22)).foregroundColor(.white.opacity(0.3))
                }

                Text(session.title).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(2)

                if !session.description.isEmpty {
                    Text(session.description).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(2)
                }

                if session.suggestedAppsCount > 0 { ActiveSessionAppsRow(session: session) }

                HStack(spacing: 0) {
                    HStack(spacing: -10) {
                        ForEach(0..<min(session.memberIds.count, 5), id: \.self) { index in
                            MiniAvatar(index: index)
                                .scaleEffect(memberAvatarsVisible ? 1 : 0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.06), value: memberAvatarsVisible)
                        }
                        if session.memberIds.count > 5 {
                            Text("+\(session.memberIds.count - 5)")
                                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.1)).overlay(Circle().stroke(Color(red: 0.12, green: 0.22, blue: 0.12), lineWidth: 2)))
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill").font(.system(size: 11, weight: .semibold))
                        Text(session.inviteCode).font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(
                        LinearGradient(colors: [statusColor.opacity(0.12), Color(red: 0.08, green: 0.08, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    RoundedRectangle(cornerRadius: 24).stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [statusColor.opacity(0.5), statusColor.opacity(0.1), statusColor.opacity(0.3), statusColor.opacity(0.0), statusColor.opacity(0.5)]),
                            center: .center, startAngle: .degrees(glowPhase), endAngle: .degrees(glowPhase + 360)
                        ), lineWidth: 2
                    )
                }
            )
            .shadow(color: statusColor.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
        .onAppear {
            memberAvatarsVisible = true
            if session.status == .active {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { glowPhase = 360 }
            }
        }
    }
}

struct MiniAvatar: View {
    let index: Int
    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.7), Color(red: 1.0, green: 0.5, blue: 0.4), Color(red: 1.0, green: 0.7, blue: 0.3),
    ]
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [colors[index % colors.count], colors[index % colors.count].opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
            .overlay(Image(systemName: "person.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.9)))
            .overlay(Circle().stroke(Color(red: 0.12, green: 0.22, blue: 0.12), lineWidth: 2))
    }
}


// MARK: - Open Pause Requests Section

struct OpenPauseRequestsSection: View {
    let requests: [PauseRequest]
    let session: Session
    let showContent: Bool
    @State private var pulseAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle().fill(Color.orange).frame(width: 10, height: 10).scaleEffect(pulseAlert ? 1.4 : 0.9)
                Text("Demandes de Pause").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("\(requests.count)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.orange.opacity(0.12)))
                Spacer()
            }.padding(.horizontal, 4)

            ForEach(requests) { request in
                OpenPauseRequestRow(request: request, sessionId: session.id ?? "")
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAlert = true } }
    }
}

struct OpenPauseRequestRow: View {
    let request: PauseRequest
    let sessionId: String
    @ObservedObject private var sessionManager = SessionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40)
                    Text(String(request.requesterUsername.prefix(1)).uppercased()).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.requesterUsername).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                    if let reason = request.reason, !reason.isEmpty {
                        Text("« \(reason) »").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.45)).italic().lineLimit(2)
                    }
                    Text(timeAgo(from: request.requestedAt.dateValue())).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.3))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { acceptRequest() }) {
                        Text("OK").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)).shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 2))
                    }.buttonStyle(BounceButtonStyle())
                    Button(action: { declineRequest() }) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32).background(Circle().fill(Color.white.opacity(0.06)))
                    }.buttonStyle(BounceButtonStyle())
                }
            }.padding(.vertical, 12)
            Rectangle().fill(LinearGradient(colors: [Color.white.opacity(0.0), Color.orange.opacity(0.1), Color.white.opacity(0.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        }
    }

    private func acceptRequest() {
        Task { try? await sessionManager.respondToPauseRequest(requestId: request.id ?? "", sessionId: sessionId, accept: true) }
    }
    private func declineRequest() {
        Task { try? await sessionManager.respondToPauseRequest(requestId: request.id ?? "", sessionId: sessionId, accept: false) }
    }
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "À l'instant" }
        if interval < 3600 { return "Il y a \(Int(interval / 60))min" }
        return "Il y a \(Int(interval / 3600))h"
    }
}


// MARK: - Bounce Button Style

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


// MARK: - Active Session Apps Row

struct ActiveSessionAppsRow: View {
    let session: Session
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var sessionApps = FamilyActivitySelection()

    var body: some View {
        HStack(spacing: 0) {
            if !sessionApps.applicationTokens.isEmpty || !sessionApps.categoryTokens.isEmpty {
                StackedAppIcons(selectedApps: sessionApps, maxToShow: 6)
            } else if session.suggestedAppsCount > 0 {
                HStack(spacing: -10) {
                    ForEach(0..<min(session.suggestedAppsCount, 4), id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.2)).frame(width: 32, height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.4), lineWidth: 1.5))
                            Image(systemName: getGenericAppIcon(index: index)).font(.system(size: 14, weight: .semibold)).foregroundColor(.purple)
                        }.zIndex(Double(4 - index))
                    }
                    if session.suggestedAppsCount > 4 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [.purple.opacity(0.3), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.5), lineWidth: 1.5))
                            Text("+\(session.suggestedAppsCount - 4)").font(.system(size: 11, weight: .bold)).foregroundColor(.purple)
                        }.zIndex(0)
                    }
                }
            }
            Spacer()
        }
        .onAppear { loadSessionApps() }
    }

    private func loadSessionApps() {
        if let sessionId = session.id,
           let localApps = sessionManager.getLocalApps(sessionId: sessionId),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {
            sessionApps = selection
        }
    }
    private func getGenericAppIcon(index: Int) -> String {
        ["app.fill", "square.stack.3d.up.fill", "app.badge.fill", "square.grid.2x2.fill"][index % 4]
    }
}


// MARK: - Preview

#Preview {
    SocialTab()
        .environmentObject(ZenloopManager.shared)
}