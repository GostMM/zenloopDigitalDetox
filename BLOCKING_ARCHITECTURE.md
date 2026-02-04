# 🔒 Architecture de Blocage d'Apps - Zenloop

Documentation complète du système de blocage, persistence et restauration des applications.

---

## 🎯 Vue d'Ensemble Rapide

### Deux Flux de Création de Blocages

```
┌─────────────────────────────────────────────────────────────────┐
│ FLUX A: Extension zenloopactivity (✅ IMPLÉMENTÉ)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DeviceActivityResults (iOS)                                    │
│         │                                                       │
│         ├─> Token DÉJÀ disponible (pas de picker nécessaire)   │
│         │                                                       │
│         ▼                                                       │
│  ExtensionAppUsage { token, name, duration }                   │
│         │                                                       │
│         ▼                                                       │
│  FullStatsAppRow.blockApp()                                    │
│         │                                                       │
│         └─> Encoder token → Créer block → Appliquer blocage    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ FLUX B: App Principale zenloop (✅ DÉJÀ FONCTIONNEL)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FamilyActivityPicker (UI iOS)                                  │
│         │                                                       │
│         ├─> Utilisateur sélectionne apps manuellement          │
│         │                                                       │
│         ▼                                                       │
│  FamilyActivitySelection { applicationTokens: [...] }          │
│         │                                                       │
│         ▼                                                       │
│  blockSelectedApps()                                           │
│         │                                                       │
│         └─> Encoder tokens → Créer blocks → Appliquer blocages │
│                                                                 │
│  ⚠️ NOTE: Ce flux existe ailleurs dans l'app et fonctionne     │
│           bien. Cette doc se concentre sur le Flux A.          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Problème Résolu

**Avant le fix:**
- ✅ Apps bloquées après restart
- ❌ Invisibles dans l'UI
- ❌ Impossible de débloquer

**Après le fix:**
- ✅ Apps bloquées après restart
- ✅ Visibles dans l'UI
- ✅ Déblocage fonctionnel
- ✅ Références conservées via `appTokenData`

**Comment?** Persistence du `ApplicationToken` via `FamilyActivitySelection.encode()` dans l'App Group.

---

## 📊 Diagramme de Flow Complet

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CYCLE DE VIE D'UN BLOCAGE                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: CRÉATION DU BLOCAGE                                                 │
│                                                                              │
│ ⚠️ IMPORTANT: Il existe 2 flux différents!                                  │
└──────────────────────────────────────────────────────────────────────────────┘


╔══════════════════════════════════════════════════════════════════════════════╗
║ FLUX A: Depuis l'EXTENSION (zenloopactivity) - ✅ IMPLÉMENTÉ                ║
╚══════════════════════════════════════════════════════════════════════════════╝

    DeviceActivityReport affiche les stats
              │
              ▼
    ┌──────────────────────────────────────┐
    │ DeviceActivityResults (iOS)          │
    │                                      │
    │ ✅ Token DÉJÀ disponible via API:    │
    │    - ApplicationToken                │
    │    - Nom app                         │
    │    - Durée utilisation               │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ TotalActivityReport                  │
    │   .makeConfiguration()               │
    │                                      │
    │ ExtensionAppUsage(                   │
    │   token: app.token,  ← Déjà là!      │
    │   name: app.name,                    │
    │   duration: duration                 │
    │ )                                    │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ FullStatsAppRow                      │
    │                                      │
    │ Utilisateur clique "Block"           │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ FullStatsAppRow.blockApp()           │
    │ (Extension zenloopactivity)          │
    │                                      │
    │ ✅ Token DÉJÀ DISPONIBLE             │
    │    let token = app.token             │
    │                                      │
    │ 1. Encoder le token                  │
    │    var selection =                   │
    │      FamilyActivitySelection()       │
    │    selection.applicationTokens =     │
    │      [app.token]                     │
    │    let tokenData = try               │
    │      JSONEncoder().encode(selection) │
    │                                      │
    │ 2. Générer storeName unique          │
    │    storeName = "block-\(UUID())"     │
    │                                      │
    │ 3. Créer ActiveBlock                 │
    │    let block = ActiveBlock(          │
    │      appName: app.name,              │
    │      storeName: storeName,           │
    │      duration: duration,             │
    │      tokenData: tokenData  ✅        │
    │    )                                 │
    └──────────────────────────────────────┘
              │
              ▼


╔══════════════════════════════════════════════════════════════════════════════╗
║ FLUX B: Depuis l'APP PRINCIPALE (zenloop) - ✅ DÉJÀ FONCTIONNEL             ║
║ (Mentionné pour référence, hors scope de cette optimisation)                ║
╚══════════════════════════════════════════════════════════════════════════════╝

    Utilisateur dans l'app principale
              │
              ▼
    ┌─────────────────────┐
    │ FamilyActivityPicker │  ← iOS System UI
    │                      │    (Existe ailleurs)
    │ [Toutes les apps]    │
    │ ☑ Instagram ✓        │
    │ ☐ TikTok             │
    └─────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ @State var selectedApps              │
    │                                      │
    │ for token in selectedApps            │
    │     .applicationTokens:              │
    │                                      │
    │   // Même logique que Flux A         │
    │   var selection = ...                │
    │   let tokenData = encode(selection)  │
    │                                      │
    │ ⚠️ Fonctionne déjà bien, pas de fix  │
    │    nécessaire ici                    │
    └──────────────────────────────────────┘
              │
              ▼


═══════════════════════════════════════════════════════════════════════════════
  FLOW COMMUN: Sauvegarde et Application du Blocage
═══════════════════════════════════════════════════════════════════════════════
              │
              ▼
    ┌──────────────────────────────────────┐
    │ BlockManager.addBlock()              │
    │                                      │
    │ Sauvegarde dans App Group:          │
    │ UserDefaults("group.com.app.zenloop")│
    │   └─> "active_blocks_v2"            │
    │        └─> [block] (JSON)           │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ ManagedSettingsStore                 │
    │                                      │
    │ let store = ManagedSettingsStore(   │
    │   named: .init(storeName)           │
    │ )                                   │
    │                                      │
    │ store.shield.applications = [token] │
    │                                      │
    │ ⚡ iOS BLOQUE L'APP IMMÉDIATEMENT    │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ ✅ APP BLOQUÉE                       │
    │                                      │
    │ - Utilisateur ne peut plus ouvrir   │
    │ - Shield UI s'affiche               │
    │ - Block apparaît dans l'UI Zenloop  │
    └──────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: PERSISTENCE (Automatique)                                           │
└──────────────────────────────────────────────────────────────────────────────┘

    App fermée / Reboot iOS
              │
              ▼
    ┌──────────────────────────────────────┐
    │ iOS System                           │
    │                                      │
    │ ✅ ManagedSettingsStore PERSISTE     │
    │    (Automatique par iOS)            │
    │                                      │
    │ ✅ App Group UserDefaults PERSISTE   │
    │    (Automatique par iOS)            │
    │                                      │
    │ ❌ ManagedSettingsStore REFERENCE    │
    │    PERDUE par l'app Zenloop         │
    └──────────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │ Résultat AVANT FIX:                  │
    │                                      │
    │ ✅ App reste bloquée (iOS)           │
    │ ❌ N'apparaît plus dans l'UI         │
    │ ❌ Impossible de débloquer           │
    │ ❌ Pas de référence au token         │
    └──────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: RESTAURATION AU DÉMARRAGE (Notre Fix)                              │
└──────────────────────────────────────────────────────────────────────────────┘

    App relancée
              │
              ▼
    ┌──────────────────────────────────────┐
    │ zenloopApp.init()                    │
    │                                      │
    │ 1. cleanupLegacyBlocks() ──────────┐│
    │                                     ││
    │ 2. restoreAllBlocks() ────────────┐││
    └────────────────────────────────────┼┼┘
                                        │││
              ┌─────────────────────────┘││
              │                          ││
              ▼                          ││
    ┌──────────────────────────────────┐ ││
    │ cleanupLegacyBlocks()            │ ││
    │                                  │ ││
    │ for block in getAllBlocks():     │ ││
    │   if block.appTokenData.isEmpty: │ ││
    │     // Ancien block sans token   │ ││
    │     blockManager.removeBlock()   │ ││
    │     store.clearAllSettings()     │ ││
    │                                  │ ││
    │ Log: "Cleaned X legacy blocks"   │ ││
    └──────────────────────────────────┘ ││
                                         ││
              ┌──────────────────────────┘│
              │                           │
              ▼                           │
    ┌──────────────────────────────────┐ │
    │ restoreAllBlocks()               │ │
    │                                  │ │
    │ Step 1: Charger depuis App Group │ │
    │ ────────────────────────────────── │
    │ let blocks = blockManager        │ │
    │   .getAllBlocks()                │ │
    │                                  │ │
    │ Log: "Found X blocks in storage" │ │
    └──────────────────────────────────┘ │
              │                           │
              ▼                           │
    ┌──────────────────────────────────┐ │
    │ Step 2: Pour chaque block        │ │
    │ ────────────────────────────────── │
    │ for block in blocks:             │ │
    │                                  │ │
    │   A. Vérifier expiration         │ │
    │      if block.isExpired:         │ │
    │        cleanupBlock()            │ │
    │        continue                  │ │
    │                                  │ │
    │   B. Vérifier statut             │ │
    │      if stopped:                 │ │
    │        cleanupBlock()            │ │
    │        continue                  │ │
    │                                  │ │
    │   C. Restaurer si actif/pausé    │ │
    │      if active || paused:        │ │
    │        restoreBlock(block) ────┐ │ │
    └────────────────────────────────┼─┘ │
                                     │   │
              ┌──────────────────────┘   │
              │                          │
              ▼                          │
    ┌──────────────────────────────────┐ │
    │ restoreBlock(block)              │ │
    │                                  │ │
    │ Step 1: Décoder le token         │ │
    │ ────────────────────────────────── │
    │ guard let token = block          │ │
    │   .getApplicationToken()         │ │
    │ else {                           │ │
    │   // Token invalide              │ │
    │   cleanupBlock()                 │ │
    │   return                         │ │
    │ }                                │ │
    │                                  │ │
    │ ┌──────────────────────────────┐ │ │
    │ │ getApplicationToken()        │ │ │
    │ │                              │ │ │
    │ │ 1. Vérifier tokenData        │ │ │
    │ │    if appTokenData.isEmpty:  │ │ │
    │ │      return nil               │ │ │
    │ │                              │ │ │
    │ │ 2. Décoder FamilyActivitySelection││ │
    │ │    let selection = JSONDecoder()││ │
    │ │      .decode(appTokenData)   │ │ │
    │ │                              │ │ │
    │ │ 3. Extraire token            │ │ │
    │ │    return selection          │ │ │
    │ │      .applicationTokens.first│ │ │
    │ └──────────────────────────────┘ │ │
    │                                  │ │
    │ Log: "Token decoded ✅"          │ │
    └──────────────────────────────────┘ │
              │                          │
              ▼                          │
    ┌──────────────────────────────────┐ │
    │ Step 2: Réinstancier le store    │ │
    │ ────────────────────────────────── │
    │ let store = ManagedSettingsStore(│ │
    │   named: .init(block.storeName)  │ │
    │ )                                │ │
    │                                  │ │
    │ // Garder référence              │ │
    │ activeManagedStores[block.id]    │ │
    │   = store                        │ │
    └──────────────────────────────────┘ │
              │                          │
              ▼                          │
    ┌──────────────────────────────────┐ │
    │ Step 3: Vérifier le blocage      │ │
    │ ────────────────────────────────── │
    │ let currentBlocked = store       │ │
    │   .shield.applications ?? []     │ │
    │                                  │ │
    │ if block.status == .active:      │ │
    │   if !currentBlocked             │ │
    │       .contains(token):          │ │
    │     // Réappliquer blocage       │ │
    │     store.shield.applications    │ │
    │       = [token]                  │ │
    │     Log: "Block re-applied ✅"   │ │
    │   else:                          │ │
    │     Log: "Already active ✅"     │ │
    │                                  │ │
    │ else if block.status == .paused: │ │
    │   store.shield.applications = nil│ │
    │   Log: "Paused (shield removed)" │ │
    └──────────────────────────────────┘ │
              │                          │
              ▼                          │
    ┌──────────────────────────────────┐ │
    │ ✅ BLOCAGE RESTAURÉ              │ │
    │                                  │ │
    │ - App bloquée dans iOS           │ │
    │ - Apparaît dans l'UI Zenloop     │ │
    │ - Déblocage possible             │ │
    │ - Références conservées          │ │
    └──────────────────────────────────┘ │
                                         │
              ┌──────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────┐
    │ Log: "RESTORE COMPLETE ✅"       │
    └──────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: DÉBLOCAGE MANUEL                                                    │
└──────────────────────────────────────────────────────────────────────────────┘

    Utilisateur clique "Unblock"
              │
              ▼
    ┌──────────────────────────────────┐
    │ BlockSyncManager.unblockApp()    │
    │                                  │
    │ 1. Récupérer le block            │
    │    let block = blockManager      │
    │      .getBlock(id: blockId)      │
    │                                  │
    │ 2. Nettoyer le store             │
    │    let store = ManagedSettingsStore│
    │      (named: block.storeName)    │
    │    store.shield.applications = nil│
    │    store.clearAllSettings()      │
    │                                  │
    │ 3. Supprimer de nos données      │
    │    blockManager.removeBlock()    │
    │    activeManagedStores.remove()  │
    │                                  │
    │ 4. Notifier l'UI                 │
    │    NotificationCenter.post(      │
    │      "ActiveBlocksDidChange"     │
    │    )                             │
    └──────────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────┐
    │ ✅ APP DÉBLOQUÉE                 │
    │                                  │
    │ - Shield retiré                  │
    │ - App utilisable                 │
    │ - Disparaît de l'UI              │
    └──────────────────────────────────┘
```

