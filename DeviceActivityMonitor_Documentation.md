# DeviceActivityMonitor Documentation - Zenloop App

## 📋 Résumé Exécutif

### Vue d'Ensemble
Le `DeviceActivityMonitor` est le cœur du système de bien-être numérique de Zenloop. Il s'agit d'une **Extension Système** qui fonctionne indépendamment de l'app principale pour surveiller et contrôler l'utilisation des applications en arrière-plan.

### 🎯 Fonctionnalités Clés
- **Blocage automatique d'apps** pendant les sessions de concentration
- **Surveillance en temps réel** des seuils d'utilisation
- **Communication bidirectionnelle** avec l'app via App Groups
- **Scheduling autonome** géré par iOS (fonctionne même app fermée)
- **Statistiques détaillées** et tracking des tentatives d'accès

### 🔄 Flux de Communication

#### App → Extension (Préparation)
```swift
1. App crée un challenge et stocke les données dans App Group
2. App programme la surveillance via DeviceActivityCenter
3. iOS prend le relais et déclenchera automatiquement l'extension
```

#### Extension → App (Événements)
```swift
1. Extension écrit les événements dans App Group (queue max 50)
2. App fait du polling toutes les 8 secondes pour lire les événements
3. App traite et affiche les mises à jour d'interface
```

### ⚡ Points Critiques

#### ✅ Ce qui Fonctionne
- Extension déclenchée automatiquement par iOS selon planning
- Blocage immédiat et efficace via ManagedSettings
- Communication asynchrone fiable via App Groups
- Fonctionne même si l'app principale est fermée

#### ⚠️ Limitations
- **Pas de communication temps réel** (délai 1-8 secondes)
- **Polling requis** côté app principale pour recevoir les événements
- **Extensions limitées** en temps d'exécution et mémoire
- **Pas de notifications directes** depuis l'extension

### 🏗️ Architecture Technique

```
┌─────────────────┐    App Groups    ┌──────────────────────┐
│   App Principale │ ◄──────────────► │  DeviceActivity      │
│   (UI + Logic)   │                  │  Monitor Extension   │
│                 │                  │  (Background)        │
├─────────────────┤                  ├──────────────────────┤
│ • Planning      │                  │ • App Blocking       │
│ • Configuration │                  │ • Event Detection    │
│ • UI Updates    │                  │ • Statistics         │
│ • Event Polling │                  │ • Notifications      │
└─────────────────┘                  └──────────────────────┘
         ▲                                       ▲
         │                                       │
         ▼                                       ▼
┌─────────────────────────────────────────────────────────┐
│                    iOS System                           │
│  • Déclenche l'extension selon planning                 │
│  • Gère ManagedSettings (restrictions)                  │
│  • Applique les blocages au niveau système              │
└─────────────────────────────────────────────────────────┘
```

### 📱 Interface Utilisateur Réactive

#### Détection d'Événements Manqués
```swift
// Quand l'app s'ouvre après fermeture
1. Vérification automatique des événements en App Group
2. Détection des sessions démarrées/terminées pendant la fermeture
3. Affichage d'alertes et interfaces adaptées
4. Mise à jour en temps réel des sessions actives
```

#### Types d'Interfaces
- **Alertes d'information** : Session démarrée/terminée pendant fermeture
- **Bannière active** : Temps restant et statut en cours
- **Statistiques** : Tentatives d'accès, durée, succès

### 🔧 Implémentation Zenloop

#### Classes Principales
- `ZenloopDeviceActivityMonitor` : Extension système (zenloopmonitor.swift)
- `DeviceActivityCoordinator` : Gestionnaire côté app principale
- `AppStateManager` : Gestion des états et interface réactive

#### Données Échangées
```swift
// App Group: "group.com.app.zenloop"
├── payload_<activityName>           // Configuration blocage
├── session_info_<activityName>      // Métadonnées session
├── device_activity_events           // Queue événements (max 50)
├── extension_activation_queue       // Sessions en attente activation
├── completedChallengeIds           // Historique réussites
└── app_attempt_log                 // Tentatives d'accès bloquées
```

### 🚀 Avantages Système

1. **Robustesse** : Fonctionne indépendamment de l'état de l'app
2. **Performance** : Extension légère, app principale pour UI complexe  
3. **Sécurité** : Restrictions appliquées au niveau iOS, non contournables
4. **Fiabilité** : iOS garantit l'exécution selon planning
5. **Efficacité** : Blocage immédiat, pas de délai utilisateur

