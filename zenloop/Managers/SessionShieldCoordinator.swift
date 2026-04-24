//
//  SessionShieldCoordinator.swift
//  zenloop
//
//  Single source of truth for session-originated shield state.
//  - Owns a per-session token registry persisted to UserDefaults.
//  - Recomputes the applied shield as the UNION of all active sessions.
//  - Handles pause (remove from active union) and resume (re-add).
//  - Removes a session cleanly on stop/leave/dissolve without nuking tokens
//    still owned by another concurrent session.
//

import Foundation
import FamilyControls
import ManagedSettings
import os

@MainActor
final class SessionShieldCoordinator {
    static let shared = SessionShieldCoordinator()

    private let logger = Logger(subsystem: "com.app.zenloop", category: "SessionShieldCoordinator")
    private let store = ManagedSettingsStore()
    private let registryKey = "session_shield_registry_v1"

    struct Entry: Codable {
        let sessionId: String
        let tokenData: Data      // Encoded FamilyActivitySelection
        var isPaused: Bool
        var updatedAt: Date
    }

    private init() {}

    // MARK: - Public API

    /// Register/refresh a session's selection and apply it to the shield.
    /// Safe to call repeatedly with the same selection (idempotent).
    func apply(sessionId: String, tokenData: Data) {
        var registry = loadRegistry()
        let existing = registry[sessionId]

        if let existing = existing, existing.tokenData == tokenData, existing.isPaused == false {
            logger.info("⏭️ [SHIELD_COORD] apply(\(sessionId)) no-op (same tokens, not paused)")
            return
        }

        registry[sessionId] = Entry(sessionId: sessionId, tokenData: tokenData, isPaused: false, updatedAt: Date())
        saveRegistry(registry)
        recomputeShield(registry: registry)
        logger.critical("➕ [SHIELD_COORD] Applied session \(sessionId) — \(registry.count) registered")
    }

    /// Mark a session as paused — its tokens are removed from the active union
    /// but kept in the registry so resume() can re-apply them.
    func pause(sessionId: String) {
        var registry = loadRegistry()
        guard var entry = registry[sessionId] else {
            logger.warning("⚠️ [SHIELD_COORD] pause(\(sessionId)) — not in registry")
            return
        }
        if entry.isPaused {
            logger.info("⏭️ [SHIELD_COORD] pause(\(sessionId)) — already paused")
            return
        }
        entry.isPaused = true
        entry.updatedAt = Date()
        registry[sessionId] = entry
        saveRegistry(registry)
        recomputeShield(registry: registry)
        logger.critical("⏸️ [SHIELD_COORD] Paused session \(sessionId)")
    }

    /// Mark a paused session as active again.
    func resume(sessionId: String) {
        var registry = loadRegistry()
        guard var entry = registry[sessionId] else {
            logger.warning("⚠️ [SHIELD_COORD] resume(\(sessionId)) — not in registry")
            return
        }
        if !entry.isPaused {
            logger.info("⏭️ [SHIELD_COORD] resume(\(sessionId)) — already active")
            return
        }
        entry.isPaused = false
        entry.updatedAt = Date()
        registry[sessionId] = entry
        saveRegistry(registry)
        recomputeShield(registry: registry)
        logger.critical("▶️ [SHIELD_COORD] Resumed session \(sessionId)")
    }

    /// Remove a session from the registry entirely (stop / leave / dissolve).
    /// The shield union is recomputed — tokens still owned by another session stay blocked.
    func remove(sessionId: String) {
        var registry = loadRegistry()
        guard registry.removeValue(forKey: sessionId) != nil else {
            logger.info("⏭️ [SHIELD_COORD] remove(\(sessionId)) — not in registry")
            return
        }
        saveRegistry(registry)
        recomputeShield(registry: registry)
        logger.critical("🗑️ [SHIELD_COORD] Removed session \(sessionId) — \(registry.count) remaining")
    }

    /// Returns the current state of a session in the registry (for diagnostics / UI).
    func state(sessionId: String) -> (registered: Bool, paused: Bool) {
        let registry = loadRegistry()
        guard let e = registry[sessionId] else { return (false, false) }
        return (true, e.isPaused)
    }

    /// Verify the actually-applied shield. Returns (apps, categories).
    func verifyApplied() -> (apps: Int, categories: Int) {
        #if os(iOS)
        let apps = store.shield.applications?.count ?? 0
        var categories = 0
        if let c = store.shield.applicationCategories,
           case .specific(let tokens, except: _) = c {
            categories = tokens.count
        }
        return (apps, categories)
        #else
        return (0, 0)
        #endif
    }

    // MARK: - Internals

    private func loadRegistry() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: registryKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveRegistry(_ registry: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        UserDefaults.standard.set(data, forKey: registryKey)
    }

    /// Recomputes the shield as the UNION of all non-paused sessions.
    /// Writes directly to the default ManagedSettingsStore so persistence works.
    private func recomputeShield(registry: [String: Entry]) {
        #if os(iOS)
        var unionApps: Set<ApplicationToken> = []
        var unionCategories: Set<ActivityCategoryToken> = []

        for entry in registry.values where entry.isPaused == false {
            guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: entry.tokenData) else {
                logger.error("❌ [SHIELD_COORD] Failed to decode selection for \(entry.sessionId)")
                continue
            }
            unionApps.formUnion(selection.applicationTokens)
            unionCategories.formUnion(selection.categoryTokens)
        }

        // Apps
        if unionApps.isEmpty {
            store.shield.applications = nil
        } else {
            store.shield.applications = unionApps
        }

        // Categories
        if unionCategories.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(unionCategories)
        }

        // Verify
        let applied = verifyApplied()
        logger.critical("🛡️ [SHIELD_COORD] Shield recomputed — \(applied.apps) apps + \(applied.categories) categories from \(registry.filter { !$0.value.isPaused }.count) active sessions")
        #endif
    }
}
