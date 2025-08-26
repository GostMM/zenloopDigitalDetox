//
//  SessionCoordinator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 24/08/2025.
//  Système centralisé de synchronisation app-extension
//

import Foundation
import SwiftUI
import FamilyControls

// MARK: - Session State Models

enum SessionSource {
    case userInitiated    // Session démarrée par l'utilisateur
    case extensionTriggered // Session déclenchée par l'extension (schedulée)
    case restored         // Session restaurée au démarrage de l'app
}

struct SessionState {
    let id: String
    let title: String
    let duration: TimeInterval
    let startTime: Date
    let source: SessionSource
    let isActive: Bool
    let isScheduled: Bool
    
    var endTime: Date {
        return startTime.addingTimeInterval(duration)
    }
    
    var timeRemaining: TimeInterval {
        return max(0, endTime.timeIntervalSinceNow)
    }
    
    var isExpired: Bool {
        return timeRemaining <= 0
    }
}

struct ScheduledSession: Codable, Identifiable {
    let id: String
    let title: String
    let duration: TimeInterval
    let scheduledFor: Date
    let createdAt: Date
    let isActive: Bool
    
    var isUpcoming: Bool {
        return scheduledFor > Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledFor)
    }
}

// MARK: - Session Coordinator

@MainActor
class SessionCoordinator: ObservableObject {
    static let shared = SessionCoordinator()
    
    // MARK: - Published State (Single Source of Truth)
    
    @Published var currentSession: SessionState?
    @Published var scheduledSessions: [ScheduledSession] = []
    @Published var isMonitoringExtension = false
    
    // MARK: - Private Properties
    
    private let appGroup = UserDefaults(suiteName: "group.com.app.zenloop")!
    private var extensionMonitorTimer: Timer?
    private var sessionSyncTimer: Timer?
    private let logger = Logger(subsystem: "com.app.zenloop", category: "SessionCoordinator")
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedScheduledSessions()
        startContinuousSync()
        
