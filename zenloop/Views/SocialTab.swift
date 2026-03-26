//
//  SocialTab.swift
//  zenloop
//
//  Onglet social repensé — plus vivant, plus social, plus animé
//  Design: avatars, présence en temps réel, animations fluides, vibe communautaire
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
    @State private var pulsePhase: CGFloat = 0

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
            
            // Particules flottantes d'ambiance sociale
            FloatingParticlesOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
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
                    LazyVStack(spacing: 20) {
                        
                        // — Présence en ligne —
                        OnlineFriendsStrip(showContent: showContent)
                            .padding(.top, 16)
                        
                        // — Actions rapides —
                        QuickActionsCard(
                            showContent: showContent,
                            onCreateSession: { showCreateSession = true },
                            onJoinSession: { showJoinSession = true }
                        )

                        // — Session active (carte hero) —
                        if let currentSession = sessionManager.currentSession {
                            ActiveSessionCard(session: currentSession, showContent: showContent)
                        }

                        // — Demandes de pause (leader only) —
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

                        // — Invitations en attente —
                        if !sessionManager.pendingInvitations.isEmpty {
                            InvitationsSection(
                                invitations: sessionManager.pendingInvitations,
                                showContent: showContent
                            )
                        }

                        // — Mes sessions —
                        if !sessionManager.mySessions.isEmpty {
                            MySessionsSection(
                                sessions: sessionManager.mySessions,
                                showContent: showContent
                            )
                        }

                        // — Sessions publiques —
                        PublicSessionsSection(
                            sessions: sessionManager.publicSessions,
                            showContent: showContent
                        )

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
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


// MARK: - Floating Particles (ambiance sociale)

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
                    
                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: wrappedY - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.opacity = alpha * 0.4
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animate = true
            }
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
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color.cyan,
        Color.mint
    ].randomElement()!
}


// MARK: - Online Friends Strip (bande d'avatars en ligne)

struct OnlineFriendsStrip: View {
    let showContent: Bool
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var breathe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(breathe ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: breathe
                    )
                
                Text("En ligne maintenant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -8) {
                    // Avatars des membres en ligne (stack chevauchant)
                    let onlineMembers = getOnlineMembers()
                    
                    ForEach(Array(onlineMembers.enumerated()), id: \.offset) { index, member in
                        OnlineAvatarBubble(
                            username: member,
                            index: index,
                            isActive: true,
                            showContent: showContent
                        )
                    }
                    
                    if onlineMembers.isEmpty {
                        // État vide — invitation à rejoindre
                        HStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { i in
                                GhostAvatar(index: i, showContent: showContent)
                            }
                            
                            Text("Invite tes amis !")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.15), value: showContent)
        .onAppear { breathe = true }
    }
    
    private func getOnlineMembers() -> [String] {
        // Récupère les noms des membres en session active
        guard let session = sessionManager.currentSession else { return [] }
        return session.memberIds.prefix(8).enumerated().map { index, _ in
            "Membre \(index + 1)"
        }
    }
}

struct OnlineAvatarBubble: View {
    let username: String
    let index: Int
    let isActive: Bool
    let showContent: Bool
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
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(username.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 3)
                )
            
            // Indicateur en ligne
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().stroke(Color(red: 0.08, green: 0.08, blue: 0.1), lineWidth: 2.5)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.0)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.6)
                .delay(Double(index) * 0.08 + 0.3)
            ) {
                appeared = true
            }
        }
    }
}

struct GhostAvatar: View {
    let index: Int
    let showContent: Bool
    @State private var shimmer = false

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 46, height: 46)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(shimmer ? 0.15 : 0.05),
                                Color.white.opacity(shimmer ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.15))
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(index) * 0.3)) {
                    shimmer = true
                }
            }
    }
}


// MARK: - Social Minimal Header (redesigné)

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
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Status pill animé
                HStack(spacing: 6) {
                    Image(systemName: sessionStatus.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sessionStatus.color)
                        .scaleEffect(statusPulse ? 1.2 : 1.0)
                    
                    Text(sessionStatus.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sessionStatus.color.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(sessionStatus.color.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(sessionStatus.color.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -15)

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                // Badge PRO
                if isPremium {
                    ProBadge()
                }

                // Cloche de notification avec animation shake
                NotificationBell(
                    unreadCount: unreadCount,
                    onTap: onNotificationTap
                )
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -10)
        }
        .frame(minHeight: 50)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
        .onAppear {
            if sessionStatus == .active {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    statusPulse = true
                }
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(shake ? 15 : 0))

                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .shadow(color: .red.opacity(0.6), radius: 6, x: 0, y: 2)
                        
                        Text("\(min(unreadCount, 99))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onChange(of: unreadCount) { oldValue, newValue in
            if newValue > oldValue {
                // Shake animation quand nouvelle notif
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 5)) {
                    shake = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring()) { shake = false }
                }
            }
        }
    }
}


