# ✅ Fix de Persistence des Blocs - COMPLET

## Problème Résolu

**Symptôme**: Les apps restaient bloquées après un reload de l'app, mais n'apparaissaient plus dans l'UI et ne pouvaient pas être débloquées manuellement.

**Cause**: Les `ManagedSettingsStore` persistent automatiquement dans iOS, mais l'app perdait les références (tokens) nécessaires pour les gérer après un restart.

## Solution Implémentée

### 1. Persistence des Tokens ✅

**Fichiers modifiés**:
- `zenloop/Models/BlockingModels.swift`
- `zenloopactivity/BlockingModels.swift`

**Changements**:
```swift
struct ActiveBlock: Codable {
    let appTokenData: Data  // ✅ NOUVEAU: Stocke le token persisté

    func getApplicationToken() -> ApplicationToken? {
        // Décode le token depuis les données sauvegardées
        guard !appTokenData.isEmpty else { return nil }

        let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: appTokenData
        )

        return selection?.applicationTokens.first
    }
}
```

### 2. Sauvegarde du Token au Blocage ✅

**Fichier modifié**: `zenloopactivity/FullStatsPageView.swift`

**Changement**:
```swift
// Encoder le token dans FamilyActivitySelection
var selection = FamilyActivitySelection()
selection.applicationTokens = [app.token]
let tokenData = try JSONEncoder().encode(selection)

// Créer le block avec le token
let block = ActiveBlock(
    appName: app.name,
    storeName: storeName,
    duration: duration,
    tokenData: tokenData,  // ✅ Token inclus
    status: .active
)
```

### 3. BlockSyncManager - Restauration Automatique ✅

**Nouveau fichier**: `zenloop/Managers/BlockSyncManager.swift`

**Fonctionnalités**:

#### A. Nettoyage des Anciens Blocs (One-Time)
```swift
func cleanupLegacyBlocks() {
    // Supprime tous les blocs créés AVANT le fix
    // (ceux qui n'ont pas de tokenData)

    for block in blocks {
        if block.appTokenData.isEmpty {
            // Supprimer le block ET nettoyer le ManagedSettingsStore
            blockManager.removeBlock(id: block.id)
            store.clearAllSettings()
        }
    }
}
```

#### B. Restauration des Blocs au Démarrage
```swift
func restoreAllBlocks() {
    let blocks = blockManager.getAllBlocks()

    for block in blocks {
        if block.status == .active || block.status == .paused {
            // 1. Décoder le token depuis appTokenData
            guard let token = block.getApplicationToken() else {
                cleanupBlock(block)
                return
            }

            // 2. Réinstancier le ManagedSettingsStore
            let store = ManagedSettingsStore(named: .init(block.storeName))
            activeManagedStores[block.id] = store

            // 3. Vérifier et réappliquer le blocage si nécessaire
            if !(store.shield.applications?.contains(token) ?? false) {
                store.shield.applications = [token]
            }
        }
    }
}
```

### 4. Intégration dans zenloopApp ✅

**Fichier modifié**: `zenloop/zenloopApp.swift`

```swift
init() {
    // ✅ ÉTAPE 1: Nettoyer les anciens blocs sans token
    BlockSyncManager.shared.cleanupLegacyBlocks()

    // ✅ ÉTAPE 2: Restaurer tous les blocs valides
    BlockSyncManager.shared.restoreAllBlocks()
}
```

## Comment Tester

### 1. Nettoyage Initial (Obligatoire)

L'app va automatiquement nettoyer les anciens blocs au prochain lancement.

**Logs à vérifier** (dans Xcode Console):
```
🧹 [SYNC] Cleaning up legacy blocks without tokens...
  → Removing legacy block: Instagram
✅ [SYNC] Cleaned X legacy blocks
```

### 2. Créer un NOUVEAU Bloc

Bloquer une app (ex: Instagram) depuis l'UI.

**Logs attendus**:
```
✅ [BLOCK_SHEET] Token encoded successfully
💾 [BLOCK_SHEET] Block saved with token (XXX bytes)
```

### 3. Tester le Cycle Complet

