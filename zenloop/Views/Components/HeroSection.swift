//
//  HeroSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct HeroSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Actions contextuelles prennent tout l'espace
            ContextualActionsSection(
                currentState: currentState,
                zenloopManager: zenloopManager
            )
            .padding(.horizontal, 20)
            
            // Indicateur d'état compact dans le coin
            CompactStateIndicator(
                currentState: currentState,
                zenloopManager: zenloopManager
            )
            .padding(.top, 10)
            .padding(.trailing, 30)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 50)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Compact State Indicator

struct CompactStateIndicator: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails.toggle() }) {
            HStack(spacing: 8) {
                // Indicateur visuel minimal
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(stateColor, lineWidth: 2)
                        )
                        .scaleEffect(currentState == .active ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: currentState == .active)
                    
                    Image(systemName: stateIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(stateColor)
                }
                
                // Texte d'état compact
                Text(stateTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                // Progress si session active
                if currentState == .active && zenloopManager.currentProgress > 0 {
                    Text("\(Int(zenloopManager.currentProgress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(stateColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stateColor.opacity(0.2), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(stateColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showDetails) {
            StateDetailsSheet(currentState: currentState, zenloopManager: zenloopManager)
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
    
    private var stateIcon: String {
        switch currentState {
        case .idle: return "brain.head.profile"
        case .active: return "timer"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        }
    }
    
    private var stateTitle: String {
        switch currentState {
        case .idle: return "Prêt"
        case .active: return "Actif"
        case .paused: return "Pause"
        case .completed: return "Terminé"
        }
    }
}

// MARK: - State Details Sheet

struct StateDetailsSheet: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Indicateur visuel principal
                StateVisualIndicator(currentState: currentState)
                
                // Informations détaillées
                StateInfoSection(currentState: currentState)
                
                // Section de progression (si applicable)
                if let challenge = zenloopManager.currentChallenge, currentState == .active {
                    ProgressSection(challenge: challenge, stateColor: stateColor, zenloopManager: zenloopManager)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Actions selon l'état
                ContextualActionsSection(
                    currentState: currentState,
                    zenloopManager: zenloopManager
                )
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("État de la Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var stateColor: Color {
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
}

// MARK: - State Visual Indicator

struct StateVisualIndicator: View {
    let currentState: ZenloopState
    
    var body: some View {
        ZStack {
            // Cercles d'animation concentriques
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(stateColor.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
                    .frame(width: 110 + CGFloat(index * 15), height: 110 + CGFloat(index * 15))
                    .scaleEffect(currentState == .active ? 1.0 + Double(index) * 0.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0 + Double(index) * 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: currentState == .active
                    )
            }
            
            // Cercle principal avec dégradé
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            stateColor.opacity(0.4),
                            stateColor.opacity(0.2),
                            stateColor.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 110, height: 110)
                .overlay(
                    Circle()
                        .stroke(stateColor.opacity(0.3), lineWidth: 2)
                )
                .scaleEffect(currentState == .active ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: currentState == .active)
            
            // Icône d'état avec shadow amélioré
            Image(systemName: stateIcon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(stateColor)
                .shadow(color: stateColor.opacity(0.4), radius: 8, x: 0, y: 2)
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
    
    private var stateIcon: String {
        switch currentState {
        case .idle: return "brain.head.profile"
        case .active: return "timer"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        }
    }
}

// MARK: - State Info Section

struct StateInfoSection: View {
    let currentState: ZenloopState
    
    var body: some View {
        VStack(spacing: 8) { // Espacement réduit
            Text(stateTitle)
                .font(.system(size: 22, weight: .bold)) // Police réduite
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(stateDescription)
                .font(.system(size: 13, weight: .medium)) // Police réduite
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(2) // Moins de lignes
                .padding(.horizontal, 4) // Padding réduit
        }
    }
    
    private var stateTitle: String {
        switch currentState {
        case .idle: return "Prêt à Focus"
        case .active: return "En Concentration"
        case .paused: return "Pause Active"
        case .completed: return "Mission Accomplie!"
        }
    }
    
    private var stateDescription: String {
        switch currentState {
        case .idle: return "Choisis ton type de concentration et commence une session"
        case .active: return "Reste concentré, tu progresses vers ton objectif"
        case .paused: return "Prends ton temps, reprend quand tu es prêt"
        case .completed: return "Excellent travail! Tu as terminé ta session avec succès"
        }
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    let challenge: ZenloopChallenge
    let stateColor: Color
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 12) { // Espacement réduit
            // Barre de progression améliorée
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background de la barre
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.15))
                        .frame(height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    // Barre de progression avec dégradé
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [stateColor, stateColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * zenloopManager.currentProgress, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(stateColor.opacity(0.3), lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.5), value: zenloopManager.currentProgress)
                }
            }
            .frame(height: 8)
            
            // Informations de progression redesignées
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRESSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    Text("\(Int(zenloopManager.currentProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TEMPS RESTANT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    Text(zenloopManager.currentTimeRemaining)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(stateColor)
                }
            }
        }
    }
}

// MARK: - Contextual Actions Section

struct ContextualActionsSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        switch currentState {
        case .idle:
            ModernQuickActionsRow(zenloopManager: zenloopManager)
        case .active:
            ModernActiveChallengeActions(zenloopManager: zenloopManager)
        case .paused:
            ModernPausedActions(zenloopManager: zenloopManager)
        case .completed:
            CompletedActions(zenloopManager: zenloopManager)
        }
    }
}

