# 🔍 Analyse du Problème de Blocage d'Apps

## Date: 2026-02-03

---

## ❌ **Problème Identifié**

### Symptômes
1. ✅ L'app se bloque correctement initialement
2. ❌ Après redémarrage de l'app → **l'app reste bloquée**
3. ❌ **Le blocage n'apparaît plus dans l'UI** (liste vide)
4. ❌ **Impossible de débloquer** manuellement

---

## 🔬 **Analyse du Code**

### Architecture Actuelle

#### 1. **Données de Blocage** (ActiveBlock)
```swift
// Stockage: App Group UserDefaults + FileManager
// Fichier: zenloop/Models/BlockingModels.swift:16-137

struct ActiveBlock: Codable {
    let id: String
    let appName: String
    let storeName: String        // ← NOM du ManagedSettingsStore
    let startDate: TimeInterval
    let originalDuration: TimeInterval
    var status: BlockStatus       // active, paused, stopped, expired
}
```

**Localisation:**
- ✅ Persisté dans App Group: `active_blocks_v2.json`
- ✅ Double persistance: UserDefaults + FileManager

#### 2. **Blocage Réel** (ManagedSettingsStore)
```swift
// Fichier: zenloopactivity/FullStatsPageView.swift:971-998

func blockApp() {
    let blockId = UUID().uuidString
    let storeName = "block-\(blockId)"

    // 1. Créer le store avec un NOM unique
    let store = ManagedSettingsStore(named: .init(storeName))

    // 2. Bloquer l'app
    var blockedApps = store.shield.applications ?? Set()
    blockedApps.insert(app.token)
    store.shield.applications = blockedApps

    // 3. Sauvegarder les métadonnées
    let block = ActiveBlock(
        id: blockId,
        appName: app.name,
        storeName: storeName,  // ← CRITIQUE
        duration: duration,
        status: .active
    )
    blockManager.saveBlock(block)
}
```

---

## 🐛 **Problèmes Identifiés**

### Problème #1: ManagedSettingsStore Lifecycle
```
[Blocage créé]
    ↓
ManagedSettingsStore("block-ABC123") créé
    ↓
ActiveBlock sauvegardé avec storeName = "block-ABC123"
    ↓
[App redémarr]
    ↓
❌ AUCUN CODE ne recharge les ManagedSettingsStore existants
    ↓
BlockManager.getAllBlocks() → Trouve les ActiveBlocks ✅
    ↓
Mais ManagedSettingsStore("block-ABC123") n'est PAS réinstancié ❌
    ↓
Résultat: App reste bloquée système mais app ne "voit" plus le blocage
```

### Problème #2: Pas de Cleanup sur Expired
```swift
// BlockingModels.swift:310-319
func removeExpiredAndStoppedBlocks() {
    var blocks = getAllBlocks()
    blocks.removeAll { $0.status == .expired || $0.status == .stopped }
    save(blocks)
    // ⚠️ MANQUE: Suppression du ManagedSettingsStore correspondant!
}
```

**Code actuel:**
- ✅ Supprime ActiveBlock de l'App Group
- ❌ **NE supprime PAS** le ManagedSettingsStore
- ❌ L'app reste bloquée "fantôme"

### Problème #3: Pas de Synchronisation au Démarrage
```
zenloopApp.swift → init() → Aucun code de sync
    ↓
ZenloopManager → init() → Aucun code de sync
    ↓
❌ Les ManagedSettingsStore existants ne sont jamais rechargés
```

---

## 📊 **Lifecycle Comparaison**

