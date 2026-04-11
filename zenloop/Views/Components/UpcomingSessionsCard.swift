//
//  UpcomingSessionsCard.swift
//  zenloop
//
//  Created by Claude on 19/10/2025.
//  Fixed on 07/04/2026: show app icons instead of text names

import SwiftUI
import FamilyControls

struct UpcomingSessionsCard: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool

    private var upcomingSessions: [ZenloopChallenge] {
        let _ = zenloopManager.hasActiveScheduledSessions
        return zenloopManager.getUpcomingSessions(limit: 3)
    }

    var body: some View {
        if !upcomingSessions.isEmpty {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.7, blue: 1.0),
                                    Color(red: 0.6, green: 0.4, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(String(localized: "upcoming_sessions"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(upcomingSessions.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Liste des sessions
                VStack(spacing: 8) {
                    ForEach(upcomingSessions) { session in
                        UpcomingSessionRow(session: session, zenloopManager: zenloopManager)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color(red: 0.5, green: 0.55, blue: 1.0).opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
        }
    }
}

// MARK: - Upcoming Session Row

struct UpcomingSessionRow: View {
    let session: ZenloopChallenge
    @ObservedObject var zenloopManager: ZenloopManager
    @State private var showCancelAlert = false
    @State private var sessionApps: FamilyActivitySelection? = nil

    private var startTime: Date { session.startTime ?? Date() }
    private var endTime: Date { startTime.addingTimeInterval(session.duration) }

    private var timeUntilStartShort: String {
        let interval = startTime.timeIntervalSince(Date())
        if interval < 0 { return "Now" }
        else if interval < 60 { return "<1min" }
        else if interval < 3600 { return "\(Int(interval / 60))min" }
        else if interval < 86400 { return "\(Int(interval / 3600))h" }
        else { return "\(Int(interval / 86400))d" }
    }

    private var difficultyColor: Color {
        switch session.difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Left side - Time badge
                VStack(spacing: 2) {
                    Text(timeUntilStartShort)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(difficultyColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(formatDuration(session.duration))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 50)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(difficultyColor.opacity(0.12))
                )

                // Center - Session info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))

                        Text("\(formatTime(startTime)) → \(formatTime(endTime))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer(minLength: 4)

                // Right side - Cancel button
                Button { showCancelAlert = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.05)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // FIX: Afficher les ICÔNES d'apps au lieu des noms texte
            if let apps = sessionApps {
                let totalCount = apps.applicationTokens.count + apps.categoryTokens.count
                if totalCount > 0 {
                    HStack(spacing: -6) {
                        // Icônes d'apps
                        ForEach(Array(apps.applicationTokens.prefix(5)), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                        }

                        // Icônes de catégories
                        ForEach(Array(apps.categoryTokens.prefix(max(0, 5 - apps.applicationTokens.count))), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                        }

                        // Badge +N si plus de 5
                        if totalCount > 5 {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))

                                Text("+\(totalCount - 5)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } else if !session.blockedAppsNames.isEmpty {
                // Fallback: texte si pas de tokens chargés
                HStack(spacing: 6) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 8))
                        .foregroundColor(difficultyColor.opacity(0.7))

                    Text("\(session.blockedAppsCount) apps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [difficultyColor.opacity(0.6), difficultyColor.opacity(0.2)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                    Spacer()
                }
            }
        )
        .shadow(color: difficultyColor.opacity(0.15), radius: 8, x: 0, y: 4)
        .onAppear { loadSessionApps() }
        .alert(String(localized: "cancel_scheduled_session"), isPresented: $showCancelAlert) {
            Button(String(localized: "cancel_session"), role: .destructive) { cancelSession() }
            Button(String(localized: "keep_session"), role: .cancel) {}
        } message: {
            Text(String(localized: "cancel_scheduled_session_message"))
        }
    }

    // MARK: - Load app tokens from App Group payload

    private func loadSessionApps() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
              let payloadData = suite.data(forKey: "payload_\(session.id)"),
              let payload = try? JSONDecoder().decode(SelectionPayload.self, from: payloadData) else {
            return
        }

        var selection = FamilyActivitySelection()
        selection.applicationTokens = Set(payload.apps)
        selection.categoryTokens = Set(payload.categories)
        sessionApps = selection
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h\(minutes)m" }
        else if hours > 0 { return "\(hours)h" }
        else { return "\(minutes)m" }
    }

    private func cancelSession() {
        zenloopManager.cancelScheduledChallenge(session.id)
        zenloopManager.updateScheduledSessionsStatus()
    }
}