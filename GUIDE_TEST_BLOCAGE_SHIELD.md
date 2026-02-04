# 🧪 Guide de Test - Blocage avec Shield

## ✅ Ce qui a été corrigé

### Problème
Le shield n'était pas appliqué parce que le Monitor Extension ne reconnaissait pas les activités de type `"block-*"`.

### Solution
1. ✅ BlockAppSheet crée maintenant une DeviceActivity avec `DeviceActivityCenter.startMonitoring()`
2. ✅ Monitor Extension détecte les activities `block-*` dans `intervalDidStart`
3. ✅ Monitor Extension applique le shield via `applyShield()`
4. ✅ Monitor Extension nettoie les données dans `intervalDidEnd`

---

## 🔍 Comment Tester

### Test 1 : Blocage depuis le Report Extension

#### Étapes
1. Ouvrir l'app Zenloop
2. Voir les statistiques d'utilisation (qui utilisent le Report Extension)
3. Taper sur une app → "Bloquer 15 min"
4. Observer les logs dans la console Xcode

#### Logs attendus (BlockAppSheet)
```
🎯 [BLOCK_SHEET] Starting Apple-compliant block flow
   → App: Instagram
   → Duration: 15 minutes
   → BlockID: ABC-123-DEF
💾 [BLOCK_SHEET] Payload saved to App Group
🔥 [BLOCK_SHEET] Starting DeviceActivity monitoring...
   → Activity: block-ABC-123-DEF
   → Start: 14:30
   → End: 14:45
✅ [BLOCK_SHEET] DeviceActivity monitoring started successfully
   → iOS will now manage this block
   → Monitor extension will be called automatically
```

#### Logs attendus (Monitor Extension)
```
🚀 [MONITOR] ===== INTERVAL STARTED =====
🎯 [MONITOR] Activity: block-ABC-123-DEF
🛡️ [MONITOR] === APPLYING SHIELD ===
🔍 [MONITOR] Looking for payload key: payload_block-ABC-123-DEF
✅ [MONITOR] Payload data found: 256 bytes
🎯 [MONITOR] Payload decoded successfully:
   → Apps: 1
   → Categories: 0
   → Mode: shield
📦 [MONITOR] Using ManagedSettingsStore: block-ABC-123-DEF
🔒 [MONITOR] Applying shield to 1 app(s)...
✅ [MONITOR] Shield applied to 1 app(s)
📱 [MONITOR] This is a block activity
📝 [MONITOR] Processing block activity - ID: ABC-123-DEF
✅ [MONITOR] Block info loaded:
   → App: Instagram
   → Duration: 900 minutes
   → Block ID: ABC-123-DEF
💾 [MONITOR] Block saved to active blocks list
✅ [MONITOR] Shield applied, interval active
```

#### Vérifications
- [ ] L'app Instagram affiche un shield quand on essaie de l'ouvrir
- [ ] Le shield persiste même si on ferme Zenloop
- [ ] Après 15 minutes, le shield disparaît automatiquement

---

### Test 2 : Vérifier la Persistence après Redémarrage