### 🎨 Expérience Utilisateur

#### Scénarios Typiques
- **Planning nocturne** : Challenge programmé pour le lendemain matin
- **Session automatique** : Blocage activé même si app fermée
- **Retour utilisateur** : Interface informe des événements manqués
- **Temps réel** : Suivi en direct des sessions actives

#### Feedback Visuel
- Bannières de session active avec countdown
- Alertes pour événements importants
- Statistiques de réussite et tentatives
- Historique complet des sessions

---

## Overview

The `DeviceActivityMonitor` is a crucial component of the Zenloop digital wellness app that enables background monitoring and control of app usage during focus sessions. It operates as a System Extension that runs independently from the main app, providing real-time app blocking and session tracking capabilities.

## Architecture

### Extension Structure
```
zenloopmonitor/
├── zenloopmonitor.swift       # Main DeviceActivityMonitor implementation
└── Info.plist                # Extension configuration
```

### Integration Points
- **Main App**: `DeviceActivityCoordinator.swift` manages communication
- **App Group**: `group.com.app.zenloop` for inter-process communication
- **Managed Settings**: Named stores for app blocking configurations

## Core Implementation

### ZenloopDeviceActivityMonitor Class

```swift
class ZenloopDeviceActivityMonitor: DeviceActivityMonitor {
    // Main implementation in zenloopmonitor.swift:31
}
```

The monitor extends Apple's `DeviceActivityMonitor` and provides:
- Session lifecycle management
- App blocking/unblocking
- Event threshold monitoring
- Communication with main app via App Groups

# DeviceActivity Framework - API Complète

## Classes Principales

### DeviceActivityMonitor

La classe de base pour surveiller les activités d'appareil. Toutes les méthodes sont optionnelles à implémenter.

#### Méthodes de Cycle de Vie des Intervalles

```swift
// Appelé au début d'un intervalle d'activité
func intervalDidStart(for activity: DeviceActivityName)

// Appelé à la fin d'un intervalle d'activité  
func intervalDidEnd(for activity: DeviceActivityName)
```

#### Méthodes d'Événements de Seuil

```swift
// Appelé when un seuil d'événement est atteint
func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName)

// Appelé avant qu'un seuil soit atteint (avertissement)
func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName)
```

#### Méthodes d'Avertissement

```swift
// Appelé au début d'un avertissement
func warningDidStart(for activity: DeviceActivityName)

// Appelé à la fin d'un avertissement
func warningDidEnd(for activity: DeviceActivityName)
```

### DeviceActivityCenter

Classe pour gérer la surveillance des activités d'appareil.

#### Propriétés

```swift
// Instance partagée
static let shared = DeviceActivityCenter()

// Activités actuellement surveillées
var activities: Set<DeviceActivityName> { get }
```

#### Méthodes de Surveillance

```swift
// Démarrer la surveillance d'une activité
func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws

// Démarrer la surveillance avec des événements
func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name : DeviceActivityEvent]) throws

// Arrêter la surveillance d'activités spécifiques
func stopMonitoring(_ activities: [DeviceActivityName])

// Arrêter toute surveillance
func stopMonitoring()
```

### DeviceActivitySchedule

Structure définissant quand surveiller l'activité.

#### Initialisation

```swift
// Planning avec heures de début/fin
init(intervalStart: DateComponents, intervalEnd: DateComponents, repeats: Bool, warningTime: DateComponents? = nil)

// Planning pour une journée entière
init(nextDayFromDate: Date, warningTime: DateComponents? = nil)

// Planning pour une date spécifique
init(from startDate: Date, to endDate: Date, warningTime: DateComponents? = nil)
```

#### Propriétés

```swift
var intervalStart: DateComponents
var intervalEnd: DateComponents
var repeats: Bool
var warningTime: DateComponents?
```

### DeviceActivityEvent

Structure représentant un événement dans une activité surveillée.

#### Initialisation

```swift
// Événement pour des applications spécifiques
init(applications: Set<ApplicationToken>, threshold: DateComponents)

// Événement pour des catégories d'applications
init(categories: Set<ActivityCategoryToken>, threshold: DateComponents)

// Événement pour des applications ET catégories
init(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, threshold: DateComponents)

// Événement pour des domaines web
init(webDomains: Set<WebDomainToken>, threshold: DateComponents)
```