---

## 💾 Code Source Complet

### 1. Modèle de Données - `BlockingModels.swift`

```swift
import Foundation
import FamilyControls
import ManagedSettings
import os

// Logger pour debugging
private let blockLogger = Logger(
    subsystem: "com.app.zenloop",
    category: "BlockingModels"
)

// MARK: - Block Status

enum BlockStatus: String, Codable {
    case active    // Blocage actif
    case paused    // Mis en pause
    case stopped   // Arrêté manuellement
}

// MARK: - Active Block Model

struct ActiveBlock: Codable, Identifiable {
    // Identifiants
    let id: String
    let appName: String
    let storeName: String  // Nom unique du ManagedSettingsStore

    // Timing
    let startDate: TimeInterval
    var pausedAt: TimeInterval?
    var totalPausedDuration: TimeInterval
    let originalDuration: TimeInterval

    // État
    var status: BlockStatus

    // ✅ CRITIQUE: Token persisté
    let appTokenData: Data

    // MARK: - Initializer

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

    // MARK: - Computed Properties

    var remainingTime: TimeInterval {
        let elapsed = Date().timeIntervalSince1970 - startDate
        let adjusted = elapsed - totalPausedDuration

        if let pausedAt = pausedAt {
            let pausedElapsed = Date().timeIntervalSince1970 - pausedAt
            return max(0, originalDuration - adjusted + pausedElapsed)
        }

        return max(0, originalDuration - adjusted)
    }

    var isExpired: Bool {
        return remainingTime <= 0 && status != .stopped
    }

    // MARK: - Token Decoding

    /// ✅ Décoder le ApplicationToken depuis les données persistées
    func getApplicationToken() -> ApplicationToken? {
        #if os(iOS)
        // 1. Vérifier que les données existent
        guard !appTokenData.isEmpty else {
            blockLogger.error("❌ No token data for \(self.appName) - legacy block")
            return nil
        }

        // 2. Décoder FamilyActivitySelection
        guard let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: appTokenData
        ) else {
            blockLogger.error("❌ Failed to decode token for \(self.appName)")
            blockLogger.error("  → Token data size: \(self.appTokenData.count) bytes")
            return nil
        }

        // 3. Extraire le token
        guard let token = selection.applicationTokens.first else {
            blockLogger.error("❌ Selection has no tokens for \(self.appName)")
            return nil
        }

        blockLogger.info("✅ Token decoded for \(self.appName)")
        return token
        #else
        return nil
        #endif
    }
}

// MARK: - Block Manager

class BlockManager {
    private let userDefaults: UserDefaults?
    private let blocksKey = "active_blocks_v2"

    init() {
        self.userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
    }

    // MARK: - Add Block

    func addBlock(
        appName: String,
        duration: TimeInterval,
        tokenData: Data? = nil,
        context: String = ""
    ) -> ActiveBlock {
        let storeName = "block_\(UUID().uuidString)"
        let block = ActiveBlock(
            appName: appName,
            storeName: storeName,
            duration: duration,
            tokenData: tokenData ?? Data(),
            status: .active
        )

        var blocks = getAllBlocks()
        blocks.append(block)
        saveBlocks(blocks)

        blockLogger.info("💾 Block saved: \(appName) | Context: \(context)")
        blockLogger.info("  → Token size: \(block.appTokenData.count) bytes")

        return block
    }

    // MARK: - Get Blocks

    func getAllBlocks() -> [ActiveBlock] {
        guard let data = userDefaults?.data(forKey: blocksKey) else {
            return []
        }

        return (try? JSONDecoder().decode([ActiveBlock].self, from: data)) ?? []
    }

    func getActiveBlocks() -> [ActiveBlock] {
        return getAllBlocks().filter { $0.status == .active }
    }

    func getBlock(id: String) -> ActiveBlock? {
        return getAllBlocks().first { $0.id == id }
    }

    // MARK: - Update Block

    func updateBlockStatus(id: String, status: BlockStatus) {
        var blocks = getAllBlocks()

        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].status = status

            if status == .paused {
                blocks[index].pausedAt = Date().timeIntervalSince1970
            } else if status == .active, blocks[index].pausedAt != nil {
                let pauseDuration = Date().timeIntervalSince1970 - blocks[index].pausedAt!
                blocks[index].totalPausedDuration += pauseDuration
                blocks[index].pausedAt = nil
            }

            saveBlocks(blocks)
            blockLogger.info("Status updated: \(status.rawValue) for block \(id)")
        }
    }

    // MARK: - Remove Block

    func removeBlock(id: String) {
        var blocks = getAllBlocks()
        blocks.removeAll { $0.id == id }
        saveBlocks(blocks)

        blockLogger.info("Block removed: \(id)")
    }

    func removeExpiredAndStoppedBlocks() {
        var blocks = getAllBlocks()
        let originalCount = blocks.count

        blocks.removeAll { $0.isExpired || $0.status == .stopped }

        if blocks.count < originalCount {
            saveBlocks(blocks)
            blockLogger.info("Cleaned \(originalCount - blocks.count) blocks")
        }
    }

    // MARK: - Save

    private func saveBlocks(_ blocks: [ActiveBlock]) {
        if let data = try? JSONEncoder().encode(blocks) {
            userDefaults?.set(data, forKey: blocksKey)
            blockLogger.info("💾 Saved \(blocks.count) blocks to App Group")
        }
    }
}
```

