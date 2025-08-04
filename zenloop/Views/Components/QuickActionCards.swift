//
//  QuickActionCards.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct QuickActionCards: View {
    let showContent: Bool
    @ObservedObject var zenloopManager: ZenloopManager
    let onSessionStarted: (() -> Void)?
    @State private var selectedCard: String? = nil
    @State private var showStartedFeedback = false
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var pendingPreset: QuickPreset? = nil
    
    init(showContent: Bool, zenloopManager: ZenloopManager, onSessionStarted: (() -> Void)? = nil) {
        self.showContent = showContent
        self.zenloopManager = zenloopManager
        self.onSessionStarted = onSessionStarted
    }
    
    // Presets enrichis avec plus d'options
    private let quickPresets: [QuickPreset] = [
        QuickPreset(
            id: "pomodoro",
            title: "Pomodoro",
            subtitle: "25 min",
            description: "Technique de concentration classique",
            icon: "timer",
            duration: 25 * 60,
            primaryColor: .orange,
            accentColor: .red,
            difficulty: .medium,
            popularityScore: 95
        ),
        QuickPreset(
            id: "deep",
            title: "Deep Focus",
            subtitle: "60 min",
            description: "Concentration profonde et continue",
            icon: "brain.head.profile",
            duration: 60 * 60,
            primaryColor: .blue,
            accentColor: .purple,
            difficulty: .hard,
            popularityScore: 85
        ),
        QuickPreset(
            id: "sprint",
            title: "Sprint",
            subtitle: "15 min",
            description: "Session rapide et intense",
            icon: "bolt.fill",
            duration: 15 * 60,
            primaryColor: .yellow,
            accentColor: .orange,
            difficulty: .easy,
            popularityScore: 78
        ),
        QuickPreset(
            id: "flow",
            title: "Flow State",
            subtitle: "90 min",
            description: "Immersion totale et créativité",
            icon: "infinity",
            duration: 90 * 60,
            primaryColor: .purple,
            accentColor: .pink,
            difficulty: .hard,
            popularityScore: 62
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête de section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessions Rapides")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Démarre instantanément avec nos presets optimisés")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Indicateur de popularité
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    
                    Text("Populaire")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            // Grid amélioré 2x2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(quickPresets, id: \.id) { preset in
                    EnhancedQuickActionCard(
                        preset: preset,
                        isSelected: selectedCard == preset.id,
                        action: {
                            selectAndStart(preset)
                        }
                    )
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
        .overlay(
            // Feedback visuel de démarrage
            startedFeedbackOverlay
        )
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            // Apps sélectionnées - mettre à jour et démarrer automatiquement
            if !newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty,
               let preset = pendingPreset {
                print("✅ [QUICK_ACTIONS] Apps sélectionnées pour \(preset.title) - démarrage automatique")
                
                // Mettre à jour la sélection globale
                zenloopManager.updateAppsSelectionWithDetails(newSelection)
                
                // Démarrer le défi automatiquement
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startQuickChallengeWithSelectedApps(preset)
                    pendingPreset = nil
                }
            }
        }
        .onAppear {
            selectedApps = zenloopManager.getAppsSelection()
        }
    }
    
    private func selectAndStart(_ preset: QuickPreset) {
        print("🎯 [QUICK_ACTIONS] Sélection preset: \(preset.title) (\(Int(preset.duration/60))min)")
        
        // Vérifier si des apps sont sélectionnées
        if zenloopManager.isAppsSelectionValid() {
            // Démarrer directement avec les apps sélectionnées
            startQuickChallengeWithSelectedApps(preset)
        } else {
            // Ouvrir le picker d'apps pour sélectionner
            print("📱 [QUICK_ACTIONS] Ouverture du picker d'apps pour \(preset.title)")
            pendingPreset = preset
            selectedApps = zenloopManager.getAppsSelection()
            showingAppSelection = true
        }
    }
    
    private func startQuickChallengeWithDefaults(_ preset: QuickPreset) {
        // Animation de sélection
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCard = preset.id
        }
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Feedback visuel immédiat
        withAnimation(.easeInOut(duration: 0.5)) {
            showStartedFeedback = true
        }
        
        // Démarrage après un léger délai pour l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            zenloopManager.startQuickChallenge(duration: preset.duration)
            selectedCard = nil
            
            // Feedback de succès
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            print("✅ [QUICK_ACTIONS] Session démarrée avec apps par défaut: \(preset.title)")
            
            // Appeler le callback de navigation si fourni
            onSessionStarted?()
            
            // Masquer le feedback après 2 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showStartedFeedback = false
                }
            }
        }
    }
    
    private func startQuickChallengeWithSelectedApps(_ preset: QuickPreset) {
        // Animation de sélection
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCard = preset.id
        }
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Feedback visuel immédiat
        withAnimation(.easeInOut(duration: 0.5)) {
            showStartedFeedback = true
        }
        
        // Démarrage avec les apps sélectionnées
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            zenloopManager.startCustomChallenge(
                title: preset.title,
                duration: preset.duration,
                difficulty: preset.difficulty,
                apps: zenloopManager.getAppsSelection()
            )
            selectedCard = nil
            
            // Feedback de succès
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            print("✅ [QUICK_ACTIONS] Session démarrée avec apps sélectionnées: \(preset.title)")
            
            // Appeler le callback de navigation si fourni
            onSessionStarted?()
            
            // Masquer le feedback après 2 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showStartedFeedback = false
                }
            }
        }
    }
    
    // MARK: - Feedback Overlay
    
    @ViewBuilder
    private var startedFeedbackOverlay: some View {
        if showStartedFeedback {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("Session Démarrée !")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Retourne à l'accueil pour voir ton défi")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.green.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .green.opacity(0.3), radius: 15, x: 0, y: 8)
            .scaleEffect(showStartedFeedback ? 1.0 : 0.8)
            .opacity(showStartedFeedback ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showStartedFeedback)
        }
    }
}