#### Propriétés

```swift
var applications: Set<ApplicationToken>
var categories: Set<ActivityCategoryToken>
var webDomains: Set<WebDomainToken>
var threshold: DateComponents
var includesUsageAcrossAllApplications: Bool
```

### DeviceActivityName

Identifiant unique pour une activité d'appareil.

```swift
struct DeviceActivityName: Hashable, RawRepresentable {
    init(_ rawValue: String)
    var rawValue: String
}
```

### DeviceActivityReport

Protocole pour créer des rapports d'activité personnalisés.

```swift
protocol DeviceActivityReport {
    var body: some View { get }
}
```

### DeviceActivityReportScene

Scène pour afficher les rapports d'activité.

```swift
struct DeviceActivityReportScene: Scene {
    init(_ reportType: DeviceActivityReportType, content: @escaping (DeviceActivityReportContext) -> Content)
}
```

## Types de Données

### DeviceActivityFilter

Filtre pour spécifier quelles données inclure dans les rapports.

```swift
struct DeviceActivityFilter {
    init(segment: DateInterval, users: Set<String> = [], devices: Set<String> = [])
    
    var segment: DateInterval
    var users: Set<String>
    var devices: Set<String>
}
```

### DeviceActivityData

Données d'activité pour les rapports.

```swift
struct DeviceActivityData {
    var activitySegments: [DeviceActivitySegment]
    var users: [DeviceActivityUser]
}
```

### DeviceActivitySegment

Segment de données d'activité.

```swift
struct DeviceActivitySegment {
    var dateInterval: DateInterval
    var totalActivityDuration: TimeInterval
    var applications: [DeviceActivityApplicationData]
    var categories: [DeviceActivityCategoryData]
    var webDomains: [DeviceActivityWebDomainData]
}
```

### DeviceActivityApplicationData

Données d'utilisation pour une application spécifique.

```swift
struct DeviceActivityApplicationData {
    var displayName: String
    var bundleIdentifier: String
    var totalActivityDuration: TimeInterval
    var numberOfPickups: Int
}
```

### DeviceActivityCategoryData

Données d'utilisation pour une catégorie d'applications.

```swift
struct DeviceActivityCategoryData {
    var displayName: String
    var identifier: String
    var totalActivityDuration: TimeInterval
    var applications: [DeviceActivityApplicationData]
}
```

### DeviceActivityWebDomainData

Données d'utilisation pour un domaine web.

```swift
struct DeviceActivityWebDomainData {
    var displayName: String
    var domain: String
    var totalActivityDuration: TimeInterval
}
```

## Erreurs

### DeviceActivityCenterError

Erreurs spécifiques au DeviceActivityCenter.

```swift
enum DeviceActivityCenterError: Error {
    case authorizationDenied
    case maximumActivitiesExceeded
    case intervalTooLong
    case intervalTooShort
    case unauthorized
    case invalidSchedule
    case cannotStartActivity
    case cannotStopActivity
}
```

## Exemples d'Utilisation Avancée

### Surveillance avec Événements de Seuil

```swift
// Configuration d'une surveillance avec seuils
let activityCenter = DeviceActivityCenter()
let activityName = DeviceActivityName("social-media-limit")

// Créer un événement de seuil (30 minutes)
let thresholdEvent = DeviceActivityEvent(
    applications: selectedSocialApps,
    threshold: DateComponents(minute: 30)
)

let events: [DeviceActivityEvent.Name : DeviceActivityEvent] = [
    DeviceActivityEvent.Name("socialMediaThreshold"): thresholdEvent
]

// Planning quotidien de 9h à 17h
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 9, minute: 0),
    intervalEnd: DateComponents(hour: 17, minute: 0),
    repeats: true,
    warningTime: DateComponents(minute: 25) // Avertissement à 25 minutes
)

// Démarrer la surveillance avec événements
try activityCenter.startMonitoring(activityName, during: schedule, events: events)
```

### Surveillance de Domaines Web