### Comportement Actuel (Cassé)
```
[Session 1]
1. User bloque Instagram → ManagedSettingsStore("block-X") créé ✅
2. ActiveBlock sauvegardé en App Group ✅
3. Instagram bloqué ✅

[App Killed]

[Session 2]
1. App démarre
2. BlockManager.getAllBlocks() lit App Group → Trouve ActiveBlock ✅
3. ⚠️ Mais ManagedSettingsStore("block-X") n'existe QUE dans iOS
4. ⚠️ App ne peut pas "voir" ce store (pas de référence)
5. UI affiche: "Aucune app bloquée" ❌
6. Instagram reste bloqué (iOS garde le store) ❌
7. User ne peut pas débloquer (pas d'UI) ❌
```

### Comportement Attendu (Correct)
```
[Session 1]
1. User bloque Instagram → ManagedSettingsStore créé ✅
2. ActiveBlock sauvegardé ✅

[App Killed]

[Session 2]
1. App démarre
2. SyncManager.restoreAllBlocks() appelé
3. Pour chaque ActiveBlock:
   a. Réinstancier ManagedSettingsStore(named: block.storeName) ✅
   b. Vérifier si toujours actif ✅
   c. Si expiré → Nettoyer le store ✅
4. UI affiche tous les blocks actifs ✅
5. User peut débloquer manuellement ✅
```

---

## 💡 **Solutions Proposées**

### Solution #1: BlockSyncManager (Recommandé ⭐)

**Concept:** Manager centralisé qui synchronise ManagedSettingsStore au démarrage

```swift
// zenloop/Managers/BlockSyncManager.swift

class BlockSyncManager {
    static let shared = BlockSyncManager()

    private let blockManager = BlockManager()
    private var activeManagedStores: [String: ManagedSettingsStore] = [:]

    /// Appelé au démarrage de l'app
    func restoreAllBlocks() {
        print("🔄 [SYNC] Restoring all blocks from App Group...")

        let blocks = blockManager.getAllBlocks()
        print("📦 [SYNC] Found \(blocks.count) blocks in storage")

        for block in blocks {
            if block.isExpired {
                // Nettoyer les blocs expirés
                cleanupBlock(block)
            } else if block.status == .active || block.status == .paused {
                // Réinstancier les stores actifs
                restoreBlock(block)
            } else if block.status == .stopped {
                // Nettoyer les blocs arrêtés
                cleanupBlock(block)
            }
        }

        // Cleanup final
        blockManager.removeExpiredAndStoppedBlocks()
    }

    private func restoreBlock(_ block: ActiveBlock) {
        #if os(iOS)
        print("♻️ [SYNC] Restoring block: \(block.appName)")

        // Réinstancier le store
        let store = ManagedSettingsStore(named: .init(block.storeName))
        activeManagedStores[block.id] = store

        // Le store existe déjà dans iOS, on garde juste la référence
        print("✅ [SYNC] Block restored: \(block.appName)")
        #endif
    }

    private func cleanupBlock(_ block: ActiveBlock) {
        #if os(iOS)
        print("🧹 [SYNC] Cleaning up block: \(block.appName)")

        // 1. Débloquer l'app
        let store = ManagedSettingsStore(named: .init(block.storeName))
        store.shield.applications = nil  // ← Débloque TOUT
        store.clearAllSettings()          // ← Nettoie le store

        // 2. Supprimer de nos données
        blockManager.removeBlock(id: block.id)
        activeManagedStores.removeValue(forKey: block.id)

        print("✅ [SYNC] Block cleaned: \(block.appName)")
        #endif
    }

    /// Débloquer une app manuellement
    func unblockApp(blockId: String) {
        guard let block = blockManager.getBlock(id: blockId) else {
            print("❌ [SYNC] Block not found: \(blockId)")
            return
        }

        cleanupBlock(block)
    }

    /// Récupérer un store actif
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
}
```

**Intégration:**
```swift
// zenloopApp.swift

@main
struct zenloopApp: App {
    init() {
        // ✅ Restaurer tous les blocages au démarrage
        BlockSyncManager.shared.restoreAllBlocks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

---

### Solution #2: Timer de Cleanup Automatique

**Concept:** Vérifier périodiquement les blocs expirés

```swift
// zenloop/Managers/BlockCleanupTimer.swift

