//
//  BlockingModels.swift
//  zenloop (App Principale)
//
//  Modèles pour le système de blocage d'apps (copie identique de l'extension)
//

import Foundation
import FamilyControls
import ManagedSettings
import os

private let blockLogger = Logger(subsystem: "com.app.zenloop", category: "BlockManager")

// MARK: - Active Block Model

struct ActiveBlock: Codable, Identifiable {
    let id: String
    let appName: String
    let storeName: String
    let startDate: TimeInterval
    var pausedAt: TimeInterval?
    var totalPausedDuration: TimeInterval
    let originalDuration: TimeInterval // Durée initiale en secondes
    var status: BlockStatus
    let appTokenData: Data  // ✅ NEW: Token persisté via FamilyActivitySelection

    enum BlockStatus: String, Codable {
        case active
        case paused
        case stopped
        case expired
    }

    // MARK: - Computed Properties

    /// Date de fin calculée (inclut les pauses)
    var endDate: TimeInterval {
        startDate + originalDuration + totalPausedDuration
    }

    /// Temps restant en secondes
    var remainingDuration: TimeInterval {
        let now = Date().timeIntervalSince1970

        switch status {
        case .active:
            return max(0, endDate - now)
        case .paused:
            guard let pausedAt = pausedAt else { return originalDuration }
            let elapsedBeforePause = pausedAt - startDate - totalPausedDuration
            return max(0, originalDuration - elapsedBeforePause)
        case .stopped, .expired:
            return 0
        }
    }

    /// Temps écoulé depuis le début
    var elapsedDuration: TimeInterval {
        originalDuration - remainingDuration
    }

    /// Pourcentage de progression (0-1)
    var progress: Double {
        guard originalDuration > 0 else { return 0 }
        return min(1.0, elapsedDuration / originalDuration)
    }

    /// Vérifie si le blocage a expiré
    var isExpired: Bool {
        let now = Date().timeIntervalSince1970
        return now >= endDate && status == .active
    }

    /// Temps formaté restant (ex: "15m 30s" ou "1h 05m")
    var formattedRemainingTime: String {
        let remaining = Int(remainingDuration)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60

        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        } else if minutes > 0 {
            return "\(minutes)m \(String(format: "%02d", seconds))s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Initializer

    init(
        id: String = UUID().uuidString,
        appName: String,
        storeName: String,
        duration: TimeInterval,
        tokenData: Data,  // ✅ NEW: Token data parameter
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

    // ✅ NEW: Méthode pour récupérer le token depuis les données persistées
    func getApplicationToken() -> ApplicationToken? {
        #if os(iOS)
        // Vérifier si on a des données de token
        guard !appTokenData.isEmpty else {
            blockLogger.error("❌ [ActiveBlock] No token data for \(self.appName) - legacy block without token")
            return nil
        }

        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: appTokenData) else {
            blockLogger.error("❌ [ActiveBlock] Failed to decode token for \(self.appName)")
            blockLogger.error("  → Token data size: \(appTokenData.count) bytes")
            return nil
        }

        guard let token = selection.applicationTokens.first else {
            blockLogger.error("❌ [ActiveBlock] Selection has no tokens for \(self.appName)")
            return nil
        }

        blockLogger.info("✅ [ActiveBlock] Token decoded successfully for \(self.appName)")
        return token
        #else
        return nil
        #endif
    }

    // MARK: - Actions

    mutating func pause() {
        guard status == .active else { return }
        status = .paused
        pausedAt = Date().timeIntervalSince1970
    }

    mutating func resume() {
        guard status == .paused, let pausedAt = pausedAt else { return }
        let pauseDuration = Date().timeIntervalSince1970 - pausedAt
        totalPausedDuration += pauseDuration
        self.pausedAt = nil
        status = .active
    }

    mutating func stop() {
        status = .stopped
    }

    mutating func extend(by seconds: TimeInterval) {
        // Ajouter du temps à la durée originale
        // Note: Cela décale automatiquement endDate
        totalPausedDuration += seconds
    }

    mutating func markAsExpired() {
        status = .expired
    }
}

// MARK: - Block Command System (Communication App ↔ Extension)

enum BlockCommand: Codable {
    case addBlock(appName: String, duration: TimeInterval, tokenData: Data, context: String)
    case stopBlock(id: String)
    case pauseBlock(id: String)
    case resumeBlock(id: String)
    case extendBlock(id: String, bySeconds: TimeInterval)