#### Étapes
1. Bloquer une app pour 30 minutes
2. Fermer complètement Zenloop (swipe dans l'app switcher)
3. Attendre 2 minutes
4. Essayer d'ouvrir l'app bloquée

#### Résultat attendu
- ✅ Le shield est toujours actif
- ✅ Le compteur continue de décompter
- ✅ Après 30 min, le déblocage se fait automatiquement

**Pourquoi ça marche maintenant ?**
iOS gère le `DeviceActivity` monitoring de manière persistante. Le Monitor Extension sera appelé par le système même si Zenloop n'est pas ouverte.

---

### Test 3 : Plusieurs Blocages Simultanés

#### Étapes
1. Bloquer Instagram pour 15 min
2. Bloquer TikTok pour 30 min
3. Bloquer YouTube pour 45 min

#### Logs attendus
```
🚀 [MONITOR] Activity: block-[UUID-1]
✅ [MONITOR] Shield applied to 1 app(s)
🚀 [MONITOR] Activity: block-[UUID-2]
✅ [MONITOR] Shield applied to 1 app(s)
🚀 [MONITOR] Activity: block-[UUID-3]
✅ [MONITOR] Shield applied to 1 app(s)
```

#### Vérifications
- [ ] Les 3 apps sont bloquées simultanément
- [ ] Instagram se débloque après 15 min
- [ ] TikTok se débloque après 30 min
- [ ] YouTube se débloque après 45 min
- [ ] Chaque déblocage est indépendant

---

## 🐛 Debugging si le Shield ne S'Applique Pas

### 1. Vérifier que le Payload est Sauvegardé

Dans BlockAppSheet, chercher ce log :
```
💾 [BLOCK_SHEET] Payload saved to App Group
```

**Si absent** → Le payload n'est pas sauvegardé. Vérifier :
- L'accès à l'App Group est configuré
- `UserDefaults(suiteName: "group.com.app.zenloop")` retourne bien une valeur

### 2. Vérifier que le Monitor est Appelé

Chercher :
```
🚀 [MONITOR] ===== INTERVAL STARTED =====
```

**Si absent** → iOS n'appelle pas le Monitor. Causes possibles :
- DeviceActivity permission non accordée
- Le schedule est incorrect (heure de début dans le passé)
- Le monitoring n'a pas démarré (erreur silencieuse)

### 3. Vérifier que le Payload est Trouvé

Chercher :
```
✅ [MONITOR] Payload data found: XXX bytes
```

**Si absent, voir** :
```
❌ [MONITOR] No payload data found for key: payload_block-XXX
```

**Solution** → Vérifier que la clé utilisée dans BlockAppSheet correspond :
```swift
// BlockAppSheet doit sauvegarder avec cette clé exacte
suite.set(payloadData, forKey: "payload_\(activityName.rawValue)")
```

### 4. Vérifier que le Shield est Appliqué

Chercher :
```
✅ [MONITOR] Shield applied to X app(s)
```

**Si présent mais l'app n'est pas bloquée** → Problème avec le token. Vérifier :
- Le token est valide (pas expiré)
- L'app est encore installée
- Les permissions Family Controls sont accordées

---

## 📊 Commandes Utiles pour Debugging

### Voir les Logs en Temps Réel
```bash
# Logs du Monitor Extension
log stream --predicate 'subsystem == "com.app.zenloop"' --level debug

# Logs spécifiques au blocage
log stream --predicate 'subsystem == "com.app.zenloop" AND eventMessage CONTAINS "MONITOR"' --level debug
```

### Vérifier les DeviceActivity Actives
```bash
# Dans l'app principale
let center = DeviceActivityCenter()
let activities = center.activities  // Liste des activities actives
```

### Inspecter l'App Group
```bash
# Afficher toutes les clés dans l'App Group (dans le code)
let suite = UserDefaults(suiteName: "group.com.app.zenloop")
let allKeys = suite?.dictionaryRepresentation().keys.sorted()
print(allKeys ?? [])
```

---

## ✅ Checklist de Validation

Avant de considérer le blocage comme fonctionnel :

- [ ] Le shield s'applique immédiatement après avoir tapé "Bloquer"
- [ ] Le shield persiste après avoir fermé Zenloop
- [ ] Le shield persiste après un redémarrage de l'iPhone
- [ ] Plusieurs blocages peuvent être actifs simultanément
- [ ] Chaque blocage se débloque automatiquement à la fin
- [ ] Les logs montrent clairement le flow complet
- [ ] Aucune erreur dans la console

---

## 🎯 Résumé du Flow Correct

```
┌─────────────────────────┐
│   User taps "Bloquer"   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   BlockAppSheet         │
│   - Crée payload        │
│   - Sauvegarde en       │
│     App Group           │
│   - startMonitoring()   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   iOS System            │
│   - Gère le timing      │
│   - Garantit la         │
│     persistence         │
└────────────┬────────────┘
             │ intervalDidStart()
             ▼
┌─────────────────────────┐
│   Monitor Extension     │
│   - Lit payload         │
│   - Applique shield     │
│   - Sauvegarde block    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   ManagedSettings       │
│   - Shield actif        │
│   - Persiste            │
└─────────────────────────┘
```

---

**Date** : 2026-02-04
**Status** : ✅ Implémenté et prêt pour test
