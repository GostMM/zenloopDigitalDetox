//
//  ScreenTimeManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import Foundation
import UIKit
import FamilyControls
import DeviceActivity
import ManagedSettings

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    @Published var activeChallenge: Challenge?
    @Published var blockedApps: Set<ApplicationToken> = []
    
    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    private var shieldActionTimer: Timer?
    
    private init() {
        checkAuthorizationStatus()
        startListeningForShieldActions()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await checkAuthorizationStatus()
            print("✅ Autorisation Screen Time accordée")
        } catch {
            print("❌ Erreur autorisation Screen Time: \(error)")
            // L'app peut toujours fonctionner en mode limité
            authorizationStatus = .denied
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        authorizationStatus = status
        isAuthorized = status == .approved
    }
    
    // MARK: - App Selection
    
    func createCustomChallenge(title: String, description: String, duration: TimeInterval, 
                              difficulty: DifficultyLevel, selectedApps: FamilyActivitySelection) -> Challenge {
        return Challenge(
            id: "custom-\(UUID().uuidString)",
            title: title,
            description: description,
            duration: duration,
            blockedApps: selectedApps.applicationTokens,
            blockedCategories: selectedApps.categoryTokens,
            difficulty: difficulty,
            isActive: false
        )
    }
    
    // MARK: - Challenge Management
    
    func startChallenge(_ challenge: Challenge) async throws {
        guard isAuthorized else {
            throw ScreenTimeError.notAuthorized
        }
        
        // Configurer les apps à bloquer
        var selection = FamilyActivitySelection()
        selection.applicationTokens = challenge.blockedApps
        selection.categoryTokens = challenge.blockedCategories
        
        // Appliquer les restrictions avec Family Controls
        store.shield.applications = selection.applicationTokens
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
                .specific(selection.categoryTokens)
        }
        
        // Note: Device Activity monitoring désactivé temporairement
        // Sera activé après approbation Apple
        /*
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )
        
        let activityName = DeviceActivityName(challenge.id)
        try center.startMonitoring(activityName, during: schedule)
        */
        
        // Simuler le démarrage du défi
        var updatedChallenge = challenge
        updatedChallenge.startTime = Date()
        updatedChallenge.isActive = true
        
        activeChallenge = updatedChallenge
        blockedApps = challenge.blockedApps
        
        print("✅ Défi démarré avec Family Controls: \(challenge.title)")
    }
    
    func stopChallenge() async throws {
        guard let challenge = activeChallenge else { return }
        
        // Note: Device Activity monitoring désactivé temporairement
        /*
        let activityName = DeviceActivityName(challenge.id)
        center.stopMonitoring([activityName])
        */
        
        // Supprimer les restrictions Family Controls
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        activeChallenge = nil
        blockedApps.removeAll()
        
        print("✅ Défi arrêté: \(challenge.title)")
    }
    
    func pauseChallenge() async throws {
        guard let challenge = activeChallenge else { return }
        
        // Supprimer temporairement les restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        print("Défi mis en pause: \(challenge.title)")
    }
    
    func resumeChallenge() async throws {
        guard let challenge = activeChallenge else { return }
        
        // Réappliquer les restrictions
        var selection = FamilyActivitySelection()
        selection.applicationTokens = challenge.blockedApps
        selection.categoryTokens = challenge.blockedCategories
        
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
            .specific(selection.categoryTokens)
        
        print("Défi repris: \(challenge.title)")
    }
    
    // MARK: - Quick Actions
    
    func quickBlockSocialMedia(duration: TimeInterval) async throws {
        let socialMediaChallenge = Challenge(
            id: "quick-social-\(Date().timeIntervalSince1970)",
            title: "Blocage Réseaux Sociaux",
            description: "Blocage rapide des réseaux sociaux",
            duration: duration,
            blockedApps: [], // À configurer avec les tokens des apps
            blockedCategories: [], // Catégorie réseaux sociaux
            difficulty: .medium,
            isActive: true
        )
        
        try await startChallenge(socialMediaChallenge)
    }
    
    func quickBlockAll(duration: TimeInterval) async throws {
        let allAppsChallenge = Challenge(
            id: "quick-all-\(Date().timeIntervalSince1970)",
            title: "Mode Focus Total",
            description: "Blocage de toutes les apps distractives",
            duration: duration,
            blockedApps: [], // À configurer
            blockedCategories: [], // Toutes les catégories
            difficulty: .hard,
            isActive: true
        )
        
        try await startChallenge(allAppsChallenge)
    }
    
    // MARK: - Shield Actions Management
    
    private func startListeningForShieldActions() {
        // Écouter les actions du shield toutes les 2 secondes
        shieldActionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForShieldActions()
        }
        print("🎧 [SCREEN TIME] Écoute des actions shield démarrée")
    }
    
    private func checkForShieldActions() {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Vérifier d'abord les demandes de pause urgentes
        if let pauseData = userDefaults?.dictionary(forKey: "urgentPauseRequest") as? [String: Any],
           let isUrgent = pauseData["urgent"] as? Bool, isUrgent,
           let timestamp = pauseData["timestamp"] as? TimeInterval,
           let context = pauseData["context"] as? String {
            
            let lastProcessedPause = UserDefaults.standard.double(forKey: "lastProcessedUrgentPause")
            if timestamp > lastProcessedPause {
                UserDefaults.standard.set(timestamp, forKey: "lastProcessedUrgentPause")
                
                print("🚨 [SCREEN TIME] PAUSE URGENTE détectée - contexte: \(context)")
                
                Task {
                    await handleUrgentPauseRequest(context: context)
                }
                
                // Supprimer la demande urgente après traitement
                userDefaults?.removeObject(forKey: "urgentPauseRequest")
                userDefaults?.synchronize()
                
                return // Traiter la pause urgente en priorité
            }
        }
        
        // Vérifier les actions shield normales
        guard let actionData = userDefaults?.dictionary(forKey: "pendingShieldAction") as? [String: Any],
              let action = actionData["action"] as? String,
              let context = actionData["context"] as? String,
              let timestamp = actionData["timestamp"] as? TimeInterval,
              let processed = actionData["processed"] as? Bool, !processed else {
            return
        }
        
        // Marquer comme traité
        var updatedActionData = actionData
        updatedActionData["processed"] = true
        userDefaults?.set(updatedActionData, forKey: "pendingShieldAction")
        userDefaults?.synchronize()
        
        print("📥 [SCREEN TIME] Action shield reçue: \(action) - \(context)")
        
        Task {
            await handleShieldAction(action: action, context: context)
        }
    }
    
    @MainActor
    private func handleShieldAction(action: String, context: String) async {
        switch action {
        case "continue_challenge":
            await handleContinueChallenge(context: context)
            
        case "request_pause_5min":
            await handleRequestBreak(context: context)
            
        default:
            print("⚠️ [SCREEN TIME] Action shield inconnue: \(action)")
        }
    }
    
    @MainActor
    private func handleUrgentPauseRequest(context: String) async {
        print("🚨 [SCREEN TIME] TRAITEMENT PAUSE URGENTE - contexte: \(context)")
        
        guard let challenge = activeChallenge else {
            print("❌ [SCREEN TIME] Aucun défi actif pour la pause urgente")
            return
        }
        
        // Accorder immédiatement la pause de 5 minutes
        await grantTemporaryBreak(duration: 5 * 60) // 5 minutes
        
        print("✅ [SCREEN TIME] Pause urgente accordée !")
    }
    
    @MainActor
    private func handleContinueChallenge(context: String) async {
        print("✅ [SCREEN TIME] Utilisateur continue le défi !")
        
        // Incrémenter les stats de motivation
        if var stats = DataManager.shared.userStats as? UserStats {
            // stats.motivationClicks += 1 // Si vous avez cette propriété
        }
        
        // Envoyer un feedback positif (optionnel)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @MainActor
    private func handleRequestBreak(context: String) async {
        print("⏸️ [SCREEN TIME] Demande de pause reçue")
        
        guard let challenge = activeChallenge else {
            print("❌ [SCREEN TIME] Aucun défi actif pour la pause")
            return
        }
        
        // Accorder une pause de 5 minutes
        await grantTemporaryBreak(duration: 5 * 60) // 5 minutes
    }
    
    @MainActor
    private func grantTemporaryBreak(duration: TimeInterval) async {
        print("🔓 [SCREEN TIME] Pause accordée pour \(Int(duration/60)) minutes")
        
        // Supprimer temporairement les restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        // Programmer la reprise du blocage après la pause
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            Task {
                await self?.resumeAfterBreak()
            }
        }
        
        // Mettre à jour les stats de pauses accordées
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        let breakCount = userDefaults?.integer(forKey: "totalBreaksGranted") ?? 0
        userDefaults?.set(breakCount + 1, forKey: "totalBreaksGranted")
    }
    
    @MainActor
    private func resumeAfterBreak() async {
        print("🔒 [SCREEN TIME] Fin de pause - Reprise du blocage")
        
        guard let challenge = activeChallenge else {
            print("❌ [SCREEN TIME] Aucun défi actif pour reprendre")
            return
        }
        
        // Réappliquer les restrictions
        var selection = FamilyActivitySelection()
        selection.applicationTokens = challenge.blockedApps
        selection.categoryTokens = challenge.blockedCategories
        
        store.shield.applications = selection.applicationTokens
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
                .specific(selection.categoryTokens)
        }
        
        print("✅ [SCREEN TIME] Blocage repris après pause")
    }
    
    deinit {
        shieldActionTimer?.invalidate()
    }
}

