# Architecture Finale des Blocages d'Apps

## ❌ PROBLÈME FONDAMENTAL DÉCOUVERT

Les **extensions DeviceActivity (Report)** sont **READ-ONLY** et **NE PEUVENT PAS** créer ou modifier des `ManagedSettingsStore`. C'est une limitation d'Apple non documentée clairement.

### Ce qui NE marche PAS :
```swift
// ❌ DANS UNE EXTENSION DeviceActivity
let store = ManagedSettingsStore(named: .init("store_name"))
store.shield.applications = blockedApps  // ❌ N'A AUCUN EFFET !
```

Les `ManagedSettingsStore` créés depuis une extension DeviceActivity **ne persistent pas** et disparaissent dès que l'extension se ferme.

## ✅ SOLUTION : ARCHITECTURE DE COMMANDES

### Flux correct :

```
1. Extension DeviceActivity (zenloopactivity)
   ├── Encode le token de l'app (FamilyActivitySelection)
   ├── Sauvegarde dans App Group avec tokenData
   └── Envoie une COMMANDE à l'app principale

2. App Principale (zenloop)
   ├── BlockCommandCoordinator écoute les commandes
   ├── Récupère le block avec tokenData
   ├── Décode le token
   └── APPLIQUE le ManagedSettingsStore (persiste !)
```

### Composants clés :

#### 1. Dans l'Extension (`FullStatsPageView.swift`) :
```swift
private func blockApp() {
    // 1. Encoder le token
    var selection = FamilyActivitySelection()
    selection.applicationTokens = [app.token]
    let tokenData = try JSONEncoder().encode(selection)

    // 2. Sauvegarder avec tokenData
    let block = blockManager.addBlock(
        appName: app.name,
        duration: duration,
        tokenData: tokenData  // ✅ CRUCIAL
    )

    // 3. Envoyer commande à l'app principale
    let command = BlockCommand.addBlock(
        appName: app.name,
        duration: duration,
        context: "DeviceActivityExtension"
    )
    blockManager.sendCommand(command)
}
```

#### 2. Dans l'App Principale (`BlockCommandCoordinator.swift`) :
```swift
private func handleAddBlock(appName: String, duration: TimeInterval, context: String) {
    // 1. Trouver le block avec tokenData
    let recentBlock = blocks.first { block in
        block.appName == appName &&
        !block.appTokenData.isEmpty &&  // ✅ A le token
        (Date().timeIntervalSince1970 - block.startDate) < 10
    }

    if let block = recentBlock {
        // 2. Décoder le token
        guard let token = block.getApplicationToken() else { return }

        // 3. APPLIQUER le ManagedSettingsStore (persiste !)
        let store = ManagedSettingsStore(named: .init(block.storeName))
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(token)
        store.shield.applications = blockedApps  // ✅ FONCTIONNE !
    }
}
```

#### 3. Communication (`BlockManager.swift`) :
```swift
func sendCommand(_ command: BlockCommand) {
    // Sauvegarde dans App Group
    suite?.set(data, forKey: commandsKey)

    // Notification Darwin pour réveiller l'app
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName("com.app.zenloop.newCommand"),
        nil, nil, true
    )
}
```

## 📋 Résumé des changements

### ✅ Ce qui a été fait :

1. **Suppression de BlockSyncHelper** - Ne fonctionnait pas car l'extension ne peut pas créer de ManagedSettingsStore

2. **Refactoring de FullStatsPageView** :
   - N'essaie plus de créer des ManagedSettingsStore
   - Envoie des commandes à l'app principale

3. **Amélioration de BlockCommandCoordinator** :
   - Récupère les blocks avec tokenData
   - Décode et applique les blocages

4. **Architecture de commandes** :
   - Extension → Commande → App Principale
   - Darwin Notifications pour communication inter-process

### 🔑 Points CRITIQUES :

1. **TokenData obligatoire** : Sans le token encodé, l'app principale ne peut pas bloquer

2. **Timing serré** : L'extension crée le block PUIS envoie la commande. L'app principale cherche un block créé dans les 10 dernières secondes

3. **Double persistance** : UserDefaults + FileManager pour fiabilité

4. **Seules peuvent bloquer** :
   - L'app principale ✅
   - Les extensions Monitor ✅
   - Les extensions DeviceActivity ❌

## 🎯 Résultat

Les blocages persistent maintenant correctement car ils sont créés par l'app principale qui a les permissions nécessaires, et non plus par l'extension DeviceActivity qui ne peut que lire et afficher.

## 🔧 Debug

Si les blocages ne persistent toujours pas :

1. Vérifier que `BlockCommandCoordinator.startMonitoring()` est appelé au démarrage (ligne 76 de `zenloopApp.swift`)

2. Vérifier les logs :
   ```
   📤 [BLOCK_SHEET] Command sent to main app for blocking
   📬 [COORDINATOR] Darwin notification received!
   🔒 [COORDINATOR] ManagedSettingsStore applied
   ```

3. Vérifier que le tokenData est bien encodé et stocké

4. S'assurer que l'app principale est en arrière-plan (pas terminée) pour recevoir les commandes