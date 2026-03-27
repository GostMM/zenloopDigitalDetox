//
//  SessionPreviewView.swift
//  zenloop
//
//  Preview d'une session publique avant de la rejoindre
//  Affiche les détails et un bouton pour confirmer la jonction
//

import SwiftUI
import UIKit

struct SessionPreviewView: View {
    let session: Session

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var showContent = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var pulse = false

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .yellow
        default: return .gray
        }
    }

    private var statusText: String {
        switch session.status {
        case .lobby: return "En attente de démarrage"
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
        ZStack {
            // Background
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Retour")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Icon + Status
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [statusColor.opacity(0.3), statusColor.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(pulse ? 1.05 : 1.0)

                                Image(systemName: statusIcon)
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundColor(statusColor)
                            }

                            // Status badge
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)

                                Text(statusText)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(statusColor.opacity(0.15))
                            )
                        }
                        .padding(.top, 20)

                        // Session Info
                        VStack(alignment: .leading, spacing: 24) {
                            // Title
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SESSION PUBLIQUE")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(1.5)

                                Text(session.title)
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            // Description
                            if !session.description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DESCRIPTION")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white.opacity(0.4))
                                        .tracking(1.2)

                                    Text(session.description)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineSpacing(4)
                                }
                            }

                            // Info Cards
                            VStack(spacing: 12) {
                                InfoRow(
                                    icon: "person.2.fill",
                                    label: "Participants",
                                    value: "\(session.memberIds.count)\(session.maxParticipants.map { " / \($0)" } ?? "")"
                                )

                                InfoRow(
                                    icon: "person.crop.circle.badge.checkmark",
                                    label: "Leader",
                                    value: session.leaderUsername
                                )

                                InfoRow(
                                    icon: "key.fill",
                                    label: "Code d'invitation",
                                    value: session.inviteCode
                                )

                                if let duration = session.durationMinutes {
                                    InfoRow(
                                        icon: "timer",
                                        label: "Durée",
                                        value: formatDuration(minutes: duration)
                                    )
                                }
                            }

                            // Warning if session is full
                            if let max = session.maxParticipants, session.memberIds.count >= max {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.orange)

                                    Text("Session complète")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.orange.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }

                            // Error message
                            if let error = errorMessage {
                                HStack(spacing: 12) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)

                                    Text(error)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.red.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 100)
                    }
                }

                // Join Button (fixed at bottom)
                VStack(spacing: 12) {
                    Button(action: joinSession) {
                        HStack(spacing: 12) {
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                                Text("Jonction en cours...")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            } else {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 20, weight: .bold))

                                Text("Rejoindre la Session")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: isJoining ? [.gray, .gray.opacity(0.8)] : [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                        )
                    }
                    .disabled(isJoining || (session.maxParticipants.map { session.memberIds.count >= $0 } ?? false))
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0),
                            Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.85),
                            Color(red: 0.06, green: 0.06, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)min" : "\(hours)h"
        } else {
            return "\(mins)min"
        }
    }

    private func joinSession() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                let joinedSession = try await sessionManager.joinSession(inviteCode: session.inviteCode)
                await MainActor.run {
                    // Start listening to session
                    sessionManager.startSessionListener(sessionId: joinedSession.id!)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                    // Navigate to session detail
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    SessionPreviewView(session: Session(
        id: "preview",
        title: "Focus Deep Work",
        description: "Session de travail profond de 2 heures sans distractions",
        leaderId: "user1",
        leaderUsername: "Alice",
        visibility: .publicSession,
        inviteCode: "ABC123",
        maxParticipants: 10,
        status: .lobby,
        createdAt: .init(),
        startedAt: nil,
        endedAt: nil,
        pausedAt: nil,
        pausedBy: nil,
        memberIds: ["user1", "user2", "user3"],
        durationMinutes: 120,
        scheduledEndTime: nil,
        suggestedAppsCount: 5
    ))
}