```swift
// Surveiller l'utilisation de sites web spécifiques
let webEvent = DeviceActivityEvent(
    webDomains: Set([socialMediaWebDomains]),
    threshold: DateComponents(minute: 45)
)

// Implémentation dans DeviceActivityMonitor
override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    
    switch event.rawValue {
    case "socialMediaThreshold":
        // Logique spécifique aux réseaux sociaux
        handleSocialMediaThreshold(activity: activity)
    case "webBrowsingThreshold":
        // Logique spécifique à la navigation web
        handleWebBrowsingThreshold(activity: activity)
    default:
        // Logique générique
        handleGenericThreshold(event: event, activity: activity)
    }
}
```

### Surveillance Multi-Activités

```swift
// Gérer plusieurs activités simultanées
class AdvancedDeviceActivityMonitor: DeviceActivityMonitor {
    
    private var activeActivities: Set<DeviceActivityName> = []
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        activeActivities.insert(activity)
        
        // Logique spécifique selon le type d'activité
        switch activity.rawValue {
        case let name where name.contains("work"):
            handleWorkSessionStart(activity)
        case let name where name.contains("study"):
            handleStudySessionStart(activity)
        case let name where name.contains("break"):
            handleBreakSessionStart(activity)
        default:
            handleGenericSessionStart(activity)
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        activeActivities.remove(activity)
        
        // Nettoyage et statistiques
        processSessionCompletion(activity)
        
        // Si c'était la dernière activité, faire un nettoyage global
        if activeActivities.isEmpty {
            performGlobalCleanup()
        }
    }
}
```

### Gestion des Avertissements

```swift
override func warningDidStart(for activity: DeviceActivityName) {
    super.warningDidStart(for: activity)
    
    // Notifier l'utilisateur qu'un avertissement a commencé
    notifyMainApp(event: "warningStarted", activity: activity.rawValue)
    
    // Logique spécifique à l'avertissement
    handleWarningStart(for: activity)
}

override func warningDidEnd(for activity: DeviceActivityName) {
    super.warningDidEnd(for: activity)
    
    // Notifier la fin de l'avertissement
    notifyMainApp(event: "warningEnded", activity: activity.rawValue)
    
    // Préparer pour la fin imminente de la session
    prepareForSessionEnd(for: activity)
}

private func handleWarningStart(for activity: DeviceActivityName) {
    // Enregistrer le début de l'avertissement
    let suite = UserDefaults(suiteName: "group.com.app.zenloop")
    suite?.set(Date().timeIntervalSince1970, forKey: "warning_started_\(activity.rawValue)")
    suite?.synchronize()
    
    // Optionnel: Ajuster les restrictions pendant l'avertissement
    adjustWarningRestrictions(for: activity)
}
```

### Planification Avancée

```swift
// Différents types de planification
class ScheduleManager {
    
    // Planning pour une session ponctuelle
    static func createOneTimeSchedule(startDate: Date, duration: TimeInterval) -> DeviceActivitySchedule {
        let endDate = startDate.addingTimeInterval(duration)
        return DeviceActivitySchedule(from: startDate, to: endDate, warningTime: DateComponents(minute: 5))
    }
    
    // Planning récurrent quotidien
    static func createDailySchedule(startHour: Int, startMinute: Int, durationMinutes: Int) -> DeviceActivitySchedule {
        let endMinute = (startMinute + durationMinutes) % 60
        let endHour = startHour + (startMinute + durationMinutes) / 60
        
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute),
            repeats: true,
            warningTime: DateComponents(minute: durationMinutes - 5)
        )
    }
    
    // Planning pour le lendemain entier
    static func createNextDaySchedule() -> DeviceActivitySchedule {
        return DeviceActivitySchedule(nextDayFromDate: Date(), warningTime: DateComponents(hour: 1))
    }
}
```

### Gestion des Erreurs Avancée

```swift
extension DeviceActivityCoordinator {
    
    func startMonitoringWithErrorHandling(for challenge: ZenloopChallenge) {
        do {
            try startMonitoring(for: challenge)
        } catch DeviceActivityCenterError.authorizationDenied {
            handleAuthorizationDenied()
        } catch DeviceActivityCenterError.maximumActivitiesExceeded {
            handleMaximumActivitiesExceeded()
        } catch DeviceActivityCenterError.intervalTooLong {
            handleIntervalTooLong(challenge: challenge)
        } catch DeviceActivityCenterError.intervalTooShort {
            handleIntervalTooShort(challenge: challenge)
        } catch DeviceActivityCenterError.invalidSchedule {
            handleInvalidSchedule(challenge: challenge)
        } catch {
            handleUnknownError(error: error)
        }
    }
    
    private func handleAuthorizationDenied() {
        // Rediriger vers les paramètres pour autoriser
        notifyMainApp(event: "authorizationRequired", activity: "system")
    }
    
    private func handleMaximumActivitiesExceeded() {
        // Arrêter d'anciennes activités pour faire de la place
        stopOldestActivities()
    }
    
    private func handleIntervalTooLong(challenge: ZenloopChallenge) {
        // Diviser en plusieurs sessions plus courtes
        createMultipleSessionsForLongChallenge(challenge)
    }
}
```

