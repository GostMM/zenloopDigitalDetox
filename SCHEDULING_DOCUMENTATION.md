# Documentation Complète du Système de Scheduling - Zenloop

## 📋 Vue d'ensemble

Le système de scheduling de Zenloop gère plusieurs types de programmation :
- **Sessions programmées** (DeviceActivity + Timers)
- **Notifications de rappel** (UserNotifications)
- **Widget Updates** (Timeline entries)
- **Auto-completion** (Background timers)

---

## 🏗️ Architecture des Fichiers de Scheduling

### 1. **ScheduledSessionsCoordinator.swift** - COORDINATEUR PRINCIPAL
**Rôle**: Gestionnaire central des sessions programmées avec double système (app foreground + background)

#### Fonctions principales:

##### `scheduleCustomChallenge()` - Ligne 40
**Appelé par**: 
- `MinimalHeader.swift:191` → `handleScheduleConfirmed()`
- `SessionPlanningRow.swift:541` → `scheduleSessionWithApps()`
- UI Components avec boutons "Programmer"

**Fonction**:
```swift
func scheduleCustomChallenge(
    title: String,
    duration: TimeInterval,
    difficulty: DifficultyLevel,
    apps: FamilyActivitySelection,
    startTime: Date,
    notificationManager: SessionNotificationManager
)
```

**Actions réalisées**:
1. Génère un `sessionId` unique
2. Programme les **notifications de rappel** via `SessionNotificationManager`
3. Crée un objet `ZenloopChallenge` 
4. Sauvegarde en persistence (`saveScheduledChallenge()`)
5. Programme le **démarrage automatique** (`scheduleAutoStart()`)
6. Programme le **blocage en arrière-plan** via `BlockScheduler` (DeviceActivity)
7. Notifie les delegates

##### `cancelScheduledChallenge()` - Ligne 108
**Appelé par**:
- Actions utilisateur "Annuler session"
- `ZenloopManager.swift:765` → `cancelScheduledChallenge()`
- Interface de gestion des sessions

**Actions réalisées**:
1. Annule les **notifications** (`notificationManager.cancelSessionNotifications()`)
2. Annule le **timer app** (`scheduledTimers[challengeId]?.cancel()`)
3. Annule le **DeviceActivitySchedule** (`BlockScheduler.shared.cancelScheduledSession()`)
4. Supprime de la **persistence** (`removeScheduledChallenge()`)

##### `scheduleAutoStart()` - Ligne 174 (PRIVÉE)
**Appelé par**: `scheduleCustomChallenge()`

**Fonction**: Programme un `DispatchWorkItem` pour démarrer automatiquement la session quand l'app est ouverte

**Logique**:
```swift
let workItem = DispatchWorkItem { [weak self] in
    // Vérifier que session pas annulée
    guard scheduledChallenges[challenge.id] != nil else { return }
    
    // Démarrer la session
    self.delegate?.scheduledSessionShouldStart(startingChallenge, apps: apps)
    
    // Nettoyer
    self.removeScheduledChallenge(challenge.id)
}
DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval, execute: workItem)
```

##### Getters et utilitaires:
- `getAllScheduledSessions()` - Ligne 215
- `getScheduledSession(id:)` - Ligne 219  
- `hasScheduledSessions()` - Ligne 223
- `getUpcomingSessions()` - Ligne 227
- `cleanupExpiredSessions()` - Ligne 241

---

### 2. **SessionNotificationManager.swift** - GESTIONNAIRE NOTIFICATIONS

#### Fonctions de scheduling:

##### `scheduleSessionReminder()` - Ligne 183
**Appelé par**: `ScheduledSessionsCoordinator.scheduleCustomChallenge()`

**Fonction**: Programme la séquence complète de notifications pour une session

**Séquence programmée**:
1. **Rappel -15 minutes**: "Votre session 'XXX' commence dans 15 minutes"
2. **Rappel -5 minutes**: "Votre session commence dans 5 minutes. Préparez-vous!"
3. **Démarrage**: "C'est parti ! Votre session a commencé"
4. **Fin de session**: "Bravo ! Session terminée avec succès"

##### `scheduleNotificationSequence()` - Ligne 217 (PRIVÉE)
**Appelé par**: `scheduleSessionReminder()`

**Fonction**: Crée et programme les notifications individuelles via `UNUserNotificationCenter`

##### `scheduleDailyTips()` - Ligne 726
**Appelé par**: `setupDailyWellnessNotifications()`

**Fonction**: Programme les conseils quotidiens bien-être (3 fois par jour)

##### `scheduleMotivationalReminders()` - Ligne 763  
**Appelé par**: `setupDailyWellnessNotifications()`

**Fonction**: Programme les rappels motivationnels personnalisés

