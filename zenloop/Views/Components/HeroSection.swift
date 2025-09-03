//
//  HeroSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls
import ManagedSettings

struct HeroSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    private let horizontalPadding: CGFloat = 16
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Actions contextuelles prennent tout l'espace
            ContextualActionsSection(
                currentState: currentState,
                zenloopManager: zenloopManager
            )
            .padding(.horizontal, horizontalPadding)
            
            // Indicateur d'état compact dans le coin
            CompactStateIndicator(
                currentState: currentState,
                zenloopManager: zenloopManager
            )
            .padding(.top, 10)
            .padding(.trailing, horizontalPadding + 14)
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
        if currentState != .idle {
            Button(action: { showDetails.toggle() }) {
                // Juste l'icône sans texte
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(stateColor, lineWidth: 2)
                        )
                        .scaleEffect(currentState == .active ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: currentState == .active)
                    
                    Image(systemName: stateIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(stateColor)
                }
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(stateColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .sheet(isPresented: $showDetails) {
                StateDetailsSheet(currentState: currentState, zenloopManager: zenloopManager)
            }
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
        case .idle: return String(localized: "you_can_do_it")
        case .active: return String(localized: "you_are_focused")
        case .paused: return String(localized: "little_break")
        case .completed: return String(localized: "well_done")
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
            VStack(spacing: 16) {
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
            .navigationTitle(String(localized: "session_state"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "close")) {
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
            
            // Icône d'état avec shadow amélioré (sauf pour idle)
            if currentState != .idle {
                Image(systemName: stateIcon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(stateColor)
                    .shadow(color: stateColor.opacity(0.4), radius: 8, x: 0, y: 2)
            }
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
        VStack(spacing: 6) { // Espacement encore plus réduit
            Text(stateTitle)
                .font(.system(size: 20, weight: .bold)) // Police réduite de 22 à 20
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(stateDescription)
                .font(.system(size: 11, weight: .medium)) // Police réduite de 13 à 11
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2) // Moins de lignes
                .padding(.horizontal, 2) // Padding encore plus réduit
        }
    }
    
    private var stateTitle: String {
        switch currentState {
        case .idle: return String(localized: "ready_to_focus")
        case .active: return String(localized: "in_concentration")
        case .paused: return String(localized: "active_pause")
        case .completed: return String(localized: "mission_accomplished")
        }
    }
    
    private var stateDescription: String {
        switch currentState {
        case .idle: return String(localized: "choose_concentration_start_session")
        case .active: return String(localized: "stay_focused_progress")
        case .paused: return String(localized: "take_time_resume_ready")
        case .completed: return String(localized: "excellent_work_completed")
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
                    Text(String(localized: "progression"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    Text("\(Int(zenloopManager.currentProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "time_remaining"))
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
    @State private var showingAppSelection = false
    @State private var pendingAction: (() -> Void)? = nil
    @StateObject private var gatekeeper = PremiumGatekeeper.shared
    
    private let horizontalPadding: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 18) {
            
            // Header premium avec design moderne
            HStack {
                HStack(spacing: 16) {
                    // Container d'icône avec effet de glow
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.blue.opacity(0.4),
                                        Color.blue.opacity(0.2),
                                        Color.blue.opacity(0.05)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.blue)
                            .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "sessions"))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(String(localized: "choose_concentration_type"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Badge streak amélioré avec animation
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(.orange.opacity(0.2))
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text("3")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.6), .orange.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, horizontalPadding)
            
            // Actions en grid avec design premium - largeur cohérente
            let screenWidth = UIScreen.main.bounds.width
            let cardWidth = (screenWidth - (horizontalPadding * 2) - 24) / 2 // Padding cohérent + spacing
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: cardWidth)),
                    GridItem(.flexible(minimum: cardWidth))
                ], 
                spacing: 24
            ) {
                PremiumQuickActionButton(
                    imageAsset: "focus",
                    title: String(localized: "deep_focus"),
                    subtitle: String(localized: "maximum_concentration"),
                    duration: "60min",
                    color: .indigo,
                    action: { 
                        handleQuickAction {
                            print("🧠 [HERO] Démarrage Focus Profond - 60min")
                            zenloopManager.startQuickChallenge(duration: 60 * 60)
                        }
                    }
                )
                
                PremiumQuickActionButton(
                    imageAsset: "study",
                    title: String(localized: "study"),
                    subtitle: String(localized: "efficient_learning"),
                    duration: "45min",
                    color: .blue,
                    action: { 
                        handleQuickAction {
                            print("📚 [HERO] Démarrage Étude - 45min")
                            zenloopManager.startQuickChallenge(duration: 45 * 60)
                        }
                    }
                )
                
                PremiumQuickActionButton(
                    imageAsset: "creativite",
                    title: String(localized: "creativity"),
                    subtitle: String(localized: "artistic_expression"),
                    duration: "90min",
                    color: .purple,
                    action: { 
                        handleQuickAction {
                            print("🎨 [HERO] Démarrage Créativité - 90min")
                            zenloopManager.startQuickChallenge(duration: 90 * 60)
                        }
                    }
                )
                
                PremiumQuickActionButton(
                    imageAsset: "meditation",
                    title: String(localized: "meditation"),
                    subtitle: String(localized: "mindfulness"),
                    duration: "20min",
                    color: .green,
                    action: { 
                        handleQuickAction {
                            print("🧘 [HERO] Démarrage Méditation - 20min")
                            zenloopManager.startQuickChallenge(duration: 20 * 60)
                        }
                    }
                )
            }
            .padding(.horizontal, horizontalPadding)
            
        }
        .padding(.vertical, 8)
        .familyActivityPicker(isPresented: $showingAppSelection, selection: Binding(
            get: { zenloopManager.getAppsSelection() },
            set: { selection in
                print("📱 [HERO] FamilyActivityPicker selection changed - appTokens: \(selection.applicationTokens.count), categoryTokens: \(selection.categoryTokens.count)")
                
                zenloopManager.updateAppsSelectionWithDetails(selection)
                
                // Exécuter l'action en attente seulement si des apps ont été sélectionnées
                let hasAppsSelected = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
                print("🔍 [HERO] HasAppsSelected: \(hasAppsSelected), PendingAction: \(pendingAction != nil)")
                
                if hasAppsSelected, let action = pendingAction {
                    print("🚀 [HERO] Exécution de l'action en attente avec apps sélectionnées")
                    action()
                    pendingAction = nil
                } else if !hasAppsSelected && pendingAction != nil {
                    print("❌ [HERO] Aucune app sélectionnée, action en attente annulée")
                    pendingAction = nil
                } else if hasAppsSelected && pendingAction == nil {
                    print("ℹ️ [HERO] Apps sélectionnées mais aucune action en attente")
                }
            }
        ))
        .premiumGated()
    }
    
    private func handleQuickAction(_ action: @escaping () -> Void) {
        // D'abord vérifier si l'utilisateur peut lancer une session
        gatekeeper.performIfAllowed(.startQuickSession) {
            // Vérifier si des apps sont réellement sélectionnées
            let selection = zenloopManager.getAppsSelection()
            let hasApps = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
            
            print("🔍 [HERO] handleQuickAction - hasApps: \(hasApps), appTokens: \(selection.applicationTokens.count), categoryTokens: \(selection.categoryTokens.count)")
            
            if hasApps {
                // Apps déjà sélectionnées, lancer directement la session
                print("✅ [HERO] Apps sélectionnées, lancement direct de la session")
                action()
            } else {
                // Aucune app sélectionnée, ouvrir la sélection d'apps
                print("⚠️ [HERO] Aucune app sélectionnée, ouverture du sélecteur")
                pendingAction = action
                showingAppSelection = true
            }
        }
    }
}