// MARK: - Quick Actions Card (redesigné avec plus de pep)

struct QuickActionsCard: View {
    let showContent: Bool
    let onCreateSession: () -> Void
    let onJoinSession: () -> Void
    @State private var hoverCreate = false
    @State private var hoverJoin = false

    var body: some View {
        VStack(spacing: 14) {
            // Bouton Créer
            Button(action: onCreateSession) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.55, blue: 1.0),
                                        Color(red: 0.25, green: 0.45, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.4), radius: 12, x: 0, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(hoverCreate ? 90 : 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Créer une Session")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Invite tes amis à focus ensemble")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .offset(x: hoverCreate ? 4 : 0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.55, blue: 1.0).opacity(0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3)) { hoverCreate = pressing }
            }, perform: {})

            // Bouton Rejoindre
            Button(action: onJoinSession) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.35, blue: 1.0),
                                        Color(red: 0.5, green: 0.25, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.4), radius: 12, x: 0, y: 4)
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rejoindre avec un Code")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Entre le code d'invitation")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .offset(x: hoverJoin ? 4 : 0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.35, blue: 1.0).opacity(0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3)) { hoverJoin = pressing }
            }, perform: {})
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.2), value: showContent)
    }
}


// MARK: - Active Session Card (hero card animée)

struct ActiveSessionCard: View {
    let session: Session
    let showContent: Bool
    @State private var glowPhase: CGFloat = 0
    @State private var memberAvatarsVisible = false

    private var statusColor: Color {
        switch session.status {
        case .active: return .green
        case .paused: return .orange
        default: return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }
    
    private var statusLabel: String {
        switch session.status {
        case .active: return "EN COURS"
        case .paused: return "EN PAUSE"
        default: return "SESSION"
        }
    }
    
    private var statusIcon: String {
        switch session.status {
        case .active: return "bolt.fill"
        case .paused: return "pause.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            VStack(alignment: .leading, spacing: 16) {
                // Top bar — status + chevron
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text(statusLabel)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(statusColor.opacity(0.15))
                    )
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.3))
                }

                // Titre
                Text(session.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Description
                if !session.description.isEmpty {
                    Text(session.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                // Apps sélectionnées (si la session a des apps suggérées)
                if session.suggestedAppsCount > 0 {
                    ActiveSessionAppsRow(session: session)
                }

                // Barre de membres (avatars empilés + code)
                HStack(spacing: 0) {
                    // Avatars empilés
                    HStack(spacing: -10) {
                        ForEach(0..<min(session.memberIds.count, 5), id: \.self) { index in
                            MiniAvatar(index: index)
                                .scaleEffect(memberAvatarsVisible ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.06),
                                    value: memberAvatarsVisible
                                )
                        }
                        
                        if session.memberIds.count > 5 {
                            Text("+\(session.memberIds.count - 5)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(Circle().stroke(Color(red: 0.12, green: 0.22, blue: 0.12), lineWidth: 2))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    // Code d'invitation (copiable)
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(session.inviteCode)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.12),
                                    Color(red: 0.08, green: 0.08, blue: 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glow border animé
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    statusColor.opacity(0.5),
                                    statusColor.opacity(0.1),
                                    statusColor.opacity(0.3),
                                    statusColor.opacity(0.0),
                                    statusColor.opacity(0.5)
                                ]),
                                center: .center,
                                startAngle: .degrees(glowPhase),
                                endAngle: .degrees(glowPhase + 360)
                            ),
                            lineWidth: 2
                        )
                }
            )
            .shadow(color: statusColor.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
        .onAppear {
            memberAvatarsVisible = true
            if session.status == .active {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    glowPhase = 360
                }
            }
        }
    }
}

struct MiniAvatar: View {
    let index: Int
    private let colors: [Color] = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.4, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.7),
        Color(red: 1.0, green: 0.5, blue: 0.4),
        Color(red: 1.0, green: 0.7, blue: 0.3),
    ]
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [colors[index % colors.count], colors[index % colors.count].opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            )
            .overlay(
                Circle()
                    .stroke(Color(red: 0.12, green: 0.22, blue: 0.12), lineWidth: 2)
            )
    }
}


// MARK: - My Sessions Section

struct MySessionsSection: View {
    let sessions: [Session]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Mes Sessions", icon: "rectangle.stack.fill", count: sessions.count)
            
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session, index: index)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
}


// MARK: - Public Sessions Section

struct PublicSessionsSection: View {
    let sessions: [Session]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sessions Publiques", icon: "globe", count: nil)
            
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "Aucune session publique",
                    subtitle: "Sois le premier à en créer une !"
                )
            } else {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    SessionRow(session: session, index: index)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.5), value: showContent)
    }
}


// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    let count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cyan.opacity(0.8))
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.12)))
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}


// MARK: - Invitations Section