##### `scheduleWeeklyEncouragement()` - Ligne 807
**Appelé par**: `setupDailyWellnessNotifications()`

**Fonction**: Programme les encouragements hebdomadaires

##### `rescheduleSession()` - Ligne 571
**Appelé par**: Actions utilisateur "Reporter session"

**Fonction**: Reporte une session programmée (annule anciennes notifs + programme nouvelles)

---

### 3. **ZenloopManager.swift** - GESTIONNAIRE PRINCIPAL APPLICATION

#### Fonctions de scheduling:

##### `scheduleSession()` - Ligne 259
**Appelé par**: 
- Interface utilisateur principale
- `SessionCoordinator.swift:134`

**Fonction**: Point d'entrée principal pour programmer une session
```swift
func scheduleSession(
    title: String,
    duration: TimeInterval,
    difficulty: DifficultyLevel,
    apps: FamilyActivitySelection,
    startTime: Date
)
```

**Délégation**: Redirige vers `ScheduledSessionsCoordinator.scheduleCustomChallenge()`

##### `cancelScheduledSession()` - Ligne 359
**Appelé par**: Interface utilisateur

**Fonction**: Annule une session programmée (délègue à `ScheduledSessionsCoordinator`)

##### `restoreLostSchedules()` - Ligne 197
**Appelé par**: `zenloopApp.swift` au démarrage de l'application

**Fonction**: Restaure les sessions programmées perdues après redémarrage app

##### `scheduleAutoCompletion()` - Ligne 923 (PRIVÉE)
**Appelé par**: Quand une session devient active

**Fonction**: Programme un timer pour compléter automatiquement la session à la fin

##### Fonctions helper scheduling:
- `getAllScheduledSessions()` - Ligne 774
- `hasScheduledSessions()` - Ligne 782  
- `updateScheduledSessionsStatus()` - Ligne 714
- `checkAndRestoreSchedules()` - Ligne 378

---

### 4. **ZenloopWidgetModels.swift** - SYSTÈME WIDGET

#### Nouvelles fonctions scheduling (après refactor):

##### `startSession(duration:origin:)` - Ligne 238
**Appelé par**: App Intents du widget

**Fonction**: Démarre une session depuis le widget avec gestion de synchronisation

##### `canStartScheduledSession()` - Ligne 429
**Appelé par**: Système de vérification avant démarrage automatique

**Fonction**: Vérifie si une session programmée peut démarrer (pas annulée, pas de conflit)

##### `cleanupCancelledSessions()` - Ligne 447
**Appelé par**: Nettoyage périodique (1x par jour recommandé)

**Fonction**: Nettoie les IDs de sessions annulées (évite le bloat mémoire)

---

### 5. **DeviceActivityCoordinator.swift** - SYSTÈME BLOCAGE ARRIÈRE-PLAN

#### Fonction scheduling:

##### `createSchedule()` - Ligne 174
**Appelé par**: `BlockScheduler` via `ScheduledSessionsCoordinator`

**Fonction**: Crée un `DeviceActivitySchedule` pour le blocage système en arrière-plan
```swift
func createSchedule(for challenge: ZenloopChallenge) -> DeviceActivitySchedule?
```

**Résultat**: Permet le blocage même si l'app est fermée

---

## 🔄 Workflow Complet de Scheduling

### Scénario: Utilisateur programme une session pour demain 14h

#### 1. **Interface Utilisateur** (`MinimalHeader.swift`)
```swift
private func handleScheduleConfirmed(startTime: Date, duration: Int) {
    // L'utilisateur confirme → Appelle ScheduledSessionsCoordinator
}
```

#### 2. **Coordinateur** (`ScheduledSessionsCoordinator.swift`)
```swift
scheduleCustomChallenge(
    title: "Focus Travail",
    duration: 3600, // 1 heure
    apps: selectedApps,
    startTime: tomorrow14h
)
```

**Actions simultanées**:
- ✅ **Timer app**: `DispatchWorkItem` dans 22 heures
- ✅ **DeviceActivity**: `BlockScheduler.scheduleSession()` 
- ✅ **Notifications**: 4 notifications programmées
- ✅ **Persistence**: Sauvegardé dans UserDefaults
- ✅ **Widget sync**: Données mises à jour

#### 3. **Le lendemain à 13h45** - Notification -15min
```swift
SessionNotificationManager.scheduleSessionReminder()
// → "Votre session Focus Travail commence dans 15 minutes"
```

#### 4. **13h55** - Notification -5min  
```swift
// → "Votre session commence dans 5 minutes. Préparez-vous!"
```