---

### 2. Création du Blocage - `zenloopactivity/FullStatsPageView.swift` (Extrait)

**⚠️ NOTE IMPORTANTE:** Ce code est dans l'**EXTENSION** `zenloopactivity`, pas dans l'app principale!
Le token `app.token` est déjà disponible via `DeviceActivityResults`, pas besoin de `FamilyActivityPicker`.

```swift
import FamilyControls
import ManagedSettings
import os

private let blockSheetLogger = Logger(
    subsystem: "com.app.zenloop.zenloopactivity",
    category: "BlockSheet"
)

// ✅ Dans l'extension: ExtensionAppUsage contient déjà le token!
struct FullStatsAppRow: View {
    let app: ExtensionAppUsage  // Contient: token, name, duration
    let isBlocked: Bool
    @State private var showBlockSheet = false
    @State private var selectedDuration = 30
    @State private var isBlocking = false

    var body: some View {
        Button {
            if !isBlocked {
                showBlockSheet = true
            }
        } label: {
            // Affichage de l'app avec son icône
            #if os(iOS)
            Label(app.token)  // ← Utilise le token pour afficher l'icône
                .labelStyle(.iconOnly)
            #endif
            Text(app.name)
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockDurationSheet(
                selectedDuration: $selectedDuration,
                onConfirm: { blockApp() }
            )
        }
    }

    // MARK: - Block App (depuis l'extension!)

    private func blockApp() {
        guard !isBlocking else { return }
        isBlocking = true

        #if os(iOS)
        let blockId = UUID().uuidString
        let storeName = "block-\(blockId)"
        let duration = TimeInterval(selectedDuration * 60)

        blockSheetLogger.info("🔒 Blocking \(app.name) for \(selectedDuration)min")

        // ✅ ÉTAPE 1: Encoder le token (déjà disponible via app.token!)
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [app.token]  // ← Token DÉJÀ LÀ!

        guard let tokenData = try? JSONEncoder().encode(selection) else {
            blockSheetLogger.error("❌ Failed to encode token for \(app.name)")
            isBlocking = false
            return
        }

        blockSheetLogger.info("✅ Token encoded successfully")
        blockSheetLogger.info("  → Token data size: \(tokenData.count) bytes")

        // ✅ ÉTAPE 2: Créer ActiveBlock avec le token
        let block = ActiveBlock(
            id: blockId,
            appName: app.name,
            storeName: storeName,
            duration: duration,
            tokenData: tokenData,  // ✅ Token persisté
            status: .active
        )

        // ✅ ÉTAPE 3: Sauvegarder dans BlockManager (App Group)
        let blockManager = BlockManager()
        blockManager.saveBlock(block)

        blockSheetLogger.info("💾 Block saved to App Group with token (\(tokenData.count) bytes)")

        // ✅ ÉTAPE 4: Appliquer le blocage dans ManagedSettings
        let store = ManagedSettingsStore(named: .init(storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(app.token)
        store.shield.applications = blockedApps

        blockSheetLogger.info("✅ ManagedSettingsStore configured - App BLOCKED!")

        // Feedback visuel + fermeture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isBlocking = false
            self.onBlockAdded?()
        }
        #endif
    }
}
```

