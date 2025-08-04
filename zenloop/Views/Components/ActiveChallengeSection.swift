//
//  ActiveChallengeSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct ActiveChallengeSection: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            activeChallengeHeader
            
            // Contenu principal
            if let challenge = zenloopManager.currentChallenge {
                challengeDetailsCard(challenge: challenge)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
    
    // MARK: - Sub-components
    
    private var activeChallengeHeader: some View {
        HStack {
            Text("Session Active")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            StatusBadge(state: zenloopManager.currentState)
        }
        .padding(.horizontal, 20)
    }
    
    private func challengeDetailsCard(challenge: ZenloopChallenge) -> some View {
        VStack(spacing: 16) {
            challengeInfo(challenge: challenge)
            progressSection
            blockedAppsSection(challenge: challenge)
            // Note: Les boutons d'action sont gérés par HeroSection > ContextualActionsSection
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(stateColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func challengeInfo(challenge: ZenloopChallenge) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Commencé à \(formatTime(challenge.startTime))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            DifficultyBadge(difficulty: challenge.difficulty)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Barre de progression
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(stateGradient)
                        .frame(width: geometry.size.width * zenloopManager.currentProgress, height: 12)
                        .animation(.easeInOut(duration: 0.5), value: zenloopManager.currentProgress)
                }
            }
            .frame(height: 12)
            
            // Stats de progression
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progression")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(Int(zenloopManager.currentProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Temps Restant")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(zenloopManager.currentTimeRemaining)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(stateColor)
                }
            }
        }
    }
    
    private func blockedAppsSection(challenge: ZenloopChallenge) -> some View {
        Group {
            if challenge.blockedAppsCount > 0 {
                VStack(spacing: 12) {
                    SelectedAppsView(selection: zenloopManager.getAppsSelection(), maxDisplayCount: 6)
                    
                    if challenge.appOpenAttempts > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            
                            Text("\(challenge.appOpenAttempts) tentative\(challenge.appOpenAttempts > 1 ? "s" : "") d'ouverture")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    
    private var stateColor: Color {
        switch zenloopManager.currentState {
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        default: return .cyan
        }
    }
    
    private var stateGradient: LinearGradient {
        LinearGradient(
            colors: [stateColor, stateColor.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "Inconnue" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let state: ZenloopState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)
            
            Text(stateText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(stateColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(stateColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
    
    private var stateText: String {
        switch state {
        case .idle: return "Libre"
        case .active: return "Actif"
        case .paused: return "Pause"
        case .completed: return "Terminé"
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: DifficultyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 10))
                .foregroundColor(difficulty.color)
            
            Text(difficulty.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(difficulty.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ActiveChallengeSection(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}