// MARK: - Modern Quick Actions Row

struct ModernQuickActionsRow: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 16) {
            // En-tête de section plus proéminent
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commencer une Session")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Choisis ton type de concentration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Actions en grid (espacement réduit)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ModernQuickActionButton(
                    icon: "brain.head.profile",
                    title: "Focus Profond",
                    subtitle: "Concentration maximale",
                    color: .indigo,
                    action: { 
                        print("🧠 [HERO] Démarrage Focus Profond - 60min")
                        zenloopManager.startQuickChallenge(duration: 60 * 60)
                    }
                )
                
                ModernQuickActionButton(
                    icon: "book.fill",
                    title: "Étude",
                    subtitle: "Apprentissage efficace",
                    color: .blue,
                    action: { 
                        print("📚 [HERO] Démarrage Étude - 45min")
                        zenloopManager.startQuickChallenge(duration: 45 * 60)
                    }
                )
                
                ModernQuickActionButton(
                    icon: "paintbrush.fill",
                    title: "Créativité",
                    subtitle: "Expression artistique",
                    color: .purple,
                    action: { 
                        print("🎨 [HERO] Démarrage Créativité - 90min")
                        zenloopManager.startQuickChallenge(duration: 90 * 60)
                    }
                )
                
                ModernQuickActionButton(
                    icon: "leaf.fill",
                    title: "Méditation",
                    subtitle: "Pleine conscience",
                    color: .green,
                    action: { 
                        print("🧘 [HERO] Démarrage Méditation - 20min")
                        zenloopManager.startQuickChallenge(duration: 20 * 60)
                    }
                )
            }
        }
    }
}

// MARK: - Modern Quick Action Button

struct ModernQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Feedback haptique
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 6) {
                // Icône avec dégradé (plus petite)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
                
                // Texte hiérarchisé (plus compact)
                VStack(spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 70) // Hauteur réduite
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(isPressed ? 0.3 : 0.1), lineWidth: isPressed ? 2 : 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? 0.1 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Modern Active Challenge Actions

struct ModernActiveChallengeActions: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête avec info session
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session en Cours")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let challenge = zenloopManager.currentChallenge {
                        Text("\(challenge.title) • \(zenloopManager.currentTimeRemaining)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                ModernActionButton(
                    icon: "pause.fill",
                    title: "Pause",
                    color: .mint,
                    action: { zenloopManager.requestPause() }
                )
                
                ModernActionButton(
                    icon: "stop.fill",
                    title: "Arrêter",
                    color: .red,
                    action: { zenloopManager.stopCurrentChallenge() }
                )
            }
        }
    }
}

// MARK: - Modern Paused Actions

struct ModernPausedActions: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête avec info pause
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session en Pause")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Reprends quand tu es prêt")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.mint.opacity(0.8))
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                ModernActionButton(
                    icon: "play.fill",
                    title: "Reprendre",
                    color: .green,
                    action: { zenloopManager.resumeChallenge() }
                )
                
                ModernActionButton(
                    icon: "stop.fill",
                    title: "Terminer",
                    color: .red,
                    action: { zenloopManager.stopCurrentChallenge() }
                )
            }
        }
    }
}

// MARK: - Completed Actions

struct CompletedActions: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête avec félicitations
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bravo! 🎉")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Session terminée avec succès")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                Spacer()
            }
            
            ModernActionButton(
                icon: "plus.circle.fill",
                title: "Nouvelle Session",
                color: .purple,
                action: { 
                    print("🔄 [HERO] Retour à idle pour nouvelle session")
                    zenloopManager.resetToIdle() 
                }
            )
        }
    }
}

// MARK: - Modern Action Button

struct ModernActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Feedback haptique
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(color.opacity(isPressed ? 0.6 : 0.3), lineWidth: isPressed ? 2 : 1)
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

#Preview {
    HeroSection(
        currentState: .idle,
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}