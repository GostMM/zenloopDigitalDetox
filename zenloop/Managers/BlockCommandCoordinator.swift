//
//  BlockCommandCoordinator.swift
//  zenloop
//
//  Coordinateur pour traiter les commandes de blocage depuis l'extension
//

import Foundation
import FamilyControls
import ManagedSettings
import os

private let logger = Logger(subsystem: "com.app.zenloop", category: "BlockCommandCoordinator")

@MainActor
class BlockCommandCoordinator: ObservableObject {
    static let shared = BlockCommandCoordinator()

    private var isMonitoring = false
    private var timer: Timer?

    private init() {}

    // MARK: - Public Interface

    /// Démarre l'écoute des commandes depuis l'extension
    func startMonitoring() {
        guard !isMonitoring else {
            logger.info("⚠️ [COORDINATOR] Already monitoring commands")
            return
        }

        isMonitoring = true
        logger.critical("🎧 [COORDINATOR] Starting command monitoring")

        // 1. Traiter immédiatement les commandes en attente
        processAllPendingCommands()

        // 2. Écouter les notifications Darwin (depuis l'extension)
        setupDarwinObserver()

        // 3. Polling de secours toutes les 2 secondes
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processAllPendingCommands()
            }
        }

        logger.critical("✅ [COORDINATOR] Command monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        timer?.invalidate()
        timer = nil

        // Remove Darwin observer
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName("com.app.zenloop.newCommand" as CFString),
            nil
        )

        logger.critical("🛑 [COORDINATOR] Command monitoring stopped")
    }

    // MARK: - Darwin Notifications

    private func setupDarwinObserver() {
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let coordinator = Unmanaged<BlockCommandCoordinator>.fromOpaque(observer).takeUnretainedValue()

                logger.critical("📬📬📬 [COORDINATOR] ============================================")
                logger.critical("📬 [COORDINATOR] DARWIN NOTIFICATION RECEIVED!")
                logger.critical("📬 [COORDINATOR] Processing commands NOW...")
                logger.critical("📬📬📬 [COORDINATOR] ============================================")

                Task { @MainActor in
                    coordinator.processAllPendingCommands()
                }
            },
            "com.app.zenloop.newCommand" as CFString,
            nil,
            .deliverImmediately
        )

        logger.critical("📡 [COORDINATOR] Darwin observer configured - listening for commands...")
    }

    // MARK: - Command Processing

    private func processAllPendingCommands() {
        let blockManager = BlockManager()
        let commands = blockManager.getPendingCommands()

        guard !commands.isEmpty else {
            return
        }

        logger.critical("📥 [COORDINATOR] Processing \(commands.count) pending commands")

        for pendingCommand in commands {
            processCommand(pendingCommand.command)
        }

        // Effacer les commandes après traitement
        blockManager.clearPendingCommands()
        logger.critical("✅ [COORDINATOR] All commands processed and cleared")
    }

    private func processCommand(_ command: BlockCommand) {
        logger.critical("⚙️ [COORDINATOR] Processing command: \(String(describing: command))")

        switch command {
        case .addBlock(let appName, let duration, let tokenData, let context):
            handleAddBlock(appName: appName, duration: duration, tokenData: tokenData, context: context)

        case .stopBlock(let id):
            handleStopBlock(id: id)

        case .pauseBlock(let id):
            handlePauseBlock(id: id)

        case .resumeBlock(let id):
            handleResumeBlock(id: id)

        case .extendBlock(let id, let bySeconds):
            handleExtendBlock(id: id, bySeconds: bySeconds)
        }
    }

    // MARK: - Command Handlers

    private func handleAddBlock(appName: String, duration: TimeInterval, tokenData: Data, context: String) {
        logger.critical("➕ [COORDINATOR] Adding block for \(appName) - \(Int(duration/60))min")
        logger.critical("   → TokenData size: \(tokenData.count) bytes")

        #if os(iOS)
        let blockManager = BlockManager()

        // 1. Créer le block avec le tokenData fourni
        let blockId = UUID().uuidString
        let storeName = "block-\(blockId)"

        let block = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: storeName,
            duration: duration,
            tokenData: tokenData,  // ✅ Utiliser le tokenData de la commande
            status: .active
        )

        // 2. Sauvegarder le block dans la persistence
        blockManager.saveBlock(block)
        logger.critical("💾 [COORDINATOR] Block saved with ID: \(blockId)")

        // 3. Décoder le token depuis les données
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData) else {
            logger.error("❌ [COORDINATOR] Failed to decode FamilyActivitySelection from tokenData")
            return
        }

        guard let token = selection.applicationTokens.first else {
            logger.error("❌ [COORDINATOR] No application token in selection")
            return
        }

        logger.critical("✅ [COORDINATOR] Token decoded successfully")

        // 4. Appliquer le blocage avec ManagedSettingsStore
        let store = ManagedSettingsStore(named: .init(storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(token)
        store.shield.applications = blockedApps

        logger.critical("🔒 [COORDINATOR] ManagedSettingsStore applied for \(appName)")
        logger.critical("   → Store name: \(storeName)")
        logger.critical("   → Apps blocked: \(blockedApps.count)")

        // 5. Garder le store en mémoire via BlockSyncManager
        BlockSyncManager.shared.restoreAllBlocks()

        logger.critical("✅ [COORDINATOR] Block \(appName) processed and applied successfully")
        #endif
    }

    private func handleStopBlock(id: String) {
        logger.critical("🛑 [COORDINATOR] Stopping block \(id)")

        #if os(iOS)
        let blockManager = BlockManager()

        guard let block = blockManager.getBlock(id: id) else {
            logger.error("❌ [COORDINATOR] Block \(id) not found")
            return
        }

        // Retirer le shield
        let store = ManagedSettingsStore(named: .init(block.storeName))
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        // Mettre à jour le status
        blockManager.updateBlockStatus(id: id, status: .stopped)

        logger.critical("✅ [COORDINATOR] Block \(id) stopped successfully")
        #endif
    }

    private func handlePauseBlock(id: String) {
        logger.critical("⏸️ [COORDINATOR] Pausing block \(id)")

        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: id, status: .paused)

        logger.critical("✅ [COORDINATOR] Block \(id) paused")
    }

    private func handleResumeBlock(id: String) {
        logger.critical("▶️ [COORDINATOR] Resuming block \(id)")

        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: id, status: .active)

        logger.critical("✅ [COORDINATOR] Block \(id) resumed")
    }

    private func handleExtendBlock(id: String, bySeconds: TimeInterval) {
        logger.critical("⏱️ [COORDINATOR] Extending block \(id) by \(Int(bySeconds/60))min")

        let blockManager = BlockManager()
        blockManager.extendBlock(id: id, bySeconds: bySeconds)

        logger.critical("✅ [COORDINATOR] Block \(id) extended")
    }
}
