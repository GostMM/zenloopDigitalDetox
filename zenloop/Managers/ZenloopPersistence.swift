//  ZenloopPersistence.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import FamilyControls
import os

// MARK: - Persistence Management

protocol ZenloopPersistenceDelegate: AnyObject {
    func dataDidLoad()
    func dataDidSave()
    func loadingError(_ error: Error)
}

@MainActor
final class ZenloopPersistence: ObservableObject {
    
    // MARK: - Private Properties
    private var persistWorkItem: DispatchWorkItem?
    private var activityPersistWorkItem: DispatchWorkItem?
    
    weak var delegate: ZenloopPersistenceDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "Persistence")
    #endif
    
    // MARK: - Constants
    private struct Keys {
        static let currentState = "zenloop_current_state"
        static let currentChallenge = "zenloop_current_challenge"
        static let recentActivity = "zenloop_recent_activity"
        static let scheduledChallenges = "scheduled_challenges"
        static let appsSelection = "zenloop_apps_selection"
        static let selectedAppsCount = "zenloop_selected_apps_count"
    }
    
    // MARK: - Current State Persistence
    
    func persistCurrentStateNow(state: ZenloopState, challenge: ZenloopChallenge?) {
        _persistCurrentState(state: state, challenge: challenge)
        #if DEBUG
        logger.debug("💾 [Persistence] Current state persisted immediately")
        #endif
    }
    
    func persistCurrentStateDebounced(state: ZenloopState, challenge: ZenloopChallenge?) {
        persistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?._persistCurrentState(state: state, challenge: challenge)
        }
        persistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
        
        #if DEBUG
        logger.debug("⏰ [Persistence] Current state persistence scheduled (debounced)")
        #endif
    }
    
    private func _persistCurrentState(state: ZenloopState, challenge: ZenloopChallenge?) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(state.rawValue, forKey: Keys.currentState)
        
        if let challenge = challenge, let data = try? JSONEncoder().encode(challenge) {
            userDefaults.set(data, forKey: Keys.currentChallenge)
        } else {
            userDefaults.removeObject(forKey: Keys.currentChallenge)
        }
        
        delegate?.dataDidSave()
    }
    
    func loadPersistedState() -> (state: ZenloopState, challenge: ZenloopChallenge?) {
        let userDefaults = UserDefaults.standard
        
        var state: ZenloopState = .idle
        if let stateString = userDefaults.string(forKey: Keys.currentState),
           let persistedState = ZenloopState(rawValue: stateString) {
            state = persistedState
        }
        
        var challenge: ZenloopChallenge?
        if let data = userDefaults.data(forKey: Keys.currentChallenge),
           let persistedChallenge = try? JSONDecoder().decode(ZenloopChallenge.self, from: data) {
            challenge = persistedChallenge
        }
        
        #if DEBUG
        logger.debug("📥 [Persistence] State loaded: \(state.rawValue), challenge: \(challenge?.id ?? "none")")
        #endif
        
        delegate?.dataDidLoad()
        return (state: state, challenge: challenge)
    }
    
    // MARK: - Activity Records Persistence
    
    func persistRecentActivity(_ activities: [ActivityRecord]) {
        saveRecentActivityDebounced(activities)
    }
    
    private func saveRecentActivityDebounced(_ activities: [ActivityRecord]) {
        activityPersistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(activities)
                UserDefaults.standard.set(data, forKey: Keys.recentActivity)
                self.delegate?.dataDidSave()
                #if DEBUG
                self.logger.debug("💾 [Persistence] Recent activity saved: \(activities.count) items")
                #endif
            } catch {
                #if DEBUG
                self.logger.error("❌ [Persistence] Failed to save activity: \(error.localizedDescription)")
                #endif
                self.delegate?.loadingError(error)
            }
        }
        activityPersistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }
    
    func loadRecentActivity() -> [ActivityRecord] {
        if let data = UserDefaults.standard.data(forKey: Keys.recentActivity),
           let activities = try? JSONDecoder().decode([ActivityRecord].self, from: data) {
            #if DEBUG
            logger.debug("📥 [Persistence] Recent activity loaded: \(activities.count) items")
            #endif
            delegate?.dataDidLoad()
            return activities
        }
        
        #if DEBUG
        logger.debug("📥 [Persistence] No recent activity found")
        #endif
        return []
    }
    
    func addActivityRecord(_ record: ActivityRecord, to activities: inout [ActivityRecord]) {
        activities.insert(record, at: 0)
        if activities.count > 20 {
            activities = Array(activities.prefix(20))
        }
        persistRecentActivity(activities)
        
        #if DEBUG
        logger.debug("📝 [Persistence] Activity record added: \(record.type.rawValue)")
        #endif
    }
    
    // MARK: - Scheduled Challenges Persistence
    
    func saveScheduledChallenge(_ challenge: ZenloopChallenge, apps: FamilyActivitySelection) {
        var scheduledChallenges = getScheduledChallenges()
        scheduledChallenges[challenge.id] = challenge
        
        if let encoded = try? JSONEncoder().encode(scheduledChallenges) {
            UserDefaults.standard.set(encoded, forKey: Keys.scheduledChallenges)
            #if DEBUG
            logger.debug("💾 [Persistence] Scheduled challenge saved: \(challenge.id)")
            #endif
        } else {
            #if DEBUG
            logger.error("❌ [Persistence] Failed to encode scheduled challenge")
            #endif
        }
    }
    
    func getScheduledChallenges() -> [String: ZenloopChallenge] {
        guard let data = UserDefaults.standard.data(forKey: Keys.scheduledChallenges),
              let challenges = try? JSONDecoder().decode([String: ZenloopChallenge].self, from: data) else {
            return [:]
        }
        
        #if DEBUG
        logger.debug("📥 [Persistence] Scheduled challenges loaded: \(challenges.count) items")
        #endif
        return challenges
    }
    
    func removeScheduledChallenge(_ challengeId: String) {
        var scheduledChallenges = getScheduledChallenges()
        scheduledChallenges.removeValue(forKey: challengeId)
        
        if let encoded = try? JSONEncoder().encode(scheduledChallenges) {
            UserDefaults.standard.set(encoded, forKey: Keys.scheduledChallenges)
            #if DEBUG
            logger.debug("🗑️ [Persistence] Scheduled challenge removed: \(challengeId)")
            #endif
        }
    }
    
    // MARK: - App Selection Persistence
    
    func persistAppsSelection(_ selection: FamilyActivitySelection, count: Int) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(selection)
            UserDefaults.standard.set(data, forKey: Keys.appsSelection)
            UserDefaults.standard.set(count, forKey: Keys.selectedAppsCount)
            #if DEBUG
            logger.debug("💾 [Persistence] Apps selection saved: \(count) items")
            #endif
        } catch {
            UserDefaults.standard.set(count, forKey: Keys.selectedAppsCount)
            #if DEBUG
            logger.error("❌ [Persistence] Failed to save apps selection: \(error.localizedDescription)")
            #endif
        }
    }
    
    func loadAppsSelection() -> (selection: FamilyActivitySelection, count: Int) {
        if let data = UserDefaults.standard.data(forKey: Keys.appsSelection) {
            do {
                let decoder = JSONDecoder()
                let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
                let count = selection.applicationTokens.count + selection.categoryTokens.count
                #if DEBUG
                logger.debug("📥 [Persistence] Apps selection loaded: \(count) items")
                #endif
                return (selection: selection, count: count)
            } catch {
                #if DEBUG
                logger.error("❌ [Persistence] Failed to load apps selection: \(error.localizedDescription)")
                #endif
                return (selection: FamilyActivitySelection(), count: 0)
            }
        } else {
            let count = UserDefaults.standard.integer(forKey: Keys.selectedAppsCount)
            if count > 0 {
                // Réinitialiser si pas de données valides
                UserDefaults.standard.set(0, forKey: Keys.selectedAppsCount)
                return (selection: FamilyActivitySelection(), count: 0)
            }
            return (selection: FamilyActivitySelection(), count: count)
        }
    }
    
    // MARK: - Generic UserDefaults Operations
    
    func setValue(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        #if DEBUG
        logger.debug("💾 [Persistence] Value saved for key: \(key)")
        #endif
    }
    
    func getValue(forKey key: String) -> Any? {
        return UserDefaults.standard.object(forKey: key)
    }
    
    func removeValue(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        #if DEBUG
        logger.debug("🗑️ [Persistence] Value removed for key: \(key)")
        #endif
    }
    
    // MARK: - Batch Operations
    
    func clearAllData() {
        let keys = [
            Keys.currentState,
            Keys.currentChallenge,
            Keys.recentActivity,
            Keys.scheduledChallenges,
            Keys.appsSelection,
            Keys.selectedAppsCount
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        #if DEBUG
        logger.debug("🧹 [Persistence] All Zenloop data cleared")
        #endif
    }
    
    func synchronize() {
        UserDefaults.standard.synchronize()
        #if DEBUG
        logger.debug("🔄 [Persistence] UserDefaults synchronized")
        #endif
    }
    
    // MARK: - Data Export/Import
    
    func exportAllData() -> [String: Any] {
        let keys = [
            Keys.currentState,
            Keys.currentChallenge,
            Keys.recentActivity,
            Keys.scheduledChallenges,
            Keys.appsSelection,
            Keys.selectedAppsCount
        ]
        
        var exportData: [String: Any] = [:]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                exportData[key] = value
            }
        }
        
        #if DEBUG
        logger.debug("📤 [Persistence] Data exported: \(exportData.keys.count) keys")
        #endif
        
        return exportData
    }
    
    func importData(_ data: [String: Any]) {
        for (key, value) in data {
            UserDefaults.standard.set(value, forKey: key)
        }
        synchronize()
        
        #if DEBUG
        logger.debug("📥 [Persistence] Data imported: \(data.keys.count) keys")
        #endif
    }
    
    // MARK: - Cleanup
    
    deinit {
        persistWorkItem?.cancel()
        activityPersistWorkItem?.cancel()
    }
}