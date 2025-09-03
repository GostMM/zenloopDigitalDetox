//  ZenloopManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//  Optimized on 11/08/2025: single GCD ticker, throttled events, no I/O in tick.

import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings
import WidgetKit
import os

// MARK: - Application States & Models

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

struct AppDetail: Identifiable {
    let id = UUID()
    let token: ApplicationToken?
    let displayName: String
    let bundleIdentifier: String
    let isApplication: Bool
    
    init(token: ApplicationToken? = nil, displayName: String, bundleIdentifier: String, isApplication: Bool = true) {
        self.token = token
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.isApplication = isApplication
    }
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
    var blockedAppsCount: Int = 0
    var blockedAppsNames: [String] = []
    var appOpenAttempts: Int = 0
    var attemptedApps: [String: Int] = [:]
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, duration, difficulty
        case startTime, pausedTime, pauseDuration
        case isActive, isCompleted, blockedAppsCount, blockedAppsNames
        case appOpenAttempts, attemptedApps
    }
    
    var progress: Double {
        guard let startTime = self.startTime, self.isActive else { return self.isCompleted ? 1.0 : 0.0 }
        guard self.duration > 0 else { return 1.0 }
        let elapsed = Date().timeIntervalSince(startTime) - self.pauseDuration
        let progressValue = elapsed / self.duration
        return progressValue.isFinite ? min(max(progressValue, 0.0), 1.0) : 0.0
    }
    
    var safeProgress: Double {
        let p = self.progress
        return p.isFinite ? p : 0.0
    }
    
    var progressPercentage: Int {
        let p = self.safeProgress * 100
        return p.isFinite ? Int(p) : 0
    }
    
    var timeRemaining: String {
        guard let startTime = self.startTime, self.isActive, !self.isCompleted else {
            return self.formatDuration(self.duration)
        }
        let elapsed = Date().timeIntervalSince(startTime) - self.pauseDuration
        let remaining = max(self.duration - elapsed, 0)
        return self.formatDuration(remaining)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
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
        case challengeScheduled = "challenge_scheduled"
    }
}

final class Ticker {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "zenloop.ticker", qos: .utility)
    
    func start(every seconds: Double = 1.0, handler: @escaping () -> Void) {
        self.stop()
        let t = DispatchSource.makeTimerSource(queue: self.queue)
        t.schedule(deadline: .now() + seconds,
                   repeating: seconds,
                   leeway: .milliseconds(100))
        t.setEventHandler(handler: handler)
        t.resume()
        self.timer = t
    }
    
    func stop() { self.timer?.cancel(); self.timer = nil }
}

// MARK: - Scheduled Sessions Support

struct SelectionPayload: Codable {
    let sessionId: String
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
}

struct SessionInfo: Codable {
    let sessionId: String
    let title: String
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let createdAt: Date
}

class BlockScheduler {
    static let shared = BlockScheduler()
    private let center = DeviceActivityCenter()
    private let suite = UserDefaults(suiteName: "group.com.app.zenloop")!
    private var activeMonitors: Set<String> = []
    
    private init() {
        restoreLostSchedules()
    }
    
    // CRUCIAL: Restaurer les sessions perdues au démarrage
    func restoreLostSchedules() {
        Task {
            await restoreActiveSchedules()
        }
    }
    
    @MainActor
    private func restoreActiveSchedules() async {
        // Récupérer toutes les sessions programmées
        let keys = suite.dictionaryRepresentation().keys
        let sessionKeys = keys.filter { $0.hasPrefix("session_info_") }
        
        for key in sessionKeys {
            let sessionId = String(key.dropFirst("session_info_".count))
            
            guard let sessionData = suite.data(forKey: key),
                  let sessionInfo = try? JSONDecoder().decode(SessionInfo.self, from: sessionData),
                  sessionInfo.endTime > Date() else {
                // Session expirée, nettoyer
                cleanupSession(sessionId)
                continue
            }
            
            print("🔄 [BlockScheduler] Restoring lost schedule: \(sessionInfo.title)")
            
            // Re-programmer la session
            do {
                try await recreateSchedule(sessionInfo: sessionInfo, sessionId: sessionId)
            } catch {
                print("❌ [BlockScheduler] Failed to restore schedule \(sessionId): \(error)")
                cleanupSession(sessionId)
            }
        }
    }
    
    // Sauvegarder les apps/catégories sélectionnées pour l'extension
    func saveSelectionForExtension(selection: FamilyActivitySelection, sessionId: String) throws {
        let encoder = JSONEncoder()
        let payload = SelectionPayload(
            sessionId: sessionId,
            apps: Array(selection.applicationTokens),
            categories: Array(selection.categoryTokens)
        )
        
        let data = try encoder.encode(payload)
        suite.set(data, forKey: "payload_\(sessionId)")
        suite.synchronize() // CRUCIAL: Forcer la synchronisation
        
        print("💾 [BlockScheduler] Selection saved for session: \(sessionId)")
        print("   📱 Apps count: \(selection.applicationTokens.count)")
        print("   📂 Categories count: \(selection.categoryTokens.count)")
        print("   🔑 Key: payload_\(sessionId)")
        
        // DEBUG: Vérifier que les données sont bien sauvées
        if let savedData = suite.data(forKey: "payload_\(sessionId)") {
            print("   ✅ Data successfully saved (\(savedData.count) bytes)")
        } else {
            print("   ❌ FAILED to save data!")
        }
    }
    
    // Programmer une session pour une heure spécifique
    func scheduleSession(
        title: String,
        duration: TimeInterval,
        startTime: Date,
        selection: FamilyActivitySelection
    ) throws {
        let sessionId = "scheduled_\(UUID().uuidString)"
        let endTime = startTime.addingTimeInterval(duration)
        
        let sessionInfo = SessionInfo(
            sessionId: sessionId,
            title: title,
            duration: duration,
            startTime: startTime,
            endTime: endTime,
            createdAt: Date()
        )
        
        // Sauvegarder la sélection pour l'extension
        try saveSelectionForExtension(selection: selection, sessionId: sessionId)
        
        // Sauvegarder les infos de session pour restauration
        let sessionData = try JSONEncoder().encode(sessionInfo)
        suite.set(sessionData, forKey: "session_info_\(sessionId)")
        
        // Programmer avec retry pour iOS 18
        Task {
            await scheduleWithRetry(sessionInfo: sessionInfo)
        }
        
        print("📅 [BlockScheduler] Session scheduled: \(title) at \(startTime)")
    }
    