### Rapports d'Activité Personnalisés

```swift
// Exemple de rapport personnalisé pour Zenloop
struct ZenloopActivityReport: DeviceActivityReport {
    let context: DeviceActivityReportContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let data = context.rawValue as? DeviceActivityData {
                ForEach(data.activitySegments, id: \.dateInterval) { segment in
                    VStack(alignment: .leading) {
                        Text("Session du \(segment.dateInterval.start, style: .date)")
                            .font(.headline)
                        
                        Text("Durée totale: \(formatDuration(segment.totalActivityDuration))")
                            .font(.subheadline)
                        
                        if !segment.applications.isEmpty {
                            Text("Applications les plus utilisées:")
                                .font(.caption)
                            ForEach(segment.applications.prefix(3), id: \.bundleIdentifier) { app in
                                HStack {
                                    Text(app.displayName)
                                    Spacer()
                                    Text(formatDuration(app.totalActivityDuration))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}
```

## Essential Methods (Implémentation Zenloop)

### 1. Session Start - `intervalDidStart(for:)`
**Location**: `zenloopmonitor.swift:45`

Called when a focus session begins.

```swift
override func intervalDidStart(for activity: DeviceActivityName) {
    // Apply app blocking immediately
    applyShield(for: activity)
    
    // Notify main app of session start
    activateSessionInMainApp(for: activity)
    notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)
}
```

**Key Actions**:
- Applies ManagedSettings shield to block selected apps
- Activates corresponding session in main app
- Records session start in App Group

### 2. Session End - `intervalDidEnd(for:)`
**Location**: `zenloopmonitor.swift:68`

Called when a focus session completes.

```swift
override func intervalDidEnd(for activity: DeviceActivityName) {
    // Remove app blocking
    removeShield(for: activity)
    
    // Stop monitoring for single sessions
    stopMonitoringIfSingleSession(activity: activity)
    
    // Save completion stats
    saveChallengeCompletion(activityName: activity)
}
```

**Key Actions**:
- Removes all app blocking restrictions
- Handles cleanup for single-use sessions
- Records successful completion

### 3. Threshold Events - `eventDidReachThreshold(_:activity:)`
**Location**: `zenloopmonitor.swift:110`

Triggered when app usage limits are reached during a session.

```swift
override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    // Log threshold breach
    print("⚠️ Threshold reached for: \(event) in activity: \(activity)")
    
    // Notify main app
    notifyMainApp(event: "thresholdReached", activity: activity.rawValue, eventName: event.rawValue)
}
```

## App Blocking System

### Shield Application - `applyShield(for:)`
**Location**: `zenloopmonitor.swift:131`

The core blocking mechanism:

```swift
private func applyShield(for activity: DeviceActivityName) {
    // 1. Retrieve blocking configuration from App Group
    let expectedKey = "payload_\(activity.rawValue)"
    guard let data = suite.data(forKey: expectedKey),
          let payload = try? JSONDecoder().decode(SelectionPayload.self, from: data)
    else { return }
    
    // 2. Create named ManagedSettings store
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
    
    // 3. Apply app blocking
    if !payload.apps.isEmpty {
        store.shield.applications = Set(payload.apps)
    }
    
    // 4. Apply category blocking
    if !payload.categories.isEmpty {
        store.shield.applicationCategories = .specific(Set(payload.categories))
    }
}
```

### Shield Removal - `removeShield(for:)`
**Location**: `zenloopmonitor.swift:192`

```swift
private func removeShield(for activity: DeviceActivityName) {
    let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
    
    // Clear all restrictions
    store.shield.applications = nil
    store.shield.applicationCategories = nil
}
```

## Data Models

### SelectionPayload
**Location**: `zenloopmonitor.swift:16`

Configuration for what to block during sessions:

