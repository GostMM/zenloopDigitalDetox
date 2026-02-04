//
//  BlockSyncManager.swift
//  zenloop
//
//  Manager pour synchroniser les blocages au démarrage de l'app
//

import Foundation
import FamilyControls
import ManagedSettings
import os

private let syncLogger = Logger(subsystem: "com.app.zenloop", category: "BlockSync")

/// ✅ Manager qui restaure et synchronise les blocages d'apps au démarrage
class BlockSyncManager {
    static let shared = BlockSyncManager()

    private let blockManager = BlockManager()
    private var activeManagedStores: [String: ManagedSettingsStore] = [:]

    private init() {
        syncLogger.info("🔧 [SYNC] BlockSyncManager initialized")
    }

    // MARK: - Cleanup Legacy Blocks

    /// ✅ TEMPORAIRE: Nettoyer tous les blocs legacy sans token
    func cleanupLegacyBlocks() {
        syncLogger.critical("🧹 [SYNC] Cleaning up legacy blocks without tokens...")

        let blocks = blockManager.getAllBlocks()
        var cleanedCount = 0

        for block in blocks {
            if block.appTokenData.isEmpty {
                syncLogger.warning("  → Removing legacy block: \(block.appName)")
                blockManager.removeBlock(id: block.id)

                // Aussi nettoyer le ManagedSettingsStore
                #if os(iOS)
                let store = ManagedSettingsStore(named: .init(block.storeName))
                store.shield.applications = nil
                store.clearAllSettings()
                #endif

                cleanedCount += 1
            }
        }

        syncLogger.critical("✅ [SYNC] Cleaned \(cleanedCount) legacy blocks")
    }

    // MARK: - Restore All Blocks (Called on App Launch)

    /// ✅ Restaure tous les blocages au démarrage de l'app
    func restoreAllBlocks() {
        syncLogger.critical("🔄 [SYNC] === RESTORE ALL BLOCKS START ===")

        let blocks = blockManager.getAllBlocks()
        syncLogger.critical("📦 [SYNC] Found \(blocks.count) blocks in storage")

        guard !blocks.isEmpty else {
            syncLogger.critical("⚠️ [SYNC] No blocks to restore - storage is empty!")

            // Debug: Vérifier l'App Group
            if let suite = UserDefaults(suiteName: "group.com.app.zenloop") {
                let allKeys = Array(suite.dictionaryRepresentation().keys)
                syncLogger.critical("📊 [SYNC] App Group has \(allKeys.count) keys")
                for key in allKeys {
                    syncLogger.critical("  - \(key)")
                }
            } else {
                syncLogger.critical("❌ [SYNC] Cannot access App Group!")
            }
            return
        }

        for block in blocks {
            syncLogger.info("  → Block: \(block.appName) | Status: \(block.status.rawValue) | ID: \(block.id)")

            if block.isExpired {
                syncLogger.warning("⏰ [SYNC] Block expired: \(block.appName)")
                cleanupBlock(block)
            } else if block.status == .stopped {
                syncLogger.info("🛑 [SYNC] Block stopped: \(block.appName)")
                cleanupBlock(block)
            } else if block.status == .active || block.status == .paused {
                syncLogger.info("♻️ [SYNC] Restoring active block: \(block.appName)")
                restoreBlock(block)
            }
        }

        // Cleanup final des blocks supprimés
        blockManager.removeExpiredAndStoppedBlocks()

        syncLogger.critical("✅ [SYNC] === RESTORE ALL BLOCKS COMPLETE ===")
    }

    // MARK: - Restore Single Block

    private func restoreBlock(_ block: ActiveBlock) {
        #if os(iOS)
        guard let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot decode token for: \(block.appName)")
            // Token invalide → Nettoyer ce block
            cleanupBlock(block)
            return
        }

        syncLogger.info("🔓 [SYNC] Token decoded successfully for: \(block.appName)")

        // 1. Réinstancier le store
        let store = ManagedSettingsStore(named: .init(block.storeName))
        activeManagedStores[block.id] = store

        // 2. Vérifier si le blocage est toujours actif dans le store
        let currentBlocked = store.shield.applications ?? Set()