class BlockCleanupTimer: ObservableObject {
    private var timer: Timer?
    private let syncManager = BlockSyncManager.shared

    func start() {
        // Vérifier toutes les 30 secondes
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkExpiredBlocks()
        }
    }

    private func checkExpiredBlocks() {
        let blockManager = BlockManager()
        let blocks = blockManager.getActiveBlocks()

        for block in blocks where block.isExpired {
            print("⏰ [CLEANUP] Block expired: \(block.appName)")
            syncManager.unblockApp(blockId: block.id)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
```

---

### Solution #3: Notification Observer

**Concept:** Écouter les changements d'ActiveBlocks

```swift
// Dans FullStatsPageView ou autre

init() {
    // Écouter les changements
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("ActiveBlocksDidChange"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.loadActiveBlocks()
    }
}
```

---

## 🎯 **Plan d'Implémentation Recommandé**

### Phase 1: BlockSyncManager ⭐ (CRITIQUE)
1. ✅ Créer `BlockSyncManager.swift`
2. ✅ Implémenter `restoreAllBlocks()`
3. ✅ Implémenter `cleanupBlock()`
4. ✅ Implémenter `unblockApp()`
5. ✅ Appeler dans `zenloopApp.init()`

### Phase 2: UI Sync
1. ✅ Mettre à jour `FullStatsPageView.loadActiveBlocks()`
2. ✅ Ajouter bouton "Unblock" dans l'UI
3. ✅ Refresh automatique après unblock

### Phase 3: Auto-Cleanup
1. ✅ Implémenter `BlockCleanupTimer`
2. ✅ Démarrer timer dans `ZenloopManager`
3. ✅ Arrêter timer sur app background

### Phase 4: Tests
1. ✅ Test: Bloquer app → Kill app → Relaunch → Vérifier affichage
2. ✅ Test: Attendre expiration → Vérifier cleanup automatique
3. ✅ Test: Débloquer manuellement → Vérifier unblock immédiat

---

## 🔍 **Apple Documentation Research**

### ManagedSettingsStore Behavior

D'après la documentation Apple:
> "A `ManagedSettingsStore` persists settings even after your app terminates. The system enforces the settings until you explicitly clear them."

**Implications:**
- ✅ Les stores persistent automatiquement
- ⚠️ MAIS l'app ne "voit" plus les stores après restart
- ✅ Il faut réinstancier avec le MÊME nom pour y accéder
- ⚠️ `clearAllSettings()` est NÉCESSAIRE pour débloquer

### Best Practices
1. **Toujours utiliser des noms unique** pour les stores ✅ (déjà fait)
2. **Garder une référence** des stores actifs ⚠️ (manque)
3. **Nettoyer explicitement** avec `clearAllSettings()` ⚠️ (manque)
4. **Synchroniser au démarrage** ❌ (pas implémenté)

---

## 📊 **Impact Estimation**

### Sans Fix
- ❌ Apps restent bloquées indéfiniment
- ❌ User frustré (ne peut pas débloquer)
- ❌ Bug critique pour production
- ❌ Potentiel App Store rejection

### Avec Fix
- ✅ Sync automatique au démarrage
- ✅ Cleanup automatique des blocs expirés
- ✅ Déblocage manuel fonctionnel
- ✅ Expérience utilisateur fluide
- ✅ Production-ready

---

## 🚀 **Prochaines Étapes**

1. **Implémenter BlockSyncManager** (30min)
2. **Intégrer dans zenloopApp.init()** (5min)
3. **Ajouter UI unblock button** (15min)
4. **Tester end-to-end** (20min)
5. **Documenter pour l'équipe** (10min)

**Temps total estimé:** ~1h30

---

**Status:** 🔴 CRITIQUE - À implémenter immédiatement
**Priority:** P0 - Bloquant pour production
