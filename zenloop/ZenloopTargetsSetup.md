# 📱 Zenloop – Architecture et Configuration du Projet iOS

Une application iOS de bien-être numérique qui permet de bloquer des apps, créer des défis de concentration, et réduire la distraction grâce aux APIs natives Screen Time.

---

## 🏗️ Architecture du projet

```
Zenloop/
├── ZenloopApp.swift
├── Views/
│   ├── Onboarding/
│   ├── Dashboard/
│   ├── Challenges/
│   └── Profile/
├── Models/
├── ViewModels/
├── Managers/
│   ├── ScreenTimeManager.swift
│   └── FirebaseManager.swift
├── Extensions/
├── Resources/
├── AppIntentsExtension/
│   └── StartChallengeIntent.swift
├── ActionExtension/
│   └── QuickBlockNow.swift
├── DeviceActivityMonitorExtension/
│   └── ZenloopMonitor.swift
├── DeviceActivityReportExtension/
│   └── ZenloopReport.swift
├── NotificationServiceExtension/ (optionnel)
│   └── RichNotification.swift
└── Info.plist (et .entitlements par target)
```

---

## 🔧 Setup Firebase

1. Crée un projet sur [Firebase Console](https://console.firebase.google.com).
2. Active **Authentication** (email + Apple).
3. Active **Firestore** (mode test puis règles sécurisées).
4. Télécharge `GoogleService-Info.plist` et ajoute-le au target principal.

---

## 🧩 Intégration des Targets et Extensions

### ✅ 1. App Intents Extension

**But :** définir des Intents pour Siri, Automations, Spotlight, etc.

- Dans Xcode : `File > New > Target > App Intents Extension`
- Exemple de `StartChallengeIntent.swift` :

```swift
import AppIntents

struct StartChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Challenge"

    func perform() async throws -> some IntentResult {
        // Logique pour démarrer le défi
        return .result()
    }
}
```

---

### ✅ 2. Action Extension

**But :** actions rapides depuis les autres apps (partage, menu contextuel, etc.).

- Target : `File > New > Target > Action Extension`
- Implémentation dans `ActionViewController.swift`

---

### ✅ 3. Device Activity Monitor Extension

**But :** suivre le comportement de l’utilisateur vis-à-vis des apps bloquées.

- Target : `File > New > Target > Device Activity Monitor Extension`
- Exemple :

```swift
import DeviceActivity

class ZenloopMonitor: DeviceActivityMonitorExtension {
    override func intervalDidStart(for activity: DeviceActivityName) {
        // Début d’un suivi de session
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Fin du suivi
    }
}
```

---

### ✅ 4. Device Activity Report Extension

**But :** afficher une interface personnalisée du rapport d’activité.

- Target : `File > New > Target > Device Activity Report Extension`
- Exemple avec SwiftUI :

```swift
import DeviceActivity

struct ZenloopReport: DeviceActivityReportScene {
    var body: some DeviceActivityReport {
        DeviceActivityReport("Zenloop Report") {
            // UI ici
        }
    }
}
```

---

### ✅ 5. Notification Service Extension (optionnel)

**But :** enrichir ou modifier les notifications avant affichage.

- Target : `Notification Service Extension`
- Exemple :

```swift
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        // Modification ici
        contentHandler(request.content)
    }
}
```

---

## 🔐 Entitlements & Capabilities

Ajoute dans `*.entitlements` :

```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.developer.screen-time-management</key>
<true/>
<key>com.apple.developer.device-activity-monitoring</key>
<true/>
```

---

## 📝 Demande d’accès Apple (Screen Time API)

Rédige ta demande via le Developer Portal :

- Nom App : **Zenloop**
- Objectif : Bien-être numérique, réduction des distractions, soutien à la concentration.
- Fonctionnalités : Blocage app, défis, rapports d’activité, suivi du self-control.
- Confidentialité : Pas de données vendues. Traité via Firebase (anonymisé si possible).

---

## 🧪 Tester en local (Simulator)

1. Choisir simulateur (iPhone 15 Pro ou +).
2. Aller dans Réglages > Temps d’écran > Activer.
3. Autoriser le DeviceActivity via `Settings > App > Screen Time > Always Allow`.
4. Lancer l’app.
5. Déclencher un défi et tester les comportements en tâche de fond.

---

## 🧠 Tips & Recommandations

- Implémente d'abord un **défi simple** : bloquer TikTok/Instagram pendant 30 min.
- Ajoute une UI avec **progression visuelle** du défi.
- Utilise des **rappels** (notifications silencieuses) pour renforcer l’engagement.

---

## 📍 Prochaine étape

- [ ] Ajouter tous les targets ci-dessus dans Xcode
- [ ] Configurer Firebase
- [ ] Implémenter `StartChallengeIntent` et la logique de base
- [ ] Créer une page “Mes défis” avec compteur de progression
- [ ] Tester sur TestFlight

---
