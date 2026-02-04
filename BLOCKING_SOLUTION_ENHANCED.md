# 🔧 Solution Améliorée - Blocage d'Apps avec Token Persistence

## Date: 2026-02-03

---

## ✅ **Découverte Importante**

Tu as raison ! `ApplicationToken` **EST** persistable car il fait partie de `FamilyActivitySelection` qui est `Codable`.

**Preuve dans le code existant:**
```swift
// ZenloopPersistence.swift:176-189

func persistAppsSelection(_ selection: FamilyActivitySelection, count: Int) {
    let encoder = JSONEncoder()
    let data = try encoder.encode(selection)  // ← FamilyActivitySelection est Codable
    UserDefaults.standard.set(data, forKey: Keys.appsSelection)
}

func loadAppsSelection() -> (selection: FamilyActivitySelection, count: Int) {
    let data = UserDefaults.standard.data(forKey: Keys.appsSelection)
    let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
    return (selection: selection, count: count)
}
```

`FamilyActivitySelection` contient:
- `applicationTokens: Set<ApplicationToken>` ✅
- `categoryTokens: Set<ActivityCategoryToken>` ✅

**Donc on PEUT persister les tokens individuels !**

---

## 🚀 **Solution Optimale : Persister le Token dans ActiveBlock**

### Modèle Amélioré

```swift
// BlockingModels.swift - VERSION AMÉLIORÉE

struct ActiveBlock: Codable {
    let id: String
    let appName: String
    let storeName: String
    let startDate: TimeInterval
    var pausedAt: TimeInterval?
    var totalPausedDuration: TimeInterval
    let originalDuration: TimeInterval
    var status: BlockStatus

    // ✅ NOUVEAU: Persister le token pour pouvoir recréer le blocage
    let appToken: Data  // ← ApplicationToken encodé

    enum CodingKeys: String, CodingKey {
        case id, appName, storeName, startDate
        case pausedAt, totalPausedDuration, originalDuration, status
        case appToken
    }

    init(
        id: String = UUID().uuidString,
        appName: String,
        storeName: String,
        duration: TimeInterval,
        token: ApplicationToken,  // ← Nouveau paramètre
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

        // ✅ Encoder le token en Data pour persistence
        if let tokenData = try? JSONEncoder().encode(token) {
            self.appToken = tokenData
        } else {
            // Fallback: Data vide si échec (ne devrait jamais arriver)
            self.appToken = Data()
        }
    }

    // ✅ Méthode pour récupérer le token décodé
    func getApplicationToken() -> ApplicationToken? {
        #if os(iOS)
        return try? JSONDecoder().decode(ApplicationToken.self, from: appToken)
        #else
        return nil
        #endif
    }
}
```

---

## 🔄 **Architecture Complète avec Token Persistence**

### Flow Complet

```
[BLOCAGE INITIAL]
1. User clique "Block Instagram"
    ↓
2. BlockAppSheet récupère app.token (ApplicationToken)
    ↓
3. Créer ManagedSettingsStore("block-ABC")
    ↓
4. Bloquer avec store.shield.applications = [token]
    ↓
5. Créer ActiveBlock avec:
   - appName: "Instagram"
   - storeName: "block-ABC"
   - appToken: encode(token)  ← NOUVEAU
    ↓
6. Sauvegarder ActiveBlock dans App Group
    ↓
Instagram bloqué ✅

[APP RESTART]
7. App démarre
    ↓
8. BlockSyncManager.restoreAllBlocks() appelé
    ↓
9. Lire tous les ActiveBlock depuis App Group
    ↓
10. Pour chaque block:
    a. Décoder appToken → ApplicationToken ✅
    b. Réinstancier ManagedSettingsStore(block.storeName)
    c. Vérifier store.shield.applications
    d. Si vide ou différent → RECRÉER le blocage ✅
    e. Si expiré → Nettoyer
    ↓
11. UI affiche tous les blocks correctement ✅
    ↓
12. User peut débloquer manuellement ✅
```

---

## 💻 **Implémentation : BlockSyncManager Amélioré**

