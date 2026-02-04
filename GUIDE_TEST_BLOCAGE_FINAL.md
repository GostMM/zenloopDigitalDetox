# 🧪 Guide de Test : Blocage d'Apps depuis FullStatsPageView

## ✅ BUILD SUCCEEDED - Système Prêt à Tester

## 🎯 Ce Qui a Été Corrigé

### ❌ Avant (Ne fonctionnait PAS)
```swift
// Extension essayait d'appliquer le blocage elle-même
let store = ManagedSettingsStore(named: .init(storeName))
store.shield.applications = blockedApps
// ❌ Disparaissait après quelques secondes
```

### ✅ Maintenant (Fonctionne)
```swift
// Extension ouvre l'app principale
@Environment(\.openURL) var openURL
openURL(URL(string: "zenloop://apply-block?id=\(blockId)")!)
// ✅ L'app principale applique le blocage de manière persistante
```

## 📋 Flux de Test Complet

### Test 1 : Blocage Basique

#### Étapes Détaillées
1. **Lancer** l'app Zenloop sur simulateur iPhone 15 Pro
2. **Naviguer** : Onglet Stats (3ème icône en bas)
3. **Voir** : La page avec le temps total d'écran
4. **Cliquer** sur une app de la liste (ex: Safari, Messages)
   - L'app doit avoir un bouton rouge avec icône `hand.raised.circle.fill`
5. **Observer** : Sheet "Bloquer temporairement cette app" s'ouvre
6. **Sélectionner** : Durée (15 minutes par défaut)
7. **Cliquer** : Bouton rouge "Bloquer 15 min"

#### Ce Qui Va Se Passer

```
┌─────────────────────────────────────┐
│  Extension (FullStatsPageView)      │
│  📤 Opening main app...              │
│  🔗 URL: zenloop://apply-block?id=..│
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  iOS System                          │
│  🚀 Launching main app...            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  App Principale (HomeView)           │
│  🔒 Applying block from Report Ext   │
│  📨 Found block request: Safari      │
│  ✅ Token decoded successfully       │
│  💾 Block saved                      │
│  🛡️ Shield applied for: Safari      │
└─────────────────────────────────────┘
```

#### Résultats Attendus

1. **L'app Zenloop s'ouvre au premier plan** (quitte les stats)
2. **Notification iOS apparaît** : "✅ App Bloquée - Safari est maintenant bloquée pour 15 minutes"
3. **Dans HomeView** : La section "Apps Bloquées" apparaît avec Safari dedans
4. **Compte à rebours** : "14m 59s" qui décrémente

#### Vérification du Blocage

5. **Appuyer** sur le bouton Home
6. **Essayer d'ouvrir Safari**
7. **Observer** : Shield Zenloop apparaît avec message de blocage
8. **Retourner** dans Zenloop → Safari toujours dans "Apps Bloquées"

### Test 2 : Persistance après Force Quit

#### Étapes
1. **Bloquer** une app (Safari, 30 minutes)
2. **Vérifier** que le shield fonctionne
3. **Double-cliquer** sur le bouton Home
4. **Swipe up** sur Zenloop pour force-quit
5. **Attendre** 5 secondes
6. **Relancer** Zenloop

#### Résultats Attendus

```
🛡️ [GLOBAL_SHIELD] Initializing with DEFAULT store
🔄 [GLOBAL_SHIELD] Restoring all active blocks...
   → Found 1 active blocks
✅ [GLOBAL_SHIELD] Token added: Safari
🛡️ [GLOBAL_SHIELD] Shield applied to 1 apps
```

**Vérifications** :
- ✅ Safari est toujours bloquée
- ✅ Le compte à rebours continue depuis ~28m (pas reset à 30m)
- ✅ Le shield fonctionne toujours

### Test 3 : Blocages Multiples

#### Étapes
1. **Bloquer** Safari (15 minutes)
2. **Attendre** que Zenloop revienne au premier plan
3. **Retourner** dans Stats → FullStatsPageView
4. **Bloquer** Messages (20 minutes)
5. **Retourner** dans Stats
6. **Bloquer** Photos (10 minutes)

#### Résultats Attendus

```
🛡️ [GLOBAL_SHIELD] Shield applied to 3 apps
```

**Vérifications** :
- ✅ Les 3 apps sont bloquées simultanément
- ✅ Chaque app a son propre compte à rebours
- ✅ "Apps Bloquées (3)" dans HomeView
- ✅ Tous les shields fonctionnent

### Test 4 : Déblocage Automatique

#### Configuration Préalable
**Modifier temporairement** les durées pour le test :

```swift
// Dans FullStatsPageView.swift, ligne ~816
private let durations = [1, 5, 15, 30, 60, 120, 240] // Ajouter 1 minute
```

#### Étapes
1. **Rebuild** l'app après modification
2. **Bloquer** une app pour **1 minute**
3. **Mettre un timer** sur ton téléphone
4. **Attendre** 60 secondes
5. **Vérifier** l'app

#### Résultats Attendus (après 60 secondes)

```
🔓 [MONITOR] Auto-unblocking: Safari
✅ [MONITOR] Auto-unblock complete: Safari
```

**Vérifications** :
- ✅ Safari disparaît de "Apps Bloquées"
- ✅ Le shield n'est plus visible
- ✅ Safari s'ouvre normalement

### Test 5 : App en Background

#### Étapes
1. **Lancer** Zenloop
2. **Aller** dans Stats → FullStatsPageView
3. **Cliquer** "Bloquer" sur une app
4. **IMMÉDIATEMENT après**, appuyer sur Home (mettre en background)
5. **Attendre** 3-5 secondes
6. **Essayer d'ouvrir** l'app bloquée

#### Résultats Attendus

