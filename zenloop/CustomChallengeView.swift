//
//  CustomChallengeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import FamilyControls

struct CustomChallengeView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var screenTimeManager: ScreenTimeManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var challengeTitle = ""
    @State private var challengeDescription = ""
    @State private var selectedDuration: TimeInterval = 30 * 60 // 30 minutes par défaut
    @State private var selectedDifficulty: CommunityDifficulty = .medium
    @State private var appSelection = FamilyActivitySelection()
    @State private var showingAppPicker = false
    @State private var isCreatingChallenge = false
    
    let durationOptions: [(String, TimeInterval)] = [
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 heure", 60 * 60),
        ("2 heures", 2 * 60 * 60),
        ("4 heures", 4 * 60 * 60),
        ("Toute la journée", 24 * 60 * 60)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    titleSection
                    
                    durationSection
                    
                    difficultySection
                    
                    appSelectionSection
                    
                    createButton
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Nouveau Défi")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Annuler") {
                    isPresented = false
                },
                trailing: EmptyView()
            )
        }
        .sheet(isPresented: $showingAppPicker) {
            FamilyActivityPickerView(
                selection: $appSelection,
                isPresented: $showingAppPicker,
                onConfirm: { selection in
                    appSelection = selection
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Créer un défi personnalisé")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Configurez votre défi de bien-être numérique")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nom du défi", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Ex: Focus travail", text: $challengeTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Description (optionnel)", text: $challengeDescription)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Durée", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(durationOptions, id: \.0) { option in
                    Button(action: {
                        selectedDuration = option.1
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Text(option.0)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedDuration == option.1 ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedDuration == option.1 ? Color.accentColor : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Difficulté", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ForEach(CommunityDifficulty.allCases, id: \.self) { level in
                    Button(action: {
                        selectedDifficulty = level
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: level.icon)
                                .font(.subheadline)
                            
                            Text(level.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedDifficulty == level ? .white : level.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedDifficulty == level ? level.color : level.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Applications à bloquer", systemImage: "apps.iphone")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                showingAppPicker = true
            }) {
                HStack {
                    Image(systemName: appSelection.applicationTokens.isEmpty ? "plus.circle" : "checkmark.circle.fill")
                        .foregroundColor(appSelection.applicationTokens.isEmpty ? .secondary : .green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appSelection.applicationTokens.isEmpty ? "Sélectionner des apps" : "Apps sélectionnées")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(appSelection.applicationTokens.isEmpty ? "Choisissez les apps à bloquer" : "\(appSelection.applicationTokens.count) apps sélectionnées")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var createButton: some View {
        DynamicButton(
            title: "Créer et démarrer le défi",
            subtitle: challengeTitle.isEmpty ? "Donnez un nom à votre défi" : challengeTitle,
            icon: isCreatingChallenge ? "hourglass" : "play.fill",
            style: .primary,
            hapticStyle: .heavy
        ) {
            createAndStartChallenge()
        }
        .disabled(challengeTitle.isEmpty || appSelection.applicationTokens.isEmpty || isCreatingChallenge)
        .opacity((challengeTitle.isEmpty || appSelection.applicationTokens.isEmpty) ? 0.6 : 1.0)
    }
    
    private func createAndStartChallenge() {
        guard !challengeTitle.isEmpty, !appSelection.applicationTokens.isEmpty else { return }
        
        isCreatingChallenge = true
        
        // Créer un nouveau défi communautaire personnalisé
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(selectedDuration)
        
        let customChallenge = CommunityChallenge(
            id: UUID().uuidString,
            title: challengeTitle,
            description: challengeDescription.isEmpty ? "Défi personnalisé" : challengeDescription,
            startDate: startDate,
            endDate: endDate,
            participantCount: 0,

            
            maxParticipants: 10, // Défaut pour défis personnalisés
            suggestedApps: extractAppNames(from: appSelection),
            category: .focus, // Défaut pour défis personnalisés
            difficulty: selectedDifficulty,
            reward: CommunityReward(
                points: calculateRewardPoints(difficulty: selectedDifficulty, duration: selectedDuration),
                badge: getBadgeForDifficulty(selectedDifficulty),
                title: "Créateur de Défi"
            )
        )
        
        Task {
            do {
                // Participer automatiquement au défi créé
                communityManager.joinChallenge(customChallenge, selectedApps: appSelection)
                
                // Ajouter aux défis disponibles localement pour compatibilité
                await MainActor.run {
                    dataManager.availableChallenges.append(customChallenge)
                }
                
                await MainActor.run {
                    isCreatingChallenge = false
                    isPresented = false
                    
                    // Feedback de succès
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
                
            } catch {
                await MainActor.run {
                    isCreatingChallenge = false
                    print("Erreur lors du démarrage du défi: \(error)")
                    
                    // Feedback d'erreur
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    private func extractAppNames(from selection: FamilyActivitySelection) -> [String] {
        // En production, on utiliserait l'API pour récupérer les noms d'apps
        // Pour l'instant, on simule avec des noms génériques
        var appNames: [String] = []
        
        for _ in selection.applicationTokens {
            appNames.append("App Sélectionnée")
        }
        
        for _ in selection.categoryTokens {
            appNames.append("Catégorie Sélectionnée")
        }
        
        return appNames
    }
    
    private func calculateRewardPoints(difficulty: CommunityDifficulty, duration: TimeInterval) -> Int {
        let basePoints = Int(duration / 60) // 1 point par minute
        
        let multiplier: Double = switch difficulty {
        case .easy: 1.0
        case .medium: 1.5
        case .hard: 2.0
        }
        
        return Int(Double(basePoints) * multiplier)
    }
    
    private func getBadgeForDifficulty(_ difficulty: CommunityDifficulty) -> String {
        switch difficulty {
        case .easy: return "🌟"
        case .medium: return "⚡"
        case .hard: return "🏆"
        }
    }
}

#Preview {
    CustomChallengeView(isPresented: .constant(true))
        .environmentObject(ScreenTimeManager.shared)
        .environmentObject(DataManager.shared)
        .environmentObject(CommunityManager.shared)
}