```swift
struct SelectionPayload: Codable {
    let sessionId: String
    let apps: [ApplicationToken]        # Specific apps to block
    let categories: [ActivityCategoryToken]  # App categories to block
}
```

### SessionInfo
**Location**: `zenloopmonitor.swift:22`

Session metadata shared between app and extension:

```swift
struct SessionInfo: Codable {
    let sessionId: String
    let title: String
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let createdAt: Date
}
```

## Communication System

### App Group Integration
**App Group ID**: `group.com.app.zenloop`

#### Key Data Exchanges:

1. **Blocking Configuration**
   - Key: `payload_<activityName>`
   - Contains: `SelectionPayload` with apps/categories to block

2. **Session Information**
   - Key: `session_info_<activityName>`
   - Contains: `SessionInfo` with session details

3. **Event Communication**
   - Key: `device_activity_events`
   - Contains: Array of event notifications for main app

4. **Session Activation Queue**
   - Key: `extension_activation_queue`
   - Contains: Queue of sessions pending activation

### Event Notification System
**Location**: `zenloopmonitor.swift:243`

```swift
private func notifyMainApp(event: String, activity: String, eventName: String? = nil) {
    let notification: [String: Any] = [
        "event": event,
        "activity": activity,
        "timestamp": Date().timeIntervalSince1970,
        "eventName": eventName as Any
    ]
    
    // Add to event queue (max 50 events)
    var notifications = defaults.array(forKey: "device_activity_events") as? [[String: Any]] ?? []
    notifications.append(notification)
    
    if notifications.count > 50 {
        notifications = Array(notifications.suffix(50))
    }
    
    defaults.set(notifications, forKey: "device_activity_events")
}
```

## Session Management

### Single Session Handling
**Location**: `zenloopmonitor.swift:94`

For scheduled sessions (prefix: "scheduled_"):

```swift
private func stopMonitoringIfSingleSession(activity: DeviceActivityName) {
    if activity.rawValue.hasPrefix("scheduled_") {
        // Signal main app to stop monitoring
        suite?.set(true, forKey: "stop_monitoring_\(activity.rawValue)")
        suite?.synchronize()
    }
}
```

### Session Activation Queue
**Location**: `zenloopmonitor.swift:332`

Handles multiple concurrent sessions:

```swift
private func addSessionToActivationQueue(session: [String: Any], activationId: String, suite: UserDefaults) {
    var activationQueue = suite.array(forKey: "extension_activation_queue") as? [[String: Any]] ?? []
    activationQueue.append(session)
    
    // Clean old activations (> 5 minutes)
    let now = Date().timeIntervalSince1970
    activationQueue = activationQueue.filter { sessionData in
        if let triggerTime = sessionData["extensionTriggeredAt"] as? Double {
            return (now - triggerTime) < 300
        }
        return false
    }
    
    suite.set(activationQueue, forKey: "extension_activation_queue")
}
```

## Statistics Tracking

### Challenge Completion
**Location**: `zenloopmonitor.swift:224`

```swift
private func saveChallengeCompletion(activityName: DeviceActivityName) {
    let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
    
    var completedChallenges = userDefaults?.array(forKey: "completedChallengeIds") as? [String] ?? []
    completedChallenges.append(activityName.rawValue)
    
    userDefaults?.set(completedChallenges, forKey: "completedChallengeIds")
    userDefaults?.set(Date(), forKey: "lastChallengeCompletedDate")
}
```

### App Access Attempts
**Location**: `zenloopmonitor.swift:269`

Track blocked app access attempts:

```swift
private func recordAppAttempt(appName: String? = nil) {
    let currentCount = defaults.integer(forKey: "app_open_attempts")
    defaults.set(currentCount + 1, forKey: "app_open_attempts")
    
    let attempt: [String: Any] = [
        "timestamp": Date().timeIntervalSince1970,
        "appName": appName ?? "unknown"
    ]
    
    var attempts = defaults.array(forKey: "app_attempt_log") as? [[String: Any]] ?? []
    attempts.append(attempt)
    defaults.set(attempts, forKey: "app_attempt_log")
}
```

## DeviceActivityCoordinator Integration

The main app uses `DeviceActivityCoordinator` to manage the monitor:

### Starting Monitoring
**Location**: `DeviceActivityCoordinator.swift:39`