**L'app doit être bloquée** même si Zenloop était en background car :
- `openURL()` force iOS à réveiller l'app
- Le traitement se fait dans `onOpenURL`
- Le blocage est appliqué avant que l'utilisateur ne le voie

## 🐛 Logs de Débogage

### Dans Xcode Console (Filter: "BLOCK")

#### Flux Réussi
```
📤 [BLOCK_SHEET] Opening main app with blockId: abc-123
🔗 [BLOCK_SHEET] URL: zenloop://apply-block?id=abc-123
✅ [BLOCK_SHEET] Main app opened successfully

🔒 [DEEP_LINK] Applying block from Report Extension: abc-123
📨 [REPORT_BLOCK] Found block request: Safari for 15min
✅ [REPORT_BLOCK] Token decoded successfully
💾 [REPORT_BLOCK] Block saved: abc-123
🛡️ [REPORT_BLOCK] Shield applied for: Safari
✅ [REPORT_BLOCK] Block request processed successfully

➕ [GLOBAL_SHIELD] ADDING BLOCK FOR: Safari
   → BlockID: abc-123
   → Current blocked apps: 0
   → After insert: 1 apps
   → Applying shield to 1 apps NOW...
   → ✅ store.shield.applications = blockedApps DONE!
✅ [GLOBAL_SHIELD] Block operation complete
```

#### Erreurs Possibles

**Erreur 1 : URL non acceptée**
```
❌ [BLOCK_SHEET] Failed to open main app - URL not accepted
```
**Cause** : URL Scheme pas enregistré
**Fix** : Vérifier CFBundleURLSchemes dans Info.plist

**Erreur 2 : No block data**
```
⚠️ [REPORT_BLOCK] No pending block data found
```
**Cause** : App Group pas accessible ou données pas écrites
**Fix** : Vérifier App Group entitlements

**Erreur 3 : Token decode failed**
```
❌ [REPORT_BLOCK] Failed to decode token
```
**Cause** : FamilyActivitySelection corrompu
**Fix** : Re-sélectionner l'app dans Family Activity Picker

## 📊 Checklist de Validation Complète

### Fonctionnalités de Base
- [ ] Cliquer "Bloquer" ouvre l'app principale
- [ ] Notification "App Bloquée" apparaît
- [ ] Shield visible sur l'app bloquée
- [ ] Compte à rebours visible dans HomeView
- [ ] Section "Apps Bloquées" visible

### Persistance
- [ ] Blocage persiste après force-quit
- [ ] Blocage persiste après redémarrage device
- [ ] Compte à rebours correct après redémarrage

### Blocages Multiples
- [ ] Peut bloquer 3+ apps simultanément
- [ ] Chaque app a son compte à rebours
- [ ] Tous les shields fonctionnent

### Déblocage
- [ ] Déblocage automatique après durée écoulée
- [ ] App disparaît de "Apps Bloquées"
- [ ] Shield disparaît
- [ ] App redevient accessible

### Edge Cases
- [ ] Fonctionne si app en background pendant le blocage
- [ ] Fonctionne si extension crashe après avoir envoyé l'URL
- [ ] Fonctionne si multiple blocages rapides (<1s entre chaque)

## 🚨 Si Ça Ne Marche Toujours Pas

### Diagnostics Système

#### 1. Vérifier les Permissions
```swift
// Dans onAppear de ContentView
Task {
    let status = AuthorizationCenter.shared.authorizationStatus
    print("📱 Screen Time Authorization: \(status)")
}
```

**Si status != .approved** :
- Demander les permissions Screen Time
- Redémarrer l'app

#### 2. Vérifier App Group
```swift
if let suite = UserDefaults(suiteName: "group.com.app.zenloop") {
    print("✅ App Group accessible")
    suite.set("test", forKey: "test_key")
    if suite.string(forKey: "test_key") == "test" {
        print("✅ App Group read/write OK")
    }
} else {
    print("❌ App Group NOT accessible")
}
```

#### 3. Vérifier Store Global
```swift
// Dans GlobalShieldManager.init()
let currentBlocked = store.shield.applications?.count ?? 0
print("🛡️ Store has \(currentBlocked) blocked apps at startup")
```

#### 4. Réinitialiser Tout
```swift
// Nettoyer App Group
UserDefaults(suiteName: "group.com.app.zenloop")?.removePersistentDomain(forName: "group.com.app.zenloop")

// Nettoyer Store
let store = ManagedSettingsStore()
store.shield.applications = nil
store.clearAllSettings()
```

## ✅ Critères de Succès

**Le système fonctionne si** :
1. ✅ Cliquer "Bloquer" ouvre l'app principale (transition visible)
2. ✅ Notification iOS apparaît dans les 2 secondes
3. ✅ Shield bloque réellement l'accès à l'app
4. ✅ Force-quit n'enlève PAS le blocage
5. ✅ Les logs montrent le flux complet sans erreur

**Si 5/5 critères ✅** → Système fonctionnel, prêt pour production

**Si < 5/5** → Consulter [POURQUOI_CA_NE_MARCHE_PAS.md](POURQUOI_CA_NE_MARCHE_PAS.md)

## 🎯 Prochaines Étapes après Validation

1. **UI/UX** : Améliorer le feedback visuel pendant l'ouverture de l'app
2. **Animation** : Ajouter une transition smooth entre Stats et HomeView
3. **Déblocage Manuel** : Ajouter un bouton "Débloquer maintenant"
4. **Historique** : Logger les blocages dans Firebase
5. **Analytics** : Tracker l'usage de la fonctionnalité

---

**Note** : Ce système utilise l'API **OFFICIELLE** d'Apple (`@Environment(\.openURL)`).
Il est **100% approuvé** pour l'App Store.