```swift
// zenloop/Managers/BlockSyncManager.swift

import Foundation
import FamilyControls
import ManagedSettings
import os

private let syncLogger = Logger(subsystem: "com.app.zenloop", category: "BlockSync")

class BlockSyncManager {
    static let shared = BlockSyncManager()

    private let blockManager = BlockManager()
    private var activeManagedStores: [String: ManagedSettingsStore] = [:]

    private init() {
        syncLogger.info("🔧 [SYNC] BlockSyncManager initialized")
    }

    // MARK: - Restore All Blocks (Called on App Launch)

    /// ✅ Restaure tous les blocages au démarrage de l'app
    func restoreAllBlocks() {
        syncLogger.critical("🔄 [SYNC] === RESTORE ALL BLOCKS START ===")

        let blocks = blockManager.getAllBlocks()
        syncLogger.info("📦 [SYNC] Found \(blocks.count) blocks in storage")

        for block in blocks {
            syncLogger.info("  → Block: \(block.appName) | Status: \(block.status.rawValue)")

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

        // 3. Si le block est en pause, ne pas appliquer le shield
        if block.status == .paused {
            syncLogger.info("⏸️ [SYNC] Block is paused: \(block.appName)")
            store.shield.applications = nil
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
    }

    // MARK: - Pause/Resume

    /// Mettre en pause un blocage
    func pauseBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId) else { return }

        syncLogger.info("⏸️ [SYNC] Pausing block: \(block.appName)")

        // 1. Mettre à jour le statut
        blockManager.updateBlockStatus(id: blockId, status: .paused)

        // 2. Retirer temporairement le shield
        if let store = activeManagedStores[blockId] {
            store.shield.applications = nil
            syncLogger.info("✅ [SYNC] Shield removed (paused)")
        }
        #endif
    }

    /// Reprendre un blocage
    func resumeBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId),
              let token = block.getApplicationToken() else {
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
        }
        #endif
    }

    // MARK: - Get Store

    /// Récupérer un store actif (pour modification)
    func getStore(for blockId: String) -> ManagedSettingsStore? {
        return activeManagedStores[blockId]
    }
}
```

---

## 📝 **Mise à Jour du Modèle ActiveBlock**

```swift
// zenloop/Models/BlockingModels.swift & zenloopactivity/BlockingModels.swift

struct ActiveBlock: Codable {
    let id: String
    let appName: String
    let storeName: String
    let startDate: TimeInterval
    var pausedAt: TimeInterval?
    var totalPausedDuration: TimeInterval
    let originalDuration: TimeInterval
    var status: BlockStatus
    let appToken: Data  // ✅ NOUVEAU

    // ... existing code ...

    init(
        id: String = UUID().uuidString,
        appName: String,
        storeName: String,
        duration: TimeInterval,
        token: ApplicationToken,  // ✅ NOUVEAU PARAMÈTRE
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

        // ✅ Encoder le token
        if let tokenData = try? JSONEncoder().encode(token) {
            self.appToken = tokenData
        } else {
            self.appToken = Data()
            print("⚠️ [ActiveBlock] Failed to encode token for \(appName)")
        }
    }

    /// ✅ Méthode pour récupérer le token
    func getApplicationToken() -> ApplicationToken? {
        #if os(iOS)
        return try? JSONDecoder().decode(ApplicationToken.self, from: appToken)
        #else
        return nil
        #endif
    }
}
```

---

## 🔧 **Mise à Jour du Code de Blocage**

```swift
// zenloopactivity/FullStatsPageView.swift - blockApp()

private func blockApp() {
    guard !isBlocking else { return }
    isBlocking = true

    #if os(iOS)
    let blockId = UUID().uuidString
    let storeName = "block-\(blockId)"
    let duration = TimeInterval(selectedDuration * 60)

    // 1. Créer le blocage avec ManagedSettings
    let store = ManagedSettingsStore(named: .init(storeName))
    var blockedApps = store.shield.applications ?? Set()
    blockedApps.insert(app.token)
    store.shield.applications = blockedApps

    print("🔒 [BLOCK_SHEET] Blocked \(app.name) for \(selectedDuration)min (ID: \(blockId))")

    // 2. Sauvegarder dans le système de gestion structuré avec TOKEN ✅
    let block = ActiveBlock(
        id: blockId,
        appName: app.name,
        storeName: storeName,
        duration: duration,
        token: app.token,  // ✅ NOUVEAU: Passer le token
        status: .active
    )

    let blockManager = BlockManager()
    blockManager.saveBlock(block)

    print("💾 [BLOCK_SHEET] Block saved to BlockManager with token")
    #endif

    // Feedback visuel + fermeture
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        self.isBlocking = false
        self.onBlockAdded?()
        self.dismiss()
    }
}
```