```swift
func startMonitoring(for challenge: ZenloopChallenge) {
    let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
    let schedule = DeviceActivitySchedule(
        intervalStart: startComponents,
        intervalEnd: endComponents,
        repeats: false
    )
    
    try activityCenter.startMonitoring(activityName, during: schedule)
}
```

### Event Processing
**Location**: `DeviceActivityCoordinator.swift:86`

```swift
func checkDeviceActivityEvents() {
    if let events = defaults.array(forKey: "device_activity_events") as? [[String: Any]] {
        for event in events {
            processDeviceActivityEvent(type: eventType, activity: activity, timestamp: timestamp)
        }
        defaults.removeObject(forKey: "device_activity_events")
    }
}
```

## Best Practices

### 1. Named ManagedSettings Stores
Always use named stores for session-specific blocking:
```swift
let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
```

### 2. App Group Synchronization
Always call `synchronize()` after App Group writes:
```swift
suite?.set(data, forKey: key)
suite?.synchronize()
```

### 3. Error Handling
Check for App Group availability:
```swift
guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
    print("❌ Cannot access App Group")
    return
}
```

### 4. Event Throttling
Prevent event flooding in main app:
```swift
func checkEventsThrottled() {
    let now = Date().timeIntervalSince1970
    if now - lastEventsCheck >= 8 {
        checkDeviceActivityEvents()
    }
}
```

## Debugging

### Logging Strategy
The extension uses extensive logging for debugging:

```swift
print("🚀 [DeviceActivity] Extension initialized")
print("🎯 [DeviceActivity] Challenge started: \(activity)")
print("🛡️ [DeviceActivity] Blocked \(count) apps")
print("✅ [DeviceActivity] Challenge completed: \(activity)")
```

### App Group Inspection
Debug App Group contents:
```swift
let allKeys = suite.dictionaryRepresentation().keys
print("📋 Available keys: \(Array(allKeys))")
```

### Extension Status
Monitor extension initialization:
```swift
// Set in init()
suite?.set(Date().timeIntervalSince1970, forKey: "extension_initialized_timestamp")
suite?.set("ZenloopDeviceActivityMonitor initialized", forKey: "extension_status")
```

## Limitations & Considerations

### 1. Background Execution
- Extensions have limited execution time
- Heavy operations should be avoided
- Communication must be asynchronous

### 2. Notification Restrictions
- Extensions cannot directly show notifications
- Must communicate with main app for user notifications
- Current implementation has notifications disabled

### 3. Data Persistence
- Extensions cannot access main app's data directly
- Must use App Groups for all data sharing
- Limited to UserDefaults and simple data types

### 4. Error Recovery
- Extensions should handle errors gracefully
- Failed shield applications should not crash the extension
- Missing payloads should be handled silently

## Testing

### Extension Testing
1. **Install Extension**: Build and install the extension target
2. **Grant Permissions**: Enable Screen Time permissions in Settings
3. **Start Session**: Create a focus session in main app
4. **Verify Blocking**: Attempt to open blocked apps
5. **Check Logs**: Monitor console output for extension events

### App Group Testing
1. **Write Test Data**: Store test payload in App Group
2. **Trigger Extension**: Start monitoring session
3. **Verify Processing**: Check extension logs for payload processing
4. **Validate Communication**: Ensure events reach main app

## Security Considerations

### 1. App Group Access
- Only apps in the same App Group can access shared data
- Data is not encrypted by default in App Groups
- Sensitive information should be minimal

### 2. Token Management
- ApplicationTokens are secure references to apps
- ActivityCategoryTokens represent app categories
- Tokens cannot be reverse-engineered to app identifiers

### 3. Permission Model
- Requires explicit user consent for Screen Time access
- Cannot be bypassed programmatically
- System enforces all restrictions

## Performance Optimization

### 1. Data Structure Efficiency
- Use `Set` for ApplicationTokens (faster lookups)
- Limit App Group data size (max 50 events)
- Clean old data regularly (5-minute cleanup)

### 2. Memory Management
- Extensions have strict memory limits
- Avoid large data structures
- Release resources promptly

### 3. CPU Usage
- Minimize complex operations in callbacks
- Use efficient JSON encoding/decoding
- Batch operations when possible

This documentation provides a comprehensive overview of the DeviceActivityMonitor implementation in the Zenloop app, covering all aspects from basic usage to advanced debugging and optimization techniques.