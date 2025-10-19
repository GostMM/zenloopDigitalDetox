//
//  zenloopmonitor.swift
//  zenloopmonitor
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import DeviceActivity
import Foundation
import UserNotifications
import ManagedSettings
import FamilyControls

// MARK: - Shared Models

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

class ZenloopDeviceActivityMonitor: DeviceActivityMonitor {
    
    override init() {
        super.init()
        
        // Marquer dans App Group que l'extension est initialisée
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "extension_initialized_timestamp")
        suite?.set("ZenloopDeviceActivityMonitor initialized", forKey: "extension_status")
        suite?.synchronize()
        
        print("🚀 [DeviceActivity] Extension ZenloopDeviceActivityMonitor initialized")
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("🚀 [DeviceActivity] ===== EXTENSION DÉCLENCHÉE =====")
        print("🎯 [DeviceActivity] Session démarrée: \(activity.rawValue)")
        print("🕐 [DeviceActivity] Heure de déclenchement: \(Date())")
        
        // CRUCIAL: Appliquer le blocage des apps depuis l'extension
        applyShield(for: activity)
        
        // CRUCIAL: Signaler à l'app qu'une session doit être activée
        activateSessionInMainApp(for: activity)
        
        // Notifier l'app principale
        notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)
        
        print("✅ [DeviceActivity] ===== EXTENSION SETUP TERMINÉ =====")
        
        // Challenge started - notification removed
        // scheduleNotification(
        //     title: "Défi Zenloop démarré",
        //     body: "Votre défi de bien-être numérique a commencé. Restez concentré !",
        //     identifier: "challenge_started_\(activity.rawValue)"
        // )
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // CRUCIAL: Retirer le blocage des apps
        removeShield(for: activity)
        
        // IMPORTANT: Arrêter le monitoring pour les sessions uniques (repeats: true)
        stopMonitoringIfSingleSession(activity: activity)
        
        // Logique quand un défi se termine
        print("✅ [DeviceActivity] Défi terminé: \(activity)")
        
        // Notifier l'app principale
        notifyMainApp(event: "intervalDidEnd", activity: activity.rawValue)
        
        // Challenge completed - notification removed
        // scheduleNotification(
        //     title: "Défi Zenloop terminé !",
        //     body: "Félicitations ! Vous avez réussi votre défi de bien-être numérique.",
        //     identifier: "challenge_completed_\(activity.rawValue)"
        // )
        
        // Sauvegarder les statistiques
        saveChallengeCompletion(activityName: activity)
    }
    
    private func stopMonitoringIfSingleSession(activity: DeviceActivityName) {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Vérifier si c'est une session programmée (commence par "scheduled_")
        if activity.rawValue.hasPrefix("scheduled_") {
            // Signaler à l'app principale d'arrêter le monitoring
            suite?.set(true, forKey: "stop_monitoring_\(activity.rawValue)")
            suite?.synchronize()
            
            print("🛑 [DeviceActivity] Marked single session for stop: \(activity.rawValue)")
        }
    }
    
    // Note: Les méthodes d'avertissement ne sont pas disponibles dans DeviceActivityMonitor
    // Elles sont gérées automatiquement par le système
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Logique quand un seuil est atteint (par exemple, limite de temps d'app)
        print("⚠️ [DeviceActivity] Seuil atteint pour l'événement: \(event) dans l'activité: \(activity)")
        
        // Notifier l'app principale
        notifyMainApp(event: "thresholdReached", activity: activity.rawValue, eventName: event.rawValue)
        
        // Threshold reached - notification removed
        // scheduleNotification(
        //     title: "Limite atteinte",
        //     body: "Vous avez atteint votre limite d'utilisation. Temps de faire une pause !",
        //     identifier: "threshold_reached_\(event.rawValue)"
        // )
    }
    
    // Note: eventWillReachThresholdWarning n'est pas disponible non plus
    
    // MARK: - Shield Management (CRUCIAL for background blocking)
    
    private func applyShield(for activity: DeviceActivityName) {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Extension is now active for this activity
        
        // Vérifier l'App Group
        guard let suite = suite else {
            print("❌ [DeviceActivity] Cannot access App Group 'group.com.app.zenloop'")
            return
        }
        
        let expectedKey = "payload_\(activity.rawValue)"
        print("🔍 [DeviceActivity] Looking for key: \(expectedKey)")
        
        // Lister toutes les clés disponibles pour debug console
        let allKeys = suite.dictionaryRepresentation().keys
        print("📋 [DeviceActivity] Available keys in App Group: \(Array(allKeys))")
        
        // Vérifier si c'est un test ou un vrai payload
        if let testPayload = suite.string(forKey: expectedKey) {
            // C'est un test payload simple
            print("✅ [DeviceActivity] Test payload found: \(testPayload)")
            return
        }
        
        guard
            let data = suite.data(forKey: expectedKey),
            let payload = try? JSONDecoder().decode(SelectionPayload.self, from: data)
        else {
            print("⚠️ [DeviceActivity] No payload found for key: \(expectedKey)")
            return
        }

        print("🎯 [DeviceActivity] Found payload - Apps: \(payload.apps.count), Categories: \(payload.categories.count)")

        // IMPORTANT: Le blocage s'applique depuis l'extension avec un store nommé
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))

        // Bloquer les apps sélectionnées
        if !payload.apps.isEmpty {
            store.shield.applications = Set(payload.apps)
            print("🛡️ [DeviceActivity] Blocked \(payload.apps.count) apps")
            
            // Apps blocked successfully
        }

        // Bloquer les catégories sélectionnées  
        if !payload.categories.isEmpty {
            store.shield.applicationCategories = .specific(Set(payload.categories))
            print("🛡️ [DeviceActivity] Blocked \(payload.categories.count) categories")
            
            // Categories blocked successfully
        }
        
        if payload.apps.isEmpty && payload.categories.isEmpty {
            print("⚠️ [DeviceActivity] Payload found but nothing to block")
        }
        
        print("✅ [DeviceActivity] Shield applied for \(activity.rawValue)")
    }

    private func removeShield(for activity: DeviceActivityName) {
        print("🔓 [DeviceActivity] Starting shield removal for: \(activity.rawValue)")

        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))

        print("   [DeviceActivity] Clearing shield.applications...")
        store.shield.applications = nil

        print("   [DeviceActivity] Clearing shield.applicationCategories...")
        store.shield.applicationCategories = nil

        print("✅ [DeviceActivity] Shield successfully removed for \(activity.rawValue)")
        print("   Blocked apps should now be accessible")
    }
    
    // MARK: - Helper Methods
    
    // Extension notifications disabled - function commented out
    /*
    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Déclencher immédiatement
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur notification: \(error)")
            }
        }
    }
    */
    
    private func saveChallengeCompletion(activityName: DeviceActivityName) {
        // Utiliser App Groups pour partager les données avec l'app principale
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Récupérer les défis complétés existants
        var completedChallenges = userDefaults?.array(forKey: "completedChallengeIds") as? [String] ?? []
        
        // Ajouter le nouveau défi complété
        completedChallenges.append(activityName.rawValue)
        
        // Sauvegarder
        userDefaults?.set(completedChallenges, forKey: "completedChallengeIds")
        userDefaults?.set(Date(), forKey: "lastChallengeCompletedDate")
        
        print("Défi sauvegardé: \(activityName.rawValue)")
    }
    
    // MARK: - Communication avec l'app principale
    
    private func notifyMainApp(event: String, activity: String, eventName: String? = nil) {
        // Utiliser UserDefaults pour communiquer avec l'app principale
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        let notification: [String: Any] = [
            "event": event,
            "activity": activity,
            "timestamp": Date().timeIntervalSince1970,
            "eventName": eventName as Any
        ]
        
        // Sauvegarder la notification
        var notifications = defaults.array(forKey: "device_activity_events") as? [[String: Any]] ?? []
        notifications.append(notification)
        
        // Garder seulement les 50 dernières notifications
        if notifications.count > 50 {
            notifications = Array(notifications.suffix(50))
        }
        
        defaults.set(notifications, forKey: "device_activity_events")
        defaults.synchronize()
        
        print("📤 [DeviceActivity] Notification envoyée: \(event) pour \(activity)")
    }
    
    private func recordAppAttempt(appName: String? = nil) {
        // Enregistrer les tentatives d'ouverture d'apps bloquées
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        // Incrementer le compteur total
        let currentCount = defaults.integer(forKey: "app_open_attempts")
        defaults.set(currentCount + 1, forKey: "app_open_attempts")
        
        // Enregistrer la tentative avec timestamp
        var attempts = defaults.array(forKey: "app_attempt_log") as? [[String: Any]] ?? []
        let attempt: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "appName": appName ?? "unknown"
        ]
        attempts.append(attempt)
        
        // Garder seulement les 100 dernières tentatives
        if attempts.count > 100 {
            attempts = Array(attempts.suffix(100))
        }
        
        defaults.set(attempts, forKey: "app_attempt_log")
        defaults.synchronize()
        
        print("🚫 [DeviceActivity] Tentative d'ouverture enregistrée: \(appName ?? "app inconnue")")
    }
    
    // MARK: - Session Activation
    
    private func activateSessionInMainApp(for activity: DeviceActivityName) {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Récupérer les infos de session depuis l'App Group
        let sessionKey = "session_info_\(activity.rawValue)"
        
        guard let sessionData = suite?.data(forKey: sessionKey),
              let sessionInfo = try? JSONDecoder().decode(SessionInfo.self, from: sessionData) else {
            print("⚠️ [DeviceActivity] No session info found for \(activity.rawValue)")
            return
        }
        
        // NOUVEAU: Gestion des sessions multiples - utiliser un système de queue
        let activationId = "\(activity.rawValue)_\(Date().timeIntervalSince1970)"
        
        // Créer un challenge actif avec ID unique et timing correct
        let activeChallenge: [String: Any] = [
            "id": sessionInfo.sessionId,
            "title": sessionInfo.title,
            "duration": sessionInfo.duration,
            "startTime": sessionInfo.startTime.timeIntervalSince1970, // CORRIGÉ: Utiliser l'heure programmée réelle
            "isActive": true,
            "isScheduled": true, // Marquer comme session programmée
            "originalStartTime": sessionInfo.startTime.timeIntervalSince1970,
            "activationId": activationId, // ID unique pour éviter les collisions
            "extensionTriggeredAt": Date().timeIntervalSince1970, // Quand l'extension s'est déclenchée
            "sessionPayloadKey": "payload_\(activity.rawValue)" // Référence aux apps à bloquer
        ]
        
        // NOUVEAU: Ajouter à une queue au lieu d'écraser
        addSessionToActivationQueue(session: activeChallenge, activationId: activationId, suite: suite!)
        
        print("🔥 [DeviceActivity] Session queued for activation: \(sessionInfo.title) (ID: \(activationId))")
    }
    
    private func addSessionToActivationQueue(session: [String: Any], activationId: String, suite: UserDefaults) {
        // Récupérer la queue existante
        var activationQueue = suite.array(forKey: "extension_activation_queue") as? [[String: Any]] ?? []
        
        // Ajouter la nouvelle session
        activationQueue.append(session)
        
        // Nettoyer les anciennes activations (> 5 minutes)
        let now = Date().timeIntervalSince1970
        activationQueue = activationQueue.filter { sessionData in
            if let triggerTime = sessionData["extensionTriggeredAt"] as? Double {
                return (now - triggerTime) < 300 // 5 minutes
            }
            return false
        }
        
        // Garder seulement les 5 dernières activations pour éviter l'overflow
        if activationQueue.count > 5 {
            activationQueue = Array(activationQueue.suffix(5))
        }
        
        // Sauvegarder la queue mise à jour
        suite.set(activationQueue, forKey: "extension_activation_queue")
        suite.set(Date().timeIntervalSince1970, forKey: "extension_queue_updated_at")
        suite.synchronize()
        
        print("📋 [DeviceActivity] Session added to queue. Total queued: \(activationQueue.count)")
    }
}

// Point d'entrée de l'extension - Device Activity Monitor n'a pas besoin de @main
// L'extension est automatiquement activée par le système