---

### 3. Manager de Synchronisation - `BlockSyncManager.swift`

```swift
import Foundation
import FamilyControls
import ManagedSettings
import os

private let syncLogger = Logger(
    subsystem: "com.app.zenloop",
    category: "BlockSync"
)

/// ✅ Manager qui restaure et synchronise les blocages d'apps au démarrage
class BlockSyncManager {
    static let shared = BlockSyncManager()

    private let blockManager = BlockManager()
    private var activeManagedStores: [String: ManagedSettingsStore] = [:]

    private init() {
        syncLogger.info("🔧 BlockSyncManager initialized")
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

    // MARK: - Restore All Blocks

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
        // 1. Décoder le token
        guard let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot decode token for: \(block.appName)")
            cleanupBlock(block)
            return
        }

        syncLogger.info("🔓 [SYNC] Token decoded successfully for: \(block.appName)")

        // 2. Réinstancier le store
        let store = ManagedSettingsStore(named: .init(block.storeName))
        activeManagedStores[block.id] = store

        // 3. Vérifier si le blocage est toujours actif
        let currentBlocked = store.shield.applications ?? Set()

        if block.status == .active {
            if !currentBlocked.contains(token) {
                // Token n'est plus bloqué → Le remettre
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
        NotificationCenter.default.post(
            name: NSNotification.Name("ActiveBlocksDidChange"),
            object: nil
        )
    }

    // MARK: - Pause/Resume

    func pauseBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId),
              let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot pause block: \(blockId)")
            return
        }

        syncLogger.info("⏸️ [SYNC] Pausing block: \(block.appName)")

        blockManager.updateBlockStatus(id: blockId, status: .paused)

        if let store = activeManagedStores[blockId] {
            store.shield.applications = nil
            syncLogger.info("✅ [SYNC] Shield removed (paused)")
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("ActiveBlocksDidChange"),
            object: nil
        )
        #endif
    }

    func resumeBlock(blockId: String) {
        #if os(iOS)
        guard let block = blockManager.getBlock(id: blockId),
              let token = block.getApplicationToken() else {
            syncLogger.error("❌ [SYNC] Cannot resume block: \(blockId)")
            return
        }

        syncLogger.info("▶️ [SYNC] Resuming block: \(block.appName)")

        blockManager.updateBlockStatus(id: blockId, status: .active)

        if let store = activeManagedStores[blockId] {
            var blockedApps = store.shield.applications ?? Set()
            blockedApps.insert(token)
            store.shield.applications = blockedApps
            syncLogger.info("✅ [SYNC] Shield re-applied (resumed)")
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("ActiveBlocksDidChange"),
            object: nil
        )
        #endif
    }
}
```

