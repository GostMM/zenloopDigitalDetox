//
//  zenloopmonitor.swift
//  zenloopmonitor
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//
//  ✅ FIX: intervalDidStart pour sessions programmées applique correctement le shield
//  ✅ FIX: intervalDidEnd nettoie le payload des sessions programmées
//

import DeviceActivity
import Foundation
import UserNotifications
import ManagedSettings
import FamilyControls
import os.log

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

// ✅ Shared with main app — MUST stay identical to ScheduledSessionCoordinator.swift
struct ScheduledSessionInfo: Codable {
    let sessionId: String
    let startTime: Date
    let endTime: Date
    var status: ScheduledSessionStatus
    var actualStartTime: Date?
    var actualEndTime: Date?
}

enum ScheduledSessionStatus: String, Codable {
    case scheduled  // Planifiée, en attente
    case started    // Démarrée automatiquement
    case completed  // Terminée automatiquement
    case cancelled  // Annulée manuellement
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

        let logger = Logger(subsystem: "com.app.zenloop.monitor", category: "IntervalStart")

        logger.critical("🚀 [MONITOR] ===== INTERVAL STARTED =====")
        logger.critical("🎯 [MONITOR] Activity: \(activity.rawValue)")
        logger.critical("🕐 [MONITOR] Time: \(Date())")

        print("🚀 [MONITOR] ===== INTERVAL STARTED =====")
        print("🎯 [MONITOR] Activity: \(activity.rawValue)")
        print("🕐 [MONITOR] Time: \(Date())")

        // ✅ APPLE-COMPLIANT: Appliquer le shield depuis le Monitor
        // applyShield cherche "payload_<activity.rawValue>" dans App Group
        applyShield(for: activity)

        // Déterminer le type d'activité
        if activity.rawValue.hasPrefix("block-") {
            // Blocage individuel depuis Report Extension
            print("📱 [MONITOR] This is a block activity")
            handleBlockActivity(activity)
        } else if activity.rawValue.hasPrefix("scheduled_session_") {
            // ✅ FIX: Session sociale programmée — démarrer la session Firebase
            print("⏰ [MONITOR] This is a scheduled social session")
            logger.critical("⏰ [MONITOR] Scheduled social session detected: \(activity.rawValue)")
            activateSessionInMainApp(for: activity)
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // Ancien système de défis
            print("⏰ [MONITOR] This is a scheduled challenge")
            activateSessionInMainApp(for: activity)
        }

