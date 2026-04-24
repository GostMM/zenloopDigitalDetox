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
    @State private var highlightedSession: Session? = nil
    @State private var feedSegment: SessionFeedSegment = .mine
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                SocialLoginView()
            }
        }
    }

    private var heroSession: Session? {
        highlightedSession ?? sessionManager.currentSession ?? sessionManager.mySessions.first
    }

    private var alertCount: Int {
        let pause = sessionManager.currentSession.map { session in
            session.leaderId == sessionManager.currentUser?.id ? sessionManager.pendingPauseRequests.count : 0
        } ?? 0
        let join = sessionManager.pendingJoinRequests.count
        return pause + join
    }

    private var authenticatedContent: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

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
                    VStack(spacing: 28) {

                        // 1. HERO — carte unique qui adapte son contenu
                        HeroSection(
                            session: heroSession,
                            showContent: showContent,
                            onCreate: { showCreateSession = true },
                            onJoin: { showJoinSession = true }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // 2. ACTION RAIL — toujours visible, discret
                        ActionRail(
                            showContent: showContent,
                            activeMembersCount: onlineMembersCount,
                            alertCount: alertCount,
                            onCreate: { showCreateSession = true },
                            onJoin: { showJoinSession = true }
                        )
                        .padding(.horizontal, 20)

                        // 3. ALERTS (leader) — affichées UNIQUEMENT si count > 0
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
                        }

                        if !sessionManager.pendingJoinRequests.isEmpty {
                            JoinRequestsSection(
                                requests: sessionManager.pendingJoinRequests,
                                showContent: showContent
                            )
                            .padding(.horizontal, 20)
                        }

                        // 4. INVITATIONS — carousel si présent
                        if !sessionManager.pendingInvitations.isEmpty {
                            InvitationsCarousel(
                                invitations: sessionManager.pendingInvitations,
                                showContent: showContent
                            )
                        }

                        // 5. FEED unifié — segment Mes / Découvrir
                        SessionsFeedSection(
                            segment: $feedSegment,
                            mySessions: sessionManager.mySessions,
                            publicSessions: sessionManager.publicSessions,
                            showContent: showContent,
                            onSessionTap: { session in
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    highlightedSession = session
                                }
                            }
                        )

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
            // ✅ Bootstrap UNE SEULE FOIS par vie de la vue.
            // Les listeners Firestore sont idempotents (SessionManager garde un flag),
            // et restent actifs en background — aucun refresh brutal à chaque onAppear.
            guard !didBootstrap, let userId = sessionManager.currentUser?.id else { return }
            didBootstrap = true
            notificationManager.startListening(userId: userId)
            Task { await sessionManager.loadUserSessions() }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if !isAuth {
                didBootstrap = false
                notificationManager.stopListening()
            }
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

    private var onlineMembersCount: Int {
        (sessionManager.currentSession?.memberIds ?? []).count
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


// MARK: - Hero Section (adapte le contenu au state)

struct HeroSection: View {
    let session: Session?
    let showContent: Bool
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        Group {
            if let session = session {
                ActiveSessionCard(session: session, showContent: showContent)
            } else {
                EmptyHeroCard(showContent: showContent, onCreate: onCreate, onJoin: onJoin)
            }
        }
    }
}

struct EmptyHeroCard: View {
    let showContent: Bool
    let onCreate: () -> Void
    let onJoin: () -> Void
    @State private var shimmerPhase: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3), .clear],
                            center: .center, startRadius: 10, endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.5)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.5, green: 0.7, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(appeared ? 0 : -30))
            }

            VStack(spacing: 6) {
                Text("Prêt à focus ensemble")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Crée une session ou rejoins-en une\npour démarrer ton focus partagé.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            HStack(spacing: 10) {
                HeroPrimaryCTA(icon: "plus.circle.fill", label: "Créer", gradient: [
                    Color(red: 0.35, green: 0.55, blue: 1.0),
                    Color(red: 0.25, green: 0.4, blue: 0.95)
                ], action: onCreate)

                HeroPrimaryCTA(icon: "person.badge.plus", label: "Rejoindre", gradient: [
                    Color(red: 0.6, green: 0.35, blue: 1.0),
                    Color(red: 0.45, green: 0.2, blue: 0.9)
                ], action: onJoin)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.14, blue: 0.22),
                                Color(red: 0.07, green: 0.08, blue: 0.14)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.blue.opacity(0.08), radius: 20, x: 0, y: 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4)) {
                appeared = true
            }
        }
    }
}

struct HeroPrimaryCTA: View {
    let icon: String
    let label: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule().fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: gradient[0].opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}


// MARK: - Action Rail (compact, toujours visible sous le hero)