    @MainActor
    private func scheduleWithRetry(sessionInfo: SessionInfo, retryCount: Int = 0) async {
        let maxRetries = 3
        
        do {
            try await performScheduling(sessionInfo: sessionInfo)
            activeMonitors.insert(sessionInfo.sessionId)
            print("✅ [BlockScheduler] Successfully scheduled \(sessionInfo.title)")
        } catch {
            print("⚠️ [BlockScheduler] Schedule attempt \(retryCount + 1) failed: \(error)")
            
            if retryCount < maxRetries {
                // Retry avec délai exponentiel
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await scheduleWithRetry(sessionInfo: sessionInfo, retryCount: retryCount + 1)
            } else {
                print("❌ [BlockScheduler] Failed to schedule after \(maxRetries) attempts")
                cleanupSession(sessionInfo.sessionId)
            }
        }
    }
    
    private func performScheduling(sessionInfo: SessionInfo) async throws {
        let activityName = DeviceActivityName(sessionInfo.sessionId)
        
        // CRUCIAL: Arrêter le monitoring existant d'abord
        center.stopMonitoring([activityName])
        
        // Petit délai pour éviter les conflits iOS 18
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
        
        // Créer le schedule avec timing précis (arrondir à la minute exacte)
        let calendar = Calendar.current
        
        // CORRECTION: Arrondir à la minute exacte pour éviter les décalages de secondes
        let startTimeRounded = calendar.dateInterval(of: .minute, for: sessionInfo.startTime)?.start ?? sessionInfo.startTime
        let endTimeRounded = calendar.dateInterval(of: .minute, for: sessionInfo.endTime)?.start ?? sessionInfo.endTime
        
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: startTimeRounded)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: endTimeRounded)
        
        // Vérifier que la session est dans au moins 1 minute
        guard sessionInfo.startTime.timeIntervalSinceNow > 60 else {
            throw NSError(domain: "BlockScheduler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session trop proche (minimum 1 minute)"])
        }
        
        print("🕐 [BlockScheduler] Creating schedule:")
        print("   Start: \(startComponents)")
        print("   End: \(endComponents)")
        print("   Time until start: \(Int(sessionInfo.startTime.timeIntervalSinceNow)) seconds")
        
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true // CHANGÉ: repeats true fonctionne mieux même pour sessions uniques
        )
        
        // Démarrer la surveillance
        try center.startMonitoring(activityName, during: schedule, events: [:])
    }
    
    private func recreateSchedule(sessionInfo: SessionInfo, sessionId: String) async throws {
        await scheduleWithRetry(sessionInfo: sessionInfo)
    }
    
    // Annuler une session programmée
    func cancelScheduledSession(_ sessionId: String) {
        let activityName = DeviceActivityName(sessionId)
        center.stopMonitoring([activityName])
        
        activeMonitors.remove(sessionId)
        cleanupSession(sessionId)
        
        print("❌ [BlockScheduler] Session cancelled: \(sessionId)")
    }
    
    private func cleanupSession(_ sessionId: String) {
        // Nettoyer toutes les données de session
        suite.removeObject(forKey: "payload_\(sessionId)")
        suite.removeObject(forKey: "session_info_\(sessionId)")
        suite.removeObject(forKey: "session_title_\(sessionId)")
        suite.removeObject(forKey: "session_duration_\(sessionId)")
    }
    
    // Méthode publique pour déclencher la restauration
    func checkAndRestoreSchedules() {
        Task {
            await restoreActiveSchedules()
        }
    }
    
    // Obtenir les sessions actives
    func getActiveSchedules() -> [SessionInfo] {
        let keys = suite.dictionaryRepresentation().keys
        let sessionKeys = keys.filter { $0.hasPrefix("session_info_") }
        
        var sessions: [SessionInfo] = []
        for key in sessionKeys {
            guard let sessionData = suite.data(forKey: key),
                  let sessionInfo = try? JSONDecoder().decode(SessionInfo.self, from: sessionData),
                  sessionInfo.endTime > Date() else {
                continue
            }
            sessions.append(sessionInfo)
        }
        
        return sessions.sorted { $0.startTime < $1.startTime }
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
    @Published var showBreathingMeditation = false
    
    // Statistiques publiées pour l'UI
    @Published var totalSavedTime: TimeInterval = 0.0
    @Published var completedChallengesTotal: Int = 0
    @Published var currentStreakCount: Int = 0
    
    // MARK: - Propriétés nonisolated (badges) - Délégation aux managers
    nonisolated var completedChallengesCount: Int { statisticsCoordinator.completedChallengesCount }
    nonisolated var totalFocusTime: TimeInterval { statisticsCoordinator.totalFocusTime }
    nonisolated var maxAppsBlockedSimultaneously: Int { statisticsCoordinator.maxAppsBlockedSimultaneously }
    nonisolated var currentStreak: Int { statisticsCoordinator.currentStreak }
    
    // MARK: - Managers Spécialisés
    private let challengeStateManager = ChallengeStateManager()
    private let appRestrictionCoordinator = AppRestrictionCoordinator()
    private let deviceActivityCoordinator = DeviceActivityCoordinator()
    private let persistence = ZenloopPersistence()
    private let statisticsCoordinator = StatisticsCoordinator()
    private let scheduledSessionsCoordinator = ScheduledSessionsCoordinator()
    
    // MARK: - Managers Existants
    private let notificationManager = SessionNotificationManager.shared
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "Zenloop")
    private let verboseLogging = false
    #endif
    
    private init() {
        // Configurer les delegates
        challengeStateManager.delegate = self
        appRestrictionCoordinator.delegate = self
        deviceActivityCoordinator.delegate = self
        persistence.delegate = self
        statisticsCoordinator.delegate = self
        scheduledSessionsCoordinator.delegate = self
        
        // Charger les données depuis les managers
        let (state, challenge) = persistence.loadPersistedState()
        currentState = state
        currentChallenge = challenge
        
        selectedAppsCount = appRestrictionCoordinator.selectedAppsCount
        
        recentActivity = persistence.loadRecentActivity()
        
        // Synchroniser l'autorisation
        appRestrictionCoordinator.checkAuthorizationStatus()
        isAuthorized = appRestrictionCoordinator.isAuthorized
        deviceActivityCoordinator.updateAuthorizationStatus(appRestrictionCoordinator.isAuthorized)
        
        // Charger les statistiques
        statisticsCoordinator.loadStatistics()
        totalSavedTime = statisticsCoordinator.totalSavedTime
        completedChallengesTotal = statisticsCoordinator.completedChallengesTotal
        currentStreakCount = statisticsCoordinator.currentStreakCount
    }
    
    // MARK: - Initialisation
    
    func initialize() {
        #if DEBUG
        self.logger.debug("🚀 [ZENLOOP] Initialisation rapide du gestionnaire")
        #endif
        
        // PHASE 1: Initialisation critique immédiate (main thread)
        initializeCriticalComponents()
        
        // PHASE 2: Initialisation complète en arrière-plan
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.initializeBackgroundComponents()
        }
    }
    
    @MainActor
    private func initializeCriticalComponents() {
        // Seulement les composants critiques pour l'UI
        self.checkAuthorizationStatus() // Rapide - juste un status check
        
        // État minimal pour permettre l'affichage
        self.currentState = .idle
        self.currentProgress = 0.0
        self.currentTimeRemaining = "00:00"
        
        #if DEBUG
        self.logger.debug("✅ [ZENLOOP] Composants critiques initialisés")
        #endif
    }
    
    private func initializeBackgroundComponents() async {
        #if DEBUG
        await MainActor.run {
            self.logger.debug("🔄 [ZENLOOP] Initialisation background en cours...")
        }
        #endif
        
        // Opérations lourdes en arrière-plan
        await withTaskGroup(of: Void.self) { group in
            // Charger les données persistées
            group.addTask { [weak self] in
                // I/O operations hors du main thread
                await MainActor.run { [weak self] in
                    // Déjà chargé dans init() via persistence.loadRecentActivity()
                    self?.syncSelectedAppsCount()
                }
            }
            
            // REMOVED: Ne plus demander autorisation automatiquement
            // L'autorisation sera demandée seulement dans l'onboarding
            
            // Restaurer la session active si nécessaire
            group.addTask { [weak self] in
                await self?.restoreActiveSession()
            }
            
            // CRUCIAL: Restaurer les sessions programmées perdues
            group.addTask { [weak self] in
                await MainActor.run { [weak self] in
                    BlockScheduler.shared.checkAndRestoreSchedules()
                    // Mettre à jour le statut après restauration
                    self?.updateScheduledSessionsStatus()
                }
            }
        }
        
        // Démarrer le monitoring une fois tout initialisé
        await MainActor.run { [weak self] in
            self?.startStateMonitoring()
            
            // NOUVEAU: Surveiller les sessions activées par l'extension
            self?.startExtensionSessionMonitoring()
            
            // Initialiser les données du widget au démarrage
            self?.updateWidgetData()
            
            #if DEBUG
            self?.logger.debug("✅ [ZENLOOP] Initialisation complète terminée")
            #endif
        }
    }
    
    private func restoreActiveSession() async {
        await MainActor.run { [weak self] in
            guard let self = self,
                  let challenge = self.currentChallenge, 
                  challenge.isActive else { return }
            
            // Restaurer l'état dans le ChallengeStateManager
            self.challengeStateManager.restoreActiveSession(challenge)
            
            // Synchroniser avec les propriétés de ZenloopManager 
            self.currentState = .active
            self.currentTimeRemaining = challenge.timeRemaining
            
            // Update widget immediately when session starts
            self.updateWidgetData()
            self.currentProgress = challenge.safeProgress
            
            // CRUCIAL: Ne pas réappliquer les restrictions si c'est une session programmée
            if self.isAuthorized && self.isAppsSelectionValid() {
                if isScheduledSession(challenge) {
                    print("⚠️ [ZENLOOP] Session programmée restaurée - restrictions gérées par l'extension")
                    // Ne pas appliquer les restrictions car l'extension les gère déjà
                } else {
                    // Session manuelle - appliquer les restrictions normalement
                    self.applyRestrictions()
                }
            } else if self.isAuthorized {
                #if DEBUG
                self.logger.warning("⚠️ [ZENLOOP] Apps doivent être re-sélectionnées")
                #endif
            }
            self.scheduleAutoCompletion()
            
            #if DEBUG
            self.logger.debug("🔄 [ZENLOOP] Session active restaurée après reload")
            #endif
        }
    }
    
    // MARK: - Notifications Debug
    
    func debugNotifications() {
        Task {
            await notificationManager.debugScheduledNotifications()
        }
    }
    
    // MARK: - Validation
    
    func validateState() -> Bool {
        if let challenge = self.currentChallenge {
            if challenge.isActive && self.currentState != .active { return false }
            if !challenge.isActive && self.currentState == .active { return false }
            if challenge.startTime == nil && challenge.isActive { return false }
        }
        if self.currentChallenge == nil && self.currentState != .idle { return false }
        return true
    }
    
    // MARK: - Autorisations - Délégation aux managers
    
    func requestAuthorization() async {
        await appRestrictionCoordinator.requestAuthorization()
        isAuthorized = appRestrictionCoordinator.isAuthorized
        deviceActivityCoordinator.updateAuthorizationStatus(appRestrictionCoordinator.isAuthorized)
    }
    
    private func checkAuthorizationStatus() {
        appRestrictionCoordinator.checkAuthorizationStatus()
        isAuthorized = appRestrictionCoordinator.isAuthorized
        deviceActivityCoordinator.updateAuthorizationStatus(appRestrictionCoordinator.isAuthorized)
    }
    
    // MARK: - Défis
    
    func startQuickChallenge(duration: TimeInterval) {
        guard challengeStateManager.canStartChallenge else { return }
        
        // Obtenir la configuration des apps depuis le coordinator
        let (hasSelectedApps, appNames, appCount) = appRestrictionCoordinator.getQuickChallengeConfiguration()
        
        var challenge = ZenloopChallenge(
            id: "quick-\(UUID().uuidString)",
            title: "Focus Rapide",
            description: "Session de concentration rapide",
            duration: duration,
            difficulty: .medium
        )
        
        challenge.blockedAppsCount = appCount
        challenge.blockedAppsNames = appNames
        
        #if DEBUG
        let source = hasSelectedApps ? "apps sélectionnées" : "apps par défaut"
        print("🎯 [ZENLOOP_MANAGER] Quick challenge avec \(appCount) \(source)")
        #endif
        
        startChallenge(challenge)
    }
    
    func startCustomChallenge(title: String, duration: TimeInterval, difficulty: DifficultyLevel, apps: FamilyActivitySelection) {
        guard self.currentState == .idle else { return }
        guard !apps.applicationTokens.isEmpty || !apps.categoryTokens.isEmpty else {
            self.recordActivity(.challengeStopped, title: "Échec démarrage: aucune app sélectionnée")
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
        challenge.blockedAppsNames = self.generateAppNamesFromSelection(apps)
        self.updateAppsSelection(apps)
        
        self.startChallenge(challenge)
    }
    
    func startSavedCustomChallenge(_ challenge: ZenloopChallenge) {
        guard self.currentState == .idle else { return }
        guard self.isAppsSelectionValid() else {
            self.recordActivity(.challengeStopped, title: "Échec démarrage défi sauvegardé: aucune app sélectionnée")
            return
        }
        
        var updated = challenge
        updated.startTime = Date()
        updated.isActive = true
        updated.blockedAppsNames = self.getSelectedAppsNames()
        updated.blockedAppsCount = self.selectedAppsCount
        
        self.startChallenge(updated)
    }
    
    // MARK: - Scheduled Sessions - Délégation aux managers
    
    // Vérifier s'il y a des sessions programmées actives
    @Published var hasActiveScheduledSessions: Bool = false
    @Published var nextScheduledSession: SessionInfo? = nil
    
    func updateScheduledSessionsStatus() {
        let activeSessions = BlockScheduler.shared.getActiveSchedules()
        hasActiveScheduledSessions = !activeSessions.isEmpty
        nextScheduledSession = activeSessions.first // La prochaine session (triée par date)
    }
    
    func scheduleCustomChallenge(
        title: String,
        duration: TimeInterval,
        difficulty: DifficultyLevel,
        apps: FamilyActivitySelection,
        startTime: Date
    ) {
        // Utiliser BlockScheduler pour le vrai blocage en arrière-plan
        do {
            try BlockScheduler.shared.scheduleSession(
                title: title,
                duration: duration,
                startTime: startTime,
                selection: apps
            )
            
            // Aussi programmer les notifications via l'ancien système
            scheduledSessionsCoordinator.scheduleCustomChallenge(
                title: title,
                duration: duration,
                difficulty: difficulty,
                apps: apps,
                startTime: startTime,
                notificationManager: notificationManager
            )
            
            print("📅 [ZENLOOP] Scheduled session with background blocking: \(title)")
            
            // Mettre à jour le statut des sessions programmées
            updateScheduledSessionsStatus()
        } catch {
            print("❌ [ZENLOOP] Failed to schedule background session: \(error)")
            
            // Fallback sur l'ancien système uniquement
            scheduledSessionsCoordinator.scheduleCustomChallenge(
                title: title,
                duration: duration,
                difficulty: difficulty,
                apps: apps,
                startTime: startTime,
                notificationManager: notificationManager
            )
        }
    }
    
    func cancelScheduledChallenge(_ challengeId: String) {
        scheduledSessionsCoordinator.cancelScheduledChallenge(
            challengeId,
            notificationManager: notificationManager
        )
    }
    
    // MARK: - Scheduled Sessions API
    
    func getAllScheduledSessions() -> [ZenloopChallenge] {
        return scheduledSessionsCoordinator.getAllScheduledSessions()
    }
    
    func getUpcomingSessions(limit: Int = 5) -> [ZenloopChallenge] {
        return scheduledSessionsCoordinator.getUpcomingSessions(limit: limit)
    }
    
    func hasScheduledSessions() -> Bool {
        return scheduledSessionsCoordinator.hasScheduledSessions()
    }
    
    func cleanupExpiredSessions() {
        scheduledSessionsCoordinator.cleanupExpiredSessions()
    }
    
    private func startChallenge(_ challenge: ZenloopChallenge) {
        // Démarrer le challenge via le state manager (qui triggera les callbacks)
        challengeStateManager.startChallenge(challenge)
        
        // Notifier le démarrage de session et programmer les notifications
        notificationManager.notifySessionStarted(sessionTitle: challenge.title, sessionId: challenge.id)
        notificationManager.scheduleProgressNotification(sessionTitle: challenge.title, sessionId: challenge.id, duration: challenge.duration)
        
        // Enregistrer l'activité
        var activities = recentActivity
        persistence.addActivityRecord(
            ActivityRecord(type: .challengeStarted, title: "Défi \(challenge.title) démarré", timestamp: Date(), duration: challenge.duration),
            to: &activities
        )
        recentActivity = activities
        
        // Validation handled by state manager
    }
    
    // MARK: - Arrêt / Complétion
    
    func initiateStopWithBreathing() {
        guard let challenge = self.currentChallenge, self.currentState == .active || self.currentState == .paused else { return }
        _ = challenge
        self.showBreathingMeditation = true
    }
    
    func stopCurrentChallenge() {
        guard let challenge = challengeStateManager.getCurrentChallenge(), challengeStateManager.hasActiveChallenge else { return }
        
        showBreathingMeditation = false
        
        // Arrêter le challenge via le state manager (qui triggera les callbacks)
        challengeStateManager.stopChallenge()
        
        // Annuler les notifications en cours pour cette session
        notificationManager.cancelSessionNotifications(sessionId: challenge.id)
        
        // Enregistrer l'activité
        var activities = recentActivity
        persistence.addActivityRecord(
            ActivityRecord(type: .challengeStopped, title: "Défi \(challenge.title) arrêté", timestamp: Date()),
            to: &activities
        )
        recentActivity = activities
    }
    
    func completeCurrentChallenge() {
        guard let challenge = self.currentChallenge, self.currentState == .active else { return }
        
        // CRUCIAL: Ne supprimer que les restrictions de cette session spécifique
        if isScheduledSession(challenge) {
            // Pour les sessions programmées, supprimer du store nommé correspondant
            appRestrictionCoordinator.removeRestrictions(for: challenge.id)
        } else {
            // Pour les sessions manuelles, vérifier qu'aucune session programmée n'est active
            if !appRestrictionCoordinator.hasActiveScheduledSession() {
                appRestrictionCoordinator.removeRestrictions()
            } else {
                print("⚠️ [ZENLOOP] Sessions programmées actives - ne pas supprimer toutes les restrictions")
            }
        }
        
        var updated = challenge
        updated.isActive = false
        updated.isCompleted = true
        self.currentChallenge = updated
        self.currentState = .completed
        
        // Update widget when session completes
        self.updateWidgetData()
        
        // Notifier la fin de session
        self.notificationManager.notifySessionCompleted(sessionTitle: challenge.title, sessionId: challenge.id)
        
        self.recordActivity(.challengeCompleted, title: "Défi \(challenge.title) terminé avec succès", duration: challenge.duration)
        self.updateChallengeStatistics(challenge: challenge)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.resetToIdle()
        }
        
        self.cancelTimers()
        self.persistCurrentStateNow()
        _ = self.validateState()
    }
    
    func resetToIdle() {
        challengeStateManager.resetToIdle()
    }
    
    // MARK: - Pause / Reprise - Délégation aux managers
    
    func requestPause() {
        guard challengeStateManager.hasActiveChallenge else { return }
        challengeStateManager.pauseChallenge()
        
        // Enregistrer l'activité
        var activities = recentActivity
        persistence.addActivityRecord(
            ActivityRecord(type: .challengePaused, title: "Pause de 5 minutes", timestamp: Date()),
            to: &activities
        )
        recentActivity = activities
    }
    
    func resumeChallenge() {
        guard currentState == .paused else { return }
        challengeStateManager.resumeChallenge()
        
        // Enregistrer l'activité
        var activities = recentActivity
        persistence.addActivityRecord(
            ActivityRecord(type: .challengeResumed, title: "Défi repris", timestamp: Date()),
            to: &activities
        )
        recentActivity = activities
    }
    
    // MARK: - Restrictions - Délégation aux managers
    
    private func applyRestrictions() {
        appRestrictionCoordinator.applyRestrictions()
    }
    
    private func removeRestrictions(for sessionId: String? = nil) {
        appRestrictionCoordinator.removeRestrictions(for: sessionId)
    }
    
    // MARK: - Ticker (1 Hz) - Délégation aux managers
    
    func startStateMonitoring() {
        challengeStateManager.startStateMonitoring()
    }
    
    func cancelTimers() {
        challengeStateManager.cancelTimers()
    }
    
    // MARK: - DeviceActivity Events - Délégation aux managers
    
    func checkDeviceActivityEvents() {
        deviceActivityCoordinator.checkEventsThrottled()
    }
    
    // MARK: - Auto-completion - Géré par ChallengeStateManager
    
    private func scheduleAutoCompletion() {
        // Géré automatiquement par ChallengeStateManager
    }
    
    // MARK: - Persistance & activité - Délégation aux managers
    
    private func recordActivity(_ type: ActivityRecord.ActivityType, title: String, duration: TimeInterval? = nil) {
        let activity = ActivityRecord(type: type, title: title, timestamp: Date(), duration: duration)
        var activities = recentActivity
        persistence.addActivityRecord(activity, to: &activities)
        recentActivity = activities
    }
    
    private func persistCurrentStateDebounced() {
        persistence.persistCurrentStateDebounced(state: currentState, challenge: currentChallenge)
    }
    
    private func persistCurrentStateNow() {
        persistence.persistCurrentStateNow(state: currentState, challenge: currentChallenge)
    }
    
    // MARK: - Sélection d'apps - Délégation aux managers
    
    func updateAppsSelection(_ selection: FamilyActivitySelection) {
        appRestrictionCoordinator.updateAppsSelection(selection)
    }
    
    func getAppsSelection() -> FamilyActivitySelection {
        return appRestrictionCoordinator.getAppsSelection()
    }
    
    func isAppsSelectionValid() -> Bool {
        return appRestrictionCoordinator.isAppsSelectionValid()
    }
    
    var canStartCustomSession: Bool {
        return currentState == .idle && appRestrictionCoordinator.canStartCustomSession
    }
    
    func syncSelectedAppsCount() {
        appRestrictionCoordinator.syncSelectedAppsCount()
    }
    
    // MARK: - Détails apps - Délégation aux managers
    
    func getSelectedAppsDetails() async -> [AppDetail] {
        return await appRestrictionCoordinator.getSelectedAppsDetails()
    }
    
    func getSelectedAppsNames() -> [String] {
        return appRestrictionCoordinator.getSelectedAppsNames()
    }
    
    private func generateAppNamesFromSelection(_ selection: FamilyActivitySelection) -> [String] {
        return appRestrictionCoordinator.generateAppNamesFromSelection(selection)
    }
    
    func isAppSelected(bundleIdentifier: String) -> Bool {
        return appRestrictionCoordinator.isAppSelected(bundleIdentifier: bundleIdentifier)
    }
    
    func updateAppsSelectionWithDetails(_ selection: FamilyActivitySelection) {
        appRestrictionCoordinator.updateAppsSelectionWithDetails(selection)
    }
    
    // MARK: - App Attempt Tracking - Délégation aux managers
    
    func recordAppOpenAttempt(appName: String? = nil) {
        challengeStateManager.recordAppOpenAttempt(appName: appName)
        let appInfo = appName != nil ? " (\(appName!))" : ""
        recordActivity(.challengeStarted, title: "Tentative d'accès à une app bloquée\(appInfo)")
    }
    
    func getTopAttemptedApps() -> [(String, Int)] {
        return challengeStateManager.getTopAttemptedApps()
    }
    
    // MARK: - DeviceActivity Monitoring - Délégation aux managers
    
    private func startDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        deviceActivityCoordinator.startMonitoring(for: challenge)
    }
    
    private func stopDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        deviceActivityCoordinator.stopMonitoring(for: challenge)
    }
    
    // MARK: - Badge Statistics - Délégation aux managers
    
    private func loadStatistics() {
        // Géré par StatisticsCoordinator dans init()
    }
    
    private func updateChallengeStatistics(challenge: ZenloopChallenge) {
        // Géré par StatisticsCoordinator dans challengeCompleted delegate
    }
    
    func applicationWillTerminate() {
        // Signaler à l'extension que l'app se ferme
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "app_terminated_at")
        suite?.synchronize()
        
        print("📱 [ZENLOOP] App is terminating - Extension should detect this")
    }
    
    // MARK: - Extension Session Monitoring
    
    private func startExtensionSessionMonitoring() {
        // Surveiller les sessions activées par l'extension toutes les 2 secondes
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForExtensionActivatedSession()
            }
        }
    }
    
    @MainActor
    private func checkForExtensionActivatedSession() {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // NOUVEAU: Traiter la queue au lieu d'une seule session
        guard let activationQueue = suite?.array(forKey: "extension_activation_queue") as? [[String: Any]],
              !activationQueue.isEmpty else {
            return // Pas de sessions en queue
        }
        
        print("📋 [ZENLOOP] Processing \(activationQueue.count) queued sessions")
        
        // Traiter chaque session dans la queue
        for (index, sessionData) in activationQueue.enumerated() {
            guard let sessionId = sessionData["id"] as? String,
                  let title = sessionData["title"] as? String,
                  let duration = sessionData["duration"] as? TimeInterval,
                  let startTimeInterval = sessionData["startTime"] as? TimeInterval,
                  let activationId = sessionData["activationId"] as? String,
                  let isScheduled = sessionData["isScheduled"] as? Bool,
                  isScheduled == true else {
                continue
            }
            
            // extensionTriggeredAt est optionnel (rétrocompatibilité)
            let extensionTriggeredAt = sessionData["extensionTriggeredAt"] as? TimeInterval
            
            // Vérifier si cette activation a déjà été traitée
            let processedActivations = suite?.array(forKey: "processed_activation_ids") as? [String] ?? []
            if processedActivations.contains(activationId) {
                print("⏭️ [ZENLOOP] Skipping already processed activation: \(activationId)")
                continue
            }
            
            print("🔥 [ZENLOOP] Processing session from queue: \(title) (\(index + 1)/\(activationQueue.count))")
            
            // CRUCIAL: Utiliser l'heure réelle où l'extension s'est déclenchée (si disponible)
            let realStartTime: Date
            if let extensionTime = extensionTriggeredAt {
                realStartTime = Date(timeIntervalSince1970: extensionTime)
                print("🕘 [ZENLOOP] Utilisation heure réelle extension: \(realStartTime)")
            } else {
                // Fallback pour rétrocompatibilité
                realStartTime = Date(timeIntervalSince1970: startTimeInterval)
                print("🕘 [ZENLOOP] Fallback - utilisation heure programmée: \(realStartTime)")
            }
            
            let originalStartTime = Date(timeIntervalSince1970: startTimeInterval)
            
            print("🕘 [ZENLOOP] Timing analysis:")
            print("   Programmée pour: \(originalStartTime)")
            print("   Extension déclenchée: \(realStartTime)")
            print("   Maintenant: \(Date())")
            
            let activeChallenge = ZenloopChallenge(
                id: sessionId,
                title: title,
                description: "Session programmée déclenchée automatiquement",
                duration: duration,
                difficulty: .medium,
                startTime: realStartTime, // Utiliser l'heure réelle de l'extension ou fallback
                isActive: true
            )
            
            // Activer la session (avec gestion des conflits intégrée)
            self.activateScheduledSession(activeChallenge)
            
            // Marquer cette activation comme traitée
            var updatedProcessedIds = processedActivations
            updatedProcessedIds.append(activationId)
            
            // Garder seulement les 20 derniers IDs pour éviter l'overflow
            if updatedProcessedIds.count > 20 {
                updatedProcessedIds = Array(updatedProcessedIds.suffix(20))
            }
            
            suite?.set(updatedProcessedIds, forKey: "processed_activation_ids")
        }
        
        // Nettoyer la queue après traitement
        suite?.removeObject(forKey: "extension_activation_queue")
        suite?.synchronize()
        
        print("✅ [ZENLOOP] Finished processing session queue")
    }
    
    private func activateScheduledSession(_ challenge: ZenloopChallenge) {
        // VÉRIFICATION DE COHÉRENCE: S'il y a déjà une session active
        if currentState == .active, let existingChallenge = currentChallenge {
            print("⚠️ [ZENLOOP] Session conflict detected!")
            print("   Existing: \(existingChallenge.title) (started \(existingChallenge.startTime?.timeIntervalSinceNow ?? 0)s ago)")
            print("   New: \(challenge.title)")
            
            // Logique intelligente de résolution de conflit
            resolveSessionConflict(existing: existingChallenge, new: challenge)
            return
        }
        
        // VÉRIFICATION: S'assurer que la session n'est pas expirée
        guard let startTime = challenge.startTime,
              startTime.addingTimeInterval(challenge.duration) > Date() else {
            print("❌ [ZENLOOP] Scheduled session expired, ignoring: \(challenge.title)")
            return
        }
        
        // CORRIGÉ: Calculer le temps déjà écoulé depuis le vrai démarrage
        let now = Date()
        let elapsedTime = now.timeIntervalSince(startTime)
        let remainingTime = challenge.duration - elapsedTime
        
        print("⏱️ [ZENLOOP] Session timing:")
        print("   Programmée pour: \(startTime)")
        print("   Maintenant: \(now)")  
        print("   Temps écoulé: \(Int(elapsedTime))s")
        print("   Temps restant: \(Int(remainingTime))s")
        
        // Vérifier que la session n'est pas déjà expirée
        guard remainingTime > 0 else {
            print("❌ [ZENLOOP] Session already expired, ignoring")
            return
        }
        
        // CRUCIAL: Créer un nouveau challenge avec l'heure réelle de l'extension
        var synchronizedChallenge = challenge
        synchronizedChallenge.startTime = startTime // CORRIGÉ: Heure réelle de l'extension
        synchronizedChallenge.isActive = true
        
        // CORRIGÉ: Activer la session avec le challenge synchronisé
        currentChallenge = synchronizedChallenge
        currentState = .active
        currentTimeRemaining = formatTime(remainingTime)
        currentProgress = elapsedTime / challenge.duration
        
        // Update widget when session becomes active
        self.updateWidgetData()
        
        challengeStateManager.startChallenge(synchronizedChallenge)
        
        // CORRIGÉ: Charger les apps spécifiques à cette session programmée
        loadAppsForScheduledSession(challenge)
        
        print("✅ [ZENLOOP] Scheduled session activated: \(challenge.title)")
        
        // Mettre à jour le widget avec les nouvelles données
        updateWidgetData()
        
        // Envoyer une notification de confirmation
        notificationManager.notifySessionStarted(
            sessionTitle: challenge.title,
            sessionId: challenge.id
        )
    }
    
    private func loadAppsForScheduledSession(_ challenge: ZenloopChallenge) {
        // IMPORTANT: Ne pas écraser les restrictions de l'extension qui sont déjà actives
        // L'extension a déjà appliqué le blocage via ManagedSettings
        // On charge seulement les infos pour l'UI, pas pour réappliquer les restrictions
        
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
              let payloadData = suite.data(forKey: "payload_\(challenge.id)") else {
            print("⚠️ [ZENLOOP] No payload found for scheduled session: \(challenge.id)")
            return
        }
        
        do {
            let payload = try JSONDecoder().decode(SelectionPayload.self, from: payloadData)
            
            // Créer une FamilyActivitySelection pour l'UI seulement
            var selection = FamilyActivitySelection()
            selection.applicationTokens = Set(payload.apps)
            selection.categoryTokens = Set(payload.categories)
            
            // CRUCIAL: Mettre à jour seulement les variables UI SANS réappliquer les restrictions
            // L'extension gère déjà les restrictions via son propre ManagedSettingsStore nommé
            
            // Mettre à jour seulement les propriétés pour l'affichage UI
            selectedAppsCount = payload.apps.count + payload.categories.count
            
            // Ne PAS appeler updateAppsSelection() qui réappliquerait les restrictions
            // et interfèrerait avec le ManagedSettingsStore de l'extension
            
            let appsCount = payload.apps.count
            let categoriesCount = payload.categories.count
            print("📱 [ZENLOOP] Apps synchronisées pour UI (session programmée):")
            print("   Applications: \(appsCount)")
            print("   Catégories: \(categoriesCount)")
            print("   ⚠️  Restrictions PAS réappliquées - Extension les gère")
            
        } catch {
            print("❌ [ZENLOOP] Failed to decode payload for session: \(challenge.id) - \(error)")
        }
    }
    
    private func isScheduledSession(_ challenge: ZenloopChallenge) -> Bool {
        // Une session programmée a un ID qui commence par "scheduled_"
        // ou est marquée comme session programmée dans les données
        return challenge.id.hasPrefix("scheduled_") || 
               challenge.description.contains("programmée déclenchée automatiquement")
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d", hours, minutes)
        } else {
            return String(format: "00:%02d", minutes)
        }
    }
    
    private func resolveSessionConflict(existing: ZenloopChallenge, new: ZenloopChallenge) {
        // Calculer le temps restant pour la session existante
        let existingTimeRemaining = existing.startTime?.addingTimeInterval(existing.duration).timeIntervalSinceNow ?? 0
        
        if existingTimeRemaining < 60 {
            // Session existante finit dans moins de 1 minute : la terminer et démarrer la nouvelle
            print("🔄 [ZENLOOP] Existing session ending soon, switching to new one")
            completeCurrentChallenge()
            
            // Petit délai pour éviter les conflits
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.activateScheduledSession(new)
            }
        } else {
            // Session existante a encore du temps : reporter la nouvelle
            print("⏸️ [ZENLOOP] Postponing new session - existing one still running")
            
            // Notifier l'utilisateur du conflit
            notificationManager.notifySessionConflict(
                existing: existing.title,
                new: new.title,
                timeRemaining: Int(existingTimeRemaining / 60)
            )
            
            // Reporter la nouvelle session après la fin de l'existante
            let postponedStartTime = existing.startTime?.addingTimeInterval(existing.duration).addingTimeInterval(120) ?? Date().addingTimeInterval(120) // +2min buffer
            
            schedulePostponedSession(challenge: new, newStartTime: postponedStartTime)
        }
    }
    
    private func schedulePostponedSession(challenge: ZenloopChallenge, newStartTime: Date) {
        // Créer une nouvelle session programmée avec le timing reporté
        var postponedChallenge = challenge
        postponedChallenge.startTime = newStartTime
        
        // Re-programmer via le BlockScheduler
        do {
            try BlockScheduler.shared.scheduleSession(
                title: "\(challenge.title) (reporté)",
                duration: challenge.duration,
                startTime: newStartTime,
                selection: FamilyActivitySelection() // TODO: Récupérer la vraie sélection
            )
            
            // Programmer les nouvelles notifications
            notificationManager.scheduleSessionReminder(
                sessionId: challenge.id,
                title: "\(challenge.title) (reporté)",
                startTime: newStartTime,
                duration: challenge.duration
            )
            
            print("📅 [ZENLOOP] Session postponed to \(newStartTime)")
        } catch {
            print("❌ [ZENLOOP] Failed to postpone session: \(error)")
        }
    }
    
    deinit {
        Task { @MainActor in
            applicationWillTerminate()
            challengeStateManager.cancelTimers()
        }
    }
}

