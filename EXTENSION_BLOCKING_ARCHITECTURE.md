# Architecture du Blocage d'Apps depuis Extensions

## 🎯 Problème Résolu

Les **Device Activity Report Extensions** ne peuvent PAS appliquer de restrictions directement car :
- Elles servent uniquement à **afficher** des données
- Elles n'ont **pas accès** aux APIs de restriction en temps réel
- Les Device Activity Monitor Extensions ne s'exécutent que lors d'**événements programmés**

## ✅ Solution Implémentée

### Architecture en 3 parties

```
┌─────────────────────────────────────────────────────────────┐
│  Device Activity Report Extension (zenloopactivity)         │
│  FullStatsPageView.swift                                     │
│                                                              │
│  1. L'utilisateur clique sur "Bloquer" une app              │
│  2. Encode le token FamilyActivitySelection                  │
│  3. Écrit dans App Group (UserDefaults)                      │
│  4. Envoie Darwin Notification                               │
│     → "com.app.zenloop.RequestBlockFromReport"              │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       │ Darwin Notification
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  App Principale (zenloop)                                    │
│  zenloopApp.swift                                            │
│                                                              │
│  1. CFNotificationCenter listener détecte la notification   │
│  2. Lit les données depuis App Group                         │
│  3. Décode le token                                          │
│  4. Crée le ActiveBlock via BlockManager                     │
│  5. Applique le shield via GlobalShieldManager               │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       │ ManagedSettingsStore
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  GlobalShieldManager                                         │
│  Managers/GlobalShieldManager.swift                          │
│                                                              │
│  - Utilise UN SEUL ManagedSettingsStore (default, sans nom) │
│  - Accumule TOUS les tokens bloqués dans un Set             │
│  - Garantit la persistance après redémarrage                │
│  - store.shield.applications = Set<ApplicationToken>        │
└─────────────────────────────────────────────────────────────┘
```

## 📂 Fichiers Modifiés

### 1. **FullStatsPageView.swift** (Report Extension)
- **Fonction modifiée** : `blockApp()` (ligne 974-1042)
- **Nouvelle fonction** : `sendBlockRequestToMainApp()` (ligne 957-972)
- **Change** : Remplace `triggerMonitorExtension()` par envoi de Darwin Notification

### 2. **zenloopApp.swift** (App Principale)
- **Nouveau listener** : Darwin Notification `com.app.zenloop.RequestBlockFromReport` (ligne 78-95)
- **Nouvelle fonction** : `processReportExtensionBlockRequest()` (ligne 572-666)
- Lit les données depuis App Group
- Crée le block
- Applique le shield

### 3. **GlobalShieldManager.swift**
- Déjà existant et fonctionnel
- Utilise le store par défaut (clé de la persistance)
- Fonction `addBlock()` ajoute le token au Set global

## 🔑 Clés Techniques

### App Group UserDefaults
```swift
"pending_block_tokenData"   // FamilyActivitySelection encodé
"pending_block_appName"     // Nom de l'app
"pending_block_duration"    // Durée en secondes
"pending_block_storeName"   // Nom du store (legacy)
"pending_block_id"          // UUID du blocage
"pending_block_timestamp"   // Timestamp de création
```

### Darwin Notifications
```swift
"com.app.zenloop.RequestBlockFromReport" // Report → App
```

Les Darwin Notifications sont **inter-process** et fonctionnent entre extensions et app principale.

### ManagedSettingsStore
```swift
// ✅ CORRECT: Store par défaut (persiste)
let store = ManagedSettingsStore()

// ❌ INCORRECT: Store nommé (ne persiste pas toujours)
let store = ManagedSettingsStore(named: .init("custom_name"))
```

## 🔄 Flux Complet

1. **User Action** : Clique sur bouton "Bloquer" dans FullStatsPageView
2. **Report Extension** :
   - Encode le token de l'app
   - Écrit dans App Group
   - Envoie Darwin Notification
3. **App Principale** (réveillée par notification) :
   - Lit les données App Group
   - Décode le token
   - Crée ActiveBlock dans BlockManager
   - Appelle GlobalShieldManager.addBlock()
4. **GlobalShieldManager** :
   - Récupère le Set actuel : `store.shield.applications ?? Set()`
   - Ajoute le nouveau token
   - Réapplique : `store.shield.applications = blockedApps`
5. **iOS** : Applique immédiatement le shield sur l'app

## ⏰ Déblocage Automatique

```swift
// Programmé via scheduled_unblocks dans App Group
var scheduledUnblocks = suite.array(forKey: "scheduled_unblocks")

// Structure:
[
  "blockId": "...",
  "storeName": "...",
  "appName": "Instagram",
  "unblockTime": 1234567890.0
]

// Vérifié périodiquement par l'app ou le Monitor Extension
```

## 🐛 Debugging

### Logs à surveiller
```
📬 [MAIN APP] Received block request from Report Extension
📨 [REPORT_BLOCK] Found block request: Instagram for 15min
✅ [REPORT_BLOCK] Token decoded successfully
💾 [REPORT_BLOCK] Block saved: abc-123
🛡️ [REPORT_BLOCK] Shield applied for: Instagram
```

### Commandes Console
```bash
# Voir les logs de l'app
log stream --predicate 'subsystem == "com.app.zenloop"' --level debug

# Voir les notifications Darwin
log stream --predicate 'eventMessage CONTAINS "Darwin"' --level debug
```

## ✅ Tests de Validation

1. **Test 1** : Bloquer une app depuis FullStatsPageView
   - Vérifier la notification
   - Vérifier que l'app est bloquée
   - Vérifier le compte à rebours

2. **Test 2** : Redémarrer l'app
   - Les blocages doivent PERSISTER
   - Le compte à rebours doit continuer

3. **Test 3** : Déblocage automatique
   - Attendre la fin de la durée
   - L'app doit se débloquer automatiquement

## 🚨 Pièges à Éviter

1. ❌ Ne JAMAIS utiliser `DeviceActivitySchedule` depuis Report Extension
2. ❌ Ne PAS créer de stores nommés multiples pour les blocks manuels
3. ✅ TOUJOURS utiliser le store par défaut dans GlobalShieldManager
4. ✅ TOUJOURS nettoyer les clés App Group après traitement
5. ✅ TOUJOURS vérifier que Darwin Notification est bien reçue

## 📝 Notes

- Les Darwin Notifications fonctionnent même si l'app est en arrière-plan
- Le system iOS réveillera l'app brièvement pour traiter la notification
- Les tokens FamilyActivitySelection sont encodables/decodables
- La persistance du store par défaut est garantie par iOS