#### 5. **14h00** - Démarrage
```swift
// A) Si app ouverte:
scheduledTimers[sessionId] déclenche:
→ delegate?.scheduledSessionShouldStart(challenge, apps)
→ ZenloopManager démarre la session

// B) Si app fermée:
DeviceActivitySchedule démarre automatiquement
→ zenloopmonitor.swift gère le blocage
```

#### 6. **15h00** - Fin automatique
```swift
// A) Si app ouverte:
scheduleAutoCompletion() déclenche completion

// B) Si app fermée:  
DeviceActivityMonitor.intervalDidEnd() termine le blocage
```

---

## ⚠️ Points Critiques de Synchronisation

### Problème résolu: Sessions qui redémarraient après arrêt manuel

#### **Ancien système** (problématique):
- Une seule source de vérité (DeviceActivity) 
- Pas de tracking des cancellations manuelles
- Conflit entre actions manuelles et automatiques

#### **Nouveau système** (résolu):
- **Double vérification**: `canStartScheduledSession()` 
- **Tracking cancellations**: `cancelledScheduledSessions` array
- **Priorité manuelle**: Actions utilisateur overrident le scheduling

### Code de synchronisation clé:
```swift
func canStartScheduledSession(_ scheduledSession: ScheduledSessionData) -> Bool {
    // 1. Vérifier si session annulée manuellement
    if currentData.cancelledScheduledSessions.contains(scheduledSession.id) {
        return false // 🚫 Session was cancelled - don't start
    }
    
    // 2. Vérifier conflit avec session active
    if currentData.activeSession != nil {
        return false // 🚫 Already active - don't start scheduled
    }
    
    return true // ✅ OK to start
}
```

---

## 📞 Fonctions d'Appel Cross-File

### De l'Interface vers le Scheduling:
1. **`SchedulePickerView.swift:244`** → `confirmSchedule()`
2. **`MinimalHeader.swift:191`** → `handleScheduleConfirmed()`  
3. **`SessionPlanningRow.swift:541`** → `scheduleSessionWithApps()`

### Du Scheduling vers l'Interface:
1. **`ScheduledSessionsCoordinator`** → `delegate?.scheduledSessionShouldStart()`
2. **`ZenloopManager`** → UI State updates via `@Published` properties
3. **`Widget Updates`** → `WidgetKit.reloadAllTimelines()`

### Entre Managers:
1. **`ScheduledSessionsCoordinator`** ↔ **`SessionNotificationManager`**
2. **`ZenloopManager`** ↔ **`DeviceActivityCoordinator`**  
3. **`Widget`** ↔ **`ZenloopWidgetDataProvider`**

---

## 🛠️ APIs Système Utilisées

### Apple FrameWorks:
- **`DeviceActivity`**: Blocage arrière-plan schedulé
- **`UserNotifications`**: Notifications programmées
- **`WidgetKit`**: Timeline entries pour widgets
- **`BackgroundTasks`**: Nettoyage et maintenance
- **`DispatchQueue`**: Timers in-app

### Persistence:
- **`UserDefaults`**: Sessions programmées, settings
- **`App Groups`**: Partage données widget ↔ app
- **`Keychain`**: Données sensibles (pas encore implémenté)

---

## 🐛 Debug et Logs

### Catégories de logs importantes:
- **`🚫 [SESSION]`**: Cancellations et rejets
- **`✅ [SESSION]`**: Démarrages réussis  
- **`⏰ [ScheduledSessions]`**: Timers et programmation
- **`📅 [ScheduledSessions]`**: Sessions planifiées
- **`🔄 [MIGRATION]`**: Conversion données widget
- **`🧹 [SCHEDULE]`**: Nettoyage sessions expirées

### Commandes debug utiles:
```swift
// Voir toutes les sessions programmées
let sessions = ScheduledSessionsCoordinator.shared.getAllScheduledSessions()

// Diagnostics complets
let diagnostics = ScheduledSessionsCoordinator.shared.getDiagnosticsInfo()

// Debug notifications
await SessionNotificationManager.shared.debugScheduledNotifications()
```

---

## 🎯 Résumé des Responsabilités

| **Fichier** | **Responsabilité** | **Scheduling Functions** |
|------------|-------------------|-------------------------|
| `ScheduledSessionsCoordinator.swift` | Orchestration générale | `scheduleCustomChallenge()`, `cancelScheduledChallenge()` |
| `SessionNotificationManager.swift` | Notifications | `scheduleSessionReminder()`, `scheduleDailyTips()` |
| `ZenloopManager.swift` | Logique métier app | `scheduleSession()`, `restoreLostSchedules()` |
| `ZenloopWidgetModels.swift` | Synchronisation widget | `canStartScheduledSession()`, `startSession()` |
| `DeviceActivityCoordinator.swift` | Blocage système | `createSchedule()` |

Cette architecture garantit une synchronisation parfaite entre tous les composants de scheduling ! 🎉