        // Notifier l'app principale
        notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)

        logger.critical("✅ [MONITOR] Shield applied, interval active")
        print("✅ [MONITOR] Shield applied, interval active")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        let logger = Logger(subsystem: "com.app.zenloop.monitor", category: "IntervalEnd")

        // ⚠️ CRITICAL DEBUG LOGS - DO NOT REMOVE
        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        logger.critical("🔓🔓🔓 [MONITOR] ===== INTERVAL DID END CALLED =====")
        logger.critical("🕐 [MONITOR] Time: \(Date())")
        logger.critical("🎯 [MONITOR] Activity: \(activity.rawValue)")
        logger.critical("⚠️ [MONITOR] This method MUST unblock the app automatically!")
        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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
        logger.critical("🔍 [MONITOR] Checking activity type: \(activity.rawValue)")

        if activity.rawValue.hasPrefix("block-") {
            // Nettoyer les données de blocage
            logger.critical("📱 [MONITOR] Detected block- activity, processing...")
            print("📱 [MONITOR] Detected block- activity, processing...")
            handleBlockActivityEnd(activity)

            // ✅ CRUCIAL: Aussi retirer du DEFAULT store (utilisé par GlobalShieldManager)
            logger.critical("🔑 [MONITOR] Now removing from DEFAULT store...")
            print("🔑 [MONITOR] Now removing from DEFAULT store...")
            removeFromDefaultStore(for: activity)
            logger.critical("✅ [MONITOR] DEFAULT store removal completed")
            print("✅ [MONITOR] DEFAULT store removal completed")
        } else if activity.rawValue.hasPrefix("scheduled_session_") {
            // ✅ FIX: Arrêter automatiquement la session sociale programmée
            logger.critical("⏰ [MONITOR] Detected scheduled_session_ activity END")
            print("⏰ [MONITOR] Detected scheduled_session_ activity END")
            handleScheduledSessionEnd(activity)

            // ✅ FIX: Nettoyer le payload de la session programmée
            cleanupScheduledSessionPayload(for: activity)
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // Sauvegarder les stats de session (ancien système de défis)
            logger.critical("⏰ [MONITOR] Detected scheduled_ activity")
            print("⏰ [MONITOR] Detected scheduled_ activity")
            stopMonitoringIfSingleSession(activity: activity)
            saveChallengeCompletion(activityName: activity)
        } else {
            logger.critical("⚠️ [MONITOR] Unknown activity type: \(activity.rawValue)")
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
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        print("⚠️ [DeviceActivity] Seuil atteint pour l'événement: \(event) dans l'activité: \(activity)")
        
        notifyMainApp(event: "thresholdReached", activity: activity.rawValue, eventName: event.rawValue)
    }
    
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
        let payloadKeys = allKeys.filter { $0.hasPrefix("payload_") }
        print("📋 [MONITOR] Payload keys in App Group: \(payloadKeys.joined(separator: ", "))")

        // Vérifier si c'est un test payload
        if let testPayload = suite.string(forKey: expectedKey) {
            print("✅ [MONITOR] Test payload found: \(testPayload)")
            return
        }

        // Décoder le payload
        guard let data = suite.data(forKey: expectedKey) else {
            print("❌ [MONITOR] No payload data found for key: \(expectedKey)")
            print("⚠️ [MONITOR] This might mean the payload wasn't saved correctly")

            // ✅ FIX: Fallback — essayer la clé des apps de session programmée
            if activity.rawValue.hasPrefix("scheduled_session_") {
                let sessionId = String(activity.rawValue.dropFirst("scheduled_session_".count))
                let appsKey = "scheduled_session_apps_\(sessionId)"
                print("🔄 [MONITOR] Trying fallback key: \(appsKey)")

                if let selectionData = suite.data(forKey: appsKey),
                   let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                    print("✅ [MONITOR] Fallback: Found FamilyActivitySelection")
                    applyShieldFromSelection(selection, activityName: activity.rawValue)
                    return
                } else {
                    print("❌ [MONITOR] Fallback also failed — no apps to block")
                }
            }
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
            if !payload.apps.isEmpty {
                print("🔒 [MONITOR] Applying shield to \(payload.apps.count) app(s)...")
                store.shield.applications = Set(payload.apps)

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
            if !payload.apps.isEmpty {
                print("🚫 [MONITOR] Hiding \(payload.apps.count) app(s) completely...")
                let blockedApps: Set<Application> = Set(payload.apps.map { Application(token: $0) })
                store.application.blockedApplications = blockedApps
                print("✅ [MONITOR] Apps hidden completely")
            }

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

    /// ✅ NEW: Fallback — applique le shield depuis une FamilyActivitySelection brute
    private func applyShieldFromSelection(_ selection: FamilyActivitySelection, activityName: String) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activityName))

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
            print("🛡️ [MONITOR] Fallback shield applied to \(selection.applicationTokens.count) app(s)")
        }

        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            print("🛡️ [MONITOR] Fallback shield applied to \(selection.categoryTokens.count) category(ies)")
        }

        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            print("⚠️ [MONITOR] Fallback: No apps or categories in selection")
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
        let logger = Logger(subsystem: "com.app.zenloop.monitor", category: "DefaultStore")

        logger.critical("🔓 [MONITOR] === REMOVING FROM DEFAULT STORE ===")
        print("🔓 [MONITOR] === REMOVING FROM DEFAULT STORE ===")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.critical("❌ [MONITOR] Cannot access App Group")
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        // ✅ CRUCIAL: Récupérer le VRAI blockId depuis le mapping
        let activityName = activity.rawValue
        let mappingKey = "blockId_for_activity_\(activityName)"

        logger.critical("🔍 [MONITOR] Looking for mapping: \(mappingKey)")
        print("🔍 [MONITOR] Looking for mapping: \(mappingKey)")

        guard let blockId = suite.string(forKey: mappingKey) else {
            logger.critical("❌ [MONITOR] No mapping found for activity: \(activityName)")
            print("❌ [MONITOR] No mapping found for activity: \(activityName)")
            logger.critical("⚠️ [MONITOR] Cannot unblock without blockId mapping!")
            print("⚠️ [MONITOR] Cannot unblock without blockId mapping!")
            return
        }

        logger.critical("✅ [MONITOR] Found blockId from mapping: \(blockId)")
        print("✅ [MONITOR] Found blockId from mapping: \(blockId)")

        logger.critical("🔍 [MONITOR] Looking for block: \(blockId)")
        print("🔍 [MONITOR] Looking for block: \(blockId)")

        // Charger le block pour obtenir le token
        var blocks = loadBlocksFromAppGroup()
        logger.critical("🔍 [MONITOR] Loaded \(blocks.count) blocks from App Group")
        print("🔍 [MONITOR] Loaded \(blocks.count) blocks from App Group")

        guard let block = blocks.first(where: { $0.id == blockId }) else {
            logger.critical("⚠️ [MONITOR] Block not found in App Group: \(blockId)")
            print("⚠️ [MONITOR] Block not found in App Group: \(blockId)")
            return
        }

        logger.critical("✅ [MONITOR] Block found: \(block.appName)")
        print("✅ [MONITOR] Block found: \(block.appName)")

        // Décoder le token
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
              let token = selection.applicationTokens.first else {
            logger.critical("❌ [MONITOR] Failed to decode token")
            print("❌ [MONITOR] Failed to decode token")
            return
        }

        logger.critical("✅ [MONITOR] Token decoded successfully")
        print("✅ [MONITOR] Token decoded successfully")

        // Retirer du DEFAULT store
        let defaultStore = ManagedSettingsStore() // Store par défaut (sans nom)
        var blockedApps = defaultStore.shield.applications ?? Set()
        let beforeCount = blockedApps.count

        blockedApps.remove(token)
        let afterCount = blockedApps.count

        defaultStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps

        logger.critical("🔓 [MONITOR] Removed from DEFAULT store:")
        logger.critical("   → Before: \(beforeCount) apps")
        logger.critical("   → After: \(afterCount) apps")
        logger.critical("   → Removed: \(beforeCount - afterCount) app(s)")

        print("🔓 [MONITOR] Removed from DEFAULT store:")
        print("   → Before: \(beforeCount) apps")
        print("   → After: \(afterCount) apps")
        print("   → Removed: \(beforeCount - afterCount) app(s)")

        if beforeCount == afterCount {
            logger.critical("⚠️ [MONITOR] WARNING: Token was not in DEFAULT store!")
            print("⚠️ [MONITOR] WARNING: Token was not in DEFAULT store!")
        }

        logger.critical("✅ [MONITOR] App unblocked from DEFAULT store: \(block.appName)")
        print("✅ [MONITOR] App unblocked from DEFAULT store: \(block.appName)")

        // ✅ Nettoyer le mapping après déblocage
        suite.removeObject(forKey: mappingKey)
        suite.synchronize()

        logger.critical("🧹 [MONITOR] Cleaned up mapping: \(mappingKey)")
        print("🧹 [MONITOR] Cleaned up mapping: \(mappingKey)")
    }

    // MARK: - ✅ NEW: Cleanup Scheduled Session Payload

    /// Nettoie les données de payload et apps d'une session programmée après son arrêt
    private func cleanupScheduledSessionPayload(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let activityName = activity.rawValue

        // Nettoyer le payload
        suite.removeObject(forKey: "payload_\(activityName)")

        // Nettoyer les apps si c'est une session sociale
        if activityName.hasPrefix("scheduled_session_") {
            let sessionId = String(activityName.dropFirst("scheduled_session_".count))
            suite.removeObject(forKey: "scheduled_session_apps_\(sessionId)")

            // Retirer de la liste des sessions actives
            var activeSchedules = suite.stringArray(forKey: "active_scheduled_sessions") ?? []
            activeSchedules.removeAll { $0 == sessionId }
            suite.set(activeSchedules, forKey: "active_scheduled_sessions")
        }

        suite.synchronize()
        print("🧹 [MONITOR] Cleaned up scheduled session payload for: \(activityName)")
    }
    
    // MARK: - Helper Methods
    
    private func saveChallengeCompletion(activityName: DeviceActivityName) {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        var completedChallenges = userDefaults?.array(forKey: "completedChallengeIds") as? [String] ?? []
        completedChallenges.append(activityName.rawValue)
        
        userDefaults?.set(completedChallenges, forKey: "completedChallengeIds")
        userDefaults?.set(Date(), forKey: "lastChallengeCompletedDate")
        
        print("Défi sauvegardé: \(activityName.rawValue)")
    }
    
    // MARK: - Communication avec l'app principale
    
    private func notifyMainApp(event: String, activity: String, eventName: String? = nil) {
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        let notification: [String: Any] = [
            "event": event,
            "activity": activity,
            "timestamp": Date().timeIntervalSince1970,
            "eventName": eventName as Any
        ]
        
        var notifications = defaults.array(forKey: "device_activity_events") as? [[String: Any]] ?? []
        notifications.append(notification)
        
        if notifications.count > 50 {
            notifications = Array(notifications.suffix(50))
        }
        
        defaults.set(notifications, forKey: "device_activity_events")
        defaults.synchronize()
        
        print("📤 [DeviceActivity] Notification envoyée: \(event) pour \(activity)")
    }
    
    private func recordAppAttempt(appName: String? = nil) {
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        let currentCount = defaults.integer(forKey: "app_open_attempts")
        defaults.set(currentCount + 1, forKey: "app_open_attempts")
        
        var attempts = defaults.array(forKey: "app_attempt_log") as? [[String: Any]] ?? []
        let attempt: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "appName": appName ?? "unknown"
        ]
        attempts.append(attempt)
        
        if attempts.count > 100 {
            attempts = Array(attempts.suffix(100))
        }
        
        defaults.set(attempts, forKey: "app_attempt_log")
        defaults.synchronize()
        
        print("🚫 [DeviceActivity] Tentative d'ouverture enregistrée: \(appName ?? "app inconnue")")
    }
    
    // MARK: - Block Activity Management

    private func handleBlockActivity(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        let activityName = activity.rawValue
        let blockId = String(activityName.dropFirst("block-".count))

        print("📝 [MONITOR] Processing block activity - ID: \(blockId)")

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

        let activeBlock = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: activityName,
            duration: duration,
            tokenData: tokenData,
            status: .active
        )

        saveBlockToAppGroup(activeBlock)

        print("💾 [MONITOR] Block saved to active blocks list")
    }

    private func handleBlockActivityEnd(_ activity: DeviceActivityName) {
        let activityName = activity.rawValue
        let blockId = String(activityName.dropFirst("block-".count))

        print("🔓 [MONITOR] Ending block activity - ID: \(blockId)")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group for cleanup")
            return
        }

        if let blockInfoDict = suite.dictionary(forKey: "block_info_\(blockId)"),
           let blockManagerId = blockInfoDict["blockId"] as? String {

            print("🗑️ [MONITOR] Removing block: \(blockManagerId)")
            removeBlockFromAppGroup(blockId: blockManagerId)
            print("✅ [MONITOR] Block removed from storage")
        }

        if let storedStoreName = suite.string(forKey: "storeName_\(blockId)") {
            print("🧹 [MONITOR] Cleaning storeName mapping: \(storedStoreName)")
            suite.removeObject(forKey: "storeName_\(blockId)")
        }

        suite.removeObject(forKey: "block_info_\(blockId)")
        suite.removeObject(forKey: "payload_\(activityName)")
        suite.synchronize()

        print("✅ [MONITOR] Block cleanup complete")
    }

    // MARK: - Session Activation

    /// ✅ Démarre automatiquement une session sociale programmée
    private func activateSessionInMainApp(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        let activityName = activity.rawValue
        guard activityName.hasPrefix("scheduled_session_") else {
            print("⚠️ [MONITOR] Invalid scheduled session activity name: \(activityName)")
            return
        }

        let sessionId = String(activityName.dropFirst("scheduled_session_".count))
        print("🚀 [MONITOR] === AUTO-STARTING SCHEDULED SESSION ===")
        print("📝 [MONITOR] Session ID: \(sessionId)")

        // Récupérer les infos de la session programmée
        guard let infoData = suite.data(forKey: "scheduled_session_\(sessionId)"),
              let info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: infoData) else {
            print("❌ [MONITOR] No scheduled session info found for \(sessionId)")
            return
        }

        // Vérifier que c'est bien l'heure de démarrer
        let now = Date()
        if now < info.startTime {
            print("⚠️ [MONITOR] Too early to start session (scheduled for \(info.startTime))")
            return
        }

        print("✅ [MONITOR] Scheduled session info loaded")
        print("   → Start: \(info.startTime.formatted())")
        print("   → End: \(info.endTime.formatted())")

        // Marquer la session comme démarrée
        var updatedInfo = info
        updatedInfo.status = .started
        updatedInfo.actualStartTime = now

        if let data = try? JSONEncoder().encode(updatedInfo) {
            suite.set(data, forKey: "scheduled_session_\(sessionId)")
            suite.synchronize()
        }

        // ✅ CRUCIAL: Signaler à l'app principale de démarrer la session Firebase
        suite.set(sessionId, forKey: "auto_start_session_id")
        suite.set(Date().timeIntervalSince1970, forKey: "auto_start_session_timestamp")
        suite.synchronize()

        print("🔥 [MONITOR] Scheduled session auto-start triggered: \(sessionId)")
        print("🎯 [MONITOR] Main app will start Firebase session on next activation")
    }

    /// ✅ Arrête automatiquement une session sociale programmée
    private func handleScheduledSessionEnd(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        let activityName = activity.rawValue
        let sessionId = String(activityName.dropFirst("scheduled_session_".count))

        print("🛑 [MONITOR] === AUTO-STOPPING SCHEDULED SESSION ===")
        print("📝 [MONITOR] Session ID: \(sessionId)")

        // Récupérer les infos de la session programmée
        if let infoData = suite.data(forKey: "scheduled_session_\(sessionId)"),
           var info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: infoData) {

            // Marquer la session comme terminée
            info.status = .completed
            info.actualEndTime = Date()

            if let data = try? JSONEncoder().encode(info) {
                suite.set(data, forKey: "scheduled_session_\(sessionId)")
                suite.synchronize()
            }
        } else {
            print("⚠️ [MONITOR] No scheduled session info found for \(sessionId) — proceeding with stop signal anyway")
        }

        // ✅ CRUCIAL: Signaler à l'app principale d'arrêter la session Firebase
        suite.set(sessionId, forKey: "auto_stop_session_id")
        suite.set(Date().timeIntervalSince1970, forKey: "auto_stop_session_timestamp")
        suite.synchronize()

        print("🔥 [MONITOR] Scheduled session auto-stop triggered: \(sessionId)")
        print("🎯 [MONITOR] Main app will stop Firebase session on next activation")
    }

    private func addSessionToActivationQueue(session: [String: Any], activationId: String, suite: UserDefaults) {
        var activationQueue = suite.array(forKey: "extension_activation_queue") as? [[String: Any]] ?? []
        activationQueue.append(session)
        
        let now = Date().timeIntervalSince1970
        activationQueue = activationQueue.filter { sessionData in
            if let triggerTime = sessionData["extensionTriggeredAt"] as? Double {
                return (now - triggerTime) < 300
            }
            return false
        }
        
        if activationQueue.count > 5 {
            activationQueue = Array(activationQueue.suffix(5))
        }
        
        suite.set(activationQueue, forKey: "extension_activation_queue")
        suite.set(Date().timeIntervalSince1970, forKey: "extension_queue_updated_at")
        suite.synchronize()
        
        print("📋 [DeviceActivity] Session added to queue. Total queued: \(activationQueue.count)")
    }

    // MARK: - DEPRECATED: Old Manual Block Management

    @available(*, deprecated, message: "Use DeviceActivityCenter.startMonitoring from the app instead")
    private func processBlockRequests() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [MONITOR] Cannot access App Group")
            return
        }

        guard let tokenData = suite.data(forKey: "pending_block_tokenData"),
              let appName = suite.string(forKey: "pending_block_appName"),
              let duration = suite.object(forKey: "pending_block_duration") as? TimeInterval,
              let storeName = suite.string(forKey: "pending_block_storeName"),
              let blockId = suite.string(forKey: "pending_block_id") else {
            return
        }

        print("📨 [MONITOR] Processing block request: \(appName)")

        suite.removeObject(forKey: "pending_block_tokenData")
        suite.removeObject(forKey: "pending_block_appName")
        suite.removeObject(forKey: "pending_block_duration")
        suite.removeObject(forKey: "pending_block_storeName")
        suite.removeObject(forKey: "pending_block_id")
        suite.removeObject(forKey: "pending_block_timestamp")
        suite.synchronize()

        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [MONITOR] Failed to decode token")
            return
        }

        print("✅ [MONITOR] Token decoded successfully")

        let store = ManagedSettingsStore(named: .init(storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(token)
        store.shield.applications = blockedApps

        print("🛡️ [MONITOR] App blocked: \(appName)")

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

        scheduleAutoUnblock(blockId: blockId, storeName: storeName, duration: duration, appName: appName)
    }

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

    private func loadBlocksFromAppGroup() -> [ActiveBlock] {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
              let data = suite.data(forKey: "active_blocks_v2"),
              let blocks = try? JSONDecoder().decode([ActiveBlock].self, from: data) else {
            return []
        }
        return blocks
    }

    private func scheduleAutoUnblock(blockId: String, storeName: String, duration: TimeInterval, appName: String) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let unblockTime = Date().timeIntervalSince1970 + duration

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
                print("🔓 [MONITOR] Auto-unblocking: \(appName)")

                let store = ManagedSettingsStore(named: .init(storeName))
                store.shield.applications = nil
                store.clearAllSettings()

                removeBlockFromAppGroup(blockId: blockId)

                print("✅ [MONITOR] Auto-unblock complete: \(appName)")
            } else {
                remainingUnblocks.append(unblockInfo)
            }
        }

        suite.set(remainingUnblocks, forKey: "scheduled_unblocks")
        suite.synchronize()
    }

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