    var id: String {
        UUID().uuidString
    }
}

struct PendingCommand: Codable {
    let id: String
    let command: BlockCommand
    let timestamp: TimeInterval

    init(command: BlockCommand) {
        self.id = UUID().uuidString
        self.command = command
        self.timestamp = Date().timeIntervalSince1970
    }
}

// MARK: - Block Manager (pour App Group)

struct BlockManager {
    private let suite: UserDefaults?
    private let key = "active_blocks_v2"
    private let commandsKey = "pending_commands"

    init() {
        self.suite = UserDefaults(suiteName: "group.com.app.zenloop")
        let suiteStatus = self.suite != nil ? "✅" : "❌"
        blockLogger.critical("🔧 [BlockManager] Init - Suite: \(suiteStatus)")
    }

    // MARK: - Read

    func getAllBlocks() -> [ActiveBlock] {
        blockLogger.critical("📖 [BlockManager] getAllBlocks() appelé")

        guard let suite = suite else {
            blockLogger.error("❌ [BlockManager] App Group suite is nil!")
            return []
        }

        // STRATEGIE 1: Essayer UserDefaults d'abord
        var data: Data? = suite.data(forKey: key)

        if data == nil {
            blockLogger.critical("⚠️ [BlockManager] Aucune donnée UserDefaults pour key: \(key)")

            // STRATEGIE 2: Fallback sur FileManager (plus fiable sur simulateur)
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.app.zenloop") {
                let fileURL = containerURL.appendingPathComponent("active_blocks_v2.json")
                blockLogger.critical("📂 [BlockManager] Tentative lecture FILE: \(fileURL.path)")

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        data = try Data(contentsOf: fileURL)
                        blockLogger.critical("✅ [BlockManager] Data FILE trouvée: \(data!.count) bytes")
                    } catch {
                        blockLogger.error("❌ [BlockManager] Erreur lecture FILE: \(error.localizedDescription)")
                    }
                } else {
                    blockLogger.error("❌ [BlockManager] Fichier n'existe pas: \(fileURL.path)")
                }
            }

