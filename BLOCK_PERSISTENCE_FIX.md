# Fix de Persistance des Blocages dans l'Extension DeviceActivity

## Problème Identifié

Dans l'extension DeviceActivity (`FullStatsPageView`), les blocages d'apps perdaient leurs références après fermeture de l'extension car :

1. **Cycles de vie différents** : L'extension et l'app principale ont des durées de vie indépendantes
2. **ManagedSettingsStore volatils** : Les références aux stores étaient perdues en mémoire
3. **Pas de restauration** : Les blocages n'étaient pas restaurés au lancement de l'extension

## Solution Implémentée

### 1. Système de Persistance des Tokens

Les tokens d'apps sont maintenant encodés et stockés dans `appTokenData` via `FamilyActivitySelection` :

```swift
// Dans ActiveBlock
let appTokenData: Data  // Token persisté

// Méthode pour récupérer le token
func getApplicationToken() -> ApplicationToken? {
    guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: appTokenData) else {
        return nil
    }
    return selection.applicationTokens.first
}
```

### 2. BlockSyncHelper pour l'Extension

Nouveau helper (`BlockSyncHelper.swift`) qui :
- **Restaure automatiquement** les blocages actifs au démarrage de l'extension
- **Maintient un cache** des ManagedSettingsStore actifs
- **Nettoie** les blocages expirés périodiquement

```swift
class BlockSyncHelper {
    // Restaure tous les blocages au démarrage
    func restoreActiveBlocks()

    // Nettoie les blocages expirés
    func cleanupExpiredBlocks()

    // Ajoute un nouveau blocage au cache
    func onNewBlockAdded(_ block: ActiveBlock)
}
```

### 3. Intégration dans FullStatsPageView

- **Au chargement** : Restauration automatique des blocages
- **Timer périodique** : Vérification toutes les 30 secondes
- **Après blocage** : Mise à jour immédiate du cache

```swift
.onAppear {
    prepareContent()
    startBlockRefreshTimer()  // Timer de vérification
}

private func prepareContent() {
    BlockSyncHelper.shared.restoreActiveBlocks()  // Restauration
    loadActiveBlocks()
}
```

### 4. Gestion du Déblocage

Nouvelle sheet `UnblockAppSheet.swift` pour :
- Débloquer manuellement une app
- Nettoyer le ManagedSettingsStore
- Mettre à jour le storage partagé

## Architecture de Persistance

```
App Group (UserDefaults + FileManager)
    ↓
[ActiveBlock avec tokenData encodé]
    ↓
Extension démarre → BlockSyncHelper.restoreActiveBlocks()
    ↓
Décode tokenData → Récupère ApplicationToken
    ↓
Réapplique ManagedSettingsStore.shield.applications
```

## Points Clés

1. **Double persistance** : UserDefaults + FileManager pour fiabilité
2. **Token encodé** : Survit aux redémarrages via `FamilyActivitySelection`
3. **Restauration automatique** : À chaque lancement de l'extension
4. **Nettoyage périodique** : Timer pour gérer les expirations

## Résultat

✅ Les blocages persistent après fermeture de l'extension
✅ Les références aux apps bloquées sont maintenues
✅ Le déblocage fonctionne depuis l'extension
✅ Les blocages expirés sont nettoyés automatiquement