// MARK: - ChallengeStateManagerDelegate

extension ZenloopManager: ChallengeStateManagerDelegate {
    func stateDidChange(to state: ZenloopState, challenge: ZenloopChallenge?) {
        currentState = state
        currentChallenge = challenge
        
        // Synchroniser avec la persistance
        persistence.persistCurrentStateDebounced(state: state, challenge: challenge)
        
        // Mettre à jour le widget quand l'état change
        updateWidgetData()
        
        // Gérer les restrictions selon l'état
        switch state {
        case .active:
            if appRestrictionCoordinator.isAuthorized {
                // CRUCIAL: Ne pas réappliquer les restrictions pour les sessions programmées
                // car l'extension les gère déjà via son propre ManagedSettingsStore
                if let challenge = challenge, isScheduledSession(challenge) {
                    print("⚠️ [ZENLOOP] Session programmée détectée - restrictions gérées par l'extension")
                    // Ne pas appeler applyRestrictions() pour éviter d'écraser l'extension
                } else {
                    // Session manuelle - appliquer les restrictions normalement
                    appRestrictionCoordinator.applyRestrictions()
                }
            }
            if let challenge = challenge {
                // Pour les sessions programmées, le monitoring est déjà actif via l'extension
                if !isScheduledSession(challenge) {
                    deviceActivityCoordinator.startMonitoring(for: challenge)
                }
            }
        case .idle, .completed, .paused:
            // CRUCIAL: Vérification complète avant suppression des restrictions
            let hasScheduledSessions = appRestrictionCoordinator.hasActiveScheduledSession()
            let isScheduledChallenge = challenge != nil && isScheduledSession(challenge!)
            
            if !hasScheduledSessions && !isScheduledChallenge {
                appRestrictionCoordinator.removeRestrictions()
                print("🔓 [ZENLOOP] Aucune session programmée - restrictions supprimées")
            } else {
                print("⚠️ [ZENLOOP] Sessions programmées actives détectées - restrictions préservées")
                print("   hasScheduledSessions: \(hasScheduledSessions)")
                print("   isScheduledChallenge: \(isScheduledChallenge)")
            }
            
            if let challenge = challenge {
                // Ne pas arrêter le monitoring pour les sessions programmées
                if !isScheduledSession(challenge) {
                    deviceActivityCoordinator.stopMonitoring(for: challenge)
                }
            }
        }
    }
    