        if block.status == .active {
            if !currentBlocked.contains(token) {
                // ⚠️ Le token n'est plus bloqué → Le remettre
                syncLogger.warning("⚠️ [SYNC] Token not in store, re-blocking: \(block.appName)")

                var blockedApps = currentBlocked
                blockedApps.insert(token)
                store.shield.applications = blockedApps

                syncLogger.info("✅ [SYNC] Block re-applied: \(block.appName)")
            } else {
                syncLogger.info("✅ [SYNC] Block already active: \(block.appName)")
            }
        } else if block.status == .paused {
            // Si le block est en pause, s'assurer que le shield est désactivé
            syncLogger.info("⏸️ [SYNC] Block is paused: \(block.appName)")
            if !currentBlocked.isEmpty {
                store.shield.applications = nil
                syncLogger.info("  → Shield removed (paused)")
            }
        }
        #endif
    }

    // MARK: - Cleanup Block

    private func cleanupBlock(_ block: ActiveBlock) {
        #if os(iOS)
        syncLogger.info("🧹 [SYNC] Cleaning up block: \(block.appName)")

        // 1. Débloquer l'app
        let store = ManagedSettingsStore(named: .init(block.storeName))
        store.shield.applications = nil
        store.clearAllSettings()

        syncLogger.info("  → Shield cleared")

        // 2. Supprimer de nos données
        blockManager.removeBlock(id: block.id)
        activeManagedStores.removeValue(forKey: block.id)

        syncLogger.info("✅ [SYNC] Block cleaned: \(block.appName)")
        #endif
    }

    // MARK: - Manual Unblock

    /// ✅ Débloquer une app manuellement depuis l'UI
    func unblockApp(blockId: String) {
        syncLogger.info("🔓 [SYNC] Manual unblock requested: \(blockId)")

        guard let block = blockManager.getBlock(id: blockId) else {
            syncLogger.error("❌ [SYNC] Block not found: \(blockId)")
            return
        }

        cleanupBlock(block)

        // Notifier l'UI
        NotificationCenter.default.post(name: NSNotification.Name("ActiveBlocksDidChange"), object: nil)
    }

    // MARK: - Pause/Resume

    /// Mettre en pause un blocage
    func pauseBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId),
              let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot pause block: \(blockId)")
            return
        }

        syncLogger.info("⏸️ [SYNC] Pausing block: \(block.appName)")

        // 1. Mettre à jour le statut
        blockManager.updateBlockStatus(id: blockId, status: .paused)

        // 2. Retirer temporairement le shield
        if let store = activeManagedStores[blockId] {
            store.shield.applications = nil
            syncLogger.info("✅ [SYNC] Shield removed (paused)")
        } else {
            // Fallback: créer le store si pas en cache
            let store = ManagedSettingsStore(named: .init(block.storeName))
            store.shield.applications = nil
            activeManagedStores[blockId] = store
        }

        // Notifier l'UI
        NotificationCenter.default.post(name: NSNotification.Name("ActiveBlocksDidChange"), object: nil)
        #endif
    }

    /// Reprendre un blocage
    func resumeBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId),
              let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot resume block: \(blockId)")
            return
        }

        syncLogger.info("▶️ [SYNC] Resuming block: \(block.appName)")

        // 1. Mettre à jour le statut
        blockManager.updateBlockStatus(id: blockId, status: .active)

        // 2. Réappliquer le shield
        if let store = activeManagedStores[blockId] {
            var blockedApps = store.shield.applications ?? Set()
            blockedApps.insert(token)
            store.shield.applications = blockedApps
            syncLogger.info("✅ [SYNC] Shield re-applied (resumed)")
        } else {
            // Fallback: créer le store si pas en cache
            let store = ManagedSettingsStore(named: .init(block.storeName))
            var blockedApps = store.shield.applications ?? Set()
            blockedApps.insert(token)
            store.shield.applications = blockedApps
            activeManagedStores[blockId] = store
        }

        // Notifier l'UI
        NotificationCenter.default.post(name: NSNotification.Name("ActiveBlocksDidChange"), object: nil)
        #endif
    }

    // MARK: - Get Store

    /// Récupérer un store actif (pour modification)
    func getStore(for blockId: String) -> ManagedSettingsStore? {
        #if os(iOS)
        if let store = activeManagedStores[blockId] {
            return store
        }

        // Fallback: réinstancier si nécessaire
        if let block = blockManager.getBlock(id: blockId) {
            let store = ManagedSettingsStore(named: .init(block.storeName))
            activeManagedStores[blockId] = store
            return store
        }
        #endif

        return nil
    }

    // MARK: - Periodic Cleanup

    /// Vérifier et nettoyer les blocks expirés (à appeler périodiquement)
    func checkExpiredBlocks() {
        syncLogger.info("🔍 [SYNC] Checking for expired blocks...")

        let blocks = blockManager.getActiveBlocks()
        var expiredCount = 0

        for block in blocks where block.isExpired {
            syncLogger.warning("⏰ [SYNC] Block expired: \(block.appName)")
            cleanupBlock(block)
            expiredCount += 1
        }

        if expiredCount > 0 {
            syncLogger.info("✅ [SYNC] Cleaned \(expiredCount) expired block(s)")
            NotificationCenter.default.post(name: NSNotification.Name("ActiveBlocksDidChange"), object: nil)
        } else {
            syncLogger.info("✅ [SYNC] No expired blocks found")
        }
    }
}
