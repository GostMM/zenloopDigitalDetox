//
//  ZenloopManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

// MARK: - États de l'application

enum ZenloopState: String, CaseIterable {
    case idle = "idle"
    case active = "active"
    case paused = "paused"
    case completed = "completed"
}

enum DifficultyLevel: String, CaseIterable, Identifiable, Codable {
    case easy = "Facile"
    case medium = "Moyen"
    case hard = "Difficile"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        }
    }
}

// MARK: - Modèles de données

struct AppDetail: Identifiable {
    let id = UUID()
    let token: ApplicationToken
    let displayName: String
    let bundleIdentifier: String
    let isApplication: Bool
}

struct ZenloopChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let duration: TimeInterval
    let difficulty: DifficultyLevel
    var startTime: Date?
    var pausedTime: Date?
    var pauseDuration: TimeInterval = 0
    var isActive: Bool = false
    var isCompleted: Bool = false
    
    // Apps bloquées (non-Codable, géré séparément)
    var blockedAppsCount: Int = 0
    var blockedAppsNames: [String] = [] // Noms des applications bloquées
    var appOpenAttempts: Int = 0 // Nombre de tentatives d'ouverture d'apps bloquées
    var attemptedApps: [String: Int] = [:] // Compteur par app: ["Instagram": 5, "TikTok": 3]
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, title, description, duration, difficulty
        case startTime, pausedTime, pauseDuration
        case isActive, isCompleted, blockedAppsCount, blockedAppsNames
        case appOpenAttempts, attemptedApps
    }
    
    var progress: Double {
        guard let startTime = startTime, isActive else { return isCompleted ? 1.0 : 0.0 }
        guard duration > 0 else { return 1.0 }
        
        let elapsed = Date().timeIntervalSince(startTime) - pauseDuration
        let progressValue = elapsed / duration
        
        return progressValue.isFinite ? min(max(progressValue, 0.0), 1.0) : 0.0
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
        guard let startTime = startTime, isActive, !isCompleted else {
            return formatDuration(duration)
        }
        
        let elapsed = Date().timeIntervalSince(startTime) - pauseDuration
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

struct ActivityRecord: Identifiable, Codable {
    let id: UUID
    let type: ActivityType
    let title: String
    let timestamp: Date
    let duration: TimeInterval?
    
    init(type: ActivityType, title: String, timestamp: Date, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.timestamp = timestamp
        self.duration = duration
    }
    
    enum ActivityType: String, Codable {
        case challengeStarted = "challenge_started"
        case challengeCompleted = "challenge_completed"
        case challengePaused = "challenge_paused"
        case challengeResumed = "challenge_resumed"
        case challengeStopped = "challenge_stopped"
    }
}

// MARK: - Gestionnaire principal

@MainActor
class ZenloopManager: ObservableObject {
    static let shared = ZenloopManager()
    
    // MARK: - État publié
    
    @Published var currentState: ZenloopState = .idle
    @Published var currentChallenge: ZenloopChallenge?
    @Published var recentActivity: [ActivityRecord] = []
    @Published var isAuthorized = false
    @Published var pauseTimeRemaining = "00:00"
    @Published var appOpenCount = 0
    @Published var dailyOpenCount = 0
    @Published var selectedAppsCount = 0
    @Published var currentTimeRemaining = "00:00"
    @Published var currentProgress: Double = 0.0
    
    // MARK: - Propriétés pour les badges (nonisolated pour être accessible depuis BadgeManager)
    
    nonisolated var completedChallengesCount: Int {
        UserDefaults.standard.integer(forKey: "completed_challenges_count")
    }
    
    nonisolated var totalFocusTime: TimeInterval {
        UserDefaults.standard.double(forKey: "total_focus_time")
    }
    
    nonisolated var maxAppsBlockedSimultaneously: Int {
        UserDefaults.standard.integer(forKey: "max_apps_blocked")
    }
    
    nonisolated var currentStreak: Int {
        UserDefaults.standard.integer(forKey: "current_streak")
    }
    
    // MARK: - Propriétés privées
    
    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private var stateTimer: Timer?
    private var pauseTimer: Timer?
    private var pauseEndTime: Date?
    private var blockedAppsSelection = FamilyActivitySelection()
    
    private init() {
        loadPersistedData()
        loadPersistedAppsSelection()
        checkAuthorizationStatus()
    }
    
    // MARK: - Initialisation
    
    func initialize() {
        print("🚀 [ZENLOOP] Initialisation du gestionnaire")
        
        startStateMonitoring()
        checkAuthorizationStatus()
        loadRecentActivity()
        
        // Synchroniser le count d'apps sélectionnées
        syncSelectedAppsCount()
        
        // Demander l'autorisation si pas encore accordée
        if !isAuthorized {
            Task {
                await requestAuthorization()
            }
        }
        
        // Vérifier s'il y a un défi en cours au lancement
        if let challenge = currentChallenge, challenge.isActive {
            currentState = .active
            print("📱 [ZENLOOP] Défi en cours détecté au lancement: \(challenge.title)")
            
            // Initialiser les propriétés de l'UI
            currentTimeRemaining = challenge.timeRemaining
            currentProgress = challenge.safeProgress
            
            // Restaurer les restrictions si nécessaire (mais apps devront être re-sélectionnées)
            if isAuthorized && isAppsSelectionValid() {
                applyRestrictions()
            } else if isAuthorized {
                print("⚠️ [ZENLOOP] Apps doivent être re-sélectionnées pour appliquer les restrictions")
            }
            
            // Reprogrammer l'auto-completion pour le temps restant
            scheduleAutoCompletion()
            
            print("🔄 [ZENLOOP] Session restaurée avec auto-completion")
        }
    }
    
    // MARK: - Debug et validation
    
    func validateState() -> Bool {
        print("🔍 [ZENLOOP] Validation de l'état du gestionnaire")
        
        // Vérifier la cohérence de l'état
        if let challenge = currentChallenge {
            if challenge.isActive && currentState != .active {
                print("⚠️ [VALIDATION] Incohérence: challenge.isActive=true mais currentState=\(currentState)")
                return false
            }
            
            if !challenge.isActive && currentState == .active {
                print("⚠️ [VALIDATION] Incohérence: challenge.isActive=false mais currentState=active")
                return false
            }
            
            if challenge.startTime == nil && challenge.isActive {
                print("⚠️ [VALIDATION] Incohérence: challenge actif sans startTime")
                return false
            }
        }
        
        if currentChallenge == nil && currentState != .idle {
            print("⚠️ [VALIDATION] Incohérence: pas de challenge mais currentState=\(currentState)")
            return false
        }
        
        print("✅ [VALIDATION] État cohérent")
        return true
    }
    
    // MARK: - Gestion des autorisations
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            checkAuthorizationStatus()
            print("✅ [ZENLOOP] Autorisation accordée")
        } catch {
            print("❌ [ZENLOOP] Erreur autorisation: \(error)")
            isAuthorized = false
        }
    }
    
    private func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = status == .approved
        print("🔐 [ZENLOOP] Statut autorisation: \(status)")
    }
    
    // MARK: - Gestion des défis
    
    func startQuickChallenge(duration: TimeInterval) {
        guard currentState == .idle else {
            print("⚠️ [ZENLOOP] Impossible de démarrer - état actuel: \(currentState)")
            return
        }
        
        var challenge = ZenloopChallenge(
            id: "quick-\(UUID().uuidString)",
            title: "Focus Rapide",
            description: "Session de concentration rapide",
            duration: duration,
            difficulty: .medium,
            startTime: Date(),
            isActive: true
        )
        
        // Apps par défaut pour les défis rapides
        challenge.blockedAppsNames = ["Instagram", "TikTok", "Twitter", "Facebook", "YouTube"]
        challenge.blockedAppsCount = challenge.blockedAppsNames.count
        
        startChallenge(challenge)
    }
    
    func startCustomChallenge(title: String, duration: TimeInterval, difficulty: DifficultyLevel, apps: FamilyActivitySelection) {
        guard currentState == .idle else {
            print("⚠️ [ZENLOOP] Impossible de démarrer - état actuel: \(currentState)")
            return
        }
        
        // Vérifier qu'au moins une app ou catégorie est sélectionnée
        guard !apps.applicationTokens.isEmpty || !apps.categoryTokens.isEmpty else {
            print("⚠️ [ZENLOOP] Impossible de démarrer - aucune app sélectionnée")
            recordActivity(.challengeStopped, title: "Échec démarrage: aucune app sélectionnée")
            return
        }
        
        var challenge = ZenloopChallenge(
            id: "custom-\(UUID().uuidString)",
            title: title,
            description: "Défi personnalisé",
            duration: duration,
            difficulty: difficulty,
            startTime: Date(),
            isActive: true
        )
        
        challenge.blockedAppsCount = apps.applicationTokens.count
        challenge.blockedAppsNames = generateAppNamesFromSelection(apps)
        
        // Mettre à jour la sélection d'apps
        updateAppsSelection(apps)
        
        startChallenge(challenge)
    }
    
    func startSavedCustomChallenge(_ challenge: ZenloopChallenge) {
        guard currentState == .idle else {
            print("⚠️ [ZENLOOP] Impossible de démarrer - état actuel: \(currentState)")
            return
        }
        
        // Vérifier qu'au moins une app ou catégorie est sélectionnée
        guard isAppsSelectionValid() else {
            print("⚠️ [ZENLOOP] Impossible de démarrer défi sauvegardé - aucune app sélectionnée")
            recordActivity(.challengeStopped, title: "Échec démarrage défi sauvegardé: aucune app sélectionnée")
            return
        }
        
        var updatedChallenge = challenge
        updatedChallenge.startTime = Date()
        updatedChallenge.isActive = true
        
        // Utiliser les apps réellement sélectionnées par l'utilisateur
        updatedChallenge.blockedAppsNames = getSelectedAppsNames()
        updatedChallenge.blockedAppsCount = selectedAppsCount
        
        startChallenge(updatedChallenge)
    }
    
    private func startChallenge(_ challenge: ZenloopChallenge) {
        print("🎯 [ZENLOOP] Démarrage du défi: \(challenge.title)")
        
        currentChallenge = challenge
        currentState = .active
        
        // Initialiser les propriétés de l'UI
        currentTimeRemaining = challenge.timeRemaining
        currentProgress = challenge.safeProgress
        
        // Appliquer les restrictions
        applyRestrictions()
        
        // Démarrer le monitoring DeviceActivity
        startDeviceActivityMonitoring(for: challenge)
        
        // Enregistrer l'activité
        recordActivity(.challengeStarted, title: "Défi \(challenge.title) démarré", duration: challenge.duration)
        
        // Sauvegarder
        persistCurrentState()
        
        // Programmer l'auto-completion
        scheduleAutoCompletion()
        
        // Validation de l'état
        _ = validateState()
    }
    
    func stopCurrentChallenge() {
        guard let challenge = currentChallenge, currentState == .active || currentState == .paused else {
            print("⚠️ [ZENLOOP] Aucun défi à arrêter")
            return
        }
        
        print("🛑 [ZENLOOP] Arrêt du défi: \(challenge.title)")
        
        // Supprimer les restrictions
        removeRestrictions()
        
        // Arrêter le monitoring DeviceActivity
        stopDeviceActivityMonitoring(for: challenge)
        
        // Mettre à jour l'état
        var updatedChallenge = challenge
        updatedChallenge.isActive = false
        currentChallenge = updatedChallenge
        currentState = .idle
        
        // Enregistrer l'activité
        recordActivity(.challengeStopped, title: "Défi \(challenge.title) arrêté")
        
        // Nettoyer
        cancelTimers()
        persistCurrentState()
        
        // Validation de l'état
        _ = validateState()
    }
    
    func completeCurrentChallenge() {
        guard let challenge = currentChallenge, currentState == .active else {
            print("⚠️ [ZENLOOP] Aucun défi à compléter")
            return
        }
        
        print("🎉 [ZENLOOP] Défi complété: \(challenge.title)")
        
        // Supprimer les restrictions
        removeRestrictions()
        
        // Mettre à jour l'état
        var updatedChallenge = challenge
        updatedChallenge.isActive = false
        updatedChallenge.isCompleted = true
        currentChallenge = updatedChallenge
        currentState = .completed
        
        // Enregistrer l'activité
        recordActivity(.challengeCompleted, title: "Défi \(challenge.title) terminé avec succès", duration: challenge.duration)
        
        // Mettre à jour les statistiques pour les badges
        updateChallengeStatistics(challenge: challenge)
        
        // Programmer le retour à idle après 5 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.resetToIdle()
        }
        
        // Nettoyer
        cancelTimers()
        persistCurrentState()
        
        // Validation de l'état
        _ = validateState()
    }
    
    func resetToIdle() {
        print("🔄 [ZENLOOP] Retour à l'état idle")
        
        currentChallenge = nil
        currentState = .idle
        pauseEndTime = nil
        pauseTimeRemaining = "00:00"
        
        cancelTimers()
        persistCurrentState()
    }
    
    // MARK: - Gestion des pauses
    
    func requestPause() {
        print("🔍 [ZENLOOP] requestPause() appelée - État actuel: \(currentState)")
        
        guard let challenge = currentChallenge, currentState == .active else {
            print("⚠️ [ZENLOOP] Aucun défi actif pour la pause - État: \(currentState)")
            return
        }
        
        print("⏸️ [ZENLOOP] Demande de pause pour: \(challenge.title)")
        
        // Arrêter les timers existants
        stateTimer?.invalidate()
        pauseTimer?.invalidate()
        
        // Mettre en pause
        var updatedChallenge = challenge
        updatedChallenge.pausedTime = Date()
        currentChallenge = updatedChallenge
        currentState = .paused
        
        print("✅ [ZENLOOP] État changé vers: \(currentState)")
        
        // Supprimer temporairement les restrictions
        removeRestrictions()
        
        // Programmer la reprise dans 5 minutes
        pauseEndTime = Date().addingTimeInterval(5 * 60)
        startPauseTimer()
        
        // Enregistrer l'activité
        recordActivity(.challengePaused, title: "Pause de 5 minutes")
        
        persistCurrentState()
        
        print("⏱️ [ZENLOOP] Timer de pause démarré - fin prévue: \(pauseEndTime!)")
    }
    
    func resumeChallenge() {
        print("🔍 [ZENLOOP] resumeChallenge() appelée - État actuel: \(currentState)")
        
        guard let challenge = currentChallenge, currentState == .paused else {
            print("⚠️ [ZENLOOP] Aucun défi en pause à reprendre - État: \(currentState)")
            return
        }
        
        print("▶️ [ZENLOOP] Reprise du défi: \(challenge.title)")
        
        // Arrêter le timer de pause
        pauseTimer?.invalidate()
        pauseTimer = nil
        
        // Calculer le temps de pause écoulé
        if let pausedTime = challenge.pausedTime {
            let pauseDuration = Date().timeIntervalSince(pausedTime)
            print("⏱️ [ZENLOOP] Durée de pause: \(pauseDuration) secondes")
            
            var updatedChallenge = challenge
            updatedChallenge.pauseDuration += pauseDuration
            updatedChallenge.pausedTime = nil
            updatedChallenge.isActive = true
            currentChallenge = updatedChallenge
        }
        
        currentState = .active
        
        print("✅ [ZENLOOP] État changé vers: \(currentState)")
        
        // Réappliquer les restrictions
        applyRestrictions()
        
        // Nettoyer la pause
        pauseEndTime = nil
        pauseTimeRemaining = "00:00"
        
        // Redémarrer le monitoring d'état
        startStateMonitoring()
        
        // Reprogrammer l'auto-completion avec le temps restant
        scheduleAutoCompletion()
        
        // Enregistrer l'activité
        recordActivity(.challengeResumed, title: "Défi repris")
        
        persistCurrentState()
        
        print("🔄 [ZENLOOP] Monitoring d'état et auto-completion redémarrés")
    }
    
    // MARK: - Gestion des restrictions
    
    private func applyRestrictions() {
        guard isAuthorized else {
            print("❌ [ZENLOOP] Pas d'autorisation pour appliquer les restrictions")
            return
        }
        
        // Utiliser les tokens des applications sélectionnées pour le blocage
        let appTokens = blockedAppsSelection.applicationTokens
        store.shield.applications = appTokens
        
        if !blockedAppsSelection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
                .specific(blockedAppsSelection.categoryTokens)
        }
        
        print("🛡️ [ZENLOOP] Restrictions appliquées: \(appTokens.count) apps, \(blockedAppsSelection.categoryTokens.count) catégories")
    }
    
    private func removeRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        print("🔓 [ZENLOOP] Restrictions supprimées")
    }
    
    // MARK: - Timers et monitoring
    
    private func startStateMonitoring() {
        // Arrêter le timer existant avant d'en créer un nouveau
        stateTimer?.invalidate()
        
        print("🔄 [ZENLOOP] Démarrage du monitoring d'état")
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateState()
            }
        }
    }
    
    private func updateState() {
        // Vérifier les événements DeviceActivity
        checkDeviceActivityEvents()
        
        // Mettre à jour les propriétés de l'UI
        if let challenge = currentChallenge, currentState == .active {
            currentTimeRemaining = challenge.timeRemaining
            currentProgress = challenge.safeProgress
            
            // Vérifier si le défi doit être complété automatiquement
            if challenge.progress >= 1.0 {
                completeCurrentChallenge()
                return
            }
        } else {
            currentTimeRemaining = "00:00"
            currentProgress = 0.0
        }
        
        // Mettre à jour les propriétés calculées pour forcer la re-évaluation de l'UI
        objectWillChange.send()
    }
    
    private func scheduleAutoCompletion() {
        guard let challenge = currentChallenge, let startTime = challenge.startTime else { return }
        
        // Calculer le temps déjà écoulé
        let elapsedTime = Date().timeIntervalSince(startTime) - challenge.pauseDuration
        let remainingTime = max(challenge.duration - elapsedTime, 0)
        
        print("⏰ [ZENLOOP] Auto-completion programmée dans \(remainingTime) secondes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) { [weak self] in
            if self?.currentState == .active {
                print("⏰ [ZENLOOP] Auto-completion déclenchée")
                self?.completeCurrentChallenge()
            }
        }
    }
    
    private func startPauseTimer() {
        print("⏱️ [ZENLOOP] Démarrage du timer de pause")
        
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                await self.updatePauseTimer()
            }
        }
        
        // S'assurer que le timer fonctionne sur le main run loop
        if let timer = pauseTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("✅ [ZENLOOP] Timer de pause ajouté au RunLoop")
        }
    }
    
    private func updatePauseTimer() async {
        guard let endTime = pauseEndTime else {
            print("⚠️ [ZENLOOP] Pas de pauseEndTime - arrêt du timer")
            pauseTimer?.invalidate()
            pauseTimer = nil
            return
        }
        
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            // Temps de pause écoulé - reprendre automatiquement
            print("🔔 [ZENLOOP] Temps de pause écoulé - reprise automatique")
            resumeChallenge()
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            let newTimeString = String(format: "%02d:%02d", minutes, seconds)
            
            if pauseTimeRemaining != newTimeString {
                pauseTimeRemaining = newTimeString
                // Log seulement toutes les 10 secondes pour réduire le spam
                if seconds % 10 == 0 {
                    print("⏱️ [ZENLOOP] Pause - temps restant: \(pauseTimeRemaining)")
                }
            }
        }
    }
    
    private func cancelTimers() {
        stateTimer?.invalidate()
        stateTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
    
    nonisolated private func cancelTimersNonisolated() {
        // Note: We can't access the timer properties directly from nonisolated context
        // But we can schedule the cancellation on the MainActor
        Task { @MainActor [weak self] in
            self?.stateTimer?.invalidate()
            self?.stateTimer = nil
            self?.pauseTimer?.invalidate()
            self?.pauseTimer = nil
        }
    }
    
    // MARK: - Persistance et activité
    
    private func recordActivity(_ type: ActivityRecord.ActivityType, title: String, duration: TimeInterval? = nil) {
        let activity = ActivityRecord(
            type: type,
            title: title,
            timestamp: Date(),
            duration: duration
        )
        
        recentActivity.insert(activity, at: 0)
        
        // Garder seulement les 20 dernières activités
        if recentActivity.count > 20 {
            recentActivity = Array(recentActivity.prefix(20))
        }
        
        saveRecentActivity()
    }
    
    private func persistCurrentState() {
        let userDefaults = UserDefaults.standard
        
        // Sauvegarder l'état actuel
        userDefaults.set(currentState.rawValue, forKey: "zenloop_current_state")
        
        // Sauvegarder le défi actuel
        if let challenge = currentChallenge {
            if let data = try? JSONEncoder().encode(challenge) {
                userDefaults.set(data, forKey: "zenloop_current_challenge")
            }
        } else {
            userDefaults.removeObject(forKey: "zenloop_current_challenge")
        }
        
        userDefaults.synchronize()
    }
    
    private func loadPersistedData() {
        let userDefaults = UserDefaults.standard
        
        // Charger l'état
        if let stateString = userDefaults.string(forKey: "zenloop_current_state"),
           let state = ZenloopState(rawValue: stateString) {
            currentState = state
        }
        
        // Charger le défi actuel
        if let data = userDefaults.data(forKey: "zenloop_current_challenge"),
           let challenge = try? JSONDecoder().decode(ZenloopChallenge.self, from: data) {
            currentChallenge = challenge
        }
    }
    
    private func loadRecentActivity() {
        if let data = UserDefaults.standard.data(forKey: "zenloop_recent_activity"),
           let activities = try? JSONDecoder().decode([ActivityRecord].self, from: data) {
            recentActivity = activities
        }
    }
    
    private func saveRecentActivity() {
        if let data = try? JSONEncoder().encode(recentActivity) {
            UserDefaults.standard.set(data, forKey: "zenloop_recent_activity")
        }
    }
    
    // MARK: - Gestion de la sélection d'apps
    
    func updateAppsSelection(_ selection: FamilyActivitySelection) {
        blockedAppsSelection = selection
        selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        persistAppsSelection()
        print("📱 [ZENLOOP] Apps sélectionnées mises à jour: \(selectedAppsCount) éléments (apps: \(selection.applicationTokens.count), catégories: \(selection.categoryTokens.count))")
    }
    
    func getAppsSelection() -> FamilyActivitySelection {
        return blockedAppsSelection
    }
    
    func isAppsSelectionValid() -> Bool {
        let hasApps = !blockedAppsSelection.applicationTokens.isEmpty
        let hasCategories = !blockedAppsSelection.categoryTokens.isEmpty
        let hasTokens = hasApps || hasCategories
        
        print("🔍 [ZENLOOP] Validation apps - Apps: \(blockedAppsSelection.applicationTokens.count), Catégories: \(blockedAppsSelection.categoryTokens.count), SelectedCount: \(selectedAppsCount), HasTokens: \(hasTokens)")
        
        // Une sélection n'est valide que si on a réellement des tokens
        // Le selectedAppsCount peut être > 0 mais les tokens peuvent être perdus
        return hasTokens
    }
    
    /// Propriété pour vérifier si le démarrage d'une session custom est possible
    var canStartCustomSession: Bool {
        return currentState == .idle && (!blockedAppsSelection.applicationTokens.isEmpty || !blockedAppsSelection.categoryTokens.isEmpty)
    }
    
    func syncSelectedAppsCount() {
        let actualCount = blockedAppsSelection.applicationTokens.count + blockedAppsSelection.categoryTokens.count
        if selectedAppsCount != actualCount {
            selectedAppsCount = actualCount
            persistAppsSelection()
            print("🔄 [ZENLOOP] Count synchronisé: \(selectedAppsCount) apps")
        }
    }
    
    private func persistAppsSelection() {
        // Sauvegarder la FamilyActivitySelection complète (maintenant possible car Codable)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(blockedAppsSelection)
            UserDefaults.standard.set(data, forKey: "zenloop_apps_selection")
            
            // Sauvegarder aussi le count pour compatibilité
            UserDefaults.standard.set(selectedAppsCount, forKey: "zenloop_selected_apps_count")
            
            print("✅ [ZENLOOP] Sélection d'apps persistée: \(selectedAppsCount) éléments")
        } catch {
            print("❌ [ZENLOOP] Erreur persistance sélection: \(error)")
            // Fallback sur l'ancien système
            UserDefaults.standard.set(selectedAppsCount, forKey: "zenloop_selected_apps_count")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func loadPersistedAppsSelection() {
        // Essayer de charger la sélection persistée
        if let data = UserDefaults.standard.data(forKey: "zenloop_apps_selection") {
            do {
                let decoder = JSONDecoder()
                blockedAppsSelection = try decoder.decode(FamilyActivitySelection.self, from: data)
                selectedAppsCount = blockedAppsSelection.applicationTokens.count + blockedAppsSelection.categoryTokens.count
                print("✅ [ZENLOOP] Sélection d'apps restaurée: \(selectedAppsCount) éléments")
            } catch {
                print("❌ [ZENLOOP] Erreur lors du chargement de la sélection: \(error)")
                selectedAppsCount = 0
                blockedAppsSelection = FamilyActivitySelection()
            }
        } else {
            // Fallback vers l'ancien système de count
            selectedAppsCount = UserDefaults.standard.integer(forKey: "zenloop_selected_apps_count")
            if selectedAppsCount > 0 {
                print("⚠️ [ZENLOOP] \(selectedAppsCount) apps étaient sélectionnées (ancien système)")
                print("🔄 [ZENLOOP] Migration vers le nouveau système de persistance")
                selectedAppsCount = 0 // Reset car pas de tokens valides
            UserDefaults.standard.set(0, forKey: "zenloop_selected_apps_count")
            }
        }
        
        print("📱 [ZENLOOP] Apps sélectionnées initialisées: \(selectedAppsCount) éléments")
        
        // Debug: afficher l'état final
        let hasApps = !blockedAppsSelection.applicationTokens.isEmpty
        let hasCategories = !blockedAppsSelection.categoryTokens.isEmpty
        print("🔍 [ZENLOOP] État final - HasApps: \(hasApps), HasCategories: \(hasCategories), Count: \(selectedAppsCount)")
    }
    
    // MARK: - Détails des applications sélectionnées
    
    /// Récupère les détails des applications sélectionnées (noms, bundle IDs)
    func getSelectedAppsDetails() async -> [AppDetail] {
        var details: [AppDetail] = []
        
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            let detail = AppDetail(
                token: token,
                displayName: "App sélectionnée", // Le nom sera affiché via Label(token) dans l'UI
                bundleIdentifier: app.bundleIdentifier ?? "",
                isApplication: true
            )
            details.append(detail)
        }
        
        return details
    }
    
    /// Récupère les noms formatés des applications pour l'affichage dans les défis
    func getSelectedAppsNames() -> [String] {
        var names: [String] = []
        
        // Pour FamilyControls, les noms réels ne sont pas directement accessibles
        // On retourne des noms génériques ou on utilise le bundle identifier
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            // Utiliser le bundle identifier comme fallback
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    /// Vérifie si une application spécifique est sélectionnée par son bundle ID
    func isAppSelected(bundleIdentifier: String) -> Bool {
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            if app.bundleIdentifier == bundleIdentifier {
                return true
            }
        }
        return false
    }
    
    /// Met à jour le count et les noms d'apps lors d'une nouvelle sélection
    func updateAppsSelectionWithDetails(_ selection: FamilyActivitySelection) {
        blockedAppsSelection = selection
        selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        
        // Récupérer les noms des apps pour les défis
        Task {
            let appDetails = await getSelectedAppsDetails()
            let appNames = appDetails.map { $0.displayName }
            
            await MainActor.run {
                // Mettre à jour les propriétés si nécessaire
                print("📱 [ZENLOOP] Apps sélectionnées: \(appNames.joined(separator: ", "))")
            }
        }
        
        persistAppsSelection()
        print("📱 [ZENLOOP] Apps sélectionnées mises à jour: \(selectedAppsCount) éléments")
    }
    
    // MARK: - Helpers
    
    private func generateAppNamesFromSelection(_ selection: FamilyActivitySelection) -> [String] {
        // Utiliser nos nouvelles méthodes pour récupérer les noms des apps
        var names: [String] = []
        
        for token in selection.applicationTokens {
            let app = Application(token: token)
            // Utiliser le bundle identifier comme fallback pour le nom
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        
        // Ajouter les noms des catégories si nécessaire
        for token in selection.categoryTokens {
            // Les catégories n'ont pas de nom facilement accessible, on utilise un nom générique
            names.append("Catégorie")
        }
        
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    // MARK: - App Attempt Tracking
    
    func recordAppOpenAttempt(appName: String? = nil) {
        guard var challenge = currentChallenge, currentState == .active else {
            print("⚠️ [ZENLOOP] Tentative d'ouverture enregistrée mais aucun défi actif")
            return
        }
        
        challenge.appOpenAttempts += 1
        
        if let appName = appName {
            challenge.attemptedApps[appName, default: 0] += 1
            print("🚫 [ZENLOOP] Tentative d'ouverture: \(appName) (total: \(challenge.attemptedApps[appName]!))")
        } else {
            print("🚫 [ZENLOOP] Tentative d'ouverture d'app bloquée (total: \(challenge.appOpenAttempts))")
        }
        
        currentChallenge = challenge
        persistCurrentState()
        
        // Enregistrer dans l'activité
        let appInfo = appName != nil ? " (\(appName!))" : ""
        recordActivity(.challengeStarted, title: "Tentative d'accès à une app bloquée\(appInfo)")
    }
    
    func getTopAttemptedApps() -> [(String, Int)] {
        guard let challenge = currentChallenge else { return [] }
        
        return challenge.attemptedApps
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
    
    // MARK: - DeviceActivity Monitoring
    
    private func startDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        guard isAuthorized else {
            print("❌ [DeviceActivity] Pas d'autorisation pour le monitoring")
            return
        }
        
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        
        // Calculer les dates de début et fin
        let startDate = challenge.startTime ?? Date()
        let endDate = startDate.addingTimeInterval(challenge.duration)
        
        // Créer l'emploi du temps
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: Calendar.current.component(.hour, from: startDate),
                minute: Calendar.current.component(.minute, from: startDate)
            ),
            intervalEnd: DateComponents(
                hour: Calendar.current.component(.hour, from: endDate),
                minute: Calendar.current.component(.minute, from: endDate)
            ),
            repeats: false
        )
        
        do {
            // Démarrer le monitoring
            try activityCenter.startMonitoring(activityName, during: schedule)
            print("✅ [DeviceActivity] Monitoring démarré pour: \(activityName)")
        } catch {
            print("❌ [DeviceActivity] Erreur monitoring: \(error)")
        }
    }
    
    private func stopDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        
        do {
            activityCenter.stopMonitoring([activityName])
            print("✅ [DeviceActivity] Monitoring arrêté pour: \(activityName)")
        } catch {
            print("❌ [DeviceActivity] Erreur arrêt monitoring: \(error)")
        }
    }
    
    func checkDeviceActivityEvents() {
        // Vérifier les événements DeviceActivity depuis l'extension
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        if let events = defaults.array(forKey: "device_activity_events") as? [[String: Any]] {
            for event in events {
                if let eventType = event["event"] as? String,
                   let activity = event["activity"] as? String,
                   let timestamp = event["timestamp"] as? TimeInterval {
                    
                    print("📥 [DeviceActivity] Événement reçu: \(eventType) pour \(activity)")
                    
                    // Traiter l'événement selon son type
                    handleDeviceActivityEvent(type: eventType, activity: activity, timestamp: timestamp)
                }
            }
            
            // Nettoyer les événements traités
            defaults.removeObject(forKey: "device_activity_events")
        }
    }
    
    private func handleDeviceActivityEvent(type: String, activity: String, timestamp: TimeInterval) {
        switch type {
        case "intervalDidEnd":
            // L'activité s'est terminée automatiquement
            if currentState == .active {
                print("🎉 [DeviceActivity] Défi terminé automatiquement")
                completeCurrentChallenge()
            }
            
        case "thresholdReached":
            // Un seuil a été atteint (si configuré)
            print("⚠️ [DeviceActivity] Seuil atteint")
            
        case "warningStart", "warningEnd":
            // Avertissements de début/fin
            print("🔔 [DeviceActivity] Avertissement: \(type)")
            
        default:
            print("📱 [DeviceActivity] Événement inconnu: \(type)")
        }
    }
    
    // MARK: - Badge Statistics
    
    private func updateChallengeStatistics(challenge: ZenloopChallenge) {
        // Incrémenter le nombre de défis complétés
        let currentCount = UserDefaults.standard.integer(forKey: "completed_challenges_count")
        UserDefaults.standard.set(currentCount + 1, forKey: "completed_challenges_count")
        
        // Ajouter le temps de focus total
        let currentFocusTime = UserDefaults.standard.double(forKey: "total_focus_time")
        UserDefaults.standard.set(currentFocusTime + challenge.duration, forKey: "total_focus_time")
        
        // Mettre à jour le maximum d'apps bloquées simultanément
        let currentMax = UserDefaults.standard.integer(forKey: "max_apps_blocked")
        if challenge.blockedAppsCount > currentMax {
            UserDefaults.standard.set(challenge.blockedAppsCount, forKey: "max_apps_blocked")
        }
        
        // Mettre à jour la série de jours consécutifs
        updateConsecutiveDays()
        
        print("📊 [STATS] Statistiques mises à jour - Défis: \(currentCount + 1), Focus: \(Int((currentFocusTime + challenge.duration) / 3600))h")
    }
    
    private func updateConsecutiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastChallengeDate = UserDefaults.standard.object(forKey: "last_challenge_date") as? Date
        
        if let lastDate = lastChallengeDate {
            let lastChallengeDay = Calendar.current.startOfDay(for: lastDate)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastChallengeDay, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Jour consécutif
                let currentStreak = UserDefaults.standard.integer(forKey: "current_streak")
                UserDefaults.standard.set(currentStreak + 1, forKey: "current_streak")
            } else if daysBetween > 1 {
                // Série interrompue
                UserDefaults.standard.set(1, forKey: "current_streak")
            }
            // Si daysBetween == 0, c'est le même jour, on ne change rien
        } else {
            // Premier défi
            UserDefaults.standard.set(1, forKey: "current_streak")
        }
        
        // Sauvegarder la date du défi d'aujourd'hui
        UserDefaults.standard.set(today, forKey: "last_challenge_date")
    }
    
    deinit {
        cancelTimersNonisolated()
    }
}