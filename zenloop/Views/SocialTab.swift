//
//  SocialTab.swift
//  zenloop
//
//  Onglet social pour les sessions de groupe
//  Style: HomeView avec OptimizedBackground et sections modulaires
//

import SwiftUI

struct SocialTab: View {
    // ✅ FIX: @ObservedObject pour les singletons (pas @StateObject)
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var showCreateSession = false
    @State private var showJoinSession = false
    @State private var inviteCode = ""

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                SocialLoginView()
            }
        }
        .onAppear {
            print("🔍 [SocialTab] isAuthenticated: \(authManager.isAuthenticated)")
            print("🔍 [SocialTab] currentFirebaseUser: \(authManager.currentFirebaseUser?.uid ?? "nil")")
        }
    }

    private var authenticatedContent: some View {
        ZStack {
            // Background optimisé - même style que HomeView
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                // Header minimaliste
                SocialHeader(showContent: showContent)
                    .padding(.horizontal, 20)

                // Contenu principal
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Quick Actions Card
                        QuickActionsCard(
                            showContent: showContent,
                            onCreateSession: {
                                showCreateSession = true
                            },
                            onJoinSession: {
                                showJoinSession = true
                            }
                        )
                        .padding(.top, 20)

                        // Active Session Card (si en session)
                        if let currentSession = sessionManager.currentSession {
                            ActiveSessionCard(
                                session: currentSession,
                                showContent: showContent
                            )
                        }

                        // My Sessions Section
                        if !sessionManager.mySessions.isEmpty {
                            MySessionsSection(
                                sessions: sessionManager.mySessions,
                                showContent: showContent
                            )
                        }

                        // Public Sessions Section
                        PublicSessionsSection(
                            sessions: sessionManager.publicSessions,
                            showContent: showContent
                        )

                        // Invitations Section
                        if !sessionManager.pendingInvitations.isEmpty {
                            InvitationsSection(
                                invitations: sessionManager.pendingInvitations,
                                showContent: showContent
                            )
                        }

                        // Espace de respiration en bas
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                showContent = true
            }
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionView()
                .environmentObject(zenloopManager)
        }
        .sheet(isPresented: $showJoinSession) {
            JoinSessionView(inviteCode: $inviteCode)
        }
    }
}

// MARK: - Social Header

struct SocialHeader: View {
    let showContent: Bool

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
        }
        .padding(.top, 60)
        .padding(.bottom, 10)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    let showContent: Bool
    let onCreateSession: () -> Void
    let onJoinSession: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Create Session Button
            Button(action: onCreateSession) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.3, green: 0.5, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Créer une Session")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Inviter des amis à focus ensemble")
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
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.17),
                                    Color(red: 0.12, green: 0.12, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Join Session Button
            Button(action: onJoinSession) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.4, blue: 1.0),
                                        Color(red: 0.5, green: 0.3, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rejoindre avec un Code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Entrer le code d'invitation")
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
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.17),
                                    Color(red: 0.12, green: 0.12, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

// MARK: - Active Session Card

struct ActiveSessionCard: View {
    let session: Session
    let showContent: Bool

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.8),
                                        Color.green
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 12, height: 12)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }

                    Text("SESSION ACTIVE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(session.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label("\(session.memberIds.count) membres", systemImage: "person.2.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Label("Code: \(session.inviteCode)", systemImage: "key.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.25, blue: 0.15),
                                Color(red: 0.10, green: 0.20, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

// MARK: - My Sessions Section

struct MySessionsSection: View {
    let sessions: [Session]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mes Sessions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            ForEach(sessions) { session in
                SessionRow(session: session)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions Publiques")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            if sessions.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: "Aucune session publique",
                    subtitle: "Créez la première !"
                )
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.5), value: showContent)
    }
}

// MARK: - Invitations Section

struct InvitationsSection: View {
    let invitations: [SessionInvitation]
    let showContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            ForEach(invitations) { invitation in
                InvitationRow(invitation: invitation)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

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
        case .lobby: return "En attente"
        case .active: return "En cours"
        case .completed: return "Terminée"
        case .dissolved: return "Dissoute"
        }
    }

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session)) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(statusColor)

                        Text("•")
                            .foregroundColor(.white.opacity(0.4))

                        Text("\(session.memberIds.count) membres")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.17),
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Invitation Row

struct InvitationRow: View {
    let invitation: SessionInvitation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.sessionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("De \(invitation.fromUsername)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    // Accept invitation
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.green))
                }

                Button(action: {
                    // Decline invitation
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.red))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.17),
                            Color(red: 0.12, green: 0.12, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    SocialTab()
        .environmentObject(ZenloopManager.shared)
}