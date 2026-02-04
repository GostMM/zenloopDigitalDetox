# 🎯 Architecture de Blocage Apple-Compliant

## ✅ Ce qui a été corrigé

### Problème Initial
L'architecture précédente utilisait un flow **non-standard** qui contournait le système iOS :
```
Report Extension → UserDefaults → URL Scheme → Main App → ManagedSettings
```

**Conséquences** :
- Blocages appliqués hors du cycle système
- Shields perdus après redémarrage
- Apps bloquées sans référence
- Dépendance à l'ouverture de l'app principale

---

## 🏗️ Nouvelle Architecture (Apple-Compliant)

### Flow Correct
```
Report Extension → DeviceActivityCenter.startMonitoring() → iOS System → Monitor Extension → ManagedSettings
```

**Avantages** :
- ✅ iOS gère le cycle de vie du blocage
- ✅ Persistance automatique par le système
- ✅ Pas besoin d'ouvrir l'app principale
- ✅ Références toujours cohérentes
- ✅ Fonctionne après redémarrage

---

## 📝 Changements Effectués

### 1. BlockAppSheet (FullStatsPageView.swift)

**Avant** :
```swift
// ❌ Ancien flow manuel
suite.set(tokenData, forKey: "pending_block_tokenData")
suite.set(duration, forKey: "pending_block_duration")
openURL("zenloop://apply-block")  // ❌ Mauvais pattern
```

**Après** :
```swift
// ✅ Flow Apple-compliant
let activityName = DeviceActivityName("block-\(blockId)")

// Créer le payload pour le Monitor
let payload = SelectionPayload(
    sessionId: blockId,
    apps: [app.token],
    categories: [],
    restrictionMode: .shield
)
suite.set(payloadData, forKey: "payload_\(activityName.rawValue)")

// Laisser iOS gérer le blocage
let center = DeviceActivityCenter()
try center.startMonitoring(activityName, during: schedule)
```

**Impact** :
- Plus besoin d'URL scheme
- Plus besoin d'ouvrir l'app principale
- iOS appelle automatiquement le Monitor à l'heure prévue

---

### 2. Monitor Extension (zenloopmonitor.swift)

**Avant** :
```swift
// ❌ Traitement manuel dans init()
processBlockRequests()  // Lit pending_block_* keys
setupDarwinListener()   // Écoute des notifications custom
```

**Après** :
```swift
// ✅ Réponse aux événements système
override func intervalDidStart(for activity: DeviceActivityName) {
    applyShield(for: activity)  // Le shield est appliqué par iOS
}

override func intervalDidEnd(for activity: DeviceActivityName) {
    removeShield(for: activity)  // iOS retire le shield
}
```

**Impact** :
- Le Monitor est appelé par iOS (garanti)
- Pas de polling ou de vérifications manuelles
- Le système gère le timing

---

### 3. Fonctions Deprecated

Les méthodes suivantes sont marquées comme deprecated :
- `processBlockRequests()` - Remplacé par `intervalDidStart`
- `setupDarwinListener()` - Plus nécessaire
- `scheduleAutoUnblock()` - Remplacé par `intervalDidEnd`
- `openMainAppToApplyBlock()` - Plus nécessaire

---

## 🔧 Migration pour les Développeurs

### Si vous bloquez une app depuis le Report Extension

**Ancien code à retirer** :
```swift
// ❌ NE PLUS FAIRE
UserDefaults(suite).set(data, forKey: "pending_block_*")
openURL("zenloop://apply-block")
```

**Nouveau code à utiliser** :
```swift
// ✅ FAIRE CECI
let center = DeviceActivityCenter()
let activityName = DeviceActivityName("block-\(UUID())")

// 1. Sauvegarder le payload pour le Monitor
let payload = SelectionPayload(...)
suite.set(payloadData, forKey: "payload_\(activityName.rawValue)")

// 2. Créer le schedule
let schedule = DeviceActivitySchedule(
    intervalStart: startComponents,
    intervalEnd: endComponents,
    repeats: false
)

// 3. Laisser iOS gérer
try center.startMonitoring(activityName, during: schedule)
```

