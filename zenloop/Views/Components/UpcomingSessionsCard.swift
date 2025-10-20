//
//  UpcomingSessionsCard.swift
//  zenloop
//
//  Created by Claude on 19/10/2025.
//

import SwiftUI

struct UpcomingSessionsCard: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool

    private var upcomingSessions: [ZenloopChallenge] {
        zenloopManager.getUpcomingSessions(limit: 3)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.3),
                                        Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
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

    private var startTime: Date {
        session.startTime ?? Date()
    }

    private var endTime: Date {
        startTime.addingTimeInterval(session.duration)
    }

    private var timeUntilStart: String {
        let now = Date()
        let interval = startTime.timeIntervalSince(now)

        if interval < 0 {
            return String(localized: "starting_now")
        } else if interval < 60 {
            return String(localized: "in_less_than_minute")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(localized: "in_x_minutes")
                .replacingOccurrences(of: "{count}", with: "\(minutes)")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(localized: "in_x_hours")
                .replacingOccurrences(of: "{count}", with: "\(hours)")
        } else {
            let days = Int(interval / 86400)
            return String(localized: "in_x_days")
                .replacingOccurrences(of: "{count}", with: "\(days)")
        }
    }

    private var timeUntilStartShort: String {
        let now = Date()
        let interval = startTime.timeIntervalSince(now)

        if interval < 0 {
            return "Now"
        } else if interval < 60 {
            return "<1min"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }

    private var difficultyColor: Color {
        switch session.difficulty {
        case .easy:
            return Color.green
        case .medium:
            return Color.orange
        case .hard:
            return Color.red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(difficultyColor.opacity(0.3), lineWidth: 1)
                        )
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
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.05)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Bottom - Apps preview
            if !session.blockedAppsNames.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 8))
                        .foregroundColor(difficultyColor.opacity(0.7))

                    Text(formatAppsPreview())
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
                // Base background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Colored accent on left edge
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [difficultyColor.opacity(0.6), difficultyColor.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)

                    Spacer()
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            difficultyColor.opacity(0.3),
                            difficultyColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: difficultyColor.opacity(0.15), radius: 8, x: 0, y: 4)
        .alert(String(localized: "cancel_scheduled_session"), isPresented: $showCancelAlert) {
            Button(String(localized: "cancel_session"), role: .destructive) {
                cancelSession()
            }
            Button(String(localized: "keep_session"), role: .cancel) {}
        } message: {
            Text(String(localized: "cancel_scheduled_session_message"))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatAppsPreview() -> String {
        let apps = session.blockedAppsNames
        if apps.isEmpty {
            return ""
        } else if apps.count == 1 {
            return apps[0]
        } else if apps.count == 2 {
            return "\(apps[0]), \(apps[1])"
        } else {
            return "\(apps[0]), \(apps[1]) +\(apps.count - 2)"
        }
    }

    private func cancelSession() {
        zenloopManager.cancelScheduledChallenge(session.id)
    }
}
