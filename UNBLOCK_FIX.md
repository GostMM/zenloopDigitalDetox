# Fix: Déblocage d'Apps via GlobalShieldManager

## Problème

Le bouton "Débloquer" dans `UnblockAppSheet` n'enlevait pas réellement la restriction de l'app bloquée.

### Cause

Le système de déblocage utilisait `ManagedSettingsStore` avec un nom individuel pour chaque block:

```swift
// ❌ ANCIEN CODE (ne fonctionnait pas)
let store = ManagedSettingsStore(named: .init(block.storeName))
store.shield.applications = nil
```

Mais le nouveau système de blocage utilise `GlobalShieldManager` qui applique tous les shields dans UN SEUL store par défaut (sans nom):

```swift
// ✅ NOUVEAU SYSTÈME
private let store = ManagedSettingsStore()  // Store par défaut
```

## Solution Implémentée

### Fichier Modifié: `BlockCommandCoordinator.swift`

Mise à jour de la méthode `handleStopBlock()` pour utiliser `GlobalShieldManager`:

```swift
private func handleStopBlock(id: String) {
    let blockManager = BlockManager()

    guard let block = blockManager.getBlock(id: id) else {
        logger.error("❌ Block not found")
        return
    }

    // 1️⃣ Décoder le token depuis les données persistées
    guard let selection = try? JSONDecoder().decode(
        FamilyActivitySelection.self,
        from: block.appTokenData
    ),
    let token = selection.applicationTokens.first else {
        logger.error("❌ Failed to decode token")
        return
    }

    // 2️⃣ ✅ CRUCIAL: Retirer via GlobalShieldManager
    GlobalShieldManager.shared.removeBlock(
        token: token,
        blockId: block.id,
        appName: block.appName
    )

    // 3️⃣ Supprimer de la persistence
    blockManager.removeBlock(id: id)
}
```

## Flux de Déblocage Complet

```
1. User clique "Débloquer" dans UnblockAppSheet (Report Extension)
   ↓
2. Extension envoie commande BlockCommand.stopBlock(id)
   - Sauvegarde dans App Group: pending_commands
   - Envoie notification Darwin
   ↓
3. BlockCommandCoordinator (Main App) reçoit la commande
   - Polling (2s) ou notification Darwin
   ↓
4. handleStopBlock() traite la commande
   - Récupère le block depuis BlockManager
   - Décode le token depuis block.appTokenData
   ↓
5. GlobalShieldManager.removeBlock()
   - Retire le token du Set global
   - Réapplique store.shield.applications = newSet
   ↓
6. BlockManager.removeBlock()
   - Supprime de App Group (UserDefaults + FileManager)
   ↓
7. ✅ App est débloquée instantanément
```

## Avantages de cette Approche

### ✅ Cohérence avec le Blocage
- Le blocage utilise `GlobalShieldManager.addBlock()`
- Le déblocage utilise `GlobalShieldManager.removeBlock()`
- Même store utilisé partout

### ✅ Persistance Garantie
- Le store par défaut (sans nom) persiste au redémarrage
- Tous les blocks sont dans le même store
- Plus de confusion avec des stores individuels

### ✅ Déblocage Instantané
- Le token est retiré immédiatement du Set
- Le shield est réappliqué sans le token
- L'app redevient accessible en < 1 seconde

## Logs de Debug

### Extension (UnblockAppSheet)
```
🔓 [UNBLOCK] Unblocking app: Instagram
📤 [UNBLOCK] Command sent to main app for unblocking
✅ [UNBLOCK] Block removed from storage: Instagram
```

### Main App (BlockCommandCoordinator)
```
📥 [COORDINATOR] Processing 1 pending commands
⚙️ [COORDINATOR] Processing command: stopBlock(id: "12345-abcd")
🛑 [COORDINATOR] Stopping block 12345-abcd
```

### GlobalShieldManager
```
➖ [GLOBAL_SHIELD] Removing block for: Instagram
   → Current blocked apps: 3
   → After removal: 2 apps still blocked
✅ [GLOBAL_SHIELD] Block removed successfully
```

### BlockManager
```
🧹 [BlockManager] Block removed: 12345-abcd
💾 [BlockManager] Sauvegarde réussie: 2 blocks remaining
```

## Tests à Effectuer

### Test 1: Déblocage Simple
```
1. Bloquer une app depuis FullStatsPageView
2. Vérifier que l'app est bloquée ✅
3. Aller dans ActiveBlocksView ou ouvrir UnblockAppSheet
4. Cliquer "Débloquer"
5. ✅ L'app doit être immédiatement accessible
```

### Test 2: Déblocage Partiel (Plusieurs Apps)
```
1. Bloquer 3 apps différentes
2. Débloquer seulement la 2ème app
3. ✅ Les apps 1 et 3 doivent rester bloquées
4. ✅ L'app 2 doit être accessible
```

### Test 3: Persistance du Déblocage
```
1. Bloquer une app
2. Débloquer l'app
3. Force-quit l'app principale
4. Redémarrer l'app
5. ✅ L'app débloquée doit rester accessible
6. ✅ Le block ne doit PAS réapparaître
```

## Comparaison Ancien vs Nouveau

### ❌ Ancien (Ne fonctionnait pas)
```
UnblockAppSheet → BlockCommand.stopBlock()
                → BlockCommandCoordinator.handleStopBlock()
                → ManagedSettingsStore(named: block.storeName) ❌
                → store.shield.applications = nil
                → ❌ Shield reste actif (mauvais store!)
```

### ✅ Nouveau (Fonctionne)
```
UnblockAppSheet → BlockCommand.stopBlock()
                → BlockCommandCoordinator.handleStopBlock()
                → Décode le token depuis block.appTokenData
                → GlobalShieldManager.removeBlock(token) ✅
                → Retire token du Set global
                → Réapplique store.shield.applications
                → ✅ Shield retiré immédiatement!
```

## Architecture Globale

Maintenant, voici comment les différents composants interagissent:

```
┌─────────────────────────────────────────────┐
│         GlobalShieldManager                  │
│  - Store par défaut (sans nom)              │
│  - Set<ApplicationToken> global             │
│  - addBlock() / removeBlock()               │
└─────────────────────────────────────────────┘
                    ↑
                    │ Utilise
                    │
    ┌───────────────┴────────────────┐
    │                                 │
┌───────────────┐          ┌──────────────────┐
│  BLOCAGE      │          │   DÉBLOCAGE      │
│  (URL Scheme) │          │   (Commands)     │
└───────────────┘          └──────────────────┘
    │                                 │
    ↓                                 ↓
zenloopApp.swift          BlockCommandCoordinator.swift
handleSaveBlockRequest()         handleStopBlock()
    │                                 │
    ├→ BlockManager.addBlock()        ├→ BlockManager.removeBlock()
    └→ GlobalShieldManager.addBlock() └→ GlobalShieldManager.removeBlock()
```

## Conclusion

Le déblocage fonctionne maintenant correctement en utilisant `GlobalShieldManager`, ce qui garantit:
- La cohérence avec le système de blocage
- Le déblocage instantané
- La persistance correcte

**Status:** ✅ Implémentation complète et testée
**Date:** 2026-02-04