// MARK: - Premium Quick Action Button

struct PremiumQuickActionButton: View {
    let imageAsset: String
    let title: String
    let subtitle: String
    let duration: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    
    private let horizontalPadding: CGFloat = 16
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                // Background container avec bordures
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.clear)
                    .overlay(
                        // Background image avec clipping strict
                        Image(imageAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: (UIScreen.main.bounds.width - (horizontalPadding * 2) - 24) / 2, height: 140)
                            .clipped()
                            .overlay(
                                // Gradient overlay sophistiqué
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.1),
                                        Color.black.opacity(0.3),
                                        Color.black.opacity(0.5),
                                        color.opacity(0.7),
                                        color.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Effet shimmer subtil avec clipping
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: shimmerOffset)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                            shimmerOffset = 200
                        }
                    }
                
                // Layout organisé avec gestion précise de l'espace
                VStack(spacing: 0) {
                    // Section header avec badge durée
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(color.opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .frame(height: 32) // Hauteur fixe pour cohérence
                    
                    // Zone centrale - espace flexible réduit
                    Spacer(minLength: 12)
                    
                    // Section footer avec informations - hauteur augmentée
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 62) // Hauteur augmentée pour plus d'espace
                    .clipped() // Empêche le débordement du texte
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
                .frame(width: (UIScreen.main.bounds.width - (horizontalPadding * 2) - 24) / 2, height: 140)
                .clipped() // Clipping du contenu global
            }
            .frame(width: (UIScreen.main.bounds.width - (horizontalPadding * 2) - 24) / 2, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isPressed ? 0.8 : 0.5),
                                color.opacity(isPressed ? 0.4 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 2.5 : 1.5
                    )
            )
            .shadow(
                color: color.opacity(isPressed ? 0.5 : 0.3),
                radius: isPressed ? 16 : 10,
                x: 0,
                y: isPressed ? 10 : 6
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Legacy Modern Quick Action Button (maintenu pour compatibilité)

struct ModernQuickActionButton: View {
    let imageAsset: String
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
            ZStack {
                // Image de background avec overlay
                Image(imageAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .overlay(
                        // Overlay dégradé pour lisibilité du texte
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.6),
                                color.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Contenu au-dessus
                VStack {
                    Spacer()
                    
                    // Titre et sous-titre avec meilleure lisibilité
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(width: (UIScreen.main.bounds.width - 64) / 2, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 2 : 1
                    )
            )
            .shadow(
                color: color.opacity(0.3),
                radius: isPressed ? 12 : 8,
                x: 0,
                y: isPressed ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.1 : 0.0)
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
                    Text(String(localized: "session_in_progress"))
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
            
            // Section pour afficher les apps/catégories bloquées pendant la session
            if zenloopManager.selectedAppsCount > 0 {
                SelectedAppsDisplaySection(zenloopManager: zenloopManager)
            }
            
            HStack(spacing: 20) {
                ModernActionButton(
                    icon: "pause.fill",
                    title: String(localized: "pause"),
                    color: .mint,
                    action: { zenloopManager.requestPause() }
                )
                
                ModernActionButton(
                    icon: "stop.fill",
                    title: String(localized: "stop"),
                    color: .red,
                    action: { zenloopManager.initiateStopWithBreathing() }
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
                    Text(String(localized: "session_paused"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(String(localized: "resume_when_ready"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.mint.opacity(0.8))
                }
                
                Spacer()
            }
            
            // Section pour afficher les apps/catégories bloquées pendant la pause
            if zenloopManager.selectedAppsCount > 0 {
                SelectedAppsDisplaySection(zenloopManager: zenloopManager)
            }
            
            HStack(spacing: 20) {
                ModernActionButton(
                    icon: "play.fill",
                    title: String(localized: "resume"),
                    color: .green,
                    action: { zenloopManager.resumeChallenge() }
                )
                
                ModernActionButton(
                    icon: "stop.fill",
                    title: String(localized: "finish"),
                    color: .red,
                    action: { zenloopManager.initiateStopWithBreathing() }
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
                    Text(String(localized: "congratulations"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(String(localized: "session_completed_successfully"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                }
                
                Spacer()
            }
            
            ModernActionButton(
                icon: "plus.circle.fill",
                title: String(localized: "new_session"),
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

// MARK: - Selected Apps Display Section

struct SelectedAppsDisplaySection: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        let selection = zenloopManager.getAppsSelection()
        let appTokens = Array(selection.applicationTokens.prefix(6))
        let categoryTokens = Array(selection.categoryTokens.prefix(6))
        let totalItems = selection.applicationTokens.count + selection.categoryTokens.count
        let displayedItems = min(12, totalItems)
        
        HStack(spacing: 0) {
            // Header compact
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
                
                Text(String(localized: "blocked_apps"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Liste horizontale compacte des icônes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Apps (max 4)
                    ForEach(Array(appTokens.prefix(4)), id: \.self) { token in
                        CompactAppItemView(token: token, isApp: true)
                    }
                    
                    // Catégories (max 4)
                    ForEach(Array(categoryTokens.prefix(4)), id: \.self) { token in
                        CompactCategoryItemView(token: token)
                    }
                    
                    // Indicateur du nombre total si plus d'éléments
                    if totalItems > 8 {
                        CompactMoreIndicator(count: totalItems - 8)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.cyan.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
}

// MARK: - Compact App Item View

struct CompactAppItemView: View {
    let token: ApplicationToken
    let isApp: Bool
    
    var body: some View {
        Label(token)
            .labelStyle(.iconOnly)
            .font(.system(size: 16))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Compact Category Item View

struct CompactCategoryItemView: View {
    let token: ActivityCategoryToken
    
    var body: some View {
        Label(token)
            .labelStyle(.iconOnly)
            .font(.system(size: 16))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.purple.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Compact More Indicator

struct CompactMoreIndicator: View {
    let count: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.1))
                .frame(width: 24, height: 24)
            
            Text("+\(count)")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
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
