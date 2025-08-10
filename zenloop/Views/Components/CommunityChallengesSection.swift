//
//  CommunityChallengesSection.swift  
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import SwiftUI
import FamilyControls

struct CommunityChallengesSection: View {
    @ObservedObject var communityManager: CommunityManager
    let showContent: Bool
    @State private var selectedChallenge: CommunityChallenge?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header de section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Défis Communautaires")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Rejoins la communauté et relève des défis ensemble")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Indicateur de défis actifs
                if !communityManager.activeChallenges.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showContent)
                        
                        Text("\(communityManager.activeChallenges.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.2), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.green.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            
            // Liste des défis actifs
            if communityManager.activeChallenges.isEmpty {
                EmptyCommunityChallengesView()
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(communityManager.activeChallenges) { challenge in
                        CommunityChallengeCard(
                            challenge: challenge,
                            onTap: {
                                selectedChallenge = challenge
                            }
                        )
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
        .sheet(item: $selectedChallenge) { challenge in
            CommunityChalleneDetailView(
                challenge: challenge,
                communityManager: communityManager
            )
        }
    }
}

// MARK: - Community Challenge Card

struct CommunityChallengeCard: View {
    let challenge: CommunityChallenge
    let onTap: () -> Void
    @State private var isPressed = false
    @ObservedObject private var communityManager = CommunityManager.shared
    
    // Computed property basé sur la source unique de vérité
    private var participationState: ChallengeParticipationState {
        return communityManager.getParticipationState(for: challenge.id)
    }
    
    private var buttonColors: [Color] {
        switch participationState.status {
        case .joining:
            return [.orange, .orange.opacity(0.8)]
        case .active:
            return participationState.hasActiveBlocking ? 
                [.green, .green.opacity(0.8)] : 
                [.blue, .blue.opacity(0.8)]
        case .completed:
            return [.yellow, .yellow.opacity(0.8)]
        case .failed:
            return [.red, .red.opacity(0.8)]
        case .notParticipating:
            return [challenge.category.color, challenge.category.color.opacity(0.8)]
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header avec catégorie et difficulté
                HStack {
                    // Badge de catégorie
                    HStack(spacing: 6) {
                        Image(systemName: challenge.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(challenge.category.color)
                        
                        Text(challenge.category.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(challenge.category.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(challenge.category.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(challenge.category.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    // Indicateur de difficulté
                    DifficultyIndicator(difficulty: challenge.difficulty)
                }
                
                // Titre et description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(challenge.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    
                    Text(challenge.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Statistiques du défi
                HStack(spacing: 20) {
                    // Participants
                    ChallengeStatItem(
                        icon: "person.3.fill",
                        value: "\(challenge.participantCount)",
                        label: "Participants",
                        color: .blue
                    )
                    
                    // Temps restant
                    ChallengeStatItem(
                        icon: "clock.fill",
                        value: challenge.timeRemainingFormatted,
                        label: "Restant",
                        color: .orange
                    )
                    
                    // Récompense
                    ChallengeStatItem(
                        icon: "star.fill",
                        value: "\(challenge.reward.points)",
                        label: "Points",
                        color: .yellow
                    )
                    
                    Spacer()
                }
                
                // Apps sélectionnées (si l'utilisateur participe) ou apps suggérées
                if participationState.isParticipating && participationState.selectedApps != nil {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                            
                            Text("Mes apps bloquées:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            let totalApps = (participationState.selectedApps?.applicationTokens.count ?? 0) + (participationState.selectedApps?.categoryTokens.count ?? 0)
                            Text("\(totalApps) app\(totalApps > 1 ? "s" : "")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2), in: Capsule())
                        }
                        
                        // Afficher les vraies icônes des apps sélectionnées
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // Applications individuelles
                                ForEach(Array((participationState.selectedApps?.applicationTokens ?? []).prefix(6)), id: \.self) { token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .font(.system(size: 16))
                                        .frame(width: 24, height: 24)
                                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                
                                // Indicateur "plus d'apps" si nécessaire
                                let totalApps = (participationState.selectedApps?.applicationTokens.count ?? 0) + (participationState.selectedApps?.categoryTokens.count ?? 0)
                                if totalApps > 6 {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.white.opacity(0.1))
                                            .frame(width: 24, height: 24)
                                        
                                        Text("+\(totalApps - 6)")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                } else if !participationState.isParticipating && !challenge.suggestedApps.isEmpty {
                    // Apps suggérées (preview) - seulement si pas encore participé
                    VStack(spacing: 8) {
                        HStack {
                            Text("Apps suggérées:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(challenge.suggestedApps.prefix(5), id: \.self) { appName in
                                    SuggestedAppTag(appName: appName)
                                }
                                
                                if challenge.suggestedApps.count > 5 {
                                    Text("+\(challenge.suggestedApps.count - 5)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.1), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
                
                // Bouton d'action
                HStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        switch participationState.status {
                        case .joining:
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                            Text("Rejointe en cours...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                        case .active, .completed:
                            Image(systemName: participationState.hasActiveBlocking ? "lock.shield.fill" : "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(participationState.hasActiveBlocking ? "Apps bloquées" : "Défi en cours")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                        case .failed:
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Échec participation")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                        case .notParticipating:
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Rejoindre le défi")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: buttonColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
            .shadow(color: challenge.category.color.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Challenge Stat Item

struct ChallengeStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Difficulty Indicator

struct DifficultyIndicator: View {
    let difficulty: CommunityDifficulty
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < difficultyLevel ? difficulty.color : difficulty.color.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            
            Text(difficulty.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(difficulty.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(difficulty.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var difficultyLevel: Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Suggested App Tag

struct SuggestedAppTag: View {
    let appName: String
    
    var body: some View {
        Text(appName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Empty State

struct EmptyCommunityChallengesView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text("Aucun défi actif")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Les nouveaux défis communautaires apparaîtront ici. Reste connecté pour ne rien manquer !")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    CommunityChallengesSection(
        communityManager: CommunityManager.shared,
        showContent: true
    )
    .background(Color.black)
}

*/