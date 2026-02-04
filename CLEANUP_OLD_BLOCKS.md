# 🧹 Nettoyage des Anciens Blocs

## Problème Détecté

Les blocs créés AVANT notre fix n'ont pas de `tokenData`, donc ils ne peuvent pas être restaurés après un restart.

## Solution Immédiate

### Option 1: Nettoyer les Anciens Blocs (Recommandé)

Ajouter cette fonction temporaire dans `BlockSyncManager` :

```swift
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
```

Puis l'appeler dans `zenloopApp.init()` :

```swift
init() {
    // Nettoyage one-time des anciens blocs
    BlockSyncManager.shared.cleanupLegacyBlocks()

    // Restaurer les blocs valides
    BlockSyncManager.shared.restoreAllBlocks()
}
```

### Option 2: Nettoyer Manuellement via Console

Si tu as accès au simulateur, exécute dans Xcode Console :

```swift
// Dans le debugger Xcode, après avoir pausé l'app
let manager = BlockManager()
let blocks = manager.getAllBlocks()
for block in blocks {
    manager.removeBlock(id: block.id)
}
```

### Option 3: Réinstaller l'App

La plus simple :
1. Désinstaller complètement l'app du simulateur
2. Clean Build Folder (⇧⌘K)
3. Rebuild et Run

Cela efface tout l'App Group et repart de zéro.

## Test du Nouveau Système

Une fois les anciens blocs nettoyés :

1. ✅ Bloquer une nouvelle app (ex: Instagram)
2. ✅ Vérifier dans les logs :
   ```
   ✅ [BLOCK_SHEET] Token encoded successfully
   💾 [BLOCK_SHEET] Block saved with token (XXX bytes)
   ```
3. ✅ Kill l'app
4. ✅ Relancer l'app
5. ✅ Vérifier dans les logs :
   ```
   🔄 [SYNC] === RESTORE ALL BLOCKS START ===
   📦 [SYNC] Found 1 blocks in storage
   ♻️ [SYNC] Restoring active block: Instagram
   🔓 [SYNC] Token decoded successfully for: Instagram
   ✅ [SYNC] Block re-applied: Instagram
   ```
6. ✅ Instagram devrait être bloqué ET visible dans l'UI

## Logs de Diagnostic

Si le problème persiste, cherche ces logs :

### Si Storage Vide :
```
⚠️ [SYNC] No blocks to restore - storage is empty!
📊 [SYNC] App Group has X keys
```

### Si Block Sans Token :
```
❌ [ActiveBlock] No token data for AppName - legacy block without token
```

### Si Token Corrompu :
```
❌ [ActiveBlock] Failed to decode token for AppName
  → Token data size: X bytes
```

### Si Succès :
```
✅ [ActiveBlock] Token decoded successfully for AppName
✅ [SYNC] Block re-applied: AppName
```

## Prochaines Actions

1. Choisir Option 1, 2 ou 3 pour nettoyer
2. Créer un NOUVEAU bloc après le nettoyage
3. Tester le cycle complet : Block → Kill → Reload
4. Vérifier les logs à chaque étape

---

**Status:** En attente de cleanup des anciens blocs
**Action:** Choisir une option de nettoyage ci-dessus