---

### 4. Point d'Entrée - `zenloopApp.swift`

```swift
import SwiftUI
import FirebaseCore

@main
struct zenloopApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var quickActionsBridge = QuickActionsBridge.shared
    @State private var showSplash = true
    @State private var isFirebaseConfigured = false

    init() {
        // OPTIMIZATION: Firebase configuration moved to async Task
        // This prevents blocking the main thread before first frame

        // ✅ CRITIQUE: Nettoyer les anciens blocs sans token (one-time)
        BlockSyncManager.shared.cleanupLegacyBlocks()

        // ✅ CRITIQUE: Restaurer tous les blocages au démarrage
        BlockSyncManager.shared.restoreAllBlocks()
    }

    var body: some Scene {
        WindowGroup {
            // ... UI Code ...
        }
    }
}
```

---

## 🔑 Points Clés de l'Architecture

### 0. **Deux Flux de Création - Token Déjà Disponible vs Picker**

#### ✅ Flux A: Extension (zenloopactivity) - IMPLÉMENTÉ
```swift
// Dans l'extension DeviceActivityReport, le token est DÉJÀ disponible
// via DeviceActivityResults (fourni par iOS)

struct FullStatsAppRow: View {
    let app: ExtensionAppUsage  // ← Contient déjà app.token!

    func blockApp() {
        // ✅ Token directement accessible
        let token = app.token  // ApplicationToken déjà là!

        // Encoder pour persistence
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [app.token]
        let tokenData = try JSONEncoder().encode(selection)

        // Créer le blocage
        let store = ManagedSettingsStore(...)
        store.shield.applications = [token]
    }
}
```

