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

// Type de restriction à appliquer
enum RestrictionMode: String, Codable {
    case shield // Blocage avec overlay (shield)
    case hide   // Masquage complet (blockedApplications)
}

struct SelectionPayload: Codable {
    let sessionId: String
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
    let restrictionMode: RestrictionMode? // nil = shield par défaut (compatibilité)
}

struct SessionInfo: Codable {
    let sessionId: String
    let title: String
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let createdAt: Date
}

// MARK: - Block Models

enum BlockStatus: String, Codable {
    case active
    case paused
    case stopped
}

struct ActiveBlock: Codable, Identifiable {
    let id: String
    let appName: String
    let storeName: String
    let startDate: TimeInterval
    var pausedAt: TimeInterval?
    var totalPausedDuration: TimeInterval
    let originalDuration: TimeInterval
    var status: BlockStatus
    let appTokenData: Data

    init(
        id: String = UUID().uuidString,
        appName: String,
        storeName: String,
        duration: TimeInterval,
        tokenData: Data,
        status: BlockStatus = .active
    ) {
        self.id = id
        self.appName = appName
        self.storeName = storeName
        self.startDate = Date().timeIntervalSince1970
        self.pausedAt = nil
        self.totalPausedDuration = 0
        self.originalDuration = duration
        self.status = status
        self.appTokenData = tokenData
    }
}

class ZenloopDeviceActivityMonitor: DeviceActivityMonitor {

    override init() {
        super.init()

        // Marquer dans App Group que l'extension est initialisée
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "extension_initialized_timestamp")
        suite?.set("ZenloopDeviceActivityMonitor initialized", forKey: "extension_status")
        suite?.synchronize()

        print("🚀 [MONITOR] Extension initialized (Apple-compliant architecture)")
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        print("🚀 [MONITOR] ===== INTERVAL STARTED =====")
        print("🎯 [MONITOR] Activity: \(activity.rawValue)")
        print("🕐 [MONITOR] Time: \(Date())")

        // ✅ APPLE-COMPLIANT: Appliquer le shield depuis le Monitor
        // C'est ici que le blocage doit se faire, pas depuis l'app principale
        applyShield(for: activity)

        // Déterminer le type d'activité
        if activity.rawValue.hasPrefix("block-") {
            // Blocage individuel depuis Report Extension
            print("📱 [MONITOR] This is a block activity")
            handleBlockActivity(activity)
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // Session programmée (défi)
            print("⏰ [MONITOR] This is a scheduled session")
            activateSessionInMainApp(for: activity)
        }