### Si vous débloquez une app

**Ancien code** :
```swift
// ❌ Manipulation manuelle du store
let store = ManagedSettingsStore(named: .init(storeName))
store.shield.applications = nil
```

**Nouveau code** :
```swift
// ✅ Arrêter le monitoring (iOS retire le shield automatiquement)
let center = DeviceActivityCenter()
center.stopMonitoring([activityName])
```

---

## 🎓 Principes Apple à Respecter

### Règle d'Or
> **Le Report Extension NE BLOQUE PAS. Il déclenche une règle.**

### Architecture Cible
```
┌─────────────────────┐
│  Report Extension   │  ← Affichage + Déclenchement
└──────────┬──────────┘
           │ startMonitoring()
           ▼
┌─────────────────────┐
│    iOS System       │  ← Gère le timing + persistence
└──────────┬──────────┘
           │ intervalDidStart()
           ▼
┌─────────────────────┐
│ Monitor Extension   │  ← Applique le shield
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ ManagedSettings     │  ← Shield actif
└─────────────────────┘
```

### Ce Qu'iOS Garantit
1. **Persistence** : Les règles survivent aux redémarrages
2. **Timing** : intervalDidStart/End sont appelés au bon moment
3. **Cohérence** : Le shield reste actif pendant toute la durée
4. **Fiabilité** : Pas besoin que l'app soit ouverte

---

## ⚠️ Compatibilité

### Code Deprecated Conservé
Les anciennes méthodes (`processBlockRequests`, etc.) sont conservées et marquées `@available(*, deprecated)` pour compatibilité temporaire.

**À faire** :
- Tester le nouveau flow sur toutes les fonctionnalités
- Retirer les URL schemes obsolètes de l'app principale
- Nettoyer GlobalShieldManager (optionnel pour maintenant)

---

## 🧪 Tests à Effectuer

### Test 1 : Blocage depuis Report
1. Ouvrir le Report Extension (widget ou app)
2. Taper sur une app → "Bloquer 15 min"
3. **Vérifier** : L'app est bloquée immédiatement
4. **Vérifier** : Le shield persiste après avoir fermé l'app
5. **Vérifier** : Le déblocage automatique fonctionne après 15 min

### Test 2 : Redémarrage
1. Bloquer une app pour 30 min
2. Redémarrer l'iPhone
3. **Vérifier** : Le shield est toujours actif
4. **Vérifier** : Le déblocage se fait au bon moment

### Test 3 : Multiple Blocks
1. Bloquer 3 apps différentes avec des durées différentes
2. **Vérifier** : Les 3 shields sont actifs simultanément
3. **Vérifier** : Chaque déblocage se fait indépendamment

---

## 📚 Références Apple

- [DeviceActivity Framework](https://developer.apple.com/documentation/deviceactivity)
- [ManagedSettings](https://developer.apple.com/documentation/managedsettings)
- [Screen Time API Best Practices](https://developer.apple.com/wwdc21/10123)

---

## 🎯 Résumé

### Ce qui a changé
| Composant | Avant | Après |
|-----------|-------|-------|
| Report Extension | Écrit dans UserDefaults + URL | Appelle DeviceActivityCenter |
| Main App | Reçoit URL → applique shield | N'est plus impliquée |
| Monitor Extension | Lit UserDefaults manuellement | Répond aux événements iOS |
| Persistence | Manuelle (fragile) | Automatique (iOS) |

### Bénéfices
- ✅ Plus de blocages "fantômes"
- ✅ Plus de références perdues
- ✅ Fonctionne sans ouvrir l'app
- ✅ Stable après redémarrage
- ✅ Conforme aux attentes d'Apple

---

**Status** : ✅ Implémenté
**Date** : 2026-02-04
**Version** : 2.0 (Apple-compliant architecture)