// MARK: - Quick Preset Model

struct QuickPreset {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let duration: TimeInterval
    let primaryColor: Color
    let accentColor: Color
    let difficulty: DifficultyLevel
    let popularityScore: Int
}

// MARK: - Enhanced Quick Action Card

struct EnhancedQuickActionCard: View {
    let preset: QuickPreset
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Header avec difficulté
                HStack {
                    QuickActionDifficultyBadge(difficulty: preset.difficulty)
                    
                    Spacer()
                    
                    // Popularité indicator
                    if preset.popularityScore > 80 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                
                // Icône principale avec animation
                ZStack {
                    // Background circles
                    Circle()
                        .fill(preset.primaryColor.opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [preset.primaryColor.opacity(0.3), preset.accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(preset.primaryColor.opacity(0.4), lineWidth: 2)
                        )
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(preset.primaryColor)
                        .shadow(color: preset.primaryColor.opacity(0.3), radius: 4)
                }
                .scaleEffect(isPressed ? 0.9 : (isSelected ? 1.1 : 1.0))
                .rotationEffect(.degrees(isSelected ? 5 : 0))
                
                // Contenu textuel
                VStack(spacing: 8) {
                    // Titre seul
                    Text(preset.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Durée sur sa propre ligne
                    Text(preset.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(preset.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(preset.primaryColor.opacity(0.2), in: Capsule())
                    
                    // Description
                    Text(preset.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Progress indicator (si sélectionné)
                if isSelected {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(preset.primaryColor)
                                .frame(width: 6, height: 6)
                                .scaleEffect(1.0 + Double(index) * 0.2)
                                .opacity(0.8 - Double(index) * 0.2)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isSelected
                                )
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: isSelected ? 
                                    [preset.primaryColor.opacity(0.6), preset.accentColor.opacity(0.4)] :
                                    [.white.opacity(0.1), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? 0.05 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Quick Action Difficulty Badge

struct QuickActionDifficultyBadge: View {
    let difficulty: DifficultyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<difficultyLevel, id: \.self) { _ in
                Circle()
                    .fill(difficultyColor)
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private var difficultyLevel: Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .red
        }
    }
}

// MARK: - Legacy Quick Action Button (pour compatibilité)

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    QuickActionCards(showContent: true, zenloopManager: ZenloopManager.shared)
        .background(Color.black)
}