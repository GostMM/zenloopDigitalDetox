# 🔄 Logique de Mise à Jour - Système d'Affiliation iOS

## 📱 Architecture de Mise à Jour

```
User Action (App) → AffiliateManager → Firebase → Dashboard Web (temps réel)
```

## 🎯 Points d'Intégration dans l'App

### 1️⃣ **Enregistrement Initial** - `FirebaseManager.swift:47`

**Quand** : Premier lancement de l'app après installation

```swift
// FirebaseManager.swift ligne 47
await AffiliateManager.shared.registerAffiliation(userId: deviceId)
```

**Ce qui se passe** :
```
1. Vérifie si code affilié existe (clipboard ou Firebase recovery)
2. Vérifie deviceFingerprint pour éviter doublons
3. Crée document dans affiliates collection
4. Incrémente totalSignups dans affiliateStats
5. Marque le clic comme "claimed" dans affiliateClicks
```

**Firebase mis à jour** :
```javascript
// Collection: affiliates
{
  affiliateCode: "JOHN123",
  userId: "device-uuid",
  deviceFingerprint: "IDFV",
  status: "pending",
  timestamp: now
}

// Collection: affiliateStats (INCRÉMENT)
{
  totalSignups: +1  // ⬆️ Dashboard se met à jour instantanément
}
```

### 2️⃣ **Achat / Trial** - `PurchaseManager.swift:426`

**Quand** : User achète un produit (trial ou payant)

```swift
// PurchaseManager.swift ligne 426
await AffiliateManager.shared.trackPurchase(
    userId: deviceId,
    purchaseType: purchaseType,  // .monthly, .yearly, .lifetime
    isTrial: isTrial,            // true si trial
    price: Double(truncating: product.price as NSNumber),
    trialEndDate: expirationDate
)
```

#### Cas A : Trial (isTrial = true)

**Ce qui se passe** :
```
1. Calcule commission = price * 0.30 (30%)
2. Crée/met à jour document dans affiliates
3. ❌ NE crée PAS de conversion
4. ❌ NE met PAS à jour totalRevenue/totalConversions
5. Status = "pending"
```

**Firebase mis à jour** :
```javascript
// Collection: affiliates
{
  status: "pending",
  isTrial: true,
  purchaseAmount: 9.99,
  purchaseType: "monthly"
}

// affiliateStats : AUCUN CHANGEMENT
// Dashboard : Affiche toujours 0€ (normal, trial en attente)
```

#### Cas B : Achat Direct (isTrial = false)

**Ce qui se passe** :
```
1. Calcule commission = price * 0.40 (40%)
2. Crée/met à jour document dans affiliates
3. ✅ Crée document dans affiliateConversions
4. ✅ Incrémente totalRevenue et totalConversions
5. Status = "active"
```

**Firebase mis à jour** :
```javascript
// Collection: affiliateConversions (NOUVEAU DOC)
{
  affiliateCode: "JOHN123",
  userId: "device-uuid",
  purchaseType: "yearly",
  purchaseAmount: 49.99,
  commission: 19.996,  // 40% de 49.99
  status: "active",
  convertedAt: now
}

// Collection: affiliateStats (INCRÉMENT)
{
  totalRevenue: +19.996,      // ⬆️
  totalConversions: +1,       // ⬆️
  lastConversionDate: now
}

// 🎉 Dashboard se met à jour en < 1 seconde !
```

### 3️⃣ **Conversion Trial → Paid** - Pas encore implémenté

**Quand** : Trial expire et user paie (à implémenter)

```swift
// À appeler quand trial converti
await AffiliateManager.shared.trackTrialConversion(
    userId: deviceId,
    fromTrial: true,
    toPurchaseType: .yearly,
    price: 49.99
)
```

**Ce qui se passe** :
```
1. Calcule commission = price * 0.30 (30% pour conversion)
2. Met à jour status = "converted"
3. Crée document dans affiliateConversions
4. Incrémente totalRevenue et totalConversions
```

## 🔥 Flux Complet Temps Réel

### Scénario Réel : User achète Yearly 49.99€

```
┌─────────────────────────────────────────────────┐
│ 1. User clique "Acheter Annuel 49.99€"         │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 2. PurchaseManager.purchase() appelé            │
│    → StoreKit transaction réussie               │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 3. trackPurchase() appelé                       │
│    userId: "ABC123"                             │
│    purchaseType: .yearly                        │
│    isTrial: false                               │
│    price: 49.99                                 │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 4. AffiliateManager calcule                    │
│    commission = 49.99 * 0.40 = 19.996€          │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 5. Firebase Operations (3 écritures)           │
│                                                 │
│ A. Crée affiliateConversions doc               │
│    {                                            │
│      purchaseAmount: 49.99,                     │
│      commission: 19.996,                        │
│      convertedAt: now                           │
│    }                                            │
│                                                 │
│ B. Incrémente affiliateStats                    │
│    totalRevenue += 19.996                       │
│    totalConversions += 1                        │
│                                                 │
│ C. Met à jour affiliates                        │
│    status: "active"                             │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 6. Dashboard Web (onSnapshot)                   │
│    ⚡ Reçoit mise à jour instantanée            │
│    📊 totalRevenue: 19.996€ → Affiche 19,99 €  │
│    📊 totalConversions: 1                       │
│    📋 Table: Nouvelle ligne apparaît            │
│                                                 │
│    ⏱️ Délai: < 1 seconde                        │
└─────────────────────────────────────────────────┘
```

