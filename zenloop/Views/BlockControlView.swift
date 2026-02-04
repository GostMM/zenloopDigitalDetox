//
//  BlockControlView.swift
//  zenloop
//
//  Gère les blocages d'apps depuis l'app principale (best practice)
//  DeviceActivityReportExtension ne doit QUE lire, pas écrire
//

import SwiftUI
import FamilyControls
import ManagedSettings
import os

private let blockLogger = Logger(subsystem: "com.app.zenloop", category: "BlockControl")

/// ✅ Manager centralisé pour créer des blocages (depuis l'app principale uniquement)
class BlockController: ObservableObject {
    static let shared = BlockController()

    @Published var activeBlocks: [ActiveBlock] = []

    private let blockManager = BlockManager()
    private var activeManagedStores: [String: ManagedSettingsStore] = [:]

    private init() {
        loadActiveBlocks()

        // Écouter les demandes de blocage depuis l'extension
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockRequest),
            name: NSNotification.Name("RequestBlockApp"),
            object: nil
        )
    }

    // MARK: - Load Active Blocks

    func loadActiveBlocks() {
        activeBlocks = blockManager.getActiveBlocks()
        blockLogger.info("📦 Loaded \(self.activeBlocks.count) active blocks")
    }

    // MARK: - Block App (depuis l'app principale)

    /// ✅ SEULE méthode pour bloquer une app (appelée depuis l'app principale)
    func blockApp(
        token: ApplicationToken,
        appName: String,
        duration: TimeInterval
    ) -> Result<ActiveBlock, Error> {
        #if os(iOS)
        blockLogger.info("🔒 [MAIN APP] Blocking \(appName) for \(duration/60)min")

        // 1. Encoder le token
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]

        guard let tokenData = try? JSONEncoder().encode(selection) else {
            let error = NSError(
                domain: "BlockController",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode token"]
            )
            blockLogger.error("❌ Failed to encode token for \(appName)")
            return .failure(error)
        }

        blockLogger.info("✅ Token encoded successfully (\(tokenData.count) bytes)")

        // 2. Créer le block
        let blockId = UUID().uuidString
        let storeName = "block-\(blockId)"

        let block = ActiveBlock(
            id: blockId,
            appName: appName,
            storeName: storeName,
            duration: duration,
            tokenData: tokenData,
            status: .active
        )

        // 3. Sauvegarder dans App Group (depuis l'app principale = FIABLE)
        _ = blockManager.addBlock(
            appName: appName,
            duration: duration,
            tokenData: tokenData,
            context: "Main App - BlockController"
        )

        blockLogger.info("💾 [MAIN APP] Block saved to App Group")

        // 4. Appliquer le blocage dans ManagedSettings
        let store = ManagedSettingsStore(named: .init(storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(token)
        store.shield.applications = blockedApps

        // Garder référence au store
        activeManagedStores[blockId] = store

        blockLogger.info("✅ [MAIN APP] ManagedSettingsStore configured - App BLOCKED!")

        // 5. Mettre à jour l'UI
        DispatchQueue.main.async {
            self.loadActiveBlocks()

            // Notifier l'extension que le blocage est créé
            NotificationCenter.default.post(
                name: NSNotification.Name("ActiveBlocksDidChange"),
                object: nil
            )
        }

        return .success(block)
        #else
        let error = NSError(
            domain: "BlockController",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Not available on this platform"]
        )
        return .failure(error)
        #endif
    }

    // MARK: - Process Pending Block Request (depuis App Group)

    /// ✅ Lire et traiter une demande de blocage depuis l'extension
    func processPendingBlockRequest() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            blockLogger.error("❌ Cannot access App Group")
            return
        }

        // Lire les données TEMPORAIRES sauvegardées par l'extension
        guard let tokenData = suite.data(forKey: "temp_block_tokenData"),
              let appName = suite.string(forKey: "temp_block_appName"),
              let duration = suite.object(forKey: "temp_block_duration") as? TimeInterval,
              let storeName = suite.string(forKey: "temp_block_storeName"),
              let blockId = suite.string(forKey: "temp_block_id") else {
            blockLogger.warning("⚠️ No pending block request found")
            return
        }

        blockLogger.critical("📨 [MAIN APP] ✅ Processing block request from extension!")
        blockLogger.info("  → App: \(appName)")
        blockLogger.info("  → Duration: \(duration/60)min")
        blockLogger.info("  → Store: \(storeName)")
        blockLogger.info("  → Block already applied by extension, now persisting properly...")

        // Nettoyer immédiatement les clés temporaires pour éviter le retraitement
        suite.removeObject(forKey: "temp_block_tokenData")
        suite.removeObject(forKey: "temp_block_appName")
        suite.removeObject(forKey: "temp_block_duration")
        suite.removeObject(forKey: "temp_block_storeName")
        suite.removeObject(forKey: "temp_block_id")
        suite.removeObject(forKey: "temp_block_timestamp")
        suite.synchronize()

        #if os(iOS)
        // ✅ IMPORTANT: L'extension a DÉJÀ bloqué l'app
        // On doit juste persister proprement dans App Group

        // Sauvegarder dans App Group (l'écriture depuis l'app principale est FIABLE)
        let persistedBlock = blockManager.addBlock(
            appName: appName,
            duration: duration,
            tokenData: tokenData,
            context: "Main App - From Extension Request"
        )

        blockLogger.info("💾 Persisted block ID: \(persistedBlock.id)")

        blockLogger.info("💾 [MAIN APP] Block persisted in App Group (will survive restart)")

        // Garder référence au store (déjà créé par l'extension)
        let store = ManagedSettingsStore(named: .init(storeName))
        activeManagedStores[blockId] = store

        // Mettre à jour l'UI
        DispatchQueue.main.async {
            self.loadActiveBlocks()

            NotificationCenter.default.post(
                name: NSNotification.Name("ActiveBlocksDidChange"),
                object: nil
            )
        }

        blockLogger.info("✅ [MAIN APP] Block persistence complete!")
        #endif
    }

    // MARK: - Handle Block Request (depuis extension - legacy)

    @objc private func handleBlockRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let tokenData = userInfo["tokenData"] as? Data,
              let appName = userInfo["appName"] as? String,
              let duration = userInfo["duration"] as? TimeInterval else {
            blockLogger.error("❌ Invalid block request data")
            return
        }

        blockLogger.info("📨 [MAIN APP] Received block request from extension: \(appName)")

        #if os(iOS)
        // Décoder le token
        guard let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: tokenData
        ),
              let token = selection.applicationTokens.first else {
            blockLogger.error("❌ Failed to decode token from request")
            return
        }

        // Créer le blocage
        let result = blockApp(token: token, appName: appName, duration: duration)

        switch result {
        case .success(let block):
            blockLogger.info("✅ [MAIN APP] Block created from extension request: \(block.id)")
        case .failure(let error):
            blockLogger.error("❌ [MAIN APP] Failed to create block: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Unblock App

    func unblockApp(blockId: String) {
        blockLogger.info("🔓 [MAIN APP] Unblocking: \(blockId)")

        guard let block = blockManager.getBlock(id: blockId) else {
            blockLogger.error("❌ Block not found: \(blockId)")
            return
        }

        #if os(iOS)
        // Nettoyer le ManagedSettingsStore
        if let store = activeManagedStores[blockId] {
            store.shield.applications = nil
            store.clearAllSettings()
        } else {
            // Fallback: réinstancier le store
            let store = ManagedSettingsStore(named: .init(block.storeName))
            store.shield.applications = nil
            store.clearAllSettings()
        }

        blockLogger.info("  → Shield cleared")
        #endif

        // Supprimer de nos données
        blockManager.removeBlock(id: blockId)
        activeManagedStores.removeValue(forKey: blockId)

        blockLogger.info("✅ [MAIN APP] Block removed")

        // Mettre à jour l'UI
        DispatchQueue.main.async {
            self.loadActiveBlocks()

            NotificationCenter.default.post(
                name: NSNotification.Name("ActiveBlocksDidChange"),
                object: nil
            )
        }
    }
}

/// Vue SwiftUI pour afficher et gérer les blocages
struct BlockControlView: View {
    @StateObject private var controller = BlockController.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if controller.activeBlocks.isEmpty {
                    Text("No active blocks")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(controller.activeBlocks, id: \.id) { block in
                        blockRow(for: block)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Active Blocks")
        .onAppear {
            controller.loadActiveBlocks()
        }
    }

    private func blockRow(for block: ActiveBlock) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.appName)
                    .font(.headline)

                Text("Remaining: \(formatTime(block.remainingDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Unblock") {
                controller.unblockApp(blockId: block.id)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    NavigationStack {
        BlockControlView()
    }
}
