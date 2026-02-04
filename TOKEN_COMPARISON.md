# 🔍 Comparaison des Méthodes d'Accès aux Tokens

## Question Posée
> "Via TimerCard on a utilisé FamilyActivitySelection, mais dans l'extension DeviceActivity on utilise l'extension device activity - est-ce toujours une question de token ?"

## ✅ Réponse : OUI, c'est TOUJOURS le même ApplicationToken !

---

## 🎯 Les Deux Chemins vers le Même Token

### Chemin #1: Via FamilyActivitySelection (App Principale)

**Utilisé dans:** TimerCard, Sessions, Challenges

```swift
// zenloop/Views/Components/TimerCard.swift

@State private var selectedApps = FamilyActivitySelection()

// User sélectionne des apps via FamilyActivityPicker
FamilyActivityPicker(selection: $selectedApps)

// Accès aux tokens
let tokens: Set<ApplicationToken> = selectedApps.applicationTokens

// Persistance
let encoder = JSONEncoder()
let data = try encoder.encode(selectedApps)  // ← FamilyActivitySelection est Codable
UserDefaults.standard.set(data, forKey: "apps")

// Reload
let decoder = JSONDecoder()
let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
let tokens = selection.applicationTokens  // ← Récupération des tokens
```

**Avantages:**
- ✅ User choisit manuellement les apps
- ✅ UI picker native d'Apple
- ✅ Codable pour persistence
- ✅ Contient tokens + categories

---

### Chemin #2: Via DeviceActivity (Extension)

**Utilisé dans:** TotalActivityReport, FullStatsPageView

```swift
// zenloopactivity/TotalActivityReport.swift

func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ExtensionActivityReport {

    var appDurations: [ApplicationToken: (name: String, duration: TimeInterval)] = [:]

    // Apple nous donne les données d'usage
    for await datum in data {
        for await segment in datum.activitySegments {
            for await catActivity in segment.categories {
                for await app in catActivity.applications {

                    // ✅ LE TOKEN EST ICI !
                    if let token = app.application.token {
                        let name = app.application.localizedDisplayName ?? "App"
                        appDurations[token] = (name, app.totalActivityDuration)
                    }
                }
            }
        }
    }

    // Convertir en ExtensionAppUsage
    let allApps = appDurations.map { (token, v) in
        ExtensionAppUsage(
            name: v.name,
            duration: v.duration,
            token: token  // ← Le token est passé ici
        )
    }

    return ExtensionActivityReport(allApps: allApps, ...)
}
```

**Avantages:**
- ✅ Données d'usage réelles du système
- ✅ Pas besoin de sélection manuelle
- ✅ Historique complet
- ✅ Même type: `ApplicationToken`

---

## 🔬 Comparaison Détaillée