// MARK: - Data Models

struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let duration: TimeInterval
    let blockedApps: Set<ApplicationToken>
    let blockedCategories: Set<ActivityCategoryToken>
    let difficulty: DifficultyLevel
    var isActive: Bool
    var startTime: Date?
    
    // Implémentation manuelle de Codable pour gérer les tokens
    private enum CodingKeys: String, CodingKey {
        case id, title, description, duration, difficulty, isActive, startTime
        case blockedAppsData, blockedCategoriesData
    }
    
    init(id: String, title: String, description: String, duration: TimeInterval, 
         blockedApps: Set<ApplicationToken>, blockedCategories: Set<ActivityCategoryToken>,
         difficulty: DifficultyLevel, isActive: Bool, startTime: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.blockedApps = blockedApps
        self.blockedCategories = blockedCategories
        self.difficulty = difficulty
        self.isActive = isActive
        self.startTime = startTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        let difficultyRawValue = try container.decode(String.self, forKey: .difficulty)
        difficulty = DifficultyLevel(rawValue: difficultyRawValue) ?? .medium
        isActive = try container.decode(Bool.self, forKey: .isActive)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        
        // Pour l'instant, on initialise avec des sets vides
        // Dans une vraie app, il faudrait sérialiser/désérialiser les tokens
        blockedApps = Set<ApplicationToken>()
        blockedCategories = Set<ActivityCategoryToken>()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(duration, forKey: .duration)
        try container.encode(difficulty.rawValue, forKey: .difficulty)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        
        // Pour l'instant, on ne sauvegarde pas les tokens
        // Dans une vraie app, il faudrait les sérialiser
    }
    var progress: Double {
        guard let startTime = startTime, isActive else { return 0.0 }
        guard duration > 0 else { return 1.0 } // Éviter division par zéro
        
        let elapsed = Date().timeIntervalSince(startTime)
        let progressValue = elapsed / duration
        
        // Vérifier que le résultat n'est pas NaN ou infini
        guard progressValue.isFinite else { return 0.0 }
        
        return min(max(progressValue, 0.0), 1.0) // Clamp entre 0 et 1
    }
    
    var safeProgress: Double {
        let p = progress
        return p.isFinite ? p : 0.0
    }
    
    var progressPercentage: Int {
        let p = safeProgress * 100
        return p.isFinite ? Int(p) : 0
    }
    
    var timeRemaining: String {
        guard let startTime = startTime, isActive else {
            return formatDuration(duration)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = max(duration - elapsed, 0)
        return formatDuration(remaining)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

enum ScreenTimeError: Error, LocalizedError {
    case notAuthorized
    case challengeNotFound
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "L'autorisation Screen Time est requise"
        case .challengeNotFound:
            return "Défi non trouvé"
        case .invalidConfiguration:
            return "Configuration invalide"
        }
    }
}

// MARK: - Extensions
// Note: ApplicationToken et ActivityCategoryToken ne sont pas Codable par défaut
// Dans une app de production, il faudrait utiliser une approche différente pour la persistance