struct ActionRail: View {
    let showContent: Bool
    let activeMembersCount: Int
    let alertCount: Int
    let onCreate: () -> Void
    let onJoin: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            // Indicateur online membres
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 18, height: 18)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                Text(activeMembersCount > 0 ? "\(activeMembersCount) en ligne" : "Personne en focus")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(activeMembersCount > 0 ? 0.75 : 0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(0.05))
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            )

            if alertCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(alertCount)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.orange.opacity(0.12))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.25), lineWidth: 1))
                )
                .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 4)

            // Actions rapides
            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.25, green: 0.4, blue: 0.95)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(BounceButtonStyle())

            Button(action: onJoin) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(red: 0.6, green: 0.35, blue: 1.0), Color(red: 0.45, green: 0.2, blue: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.3), value: showContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}


// MARK: - Sessions Feed (segment Mes / Découvrir)

enum SessionFeedSegment: String, CaseIterable {
    case mine = "Mes Sessions"
    case discover = "Découvrir"

    var icon: String {
        switch self {
        case .mine: return "rectangle.stack.fill"
        case .discover: return "globe"
        }
    }

    var accent: Color {
        switch self {
        case .mine: return .cyan
        case .discover: return Color(red: 0.6, green: 0.4, blue: 1.0)
        }
    }
}

struct SessionsFeedSection: View {
    @Binding var segment: SessionFeedSegment
    let mySessions: [Session]
    let publicSessions: [Session]
    let showContent: Bool
    var onSessionTap: ((Session) -> Void)? = nil

    private var currentSessions: [Session] {
        segment == .mine ? mySessions : publicSessions
    }

    private var emptyMessage: String {
        segment == .mine ? "Tu n'as pas encore de session." : "Crée la première session publique !"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Segment control
            HStack(spacing: 6) {
                ForEach(SessionFeedSegment.allCases, id: \.self) { seg in
                    SegmentPill(
                        segment: seg,
                        isSelected: segment == seg,
                        count: seg == .mine ? mySessions.count : publicSessions.count,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                segment = seg
                            }
                        }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Group {
                if currentSessions.isEmpty {
                    CarouselEmptyState(message: emptyMessage, accentColor: segment.accent)
                        .padding(.horizontal, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Array(currentSessions.enumerated()), id: \.element.id) { index, session in
                                SessionCarouselCard(
                                    session: session,
                                    accentColor: segment.accent,
                                    index: index,
                                    showContent: showContent,
                                    onTap: onSessionTap
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: segment)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 25)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.45), value: showContent)
    }
}

struct SegmentPill: View {
    let segment: SessionFeedSegment
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: segment.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(segment.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(isSelected ? .white : segment.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.22) : segment.accent.opacity(0.15))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? segment.accent.opacity(0.9) : Color.white.opacity(0.04))
                    .overlay(
                        Capsule().stroke(
                            isSelected ? segment.accent.opacity(0.5) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                    )
            )
            .shadow(
                color: isSelected ? segment.accent.opacity(0.35) : .clear,
                radius: 10, x: 0, y: 4
            )
        }
        .buttonStyle(BounceButtonStyle())
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


// MARK: - Session Carousel Card (réutilisé par SessionsFeedSection)

struct SessionCarouselCard: View {
    let session: Session
    let accentColor: Color
    let index: Int
    let showContent: Bool
    var onTap: ((Session) -> Void)? = nil // ✅ Callback pour sélection
    @State private var appeared = false
    @ObservedObject private var sessionManager = SessionManager.shared

