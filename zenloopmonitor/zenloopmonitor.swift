//
//  zenloopmonitor.swift
//  zenloopmonitor
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//
//  Fixed on 06/04/2026:
//  - Bug 7: activateSessionInMainApp now handles "scheduled_" prefix (not just "scheduled_session_")
//  - Cleaned up duplicate print/logger calls
//  - Better payload fallback for scheduled_ sessions

import DeviceActivity
import Foundation
import UserNotifications
import ManagedSettings
import FamilyControls
import os.log

// MARK: - Shared Models

enum RestrictionMode: String, Codable {
    case shield
    case hide
}

struct SelectionPayload: Codable {
    let sessionId: String
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
    let restrictionMode: RestrictionMode?
}

struct SessionInfo: Codable {
    let sessionId: String
    let title: String
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let createdAt: Date
}

struct ScheduledSessionInfo: Codable {
    let sessionId: String
    let startTime: Date
    let endTime: Date
    var status: ScheduledSessionStatus
    var actualStartTime: Date?
    var actualEndTime: Date?
}

enum ScheduledSessionStatus: String, Codable {
    case scheduled
    case started
    case completed
    case cancelled
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
    
    private let logger = Logger(subsystem: "com.app.zenloop.monitor", category: "Monitor")

    override init() {
        super.init()

        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "extension_initialized_timestamp")
        suite?.set("ZenloopDeviceActivityMonitor initialized", forKey: "extension_status")
        suite?.synchronize()

        logger.info("🚀 [MONITOR] Extension initialized")
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        logger.critical("🚀 [MONITOR] ===== INTERVAL STARTED: \(activity.rawValue) =====")

        // Appliquer le shield (cherche payload_<activity.rawValue> dans App Group)
        applyShield(for: activity)

        // Router selon le type d'activité
        if activity.rawValue.hasPrefix("block-") {
            logger.info("📱 [MONITOR] Block activity started")
            handleBlockActivity(activity)
        } else if activity.rawValue.hasPrefix("scheduled_session_") {
            // Session sociale programmée
            logger.info("⏰ [MONITOR] Scheduled social session started")
            activateScheduledSocialSession(for: activity)
        } else if activity.rawValue.hasPrefix("active_session_") {
            // Session active avec durée — monitoring de fin
            logger.info("⏰ [MONITOR] Active session end monitoring started")
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // FIX Bug 7: Sessions programmées via BlockScheduler (préfixe "scheduled_{UUID}")
            // Ces sessions n'ont PAS le préfixe "scheduled_session_" mais doivent quand même
            // être signalées à l'app principale pour activation
            logger.critical("⏰ [MONITOR] Scheduled challenge started (BlockScheduler): \(activity.rawValue)")
            activateBlockSchedulerSession(for: activity)
        }

        notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)
        logger.critical("✅ [MONITOR] Shield applied, interval active")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        logger.critical("🔓 [MONITOR] ===== INTERVAL ENDED: \(activity.rawValue) =====")

        // Log to App Group for visibility
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "last_intervalDidEnd_timestamp")
        suite?.set(activity.rawValue, forKey: "last_intervalDidEnd_activity")
        suite?.synchronize()

        // Retirer le shield
        removeShield(for: activity)

        // Router selon le type d'activité
        if activity.rawValue.hasPrefix("block-") {
            handleBlockActivityEnd(activity)
            removeFromDefaultStore(for: activity)
        } else if activity.rawValue.hasPrefix("scheduled_session_") {
            handleScheduledSessionEnd(activity)
            cleanupScheduledSessionPayload(for: activity)
        } else if activity.rawValue.hasPrefix("active_session_") {
            handleActiveSessionEnd(activity)
            cleanupActiveSessionPayload(for: activity)
        } else if activity.rawValue.hasPrefix("scheduled_") {
            // FIX Bug 7: Nettoyer les sessions BlockScheduler
            stopMonitoringIfSingleSession(activity: activity)
            saveChallengeCompletion(activityName: activity)
            cleanupBlockSchedulerSessionPayload(for: activity)
        } else {
            logger.warning("⚠️ [MONITOR] Unknown activity type: \(activity.rawValue)")
        }

        notifyMainApp(event: "intervalDidEnd", activity: activity.rawValue)
        logger.critical("✅ [MONITOR] Interval end complete — app should be unblocked")
    }
    
    private func stopMonitoringIfSingleSession(activity: DeviceActivityName) {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        if activity.rawValue.hasPrefix("scheduled_") {
            suite?.set(true, forKey: "stop_monitoring_\(activity.rawValue)")
            suite?.synchronize()
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.info("⚠️ [MONITOR] Threshold reached: \(event.rawValue) for \(activity.rawValue)")
        notifyMainApp(event: "thresholdReached", activity: activity.rawValue, eventName: event.rawValue)
    }
    
    // MARK: - Shield Management
    
    private func applyShield(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.error("❌ [MONITOR] Cannot access App Group")
            return
        }

        let expectedKey = "payload_\(activity.rawValue)"

        // Décoder le payload
        guard let data = suite.data(forKey: expectedKey) else {
            logger.warning("⚠️ [MONITOR] No payload for key: \(expectedKey)")

            // Fallback pour sessions sociales programmées
            if activity.rawValue.hasPrefix("scheduled_session_") {
                let sessionId = String(activity.rawValue.dropFirst("scheduled_session_".count))
                let appsKey = "scheduled_session_apps_\(sessionId)"

                if let selectionData = suite.data(forKey: appsKey),
                   let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                    logger.info("✅ [MONITOR] Fallback: Found FamilyActivitySelection for social session")
                    applyShieldFromSelection(selection, activityName: activity.rawValue)
                    return
                }
            }
            return
        }

        guard let payload = try? JSONDecoder().decode(SelectionPayload.self, from: data) else {
            logger.error("❌ [MONITOR] Failed to decode payload")
            return
        }

        let mode = payload.restrictionMode ?? .shield
        logger.info("🛡️ [MONITOR] Applying \(mode.rawValue) — \(payload.apps.count) apps, \(payload.categories.count) categories")

        // FIX 2: Utiliser le DEFAULT store pour les sessions programmées
        // Les named stores sont ÉPHÉMÈRES — ils disparaissent si le process Monitor est recyclé par iOS.
        // Le DEFAULT store persiste automatiquement entre les lancements.
        // Pour les block- individuels, on garde le named store (ils ont leur propre cleanup).
        let store: ManagedSettingsStore
        if activity.rawValue.hasPrefix("block-") {
            store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        } else {
            store = ManagedSettingsStore()  // DEFAULT — persiste toujours
        }

        logger.info("📦 [MONITOR] Using store: \(activity.rawValue.hasPrefix("block-") ? "named(\(activity.rawValue))" : "DEFAULT")")

        switch mode {
        case .shield:
            if !payload.apps.isEmpty {
                // FIX 2: Pour le DEFAULT store, MERGER avec les apps existantes (pas écraser)
                if activity.rawValue.hasPrefix("block-") {
                    store.shield.applications = Set(payload.apps)
                } else {
                    var existingApps = store.shield.applications ?? Set()
                    existingApps.formUnion(Set(payload.apps))
                    store.shield.applications = existingApps
                }
            }
            if !payload.categories.isEmpty {
                store.shield.applicationCategories = .specific(Set(payload.categories))
            }

        case .hide:
            if !payload.apps.isEmpty {
                let blockedApps: Set<Application> = Set(payload.apps.map { Application(token: $0) })
                if activity.rawValue.hasPrefix("block-") {
                    store.application.blockedApplications = blockedApps
                } else {
                    var existingBlocked = store.application.blockedApplications ?? Set()
                    existingBlocked.formUnion(blockedApps)
                    store.application.blockedApplications = existingBlocked
                }
            }
            if !payload.categories.isEmpty {
                store.shield.applicationCategories = .specific(Set(payload.categories))
            }
        }

        // Sauvegarder quels tokens appartiennent à cette session (pour removeShield)
        if !activity.rawValue.hasPrefix("block-") {
            suite.set(data, forKey: "active_shield_\(activity.rawValue)")
            suite.synchronize()
        }

        logger.info("✅ [MONITOR] Shield applied for \(activity.rawValue)")
    }

    private func applyShieldFromSelection(_ selection: FamilyActivitySelection, activityName: String) {
        // FIX 2: DEFAULT store pour sessions programmées
        let store: ManagedSettingsStore
        if activityName.hasPrefix("block-") {
            store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activityName))
        } else {
            store = ManagedSettingsStore()
        }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
    }

    private func removeShield(for activity: DeviceActivityName) {
        if activity.rawValue.hasPrefix("block-") {
            // Block individuel : nettoyer le named store entier
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.application.blockedApplications = nil
            logger.info("🔓 [MONITOR] Named store cleared for \(activity.rawValue)")
        } else {
            // Session programmée : retirer SEULEMENT les tokens de cette session du DEFAULT store
            let defaultStore = ManagedSettingsStore()
            let suite = UserDefaults(suiteName: "group.com.app.zenloop")

            // Récupérer les tokens sauvés pour cette session
            if let savedData = suite?.data(forKey: "active_shield_\(activity.rawValue)"),
               let payload = try? JSONDecoder().decode(SelectionPayload.self, from: savedData) {

                let mode = payload.restrictionMode ?? .shield

                switch mode {
                case .shield:
                    if !payload.apps.isEmpty {
                        var currentApps = defaultStore.shield.applications ?? Set()
                        for token in payload.apps {
                            currentApps.remove(token)
                        }
                        defaultStore.shield.applications = currentApps.isEmpty ? nil : currentApps
                    }
                    if !payload.categories.isEmpty {
                        // Pour les catégories, on ne peut pas facilement "retirer" — on nil si c'est la seule session
                        defaultStore.shield.applicationCategories = nil
                    }

                case .hide:
                    if !payload.apps.isEmpty {
                        var currentBlocked = defaultStore.application.blockedApplications ?? Set()
                        for token in payload.apps {
                            currentBlocked.remove(Application(token: token))
                        }
                        defaultStore.application.blockedApplications = currentBlocked.isEmpty ? nil : currentBlocked
                    }
                    if !payload.categories.isEmpty {
                        defaultStore.shield.applicationCategories = nil
                    }
                }

                logger.info("🔓 [MONITOR] Removed \(payload.apps.count) apps from DEFAULT store for \(activity.rawValue)")
            } else {
                // Fallback : pas de données sauvées, nettoyer tout le DEFAULT store
                logger.warning("⚠️ [MONITOR] No saved shield data — clearing entire DEFAULT store")
                defaultStore.shield.applications = nil
                defaultStore.shield.applicationCategories = nil
                defaultStore.application.blockedApplications = nil
            }

            // Nettoyer les données sauvées
            suite?.removeObject(forKey: "active_shield_\(activity.rawValue)")
            suite?.synchronize()

            logger.info("🔓 [MONITOR] Restrictions removed for \(activity.rawValue)")
        }
    }

    private func removeFromDefaultStore(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let activityName = activity.rawValue
        let mappingKey = "blockId_for_activity_\(activityName)"

        guard let blockId = suite.string(forKey: mappingKey) else {
            logger.warning("⚠️ [MONITOR] No mapping found for activity: \(activityName)")
            return
        }

        var blocks = loadBlocksFromAppGroup()

        guard let block = blocks.first(where: { $0.id == blockId }) else {
            logger.warning("⚠️ [MONITOR] Block not found: \(blockId)")
            return
        }

        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
              let token = selection.applicationTokens.first else {
            logger.error("❌ [MONITOR] Failed to decode token for block: \(blockId)")
            return
        }

        let defaultStore = ManagedSettingsStore()
        var blockedApps = defaultStore.shield.applications ?? Set()
        blockedApps.remove(token)
        defaultStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps

        logger.info("🔓 [MONITOR] Removed from DEFAULT store: \(block.appName)")

        suite.removeObject(forKey: mappingKey)
        suite.synchronize()
    }

    // MARK: - Session Payload Cleanup

    private func cleanupActiveSessionPayload(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = String(activity.rawValue.dropFirst("active_session_".count))
        suite.removeObject(forKey: "payload_active_session_\(sessionId)")
        suite.removeObject(forKey: "active_session_\(sessionId)")

        var activeEndMonitors = suite.stringArray(forKey: "active_end_monitors") ?? []
        activeEndMonitors.removeAll { $0 == sessionId }
        suite.set(activeEndMonitors, forKey: "active_end_monitors")
        suite.synchronize()
    }

    private func cleanupScheduledSessionPayload(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let activityName = activity.rawValue
        suite.removeObject(forKey: "payload_\(activityName)")

        if activityName.hasPrefix("scheduled_session_") {
            let sessionId = String(activityName.dropFirst("scheduled_session_".count))
            suite.removeObject(forKey: "scheduled_session_apps_\(sessionId)")

            var activeSchedules = suite.stringArray(forKey: "active_scheduled_sessions") ?? []
            activeSchedules.removeAll { $0 == sessionId }
            suite.set(activeSchedules, forKey: "active_scheduled_sessions")
        }
        suite.synchronize()
    }

    // FIX Bug 7: Cleanup pour sessions BlockScheduler (préfixe "scheduled_{UUID}")
    private func cleanupBlockSchedulerSessionPayload(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = activity.rawValue
        suite.removeObject(forKey: "payload_\(sessionId)")
        suite.removeObject(forKey: "session_info_\(sessionId)")
        suite.removeObject(forKey: "activation_info_\(sessionId)")
        suite.synchronize()

        logger.info("🧹 [MONITOR] Cleaned up BlockScheduler session: \(sessionId)")
    }
    
    // MARK: - Helper Methods
    
    private func saveChallengeCompletion(activityName: DeviceActivityName) {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        var completedChallenges = userDefaults?.array(forKey: "completedChallengeIds") as? [String] ?? []
        completedChallenges.append(activityName.rawValue)
        
        userDefaults?.set(completedChallenges, forKey: "completedChallengeIds")
        userDefaults?.set(Date(), forKey: "lastChallengeCompletedDate")
    }
    
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
    }
    
    // MARK: - Block Activity Management

    private func handleBlockActivity(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let blockId = String(activity.rawValue.dropFirst("block-".count))

        guard let blockInfoDict = suite.dictionary(forKey: "block_info_\(blockId)"),
              let appName = blockInfoDict["appName"] as? String,
              let duration = blockInfoDict["duration"] as? TimeInterval,
              let tokenData = blockInfoDict["tokenData"] as? Data else {
            logger.warning("⚠️ [MONITOR] No block info for \(blockId)")
            return
        }

        let activeBlock = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: activity.rawValue,
            duration: duration,
            tokenData: tokenData,
            status: .active
        )

        saveBlockToAppGroup(activeBlock)
        logger.info("💾 [MONITOR] Block saved: \(appName)")
    }

    private func handleBlockActivityEnd(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let blockId = String(activity.rawValue.dropFirst("block-".count))

        if let blockInfoDict = suite.dictionary(forKey: "block_info_\(blockId)"),
           let blockManagerId = blockInfoDict["blockId"] as? String {
            removeBlockFromAppGroup(blockId: blockManagerId)
        }

        suite.removeObject(forKey: "storeName_\(blockId)")
        suite.removeObject(forKey: "block_info_\(blockId)")
        suite.removeObject(forKey: "payload_\(activity.rawValue)")
        suite.synchronize()
    }

    // MARK: - Session Activation

    /// Sessions sociales programmées (préfixe "scheduled_session_")
    private func activateScheduledSocialSession(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = String(activity.rawValue.dropFirst("scheduled_session_".count))
        logger.critical("🚀 [MONITOR] Auto-starting scheduled social session: \(sessionId)")

        if let infoData = suite.data(forKey: "scheduled_session_\(sessionId)"),
           var info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: infoData) {

            let now = Date()
            guard now >= info.startTime.addingTimeInterval(-60) else {
                logger.warning("⚠️ [MONITOR] Too early for session \(sessionId)")
                return
            }

            info.status = .started
            info.actualStartTime = now

            if let data = try? JSONEncoder().encode(info) {
                suite.set(data, forKey: "scheduled_session_\(sessionId)")
            }
        }

        suite.set(sessionId, forKey: "auto_start_session_id")
        suite.set(Date().timeIntervalSince1970, forKey: "auto_start_session_timestamp")
        suite.synchronize()

        logger.critical("🔥 [MONITOR] Social session auto-start triggered: \(sessionId)")
    }

    /// FIX Bug 7: Sessions BlockScheduler (préfixe "scheduled_{UUID}")
    /// Ces sessions sont créées par BlockScheduler et n'ont PAS le préfixe "scheduled_session_"
    /// Mais elles doivent quand même signaler à l'app principale de démarrer
    private func activateBlockSchedulerSession(for activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = activity.rawValue  // "scheduled_{UUID}"
        logger.critical("🚀 [MONITOR] Auto-starting BlockScheduler session: \(sessionId)")

        // Récupérer les infos de session depuis activation_info (sauvé par BlockScheduler)
        if let activationInfo = suite.dictionary(forKey: "activation_info_\(sessionId)") {
            let title = activationInfo["title"] as? String ?? "Session programmée"
            let duration = activationInfo["duration"] as? TimeInterval ?? 0
            let startTimeInterval = activationInfo["startTime"] as? TimeInterval ?? Date().timeIntervalSince1970

            logger.info("✅ [MONITOR] Session info found: \(title), \(Int(duration/60))min")

            // Ajouter à la queue d'activation pour l'app principale
            let activationId = UUID().uuidString
            let sessionData: [String: Any] = [
                "id": sessionId,
                "title": title,
                "duration": duration,
                "startTime": startTimeInterval,
                "activationId": activationId,
                "isScheduled": true,
                "extensionTriggeredAt": Date().timeIntervalSince1970
            ]

            addSessionToActivationQueue(session: sessionData, activationId: activationId, suite: suite)

            logger.critical("🔥 [MONITOR] BlockScheduler session queued for main app: \(sessionId)")
        } else {
            // Fallback: essayer session_info
            if let sessionData = suite.data(forKey: "session_info_\(sessionId)"),
               let sessionInfo = try? JSONDecoder().decode(SessionInfo.self, from: sessionData) {

                logger.info("✅ [MONITOR] Fallback: Found SessionInfo for \(sessionId)")

                let activationId = UUID().uuidString
                let sessionActivation: [String: Any] = [
                    "id": sessionId,
                    "title": sessionInfo.title,
                    "duration": sessionInfo.duration,
                    "startTime": sessionInfo.startTime.timeIntervalSince1970,
                    "activationId": activationId,
                    "isScheduled": true,
                    "extensionTriggeredAt": Date().timeIntervalSince1970
                ]

                addSessionToActivationQueue(session: sessionActivation, activationId: activationId, suite: suite)

                logger.critical("🔥 [MONITOR] BlockScheduler session (fallback) queued: \(sessionId)")
            } else {
                logger.error("❌ [MONITOR] No activation info found for \(sessionId) — session cannot be started")
                logger.error("   Keys tried: activation_info_\(sessionId), session_info_\(sessionId)")
            }
        }
    }

    /// Arrête automatiquement une session active avec durée
    private func handleActiveSessionEnd(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = String(activity.rawValue.dropFirst("active_session_".count))
        logger.critical("🛑 [MONITOR] Auto-stopping active session: \(sessionId)")

        if let infoData = suite.data(forKey: "active_session_\(sessionId)"),
           var info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: infoData) {
            info.status = .completed
            info.actualEndTime = Date()
            if let data = try? JSONEncoder().encode(info) {
                suite.set(data, forKey: "active_session_\(sessionId)")
            }
        }

        suite.set(sessionId, forKey: "auto_stop_session_id")
        suite.set(Date().timeIntervalSince1970, forKey: "auto_stop_session_timestamp")
        suite.synchronize()
    }

    /// Arrête automatiquement une session sociale programmée
    private func handleScheduledSessionEnd(_ activity: DeviceActivityName) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let sessionId = String(activity.rawValue.dropFirst("scheduled_session_".count))
        logger.critical("🛑 [MONITOR] Auto-stopping scheduled session: \(sessionId)")

        if let infoData = suite.data(forKey: "scheduled_session_\(sessionId)"),
           var info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: infoData) {
            info.status = .completed
            info.actualEndTime = Date()
            if let data = try? JSONEncoder().encode(info) {
                suite.set(data, forKey: "scheduled_session_\(sessionId)")
            }
        }

        suite.set(sessionId, forKey: "auto_stop_session_id")
        suite.set(Date().timeIntervalSince1970, forKey: "auto_stop_session_timestamp")
        suite.synchronize()
    }

    private func addSessionToActivationQueue(session: [String: Any], activationId: String, suite: UserDefaults) {
        var activationQueue = suite.array(forKey: "extension_activation_queue") as? [[String: Any]] ?? []
        activationQueue.append(session)
        
        // Nettoyer les entrées expirées (> 5 min)
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
    }

    // MARK: - Block Storage

    private func saveBlockToAppGroup(_ block: ActiveBlock) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        var blocks = loadBlocksFromAppGroup()
        blocks.append(block)

        if let data = try? JSONEncoder().encode(blocks) {
            suite.set(data, forKey: "active_blocks_v2")
            suite.synchronize()
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

    private func removeBlockFromAppGroup(blockId: String) {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        var blocks = loadBlocksFromAppGroup()
        blocks.removeAll { $0.id == blockId }

        if let data = try? JSONEncoder().encode(blocks) {
            suite.set(data, forKey: "active_blocks_v2")
            suite.synchronize()
        }
    }
}