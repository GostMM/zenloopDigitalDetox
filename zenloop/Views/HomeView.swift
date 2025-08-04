//
//  HomeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @StateObject private var badgeManager = BadgeManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showContent = false
    @State private var backgroundOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background plus sombre et intense pour focus sur les badges
            IntenseBackground(currentState: zenloopManager.currentState)
                .ignoresSafeArea(.all, edges: .all)
            
            // Interface principale
            VStack(spacing: 0) {
                // Header minimaliste
                MinimalHeader(
                    showContent: showContent,
                    currentState: zenloopManager.currentState
                )
                .padding(.horizontal, 20)
               
                
                // Contenu principal avec espacement amélioré
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 32) { // Espacement optimisé entre sections
                        // Logique d'affichage selon l'état
                        if zenloopManager.currentState == .idle {
                            // État IDLE : Afficher apps sélectionnées + actions OU HeroSection
                            if zenloopManager.isAppsSelectionValid() {
                                VStack(spacing: 16) {
                                    SelectedAppsInlineCard(
                                        zenloopManager: zenloopManager,
                                        showContent: showContent
                                    )
                                    
                                    InlineQuickActionsRow(
                                        zenloopManager: zenloopManager,
                                        showContent: showContent
                                    )
                                }
                                .padding(.top, 30)
                            } else {
                                HeroSection(
                                    currentState: zenloopManager.currentState,
                                    zenloopManager: zenloopManager,
                                    showContent: showContent
                                )
                                .padding(.top, 30)
                            }
                        } else {
                            // État ACTIF/PAUSE : Afficher HeroSection avec ContextualActions (Pause/Stop)
                            HeroSection(
                                currentState: zenloopManager.currentState,
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                            .padding(.top, 30)
                        }
                        
                        // Timer Card - priorité principale (uniquement si idle)
                        if zenloopManager.currentState == .idle {
                            TimerCard(zenloopManager: zenloopManager, showContent: showContent)
                        }
                        
                        // Défis par catégorie - juste après TimerCard (uniquement si IDLE)
                        if zenloopManager.currentState == .idle {
                            CategoryChallengesRow(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                            .padding(.top, -16) // Rapprocher du TimerCard
                        }
                        
                        // Section active challenge - priorité quand actif
                        if zenloopManager.currentState != .idle {
                            ActiveChallengeSection(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                            .padding(.top, 30)
                        }
                        
                        // Section stats compacte - toujours visible mais plus discrète
                        StatsInsightsSection(
                            badgeManager: badgeManager,
                            zenloopManager: zenloopManager,
                            showContent: showContent
                        )
                        
                        // Section motivation - uniquement si idle
                        if zenloopManager.currentState == .idle {
                            MotivationSection(showContent: showContent, zenloopManager: zenloopManager)
                        }
                        
                        // Historique en bas - plus discret
                        RecentActivitySection(
                            zenloopManager: zenloopManager,
                            showContent: showContent
                        )
                        
                        // Espace de respiration en bas
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 0) // Retirer le padding global pour laisser les composants gérer leurs propres marges
                }
                .frame(maxHeight: .infinity)
            }
            
            // Plus de bottom bar - maintenant intégrée en carte
            
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                showContent = true
            }
            startBackgroundAnimation()
            badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
        }
        .onChange(of: zenloopManager.currentState) { _, _ in
            badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
        }
    }
    
    // MARK: - Safe Area helpers
    
    private func getSafeAreaTop() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.top
    }
    
    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
    
    private func getTabBarHeight() -> CGFloat {
        // Hauteur standard de la tab bar iOS (49pt + safe area)
        return 49
    }
    
    // MARK: - Animation d'arrière-plan
    
    private func startBackgroundAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            backgroundOffset += 1
        }
    }
}

// MARK: - Selected Apps Inline Card

struct SelectedAppsInlineCard: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Header avec titre et nombre d'apps
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("Apps sélectionnées")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(zenloopManager.selectedAppsCount) app\(zenloopManager.selectedAppsCount > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Scroll horizontal des apps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let selection = zenloopManager.getAppsSelection()
                    
                    // Afficher jusqu'à 8 apps pour éviter la performance
                    ForEach(Array(selection.applicationTokens.prefix(8)), id: \.self) { token in
                        VStack(spacing: 6) {
                            // Icône de l'app
                            Label(token)
                                .labelStyle(.iconOnly)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            
                            // Nom de l'app (optionnel, si on veut l'afficher)
                            /*
                            Text(token.localizedDisplayName ?? "App")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .frame(maxWidth: 40)
                            */
                        }
                    }
                    
                    // Indicateur s'il y a plus d'apps
                    if selection.applicationTokens.count > 8 {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Text("+\(selection.applicationTokens.count - 8)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
}

// MARK: - Inline Quick Actions Row (sans card)

struct InlineQuickActionsRow: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    private let quickActions = [
        QuickAction(
            id: "focus",
            icon: "brain.head.profile",
            title: "Focus Profond",
            subtitle: "60min",
            color: .indigo,
            duration: 60 * 60
        ),
        QuickAction(
            id: "study",
            icon: "book.fill",
            title: "Étude",
            subtitle: "45min",
            color: .blue,
            duration: 45 * 60
        ),
        QuickAction(
            id: "creative",
            icon: "paintbrush.fill",
            title: "Créativité",
            subtitle: "90min",
            color: .purple,
            duration: 90 * 60
        ),
        QuickAction(
            id: "meditation",
            icon: "leaf.fill",
            title: "Méditation",
            subtitle: "20min",
            color: .green,
            duration: 20 * 60
        ),
        QuickAction(
            id: "work",
            icon: "briefcase.fill",
            title: "Travail",
            subtitle: "120min",
            color: .orange,
            duration: 120 * 60
        ),
        QuickAction(
            id: "pomodoro",
            icon: "timer",
            title: "Pomodoro",
            subtitle: "25min",
            color: .red,
            duration: 25 * 60
        )
    ]
    
    var body: some View {
        // Scroll horizontal des actions (directement sans card)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickActions) { action in
                    InlineQuickActionButton(
                        action: action,
                        onTap: {
                            startQuickAction(action)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
    
    private func startQuickAction(_ action: QuickAction) {
        print("🚀 [INLINE_ACTIONS] Démarrage: \(action.title) - \(action.subtitle)")
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Démarrer avec les apps déjà sélectionnées
        let difficulty: DifficultyLevel = action.duration <= 1800 ? .easy : action.duration <= 3600 ? .medium : .hard
        
        zenloopManager.startCustomChallenge(
            title: "\(action.title) - \(action.subtitle)",
            duration: TimeInterval(action.duration),
            difficulty: difficulty,
            apps: zenloopManager.getAppsSelection()
        )
    }
}

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let duration: Int
}

// MARK: - Inline Quick Action Button

struct InlineQuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            // Format horizontal inline [ 🧠 Focus 60min]
            HStack(spacing: 8) {
                // Icône
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(action.color)
                
                // Titre
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Durée
                Text(action.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(action.color.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Apps Selected Indicator (Legacy - à supprimer)

struct AppsSelectedIndicator: View {
    let count: Int
    @State private var isPressed = false
    @State private var showPulse = false
    
    var body: some View {
        Button {
            // Action pour afficher les détails des apps sélectionnées
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    // Pulse animation background
                    Circle()
                        .fill(.green.opacity(0.3))
                        .frame(width: showPulse ? 32 : 24, height: showPulse ? 32 : 24)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showPulse)
                    
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(count == 1 ? "app" : "apps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.green.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? 0.1 : 0.0)
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            showPulse = true
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ZenloopManager.shared)
}
