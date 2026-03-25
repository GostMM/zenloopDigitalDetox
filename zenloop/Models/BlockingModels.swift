//
//  BlockingModels.swift
//  zenloop
//
//  Modèles et gestionnaire pour le système de blocage d'apps.
//  Communique avec l'extension via App Group (UserDefaults + FileManager).
//

import Foundation
import FamilyControls
import ManagedSettings
import os

// MARK: - Logger

private let logger = Logger(subsystem: "com.app.zenloop", category: "Blocking")

// MARK: - Constants

private enum StorageKeys {
    static let activeBlocks = "active_blocks_v2"
    static let pendingCommands = "pending_commands"
    static let appGroupID = "group.com.app.zenloop"
    static let blocksFileName = "active_blocks_v2.json"
    static let darwinNotification = "com.app.zenloop.newCommand"
    static let blocksChangedNotification = Notification.Name("ActiveBlocksDidChange")
}

// MARK: - Convenience top-level alias

typealias BlockStatus = ActiveBlock.BlockStatus

// MARK: - ActiveBlock

struct ActiveBlock: Codable, Identifiable {

    enum BlockStatus: String, Codable {
        case active, paused, stopped, expired

        var isRunning: Bool { self == .active || self == .paused }
        var isTerminal: Bool { self == .stopped || self == .expired }
    }

    let id: String
    let appName: String
    let storeName: String
    let startDate: TimeInterval
    let originalDuration: TimeInterval
    let appTokenData: Data

    private(set) var pausedAt: TimeInterval?
    private(set) var totalPausedDuration: TimeInterval
    private(set) var status: BlockStatus

    // MARK: Init

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
        self.originalDuration = duration
        self.appTokenData = tokenData
        self.pausedAt = nil
        self.totalPausedDuration = 0
        self.status = status
    }

    // MARK: Computed — Time

    var endDate: TimeInterval {
        startDate + originalDuration + totalPausedDuration
    }

    var remainingDuration: TimeInterval {
        let now = Date().timeIntervalSince1970
        switch status {
        case .active:
            return max(0, endDate - now)
        case .paused:
            let elapsed = (pausedAt ?? now) - startDate - totalPausedDuration
            return max(0, originalDuration - elapsed)
        case .stopped, .expired:
            return 0
        }
    }

    var elapsedDuration: TimeInterval {
        originalDuration - remainingDuration
    }

    var progress: Double {
        guard originalDuration > 0 else { return 0 }
        return min(1, elapsedDuration / originalDuration)
    }

    var isExpired: Bool {
        status == .active && Date().timeIntervalSince1970 >= endDate
    }

    var formattedRemainingTime: String {
        let total = Int(remainingDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    // MARK: Computed — Token

    #if os(iOS)
    var applicationToken: ApplicationToken? {
        guard !appTokenData.isEmpty else {
            logger.error("No token data for '\(self.appName)'")
            return nil
        }
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: appTokenData) else {
            logger.error("Failed to decode FamilyActivitySelection for '\(self.appName)' (\(self.appTokenData.count) bytes)")
            return nil
        }
        guard let token = selection.applicationTokens.first else {
            logger.error("Decoded selection has no tokens for '\(self.appName)'")
            return nil
        }
        return token
    }

    /// Backward compat alias
    func getApplicationToken() -> ApplicationToken? { applicationToken }
    #endif

    // MARK: Mutations

    mutating func pause() {
        guard status == .active else { return }
        status = .paused
        pausedAt = Date().timeIntervalSince1970
    }

    mutating func resume() {
        guard status == .paused, let pauseStart = pausedAt else { return }
        totalPausedDuration += Date().timeIntervalSince1970 - pauseStart
        pausedAt = nil
        status = .active
    }

    mutating func stop() {
        status = .stopped
    }

    mutating func markExpired() {
        status = .expired
    }

    mutating func extend(by seconds: TimeInterval) {
        guard seconds > 0 else { return }
        totalPausedDuration += seconds
    }
}

// MARK: - BlockCommand

enum BlockCommand: Codable {
    case addBlock(appName: String, duration: TimeInterval, tokenData: Data, context: String)
    case stopBlock(id: String)
    case pauseBlock(id: String)
    case resumeBlock(id: String)
    case extendBlock(id: String, bySeconds: TimeInterval)
}

struct PendingCommand: Codable, Identifiable {
    let id: String
    let command: BlockCommand
    let timestamp: TimeInterval

    init(command: BlockCommand) {
        self.id = UUID().uuidString
        self.command = command
        self.timestamp = Date().timeIntervalSince1970
    }
}

// MARK: - BlockStorage (persistence layer)

/// Gère la double persistance UserDefaults + FileManager dans l'App Group.
private struct BlockStorage {

    private let suite: UserDefaults?
    private let containerURL: URL?