        // Notifier l'app principale
        notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)

        print("✅ [MONITOR] Shield applied, interval active")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // ⚠️ CRITICAL DEBUG LOGS - DO NOT REMOVE
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔓🔓🔓 [MONITOR] ===== INTERVAL DID END CALLED =====")
        print("🕐 [MONITOR] Time: \(Date())")
        print("🎯 [MONITOR] Activity: \(activity.rawValue)")
        print("⚠️ [MONITOR] This method MUST unblock the app automatically!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Log to App Group for visibility
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "last_intervalDidEnd_timestamp")
        suite?.set(activity.rawValue, forKey: "last_intervalDidEnd_activity")
        suite?.synchronize()
        print("💾 [MONITOR] Logged to App Group: last_intervalDidEnd_timestamp")

        // ✅ APPLE-COMPLIANT: Retirer le shield quand l'intervalle se termine
        removeShield(for: activity)

        // Gérer selon le type d'activité
        if activity.rawValue.hasPrefix("block-") {
            // Nettoyer les données de blocage
            print("📱 [MONITOR] Detected block- activity, processing...")
            handleBlockActivityEnd(activity)

            // ✅ CRUCIAL: Aussi retirer du DEFAULT store (utilisé par GlobalShieldManager)
            print("🔑 [MONITOR] Now removing from DEFAULT store...")
            removeFromDefaultStore(for: activity)
            print("✅ [MONITOR] DEFAULT store removal completed")
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // Sauvegarder les stats de session
            print("⏰ [MONITOR] Detected scheduled_ activity")
            stopMonitoringIfSingleSession(activity: activity)
            saveChallengeCompletion(activityName: activity)
        } else {
            print("⚠️ [MONITOR] Unknown activity type: \(activity.rawValue)")
        }

        // Notifier l'app principale
        notifyMainApp(event: "intervalDidEnd", activity: activity.rawValue)

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅✅✅ [MONITOR] INTERVAL DID END COMPLETE")
        print("🔓 [MONITOR] App should be UNBLOCKED now!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
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
        print("🛡️ [MONITOR] === APPLYING SHIELD ===")
        print("🛡️ [MONITOR] Activity: \(activity.rawValue)")

        // Vérifier l'App Group
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group 'group.com.app.zenloop'")
            return
        }

        let expectedKey = "payload_\(activity.rawValue)"
        print("🔍 [MONITOR] Looking for payload key: \(expectedKey)")

        // Debug: Lister toutes les clés disponibles
        let allKeys = suite.dictionaryRepresentation().keys.sorted()
        print("📋 [MONITOR] Available keys in App Group: \(allKeys.prefix(10).joined(separator: ", "))")

        // Vérifier si c'est un test payload
        if let testPayload = suite.string(forKey: expectedKey) {
            print("✅ [MONITOR] Test payload found: \(testPayload)")
            return
        }

        // Décoder le payload
        guard let data = suite.data(forKey: expectedKey) else {
            print("❌ [MONITOR] No payload data found for key: \(expectedKey)")
            print("⚠️ [MONITOR] This might mean the BlockAppSheet didn't save the payload correctly")
            return
        }

        print("✅ [MONITOR] Payload data found: \(data.count) bytes")

        guard let payload = try? JSONDecoder().decode(SelectionPayload.self, from: data) else {
            print("❌ [MONITOR] Failed to decode payload data")
            return
        }

        let mode = payload.restrictionMode ?? .shield
        print("🎯 [MONITOR] Payload decoded successfully:")
        print("   → Apps: \(payload.apps.count)")
        print("   → Categories: \(payload.categories.count)")
        print("   → Mode: \(mode.rawValue)")
        print("   → Session ID: \(payload.sessionId)")

        // IMPORTANT: Le blocage s'applique depuis l'extension avec un store nommé
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        print("📦 [MONITOR] Using ManagedSettingsStore: \(activity.rawValue)")

        switch mode {
        case .shield:
            // Mode Shield: Blocage avec overlay
            if !payload.apps.isEmpty {
                print("🔒 [MONITOR] Applying shield to \(payload.apps.count) app(s)...")
                store.shield.applications = Set(payload.apps)

                // Vérification immédiate
                let appliedApps = store.shield.applications?.count ?? 0
                print("✅ [MONITOR] Shield applied to \(appliedApps) app(s)")

                if appliedApps != payload.apps.count {
                    print("⚠️ [MONITOR] Mismatch! Expected \(payload.apps.count) but got \(appliedApps)")
                }
            }

            if !payload.categories.isEmpty {
                print("🔒 [MONITOR] Applying shield to \(payload.categories.count) category(ies)...")
                store.shield.applicationCategories = .specific(Set(payload.categories))
                print("✅ [MONITOR] Shield applied to categories")
            }

        case .hide:
            // Mode Hide: Masquage complet des apps individuelles
            if !payload.apps.isEmpty {
                print("🚫 [MONITOR] Hiding \(payload.apps.count) app(s) completely...")
                let blockedApps: Set<Application> = Set(payload.apps.map { Application(token: $0) })
                store.application.blockedApplications = blockedApps
                print("✅ [MONITOR] Apps hidden completely")
            }

            // Pour les catégories en mode hide, on utilise quand même shield
            if !payload.categories.isEmpty {
                store.shield.applicationCategories = .specific(Set(payload.categories))
                print("✅ [MONITOR] Shield applied for categories (hide mode)")
            }
        }

        if payload.apps.isEmpty && payload.categories.isEmpty {
            print("⚠️ [MONITOR] Payload found but nothing to block!")
        } else {
            print("✅ [MONITOR] Shield successfully applied for \(activity.rawValue)")
            print("   → Mode: \(mode.rawValue)")
            print("   → Apps blocked: \(payload.apps.count)")
            print("   → Categories blocked: \(payload.categories.count)")
        }
    }

    private func removeShield(for activity: DeviceActivityName) {
        print("🔓 [DeviceActivity] Starting restriction removal for: \(activity.rawValue)")

        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))

        // Nettoyer les deux modes (shield ET hide) pour être sûr
        print("   [DeviceActivity] Clearing shield.applications...")
        store.shield.applications = nil

        print("   [DeviceActivity] Clearing shield.applicationCategories...")
        store.shield.applicationCategories = nil

        print("   [DeviceActivity] Clearing application.blockedApplications (hide mode)...")
        store.application.blockedApplications = nil

        print("✅ [DeviceActivity] All restrictions removed for \(activity.rawValue)")
        print("   Apps should now be accessible/visible")
    }

    /// ✅ CRUCIAL: Retirer le token du DEFAULT store (utilisé par GlobalShieldManager)
    private func removeFromDefaultStore(for activity: DeviceActivityName) {
        print("🔓 [MONITOR] === REMOVING FROM DEFAULT STORE ===")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        // Récupérer le blockId depuis l'activity name
        let activityName = activity.rawValue
        let blockId = String(activityName.dropFirst("block-".count))

        print("🔍 [MONITOR] Looking for block: \(blockId)")

        // Charger le block pour obtenir le token
        var blocks = loadBlocksFromAppGroup()
        guard let block = blocks.first(where: { $0.id == blockId }) else {
            print("⚠️ [MONITOR] Block not found in App Group: \(blockId)")
            return
        }

        print("✅ [MONITOR] Block found: \(block.appName)")

        // Décoder le token
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [MONITOR] Failed to decode token")
            return
        }

        print("✅ [MONITOR] Token decoded successfully")

        // Retirer du DEFAULT store
        let defaultStore = ManagedSettingsStore() // Store par défaut (sans nom)
        var blockedApps = defaultStore.shield.applications ?? Set()
        let beforeCount = blockedApps.count

        blockedApps.remove(token)
        let afterCount = blockedApps.count

        defaultStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps

        print("🔓 [MONITOR] Removed from DEFAULT store:")
        print("   → Before: \(beforeCount) apps")
        print("   → After: \(afterCount) apps")
        print("   → Removed: \(beforeCount - afterCount) app(s)")

        if beforeCount == afterCount {
            print("⚠️ [MONITOR] WARNING: Token was not in DEFAULT store!")
        }

        print("✅ [MONITOR] App unblocked from DEFAULT store: \(block.appName)")
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
    
    // MARK: - Block Activity Management

    /// Gère les activités de blocage individuel (block-*)
    private func handleBlockActivity(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        // Extraire le blockId depuis le nom de l'activité
        let activityName = activity.rawValue
        let blockId = String(activityName.dropFirst("block-".count))

        print("📝 [MONITOR] Processing block activity - ID: \(blockId)")

        // Récupérer les infos du block depuis App Group
        guard let blockInfoDict = suite.dictionary(forKey: "block_info_\(blockId)") else {
            print("⚠️ [MONITOR] No block info found for \(blockId)")
            return
        }

        guard let appName = blockInfoDict["appName"] as? String,
              let duration = blockInfoDict["duration"] as? TimeInterval,
              let startTime = blockInfoDict["startTime"] as? TimeInterval,
              let tokenData = blockInfoDict["tokenData"] as? Data else {
            print("❌ [MONITOR] Invalid block info format")
            return
        }

        print("✅ [MONITOR] Block info loaded:")
        print("   → App: \(appName)")
        print("   → Duration: \(Int(duration/60)) minutes")
        print("   → Block ID: \(blockId)")

        // Créer l'ActiveBlock pour affichage dans l'UI
        let activeBlock = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: activityName,
            duration: duration,
            tokenData: tokenData,
            status: .active
        )

        // Sauvegarder dans la liste des blocks actifs
        saveBlockToAppGroup(activeBlock)

        print("💾 [MONITOR] Block saved to active blocks list")
    }

    /// Gère la fin d'une activité de blocage
    private func handleBlockActivityEnd(_ activity: DeviceActivityName) {
        let activityName = activity.rawValue
        let blockId = String(activityName.dropFirst("block-".count))

        print("🔓 [MONITOR] Ending block activity - ID: \(blockId)")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group for cleanup")
            return
        }

        // 1. Récupérer le block info pour trouver le blockManagerId
        if let blockInfoDict = suite.dictionary(forKey: "block_info_\(blockId)"),
           let blockManagerId = blockInfoDict["blockId"] as? String {

            print("🗑️ [MONITOR] Removing block: \(blockManagerId)")

            // Retirer du storage (utilise les fonctions locales)
            removeBlockFromAppGroup(blockId: blockManagerId)

            print("✅ [MONITOR] Block removed from storage")
        }

        // 2. Nettoyer le storeName mapping
        if let storedStoreName = suite.string(forKey: "storeName_\(blockId)") {
            print("🧹 [MONITOR] Cleaning storeName mapping: \(storedStoreName)")
            suite.removeObject(forKey: "storeName_\(blockId)")
        }

        // 3. Nettoyer les infos temporaires
        suite.removeObject(forKey: "block_info_\(blockId)")
        suite.removeObject(forKey: "payload_\(activityName)")
        suite.synchronize()

        print("✅ [MONITOR] Block cleanup complete")
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

    // MARK: - DEPRECATED: Old Manual Block Management
    // These methods are kept for backward compatibility but should not be used
    // The new architecture uses DeviceActivityCenter → Monitor → ManagedSettings

    /// ⚠️ DEPRECATED: Use DeviceActivityCenter.startMonitoring instead
    @available(*, deprecated, message: "Use DeviceActivityCenter.startMonitoring from the app instead")
    private func processBlockRequests() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        // Lire la demande de blocage
        guard let tokenData = suite.data(forKey: "pending_block_tokenData"),
              let appName = suite.string(forKey: "pending_block_appName"),
              let duration = suite.object(forKey: "pending_block_duration") as? TimeInterval,
              let storeName = suite.string(forKey: "pending_block_storeName"),
              let blockId = suite.string(forKey: "pending_block_id") else {
            // Pas de demande en attente, c'est normal
            return
        }

        print("📨 [MONITOR] Processing block request: \(appName)")

        // Nettoyer immédiatement pour éviter le retraitement
        suite.removeObject(forKey: "pending_block_tokenData")
        suite.removeObject(forKey: "pending_block_appName")
        suite.removeObject(forKey: "pending_block_duration")
        suite.removeObject(forKey: "pending_block_storeName")
        suite.removeObject(forKey: "pending_block_id")
        suite.removeObject(forKey: "pending_block_timestamp")
        suite.synchronize()

        // Décoder le token
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [MONITOR] Failed to decode token")
            return
        }

        print("✅ [MONITOR] Token decoded successfully")

        // 1. Appliquer le blocage immédiatement
        let store = ManagedSettingsStore(named: .init(storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(token)
        store.shield.applications = blockedApps

        print("🛡️ [MONITOR] App blocked: \(appName)")

        // 2. Sauvegarder dans App Group (l'écriture depuis Monitor est FIABLE)
        let block = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: storeName,
            duration: duration,
            tokenData: tokenData,
            status: .active
        )

        saveBlockToAppGroup(block)

        print("✅ [MONITOR] Block persisted in App Group: \(blockId)")

        // 3. Programmer le déblocage automatique
        scheduleAutoUnblock(blockId: blockId, storeName: storeName, duration: duration, appName: appName)
    }

    /// Sauvegarder le block dans App Group
    private func saveBlockToAppGroup(_ block: ActiveBlock) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        var blocks = loadBlocksFromAppGroup()
        blocks.append(block)

        if let data = try? JSONEncoder().encode(blocks) {
            suite.set(data, forKey: "active_blocks_v2")
            suite.synchronize()
            print("💾 [MONITOR] Saved \(blocks.count) blocks to App Group")
        }
    }

    /// Charger les blocks depuis App Group
    private func loadBlocksFromAppGroup() -> [ActiveBlock] {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
              let data = suite.data(forKey: "active_blocks_v2"),
              let blocks = try? JSONDecoder().decode([ActiveBlock].self, from: data) else {
            return []
        }
        return blocks
    }

    /// Programmer le déblocage automatique
    private func scheduleAutoUnblock(blockId: String, storeName: String, duration: TimeInterval, appName: String) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let unblockTime = Date().timeIntervalSince1970 + duration

        // Sauvegarder l'info de déblocage
        let unblockInfo: [String: Any] = [
            "blockId": blockId,
            "storeName": storeName,
            "appName": appName,
            "unblockTime": unblockTime
        ]

        var scheduledUnblocks = suite.array(forKey: "scheduled_unblocks") as? [[String: Any]] ?? []
        scheduledUnblocks.append(unblockInfo)
        suite.set(scheduledUnblocks, forKey: "scheduled_unblocks")
        suite.synchronize()

        print("⏰ [MONITOR] Auto-unblock scheduled for \(appName) at \(Date(timeIntervalSince1970: unblockTime))")
    }

    /// Vérifier et exécuter les déblocages programmés
    func checkScheduledUnblocks() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let now = Date().timeIntervalSince1970
        var scheduledUnblocks = suite.array(forKey: "scheduled_unblocks") as? [[String: Any]] ?? []
        var remainingUnblocks: [[String: Any]] = []

        for unblockInfo in scheduledUnblocks {
            guard let unblockTime = unblockInfo["unblockTime"] as? TimeInterval,
                  let storeName = unblockInfo["storeName"] as? String,
                  let blockId = unblockInfo["blockId"] as? String,
                  let appName = unblockInfo["appName"] as? String else {
                continue
            }

            if now >= unblockTime {
                // C'est l'heure de débloquer
                print("🔓 [MONITOR] Auto-unblocking: \(appName)")

                let store = ManagedSettingsStore(named: .init(storeName))
                store.shield.applications = nil
                store.clearAllSettings()

                // Retirer le block de App Group
                removeBlockFromAppGroup(blockId: blockId)

                print("✅ [MONITOR] Auto-unblock complete: \(appName)")
            } else {
                // Pas encore l'heure, garder
                remainingUnblocks.append(unblockInfo)
            }
        }

        // Mettre à jour la liste
        suite.set(remainingUnblocks, forKey: "scheduled_unblocks")
        suite.synchronize()
    }

    /// Retirer un block de App Group
    private func removeBlockFromAppGroup(blockId: String) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        var blocks = loadBlocksFromAppGroup()
        blocks.removeAll { $0.id == blockId }

        if let data = try? JSONEncoder().encode(blocks) {
            suite.set(data, forKey: "active_blocks_v2")
            suite.synchronize()
            print("🗑️ [MONITOR] Block removed from App Group: \(blockId)")
        }
    }
}

// Point d'entrée de l'extension - Device Activity Monitor n'a pas besoin de @main
// L'extension est automatiquement activée par le système