**Pourquoi ça fonctionne?**
- `DeviceActivityResults` est l'API iOS qui donne accès aux données d'utilisation
- Elle retourne directement les `ApplicationToken` des apps utilisées
- Pas besoin de `FamilyActivityPicker` car iOS nous donne déjà les tokens!

#### ❌ Flux B: App Principale - NON IMPLÉMENTÉ (Future)
```swift
// Dans l'app principale, on doit DEMANDER à l'utilisateur
// de sélectionner via FamilyActivityPicker

import FamilyControls

struct BlockAppsView: View {
    @State private var selectedApps = FamilyActivitySelection()

    var body: some View {
        VStack {
            // ❌ Ce picker n'existe PAS dans l'extension!
            FamilyActivityPicker(selection: $selectedApps)

            Button("Block Selected Apps") {
                blockSelectedApps()
            }
        }
    }

    func blockSelectedApps() {
        // Récupérer les tokens depuis la sélection
        for token in selectedApps.applicationTokens {
            // Encoder et bloquer (même logique que Flux A)
            var selection = FamilyActivitySelection()
            selection.applicationTokens = [token]
            let tokenData = try JSONEncoder().encode(selection)
            // ...
        }
    }
}
```

**Différence clé:**
- `FamilyActivityPicker` = UI iOS pour sélectionner n'importe quelle app
- Disponible UNIQUEMENT dans l'app principale
- PAS disponible dans les extensions (sandbox restrictions)

