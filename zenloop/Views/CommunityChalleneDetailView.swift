//
//  CommunityChallengeDetailView.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import SwiftUI
import FamilyControls

struct CommunityChalleneDetailView: View {
    let challenge: CommunityChallenge
    @ObservedObject var communityManager: CommunityManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var hasJoined = false
    @State private var showContent = false
    @State private var selectedTab: DetailTab = .overview
    @State private var currentProgress: Double = 0.0
    @State private var selectedAppsForChallenge: [String] = []
    @State private var blockingSession: BlockingSession?
    @State private var isCheckingParticipation = true
    @State private var currentParticipation: CommunityParticipant?
    
    enum DetailTab: CaseIterable {
        case overview, discussion
        
        var title: String {
            switch self {
            case .overview: return "Aperçu"
            case .discussion: return "Discussion"
            }
        }
        
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .discussion: return "bubble.left.and.bubble.right"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundGradient
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        // Header du défi
                        ChallengeDetailHeader(challenge: challenge)
                        
                        // Statut de participation active (si user a rejoint)
                        if hasJoined {
                            if let session = blockingSession {
                                ActiveParticipationView(
                                    session: session,
                                    progress: currentProgress,
                                    selectedApps: selectedAppsForChallenge
                                )
                            } else {
                                // Afficher un statut de participation sans session active
                                ParticipationWithoutBlockingView(
                                    challenge: challenge,
                                    progress: currentProgress,
                                    selectedAppsCount: selectedAppsForChallenge.count
                                )
                            }
                        }
                        
                        // Navigation par onglets
                        ChallengeDetailTabBar(selectedTab: $selectedTab)
                        
