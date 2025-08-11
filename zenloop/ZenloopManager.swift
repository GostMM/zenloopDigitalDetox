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
import os

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
    }
}

// MARK: - Ticker GCD (1 Hz)

final class Ticker {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "zenloop.ticker", qos: .utility)
    
    func start(every seconds: Double = 1.0, handler: @escaping () -> Void) {
        self.stop()
        let t = DispatchSource.makeTimerSource(queue: self.queue)
        t.schedule(deadline: .now() + seconds,
                   repeating: seconds,
                   leeway: .milliseconds(100)) // coalescing
        t.setEventHandler(handler: handler)
        t.resume()
        self.timer = t
    }
    
    func stop() { self.timer?.cancel(); self.timer = nil }
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
    
    // MARK: - Propriétés nonisolated (badges)
    nonisolated var completedChallengesCount: Int { UserDefaults.standard.integer(forKey: "completed_challenges_count") }
    nonisolated var totalFocusTime: TimeInterval { UserDefaults.standard.double(forKey: "total_focus_time") }
    nonisolated var maxAppsBlockedSimultaneously: Int { UserDefaults.standard.integer(forKey: "max_apps_blocked") }
    nonisolated var currentStreak: Int { UserDefaults.standard.integer(forKey: "current_streak") }
    
    // MARK: - Privées
    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private var pauseEndTime: Date?
    private var blockedAppsSelection = FamilyActivitySelection()
    
    private let ticker = Ticker()
    private var lastSecondBroadcast: Int? = nil
    private var lastProgress: Double = -1
    private var lastPauseSecondBroadcast: Int? = nil
    
    private var lastEventsCheck: TimeInterval = 0
    
    private var persistWorkItem: DispatchWorkItem?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "Zenloop")
    private let verboseLogging = false
    #endif
    
    private init() {
        self.loadPersistedData()
        self.loadPersistedAppsSelection()
        self.checkAuthorizationStatus()
        self.loadStatistics()
    }
    
    // MARK: - Initialisation
    
    func initialize() {
        #if DEBUG
        self.logger.debug("🚀 [ZENLOOP] Initialisation du gestionnaire")
        #endif
        
        self.startStateMonitoring()
        self.checkAuthorizationStatus()
        self.loadRecentActivity()
        self.syncSelectedAppsCount()
        
        if !self.isAuthorized {
            Task { @MainActor in
                await self.requestAuthorization()
            }
        }
        
        if let challenge = self.currentChallenge, challenge.isActive {
            self.currentState = .active
            self.currentTimeRemaining = challenge.timeRemaining
            self.currentProgress = challenge.safeProgress
            
            if self.isAuthorized && self.isAppsSelectionValid() {
                self.applyRestrictions()
            } else if self.isAuthorized {
                #if DEBUG
                self.logger.warning("⚠️ [ZENLOOP] Apps doivent être re-sélectionnées pour appliquer les restrictions")
                #endif
            }
            self.scheduleAutoCompletion()
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
    
    // MARK: - Autorisations
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.checkAuthorizationStatus()
            #if DEBUG
            self.logger.debug("✅ [ZENLOOP] Autorisation accordée")
            #endif
        } catch {
            #if DEBUG
            self.logger.error("❌ [ZENLOOP] Erreur autorisation: \(error.localizedDescription)")
            #endif
            self.isAuthorized = false
        }
    }
    
    private func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        self.isAuthorized = status == .approved
        #if DEBUG
        self.logger.debug("🔐 [ZENLOOP] Statut autorisation: \(String(describing: status))")
        #endif
    }
    
    // MARK: - Défis
    
    func startQuickChallenge(duration: TimeInterval) {
        guard self.currentState == .idle else { return }
        
        var challenge = ZenloopChallenge(
            id: "quick-\(UUID().uuidString)",
            title: "Focus Rapide",
            description: "Session de concentration rapide",
            duration: duration,
            difficulty: .medium,
            startTime: Date(),
            isActive: true
        )
        challenge.blockedAppsNames = ["Instagram", "TikTok", "Twitter", "Facebook", "YouTube"]
        challenge.blockedAppsCount = challenge.blockedAppsNames.count
        
        self.startChallenge(challenge)
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
    
    private func startChallenge(_ challenge: ZenloopChallenge) {
        self.currentChallenge = challenge
        self.currentState = .active
        
        self.currentTimeRemaining = challenge.timeRemaining
        self.currentProgress = challenge.safeProgress
        
        self.startStateMonitoring()
        self.applyRestrictions()
        self.startDeviceActivityMonitoring(for: challenge)
        
        self.recordActivity(.challengeStarted, title: "Défi \(challenge.title) démarré", duration: challenge.duration)
        self.persistCurrentStateNow()
        self.scheduleAutoCompletion()
        _ = self.validateState()
    }
    
    // MARK: - Arrêt / Complétion
    
    func initiateStopWithBreathing() {
        guard let challenge = self.currentChallenge, self.currentState == .active || self.currentState == .paused else { return }
        _ = challenge
        self.showBreathingMeditation = true
    }
    
    func stopCurrentChallenge() {
        guard let challenge = self.currentChallenge, self.currentState == .active || self.currentState == .paused else { return }
        
        self.showBreathingMeditation = false
        self.removeRestrictions()
        self.stopDeviceActivityMonitoring(for: challenge)
        
        var updated = challenge
        updated.isActive = false
        self.currentChallenge = updated
        self.currentState = .idle
        
        self.recordActivity(.challengeStopped, title: "Défi \(challenge.title) arrêté")
        self.cancelTimers()
        self.persistCurrentStateNow()
        _ = self.validateState()
    }
    
    func completeCurrentChallenge() {
        guard let challenge = self.currentChallenge, self.currentState == .active else { return }
        
        self.removeRestrictions()
        
        var updated = challenge
        updated.isActive = false
        updated.isCompleted = true
        self.currentChallenge = updated
        self.currentState = .completed
        
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
        self.currentChallenge = nil
        self.currentState = .idle
        self.pauseEndTime = nil
        self.pauseTimeRemaining = "00:00"
        
        self.cancelTimers()
        self.persistCurrentStateDebounced()
    }
    
    // MARK: - Pause / Reprise
    
    func requestPause() {
        guard let challenge = self.currentChallenge, self.currentState == .active else { return }
        
        var updated = challenge
        updated.pausedTime = Date()
        self.currentChallenge = updated
        self.currentState = .paused
        
        self.removeRestrictions()
        
        self.pauseEndTime = Date().addingTimeInterval(5 * 60)
        self.recordActivity(.challengePaused, title: "Pause de 5 minutes")
        self.persistCurrentStateNow()
    }
    
    func resumeChallenge() {
        guard let challenge = self.currentChallenge, self.currentState == .paused else { return }
        
        if let pausedTime = challenge.pausedTime {
            let pauseDur = Date().timeIntervalSince(pausedTime)
            var updated = challenge
            updated.pauseDuration += pauseDur
            updated.pausedTime = nil
            updated.isActive = true
            self.currentChallenge = updated
        }
        
        self.currentState = .active
        self.applyRestrictions()
        self.pauseEndTime = nil
        self.pauseTimeRemaining = "00:00"
        
        self.startStateMonitoring()
        self.scheduleAutoCompletion()
        
        self.recordActivity(.challengeResumed, title: "Défi repris")
        self.persistCurrentStateNow()
    }
    
    // MARK: - Restrictions
    
    private func applyRestrictions() {
        guard self.isAuthorized else { return }
        
        let appTokens = self.blockedAppsSelection.applicationTokens
        self.store.shield.applications = appTokens
        
        if !self.blockedAppsSelection.categoryTokens.isEmpty {
            self.store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
                .specific(self.blockedAppsSelection.categoryTokens)
        }
        
        #if DEBUG
        if self.verboseLogging {
            self.logger.debug("🛡️ Restrictions appliquées: \(appTokens.count) apps, \(self.blockedAppsSelection.categoryTokens.count) catégories")
        }
        #endif
    }
    
    private func removeRestrictions() {
        self.store.shield.applications = nil
        self.store.shield.applicationCategories = nil
    }
    
    // MARK: - Ticker (1 Hz)
    
    func startStateMonitoring() {
        self.ticker.start(every: 1.0) { [weak self] in
            // tick est @MainActor — on y revient proprement
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    func cancelTimers() {
        self.ticker.stop()
    }
    
    // @MainActor: on garde la sécurité UI; on a réduit au minimum le travail ici
    private func tick() {
        let now = Date()
        
        // 1) DeviceActivity events (throttlé)
        let nowTs = now.timeIntervalSince1970
        if nowTs - self.lastEventsCheck >= 8 {
            self.lastEventsCheck = nowTs
            self.checkDeviceActivityEvents()
        }
        
        // 2) Défi actif
        if let c = self.currentChallenge, c.isActive, let start = c.startTime {
            let elapsed = now.timeIntervalSince(start) - c.pauseDuration
            let remaining = max(0, c.duration - elapsed)
            let sec = Int(remaining.rounded(.down))
            let prog = min(1, max(0, elapsed / max(1, c.duration)))
            
            if self.lastSecondBroadcast != sec || abs(prog - self.lastProgress) > 0.001 {
                self.lastSecondBroadcast = sec
                self.lastProgress = prog
                let timeString = Self.mmss(sec)
                
                if self.currentTimeRemaining != timeString { self.currentTimeRemaining = timeString }
                if abs(self.currentProgress - prog) > 0.001 { self.currentProgress = prog }
                if prog >= 1.0, self.currentState == .active { self.completeCurrentChallenge() }
            }
            return
        }
        
        // 3) Pause en cours
        if self.currentState == .paused, let end = self.pauseEndTime {
            let remain = max(0, Int(end.timeIntervalSinceNow.rounded(.down)))
            if self.lastPauseSecondBroadcast != remain {
                self.lastPauseSecondBroadcast = remain
                let str = Self.mmss(remain)
                if self.pauseTimeRemaining != str { self.pauseTimeRemaining = str }
                if remain == 0 { self.resumeChallenge() }
            }
            return
        }
        
        // 4) État inactif
        if self.currentState != .active {
            if self.currentTimeRemaining != "00:00" { self.currentTimeRemaining = "00:00" }
            if self.currentProgress != 0 { self.currentProgress = 0 }
        }
    }
    
    private static func mmss(_ s: Int) -> String {
        let clamped = max(0, s)
        return String(format: "%02d:%02d", clamped/60, clamped%60)
    }
    
    // MARK: - Auto-completion
    
    private func scheduleAutoCompletion() {
        guard let challenge = self.currentChallenge, let startTime = challenge.startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime) - challenge.pauseDuration
        let remainingTime = max(challenge.duration - elapsedTime, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) { [weak self] in
            if self?.currentState == .active {
                self?.completeCurrentChallenge()
            }
        }
    }
    
    // MARK: - Persistance & activité (debounce, pas d'I/O dans tick)
    
    private func recordActivity(_ type: ActivityRecord.ActivityType, title: String, duration: TimeInterval? = nil) {
        let activity = ActivityRecord(type: type, title: title, timestamp: Date(), duration: duration)
        self.recentActivity.insert(activity, at: 0)
        if self.recentActivity.count > 20 { self.recentActivity = Array(self.recentActivity.prefix(20)) }
        self.saveRecentActivityDebounced()
    }
    
    private func persistCurrentStateDebounced() {
        self.persistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?._persistCurrentStateNow()
        }
        self.persistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }
    
    private func persistCurrentStateNow() {
        self._persistCurrentStateNow()
    }
    
    private func _persistCurrentStateNow() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(self.currentState.rawValue, forKey: "zenloop_current_state")
        if let challenge = self.currentChallenge, let data = try? JSONEncoder().encode(challenge) {
            userDefaults.set(data, forKey: "zenloop_current_challenge")
        } else {
            userDefaults.removeObject(forKey: "zenloop_current_challenge")
        }
    }
    
    private func loadPersistedData() {
        let userDefaults = UserDefaults.standard
        if let stateString = userDefaults.string(forKey: "zenloop_current_state"),
           let state = ZenloopState(rawValue: stateString) {
            self.currentState = state
        }
        if let data = userDefaults.data(forKey: "zenloop_current_challenge"),
           let challenge = try? JSONDecoder().decode(ZenloopChallenge.self, from: data) {
            self.currentChallenge = challenge
        }
    }
    
    private func loadRecentActivity() {
        if let data = UserDefaults.standard.data(forKey: "zenloop_recent_activity"),
           let activities = try? JSONDecoder().decode([ActivityRecord].self, from: data) {
            self.recentActivity = activities
        }
    }
    
    private func saveRecentActivityDebounced() {
        self.persistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(self.recentActivity) {
                UserDefaults.standard.set(data, forKey: "zenloop_recent_activity")
            }
        }
        self.persistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }
    
    // MARK: - Sélection d'apps
    
    func updateAppsSelection(_ selection: FamilyActivitySelection) {
        self.blockedAppsSelection = selection
        self.selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        self.persistAppsSelection()
    }
    
    func getAppsSelection() -> FamilyActivitySelection {
        return self.blockedAppsSelection
    }
    
    func isAppsSelectionValid() -> Bool {
        return (!self.blockedAppsSelection.applicationTokens.isEmpty) || (!self.blockedAppsSelection.categoryTokens.isEmpty)
    }
    
    var canStartCustomSession: Bool {
        return self.currentState == .idle && self.isAppsSelectionValid()
    }
    
    func syncSelectedAppsCount() {
        let actualCount = self.blockedAppsSelection.applicationTokens.count + self.blockedAppsSelection.categoryTokens.count
        if self.selectedAppsCount != actualCount {
            self.selectedAppsCount = actualCount
            self.persistAppsSelection()
        }
    }
    
    private func persistAppsSelection() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self.blockedAppsSelection)
            UserDefaults.standard.set(data, forKey: "zenloop_apps_selection")
            UserDefaults.standard.set(self.selectedAppsCount, forKey: "zenloop_selected_apps_count")
        } catch {
            UserDefaults.standard.set(self.selectedAppsCount, forKey: "zenloop_selected_apps_count")
        }
    }
    
    private func loadPersistedAppsSelection() {
        if let data = UserDefaults.standard.data(forKey: "zenloop_apps_selection") {
            do {
                let decoder = JSONDecoder()
                self.blockedAppsSelection = try decoder.decode(FamilyActivitySelection.self, from: data)
                self.selectedAppsCount = self.blockedAppsSelection.applicationTokens.count + self.blockedAppsSelection.categoryTokens.count
            } catch {
                self.selectedAppsCount = 0
                self.blockedAppsSelection = FamilyActivitySelection()
            }
        } else {
            self.selectedAppsCount = UserDefaults.standard.integer(forKey: "zenloop_selected_apps_count")
            if self.selectedAppsCount > 0 {
                self.selectedAppsCount = 0
                UserDefaults.standard.set(0, forKey: "zenloop_selected_apps_count")
            }
        }
    }
    
    // MARK: - Détails apps
    
    func getSelectedAppsDetails() async -> [AppDetail] {
        var details: [AppDetail] = []
        for token in self.blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            let detail = AppDetail(
                token: token,
                displayName: "App sélectionnée",
                bundleIdentifier: app.bundleIdentifier ?? "",
                isApplication: true
            )
            details.append(detail)
        }
        return details
    }
    
    func getSelectedAppsNames() -> [String] {
        var names: [String] = []
        for token in self.blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    private func generateAppNamesFromSelection(_ selection: FamilyActivitySelection) -> [String] {
        var names: [String] = []
        for token in selection.applicationTokens {
            let app = Application(token: token)
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        if !selection.categoryTokens.isEmpty {
            names.append(contentsOf: Array(repeating: "Catégorie", count: selection.categoryTokens.count))
        }
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    func isAppSelected(bundleIdentifier: String) -> Bool {
        for token in self.blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            if app.bundleIdentifier == bundleIdentifier { return true }
        }
        return false
    }
    
    func updateAppsSelectionWithDetails(_ selection: FamilyActivitySelection) {
        self.blockedAppsSelection = selection
        self.selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        
        Task { [weak self] in
            guard let self = self else { return }
            let appDetails = await self.getSelectedAppsDetails()
            let appNames = appDetails.map { $0.displayName }
            await MainActor.run {
                debugPrint("📱 [ZENLOOP] Apps sélectionnées: \(appNames.joined(separator: ", "))")
            }
        }
        
        self.persistAppsSelection()
    }
    
    // MARK: - App Attempt Tracking
    
    func recordAppOpenAttempt(appName: String? = nil) {
        guard var challenge = self.currentChallenge, self.currentState == .active else { return }
        challenge.appOpenAttempts += 1
        if let appName = appName {
            challenge.attemptedApps[appName, default: 0] += 1
        }
        self.currentChallenge = challenge
        self.persistCurrentStateDebounced()
        let appInfo = appName != nil ? " (\(appName!))" : ""
        self.recordActivity(.challengeStarted, title: "Tentative d'accès à une app bloquée\(appInfo)")
    }
    
    func getTopAttemptedApps() -> [(String, Int)] {
        guard let challenge = self.currentChallenge else { return [] }
        return challenge.attemptedApps.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    // MARK: - DeviceActivity Monitoring
    
    private func startDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        guard self.isAuthorized else { return }
        
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        let startDate = challenge.startTime ?? Date()
        let endDate = startDate.addingTimeInterval(challenge.duration)
        
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
            try self.activityCenter.startMonitoring(activityName, during: schedule)
        } catch {
            #if DEBUG
            self.logger.error("❌ [DeviceActivity] Erreur monitoring: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func stopDeviceActivityMonitoring(for challenge: ZenloopChallenge) {
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        self.activityCenter.stopMonitoring([activityName])
    }
    
    func checkDeviceActivityEvents() {
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        if let events = defaults.array(forKey: "device_activity_events") as? [[String: Any]] {
            for event in events {
                if let eventType = event["event"] as? String,
                   let activity = event["activity"] as? String,
                   let timestamp = event["timestamp"] as? TimeInterval {
                    self.handleDeviceActivityEvent(type: eventType, activity: activity, timestamp: timestamp)
                }
            }
            defaults.removeObject(forKey: "device_activity_events")
        }
    }
    
    private func handleDeviceActivityEvent(type: String, activity: String, timestamp: TimeInterval) {
        switch type {
        case "intervalDidEnd":
            if self.currentState == .active { self.completeCurrentChallenge() }
        case "thresholdReached":
            debugPrint("⚠️ [DeviceActivity] Seuil atteint")
        case "warningStart", "warningEnd":
            debugPrint("🔔 [DeviceActivity] Avertissement: \(type)")
        default:
            debugPrint("📱 [DeviceActivity] Événement inconnu: \(type)")
        }
    }
    
    // MARK: - Badge Statistics
    
    private func loadStatistics() {
        self.totalSavedTime = UserDefaults.standard.double(forKey: "total_focus_time")
        self.completedChallengesTotal = UserDefaults.standard.integer(forKey: "completed_challenges_count")
        self.currentStreakCount = UserDefaults.standard.integer(forKey: "current_streak")
    }
    
    private func updateChallengeStatistics(challenge: ZenloopChallenge) {
        let currentCount = UserDefaults.standard.integer(forKey: "completed_challenges_count")
        UserDefaults.standard.set(currentCount + 1, forKey: "completed_challenges_count")
        
        let currentFocusTime = UserDefaults.standard.double(forKey: "total_focus_time")
        UserDefaults.standard.set(currentFocusTime + challenge.duration, forKey: "total_focus_time")
        
        let currentMax = UserDefaults.standard.integer(forKey: "max_apps_blocked")
        if challenge.blockedAppsCount > currentMax {
            UserDefaults.standard.set(challenge.blockedAppsCount, forKey: "max_apps_blocked")
        }
        
        self.totalSavedTime = currentFocusTime + challenge.duration
        self.completedChallengesTotal = currentCount + 1
        
        self.updateConsecutiveDays()
    }
    
    private func updateConsecutiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastChallengeDate = UserDefaults.standard.object(forKey: "last_challenge_date") as? Date
        
        if let lastDate = lastChallengeDate {
            let lastChallengeDay = Calendar.current.startOfDay(for: lastDate)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastChallengeDay, to: today).day ?? 0
            
            if daysBetween == 1 {
                let currentStreak = UserDefaults.standard.integer(forKey: "current_streak")
                UserDefaults.standard.set(currentStreak + 1, forKey: "current_streak")
            } else if daysBetween > 1 {
                UserDefaults.standard.set(1, forKey: "current_streak")
            }
        } else {
            UserDefaults.standard.set(1, forKey: "current_streak")
        }
        
        UserDefaults.standard.set(today, forKey: "last_challenge_date")
        self.currentStreakCount = UserDefaults.standard.integer(forKey: "current_streak")
    }
    
    deinit {
        self.ticker.stop()
    }
}
