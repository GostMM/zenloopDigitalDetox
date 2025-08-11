//
//  RecentActivitySection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct RecentActivitySection: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            // En-tête modernisé avec statistiques
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "recent_activity"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(String(localized: "your_latest_focus_sessions"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Stats badge
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        
                        Text("\(zenloopManager.recentActivity.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.cyan.opacity(0.2), .blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(.cyan.opacity(0.3), lineWidth: 1)
                    )
                }
                
                if !zenloopManager.recentActivity.isEmpty {
                    // Bouton voir tout amélioré
                    HStack {
                        Spacer()
                        
                        Button {
                            // Action pour voir historique complet
                        } label: {
                            HStack(spacing: 6) {
                                Text(String(localized: "view_complete_history"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
            
            if zenloopManager.recentActivity.isEmpty {
                // État vide modernisé
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 2)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 12) {
                        Text(String(localized: "no_recent_activity"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(String(localized: "launch_first_focus_challenge"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
            } else {
                // Liste des activités modernisée
                VStack(spacing: 16) {
                    ForEach(Array(zenloopManager.recentActivity.prefix(4)), id: \.id) { activity in
                        EnhancedActivityRow(activity: activity)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
    }
}

// MARK: - Enhanced Activity Row

struct EnhancedActivityRow: View {
    let activity: ActivityRecord
    @State private var isPressed = false
    
    var body: some View {
        Button {
            // Action pour voir détails de l'activité
        } label: {
            HStack(spacing: 16) {
                // Icône d'activité améliorée
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [activityColor.opacity(0.3), activityColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .stroke(activityColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: activityIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(activityColor)
                        .shadow(color: activityColor.opacity(0.3), radius: 2)
                }
                
                // Contenu principal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(activity.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Badge type amélioré
                        Text(activityTypeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [activityColor, activityColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                            .shadow(color: activityColor.opacity(0.3), radius: 2)
                    }
                    
                    // Métadonnées avec icônes
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatDate(activity.timestamp))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let duration = activity.duration {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(formatDuration(duration))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // Indicateur d'action
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [activityColor.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? 0.05 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Computed Properties
    
    private var activityIcon: String {
        switch activity.type {
        case .challengeStarted: return "play.circle.fill"
        case .challengeCompleted: return "checkmark.circle.fill"
        case .challengePaused: return "pause.circle.fill"
        case .challengeResumed: return "arrow.clockwise.circle.fill"
        case .challengeStopped: return "stop.circle.fill"
        }
    }
    
    private var activityColor: Color {
        switch activity.type {
        case .challengeStarted: return .cyan
        case .challengeCompleted: return .green
        case .challengePaused: return .orange
        case .challengeResumed: return .blue
        case .challengeStopped: return .red
        }
    }
    
    private var activityTypeText: String {
        switch activity.type {
        case .challengeStarted: return String(localized: "started")
        case .challengeCompleted: return String(localized: "completed")
        case .challengePaused: return String(localized: "paused")
        case .challengeResumed: return String(localized: "resumed")
        case .challengeStopped: return String(localized: "stopped")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "today_at_time", defaultValue: "Today \(formatter.string(from: date))", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: formatter.string(from: date))
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "yesterday_at_time", defaultValue: "Yesterday \(formatter.string(from: date))", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: formatter.string(from: date))
        } else {
            formatter.dateFormat = "dd/MM HH:mm"
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h\(remainingMinutes > 0 ? "\(remainingMinutes)m" : "")"
        }
    }
}

struct RecentActivityRow: View {
    let activity: ActivityRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône d'activité
            Image(systemName: activityIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(activityColor)
                .frame(width: 28, height: 28)
                .background(activityColor.opacity(0.2), in: Circle())
            
            // Contenu
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formatDate(activity.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if let duration = activity.duration {
                        Text("•")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(formatDuration(duration))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            // Badge type
            Text(activityTypeText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(activityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(activityColor.opacity(0.2), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var activityIcon: String {
        switch activity.type {
        case .challengeStarted: return "play.circle"
        case .challengeCompleted: return "checkmark.circle"
        case .challengePaused: return "pause.circle"
        case .challengeResumed: return "arrow.clockwise.circle"
        case .challengeStopped: return "stop.circle"
        }
    }
    
    private var activityColor: Color {
        switch activity.type {
        case .challengeStarted: return .cyan
        case .challengeCompleted: return .green
        case .challengePaused: return .orange
        case .challengeResumed: return .blue
        case .challengeStopped: return .red
        }
    }
    
    private var activityTypeText: String {
        switch activity.type {
        case .challengeStarted: return String(localized: "started")
        case .challengeCompleted: return String(localized: "finished")
        case .challengePaused: return String(localized: "paused")
        case .challengeResumed: return String(localized: "resumed")
        case .challengeStopped: return String(localized: "stopped")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "today_at_time", defaultValue: "Today \(formatter.string(from: date))", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: formatter.string(from: date))
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return String(localized: "yesterday_at_time", defaultValue: "Yesterday \(formatter.string(from: date))", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: formatter.string(from: date))
        } else {
            formatter.dateFormat = "dd/MM HH:mm"
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h\(remainingMinutes > 0 ? "\(remainingMinutes)m" : "")"
        }
    }
}

#Preview {
    RecentActivitySection(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}