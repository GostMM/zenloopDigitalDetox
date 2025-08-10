//
//  ModernChallengesView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct ModernChallengesView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var showingCreateChallenge = false
    @State private var savedChallenges: [SavedChallenge] = []
    
    var body: some View {
        ZStack {
            // Background style cohérent avec HomeView
            IntenseBackground(currentState: zenloopManager.currentState)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Défis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Crée des sessions personnalisées")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 30) {
                        // Quick Actions
                        QuickActionCards(
                            showContent: showContent,
                            zenloopManager: zenloopManager,
                            onSessionStarted: {
                                // Navigation vers l'onglet Home après démarrage d'une session
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    NotificationCenter.default.post(name: .navigateToHome, object: nil)
                                }
                            }
                        )
                        .padding(.top, 30)
                        .padding(.horizontal, 20)
                        
                        // Défis personnalisés
                        CustomChallengesSection(
                            showContent: showContent,
                            savedChallenges: $savedChallenges,
                            zenloopManager: zenloopManager,
                            onCreateChallenge: { showingCreateChallenge = true },
                            onStartChallenge: { challenge in startSavedChallenge(challenge) }
                        )
                        
                        Spacer(minLength: 100)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                showContent = true
            }
            loadSavedChallenges()
            
            // Créer des défis par défaut si c'est la première fois
            if savedChallenges.isEmpty && !UserDefaults.standard.bool(forKey: "has_created_default_challenges") {
                createDefaultChallenges()
                UserDefaults.standard.set(true, forKey: "has_created_default_challenges")
            }
        }
        .sheet(isPresented: $showingCreateChallenge) {
            CreateChallengeSheet(
                onSave: { challenge in
                    saveChallengeTemplate(challenge)
                    showingCreateChallenge = false
                },
                onCancel: { showingCreateChallenge = false }
            )
        }
    }
    
    // MARK: - Méthodes de gestion des défis
    
    private func loadSavedChallenges() {
        if let data = UserDefaults.standard.data(forKey: "saved_challenges"),
           let challenges = try? JSONDecoder().decode([SavedChallenge].self, from: data) {
            savedChallenges = challenges
        }
    }
    
    private func saveChallengeTemplate(_ challenge: SavedChallenge) {
        savedChallenges.append(challenge)
        if let data = try? JSONEncoder().encode(savedChallenges) {
            UserDefaults.standard.set(data, forKey: "saved_challenges")
        }
    }
    
    private func startSavedChallenge(_ challenge: SavedChallenge) {
        print("🎯 [CHALLENGES] Tentative de démarrage du défi: \(challenge.title)")
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Vérifier si des apps sont sélectionnées
        guard zenloopManager.isAppsSelectionValid() else {
            print("⚠️ [CHALLENGES] Aucune app sélectionnée - redirection vers la configuration")
            
            // Feedback d'erreur
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.warning)
            
            // Rediriger vers l'onglet Home où se trouve le TimerCard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .navigateToHome, object: nil)
            }
            return
        }
        
        print("🚀 [CHALLENGES] Démarrage défi sauvegardé: \(challenge.title)")
        
        // Démarrer le défi avec le titre personnalisé
        let customChallenge = ZenloopChallenge(
            id: "saved-\(challenge.id.uuidString)",
            title: challenge.title,
            description: challenge.description,
            duration: TimeInterval(challenge.durationMinutes * 60),
            difficulty: challenge.difficulty,
            startTime: Date(),
            isActive: true
        )
        
        // Utiliser la méthode interne pour démarrer avec le défi personnalisé
        zenloopManager.startSavedCustomChallenge(customChallenge)
    }
    
    private func createDefaultChallenges() {
        let defaultChallenges = [
            SavedChallenge(
                title: "Focus Matinal",
                description: "Commence ta journée avec concentration",
                durationMinutes: 30,
                difficulty: .easy,
                iconName: "sunrise.fill",
                color: .orange
            ),
            SavedChallenge(
                title: "Deep Work",
                description: "Session de travail profond",
                durationMinutes: 90,
                difficulty: .hard,
                iconName: "brain.head.profile",
                color: .blue
            ),
            SavedChallenge(
                title: "Pause Étude",
                description: "Révisions concentrées",
                durationMinutes: 45,
                difficulty: .medium,
                iconName: "book.fill",
                color: .green
            ),
            SavedChallenge(
                title: "Créativité",
                description: "Session créative sans distractions",
                durationMinutes: 60,
                difficulty: .medium,
                iconName: "paintbrush.fill",
                color: .purple
            )
        ]
        
        savedChallenges = defaultChallenges
        
        // Sauvegarder les défis par défaut
        if let data = try? JSONEncoder().encode(savedChallenges) {
            UserDefaults.standard.set(data, forKey: "saved_challenges")
        }
        
        print("✅ [CHALLENGES] Défis par défaut créés: \(defaultChallenges.count)")
    }
}