    private var isMember: Bool {
        guard let userId = sessionManager.currentUser?.id else { return false }
        return (session.memberIds ?? []).contains(userId)
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
        .simultaneousGesture(
            TapGesture().onEnded {
                // ✅ Appeler le callback si disponible pour mettre à jour la ActiveSessionCard
                onTap?(session)
            }
        )
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
                    Text("\((session.memberIds ?? []).count)").font(.system(size: 11, weight: .bold, design: .rounded))
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
            if !(session.description ?? "").isEmpty {
                Text(session.description ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(2)
                    .padding(.bottom, 10)
            }

            Spacer(minLength: 0)

            // Bottom : avatars + code
            HStack(spacing: 0) {
                HStack(spacing: -8) {
                    ForEach(0..<min((session.memberIds ?? []).count, 4), id: \.self) { i in
                        CarouselMiniAvatar(index: i)
                    }

                    if (session.memberIds ?? []).count > 4 {
                        Text("+\((session.memberIds ?? []).count - 4)")
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
        .background(
            ZStack {
                // ✅ Image de fond depuis Firebase Storage avec cache et shimmer
                if let storagePath = session.backgroundImageUrl, !storagePath.isEmpty {
                    CachedFirebaseImage(storagePath: storagePath, cornerRadius: 20)
                        .frame(width: 220, height: 200)
                        .withReadabilityOverlay(cornerRadius: 20)
                } else {
                    // Pas d'image - motif par défaut
                    ZStack {
                        CardPatternBackground(color: accentColor, cornerRadius: 20)
                        RoundedRectangle(cornerRadius: 20).fill(cardGradient.opacity(0.7))
                    }
                }
            }
        )
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


// MARK: - Card Pattern Background (motifs subtils)

struct CardPatternBackground: View {
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            // Base gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.12), Color(red: 0.08, green: 0.08, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Motif géométrique subtil
            GeometryReader { geometry in
                Canvas { context, size in
                    // Grille de cercles subtils
                    let spacing: CGFloat = 40
                    let dotSize: CGFloat = 2

                    for x in stride(from: 0, to: size.width, by: spacing) {
                        for y in stride(from: 0, to: size.height, by: spacing) {
                            let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                            context.opacity = 0.08
                            context.fill(Circle().path(in: rect), with: .color(color))
                        }
                    }

                    // Lignes diagonales subtiles
                    context.opacity = 0.04
                    for offset in stride(from: -size.height, to: size.width, by: 60) {
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                        context.stroke(path, with: .color(color), lineWidth: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}


// MARK: - Active Session Card (hero — INTACT)

struct ActiveSessionCard: View {
    let session: Session
    let showContent: Bool
    @State private var glowPhase: CGFloat = 0
    @State private var memberAvatarsVisible = false
    @State private var elapsedTick = Date()
    @State private var livePulse = false

    private let liveTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var statusColor: Color {
        switch session.status {
        case .active: return Color(red: 0.3, green: 0.9, blue: 0.5)
        case .paused: return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .lobby: return Color(red: 0.5, green: 0.7, blue: 1.0)
        default: return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }

    private var statusLabel: String {
        switch session.status {
        case .active: return "EN COURS"
        case .paused: return "EN PAUSE"
        case .lobby: return "LOBBY"
        default: return "SESSION"
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .active: return "bolt.fill"
        case .paused: return "pause.fill"
        case .lobby: return "hourglass"
        default: return "circle.fill"
        }
    }

    private var elapsedText: String? {
        guard session.status == .active, let started = session.startedAt?.dateValue() else { return nil }
        let interval = max(0, Int(elapsedTick.timeIntervalSince(started)))
        let h = interval / 3600
        let m = (interval % 3600) / 60
        let s = interval % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private var memberCount: Int { (session.memberIds ?? []).count }

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            cardContent
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
                memberAvatarsVisible = true
            }
            if session.status == .active {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { glowPhase = 360 }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { livePulse = true }
            }
        }
        .onReceive(liveTimer) { now in
            if session.status == .active { elapsedTick = now }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top row : status + LIVE timer + arrow
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon).font(.system(size: 10, weight: .heavy))
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(
                    Capsule().fill(statusColor.opacity(0.18))
                        .overlay(Capsule().stroke(statusColor.opacity(0.35), lineWidth: 1))
                )

                if session.status == .active {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .scaleEffect(livePulse ? 1.3 : 0.9)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.85))
                        if let elapsed = elapsedText {
                            Text(elapsed)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Titre + description
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !(session.description ?? "").isEmpty {
                    Text(session.description ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }

            // Apps row (si présent)
            if (session.suggestedAppsCount ?? 0) > 0 {
                ActiveSessionAppsRow(session: session)
            }

            Spacer(minLength: 0)

            // Bottom : avatars + invite code
            HStack(spacing: 12) {
                HStack(spacing: -10) {
                    ForEach(0..<min(memberCount, 5), id: \.self) { index in
                        MiniAvatar(index: index)
                            .scaleEffect(memberAvatarsVisible ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.65).delay(Double(index) * 0.07),
                                value: memberAvatarsVisible
                            )
                    }
                    if memberCount > 5 {
                        Text("+\(memberCount - 5)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(Color.white.opacity(0.12))
                                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 2))
                            )
                    }
                }

                if memberCount > 0 {
                    Text("\(memberCount) membre\(memberCount > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "key.fill").font(.system(size: 10, weight: .bold))
                    Text(session.inviteCode)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.08))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28).stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        statusColor.opacity(0.6),
                        statusColor.opacity(0.1),
                        statusColor.opacity(0.4),
                        statusColor.opacity(0.0),
                        statusColor.opacity(0.6)
                    ]),
                    center: .center,
                    startAngle: .degrees(glowPhase),
                    endAngle: .degrees(glowPhase + 360)
                ),
                lineWidth: 1.5
            )
        )
        .shadow(color: statusColor.opacity(0.2), radius: 24, x: 0, y: 12)
    }

    @ViewBuilder
    private var cardBackground: some View {
        GeometryReader { geometry in
            ZStack {
                if let storagePath = session.backgroundImageUrl, !storagePath.isEmpty {
                    CachedFirebaseImage(storagePath: storagePath, cornerRadius: 28)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .withReadabilityOverlay(cornerRadius: 28)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.25),
                            Color.black.opacity(0.55)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    CardPatternBackground(color: statusColor, cornerRadius: 28)
                    LinearGradient(
                        colors: [
                            statusColor.opacity(0.12),
                            Color(red: 0.06, green: 0.08, blue: 0.14)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
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

// MARK: - Join Requests Section

struct JoinRequestsSection: View {
    let requests: [JoinRequest]
    let showContent: Bool
    @State private var pulseAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle().fill(Color.blue).frame(width: 10, height: 10).scaleEffect(pulseAlert ? 1.4 : 0.9)
                Text("Demandes de rejoindre").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("\(requests.count)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.blue)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.blue.opacity(0.12)))
                Spacer()
            }.padding(.horizontal, 4)

            ForEach(requests) { request in
                JoinRequestRow(request: request)
            }
        }
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: showContent)
        .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulseAlert = true } }
    }
}

struct JoinRequestRow: View {
    let request: JoinRequest
    @ObservedObject private var sessionManager = SessionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40)
                    Text(String(request.username.prefix(1)).uppercased()).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.username).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("Veut rejoindre « \(request.targetSessionTitle) »").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
                    if let currentSessionTitle = request.currentSessionTitle {
                        Text("Actuellement dans « \(currentSessionTitle) »").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.3)).lineLimit(1)
                    }
                    Text(timeAgo(from: request.createdAt.dateValue())).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.3))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { approveRequest() }) {
                        Text("OK").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom)).shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 2))
                    }.buttonStyle(BounceButtonStyle())
                    Button(action: { rejectRequest() }) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32).background(Circle().fill(Color.white.opacity(0.06)))
                    }.buttonStyle(BounceButtonStyle())
                }
            }.padding(.vertical, 12)
            Rectangle().fill(LinearGradient(colors: [Color.white.opacity(0.0), Color.blue.opacity(0.1), Color.white.opacity(0.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        }
    }

    private func approveRequest() {
        Task {
            guard let requestId = request.id, !requestId.isEmpty else {
                print("❌ Request ID is nil or empty")
                return
            }
            do {
                try await sessionManager.approveJoinRequest(requestId: requestId)
            } catch {
                print("❌ Error approving join request: \(error.localizedDescription)")
            }
        }
    }

    private func rejectRequest() {
        Task {
            guard let requestId = request.id, !requestId.isEmpty else {
                print("❌ Request ID is nil or empty")
                return
            }
            do {
                try await sessionManager.rejectJoinRequest(requestId: requestId)
            } catch {
                print("❌ Error rejecting join request: \(error.localizedDescription)")
            }
        }
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
            } else if (session.suggestedAppsCount ?? 0) > 0 {
                HStack(spacing: -10) {
                    ForEach(0..<min(session.suggestedAppsCount ?? 0, 4), id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.2)).frame(width: 32, height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.4), lineWidth: 1.5))
                            Image(systemName: getGenericAppIcon(index: index)).font(.system(size: 14, weight: .semibold)).foregroundColor(.purple)
                        }.zIndex(Double(4 - index))
                    }
                    if (session.suggestedAppsCount ?? 0) > 4 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [.purple.opacity(0.3), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.5), lineWidth: 1.5))
                            Text("+\((session.suggestedAppsCount ?? 0) - 4)").font(.system(size: 11, weight: .bold)).foregroundColor(.purple)
                        }.zIndex(0)
                    }
                }
            }
            Spacer()
        }
        .onAppear { loadSessionApps() }
        .onChange(of: session.id) { _, _ in loadSessionApps() }
        .onChange(of: session.sharedAppTokens) { _, _ in loadSessionApps() }
    }

    private func loadSessionApps() {
        guard let sessionId = session.id else {
            sessionApps = FamilyActivitySelection()
            return
        }

        // 1) Sélection locale du membre (source prioritaire — ce sont ses propres tokens,
        //    donc `Label(token)` rend correctement les icônes d'apps).
        if let localApps = sessionManager.getLocalApps(sessionId: sessionId),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: localApps.selectedAppTokens),
           !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
            sessionApps = selection
            return
        }

        // 2) Fallback: sélection partagée publiée par le leader via Firestore
        //    (pour late joiners qui n'ont pas encore fait leur choix).
        if let shared = session.sharedAppTokens,
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: shared),
           !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
            sessionApps = selection
            return
        }

        sessionApps = FamilyActivitySelection()
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