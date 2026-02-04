# 🐛 Debug : Perte de Référence après Reload

## 🔴 Problème Actuel

Après avoir bloqué une app :
1. ✅ Le shield est appliqué (l'app est bloquée)
2. ✅ L'UI montre "Bloquée"
3. ❌ **Après reload de l'app → La référence est perdue**

**Symptôme** : `loadActiveBlocks()` retourne un tableau vide

---

## 🔍 Logs de Debugging Ajoutés

### Dans BlockAppSheet (lors de la création)

```
📝 [BLOCK_SHEET] Creating BlockManager instance...
➕ [BLOCK_SHEET] Adding block to BlockManager...
✅ [BLOCK_SHEET] Block added with ID: ABC-123
   → App: Instagram
   → Duration: 15 minutes
   → Status: active
   → StoreName: block_XYZ
🔗 [BLOCK_SHEET] StoreName linked: block-ABC-123-DEF
🔍 [BLOCK_SHEET] Verifying block was saved...
📊 [BLOCK_SHEET] Total blocks in storage: 1
✅ [BLOCK_SHEET] Block found in storage - SAVE OK
💾 [BLOCK_SHEET] Block registered in BlockManager: ABC-123
```

### Dans FullStatsPageView (lors du chargement)

```
🔍 [FULLSTATS] === LOADING ACTIVE BLOCKS ===
📊 [FULLSTATS] Found 0 active blocks
⚠️ [FULLSTATS] No active blocks found!
   This could mean:
   1. No blocks were created
   2. BlockManager failed to save
   3. BlockManager failed to read from App Group
```

---

## 🧪 Scénarios de Test

### Test 1 : Vérifier la Sauvegarde Immédiate

**Actions** :
1. Bloquer une app
2. Observer les logs `[BLOCK_SHEET]`

**Logs à chercher** :
```
✅ [BLOCK_SHEET] Block found in storage - SAVE OK
```

**Si absent** → Le BlockManager ne sauvegarde pas correctement

**Si présent** → Le problème est lors du chargement

---

### Test 2 : Vérifier le Chargement Immédiat

**Actions** :
1. Bloquer une app
2. Sans reloader, regarder la section "Apps Bloquées"

**Résultat attendu** :
- ✅ La section apparaît
- ✅ L'app est listée avec compteur

**Si échec** → `loadActiveBlocks()` ne lit pas correctement

---

### Test 3 : Vérifier la Persistence après Reload

**Actions** :
1. Bloquer une app
2. Fermer complètement l'app (swipe kill)
3. Réouvrir l'app
4. Observer les logs `[FULLSTATS]`

**Logs à chercher** :
```
📊 [FULLSTATS] Found 0 active blocks
```

**Si 0** → Les données ne persistent pas dans l'App Group

---

## 🔎 Causes Possibles

### Cause 1 : App Group Non Configuré Correctement

**Vérifier** :
```swift
let suite = UserDefaults(suiteName: "group.com.app.zenloop")
print("Suite accessible: \(suite != nil)")
```

**Si false** → Vérifier dans Xcode :
- Target → Signing & Capabilities → App Groups
- `group.com.app.zenloop` doit être coché

---

### Cause 2 : Extension vs App Utilisent des Stores Différents

**Dans BlockManager (ligne 204)** :
```swift
self.suite = UserDefaults(suiteName: "group.com.app.zenloop")
```

**Vérifier** que :
- BlockAppSheet utilise le même App Group ID
- FullStatsPageView utilise le même App Group ID
- Pas de typo dans "group.com.app.zenloop"

---

### Cause 3 : Données Écrasées ou Nettoyées

**Possibilité** : Un autre process nettoie les blocks

**Chercher dans le code** :
```bash
grep -r "removeBlock\|clearBlocks\|active_blocks_v2" zenloop/
```

**Suspect** :
- Un cleanup automatique trop agressif
- Un autre flow qui réinitialise les blocks

---

### Cause 4 : Simulateur vs Device

**Sur Simulateur** : UserDefaults peut être instable

**Vérifier dans BlockManager.swift:420-434** :
```swift
// DOUBLE PERSISTENCE: UserDefaults + FileManager
```

Le code sauvegarde aussi dans un fichier. Vérifier que ce fichier persiste :

**Logs à chercher** :
```
💾 [BlockManager] Sauvegarde FILE réussie: /path/to/active_blocks_v2.json
```

---

## 🔧 Vérifications à Faire

### 1. Vérifier l'App Group Container

Ajouter ce log dans `BlockManager.init()` :

```swift
if let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.app.zenloop"
) {
    print("📁 [BlockManager] Container: \(containerURL.path)")
    print("📁 [BlockManager] Exists: \(FileManager.default.fileExists(atPath: containerURL.path))")
} else {
    print("❌ [BlockManager] Cannot access App Group container!")
}
```

---

### 2. Vérifier les Permissions

Dans `BlockingModels.swift`, BlockManager utilise :

```swift
// 1. UserDefaults
suite?.set(data, forKey: key)

// 2. FileManager
try data.write(to: fileURL, options: [.atomic])
```

**Vérifier** que les deux fonctionnent.

---

### 3. Vérifier le Timing

**Possibilité** : Le reload se fait AVANT que la sauvegarde soit complète

**Solution** : Ajouter `suite?.synchronize()` après chaque sauvegarde

Dans BlockManager.save() (ligne 435) :
```swift
suite?.synchronize()  // Force immediate write
```

---

## 🎯 Plan d'Action

### Étape 1 : Lancer l'app avec logs activés
```bash
# Console app → Filter: [BLOCK
# Ou terminal:
log stream --predicate 'subsystem == "com.app.zenloop"' --level debug
```

### Étape 2 : Bloquer une app
Observer :
```
✅ [BLOCK_SHEET] Block found in storage - SAVE OK
```

### Étape 3 : Sans reloader, vérifier l'UI
La section "Apps Bloquées" devrait apparaître

**Si non** → Problème de synchronisation entre BlockManager et UI

### Étape 4 : Reloader l'app
Observer :
```
🔍 [FULLSTATS] === LOADING ACTIVE BLOCKS ===
📊 [FULLSTATS] Found X active blocks
```

**Si 0** → Problème de persistence

---

## 💡 Solutions Potentielles

### Solution 1 : Forcer la Synchronisation

Dans `BlockManager.save()` :
```swift
suite?.set(data, forKey: key)
suite?.synchronize()  // ← AJOUTER

// ET vérifier immédiatement
let verify = suite?.data(forKey: key)
print("✅ Verification: \(verify != nil ? "\(verify!.count) bytes" : "FAILED")")
```

---

### Solution 2 : Utiliser NotificationCenter

Quand un block est ajouté, notifier l'UI :

```swift
// Dans BlockManager.save()
NotificationCenter.default.post(
    name: NSNotification.Name("ActiveBlocksDidChange"),
    object: nil
)

// Dans FullStatsPageView.onAppear
NotificationCenter.default.addObserver(
    forName: NSNotification.Name("ActiveBlocksDidChange"),
    object: nil,
    queue: .main
) { _ in
    loadActiveBlocks()
}
```

---

### Solution 3 : Debugging FileManager Fallback

Si UserDefaults échoue, BlockManager utilise FileManager.

**Vérifier le fichier** :
```bash
# Sur simulateur
xcrun simctl get_app_container booted com.app.zenloop data

# Naviguer vers:
# /Library/Group Containers/group.com.app.zenloop/active_blocks_v2.json
```

**Le fichier existe ?**
- Oui → UserDefaults ne lit pas le fichier
- Non → La sauvegarde échoue complètement

---

## 📋 Checklist de Debugging

- [ ] Logs `[BLOCK_SHEET]` montrent "SAVE OK"
- [ ] Logs `[BlockManager]` montrent "Sauvegarde réussie"
- [ ] App Group est configuré dans tous les targets
- [ ] Le même App Group ID est utilisé partout
- [ ] `suite?.synchronize()` est appelé après save
- [ ] FileManager fallback fonctionne
- [ ] Aucun cleanup automatique n'interfère
- [ ] L'UI reçoit bien les notifications de changement

---

**Prochaine étape** : Lancer l'app, bloquer une app, et analyser les logs pour identifier exactement où ça casse.

**Date** : 2026-02-04
**Branch** : `feature/immediate-shield-application`
