//
//  NotificationsView.swift
//  zenloop
//
//  Vue des notifications sociales
//

import SwiftUI

struct NotificationsView: View {
    @ObservedObject private var notificationManager = SocialNotificationManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showContent = false
    @State private var selectedSessionId: String? = nil
    @State private var showSessionDetail = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        if !notificationManager.notifications.isEmpty {
                            Button(action: markAllAsRead) {
                                Text("Tout marquer lu")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    if notificationManager.notifications.isEmpty {
                        EmptyNotificationsView()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(notificationManager.notifications) { notification in
                                    NotificationRow(
                                        notification: notification,
                                        onTap: { handleNotificationTap(notification) }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .sheet(isPresented: $showSessionDetail) {
                if let sessionId = selectedSessionId,
                   let session = sessionManager.mySessions.first(where: { $0.id == sessionId }) ?? sessionManager.publicSessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    private func handleNotificationTap(_ notification: SocialNotification) {
        // Marquer comme lu
        Task {
            if let notifId = notification.id {
                try? await notificationManager.markAsRead(notificationId: notifId)
            }
        }

        // Navigation vers la session
        if let sessionId = notification.sessionId {
            selectedSessionId = sessionId
            showSessionDetail = true
            // Ne pas dismiss ici - la sheet doit s'ouvrir d'abord
        }
    }

    private func markAllAsRead() {
        Task {
            if let userId = sessionManager.currentUser?.id {
                try? await notificationManager.markAllAsRead(userId: userId)
            }
        }
    }
}

struct NotificationRow: View {
    let notification: SocialNotification
    let onTap: () -> Void

    private var iconName: String {
        switch notification.type {
        case .message: return "message.fill"
        case .mention: return "at.circle.fill"
        case .pauseRequest: return "hand.raised.fill"
        case .pauseAccepted: return "checkmark.circle.fill"
        case .pauseDeclined: return "xmark.circle.fill"
        case .sessionStarted: return "play.circle.fill"
        case .sessionPaused: return "pause.circle.fill"
        case .sessionResumed: return "play.fill"
        case .sessionCompleted: return "checkmark.seal.fill"
        case .memberJoined: return "person.badge.plus.fill"
        case .memberLeft: return "person.badge.minus.fill"
        case .invitation: return "envelope.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .message: return .blue
        case .mention: return .purple
        case .pauseRequest: return .orange
        case .pauseAccepted: return .green
        case .pauseDeclined: return .red
        case .sessionStarted: return .green
        case .sessionPaused: return .orange
        case .sessionResumed: return .green
        case .sessionCompleted: return .blue
        case .memberJoined: return .cyan
        case .memberLeft: return .gray
        case .invitation: return .pink
        }
    }

    private var timeAgo: String {
        let now = Date()
        let timestamp = notification.timestamp.dateValue()
        let interval = now.timeIntervalSince(timestamp)

        if interval < 60 {
            return "À l'instant"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Il y a \(minutes) min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Il y a \(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "Il y a \(days)j"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    if let sessionTitle = notification.sessionTitle {
                        Text(sessionTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Text(notification.message)
                        .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                        .foregroundColor(notification.isRead ? .white.opacity(0.7) : .white)
                        .lineLimit(3)

                    Text(timeAgo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(notification.isRead ? Color.white.opacity(0.05) : Color.blue.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(notification.isRead ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("Aucune notification")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            Text("Vos notifications sociales apparaîtront ici")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

#Preview {
    NotificationsView()
}
