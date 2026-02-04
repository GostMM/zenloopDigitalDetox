# Guide de Test : Blocage d'Apps depuis Report Extension

## ✅ Compilation : BUILD SUCCEEDED

Le système de blocage depuis `FullStatsPageView` est maintenant opérationnel.

## 🧪 Plan de Test

### Test 1 : Blocage Basique

#### Étapes
1. Lancer l'app Zenloop sur le simulateur
2. Naviguer vers les statistiques (onglet Stats)
3. Appuyer sur l'app pour voir `FullStatsPageView`
4. Cliquer sur une app dans la liste (bouton rouge avec icône main levée)
5. Sélectionner une durée (ex: 15 minutes)
6. Appuyer sur "Bloquer"

#### Résultats Attendus
```
📤 [BLOCK_SHEET] Block request sent to Monitor Extension
   → App: Instagram
   → Duration: 15 minutes
   → BlockID: abc-123
⏰ [BLOCK_SHEET] Notifying main app...
✅ [BLOCK_SHEET] Main app will apply the shield

📬 [MAIN APP] Received block request from Report Extension
📨 [REPORT_BLOCK] Found block request: Instagram for 15min
✅ [REPORT_BLOCK] Token decoded successfully
💾 [REPORT_BLOCK] Block saved: abc-123
🛡️ [REPORT_BLOCK] Shield applied for: Instagram
✅ [REPORT_BLOCK] Block request processed successfully
```

#### Vérifications
- ✅ Notification iOS : "✅ App Bloquée - Instagram est maintenant bloquée pour 15 minutes"
- ✅ L'app Instagram affiche un shield quand on essaie de l'ouvrir
- ✅ Le checkmark vert apparaît dans `FullStatsPageView` à côté d'Instagram
- ✅ La section "Apps Bloquées" apparaît en haut de la page avec Instagram dedans

### Test 2 : Persistance après Redémarrage

#### Étapes
1. Bloquer une app (ex: Instagram) pour 30 minutes
2. **Force-quit** l'app Zenloop (swipe up dans le task manager)
3. Relancer l'app Zenloop

#### Résultats Attendus
```
🛡️ [GLOBAL_SHIELD] Initializing with DEFAULT store (key to persistence)
🔄 [GLOBAL_SHIELD] Restoring all active blocks...
   → Found 1 active blocks
✅ [GLOBAL_SHIELD] Token added: Instagram
🛡️ [GLOBAL_SHIELD] Shield applied to 1 apps
   → Store: DEFAULT (persists across restarts)
```

#### Vérifications
- ✅ Instagram est toujours bloquée après le redémarrage
- ✅ Le compte à rebours continue depuis où il s'était arrêté
- ✅ Le shield est toujours actif sur Instagram

### Test 3 : Blocages Multiples

#### Étapes
1. Bloquer Instagram pour 15 minutes
2. Bloquer TikTok pour 20 minutes
3. Bloquer Twitter pour 10 minutes

#### Résultats Attendus
```
🛡️ [GLOBAL_SHIELD] Shield applied to 3 apps
```

#### Vérifications
- ✅ Toutes les 3 apps sont bloquées simultanément
- ✅ Chacune a son propre compte à rebours
- ✅ Les 3 apps apparaissent dans "Apps Bloquées"

### Test 4 : Déblocage Automatique

#### Étapes
1. Bloquer une app pour **1 minute** (modifier durations dans BlockAppSheet)
2. Attendre 1 minute
3. Vérifier que l'app se débloque automatiquement

#### Résultats Attendus (après 1 minute)
```
🔓 [MONITOR] Auto-unblocking: Instagram
✅ [MONITOR] Auto-unblock complete: Instagram
```

#### Vérifications
- ✅ Instagram est débloquée après 1 minute
- ✅ Le shield disparaît
- ✅ Instagram disparaît de la section "Apps Bloquées"

### Test 5 : App en Background

#### Étapes
1. Lancer Zenloop
2. Aller dans `FullStatsPageView`
3. Bloquer une app
4. **Mettre l'app en background** (swipe home)
5. Attendre 2-3 secondes
6. Vérifier que l'app est bloquée

#### Résultats Attendus
- ✅ Darwin Notification réveille l'app en background
- ✅ Le blocage est appliqué même si l'app n'est pas au premier plan
- ✅ Notification iOS apparaît

## 🐛 Debugging en Cas de Problème

### Console Logs en Temps Réel
```bash
# Terminal 1 : Logs de l'app principale
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.app.zenloop"' --level debug

# Terminal 2 : Logs des extensions
xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "zenloop"' --level debug

# Terminal 3 : Darwin Notifications
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "Darwin"'
```

### Vérifier App Group
```swift
// Dans Xcode Console pendant debug
po UserDefaults(suiteName: "group.com.app.zenloop")?.dictionaryRepresentation()

// Chercher les clés:
// - pending_block_tokenData
// - pending_block_appName
// - active_blocks_v2
```

### Vérifier ManagedSettingsStore
```swift
// Dans zenloopApp.swift, ajouter temporairement dans onAppear:
let store = ManagedSettingsStore()
print("🔍 Current blocked apps: \(store.shield.applications?.count ?? 0)")
```

## 🔧 Problèmes Connus et Solutions

### Problème 1 : "Block not applied"
**Cause** : Darwin Notification non reçue par l'app
**Solution** : Vérifier que l'app a la permission de recevoir des notifications

### Problème 2 : "Shield disappears after restart"
**Cause** : Store nommé au lieu de store par défaut
**Solution** : Vérifier que GlobalShieldManager utilise bien `ManagedSettingsStore()` sans paramètre

### Problème 3 : "Token decode failed"
**Cause** : FamilyActivitySelection corrompu
**Solution** : Vérifier que `tokenData` contient bien un token valide

### Problème 4 : "Multiple blocks don't work"
**Cause** : Store écrasé au lieu d'accumulé
**Solution** : Vérifier que `addBlock()` fait bien `insert()` et pas `=`

## 📊 Métriques de Performance

| Opération | Temps Attendu |
|-----------|---------------|
| Clic sur "Bloquer" → Darwin Notification | < 100ms |
| Darwin Notification → App Wakeup | < 500ms |
| App Wakeup → Shield Applied | < 200ms |
| **Total** | **< 800ms** |

## ✅ Checklist de Validation Complète

- [ ] Blocage depuis FullStatsPageView fonctionne
- [ ] Notification iOS apparaît
- [ ] Shield est visible sur l'app bloquée
- [ ] Compte à rebours fonctionne
- [ ] Persistance après redémarrage
- [ ] Déblocage automatique après durée écoulée
- [ ] Blocages multiples fonctionnent
- [ ] Fonctionne en background
- [ ] Logs sont clairs et détaillés

## 📝 Notes de Debug

- Les logs sont préfixés avec `[REPORT_BLOCK]` pour le traitement depuis Report Extension
- Les logs sont préfixés avec `[GLOBAL_SHIELD]` pour l'application du shield
- Les logs sont préfixés avec `[BLOCK_SHEET]` pour l'UI de blocage
- Chercher "❌" dans les logs pour identifier les erreurs
- Chercher "✅" pour confirmer les succès

## 🚀 Prochaines Étapes

Si tous les tests passent :
1. Tester sur device physique (pas seulement simulateur)
2. Ajouter des analytics pour tracker l'usage
3. Améliorer l'UI du compte à rebours
4. Ajouter la possibilité de débloquer manuellement
5. Ajouter des sons/haptics pour meilleur feedback
