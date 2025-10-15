# 🔗 Système d'Affiliation Zenloop

Documentation complète du système d'affiliation avec deep linking et tracking Firebase.

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Deep Linking](#deep-linking)
4. [Tracking Firebase](#tracking-firebase)
5. [Statuts et Types](#statuts-et-types)
6. [API & Endpoints](#api--endpoints)
7. [Testing](#testing)
8. [Dashboard Affilié](#dashboard-affilié)

---

## 🎯 Vue d'ensemble

Le système d'affiliation permet de :
- Tracker les utilisateurs référés par un code affilié
- Distinguer les trials des achats paid
- Calculer les commissions automatiquement
- Gérer les conversions trial → paid
- Fournir des statistiques en temps réel

### Flux Utilisateur

```
1. Utilisateur clique sur lien affilié
   zenloop://affiliate?code=JOHN123

2. App ouvre et sauvegarde le code
   UserDefaults + AffiliateManager

3. Utilisateur s'inscrit / premier lancement
   → Firebase enregistre l'affiliation

4. Utilisateur démarre un trial
   → Statut: pending
   → Revenue: 0

5. Trial se convertit en paid
   → Statut: converted
   → Revenue: 40€ (exemple)
   → Commission versée à l'affilié

6. OU Trial expire
   → Statut: expired
   → Revenue: 0
```

---

## 🏗️ Architecture

### Composants

#### **1. AffiliateManager.swift**
Gestionnaire principal du système d'affiliation.

**Responsabilités :**
- Traiter les deep links
- Sauvegarder les codes affiliés
- Communiquer avec Firebase
- Tracker les achats et conversions

**Singleton :**
```swift
AffiliateManager.shared
```

#### **2. FirebaseManager.swift**
Intégration avec l'enregistrement utilisateur.

**Hook :**
```swift
func registerDeviceOnFirstLaunch() async {
    // ...
    await AffiliateManager.shared.registerAffiliation(userId: deviceId)
}
```

#### **3. PurchaseManager.swift**
Intégration avec le système d'achats StoreKit.

**Tracking automatique :**
- Trial start
- Trial → Paid conversion
- Trial expiration
- Refunds

---

## 🔗 Deep Linking

### Format d'URL

```
zenloop://affiliate?code=AFFILIATECODE
```

**Exemples :**
```
zenloop://affiliate?code=JOHN123
zenloop://affiliate?code=MARIA456
zenloop://affiliate?code=PARTNER2024
```

### Configuration URL Scheme

**Dans Info.plist :**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zenloop</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.app.zenloop</string>
    </dict>
</array>
```

### Processing dans l'App

**zenloopApp.swift :**
```swift
.onOpenURL { url in
    Task {
        await AffiliateManager.shared.processDeepLink(url: url)
    }
}
```

### Génération de Liens

**Pour les affiliés :**
```
https://zenloop.app?ref=AFFILIATECODE
→ Redirige vers zenloop://affiliate?code=AFFILIATECODE
```

---

## 🔥 Tracking Firebase

### Structure Firestore

#### Collection: `affiliates`
Document par userId :

```json
{
  "affiliateCode": "JOHN123",
  "userId": "device_abc123",
  "timestamp": "2025-01-15T10:30:00Z",
  "purchaseType": "yearly",
  "purchaseDate": "2025-01-15T11:00:00Z",
  "status": "converted",
  "isTrial": false,
  "trialEndDate": null,
  "revenue": 40.0,
  "deviceInfo": {
    "model": "iPhone",
    "system": "iOS",
    "version": "18.2"
  }
}
```

#### Collection: `affiliateStats`
Document par code affilié :

```json
{
  "code": "JOHN123",
  "totalSignups": 156,
  "totalConversions": 42,
  "totalRevenue": 1680.0,
  "totalExpired": 78,
  "lastSignupDate": "2025-01-15T10:30:00Z",
  "lastConversionDate": "2025-01-15T11:00:00Z"
}
```

#### Collection: `affiliateConversions`
Document par conversion :

```json
{
  "affiliateCode": "JOHN123",
  "userId": "device_abc123",
  "fromType": "trial",
  "toType": "yearly",
  "conversionDate": "2025-01-15T11:00:00Z",
  "revenue": 40.0
}
```

---

## 📊 Statuts et Types

### AffiliateStatus

```swift
enum AffiliateStatus {
    case pending     // Trial actif
    case converted   // Trial → Paid
    case active      // Premium actif
    case expired     // Trial expiré
    case refunded    // Remboursé
}
```

### PurchaseType

```swift
enum PurchaseType {
    case trial       // 7 jours gratuits
    case monthly     // 10€/mois
    case yearly      // 40€/an
    case lifetime    // 150€ unique
}
```

### Mapping Statuts

| Événement | Status | Revenue | Action |
|-----------|--------|---------|--------|
| User signs up + trial | `pending` | 0€ | Attente |
| Trial → Monthly | `converted` | 10€ | Commission versée |
| Trial → Yearly | `converted` | 40€ | Commission versée |
| Trial → Lifetime | `converted` | 150€ | Commission versée |
| Trial expire | `expired` | 0€ | Aucune |
| User refund | `refunded` | -X€ | Déduction commission |

---

## 🔧 API & Endpoints

### Méthodes AffiliateManager

#### `processDeepLink(url: URL)`
Traite un lien d'affiliation.

```swift
let url = URL(string: "zenloop://affiliate?code=JOHN123")!
await AffiliateManager.shared.processDeepLink(url: url)
```

#### `registerAffiliation(userId: String)`
Enregistre l'affiliation dans Firebase.

```swift
await AffiliateManager.shared.registerAffiliation(userId: "device_abc123")
```

#### `trackPurchase(...)`
Track un achat avec distinction trial/paid.

```swift
await AffiliateManager.shared.trackPurchase(
    userId: "device_abc123",
    purchaseType: .yearly,
    isTrial: false,
    price: 40.0,
    trialEndDate: nil
)
```

#### `trackTrialConversion(...)`
Track une conversion trial → paid.

```swift
await AffiliateManager.shared.trackTrialConversion(
    userId: "device_abc123",
    fromTrial: true,
    toPurchaseType: .yearly,
    price: 40.0
)
```

#### `trackTrialExpired(userId: String)`
Track l'expiration d'un trial.

```swift
await AffiliateManager.shared.trackTrialExpired(userId: "device_abc123")
```

---

## 🧪 Testing

### Simuler un Lien d'Affiliation

```swift
// Dans l'app ou via console
AffiliateManager.shared.simulateAffiliateLink(code: "TEST123")
```

### Clear Data (Testing)

```swift
AffiliateManager.shared.clearAffiliateData()
```

### Debug Info

```swift
AffiliateManager.shared.printDebugInfo()
```

**Output :**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 AFFILIATE DEBUG INFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Code: JOHN123
Processed: true
Data: JOHN123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Test Scenarios

#### Scenario 1: Nouveau User avec Trial
```swift
1. simulateAffiliateLink(code: "TEST123")
2. registerAffiliation(userId: "test_user_1")
3. trackPurchase(..., isTrial: true)
→ Vérifier: status = pending, revenue = 0
```

#### Scenario 2: Trial → Paid Conversion
```swift
1. Après scenario 1...
2. trackTrialConversion(..., toType: .yearly, price: 40)
→ Vérifier: status = converted, revenue = 40
```

#### Scenario 3: Trial Expired
```swift
1. Après scenario 1...
2. trackTrialExpired(userId: "test_user_1")
→ Vérifier: status = expired, revenue = 0
```

---

## 📈 Dashboard Affilié

### Données Disponibles

Pour chaque affilié (code), vous pouvez afficher :

**Métriques Principales :**
- Total Signups
- Total Conversions
- Total Revenue
- Conversion Rate (conversions / signups)

**Métriques Détaillées :**
- Trials actifs
- Trials expirés
- Refunds

**Timeline :**
- Last Signup Date
- Last Conversion Date

### Requêtes Firestore

#### Stats d'un Affilié

```swift
let statsRef = db.collection("affiliateStats").document(code)
let snapshot = try await statsRef.getDocument()
let stats = try snapshot.data(as: AffiliateStats.self)
```

#### Utilisateurs Référés

```swift
let usersRef = db.collection("affiliates")
    .whereField("affiliateCode", isEqualTo: code)
let snapshot = try await usersRef.getDocuments()
```

#### Conversions Récentes

```swift
let conversionsRef = db.collection("affiliateConversions")
    .whereField("affiliateCode", isEqualTo: code)
    .order(by: "conversionDate", descending: true)
    .limit(to: 20)
let snapshot = try await conversionsRef.getDocuments()
```

---

## 🎁 Commission System

### Calcul des Commissions

**Modèle suggéré : 30% des revenus**

| Type | Prix | Commission |
|------|------|------------|
| Monthly | 10€ | 3€ |
| Yearly | 40€ | 12€ |
| Lifetime | 150€ | 45€ |

### Payout Rules

- **Minimum payout**: 50€
- **Payout frequency**: Mensuel
- **Trial period**: Commission versée UNIQUEMENT après conversion
- **Refund policy**: Commission déduite si refund < 30 jours

---

## 🔐 Security

### Validation du Code

```swift
private func isValidAffiliateCode(_ code: String) -> Bool {
    // Alphanumeric, 4-20 caractères
    let pattern = "^[A-Z0-9]{4,20}$"
    return code.range(of: pattern, options: .regularExpression) != nil
}
```

### Prévention Fraud

- Code unique par affilié
- Max 1 affiliation par device ID
- Tracking IP/Device fingerprint
- Review manuelle des gros volumes

---

## 📝 Notes Importantes

### ⚠️ Trial vs Paid

**CRUCIAL :** Bien distinguer les trials des achats paid !

```swift
// ✅ CORRECT
trackPurchase(..., isTrial: true, price: 0)  // Trial
trackPurchase(..., isTrial: false, price: 40) // Paid

// ❌ INCORRECT
trackPurchase(..., isTrial: false, price: 0)  // Pas de revenue = pas de commission
```

### 🔄 Conversion Tracking

Quand un trial se convertit en paid, DEUX événements :
1. `trackTrialConversion()` → Enregistre la conversion
2. Stats mise à jour → Revenue comptabilisé

### 📊 Métriques Importantes

Pour le dashboard affilié, focus sur :
- **Conversion Rate** : conversions / signups
- **Revenue per Signup** : totalRevenue / totalSignups
- **Trial Completion Rate** : (conversions + expired) / signups

---

## 🚀 Next Steps

### Phase 1 : MVP (FAIT ✅)
- [x] Deep linking
- [x] Firebase tracking
- [x] Trial/Paid distinction
- [x] Conversion tracking

### Phase 2 : Dashboard (À FAIRE)
- [ ] Web dashboard pour affiliés
- [ ] Génération automatique de liens
- [ ] Statistiques en temps réel
- [ ] Export CSV

### Phase 3 : Advanced (FUTUR)
- [ ] Payout automation
- [ ] Multi-tier commissions
- [ ] Affiliate leaderboard
- [ ] Email notifications

---

## 📞 Support

Pour toute question sur le système d'affiliation :
- Email: dev@zenloop.app
- Slack: #affiliation-support

---

**Dernière mise à jour** : Janvier 2025
**Version** : 1.0.0