    func challengeProgressUpdated(timeRemaining: String, progress: Double) {
        currentTimeRemaining = timeRemaining
        currentProgress = progress
    }
    
    func pauseTimeUpdated(timeRemaining: String) {
        pauseTimeRemaining = timeRemaining
    }
    
    func challengeCompleted(challenge: ZenloopChallenge) {
        // Mettre à jour les statistiques
        statisticsCoordinator.updateChallengeStatistics(challenge: challenge)
        statisticsCoordinator.updateWeeklyStats()
        statisticsCoordinator.updateMonthlyStats()
        statisticsCoordinator.updateLongestSession(challenge.duration)
        
        // Enregistrer l'activité
        var activities = recentActivity
        persistence.addActivityRecord(
            ActivityRecord(type: .challengeCompleted, title: "Défi \(challenge.title) terminé avec succès", timestamp: Date(), duration: challenge.duration),
            to: &activities
        )
        recentActivity = activities
        
        // Notifier la fin
        notificationManager.notifySessionCompleted(sessionTitle: challenge.title, sessionId: challenge.id)
        
        // Synchroniser les statistiques publiées
        totalSavedTime = statisticsCoordinator.totalSavedTime
        completedChallengesTotal = statisticsCoordinator.completedChallengesTotal
        currentStreakCount = statisticsCoordinator.currentStreakCount
        
        // Mettre à jour le widget après completion
        updateWidgetData()
    }
    