        logger.debug("🎛️ [SESSION_COORDINATOR] Initialized with centralized synchronization")
    }
    
    deinit {
        Task { @MainActor in
            stopAllTimers()
        }
    }
    
    // MARK: - Public Interface
    
    func startSession(
        title: String,
        duration: TimeInterval,
        selection: FamilyActivitySelection,
        source: SessionSource = .userInitiated
    ) {
        // Vérifier les conflits
        if let existing = currentSession {
            logger.debug("⚠️ [SESSION_COORDINATOR] Conflict detected: \(existing.title) vs \(title)")
            handleSessionConflict(existing: existing, newTitle: title, newDuration: duration)
            return
        }
        
        // Créer la nouvelle session
        let sessionId = "session_\(UUID().uuidString)"
        let session = SessionState(
            id: sessionId,
            title: title,
            duration: duration,
            startTime: Date(),
            source: source,
            isActive: true,
            isScheduled: false
        )
        
        // Mettre à jour l'état
        currentSession = session
        
        // Synchronisation immédiate avec l'app et l'extension
        syncSessionToSystem(session: session, selection: selection)
        syncCurrentSessionState() // Sync immédiat vers App Group
        checkExtensionTriggeredSessions() // Vérification immédiate des conflits
        
        logger.debug("✅ [SESSION_COORDINATOR] Session started with immediate sync: \(title)")
    }
    
    func scheduleSession(
        title: String,
        duration: TimeInterval,
        scheduledFor: Date,
        selection: FamilyActivitySelection
    ) {
        let scheduledSession = ScheduledSession(
            id: "scheduled_\(UUID().uuidString)",
            title: title,
            duration: duration,
            scheduledFor: scheduledFor,
            createdAt: Date(),
            isActive: false
        )
        
        // Ajouter à la liste
        scheduledSessions.append(scheduledSession)
        
        // Persister
        persistScheduledSessions()
        
        // Programmer via BlockScheduler
        do {
            try BlockScheduler.shared.scheduleSession(
                title: title,
                duration: duration,
                startTime: scheduledFor,
                selection: selection
            )
            
            logger.debug("📅 [SESSION_COORDINATOR] Session scheduled: \(title) at \(scheduledFor)")
        } catch {
            logger.debug("❌ [SESSION_COORDINATOR] Failed to schedule: \(error)")
        }
    }
    
    func stopCurrentSession() {
        guard let session = currentSession else { return }
        
        // Mettre à jour l'état local
        currentSession = nil
        
        // Synchronisation immédiate de l'arrêt
        syncSessionStopToSystem(sessionId: session.id)
        syncCurrentSessionState() // Nettoyage immédiat de l'App Group
        
        logger.debug("🛑 [SESSION_COORDINATOR] Session stopped with immediate sync: \(session.title)")
    }
    
    func cancelScheduledSession(_ sessionId: String) {
        // Retirer de la liste
        scheduledSessions.removeAll { $0.id == sessionId }
        
        // Persister
        persistScheduledSessions()
        
        // Annuler dans BlockScheduler
        BlockScheduler.shared.cancelScheduledSession(sessionId)
        
        logger.debug("🗑️ [SESSION_COORDINATOR] Scheduled session cancelled: \(sessionId)")
    }
    
    // MARK: - Extension Synchronization
    
    private func startContinuousSync() {
        // Surveillance haute fréquence des sessions d'extension (0.25s pour réactivité maximale)
        extensionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkExtensionTriggeredSessions()
        }
        
        // Synchronisation fréquente de l'état (0.5s pour temps réel)
        sessionSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.syncCurrentSessionState()
        }
        
        isMonitoringExtension = true
        logger.debug("🔄 [SESSION_COORDINATOR] High-frequency sync started (250ms/500ms)")
    }
    
    private func stopAllTimers() {
        extensionMonitorTimer?.invalidate()
        sessionSyncTimer?.invalidate()
        extensionMonitorTimer = nil
        sessionSyncTimer = nil
        isMonitoringExtension = false
    }
    
    private func checkExtensionTriggeredSessions() {
        // Traiter la queue d'activations de l'extension (traitement batch pour performance)
        guard let activationQueue = appGroup.array(forKey: "extension_activation_queue") as? [[String: Any]],
              !activationQueue.isEmpty else {
            return
        }
        
        let processedIds = appGroup.array(forKey: "coordinator_processed_activations") as? [String] ?? []
        var newProcessedIds = processedIds
        
        // Traiter tous les éléments de la queue en une seule fois
        for sessionData in activationQueue {
            guard let sessionId = sessionData["id"] as? String,
                  let title = sessionData["title"] as? String,
                  let duration = sessionData["duration"] as? TimeInterval,
                  let activationId = sessionData["activationId"] as? String else {
                continue
            }
            
            // Éviter les doublons avec batch processing
            if processedIds.contains(activationId) {
                continue
            }
            
            // Créer la session depuis l'extension
            let session = SessionState(
                id: sessionId,
                title: title,
                duration: duration,
                startTime: Date(),
                source: .extensionTriggered,
                isActive: true,
                isScheduled: true
            )
            
            // Activer avec gestion de conflit intégrée
            if currentSession != nil {
                handleSessionConflict(existing: currentSession!, newTitle: title, newDuration: duration)
            } else {
                currentSession = session
                
                // Synchronisation immédiate pour les sessions d'extension
                if let selectionData = sessionData["apps"] as? Data,
                   let selection = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(selectionData) as? FamilyActivitySelection {
                    syncSessionToSystem(session: session, selection: selection)
                } else {
                    // Fallback sans sélection d'apps
                    syncSessionToSystem(session: session, selection: FamilyActivitySelection())
                }
                syncCurrentSessionState()
                
                logger.debug("🔥 [SESSION_COORDINATOR] Extension session activated with immediate sync: \(title)")
            }
            
            // Marquer comme traité dans le batch
            newProcessedIds.append(activationId)
        }
        
        // Sauvegarder tous les changements en une fois (optimisation performances)
        appGroup.set(newProcessedIds, forKey: "coordinator_processed_activations")
        appGroup.removeObject(forKey: "extension_activation_queue")
        appGroup.synchronize()
    }
    
    private func syncCurrentSessionState() {
        guard let session = currentSession else {
            // Nettoyer l'état dans l'App Group si pas de session active
            appGroup.removeObject(forKey: "coordinator_current_session")
            appGroup.synchronize()
            return
        }
        
        // Vérifier si la session a expiré
        if session.isExpired {
            logger.debug("⏰ [SESSION_COORDINATOR] Session expired, stopping: \(session.title)")
            stopCurrentSession()
            return
        }
        
        // Synchroniser l'état actuel vers l'App Group
        let sessionData: [String: Any] = [
            "id": session.id,
            "title": session.title,
            "duration": session.duration,
            "startTime": session.startTime.timeIntervalSince1970,
            "timeRemaining": session.timeRemaining,
            "isActive": session.isActive,
            "source": session.source.rawValue,
            "syncedAt": Date().timeIntervalSince1970
        ]
        
        appGroup.set(sessionData, forKey: "coordinator_current_session")
        appGroup.synchronize()
    }
    
    // MARK: - Conflict Resolution
    
    private func handleSessionConflict(existing: SessionState, newTitle: String, newDuration: TimeInterval) {
        let timeRemaining = existing.timeRemaining
        
        if timeRemaining < 60 {
            // Session existante finit bientôt, la remplacer immédiatement
            stopCurrentSession()
            
            // Transition instantanée (délai minimal pour éviter les conflits système)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.startSession(
                    title: newTitle,
                    duration: newDuration,
                    selection: FamilyActivitySelection(), // TODO: Récupérer vraie sélection
                    source: .extensionTriggered
                )
            }
        } else {
            // Reporter la nouvelle session
            let postponedTime = existing.endTime.addingTimeInterval(120) // +2min buffer
            scheduleSession(
                title: "\(newTitle) (reporté)",
                duration: newDuration,
                scheduledFor: postponedTime,
                selection: FamilyActivitySelection() // TODO: Récupérer vraie sélection
            )
        }
    }
    
    // MARK: - System Integration
    
    private func syncSessionToSystem(session: SessionState, selection: FamilyActivitySelection) {
        // Intégration avec ZenloopManager
        let zenloopManager = ZenloopManager.shared
        
        // Extraire la difficulté depuis le titre si possible
        let difficulty: DifficultyLevel
        if session.title.contains("Profond") {
            difficulty = .hard
        } else if session.title.contains("Léger") {
            difficulty = .easy
        } else {
            difficulty = .medium
        }
        
        // Démarrer le challenge dans ZenloopManager
        zenloopManager.startCustomChallenge(
            title: session.title,
            duration: session.duration,
            difficulty: difficulty,
            apps: selection
        )
        
        logger.debug("🔗 [SESSION_COORDINATOR] Session synced to ZenloopManager: \(session.title)")
    }
    
    private func syncSessionStopToSystem(sessionId: String) {
        // Intégration avec ZenloopManager
        let zenloopManager = ZenloopManager.shared
        
        // Arrêter le challenge actuel
        if zenloopManager.currentState != .idle {
            zenloopManager.stopCurrentChallenge()
        }
        
        logger.debug("🔗 [SESSION_COORDINATOR] Session stop synced to ZenloopManager: \(sessionId)")
    }
    
    // MARK: - Persistence
    
    private func persistScheduledSessions() {
        if let data = try? JSONEncoder().encode(scheduledSessions) {
            appGroup.set(data, forKey: "coordinator_scheduled_sessions")
            appGroup.synchronize()
        }
    }
    
    private func loadPersistedScheduledSessions() {
        guard let data = appGroup.data(forKey: "coordinator_scheduled_sessions"),
              let sessions = try? JSONDecoder().decode([ScheduledSession].self, from: data) else {
            return
        }
        
        // Filtrer les sessions expirées
        scheduledSessions = sessions.filter { $0.isUpcoming }
        
        logger.debug("📥 [SESSION_COORDINATOR] Loaded \(scheduledSessions.count) scheduled sessions")
    }
}

// MARK: - SessionSource Extension

extension SessionSource {
    var rawValue: String {
        switch self {
        case .userInitiated: return "user"
        case .extensionTriggered: return "extension"
        case .restored: return "restored"
        }
    }
}

// MARK: - Logger Extension

import os

private extension Logger {
    func debug(_ message: String) {
        print(message) // Fallback pour debug
    }
}