| Aspect | FamilyActivitySelection | DeviceActivity Extension |
|--------|------------------------|--------------------------|
| **Source** | User selection (picker) | System usage data |
| **Type Token** | `ApplicationToken` ✅ | `ApplicationToken` ✅ |
| **Codable** | ✅ Oui (tout l'objet) | ⚠️ Non directement* |
| **Quand obtenu** | User choisit | Après utilisation |
| **Données incluses** | Tokens seulement | Tokens + usage stats |
| **Accès depuis** | App principale | Extension seulement** |
| **Usage typique** | Blocking, Sessions | Reports, Statistics |

*Le token lui-même n'est pas directement Codable seul, MAIS il l'est dans FamilyActivitySelection
**L'extension renvoie des données via la view, pas les tokens bruts

---

## 💡 L'Insight Clé

### C'est le MÊME ApplicationToken dans les deux cas !

```swift
// Scénario complet:

// 1. User sélectionne Instagram via FamilyActivityPicker
let selection = FamilyActivitySelection()
selection.applicationTokens.contains(instagramToken)  // ← Token A

// 2. User utilise Instagram pendant 30min

// 3. DeviceActivity extension lit les stats
for await app in applications {
    if app.application.token == instagramToken {  // ← Token A (même!)
        print("Instagram: 30min")
    }
}

// 4. On peut bloquer Instagram
let store = ManagedSettingsStore()
store.shield.applications = [instagramToken]  // ← Token A (toujours le même!)
```

**Le token est l'identifiant UNIQUE d'Apple pour une app donnée**

---

## 🎯 Application à Notre Problème de Blocage

### Pourquoi c'est Important

Dans notre système de blocage:

```swift
// FullStatsPageView.swift - On obtient le token via DeviceActivity
struct ExtensionAppUsage {
    let name: String
    let token: ApplicationToken  // ← Obtenu via DeviceActivity
}

// User clique "Block Instagram"
func blockApp() {
    // On a déjà le token grâce à DeviceActivity ! ✅
    let token = app.token

    // On peut le bloquer
    let store = ManagedSettingsStore(named: .init(storeName))
    store.shield.applications = [token]

    // ✅ ET on peut le persister dans ActiveBlock
    let block = ActiveBlock(
        appName: app.name,
        storeName: storeName,
        duration: duration,
        token: token  // ← Encodable car fait partie de FamilyActivitySelection
    )
}

// Au restart de l'app
func restoreBlock(block: ActiveBlock) {
    // ✅ On décode le token
    let token = block.getApplicationToken()

    // ✅ On peut recréer le blocage
    let store = ManagedSettingsStore(named: .init(block.storeName))
    store.shield.applications = [token]
}
```

---

## 🔧 Encodage du Token

### Comment Encoder un ApplicationToken Seul

Même si `ApplicationToken` n'est pas directement `Codable`, on peut l'encoder via `FamilyActivitySelection`:

```swift
// Méthode 1: Via FamilyActivitySelection (✅ Recommandé)
func encodeToken(_ token: ApplicationToken) -> Data? {
    var selection = FamilyActivitySelection()
    selection.applicationTokens = [token]
    return try? JSONEncoder().encode(selection)
}

func decodeToken(from data: Data) -> ApplicationToken? {
    let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    return selection?.applicationTokens.first
}

// Méthode 2: NSKeyedArchiver (alternative)
func encodeTokenAlt(_ token: ApplicationToken) -> Data? {
    return try? NSKeyedArchiver.archivedData(
        withRootObject: token,
        requiringSecureCoding: true
    )
}
```

**Note:** Dans notre cas, on va utiliser Méthode 1 via FamilyActivitySelection.

---

## 📊 Schéma de Flux Complet

```
[USER SÉLECTION]
    ↓
FamilyActivityPicker
    ↓
FamilyActivitySelection { applicationTokens: [Token1, Token2] }
    ↓
Encode → UserDefaults
    ↓
[UTILISATION DES APPS]
    ↓
DeviceActivity collecte stats
    ↓
Extension: makeConfiguration()
    ↓
app.application.token → Token1 (même que sélection!)
    ↓
ExtensionAppUsage { token: Token1 }
    ↓
[USER CLIQUE "BLOCK"]
    ↓
ActiveBlock { appToken: encode(Token1) }
    ↓
ManagedSettingsStore { shield: [Token1] }
    ↓
[APP RESTART]
    ↓
BlockSyncManager.restoreBlock()
    ↓
decode(appToken) → Token1
    ↓
ManagedSettingsStore { shield: [Token1] } recréé ✅
```

---

## ✅ Conclusion

1. **Même Token** : FamilyActivitySelection et DeviceActivity utilisent le MÊME `ApplicationToken`

2. **Codable** : Le token est encodable via `FamilyActivitySelection`

3. **Interopérabilité** : On peut:
   - Obtenir token via DeviceActivity ✅
   - L'encoder dans ActiveBlock ✅
   - Le décoder au restart ✅
   - Recréer le blocage ✅

4. **Notre Solution** : Valide et optimale ! 🎯

---

**Date:** 2026-02-03
**Status:** ✅ CONFIRMED - Token persistence is possible and optimal
