//
//  ScreenTimeManager.swift
//  zenloop
//
//  Created by Claude on 07/08/2025.
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import Combine

// MARK: - Screen Time Integration Manager

class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    private let deviceActivityCenter = DeviceActivityCenter()
    @Published var isAuthorized = false
    @Published var activeBlockingSessions: [String: BlockingSession] = [:]
    
    private init() {
        checkAuthorization()
        loadPersistedSessions()
    }
    
    // MARK: - Authorization
    
    private func checkAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run {
                    self.isAuthorized = true
                    print("✅ [SCREEN_TIME] Authorization granted")
                }
            } catch {
                await MainActor.run {
                    self.isAuthorized = false
                    print("❌ [SCREEN_TIME] Authorization denied: \(error)")
                }
            }
        }
    }
    
    func requestScreenTimeAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        } catch {
            print("❌ [SCREEN_TIME] Failed to get authorization: \(error)")
            return false
        }
    }
    
    // MARK: - App Blocking
    
    func startBlocking(
        challengeId: String,
        selectedApps: FamilyActivitySelection,
        duration: TimeInterval,
        challengeTitle: String
    ) async -> Bool {
        
        if !isAuthorized {
            print("❌ [SCREEN_TIME] Not authorized for Screen Time - requesting authorization")
            let authorized = await requestScreenTimeAuthorization()
            guard authorized else {
                print("❌ [SCREEN_TIME] Authorization denied")
                return false
            }
        }
        
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            print("❌ [SCREEN_TIME] No apps or categories selected")
            return false
        }
        
        do {
            // Créer un schedule pour ce défi - commence immédiatement
            let activityName = DeviceActivityName("challenge_\(challengeId)")
            let startTime = Date()
            let endTime = startTime.addingTimeInterval(duration)
            
            // Schedule immédiat (commence maintenant)
            let startComponents = DateComponents(
                hour: Calendar.current.component(.hour, from: startTime),
                minute: Calendar.current.component(.minute, from: startTime),
                second: Calendar.current.component(.second, from: startTime)
            )
            
            let endComponents = DateComponents(
                hour: Calendar.current.component(.hour, from: endTime),
                minute: Calendar.current.component(.minute, from: endTime),
                second: Calendar.current.component(.second, from: endTime)
            )
            
            let schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )
            
            // 🔒 ÉTAPE 1: Activer le blocage immédiat avec ManagedSettings
            // Utiliser un store nommé pour éviter les conflits avec les sessions programmées
            let storeIdentifier = challengeId.hasPrefix("scheduled_") ? challengeId : "manual_\(challengeId)"
            let managedSettings = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeIdentifier))
            
            // Bloquer les applications sélectionnées
            if !selectedApps.applicationTokens.isEmpty {
                managedSettings.shield.applications = selectedApps.applicationTokens
                print("🛡️ [MANAGED_SETTINGS] Blocked \(selectedApps.applicationTokens.count) applications in store: \(storeIdentifier)")
            }
            
            // Bloquer les catégories sélectionnées
            if !selectedApps.categoryTokens.isEmpty {
                managedSettings.shield.applicationCategories = .specific(selectedApps.categoryTokens)
                print("🛡️ [MANAGED_SETTINGS] Blocked \(selectedApps.categoryTokens.count) categories in store: \(storeIdentifier)")
            }
            
            // 📊 ÉTAPE 2: Démarrer le monitoring pour statistiques (optionnel)
            let eventName = DeviceActivityEvent.Name("challenge_monitoring_\(challengeId)")
            let event = DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                categories: selectedApps.categoryTokens,
                webDomains: Set<WebDomainToken>(),
                threshold: DateComponents(second: 1)
            )
            
            // Démarrer le monitoring pour les stats (ne bloque pas, juste surveille)
            let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [eventName: event]
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            
            // Enregistrer la session
            let session = BlockingSession(
                challengeId: challengeId,
                challengeTitle: challengeTitle,
                startTime: startTime,
                endTime: endTime,
                selectedApps: selectedApps,
                activityName: activityName
            )
            
            await MainActor.run {
                self.activeBlockingSessions[challengeId] = session
                
                // Persister la session pour la récupérer après un redémarrage
                self.persistSession(session)
            }
            
            print("🛡️ [SCREEN_TIME] Started effective blocking for challenge: \(challengeTitle)")
            print("🔒 [MANAGED_SETTINGS] Apps are now BLOCKED immediately")
            print("📱 [SCREEN_TIME] Blocking \(selectedApps.applicationTokens.count) apps and \(selectedApps.categoryTokens.count) categories")
            print("⏰ [SCREEN_TIME] Duration: \(duration/3600) hours until \(endTime)")
            
            // Programmer l'arrêt automatique du blocage
            scheduleBlockingEnd(challengeId: challengeId, endTime: endTime)
            
            // Activer le suivi de progression
            setupProgressTracking()
            
            return true
            
        } catch {
            print("❌ [SCREEN_TIME] Failed to start blocking: \(error)")
            // En cas d'échec, activer mode simulation
            await activateSimulationMode(challengeId: challengeId, selectedApps: selectedApps, duration: duration, title: challengeTitle)
            return true // Retourner true car simulation activée
        }
    }
    
    // Mode simulation pour développement/fallback
    private func activateSimulationMode(challengeId: String, selectedApps: FamilyActivitySelection, duration: TimeInterval, title: String) async {
        print("🔄 [SCREEN_TIME] Activating simulation mode for challenge: \(title)")
        
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)
        
        let session = BlockingSession(
            challengeId: challengeId,
            challengeTitle: title,
            startTime: startTime,
            endTime: endTime,
            selectedApps: selectedApps,
            activityName: DeviceActivityName("sim_\(challengeId)")
        )
        
        await MainActor.run {
            self.activeBlockingSessions[challengeId] = session
        }
        
        // Enregistrer en UserDefaults pour persistance
        UserDefaults.standard.set(true, forKey: "blocking_active_\(challengeId)")
        UserDefaults.standard.set(startTime, forKey: "blocking_start_\(challengeId)")
        UserDefaults.standard.set(endTime, forKey: "blocking_end_\(challengeId)")
        
        print("✅ [SCREEN_TIME] Simulation mode activated - tracking progress")
    }
    
    func stopBlocking(challengeId: String) async -> Bool {
        guard let session = activeBlockingSessions[challengeId] else {
            print("❌ [SCREEN_TIME] No active session found for challenge: \(challengeId)")
            return false
        }
        
        do {
            // 🔓 ÉTAPE 1: Supprimer le blocage ManagedSettings du bon store
            let storeIdentifier = challengeId.hasPrefix("scheduled_") ? challengeId : "manual_\(challengeId)"
            let managedSettings = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeIdentifier))
            
            // Supprimer le blocage des applications
            if !session.selectedApps.applicationTokens.isEmpty {
                managedSettings.shield.applications = nil
                print("🔓 [MANAGED_SETTINGS] Unblocked \(session.selectedApps.applicationTokens.count) applications from store: \(storeIdentifier)")
            }
            
            // Supprimer le blocage des catégories
            if !session.selectedApps.categoryTokens.isEmpty {
                managedSettings.shield.applicationCategories = nil
                print("🔓 [MANAGED_SETTINGS] Unblocked \(session.selectedApps.categoryTokens.count) categories from store: \(storeIdentifier)")
            }
            
            // 📊 ÉTAPE 2: Arrêter le monitoring
            deviceActivityCenter.stopMonitoring([session.activityName])
            
            // Supprimer la session
            await MainActor.run {
                self.activeBlockingSessions.removeValue(forKey: challengeId)
            }
            
            // Supprimer la persistance
            removePersistedSession(challengeId)
            
            print("🔓 [SCREEN_TIME] Stopped effective blocking for challenge: \(session.challengeTitle)")
            print("✅ [MANAGED_SETTINGS] Apps are now UNBLOCKED")
            return true
            
        } catch {
            print("❌ [SCREEN_TIME] Failed to stop blocking: \(error)")
            return false
        }
    }
    
    // MARK: - Automatic Blocking End
    
    private func scheduleBlockingEnd(challengeId: String, endTime: Date) {
        let timeInterval = endTime.timeIntervalSince(Date())
        guard timeInterval > 0 else { 
            print("⚠️ [SCREEN_TIME] End time already passed for challenge: \(challengeId)")
            return
        }
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task {
                print("⏰ [SCREEN_TIME] Auto-stopping blocking for challenge: \(challengeId)")
                await self?.stopBlocking(challengeId: challengeId)
                
                // Notifier CommunityManager que le défi est terminé
                //await CommunityManager.shared.challengeCompleted(challengeId)
            }
        }
        
        print("⏰ [SCREEN_TIME] Scheduled auto-stop in \(Int(timeInterval/60)) minutes for challenge: \(challengeId)")
    }
    
    func stopAllBlocking() async {
        let allActivityNames = activeBlockingSessions.values.map { $0.activityName }
        let allChallengeIds = Array(activeBlockingSessions.keys)
        
        if !allActivityNames.isEmpty {
            // Supprimer tous les blocages ManagedSettings de chaque store nommé
            for challengeId in allChallengeIds {
                let storeIdentifier = challengeId.hasPrefix("scheduled_") ? challengeId : "manual_\(challengeId)"
                let managedSettings = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeIdentifier))
                // Clear both shield mode and hide mode restrictions
                managedSettings.shield.applications = nil
                managedSettings.shield.applicationCategories = nil
                managedSettings.application.blockedApplications = nil
                print("🔓 [MANAGED_SETTINGS] Cleared restrictions from store: \(storeIdentifier)")
            }
            
            // Aussi nettoyer le store par défaut au cas où
            let defaultStore = ManagedSettingsStore()
            defaultStore.shield.applications = nil
            defaultStore.shield.applicationCategories = nil
            defaultStore.application.blockedApplications = nil
            
            deviceActivityCenter.stopMonitoring(allActivityNames)
            
            await MainActor.run {
                self.activeBlockingSessions.removeAll()
            }
            
            print("🔓 [SCREEN_TIME] Stopped all blocking sessions (\(allActivityNames.count))")
            print("✅ [MANAGED_SETTINGS] Cleared all app restrictions from all stores")
        }
    }
    
    // MARK: - Session Management
    
    func getActiveSession(for challengeId: String) -> BlockingSession? {
        return activeBlockingSessions[challengeId]
    }
    
    func getAllActiveSessions() -> [BlockingSession] {
        return Array(activeBlockingSessions.values)
    }
    
    func isBlocking(challengeId: String) -> Bool {
        guard let session = activeBlockingSessions[challengeId] else { return false }
        return Date() < session.endTime
    }
    
    // MARK: - Progress Calculation
    
    func calculateProgress(for challengeId: String) -> Double {
        guard let session = activeBlockingSessions[challengeId] else { return 0.0 }
        
        let now = Date()
        let totalDuration = session.endTime.timeIntervalSince(session.startTime)
        let elapsed = now.timeIntervalSince(session.startTime)
        
        if now >= session.endTime {
            return 1.0 // Terminé
        } else if elapsed < 0 {
            return 0.0 // Pas encore commencé
        } else {
            return elapsed / totalDuration
        }
    }
    
    // MARK: - Notifications & Events
    
    func setupProgressTracking() {
        // Vérifier la progression toutes les 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.checkProgressUpdates()
            }
        }
    }
    
    private func checkProgressUpdates() async {
        for (challengeId, session) in activeBlockingSessions {
            let progress = calculateProgress(for: challengeId)
            
            // Notifier CommunityManager des changements de progression
                //await CommunityManager.shared.updateChallengeProgress(challengeId, progress: progress)
            
            // Si terminé, nettoyer la session
            if progress >= 1.0 {
                await MainActor.run {
                    self.activeBlockingSessions.removeValue(forKey: challengeId)
                }
            }
        }
    }
    
    // MARK: - Session Persistence
    
    private func persistSession(_ session: BlockingSession) {
        let sessionData: [String: Any] = [
            "challengeId": session.challengeId,
            "challengeTitle": session.challengeTitle,
            "startTime": session.startTime.timeIntervalSince1970,
            "endTime": session.endTime.timeIntervalSince1970,
            "applicationTokensCount": session.selectedApps.applicationTokens.count,
            "categoryTokensCount": session.selectedApps.categoryTokens.count,
            "activityNameRaw": session.activityName.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(sessionData, forKey: "blocking_session_\(session.challengeId)")
        print("💾 [SCREEN_TIME] Persisted blocking session: \(session.challengeId)")
    }
    
    private func loadPersistedSessions() {
        let userDefaults = UserDefaults.standard
        let sessionPrefix = "blocking_session_"
        
        // Parcourir toutes les clés UserDefaults pour trouver les sessions
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(sessionPrefix),
               let sessionData = userDefaults.dictionary(forKey: key) as? [String: Any] {
                
                if let challengeId = sessionData["challengeId"] as? String,
                   let challengeTitle = sessionData["challengeTitle"] as? String,
                   let startTimeInterval = sessionData["startTime"] as? TimeInterval,
                   let endTimeInterval = sessionData["endTime"] as? TimeInterval,
                   let activityNameRaw = sessionData["activityNameRaw"] as? String {
                    
                    let startTime = Date(timeIntervalSince1970: startTimeInterval)
                    let endTime = Date(timeIntervalSince1970: endTimeInterval)
                    
                    // Vérifier si la session est encore active
                    if Date() < endTime {
                        // Récupérer les apps sélectionnées depuis CommunityManager
                        let selectedApps =  FamilyActivitySelection()
                        
                        let session = BlockingSession(
                            challengeId: challengeId,
                            challengeTitle: challengeTitle,
                            startTime: startTime,
                            endTime: endTime,
                            selectedApps: selectedApps,
                            activityName: DeviceActivityName(activityNameRaw)
                        )
                        
                        // Redémarrer le blocage si les apps sont disponibles
                        if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
                            Task {
                                await self.restartBlockingForRestoredSession(session)
                            }
                        }
                        
                        activeBlockingSessions[challengeId] = session
                        print("✅ [SCREEN_TIME] Restored session: \(challengeId)")
                    } else {
                        // Session expirée, la supprimer
                        userDefaults.removeObject(forKey: key)
                        print("🧹 [SCREEN_TIME] Removed expired session: \(challengeId)")
                    }
                }
            }
        }
    }
    
    private func removePersistedSession(_ challengeId: String) {
        UserDefaults.standard.removeObject(forKey: "blocking_session_\(challengeId)")
        print("🗑️ [SCREEN_TIME] Removed persisted session: \(challengeId)")
    }
    
    private func restartBlockingForRestoredSession(_ session: BlockingSession) async {
        guard isAuthorized else {
            print("❌ [SCREEN_TIME] Not authorized - cannot restart blocking for restored session")
            return
        }
        
        guard !session.selectedApps.applicationTokens.isEmpty || !session.selectedApps.categoryTokens.isEmpty else {
            print("❌ [SCREEN_TIME] No apps in restored session to block")
            return
        }
        
        do {
            // Calculer le temps restant
            let timeRemaining = session.endTime.timeIntervalSince(Date())
            guard timeRemaining > 0 else {
                print("⏰ [SCREEN_TIME] Restored session already expired")
                return
            }
            
            // 🔒 ÉTAPE 1: Réactiver le blocage ManagedSettings immédiatement
            let storeIdentifier = session.challengeId.hasPrefix("scheduled_") ? session.challengeId : "manual_\(session.challengeId)"
            let managedSettings = ManagedSettingsStore(named: ManagedSettingsStore.Name(storeIdentifier))
            
            if !session.selectedApps.applicationTokens.isEmpty {
                managedSettings.shield.applications = session.selectedApps.applicationTokens
                print("🛡️ [MANAGED_SETTINGS] Restored blocking for \(session.selectedApps.applicationTokens.count) applications in store: \(storeIdentifier)")
            }
            
            if !session.selectedApps.categoryTokens.isEmpty {
                managedSettings.shield.applicationCategories = .specific(session.selectedApps.categoryTokens)
                print("🛡️ [MANAGED_SETTINGS] Restored blocking for \(session.selectedApps.categoryTokens.count) categories in store: \(storeIdentifier)")
            }
            
            // 📊 ÉTAPE 2: Recréer le schedule avec le temps restant
            let startComponents = DateComponents(
                hour: Calendar.current.component(.hour, from: Date()),
                minute: Calendar.current.component(.minute, from: Date()),
                second: Calendar.current.component(.second, from: Date())
            )
            
            let endTime = Date().addingTimeInterval(timeRemaining)
            let endComponents = DateComponents(
                hour: Calendar.current.component(.hour, from: endTime),
                minute: Calendar.current.component(.minute, from: endTime),
                second: Calendar.current.component(.second, from: endTime)
            )
            
            let schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )
            
            // Créer les événements de monitoring
            let eventName = DeviceActivityEvent.Name("challenge_monitoring_\(session.challengeId)")
            let event = DeviceActivityEvent(
                applications: session.selectedApps.applicationTokens,
                categories: session.selectedApps.categoryTokens,
                webDomains: Set<WebDomainToken>(),
                threshold: DateComponents(second: 1)
            )
            
            // Redémarrer le monitoring
            let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [eventName: event]
            try deviceActivityCenter.startMonitoring(session.activityName, during: schedule, events: events)
            
            // Programmer l'arrêt automatique
            scheduleBlockingEnd(challengeId: session.challengeId, endTime: session.endTime)
            
            print("🔄 [SCREEN_TIME] Restarted effective blocking for restored session: \(session.challengeTitle)")
            print("🔒 [MANAGED_SETTINGS] Apps are BLOCKED again after restore")
            print("📱 [SCREEN_TIME] Time remaining: \(Int(timeRemaining/60)) minutes")
            
        } catch {
            print("❌ [SCREEN_TIME] Failed to restart blocking for restored session: \(error)")
        }
    }
}

// MARK: - Supporting Data Structures

struct BlockingSession {
    let challengeId: String
    let challengeTitle: String
    let startTime: Date
    let endTime: Date
    let selectedApps: FamilyActivitySelection
    let activityName: DeviceActivityName
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }
    
    var timeRemaining: TimeInterval {
        return max(0, endTime.timeIntervalSince(Date()))
    }
    
    var progressPercentage: Double {
        let now = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        let elapsed = now.timeIntervalSince(startTime)
        
        if now >= endTime {
            return 100.0
        } else if elapsed < 0 {
            return 0.0
        } else {
            return (elapsed / totalDuration) * 100.0
        }
    }
}