            // Si toujours rien, afficher debug
            if data == nil {
                return []
            }
        } else {
            blockLogger.critical("📦 [BlockManager] Data UserDefaults trouvée: \(data!.count) bytes")
        }

        guard let finalData = data else {
            return []
        }

        do {
            let blocks = try JSONDecoder().decode([ActiveBlock].self, from: finalData)
            blockLogger.critical("✅ [BlockManager] \(blocks.count) blocks décodés avec succès")
            for block in blocks {
                blockLogger.critical("  → Block: \(block.appName) | Status: \(block.status.rawValue) | ID: \(block.id)")
            }
            return blocks
        } catch {
            blockLogger.error("❌ [BlockManager] Erreur décodage JSON: \(error.localizedDescription)")
            return []
        }
    }

    func getBlock(id: String) -> ActiveBlock? {
        getAllBlocks().first { $0.id == id }
    }

    func getActiveBlocks() -> [ActiveBlock] {
        let all = getAllBlocks()
        let active = all.filter { $0.status == .active || $0.status == .paused }
        blockLogger.critical("🟢 [BlockManager] getActiveBlocks: \(active.count) actifs sur \(all.count) total")
        return active
    }

    // MARK: - Write

    @discardableResult
    func addBlock(appName: String, duration: TimeInterval, tokenData: Data? = nil, context: String = "") -> ActiveBlock {
        let storeName = "block_\(UUID().uuidString.prefix(8))"

        // ✅ Utiliser tokenData si fourni, sinon Data vide (pour compatibilité)
        let finalTokenData = tokenData ?? Data()

        let block = ActiveBlock(
            appName: appName,
            storeName: storeName,
            duration: duration,
            tokenData: finalTokenData
        )

        blockLogger.critical("➕ [BlockManager] Ajout d'un nouveau block: \(appName) pour \(Int(duration/60))min - Context: \(context)")
        if tokenData != nil {
            blockLogger.critical("  → Token data: \(finalTokenData.count) bytes")
        } else {
            blockLogger.warning("  → ⚠️ No token data provided (legacy call)")
        }

        saveBlock(block)
        blockLogger.critical("✅ [BlockManager] Block ajouté avec ID: \(block.id)")

        return block
    }

    func saveBlock(_ block: ActiveBlock) {
        var blocks = getAllBlocks()

        // Remplacer si existe, sinon ajouter
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }

        save(blocks)
    }

    func removeBlock(id: String) {
        var blocks = getAllBlocks()
        blocks.removeAll { $0.id == id }
        save(blocks)
    }

    func updateBlockStatus(id: String, status: ActiveBlock.BlockStatus) {
        guard var block = getBlock(id: id) else { return }

        switch status {
        case .paused:
            block.pause()
        case .active:
            block.resume()
        case .stopped:
            block.stop()
        case .expired:
            block.markAsExpired()
        }

        saveBlock(block)
    }

    func extendBlock(id: String, bySeconds: TimeInterval) {
        guard var block = getBlock(id: id) else { return }
        block.extend(by: bySeconds)
        saveBlock(block)
    }

    // MARK: - Clean Up

    func removeExpiredAndStoppedBlocks() {
        var blocks = getAllBlocks()
        let before = blocks.count
        blocks.removeAll { $0.status == .expired || $0.status == .stopped }

        if blocks.count < before {
            save(blocks)
            print("🧹 [BlockManager] Removed \(before - blocks.count) completed blocks")
        }
    }

    // MARK: - Command System (Extension → App Communication)

    /// Envoie une commande à l'app principale (depuis l'extension)
    func sendCommand(_ command: BlockCommand) {
        let pendingCommand = PendingCommand(command: command)
        var commands = getPendingCommands()
        commands.append(pendingCommand)

        guard let data = try? JSONEncoder().encode(commands) else {
            blockLogger.error("❌ [BlockManager] Échec encodage des commandes")
            return
        }

        suite?.set(data, forKey: commandsKey)
        suite?.synchronize()

        blockLogger.critical("📤 [BlockManager] Commande envoyée: \(String(describing: command))")

        // Envoyer une notification Darwin pour réveiller l'app
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.app.zenloop.newCommand" as CFString),
            nil, nil, true
        )
    }

    /// Récupère les commandes en attente (pour l'app principale)
    func getPendingCommands() -> [PendingCommand] {
        guard let suite = suite,
              let data = suite.data(forKey: commandsKey) else {
            return []
        }

        do {
            let commands = try JSONDecoder().decode([PendingCommand].self, from: data)
            return commands
        } catch {
            blockLogger.error("❌ [BlockManager] Erreur décodage des commandes: \(error.localizedDescription)")
            return []
        }
    }

    /// Efface toutes les commandes en attente (après exécution par l'app)
    func clearPendingCommands() {
        suite?.removeObject(forKey: commandsKey)
        suite?.synchronize()
        blockLogger.critical("🧹 [BlockManager] Commandes effacées")
    }

    // MARK: - Private

    private func save(_ blocks: [ActiveBlock]) {
        guard let data = try? JSONEncoder().encode(blocks) else {
            blockLogger.error("❌ [BlockManager] Échec encodage JSON")
            return
        }

        // DOUBLE PERSISTENCE: UserDefaults + FileManager (pour simulateur)
        // 1. UserDefaults (standard)
        suite?.set(data, forKey: key)
        suite?.synchronize()

        // 2. FileManager (plus fiable sur simulateur)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.app.zenloop") {
            let fileURL = containerURL.appendingPathComponent("active_blocks_v2.json")
            do {
                try data.write(to: fileURL, options: [.atomic])
                blockLogger.critical("💾 [BlockManager] Sauvegarde FILE réussie: \(fileURL.path)")
            } catch {
                blockLogger.error("❌ [BlockManager] Erreur sauvegarde FILE: \(error.localizedDescription)")
            }
        }

        blockLogger.critical("💾 [BlockManager] Sauvegarde réussie: \(blocks.count) blocks, \(data.count) bytes")

        // Notifier l'UI que les blocks ont changé
        NotificationCenter.default.post(name: NSNotification.Name("ActiveBlocksDidChange"), object: nil)
    }
}