struct InvitationsSection: View {
    let invitations: [SessionInvitation]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Invitations", icon: "envelope.open.fill", count: invitations.count)
            
            ForEach(Array(invitations.enumerated()), id: \.element.id) { index, invitation in
                InvitationRow(invitation: invitation, index: index)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.35), value: showContent)
    }
}


// MARK: - Session Row (redesigné)

struct SessionRow: View {
    let session: Session
    var index: Int = 0
    @State private var appeared = false
    
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
        NavigationLink(destination: SessionDetailView(session: session)) {
            HStack(spacing: 14) {
                // Icône de status avec halo
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusColor)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(session.memberIds.count)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Mini-avatars
                HStack(spacing: -6) {
                    ForEach(0..<min(session.memberIds.count, 3), id: \.self) { i in
                        Circle()
                            .fill(
                                [Color.blue, Color.purple, Color.mint, Color.pink][i % 4].opacity(0.7)
                            )
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color(red: 0.15, green: 0.15, blue: 0.17), lineWidth: 1.5))
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(16)
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
        .buttonStyle(BounceButtonStyle())
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}


// MARK: - Invitation Row (redesigné)

struct InvitationRow: View {
    let invitation: SessionInvitation
    var index: Int = 0
    @State private var appeared = false
    @State private var slideOut: CGFloat = 0

    var body: some View {
        HStack(spacing: 14) {
            // Avatar de l'envoyeur
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Text(String(invitation.fromUsername.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.sessionTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("de")
                        .foregroundColor(.white.opacity(0.4))
                    Text(invitation.fromUsername)
                        .foregroundColor(.cyan.opacity(0.8))
                }
                .font(.system(size: 13, weight: .medium))
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 10) {
                Button(action: { /* accept */ }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 3)
                        )
                }
                .buttonStyle(BounceButtonStyle())
                
                Button(action: { /* decline */ }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                }
                .buttonStyle(BounceButtonStyle())
            }
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
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .offset(x: slideOut)
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                appeared = true
            }
        }
    }
}


// MARK: - Empty State View (redesigné)

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    @State private var float = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 90, height: 90)
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: float ? -4 : 4)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}


// MARK: - Leader Pause Requests Card

struct LeaderPauseRequestsCard: View {
    let requests: [PauseRequest]
    let session: Session
    let showContent: Bool
    @State private var pulseAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseAlert ? 1.15 : 1.0)
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Demandes de Pause")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(requests.count) en attente")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.8))
                }

                Spacer()
            }

            ForEach(requests) { request in
                PauseRequestPreviewRow(request: request, sessionId: session.id ?? "")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .orange.opacity(0.1), radius: 16, x: 0, y: 8)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAlert = true
            }
        }
    }
}

struct PauseRequestPreviewRow: View {
    let request: PauseRequest
    let sessionId: String
    @ObservedObject private var sessionManager = SessionManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text(String(request.requesterUsername.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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

                Text(timeAgo(from: request.requestedAt.dateValue()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { acceptRequest() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .green.opacity(0.4), radius: 6, x: 0, y: 2)
                        )
                }
                .buttonStyle(BounceButtonStyle())

                Button(action: { declineRequest() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
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


// MARK: - Bounce Button Style (micro-interaction tactile)

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
        HStack(spacing: 10) {
            // Icône et label
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)

                Text("Apps bloquées")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Apps icons ou nombre
            if session.suggestedAppsCount > 0 {
                HStack(spacing: -8) {
                    // Si on a les vraies apps de la session locale
                    if let sessionId = session.id,
                       let localApps = sessionManager.getLocalApps(sessionId: sessionId),
                       localApps.selectedAppsCount > 0 {

                        // Afficher jusqu'à 4 icônes
                        let maxIcons = 4
                        ForEach(0..<min(localApps.selectedAppsCount, maxIcons), id: \.self) { index in
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                                    .frame(width: 24, height: 24)

                                Image(systemName: getAppIcon(index: index))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            .zIndex(Double(maxIcons - index))
                        }

                        if localApps.selectedAppsCount > maxIcons {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                                    .frame(width: 24, height: 24)

                                Text("+\(localApps.selectedAppsCount - maxIcons)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            .zIndex(0)
                        }
                    } else {
                        // Afficher juste le nombre suggéré
                        Text("\(session.suggestedAppsCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.purple.opacity(0.2))
                            )
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadSessionApps()
        }
    }

    private func loadSessionApps() {
        if let sessionId = session.id,
           let localApps = sessionManager.getLocalApps(sessionId: sessionId),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens) {
            sessionApps = selection
        }
    }

    private func getAppIcon(index: Int) -> String {
        let icons = ["app.fill", "square.stack.3d.up.fill", "app.badge.fill", "square.grid.2x2.fill"]
        return icons[index % icons.count]
    }
}


// MARK: - Preview

#Preview {
    SocialTab()
        .environmentObject(ZenloopManager.shared)
}