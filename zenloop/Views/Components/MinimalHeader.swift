//
//  MinimalHeader.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct MinimalHeader: View {
    let showContent: Bool
    let currentState: ZenloopState
    let isPremium: Bool
    @ObservedObject var zenloopManager: ZenloopManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var subscriptionStatus: SubscriptionStatus = .none
    @State private var showSubscriptionStatus = false
    @State private var activeBlocksCount: Int = 0
    @State private var showActiveBlocks = false
    
    // TODO: Schedule functionality to be implemented in future version
    // @State private var showingSchedulePicker = false
    // @State private var scheduledStartTime = Date()
    // @State private var isScheduled = false
    // @State private var scheduledDuration = 25
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentGreeting)
                        .font(.system(size: adaptiveGreetingSize(width: geometry.size.width), weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -20)
                    
                    Text(statusText)
                        .font(.system(size: adaptiveStatusSize(width: geometry.size.width), weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -10)
                }
                .frame(maxWidth: adaptiveTextMaxWidth(totalWidth: geometry.size.width))

                Spacer(minLength: 4)
                
                // TODO: Schedule button to be implemented in future version
                /*
            // Bouton de programmation compact
            Button(action: {
                if isScheduled {
                    showingSchedulePicker = true
                } else {
                    isScheduled = true
                    scheduledStartTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                    showingSchedulePicker = true
                }
            }) {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: (isScheduled || zenloopManager.hasActiveScheduledSessions) ? "clock.fill" : "clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor((isScheduled || zenloopManager.hasActiveScheduledSessions) ? .orange : .white.opacity(0.7))
                        
                        // Indicateur de notification animé quand programmé
                        if isScheduled || zenloopManager.hasActiveScheduledSessions {
                            ScheduledNotificationDot()
                        }
                    }
                    
                    if isScheduled {
                        Text(formatCompactTime(scheduledStartTime))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    } else if zenloopManager.hasActiveScheduledSessions {
                        // Afficher la prochaine session programmée via ZenloopManager
                        if let nextSession = zenloopManager.nextScheduledSession {
                            Text(formatCompactTime(nextSession.startTime))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        } else {
                            Text("Sessions en attente")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("Programmer")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((isScheduled || zenloopManager.hasActiveScheduledSessions) ? .orange.opacity(0.15) : .white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke((isScheduled || zenloopManager.hasActiveScheduledSessions) ? .orange.opacity(0.4) : .white.opacity(0.1), lineWidth: (isScheduled || zenloopManager.hasActiveScheduledSessions) ? 1.5 : 1)
                        )
                        .shadow(
                            color: (isScheduled || zenloopManager.hasActiveScheduledSessions) ? .orange.opacity(0.3) : .clear,
                            radius: (isScheduled || zenloopManager.hasActiveScheduledSessions) ? 4 : 0,
                            x: 0,
                            y: 2
                        )
                )
            }
            .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isScheduled)
                */
                
                // Bouton Active Blocks
                if activeBlocksCount > 0 {
                    Button {
                        showActiveBlocks = true
                    } label: {
                        ZStack {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                                        )
                                )

                            // Badge count
                            Text("\(activeBlocksCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(Color.red))
                                .offset(x: 10, y: -10)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
                }

                // Badge PRO si premium ou indicateur de statut d'abonnement
                if isPremium {
                    ProBadge()
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -10)
                } else {
                    // Indicateur de statut d'abonnement pour utilisateurs non premium
                    SubscriptionStatusIndicator(
                        status: subscriptionStatus,
                        showContent: showContent
                    ) {
                        showSubscriptionStatus = true
                    }
                }
                
                // Indicateur d'état minimal
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(currentState == .active ? 1.3 : 1.0)
                    .animation(
                        currentState == .active ?
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                        .easeOut(duration: 0.3),
                        value: currentState
                    )
                    .opacity(showContent ? 1 : 0)
            }
        }
        .frame(height: 44) // Hauteur optimisée pour réduire l'espacement
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
        .sheet(isPresented: $showSubscriptionStatus) {
            SubscriptionStatusView()
        }
        .task {
            await updateSubscriptionStatus()
            updateActiveBlocksCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateActiveBlocksCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActiveBlocksDidChange"))) { _ in
            updateActiveBlocksCount()
        }
        .sheet(isPresented: $showActiveBlocks) {
            BlockControllerView()
        }
        // TODO: Schedule picker to be implemented in future version
        /*
        .sheet(isPresented: $showingSchedulePicker) {
            SchedulePickerView(
                selectedTime: $scheduledStartTime,
                onScheduleConfirmed: { startTime, duration in
                    handleScheduleConfirmed(startTime: startTime, duration: duration)
                }
            )
        }
        */
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
    
    private var statusText: String {
        switch currentState {
        case .idle: return String(localized: "status_ready_new_challenge")
        case .active: return String(localized: "status_focus_in_progress")
        case .paused: return String(localized: "status_active_pause")
        case .completed: return String(localized: "status_mission_accomplished")
        }
    }
    
    private var stateColor: Color {
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
    
    // MARK: - Adaptive Layout Functions
    
    private func adaptiveGreetingSize(width: CGFloat) -> CGFloat {
        switch width {
        case 0..<320: return 18 // iPhone SE
        case 320..<375: return 20 // iPhone 8
        case 375..<414: return 22 // iPhone 8 Plus
        case 414...: return 24 // iPhone Pro Max et plus grand
        default: return 22
        }
    }
    
    private func adaptiveStatusSize(width: CGFloat) -> CGFloat {
        switch width {
        case 0..<320: return 10
        case 320..<375: return 11
        case 375..<414: return 12
        case 414...: return 13
        default: return 12
        }
    }
    
    private func adaptiveTextMaxWidth(totalWidth: CGFloat) -> CGFloat {
        // Réserver de l'espace pour les badges et indicateurs à droite
        let reservedSpace: CGFloat = 120 // Espace pour badges + PRO + circle
        return max(totalWidth * 0.6, totalWidth - reservedSpace)
    }
    
    // TODO: Schedule functions to be implemented in future version
    /*
    private func formatCompactTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: date)
        
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            return timeString
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            return "D+1"
        } else {
            let dayDiff = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
            return "D+\(dayDiff)"
        }
    }
    
    private func handleScheduleConfirmed(startTime: Date, duration: Int) {
        // Mettre à jour l'état local
        scheduledStartTime = startTime
        scheduledDuration = duration
        isScheduled = true
        
        // Ici on devrait programmer la tâche en arrière-plan
        scheduleBackgroundTask(startTime: startTime, duration: duration)
        
        print("📅 [MINIMAL_HEADER] Session programmée:")
        print("  - Début: \(startTime)")
        print("  - Durée: \(duration) minutes")
        print("  - Fin: \(Calendar.current.date(byAdding: .minute, value: duration, to: startTime) ?? startTime)")
    }
    
    private func scheduleBackgroundTask(startTime: Date, duration: Int) {
        let durationInSeconds = TimeInterval(duration * 60)
        let title = "Session programmée - \(duration) min"
        let difficulty: DifficultyLevel = duration <= 20 ? .easy : duration <= 60 ? .medium : .hard
        
        // Programmer via ZenloopManager avec les apps actuellement sélectionnées
        zenloopManager.scheduleCustomChallenge(
            title: title,
            duration: durationInSeconds,
            difficulty: difficulty,
            apps: zenloopManager.getAppsSelection(), // Utilise la sélection actuelle
            startTime: startTime
        )
        
        let endTime = Calendar.current.date(byAdding: .minute, value: duration, to: startTime) ?? startTime
        print("🚀 [BACKGROUND] Session programmée via ZenloopManager:")
        print("  - Titre: \(title)")
        print("  - Difficulté: \(difficulty)")
        print("  - Début: \(formatDateTime(startTime))")
        print("  - Fin: \(formatDateTime(endTime))")
        print("  - Durée: \(duration) minutes")
        print("  - Apps sélectionnées: \(zenloopManager.selectedAppsCount)")
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    */
    
    // MARK: - Subscription Status Methods

    private func updateSubscriptionStatus() async {
        subscriptionStatus = await purchaseManager.getSubscriptionStatus()
    }

    // MARK: - Active Blocks Methods

    private func updateActiveBlocksCount() {
        let blockManager = BlockManager()
        activeBlocksCount = blockManager.getActiveBlocks().count
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Subscription Status Indicator

struct SubscriptionStatusIndicator: View {
    let status: SubscriptionStatus
    let showContent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                statusIcon
                    .font(.system(size: 10, weight: .bold))
                
                if shouldShowText {
                    Text(statusText)
                        .font(.system(size: 8, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(status.color.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -10)
    }
    
    private var statusIcon: some View {
        Group {
            switch status {
            case .expiringSoon:
                Image(systemName: "exclamationmark.triangle.fill")
            case .expired:
                Image(systemName: "xmark.circle.fill")
            case .refunded:
                Image(systemName: "arrow.uturn.backward.circle.fill")
            case .none:
                Image(systemName: "crown")
            default:
                Image(systemName: "crown")
            }
        }
    }
    
    private var statusText: String {
        switch status {
        case .expiringSoon: return String(localized: "expires_short")
        case .expired: return String(localized: "expired_short")
        case .refunded: return String(localized: "refunded_short")
        case .none: return String(localized: "premium_short")
        default: return ""
        }
    }
    
    private var shouldShowText: Bool {
        // Afficher le texte seulement pour les statuts critiques ou si pas d'abonnement
        switch status {
        case .expiringSoon, .expired, .refunded, .none:
            return true
        default:
            return false
        }
    }
}

// TODO: Schedule notification dot to be implemented in future version
/*
// MARK: - Scheduled Notification Dot

struct ScheduledNotificationDot: View {
    @State private var isPulsing = false
    @State private var isBreathing = false
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.yellow, .orange],
                    center: .center,
                    startRadius: 1,
                    endRadius: 4
                )
            )
            .frame(width: 6, height: 6)
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isBreathing ? 0.6 : 1.0)
            .shadow(color: .orange, radius: isPulsing ? 3 : 1)
            .offset(x: 8, y: -8) // Position en haut à droite de l'icône
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear {
                withAnimation {
                    isPulsing = true
                    isBreathing = true
                }
            }
    }
}
*/