    // MARK: - Widget Data Updates
    
    func updateWidgetData() {
        // Mettre à jour les données du widget via App Groups directement
        // Au lieu d'utiliser les types du widget, utiliser des UserDefaults simples
        
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [ZENLOOP] Cannot access App Group for widget update")
            return
        }
        
        // Mapper l'état pour le widget (nouvelle structure)
        let widgetState = mapStateToString(currentState)
        
        suite.set(widgetState, forKey: "widget_current_state")
        suite.set(completedChallengesTotal, forKey: "widget_sessions_completed")
        suite.set(currentStreakCount, forKey: "widget_streak")
        
        // Session active (nouvelle structure)
        if currentState == .active || currentState == .paused, let challenge = currentChallenge {
            let sessionId = UUID().uuidString
            suite.set(sessionId, forKey: "widget_active_session_id")
            suite.set(challenge.title, forKey: "widget_active_session_title")
            suite.set(currentTimeRemaining, forKey: "widget_active_session_time_remaining")
            suite.set(currentProgress, forKey: "widget_active_session_progress")
            suite.set("manual", forKey: "widget_active_session_origin")
            suite.set(Date(), forKey: "widget_active_session_start_time")
            suite.set(challenge.duration, forKey: "widget_active_session_duration")
        } else {
            // Clear active session data
            suite.removeObject(forKey: "widget_active_session_id")
            suite.removeObject(forKey: "widget_active_session_title")
            suite.removeObject(forKey: "widget_active_session_time_remaining")
            suite.removeObject(forKey: "widget_active_session_progress")
            suite.removeObject(forKey: "widget_active_session_origin")
            suite.removeObject(forKey: "widget_active_session_start_time")
            suite.removeObject(forKey: "widget_active_session_duration")
        }
        