**Résumé:**
| Context | Source du Token | Méthode | Status |
|---------|----------------|---------|---------|
| Extension (zenloopactivity) | `DeviceActivityResults` | ✅ Déjà disponible | Focus de cette doc |
| App principale (zenloop) | `FamilyActivityPicker` | ✅ Déjà fonctionnel | Hors scope |

⚠️ **Note:** Cette documentation se concentre sur le **Flux A (Extension)** car c'est là où le fix de persistence a été appliqué. Le Flux B existe ailleurs dans l'app et fonctionne déjà bien.

---

### 1. **ApplicationToken n'est PAS directement Codable**
```swift
// ❌ NE FONCTIONNE PAS
let tokenData = try JSONEncoder().encode(token)

// ✅ FONCTIONNE via FamilyActivitySelection
var selection = FamilyActivitySelection()
selection.applicationTokens = [token]
let tokenData = try JSONEncoder().encode(selection)
```

### 2. **ManagedSettingsStore Persiste Automatiquement**
- iOS garde le `ManagedSettingsStore` en mémoire
- Les blocages persistent après reboot
- MAIS l'app perd la référence Swift au store

### 3. **storeName Unique est Essentiel**
```swift
let storeName = "block_\(UUID().uuidString)"
let store = ManagedSettingsStore(named: .init(storeName))
```