## 🎯 Points Clés de la Logique

### ✅ Utilisation de `FieldValue.increment()`

**Pourquoi** : Évite les race conditions

```swift
// ❌ MAUVAIS (race condition possible)
let current = stats.totalRevenue
stats.totalRevenue = current + commission

// ✅ BON (atomique)
"totalRevenue": FieldValue.increment(Double(commission))
```

**Avantage** : Si 2 achats arrivent simultanément, Firebase gère l'incrémentation correctement.

### ✅ Query par `affiliateCode`

**Pourquoi** : Le document ID n'est pas le code affilié

```swift
// ❌ MAUVAIS
let ref = db.collection("affiliateStats").document(affiliateCode)

// ✅ BON
let query = db.collection("affiliateStats")
    .whereField("affiliateCode", isEqualTo: affiliateCode)
    .limit(to: 1)
```

**Raison** : Le document est créé avec Firebase Auth UID comme ID, pas le code affilié.

### ✅ `setData(merge: true)` au lieu de `updateData()`

**Pourquoi** : Crée le document s'il n'existe pas

```swift
// ❌ MAUVAIS (échoue si doc n'existe pas)
try await docRef.updateData(data)

// ✅ BON (crée ou met à jour)
try await docRef.setData(data, merge: true)
```

### ✅ Double Type pour Revenue

**Pourquoi** : Précision décimale

```swift
// ❌ MAUVAIS (perd les centimes)
FieldValue.increment(Int64(19.996))  // → 19

// ✅ BON (garde les centimes)
FieldValue.increment(Double(19.996))  // → 19.996
```

## 📊 Dashboard : Réception Temps Réel

### Avant (lecture unique)
```javascript
const snapshot = await getDocs(query);
// ❌ Fige les données au moment du chargement
```

### Après (temps réel)
```javascript
onSnapshot(query, (snapshot) => {
  // ✅ Se déclenche à chaque modification Firebase
  const data = snapshot.docs[0].data();
  setStats(data);  // React re-render automatique
});
```

**Résultat** : Dashboard se met à jour **sans refresh** quand iOS écrit dans Firebase !

## 🧪 Test Manuel

### 1. Simuler un achat dans Xcode

```swift
// Dans un bouton debug ou test
Task {
    let deviceId = await FirebaseManager.shared.getDeviceId()

    await AffiliateManager.shared.trackPurchase(
        userId: deviceId,
        purchaseType: .yearly,
        isTrial: false,
        price: 49.99
    )

    print("✅ Achat simulé!")
}
```

### 2. Observer le Dashboard

- Ouvrir le dashboard dans le navigateur
- Ouvrir la console (F12)
- Observer les logs :

```javascript
📊 Stats mise à jour: {
  totalSignups: 1,
  totalConversions: 1,
  totalRevenue: 19.996
}

💰 Conversions mise à jour: 1 conversions
```

- **Le dashboard se met à jour instantanément** (< 1 sec)

## 🔍 Débogage

### Log iOS
```swift
// Vérifier dans la console Xcode
✅ [AFFILIATE] Updated affiliate stats with commission: 19.996
✅ [AFFILIATE] Purchase tracked - Type: yearly, Trial: false, Commission: 19.996
```

### Log Dashboard
```javascript
// Console navigateur
📊 Stats mise à jour: { totalRevenue: 19.996, ... }
```

### Firebase Console
- Collection `affiliateStats` → Voir `totalRevenue` augmenter
- Collection `affiliateConversions` → Voir nouveau document

## ⚠️ Cas Spéciaux

### Trial sans conversion
```
User active trial → totalSignups +1
Dashboard: 0€ (normal)

Trial expire sans paiement → status: "expired"
Dashboard: toujours 0€
```

### Trial avec conversion
```
User active trial → totalSignups +1
User paie après trial → trackTrialConversion()
Dashboard: +commission (30%)
```

### Achat direct sans trial
```
User paie directement → trackPurchase(isTrial: false)
Dashboard: +commission (40%) instantanément
```

## 📝 Résumé

| Action | Fonction iOS | Firebase Mis à Jour | Dashboard |
|--------|-------------|---------------------|-----------|
| Installation + clic lien | `registerAffiliation()` | `totalSignups +1` | Inscriptions +1 |
| Achat trial | `trackPurchase(isTrial: true)` | Rien | Pas de changement |
| Achat direct | `trackPurchase(isTrial: false)` | `totalRevenue +40%`, `totalConversions +1` | Revenue +€, Conversions +1 |
| Conversion trial | `trackTrialConversion()` | `totalRevenue +30%`, `totalConversions +1` | Revenue +€, Conversions +1 |

**Délai de synchronisation** : < 1 seconde grâce à `onSnapshot()` 🚀
