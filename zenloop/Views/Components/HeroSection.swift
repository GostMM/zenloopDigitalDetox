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

            // Indicateur de difficulté
            DifficultyIndicator(difficulty: challenge.difficulty)
        }
    }
}

// MARK: - Difficulty Indicator

struct DifficultyIndicator: View {
    let difficulty: DifficultyLevel

    private var modeInfo: (title: String, description: String, icon: String) {
        switch difficulty {
        case .easy:
            return (
                String(localized: "difficulty_easy_mode"),
                String(localized: "difficulty_easy_desc"),
                "shield.lefthalf.filled"
            )
        case .medium:
            return (
                String(localized: "difficulty_medium_mode"),
                String(localized: "difficulty_medium_desc"),
                "shield.fill"
            )
        case .hard:
            return (
                String(localized: "difficulty_hard_mode"),
                String(localized: "difficulty_hard_desc"),
                "eye.slash.fill"
            )
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                difficulty.color.opacity(0.2),
                                difficulty.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: difficulty.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(difficulty.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(difficulty.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    HStack(spacing: 4) {
                        Image(systemName: modeInfo.icon)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(difficulty.color.opacity(0.8))

                        Text(modeInfo.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(difficulty.color.opacity(0.9))
                    }
                }

                Text(modeInfo.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            difficulty.color.opacity(0.12),
                            difficulty.color.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(difficulty.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Contextual Actions Section

struct ContextualActionsSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager

    var body: some View {
        switch currentState {
        case .idle:
            EmptyView()
        case .active:
            ModernActiveChallengeActions(zenloopManager: zenloopManager)
        case .paused:
            ModernPausedActions(zenloopManager: zenloopManager)
        case .completed:
            CompletedActions(zenloopManager: zenloopManager)
        }
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

            // Objectif/Tâche si défini
            if let challenge = zenloopManager.currentChallenge, let taskGoal = challenge.taskGoal, !taskGoal.isEmpty {
                TaskGoalCard(taskGoal: taskGoal, zenloopManager: zenloopManager)
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


// MARK: - Task Goal Card

struct TaskGoalCard: View {
    let taskGoal: String
    @ObservedObject var zenloopManager: ZenloopManager

    // Parser les tâches du string (format: "✅ Task 1\n⭕️ Task 2\n...")
    private var tasks: [(emoji: String, text: String, isCompleted: Bool)] {
        let lines = taskGoal.split(separator: "\n").map(String.init)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("✅") {
                let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                return ("✅", text, true)
            } else if trimmed.hasPrefix("⭕️") {
                let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                return ("⭕️", text, false)
            }
            return nil
        }
    }

    private func toggleTask(at index: Int) {
        guard index < tasks.count else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Reconstruire le taskGoal avec le statut changé
        var updatedTasks = tasks
        updatedTasks[index].isCompleted.toggle()

        let newTaskGoal = updatedTasks.map { task in
            task.isCompleted ? "✅ \(task.text)" : "⭕️ \(task.text)"
        }.joined(separator: "\n")

        // Mettre à jour dans le ZenloopManager
        zenloopManager.updateTaskGoal(newTaskGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow)

                Text(String(localized: "your_goal"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Compteur de tâches complétées
                let completedCount = tasks.filter { $0.isCompleted }.count
                Text("\(completedCount)/\(tasks.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.yellow.opacity(0.15))
                    )
            }

            // Liste des tâches
            VStack(spacing: 8) {
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    Button(action: {
                        toggleTask(at: index)
                    }) {
                        HStack(spacing: 10) {
                            // Emoji de statut (cliquable)
                            Text(task.emoji)
                                .font(.system(size: 16))

                            // Texte de la tâche
                            Text(task.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(task.isCompleted ? .white.opacity(0.5) : .white)
                                .strikethrough(task.isCompleted, color: .green)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(task.isCompleted ? Color.green.opacity(0.08) : Color.yellow.opacity(0.05))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.yellow.opacity(0.3), lineWidth: 1)
                )
        )
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