Chaque blocage a son propre store pour:
- Débloquer individuellement
- Éviter les conflits
- Retrouver le bon store après restart

### 4. **App Group pour Partage de Données**
```swift
UserDefaults(suiteName: "group.com.app.zenloop")
```

Permet de partager entre:
- L'app principale
- L'extension Device Activity Report
- L'extension Device Activity Monitor

### 5. **Ordre des Opérations Critique**
```swift
// 1. NETTOYER d'abord (anciens blocs)
cleanupLegacyBlocks()

// 2. RESTAURER ensuite (nouveaux blocs)
restoreAllBlocks()
```

---

## 🚀 Logs de Diagnostic

### Création d'un Bloc (Premier Lancement)
```
✅ [BLOCK_SHEET] Token encoded successfully for Instagram
  → Token data size: 142 bytes
💾 [BLOCK_SHEET] Block saved with token (142 bytes)
✅ [BLOCK_SHEET] ManagedSettingsStore configured for Instagram
🎉 [BLOCK_SHEET] Block process complete!
```

### Relancement de l'App (Restauration)
```
🧹 [SYNC] Cleaning up legacy blocks without tokens...
✅ [SYNC] Cleaned 0 legacy blocks

🔄 [SYNC] === RESTORE ALL BLOCKS START ===
📦 [SYNC] Found 1 blocks in storage
  → Block: Instagram | Status: active
♻️ [SYNC] Restoring active block: Instagram
✅ [ActiveBlock] Token decoded for Instagram
🔓 [SYNC] Token decoded successfully for: Instagram
✅ [SYNC] Block already active: Instagram
✅ [SYNC] === RESTORE ALL BLOCKS COMPLETE ===
```

### Déblocage Manuel
```
🔓 [SYNC] Manual unblock requested: <block-id>
🧹 [SYNC] Cleaning up block: Instagram
  → Shield cleared
✅ [SYNC] Block cleaned: Instagram
```

---

## 🎯 Résumé

### Le Problème
- Apps bloquées mais invisibles après restart
- Impossibilité de débloquer

### La Cause
- `ApplicationToken` non persisté
- `ManagedSettingsStore` référence perdue

### La Solution
1. ✅ Persister token via `FamilyActivitySelection`
2. ✅ Décoder token au démarrage
3. ✅ Réinstancier `ManagedSettingsStore` avec `storeName`
4. ✅ Vérifier et réappliquer blocages si nécessaire
5. ✅ Nettoyer automatiquement les anciens blocs

### Résultat
- ✅ Blocages persistent après restart
- ✅ UI affiche correctement les apps bloquées
- ✅ Déblocage manuel fonctionne
- ✅ Architecture robuste et maintenable

---

**Documentation complète de l'architecture de blocage Zenloop**