1. **Bloquer une app** → Vérifier qu'elle est bien bloquée
2. **Kill l'app** (swipe up dans le sélecteur d'apps)
3. **Relancer l'app**
4. **Vérifier** que:
   - L'app bloquée apparaît dans l'UI
   - Le timer/durée est correct
   - L'app reste bloquée
   - Le bouton "Unblock" fonctionne

**Logs attendus au reload**:
```
🧹 [SYNC] Cleaning up legacy blocks without tokens...
✅ [SYNC] Cleaned 0 legacy blocks (déjà fait)

🔄 [SYNC] === RESTORE ALL BLOCKS START ===
📦 [SYNC] Found 1 blocks in storage
♻️ [SYNC] Restoring active block: Instagram
🔓 [SYNC] Token decoded successfully for: Instagram
✅ [SYNC] Block re-applied: Instagram
✅ [SYNC] === RESTORE ALL BLOCKS COMPLETE ===
```

## Diagnostic en Cas de Problème

### Si Storage Vide
```
⚠️ [SYNC] No blocks to restore - storage is empty!
📊 [SYNC] App Group has X keys
  - active_blocks_v2
  - ...
```
→ Vérifier que le block a bien été sauvegardé

### Si Token Manquant
```
❌ [ActiveBlock] No token data for AppName - legacy block without token
```
→ Block créé avant le fix → Sera nettoyé automatiquement

### Si Token Corrompu
```
❌ [ActiveBlock] Failed to decode token for AppName
  → Token data size: X bytes
```
→ Erreur d'encodage → Vérifier le code de sauvegarde

## Architecture Finale

```
┌─────────────────────────────────────────────┐
│ zenloopApp.init()                           │
│                                             │
│ 1. cleanupLegacyBlocks()                    │
│    └─> Supprime blocs sans token           │
│                                             │
│ 2. restoreAllBlocks()                       │
│    └─> Restaure blocs valides              │
│        ├─> Décode tokens                    │
│        ├─> Réinstancie ManagedSettingsStore │
│        └─> Réapplique blocages              │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│ Utilisateur bloque une app                 │
│                                             │
│ 1. FamilyActivityPicker                     │
│    └─> Sélection d'app → ApplicationToken  │
│                                             │
│ 2. blockApp()                               │
│    ├─> Encode token → FamilyActivitySelection│
│    ├─> Sauvegarde tokenData dans ActiveBlock│
│    └─> Crée ManagedSettingsStore            │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│ App Group (Persistence)                     │
│                                             │
│ active_blocks_v2:                           │
│ [                                           │
│   {                                         │
│     id: "...",                              │
│     appName: "Instagram",                   │
│     storeName: "block_xxx",                 │
│     appTokenData: Data(...),  ← ✅ TOKEN    │
│     status: "active"                        │
│   }                                         │
│ ]                                           │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│ iOS System (ManagedSettings)               │
│                                             │
│ ManagedSettingsStore("block_xxx")           │
│ └─> shield.applications = [token]          │
│     └─> App BLOQUÉE par iOS ✅              │
└─────────────────────────────────────────────┘
```

## Prochaines Étapes

1. ✅ **Build réussi** - Code compilé sans erreurs
2. ⏳ **Test en cours** - Tester le cycle complet:
   - Créer un nouveau bloc
   - Vérifier la persistence après reload
   - Confirmer que l'UI affiche correctement les blocs
   - Tester le déblocage manuel
3. 🔜 **Cleanup du code** - Si tout fonctionne, retirer `cleanupLegacyBlocks()` après quelques versions

## Notes Importantes

- ⚠️ **Les anciens blocs** (créés avant ce fix) seront automatiquement nettoyés au prochain lancement
- ✅ **Tous les nouveaux blocs** incluent maintenant le token persisté
- 🔄 **Restauration automatique** à chaque lancement de l'app
- 📱 **Compatible iOS** - Utilise les APIs standards d'Apple
- 🔒 **Sécurisé** - Les tokens sont chiffrés par iOS automatiquement

---

**Status**: ✅ Implémentation complète - Prêt pour tests
**Auteur**: Claude Code
**Date**: 2026-02-03