---

## 🚀 **Intégration dans l'App**

```swift
// zenloop/zenloopApp.swift

@main
struct zenloopApp: App {
    @State private var quickActionsBridge = QuickActionsBridge()

    init() {
        print("🚀 [APP] zenloop starting...")

        // ✅ CRITIQUE: Restaurer tous les blocages au démarrage
        BlockSyncManager.shared.restoreAllBlocks()

        print("✅ [APP] zenloop initialized")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quickActionsBridge)
        }
    }
}
```

---

## 🧪 **Tests à Effectuer**

### Test 1: Blocage Simple
```
1. Bloquer Instagram pour 15min
2. Vérifier: Instagram bloqué ✅
3. Kill app
4. Relancer app
5. Vérifier: Instagram toujours bloqué ✅
6. Vérifier: Block apparaît dans l'UI ✅
7. Débloquer manuellement
8. Vérifier: Instagram débloqué ✅
```

### Test 2: Expiration Automatique
```
1. Bloquer Instagram pour 1min
2. Kill app
3. Attendre 2min
4. Relancer app
5. Vérifier: Instagram débloqué automatiquement ✅
6. Vérifier: Block nettoyé de l'UI ✅
```

### Test 3: Multiple Blocks
```
1. Bloquer Instagram, TikTok, YouTube
2. Kill app
3. Relancer app
4. Vérifier: Tous bloqués ✅
5. Vérifier: Tous visibles dans l'UI ✅
6. Débloquer TikTok seulement
7. Vérifier: Instagram et YouTube toujours bloqués ✅
```

### Test 4: Pause/Resume
```
1. Bloquer Instagram
2. Mettre en pause
3. Kill app
4. Relancer app
5. Vérifier: Instagram accessible ✅
6. Vérifier: Block en pause dans l'UI ✅
7. Reprendre
8. Vérifier: Instagram bloqué ✅
```

---

## 📊 **Avantages de Cette Solution**

### ✅ Robustesse
- Token persisté → Peut toujours recréer le blocage
- Sync automatique au démarrage
- Cleanup automatique des blocs expirés

### ✅ Fiabilité
- Même si ManagedSettingsStore "perd" le blocage → On peut le remettre
- Pas de "blocages fantômes"
- UI toujours synchronisée avec la réalité

### ✅ Flexibilité
- Pause/Resume fonctionnel
- Déblocage manuel
- Extension de durée possible

### ✅ Maintenance
- Code centralisé dans BlockSyncManager
- Logs détaillés pour debugging
- Facile à tester

---

## 🎯 **Plan d'Implémentation**

### Phase 1: Mise à Jour du Modèle (15min)
1. ✅ Ajouter `appToken: Data` dans ActiveBlock
2. ✅ Ajouter `token: ApplicationToken` dans init
3. ✅ Ajouter méthode `getApplicationToken()`
4. ✅ Mettre à jour les deux fichiers (app + extension)

### Phase 2: BlockSyncManager (30min)
1. ✅ Créer BlockSyncManager.swift
2. ✅ Implémenter restoreAllBlocks()
3. ✅ Implémenter restoreBlock() avec token
4. ✅ Implémenter cleanupBlock()
5. ✅ Implémenter pause/resume

### Phase 3: Intégration (10min)
1. ✅ Appeler dans zenloopApp.init()
2. ✅ Mettre à jour blockApp() pour passer token
3. ✅ Ajouter logs

### Phase 4: Tests (30min)
1. ✅ Test tous les scénarios ci-dessus
2. ✅ Vérifier logs
3. ✅ Fix bugs éventuels

**Temps total estimé: ~1h30**

---

**Status:** 🟢 SOLUTION OPTIMALE IDENTIFIÉE
**Ready to implement:** ✅ OUI