// MARK: - Custom Challenges Section

struct CustomChallengesSection: View {
    let showContent: Bool
    @Binding var savedChallenges: [SavedChallenge]
    let zenloopManager: ZenloopManager
    let onCreateChallenge: () -> Void
    let onStartChallenge: (SavedChallenge) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Défis Personnalisés")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Créer") {
                    onCreateChallenge()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                if savedChallenges.isEmpty {
                    EmptyChallengesView(onCreateChallenge: onCreateChallenge)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(savedChallenges) { challenge in
                            SavedChallengeCard(
                                challenge: challenge,
                                zenloopManager: zenloopManager,
                                onStart: { onStartChallenge(challenge) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
    }
}

struct EmptyChallengesView: View {
    let onCreateChallenge: () -> Void
    
    var body: some View {
        Button(action: onCreateChallenge) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "plus.circle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.cyan)
                }
                
                VStack(spacing: 8) {
                    Text("Aucun défi personnalisé")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Tape pour créer ton premier défi sur mesure")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.cyan.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 24)
    }
}

// MARK: - Data Models

struct SavedChallenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let durationMinutes: Int
    let difficulty: DifficultyLevel
    let createdAt: Date
    var iconName: String
    var color: CodableColor
    
    init(title: String, description: String, durationMinutes: Int, difficulty: DifficultyLevel, iconName: String = "target", color: Color = .blue) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.durationMinutes = durationMinutes
        self.difficulty = difficulty
        self.createdAt = Date()
        self.iconName = iconName
        self.color = CodableColor(color)
    }
}


// MARK: - Saved Challenge Card

struct SavedChallengeCard: View {
    let challenge: SavedChallenge
    @ObservedObject var zenloopManager: ZenloopManager
    let onStart: () -> Void
    @State private var isPressed = false
    @State private var isStarted = false
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var hasInitiallyLoaded = false
    
    private var canStart: Bool {
        let result = zenloopManager.isAppsSelectionValid()
        print("🔄 [CHALLENGE_CARD] CanStart pour \(challenge.title): \(result)")
        return result
    }
    
    var body: some View {
        Button(action: {
            if canStart {
                // Animation de démarrage
                withAnimation(.easeInOut(duration: 0.2)) {
                    isStarted = true
                }
                
                // Feedback haptique
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Démarrage avec délai pour l'animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStart()
                    
                    // Navigation automatique vers Home
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NotificationCenter.default.post(name: .navigateToHome, object: nil)
                    }
                    
                    // Reset de l'animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isStarted = false
                        }
                    }
                }
            } else {
                // Ouvrir le picker d'apps pour sélectionner
                print("📱 [CHALLENGE_CARD] Ouverture du picker d'apps pour \(challenge.title)")
                selectedApps = zenloopManager.getAppsSelection()
                showingAppSelection = true
            }
        }) {
            VStack(spacing: 16) {
                // Icon avec badge de difficulté
                ZStack {
                    Circle()
                        .fill(challenge.color.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(challenge.color.color)
                }
                .overlay(
                    // Badge de difficulté
                    HStack(spacing: 4) {
                        Image(systemName: challenge.difficulty.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(challenge.difficulty.rawValue)
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(challenge.difficulty.color, in: Capsule())
                    .offset(x: 20, y: -20)
                )
                
                // Contenu textuel
                VStack(spacing: 8) {
                    Text(challenge.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("\(challenge.durationMinutes) min")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Bouton start avec état
                HStack(spacing: 6) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 10, weight: .bold))
                    Text(buttonText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(buttonColor, in: Capsule())
                .animation(.easeInOut(duration: 0.2), value: isStarted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(challenge.color.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? -0.1 : 0.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            // Ne déclencher l'action que si ce n'est pas le chargement initial
            guard hasInitiallyLoaded else {
                print("🔄 [CHALLENGE_CARD] Chargement initial - pas de démarrage automatique")
                return
            }
            
            // Apps sélectionnées - mettre à jour et démarrer automatiquement
            if !newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty {
                print("✅ [CHALLENGE_CARD] Apps sélectionnées pour \(challenge.title) - démarrage automatique")
                
                // Mettre à jour la sélection globale
                zenloopManager.updateAppsSelectionWithDetails(newSelection)
                
                // Démarrer le défi automatiquement
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStart()
                    
                    // Navigation automatique vers Home
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NotificationCenter.default.post(name: .navigateToHome, object: nil)
                    }
                }
            }
        }
        .onAppear {
            selectedApps = zenloopManager.getAppsSelection()
            // Marquer comme chargé après la mise à jour initiale
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasInitiallyLoaded = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonIcon: String {
        if isStarted {
            return "checkmark"
        } else if !canStart {
            return "plus.app"
        } else {
            return "play.fill"
        }
    }
    
    private var buttonText: String {
        if isStarted {
            return "Démarré !"
        } else if !canStart {
            return "Choisir & Lancer"
        } else {
            return "Démarrer"
        }
    }
    
    private var buttonColor: Color {
        if isStarted {
            return .green
        } else if !canStart {
            return .orange
        } else {
            return challenge.color.color
        }
    }
}

// MARK: - Create Challenge Sheet

struct CreateChallengeSheet: View {
    @State private var title = ""
    @State private var description = ""
    @State private var durationMinutes = 25
    @State private var selectedDifficulty: DifficultyLevel = .medium
    @State private var selectedIcon = "target"
    @State private var selectedColor: Color = .blue
    
    let onSave: (SavedChallenge) -> Void
    let onCancel: () -> Void
    
    private let availableDurations = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    private let availableIcons = ["target", "brain.head.profile", "bolt.fill", "flame.fill", "leaf.fill", "timer", "focus.ring", "trophy.fill"]
    private let availableColors: [Color] = [.blue, .cyan, .green, .orange, .purple, .pink, .red, .indigo]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                        Color(red: 0.08, green: 0.02, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Preview card
                        SavedChallengeCard(
                            challenge: SavedChallenge(
                                title: title.isEmpty ? "Mon Défi" : title,
                                description: description,
                                durationMinutes: durationMinutes,
                                difficulty: selectedDifficulty,
                                iconName: selectedIcon,
                                color: selectedColor
                            ),
                            zenloopManager: ZenloopManager.shared, // Manager pour la preview
                            onStart: {}
                        )
                        .frame(maxWidth: 180)
                        .padding(.top, 20)
                        
                        VStack(spacing: 18) {
                            // Titre
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Titre du défi")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextField("Ex: Focus Matinal", text: $title)
                                    .textFieldStyle(CompactTextFieldStyle())
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (optionnel)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextField("Ex: Session de focus", text: $description)
                                    .textFieldStyle(CompactTextFieldStyle())
                            }
                            
                            // Durée
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Durée")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(availableDurations, id: \.self) { duration in
                                            Button("\(duration)min") {
                                                durationMinutes = duration
                                            }
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(durationMinutes == duration ? .white : .white.opacity(0.7))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                durationMinutes == duration ? selectedColor : .clear,
                                                in: Capsule()
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // Difficulté
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Difficulté")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    ForEach(DifficultyLevel.allCases) { difficulty in
                                        Button {
                                            selectedDifficulty = difficulty
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: difficulty.icon)
                                                    .font(.system(size: 10))
                                                Text(difficulty.rawValue)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundColor(selectedDifficulty == difficulty ? .white : .white.opacity(0.7))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedDifficulty == difficulty ? difficulty.color : .clear,
                                                in: Capsule()
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Icône
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Icône")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                    ForEach(availableIcons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.7))
                                                .frame(width: 50, height: 50)
                                                .background(
                                                    selectedIcon == icon ? selectedColor : .clear,
                                                    in: RoundedRectangle(cornerRadius: 12)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                            
                            // Couleur
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Couleur")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    ForEach(availableColors, id: \.self) { color in
                                        Button {
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Circle()
                                                        .stroke(.white, lineWidth: selectedColor == color ? 2 : 0)
                                                )
                                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                                .animation(.easeInOut(duration: 0.2), value: selectedColor == color)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle("Nouveau Défi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        onCancel()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        let challenge = SavedChallenge(
                            title: title.isEmpty ? "Mon Défi" : title,
                            description: description,
                            durationMinutes: durationMinutes,
                            difficulty: selectedDifficulty,
                            iconName: selectedIcon,
                            color: selectedColor
                        )
                        onSave(challenge)
                    }
                    .foregroundColor(.cyan)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct CompactTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.white)
            .font(.system(size: 15, weight: .medium))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}


#Preview {
    ModernChallengesView()
        .environmentObject(ZenloopManager.shared)
}