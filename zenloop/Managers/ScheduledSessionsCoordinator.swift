//  ScheduledSessionsCoordinator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import FamilyControls
import os

// MARK: - Scheduled Sessions Management

protocol ScheduledSessionsCoordinatorDelegate: AnyObject {
    func scheduledSessionShouldStart(_ challenge: ZenloopChallenge, apps: FamilyActivitySelection)
    func scheduledSessionCreated(sessionId: String, title: String)
    func scheduledSessionCancelled(sessionId: String)
    func generateAppNames(from selection: FamilyActivitySelection) -> [String]
    func recordActivity(type: ActivityRecord.ActivityType, title: String)
}

@MainActor
final class ScheduledSessionsCoordinator: ObservableObject {
    
    // MARK: - Private Properties
    private var scheduledTimers: [String: DispatchWorkItem] = [:]
    
    weak var delegate: ScheduledSessionsCoordinatorDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "ScheduledSessions")
    #endif
    
    // MARK: - Constants
    private struct Keys {
        static let scheduledChallenges = "scheduled_challenges"
    }
    
    // MARK: - Public Interface
    
    func scheduleCustomChallenge(
        title: String,
        duration: TimeInterval,
        difficulty: DifficultyLevel,
        apps: FamilyActivitySelection,
        startTime: Date,
        notificationManager: SessionNotificationManager
    ) {
        let sessionId = "scheduled-\(UUID().uuidString)"
        
        // Créer la session programmée
        let appNames = delegate?.generateAppNames(from: apps) ?? []
        
        // CORRECTION: Utiliser le même timing arrondi pour les notifications
        let calendar = Calendar.current
        let roundedStartTime = calendar.dateInterval(of: .minute, for: startTime)?.start ?? startTime
        
        // Programmer les notifications avec le timing exact
        notificationManager.scheduleSessionReminder(
            sessionId: sessionId,
            title: title,
            startTime: roundedStartTime,
            duration: duration,
            apps: appNames
        )
        
        // Enregistrer la session programmée pour démarrage automatique
        let scheduledChallenge = ZenloopChallenge(
            id: sessionId,
            title: title,
            description: "Session programmée",
            duration: duration,
            difficulty: difficulty,
            startTime: roundedStartTime, // Utiliser le timing exact
            isActive: false
        )
        
        // Sauvegarder dans UserDefaults pour persistance
        saveScheduledChallenge(scheduledChallenge, apps: apps)
        
        // Programmer le démarrage automatique (timer pour app ouverte)
        scheduleAutoStart(challenge: scheduledChallenge, apps: apps)
        
        // CRUCIAL: Programmer AUSSI avec DeviceActivitySchedule pour arrière-plan
        do {
            try BlockScheduler.shared.scheduleSession(
                title: title,
                duration: duration,
                startTime: roundedStartTime, // Réutiliser la même variable
                selection: apps
            )
            #if DEBUG
            self.logger.debug("🛡️ [ScheduledSessions] DeviceActivity scheduled pour arrière-plan")
            #endif
        } catch {
            #if DEBUG
            self.logger.debug("❌ [ScheduledSessions] Erreur DeviceActivity: \(error)")
            #endif
        }
        
        #if DEBUG
        self.logger.debug("📅 [ScheduledSessions] Session programmée: \(title) pour \(startTime)")
        #endif
        
        delegate?.recordActivity(type: .challengeScheduled, title: "Session programmée: \(title)")
        delegate?.scheduledSessionCreated(sessionId: sessionId, title: title)
    }
    
    func cancelScheduledChallenge(_ challengeId: String, notificationManager: SessionNotificationManager) {
        // Annuler les notifications
        notificationManager.cancelSessionNotifications(sessionId: challengeId)
        
        // Annuler le timer si il existe
        scheduledTimers[challengeId]?.cancel()
        scheduledTimers.removeValue(forKey: challengeId)
        
        // CRUCIAL: Annuler AUSSI le DeviceActivitySchedule
        BlockScheduler.shared.cancelScheduledSession(challengeId)
        
        // Supprimer de la persistance
        removeScheduledChallenge(challengeId)
        
        #if DEBUG
        self.logger.debug("🗑️ [ScheduledSessions] Session programmée annulée: \(challengeId)")
        #endif
        
        delegate?.scheduledSessionCancelled(sessionId: challengeId)
        delegate?.recordActivity(type: .challengeStopped, title: "Session programmée annulée")
    }
    
    // MARK: - Persistence
    
    private func saveScheduledChallenge(_ challenge: ZenloopChallenge, apps: FamilyActivitySelection) {
        var scheduledChallenges = getScheduledChallenges()
        scheduledChallenges[challenge.id] = challenge
        
        if let encoded = try? JSONEncoder().encode(scheduledChallenges) {
            UserDefaults.standard.set(encoded, forKey: Keys.scheduledChallenges)
            #if DEBUG
            self.logger.debug("💾 [ScheduledSessions] Challenge saved: \(challenge.id)")
            #endif
        } else {
            #if DEBUG
            self.logger.error("❌ [ScheduledSessions] Failed to encode scheduled challenge")
            #endif
        }
    }
    
    func getScheduledChallenges() -> [String: ZenloopChallenge] {
        guard let data = UserDefaults.standard.data(forKey: Keys.scheduledChallenges),
              let challenges = try? JSONDecoder().decode([String: ZenloopChallenge].self, from: data) else {
            return [:]
        }
        
        #if DEBUG
        self.logger.debug("📥 [ScheduledSessions] Loaded \(challenges.count) scheduled challenges")
        #endif
        return challenges
    }
    
    private func removeScheduledChallenge(_ challengeId: String) {
        var scheduledChallenges = getScheduledChallenges()
        scheduledChallenges.removeValue(forKey: challengeId)
        
        if let encoded = try? JSONEncoder().encode(scheduledChallenges) {
            UserDefaults.standard.set(encoded, forKey: Keys.scheduledChallenges)
            #if DEBUG
            self.logger.debug("🗑️ [ScheduledSessions] Challenge removed from persistence: \(challengeId)")
            #endif
        }
    }
    
    // MARK: - Auto-start Scheduling
    
    private func scheduleAutoStart(challenge: ZenloopChallenge, apps: FamilyActivitySelection) {
        guard let startTime = challenge.startTime else { return }
        let timeInterval = startTime.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        
        // Créer un DispatchWorkItem pour pouvoir l'annuler si nécessaire
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Vérifier que la session n'a pas été annulée
            let scheduledChallenges = self.getScheduledChallenges()
            guard scheduledChallenges[challenge.id] != nil else { return }
            
            // Préparer le challenge pour démarrage
            var startingChallenge = challenge
            startingChallenge.startTime = Date()
            startingChallenge.isActive = true
            
            // Déléguer le démarrage au manager principal
            self.delegate?.scheduledSessionShouldStart(startingChallenge, apps: apps)
            
            // Nettoyer les données de programmation
            self.removeScheduledChallenge(challenge.id)
            self.scheduledTimers.removeValue(forKey: challenge.id)
            
            #if DEBUG
            self.logger.debug("🚀 [ScheduledSessions] Auto-started: \(challenge.title)")
            #endif
        }
        
        // Programmer l'exécution et stocker le work item pour annulation possible
        scheduledTimers[challenge.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval, execute: workItem)
        
        #if DEBUG
        self.logger.debug("⏰ [ScheduledSessions] Auto-start scheduled in \(Int(timeInterval))s for: \(challenge.title)")
        #endif
    }
    
    // MARK: - Session Management
    
    func getAllScheduledSessions() -> [ZenloopChallenge] {
        return Array(getScheduledChallenges().values)
    }
    
    func getScheduledSession(id: String) -> ZenloopChallenge? {
        return getScheduledChallenges()[id]
    }
    
    func hasScheduledSessions() -> Bool {
        return !getScheduledChallenges().isEmpty
    }
    
    func getUpcomingSessions(limit: Int = 5) -> [ZenloopChallenge] {
        let now = Date()
        return getScheduledChallenges().values
            .compactMap { challenge in
                guard let startTime = challenge.startTime, startTime > now else { return nil }
                return challenge
            }
            .sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Cleanup
    
    func cleanupExpiredSessions() {
        let now = Date()
        let scheduledChallenges = getScheduledChallenges()
        var hasChanges = false
        
        for (id, challenge) in scheduledChallenges {
            if let startTime = challenge.startTime, startTime < now.addingTimeInterval(-3600) { // 1h grace period
                removeScheduledChallenge(id)
                scheduledTimers[id]?.cancel()
                scheduledTimers.removeValue(forKey: id)
                hasChanges = true
                
                #if DEBUG
                self.logger.debug("🧹 [ScheduledSessions] Cleaned expired session: \(id)")
                #endif
            }
        }
        
        if hasChanges {
            #if DEBUG
            self.logger.debug("🧹 [ScheduledSessions] Cleanup completed")
            #endif
        }
    }
    
    // MARK: - Diagnostics
    
    func getDiagnosticsInfo() -> [String: Any] {
        let scheduledChallenges = getScheduledChallenges()
        let activeChallenges = scheduledChallenges.filter { $0.value.startTime ?? Date.distantPast > Date() }
        
        return [
            "totalScheduledSessions": scheduledChallenges.count,
            "upcomingSessions": activeChallenges.count,
            "activeTimers": scheduledTimers.count,
            "nextSessionTime": activeChallenges.values.compactMap(\.startTime).min()?.timeIntervalSince1970 ?? 0
        ]
    }
    
    deinit {
        // Annuler tous les timers en cours
        for (_, workItem) in scheduledTimers {
            workItem.cancel()
        }
        scheduledTimers.removeAll()
    }
}