    init() {
        self.suite = UserDefaults(suiteName: StorageKeys.appGroupID)
        self.containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: StorageKeys.appGroupID)
    }

    // MARK: Blocks

    func loadBlocks() -> [ActiveBlock] {
        guard let data = readData(key: StorageKeys.activeBlocks, fileName: StorageKeys.blocksFileName) else {
            return []
        }
        do {
            return try JSONDecoder().decode([ActiveBlock].self, from: data)
        } catch {
            logger.error("Failed to decode blocks: \(error.localizedDescription)")
            return []
        }
    }

    func saveBlocks(_ blocks: [ActiveBlock]) {
        guard let data = try? JSONEncoder().encode(blocks) else {
            logger.error("Failed to encode blocks")
            return
        }
        writeData(data, key: StorageKeys.activeBlocks, fileName: StorageKeys.blocksFileName)
        NotificationCenter.default.post(name: StorageKeys.blocksChangedNotification, object: nil)
    }

    // MARK: Commands

    func loadCommands() -> [PendingCommand] {
        guard let data = suite?.data(forKey: StorageKeys.pendingCommands) else { return [] }
        return (try? JSONDecoder().decode([PendingCommand].self, from: data)) ?? []
    }

    func saveCommands(_ commands: [PendingCommand]) {
        let data = try? JSONEncoder().encode(commands)
        suite?.set(data, forKey: StorageKeys.pendingCommands)
        suite?.synchronize()
    }

    func clearCommands() {
        suite?.removeObject(forKey: StorageKeys.pendingCommands)
        suite?.synchronize()
    }

    // MARK: Private — Dual persistence

    private func readData(key: String, fileName: String) -> Data? {
        // Priorité: UserDefaults, fallback FileManager
        if let data = suite?.data(forKey: key) { return data }

        guard let fileURL = containerURL?.appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            logger.error("File read failed for \(fileName): \(error.localizedDescription)")
            return nil
        }
    }

    private func writeData(_ data: Data, key: String, fileName: String) {
        // 1. UserDefaults
        suite?.set(data, forKey: key)
        suite?.synchronize()

        // 2. FileManager (plus fiable sur simulateur)
        guard let fileURL = containerURL?.appendingPathComponent(fileName) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("File write failed for \(fileName): \(error.localizedDescription)")
        }
    }
}

// MARK: - BlockManager (public API)

struct BlockManager {

    private let storage = BlockStorage()

    // MARK: Read

    func allBlocks() -> [ActiveBlock] {
        storage.loadBlocks()
    }

    func block(withID id: String) -> ActiveBlock? {
        allBlocks().first { $0.id == id }
    }

    func activeBlocks() -> [ActiveBlock] {
        allBlocks().filter { $0.status.isRunning }
    }

    func hasActiveBlock(for appName: String) -> Bool {
        allBlocks().contains { $0.appName == appName && $0.status.isRunning }
    }

    // MARK: Write

    @discardableResult
    func addBlock(
        appName: String,
        duration: TimeInterval,
        tokenData: Data = Data(),
        context: String = ""
    ) -> ActiveBlock {
        // Refuser les doublons
        if let existing = allBlocks().first(where: { $0.appName == appName && $0.status.isRunning }) {
            logger.warning("Block already active for '\(appName)', returning existing")
            return existing
        }

        if tokenData.isEmpty {
            logger.warning("No token data provided for '\(appName)' — shield will be limited")
        }

        let block = ActiveBlock(
            appName: appName,
            storeName: "block_\(UUID().uuidString.prefix(8))",
            duration: duration,
            tokenData: tokenData
        )

        var blocks = allBlocks()
        blocks.append(block)
        storage.saveBlocks(blocks)
        return block
    }

    func save(_ block: ActiveBlock) {
        var blocks = allBlocks()
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
        storage.saveBlocks(blocks)
    }

    func removeBlock(id: String) {
        var blocks = allBlocks()
        blocks.removeAll { $0.id == id }
        storage.saveBlocks(blocks)
    }

    // MARK: State transitions

    func updateStatus(of id: String, to newStatus: BlockStatus) {
        guard var block = block(withID: id) else { return }
        switch newStatus {
        case .active:  block.resume()
        case .paused:  block.pause()
        case .stopped: block.stop()
        case .expired: block.markExpired()
        }
        save(block)
    }

    func extendBlock(id: String, by seconds: TimeInterval) {
        guard var block = block(withID: id) else { return }
        block.extend(by: seconds)
        save(block)
    }

    // MARK: Cleanup

    func purgeTerminatedBlocks() {
        var blocks = allBlocks()
        let before = blocks.count
        blocks.removeAll { $0.status.isTerminal }
        guard blocks.count < before else { return }
        storage.saveBlocks(blocks)
        logger.info("Purged \(before - blocks.count) terminated blocks")
    }

    // MARK: Command queue (Extension ↔ App)

    func sendCommand(_ command: BlockCommand) {
        var commands = storage.loadCommands()
        commands.append(PendingCommand(command: command))
        storage.saveCommands(commands)

        // Notification Darwin pour réveiller l'app
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(StorageKeys.darwinNotification as CFString),
            nil, nil, true
        )
    }

    func pendingCommands() -> [PendingCommand] {
        storage.loadCommands()
    }

    func clearPendingCommands() {
        storage.clearCommands()
    }

    // MARK: - Backward Compatibility (ancien API)

    func getAllBlocks() -> [ActiveBlock] { allBlocks() }
    func getActiveBlocks() -> [ActiveBlock] { activeBlocks() }
    func getBlock(id: String) -> ActiveBlock? { block(withID: id) }
    func getPendingCommands() -> [PendingCommand] { pendingCommands() }
    func saveBlock(_ block: ActiveBlock) { save(block) }

    func updateBlockStatus(id: String, status: BlockStatus) {
        updateStatus(of: id, to: status)
    }

    func removeExpiredAndStoppedBlocks() {
        purgeTerminatedBlocks()
    }

    func extendBlock(id: String, bySeconds seconds: TimeInterval) {
        extendBlock(id: id, by: seconds)
    }
}