        // Prochaine session programmée (nouvelle structure)
        if let nextSession = nextScheduledSession {
            let nextSessionId = UUID().uuidString
            suite.set(nextSessionId, forKey: "widget_next_session_id")
            suite.set(nextSession.title, forKey: "widget_next_session_title")
            suite.set(nextSession.startTime, forKey: "widget_next_session_start")
            suite.set(nextSession.duration, forKey: "widget_next_session_duration")
        } else {
            suite.removeObject(forKey: "widget_next_session_id")
            suite.removeObject(forKey: "widget_next_session_title")
            suite.removeObject(forKey: "widget_next_session_start")
            suite.removeObject(forKey: "widget_next_session_duration")
        }
        
        suite.set(Date(), forKey: "widget_last_updated")
        suite.synchronize()
        
        print("📱 [ZENLOOP] Widget data updated: \(widgetState)")
        
        // Forcer la mise à jour du widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func mapStateToString(_ state: ZenloopState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .active:
            return "active"
        case .paused:
            return "paused"
        case .completed:
            return "completed"
        }
    }
}

// MARK: - AppRestrictionCoordinatorDelegate

extension ZenloopManager: AppRestrictionCoordinatorDelegate {
    func selectedAppsCountChanged(_ count: Int) {
        selectedAppsCount = count
    }
    
