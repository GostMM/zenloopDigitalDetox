//
//  GlobalShieldManager.swift
//  zenloop
//
//  Gère UN SEUL ManagedSettingsStore global pour TOUS les blocages
//  C'est la clé pour la persistance !
//

import Foundation
import FamilyControls
import ManagedSettings
import os

private let logger = Logger(subsystem: "com.app.zenloop", category: "GlobalShieldManager")

@MainActor
class GlobalShieldManager: ObservableObject {
    static let shared = GlobalShieldManager()

    // ✅ CRUCIAL: UN SEUL store par défaut (sans nom) - c'est ça la clé !
    private let store = ManagedSettingsStore()

    private let blockManager = BlockManager()

    private init() {
        logger.critical("🛡️ [GLOBAL_SHIELD] Initializing with DEFAULT store (key to persistence)")
        // Restaurer tous les blocages au démarrage
        restoreAllActiveBlocks()
    }

    /// Restaure TOUS les blocages actifs depuis App Group
    func restoreAllActiveBlocks() {
        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        logger.critical("🔄 [GLOBAL_SHIELD] ========== RESTORE ALL BLOCKS ==========")
        logger.critical("⚠️ [GLOBAL_SHIELD] WARNING: This will OVERWRITE the DEFAULT store!")

        let activeBlocks = blockManager.getActiveBlocks()
        logger.critical("🔄 [GLOBAL_SHIELD] Found \(activeBlocks.count) active blocks in BlockManager")

        // Vérifier l'état AVANT restauration
        let beforeRestore = store.shield.applications?.count ?? 0
        logger.critical("🔄 [GLOBAL_SHIELD] BEFORE restore: DEFAULT store has \(beforeRestore) blocked apps")

        guard !activeBlocks.isEmpty else {
            logger.info("   → No blocks to restore, skipping")
            logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        #if os(iOS)
        // Collecter TOUS les tokens de toutes les apps bloquées
        var allBlockedTokens: Set<ApplicationToken> = []

        logger.critical("🔄 [GLOBAL_SHIELD] Processing \(activeBlocks.count) blocks:")
        for block in activeBlocks {
            logger.critical("   → Block: \(block.appName) | Status: \(block.status.rawValue) | ID: \(block.id)")

            guard block.status == .active else {
                logger.info("     → Skipped (not active)")
                continue
            }

            // Décoder le token
            guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
                  let token = selection.applicationTokens.first else {
                logger.error("❌ [GLOBAL_SHIELD] Cannot decode token for: \(block.appName)")
                continue
            }

            allBlockedTokens.insert(token)
            logger.critical("✅ [GLOBAL_SHIELD] Token collected: \(block.appName)")
        }

        logger.critical("🔄 [GLOBAL_SHIELD] Collected \(allBlockedTokens.count) tokens to apply")

        // ✅ APPLIQUER TOUS LES TOKENS EN UNE FOIS dans le store global
        logger.critical("⚠️⚠️⚠️ [GLOBAL_SHIELD] OVERWRITING DEFAULT store with \(allBlockedTokens.count) apps...")
        store.shield.applications = allBlockedTokens

        // Vérifier APRÈS restauration
        let afterRestore = store.shield.applications?.count ?? 0
        logger.critical("🔄 [GLOBAL_SHIELD] AFTER restore: DEFAULT store has \(afterRestore) blocked apps")

        if afterRestore != allBlockedTokens.count {
            logger.error("❌ [GLOBAL_SHIELD] MISMATCH! Expected \(allBlockedTokens.count) but got \(afterRestore)")
        }

        logger.critical("🛡️ [GLOBAL_SHIELD] Restore complete!")
        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
    }

    /// Ajoute un blocage au shield global
    func addBlock(token: ApplicationToken, blockId: String, appName: String) {
        logger.critical("➕ [GLOBAL_SHIELD] ========================================")
        logger.critical("➕ [GLOBAL_SHIELD] ADDING BLOCK FOR: \(appName)")
        logger.critical("   → BlockID: \(blockId)")

        #if os(iOS)
        // Récupérer les apps déjà bloquées
        var blockedApps = store.shield.applications ?? Set()
        logger.critical("   → Current blocked apps: \(blockedApps.count)")

        // Ajouter le nouveau token
        let oldCount = blockedApps.count
        blockedApps.insert(token)
        logger.critical("   → After insert: \(blockedApps.count) apps")
        logger.critical("   → Actually added: \(blockedApps.count > oldCount)")

        // Réappliquer tout le set
        logger.critical("   → Applying shield to \(blockedApps.count) apps NOW...")
        store.shield.applications = blockedApps
        logger.critical("   → ✅ store.shield.applications = blockedApps DONE!")

        // Vérifier immédiatement
        let verify = store.shield.applications?.count ?? 0
        logger.critical("   → Verification: store now has \(verify) apps blocked")

        if verify != blockedApps.count {
            logger.error("   → ⚠️ MISMATCH! Expected \(blockedApps.count) but store has \(verify)")
        }

        logger.critical("✅ [GLOBAL_SHIELD] Block operation complete")
        logger.critical("➕ [GLOBAL_SHIELD] ========================================")
        #endif
    }

    /// Retire un blocage du shield global
    func removeBlock(token: ApplicationToken, blockId: String, appName: String) {
        logger.critical("➖ [GLOBAL_SHIELD] Removing block for: \(appName)")

        #if os(iOS)
        // Récupérer les apps bloquées
        var blockedApps = store.shield.applications ?? Set()

        // Retirer ce token
        blockedApps.remove(token)

        // Réappliquer
        if blockedApps.isEmpty {
            // Plus rien à bloquer
            store.shield.applications = nil
            logger.info("   → No more blocks, shield cleared")
        } else {
            store.shield.applications = blockedApps
            logger.info("   → \(blockedApps.count) apps still blocked")
        }

        logger.critical("✅ [GLOBAL_SHIELD] Block removed successfully")
        #endif
    }

    /// Nettoie les blocages expirés
    func cleanupExpiredBlocks() {
        logger.info("🧹 [GLOBAL_SHIELD] Cleaning up expired blocks...")

        let allBlocks = blockManager.getAllBlocks()
        var tokensToRemove: [ApplicationToken] = []

        for block in allBlocks where block.isExpired || block.status != .active {
            if let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
               let token = selection.applicationTokens.first {
                tokensToRemove.append(token)
                logger.info("   → Marking for removal: \(block.appName)")
            }

            // Retirer du storage
            blockManager.removeBlock(id: block.id)
        }

        guard !tokensToRemove.isEmpty else {
            logger.info("   → No expired blocks")
            return
        }

        #if os(iOS)
        // Retirer tous les tokens expirés
        var currentBlocked = store.shield.applications ?? Set()
        for token in tokensToRemove {
            currentBlocked.remove(token)
        }

        store.shield.applications = currentBlocked.isEmpty ? nil : currentBlocked
        logger.critical("✅ [GLOBAL_SHIELD] Removed \(tokensToRemove.count) expired blocks")
        #endif
    }

    /// Force une synchronisation complète
    func forceSync() {
        logger.critical("🔄 [GLOBAL_SHIELD] Force syncing all blocks...")
        restoreAllActiveBlocks()
    }
}