                        // Contenu selon l'onglet
                        Group {
                            switch selectedTab {
                            case .overview:
                                ChallengeOverviewSection(challenge: challenge)
                            case .discussion:
                                ChallengeDiscussionSection(
                                    challenge: challenge,
                                    communityManager: communityManager
                                )
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Bouton de participation flottant
                VStack {
                    Spacer()
                    
                    ChallengeJoinButton(
                        challenge: challenge,
                        hasJoined: hasJoined,
                        isLoading: isCheckingParticipation,
                        currentProgress: currentProgress,
                        onJoin: {
                            if hasJoined {
                                // Si défi terminé, ne rien faire, sinon permettre de quitter
                                if currentProgress < 1.0 {
                                    leaveChallenege()
                                }
                            } else {
                                showingAppSelection = true
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 50)
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showContent)
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fermer") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            joinChallenge(with: newSelection)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
            checkExistingParticipation()
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.12),
                Color(red: 0.06, green: 0.03, blue: 0.15),
                Color(red: 0.08, green: 0.02, blue: 0.18),
                challenge.category.color.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private func joinChallenge(with selection: FamilyActivitySelection) {
        let hasApps = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        
        guard hasApps else {
            print("⚠️ [JOIN_CHALLENGE] No apps selected")
            return
        }
        
        Task {
            // Utiliser la méthode atomique du CommunityManager
            let success = await communityManager.joinChallengeAtomic(challenge, selectedApps: selection)
            
            await MainActor.run {
                if success {
                    // Succès : mettre à jour l'interface
                    let totalApps = selection.applicationTokens.count + selection.categoryTokens.count
                    selectedAppsForChallenge = Array(repeating: "App", count: totalApps)
                    hasJoined = true
                    
                    // Récupérer l'état mis à jour
                    let participationState = communityManager.getParticipationState(for: challenge.id)
                    blockingSession = participationState.blockingSession
                    currentParticipation = participationState.participant
                    
                    // Feedback haptique de succès
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Démarrer le suivi de progression
                    startProgressTracking()
                    
                    print("✅ [JOIN_CHALLENGE] Challenge joined successfully via atomic method")
                } else {
                    // Échec : garder l'état actuel
                    print("❌ [JOIN_CHALLENGE] Failed to join challenge via atomic method")
                }
            }
        }
    }
    
    private func startProgressTracking() {
        // Mettre à jour la progression toutes les 30 secondes
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if let session = blockingSession {
                currentProgress = ScreenTimeManager.shared.calculateProgress(for: challenge.id)
                
                // Si terminé, marquer comme complété
                if currentProgress >= 1.0 {
                    hasJoined = false
                    blockingSession = nil
                }
            }
        }
    }
    
    private func leaveChallenege() {
        // Supprimer d'abord la persistance locale
        communityManager.removeStoredParticipation(for: challenge.id)
        
        // Ensuite quitter sur Firebase
        communityManager.leaveChallenge(challenge.id)
        
        // Réinitialiser l'état local
        hasJoined = false
        blockingSession = nil
        selectedAppsForChallenge = []
        currentProgress = 0.0
        currentParticipation = nil
        
        // Notifier les autres vues que la participation a changé
        NotificationCenter.default.post(
            name: NSNotification.Name("ChallengeParticipationChanged"),
            object: nil,
            userInfo: ["challengeId": challenge.id]
        )
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("🚪 [PARTICIPATION] Left challenge and cleared local data: \(challenge.id)")
    }
    
    private func checkExistingParticipation() {
        // Utiliser la source unique de vérité
        let participationState = communityManager.getParticipationState(for: challenge.id)
        
        hasJoined = participationState.isParticipating
        isCheckingParticipation = false
        
        if participationState.isParticipating {
            // Charger les détails depuis l'état centralisé
            loadExistingParticipationDetails(from: participationState)
        }
        
        print("✅ [PERSISTENCE] Loaded participation state: \(participationState.status) for challenge: \(challenge.id)")
    }
    
    private func loadExistingParticipationDetails(from participationState: ChallengeParticipationState) {
        // Charger directement depuis l'état centralisé
        currentParticipation = participationState.participant
        currentProgress = participationState.participant?.progress ?? 0.0
        blockingSession = participationState.blockingSession
        
        // Charger les apps sélectionnées
        if let selectedApps = participationState.selectedApps {
            let totalApps = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
            selectedAppsForChallenge = Array(repeating: "App", count: totalApps)
        }
        
        // Démarrer le suivi si la participation est active
        if participationState.status == .active && currentProgress < 1.0 {
            startProgressTracking()
        }
        
        print("✅ [CENTRALIZED] Loaded participation details from centralized state")
    }
    
}

// MARK: - Challenge Detail Header

struct ChallengeDetailHeader: View {
    let challenge: CommunityChallenge
    
    var body: some View {
        VStack(spacing: 20) {
            // Badge et titre
            VStack(spacing: 12) {
                // Badge de catégorie large
                HStack(spacing: 8) {
                    Image(systemName: challenge.category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(challenge.category.color)
                    
                    Text(challenge.category.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(challenge.category.color)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(challenge.difficulty.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(challenge.difficulty.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                
                // Titre principal
                Text(challenge.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(challenge.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            // Statistiques principales
            HStack(spacing: 30) {
                DetailStatItem(
                    icon: "person.3.fill",
                    value: String(challenge.participantCount),
                    subtitle: "Participants",
                    color: .blue
                )
                
                DetailStatItem(
                    icon: "clock.fill", 
                    value: challenge.timeRemainingFormatted,
                    subtitle: "Restant",
                    color: .orange
                )
                
                DetailStatItem(
                    icon: "star.fill",
                    value: "\(challenge.reward.points)",
                    subtitle: "Points",
                    color: .yellow
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Detail Stat Item

struct DetailStatItem: View {
    let icon: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Challenge Detail Tab Bar

struct ChallengeDetailTabBar: View {
    @Binding var selectedTab: CommunityChalleneDetailView.DetailTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CommunityChalleneDetailView.DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                        
                        Text(tab.title)
                            .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                            AnyView(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            ) :
                            AnyView(Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Challenge Join Button

struct ChallengeJoinButton: View {
    let challenge: CommunityChallenge
    let hasJoined: Bool
    let isLoading: Bool
    let currentProgress: Double
    let onJoin: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: isLoading ? {} : onJoin) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if hasJoined && currentProgress > 0 {
                        Text("\(Int(currentProgress * 100))% terminé")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: hasJoined ? 
                        [.red.opacity(0.8), .red] :
                        [challenge.category.color, challenge.category.color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? 0.1 : 0.0)
            .shadow(color: (hasJoined ? Color.red : challenge.category.color).opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .disabled(isLoading)
    }
    
    private var buttonText: String {
        if isLoading {
            return "Vérification..."
        } else if hasJoined {
            if currentProgress >= 1.0 {
                return "Défi terminé!"
            } else {
                return "Défi en cours"
            }
        } else {
            return "Rejoindre le défi"
        }
    }
    
    private var buttonIcon: String {
        if hasJoined {
            if currentProgress >= 1.0 {
                return "trophy.fill"
            } else {
                return "play.circle.fill"
            }
        } else {
            return "plus.circle.fill"
        }
    }
}

// MARK: - Sections de contenu (placeholders pour l'instant)

struct ChallengeOverviewSection: View {
    let challenge: CommunityChallenge
    @State private var userSelectedApps = FamilyActivitySelection()
    @State private var isLoadingApps = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Apps sélectionnées par l'utilisateur (si participant)
            if !userSelectedApps.applicationTokens.isEmpty || !userSelectedApps.categoryTokens.isEmpty {
                UserSelectedAppsSection(selectedApps: userSelectedApps)
            }
            // Récompenses
            VStack(alignment: .leading, spacing: 12) {
                Text("Récompenses")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    Text(challenge.reward.badge)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.reward.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(challenge.reward.points) points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Apps suggérées
            if !challenge.suggestedApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apps suggérées à bloquer")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(challenge.suggestedApps, id: \.self) { appName in
                            Text(appName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .onAppear {
            loadUserSelectedApps()
        }
    }
    
    private func loadUserSelectedApps() {
        // Prioriser les apps persistées pour afficher les vraies icônes
        if let persistedSelection = CommunityManager.shared.getFamilyActivitySelection(for: challenge.id) {
            userSelectedApps = persistedSelection
            print("✅ [APPS_DISPLAY] Loaded \(persistedSelection.applicationTokens.count) apps from persistence")
        } else if let session = ScreenTimeManager.shared.getActiveSession(for: challenge.id) {
            userSelectedApps = session.selectedApps
            print("✅ [APPS_DISPLAY] Loaded \(session.selectedApps.applicationTokens.count) apps from active session")
        } else {
            userSelectedApps = FamilyActivitySelection()
            print("⚠️ [APPS_DISPLAY] No apps found for challenge: \(challenge.id)")
        }
        
        isLoadingApps = false
    }
}

// MARK: - User Selected Apps Section

struct UserSelectedAppsSection: View {
    let selectedApps: FamilyActivitySelection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                
                Text("Mes apps bloquées")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                let totalCount = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
                Text("\(totalCount) app\(totalCount > 1 ? "s" : "")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Utiliser le vrai composant SelectedAppsView pour afficher les icônes
            SelectedAppsView(selection: selectedApps, maxDisplayCount: 8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ChallengeDiscussionSection: View {
    let challenge: CommunityChallenge
    @ObservedObject var communityManager: CommunityManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Intégrer le système de chat complet
            CommunityDiscussionView(
                challenge: challenge,
                communityManager: communityManager
            )
            .frame(height: 400)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct ChallengeParticipantsSection: View {
    let challenge: CommunityChallenge
    let communityManager: CommunityManager
    @State private var showingSortOptions = false
    @State private var sortBy: ParticipantSortOption = .rank
    @State private var participants: [CommunityParticipant] = []
    @State private var isLoading = true
    @State private var challengeStats: (active: Int, completed: Int, averageProgress: Double) = (0, 0, 0.0)
    
    enum ParticipantSortOption: String, CaseIterable {
        case rank = "Classement"
        case progress = "Progression"
        case joinDate = "Date d'inscription"
        case username = "Nom d'utilisateur"
        
        var icon: String {
            switch self {
            case .rank: return "trophy.fill"
            case .progress: return "chart.bar.fill"
            case .joinDate: return "calendar"
            case .username: return "person.fill"
            }
        }
    }
    
    private var sortedParticipants: [CommunityParticipant] {
        switch sortBy {
        case .rank:
            return participants.sorted { $0.rank < $1.rank }
        case .progress:
            return participants.sorted { $0.progress > $1.progress }
        case .joinDate:
            return participants.sorted { $0.joinedAt < $1.joinedAt }
        case .username:
            return participants.sorted { $0.username < $1.username }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                // État de chargement
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    
                    Text("Chargement des participants...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // En-tête avec statistiques
                ParticipantsHeaderView(
                    challenge: challenge,
                    stats: challengeStats
                )
                
                // Options de tri
                if !participants.isEmpty {
                    ParticipantsSortBar(
                        selectedSort: $sortBy,
                        showingSortOptions: $showingSortOptions
                    )
                }
                
                // Liste des participants ou état vide
                if participants.isEmpty {
                    EmptyParticipantsView(challenge: challenge)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedParticipants) { participant in
                            ParticipantCard(participant: participant)
                        }
                    }
                }
                
                // Footer avec informations
                ParticipantsFooterView(challenge: challenge)
            }
        }
        .onAppear {
            Task {
                await loadParticipants()
            }
        }
        .refreshable {
            await loadParticipants()
        }
    }
    
    private func loadParticipants() async {
        isLoading = true
        
        async let participantsData = communityManager.getChallengeParticipants(challenge.id)
        async let statsData = communityManager.getChallengeStatistics(challenge.id)
        
        let (loadedParticipants, loadedStats) = await (participantsData, statsData)
        
        await MainActor.run {
            self.participants = loadedParticipants
            self.challengeStats = loadedStats
            self.isLoading = false
        }
    }
}

// MARK: - Participants Header

struct ParticipantsHeaderView: View {
    let challenge: CommunityChallenge
    let stats: (active: Int, completed: Int, averageProgress: Double)
    
    var body: some View {
        VStack(spacing: 16) {
            // Titre
            HStack {
                Text("Participants")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Badge du nombre de participants
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("\(challenge.participantCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.4), lineWidth: 1)
                )
            }
            
            // Statistiques rapides
            HStack(spacing: 20) {
                StatItemView(
                    title: "Actifs",
                    value: "\(stats.active)",
                    color: .green,
                    icon: "play.circle.fill"
                )
                
                StatItemView(
                    title: "Terminés",
                    value: "\(stats.completed)",
                    color: .yellow,
                    icon: "checkmark.circle.fill"
                )
                
                StatItemView(
                    title: "Moyenne",
                    value: "\(Int(stats.averageProgress * 100))%",
                    color: .orange,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                Spacer()
            }
        }
    }
}

// MARK: - Stat Item

struct StatItemView: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Sort Bar

struct ParticipantsSortBar: View {
    @Binding var selectedSort: ChallengeParticipantsSection.ParticipantSortOption
    @Binding var showingSortOptions: Bool
    
    var body: some View {
        HStack {
            Text("Trier par:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showingSortOptions.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: selectedSort.icon)
                        .font(.system(size: 12, weight: .semibold))
                    
                    Text(selectedSort.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(showingSortOptions ? 180 : 0))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 4)
        
        // Options de tri déroulantes
        if showingSortOptions {
            VStack(spacing: 8) {
                ForEach(ChallengeParticipantsSection.ParticipantSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            selectedSort = option
                            showingSortOptions = false
                        }
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selectedSort == option ? .blue : .white.opacity(0.7))
                            
                            Text(option.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedSort == option ? .white : .white.opacity(0.8))
                            
                            Spacer()
                            
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedSort == option ?
                            .blue.opacity(0.15) : .white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }
            .padding(.top, 8)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Participant Card

struct ParticipantCard: View {
    let participant: CommunityParticipant
    
    var body: some View {
        HStack(spacing: 16) {
            // Rang
            VStack {
                Text("#\(participant.rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rankColor)
                
                if participant.rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(rankColor)
                }
            }
            .frame(width: 40)
            
            // Avatar et infos
            VStack(alignment: .leading, spacing: 6) {
                // Nom et badges
                HStack {
                    Text(participant.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Badges
                    HStack(spacing: 4) {
                        ForEach(participant.badges.prefix(3), id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 14))
                        }
                    }
                }
                
                // Progression et statut
                HStack {
                    // Barre de progression
                    ProgressView(value: participant.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .accentColor(participant.statusColor)
                        .scaleEffect(x: 1, y: 0.8)
                    
                    // Pourcentage
                    Text("\(participant.progressPercentage)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(participant.statusColor)
                        .frame(width: 40, alignment: .trailing)
                }
                
                // Informations supplémentaires
                HStack {
                    // Statut
                    HStack(spacing: 4) {
                        Circle()
                            .fill(participant.statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(participant.statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Streak
                    if participant.streakCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                            
                            Text("\(participant.streakCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Date d'inscription
                    Text("Rejoint \(participant.formattedJoinDate)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch participant.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white.opacity(0.7)
        }
    }
    
    private var rankIcon: String {
        switch participant.rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return ""
        }
    }
}

// MARK: - Empty Participants View

struct EmptyParticipantsView: View {
    let challenge: CommunityChallenge
    
    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Aucun participant pour l'instant")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Sois le premier à rejoindre ce défi et montre l'exemple à la communauté !")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Informations sur le défi
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Défi actif jusqu'au \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(challenge.maxParticipants) places disponibles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
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

// MARK: - Participants Footer

struct ParticipantsFooterView: View {
    let challenge: CommunityChallenge
    
    var body: some View {
        VStack(spacing: 12) {
            // Séparateur
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Information sur les places disponibles
            if challenge.participantCount < challenge.maxParticipants {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("\(challenge.maxParticipants - challenge.participantCount) places restantes sur \(challenge.maxParticipants)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("Défi complet - \(challenge.maxParticipants) participants")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            // Note sur la mise à jour en temps réel
            Text("La liste se met à jour automatiquement")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .padding(.top, 20)
    }
}

// MARK: - Active Participation View

struct ActiveParticipationView: View {
    let session: BlockingSession
    let progress: Double
    let selectedApps: [String] // Gardé pour compatibilité mais on utilisera session.selectedApps
    
    var body: some View {
        VStack(spacing: 16) {
            // Header de participation active
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Défi en cours")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))% terminé")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Barre de progression
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(.green)
                .scaleEffect(x: 1, y: 1.5)
            
            // Temps restant et apps
            HStack(spacing: 20) {
                // Temps restant
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temps restant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(timeRemainingText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Apps bloquées
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Apps bloquées")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    let totalApps = session.selectedApps.applicationTokens.count + session.selectedApps.categoryTokens.count
                    Text("\(totalApps) app\(totalApps > 1 ? "s" : "")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            // Aperçu des apps sélectionnées avec vraies icônes
            if !session.selectedApps.applicationTokens.isEmpty || !session.selectedApps.categoryTokens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apps bloquées:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Affichage horizontal compact des vraies icônes
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // Applications individuelles
                            ForEach(Array(session.selectedApps.applicationTokens.prefix(6)), id: \.self) { token in
                                Label(token)
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 20))
                                    .frame(width: 28, height: 28)
                                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            // Catégories
                            ForEach(Array(session.selectedApps.categoryTokens.prefix(3)), id: \.self) { token in
                                Label(token)
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 20))
                                    .frame(width: 28, height: 28)
                                    .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Indicateur "plus d'apps" si nécessaire
                            let totalApps = session.selectedApps.applicationTokens.count + session.selectedApps.categoryTokens.count
                            if totalApps > 9 {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 28, height: 28)
                                    
                                    Text("+\(totalApps - 9)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .green.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var timeRemainingText: String {
        let remaining = session.timeRemaining
        
        if remaining <= 0 {
            return "Terminé!"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Participation Without Blocking View

struct ParticipationWithoutBlockingView: View {
    let challenge: CommunityChallenge
    let progress: Double
    let selectedAppsCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Header de participation
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    
                    Text("Défi rejoint - Blocage en attente")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))% terminé")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Barre de progression
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(.orange)
                .scaleEffect(x: 1, y: 1.5)
            
            // Message informatif
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("Le blocage des apps est en cours d'activation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
                
                Text("Assure-toi d'avoir autorisé l'accès à Screen Time dans les Réglages pour que tes \(selectedAppsCount) apps soient bloquées.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    CommunityChalleneDetailView(
        challenge: CommunityChallenge(
            id: "test",
            title: "Journée sans IA",
            description: "Test description",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            participantCount: 42,
            maxParticipants: 100,
            suggestedApps: ["ChatGPT", "Claude"],
            category: .productivity,
            difficulty: .medium,
            reward: CommunityReward(points: 100, badge: "🤖", title: "Anti-IA Pioneer")
        ),
        communityManager: CommunityManager.shared
    )
}

*/