    func appsSelectionUpdated(_ selection: FamilyActivitySelection) {
        // Mise à jour handled by coordinator
    }
}

// MARK: - DeviceActivityCoordinatorDelegate

extension ZenloopManager: DeviceActivityCoordinatorDelegate {
    func deviceActivityEventReceived(type: String, activity: String, timestamp: TimeInterval) {
        // Events are processed by the coordinator
    }
    
    func challengeShouldComplete() {
        if currentState == .active {
            challengeStateManager.completeChallenge()
        }
    }
    
    func appThresholdReached() {
        // Handle app threshold reached
        debugPrint("⚠️ [ZenloopManager] App usage threshold reached")
    }
}

// MARK: - ZenloopPersistenceDelegate

extension ZenloopManager: ZenloopPersistenceDelegate {
    func dataDidLoad() {
        // Data loading completed
    }
    
    func dataDidSave() {
        // Data saving completed
    }
    
    func loadingError(_ error: Error) {
        #if DEBUG
        logger.error("❌ [ZenloopManager] Persistence error: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - StatisticsCoordinatorDelegate

extension ZenloopManager: StatisticsCoordinatorDelegate {
    func statisticsDidUpdate() {
        // Synchroniser les valeurs publiées
        totalSavedTime = statisticsCoordinator.totalSavedTime
        completedChallengesTotal = statisticsCoordinator.completedChallengesTotal
        currentStreakCount = statisticsCoordinator.currentStreakCount
    }
    
    func badgeEarned(type: BadgeType, value: Any) {
        // Handle badge earned
        debugPrint("🏆 [ZenloopManager] Badge earned: \(type.rawValue) - \(value)")
    }
    
    func streakUpdated(newStreak: Int) {
        currentStreakCount = newStreak
    }
}

// MARK: - ScheduledSessionsCoordinatorDelegate

extension ZenloopManager: ScheduledSessionsCoordinatorDelegate {
    func scheduledSessionShouldStart(_ challenge: ZenloopChallenge, apps: FamilyActivitySelection) {
        // Mettre à jour la sélection d'apps et démarrer le challenge
        updateAppsSelection(apps)
        startChallenge(challenge)
        
        // Notifier l'utilisateur
        notificationManager.notifySessionStarted(sessionTitle: challenge.title, sessionId: challenge.id)
    }
    
    func scheduledSessionCreated(sessionId: String, title: String) {
        // Session programmée créée avec succès
        #if DEBUG
        print("📅 [ZENLOOP] Session programmée créée: \(title)")
        #endif
    }
    
    func scheduledSessionCancelled(sessionId: String) {
        // Session programmée annulée
        #if DEBUG
        print("🗑️ [ZENLOOP] Session programmée annulée: \(sessionId)")
        #endif
    }
    
    func generateAppNames(from selection: FamilyActivitySelection) -> [String] {
        return appRestrictionCoordinator.generateAppNamesFromSelection(selection)
    }
    
    func recordActivity(type: ActivityRecord.ActivityType, title: String) {
        recordActivity(type, title: title)
    }
}
