# 🔍 GUIDE DE DEBUG COMPLET

## 📋 ÉTAPES DE TEST

### 1. Ouvrir l'app principale Zenloop

**Logs attendus :**
```
🛡️ [GLOBAL_SHIELD] Initializing with DEFAULT store (key to persistence)
🔄 [GLOBAL_SHIELD] Restoring all active blocks...
   → Found 0 active blocks
```

### 2. Aller dans l'extension Stats (DeviceActivity Report)

Naviguer vers la page avec les stats et la liste des apps.

### 3. Cliquer sur une app et choisir "Bloquer"

Par exemple : Instagram, 15 minutes

**Logs attendus dans l'EXTENSION :**
```
✅ [BLOCK_SHEET] Token encoded successfully
💾 [BLOCK_SHEET] Block saved: Instagram
   → Duration: 15 minutes
   → BlockID: xxx-xxx-xxx
✅ [BLOCK_SHEET] Block ready - app must apply shield on next launch
```

### 4. Retourner à l'app principale (ou la lancer)

**Logs attendus dans l'APP PRINCIPALE :**
```
🔍 [CHECK_PENDING] Checking for pending blocks...
🚨 [CHECK_PENDING] Found pending block: xxx-xxx-xxx (age: 5s)
   → Applying NOW...
🔒 [APPLY_BLOCK] Starting block application for ID: xxx
✅ [APPLY_BLOCK] Token decoded for: Instagram
➕ [GLOBAL_SHIELD] ========================================
➕ [GLOBAL_SHIELD] ADDING BLOCK FOR: Instagram
   → BlockID: xxx-xxx-xxx
   → Current blocked apps: 0
   → After insert: 1 apps
   → Actually added: true
   → Applying shield to 1 apps NOW...
   → ✅ store.shield.applications = blockedApps DONE!
   → Verification: store now has 1 apps blocked
✅ [GLOBAL_SHIELD] Block operation complete
➕ [GLOBAL_SHIELD] ========================================
```

### 5. Essayer d'ouvrir Instagram

L'app **DOIT** être bloquée avec un écran de shield.

## ⚠️ SI ÇA NE MARCHE PAS

### Scénario A : L'extension ne sauvegarde pas le block

**Logs manquants :**
```
(Pas de "Block saved" dans les logs)
```

**Vérifier :**
1. App Group est bien configuré : `group.com.app.zenloop`
2. L'extension a bien accès à l'App Group
3. Le token est bien encodé

### Scénario B : L'app principale ne trouve pas le block

**Logs :**
```
🔍 [CHECK_PENDING] Checking for pending blocks...
   → No pending blocks
```

**Vérifier :**
1. `pending_apply_block_id` est bien dans App Group
2. L'app check bien au démarrage (`.onAppear`)

### Scénario C : Le token ne décode pas

**Logs :**
```
❌ [APPLY_BLOCK] Failed to decode token
```

**Problème :** Le tokenData est corrompu ou vide

**Solution :** Vérifier que `FamilyActivitySelection` est bien encodé dans l'extension

### Scénario D : Le shield n'est pas appliqué

**Logs :**
```
✅ [GLOBAL_SHIELD] Block operation complete
   → Verification: store now has 1 apps blocked
```

**MAIS l'app n'est pas bloquée quand on l'ouvre**

**Causes possibles :**

1. **Permissions manquantes**
   - Settings → Screen Time → Zenloop
   - Family Controls doit être ON
   - L'utilisateur doit avoir autorisé

2. **Store par défaut ne marche pas sur simulateur**
   - Tester sur un VRAI DEVICE
   - Le simulateur peut avoir des bugs

3. **Token invalide**
   - Le token peut être expiré
   - Essayer de re-sélectionner l'app

4. **ManagedSettingsStore ne persiste pas**
   - Possible bug iOS
   - Essayer de redémarrer le device

## 🧪 TEST ULTIME

### Test avec logs maximaux

1. **Ouvrir Xcode Console**
2. **Filtrer sur "GLOBAL_SHIELD"**
3. **Bloquer une app**
4. **Noter EXACTEMENT quels logs apparaissent**

### Questions à se poser :

1. ✅ Le token est-il bien encodé ?
   ```
   ✅ [BLOCK_SHEET] Token encoded successfully
   ```

2. ✅ Le block est-il bien sauvegardé ?
   ```
   💾 [BLOCK_SHEET] Block saved: Instagram
   ```

3. ✅ L'app principale trouve-t-elle le block ?
   ```
   🚨 [CHECK_PENDING] Found pending block
   ```

4. ✅ Le token est-il bien décodé ?
   ```
   ✅ [APPLY_BLOCK] Token decoded for: Instagram
   ```

5. ✅ Le shield est-il bien appliqué ?
   ```
   ✅ store.shield.applications = blockedApps DONE!
   ```

6. ✅ La vérification confirme-t-elle ?
   ```
   → Verification: store now has 1 apps blocked
   ```

**Si TOUT est ✅ mais l'app n'est pas bloquée → Problème de permissions ou de device**

## 🎯 CHECKLIST FINALE

- [ ] App Group configuré : `group.com.app.zenloop`
- [ ] Entitlements Family Controls activés
- [ ] Permissions Screen Time accordées
- [ ] L'app principale est ouverte avant/après le blocage
- [ ] Tester sur un VRAI device (pas simulateur)
- [ ] L'app à bloquer est bien installée
- [ ] GlobalShieldManager s'initialise au démarrage
- [ ] Les logs montrent que le shield est appliqué

## 💡 SOLUTION DE DERNIER RECOURS

Si RIEN ne marche, essayer de bloquer DIRECTEMENT depuis l'app principale :

```swift
// Test manuel dans l'app
let store = ManagedSettingsStore()
var selection = FamilyActivitySelection()
// Sélectionner Instagram manuellement
store.shield.applications = selection.applicationTokens
```

Si ça ne marche pas même en manuel → **Problème de permissions système**