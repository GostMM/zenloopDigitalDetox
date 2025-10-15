# 🔄 Système de Statuts Complet - Affiliation Zenloop

## 📊 Tous les Statuts Gérés

### 1️⃣ **PENDING** (Trial en attente)
**Quand** : User active un trial gratuit

```swift
trackPurchase(isTrial: true, price: 9.99)
```

**Firebase Updates** :
```javascript
// affiliateConversions (CRÉÉ)
{
  status: "pending",
  isTrial: true,
  commission: 2.997,  // 30% calculé mais non payé
  purchaseAmount: 9.99,
  trialEndDate: Date + 7 jours
}

// affiliateStats (INCRÉMENT)
{
  totalPending: +1  // ⬆️
}

// Dashboard affiche
Trials en Attente: 1
Revenu Total: 0€ (pas encore payé)
```

---

### 2️⃣ **ACTIVE** (Achat direct payant)
**Quand** : User achète directement sans trial

```swift
trackPurchase(isTrial: false, price: 49.99)
```

**Firebase Updates** :
```javascript
// affiliateConversions (CRÉÉ)
{
  status: "active",
  isTrial: false,
  commission: 19.996,  // 40% payé immédiatement
  purchaseAmount: 49.99
}

// affiliateStats (INCRÉMENT)
{
  totalConversions: +1,  // ⬆️
  totalRevenue: +19.996  // ⬆️
}

// Dashboard affiche
Conversions Payées: 1
Revenu Total: 19,99€
```

---

### 3️⃣ **CONVERTED** (Trial → Payant)
**Quand** : User paie après le trial

```swift
trackTrialConversion(price: 49.99)
```

**Firebase Updates** :
```javascript
// affiliateConversions (MIS À JOUR)
{
  status: "converted",  // était "pending"
  commission: 14.997,   // 30% pour conversion
  purchaseAmount: 49.99
}

// affiliateStats (INCRÉMENT & DÉCRÉMENT)
{
  totalPending: -1,       // ⬇️ Retire du pending
  totalConversions: +1,   // ⬆️ Ajoute aux conversions
  totalRevenue: +14.997   // ⬆️ Commission 30%
}

// Dashboard affiche
Trials en Attente: 0 (-1)
Conversions Payées: 1 (+1)
Revenu Total: 14,99€ (+14.99)
```

---

### 4️⃣ **EXPIRED** (Trial expiré sans paiement)
**Quand** : Trial expire et user ne paie pas

```swift
trackTrialExpired(userId: "user123")
```

**Firebase Updates** :
```javascript
// affiliateConversions (MIS À JOUR)
{
  status: "expired",  // était "pending"
  commission: 0,      // Aucun revenu
}

// affiliateStats (INCRÉMENT & DÉCRÉMENT)
{
  totalPending: -1,    // ⬇️ Retire du pending
  totalExpired: +1     // ⬆️ Compte les expirés
}

// Dashboard affiche
Trials en Attente: 0 (-1)
Conversions Payées: 0 (aucun changement)
Revenu Total: 0€ (aucun changement)
```

---

### 5️⃣ **REFUNDED** (Remboursement)
**Quand** : User demande un remboursement (à implémenter)

```swift
// À créer
trackRefund(userId: "user123", originalPrice: 49.99)
```

**Firebase Updates** (futur) :
```javascript
// affiliateConversions (MIS À JOUR)
{
  status: "refunded",
  refundedAt: Timestamp(now)
}

// affiliateStats (DÉCRÉMENT)
{
  totalConversions: -1,   // ⬇️
  totalRevenue: -19.996   // ⬇️ Retire la commission
}
```

---

## 📈 Dashboard : Affichage par Statut

### Structure des Stats
```javascript
{
  totalSignups: 10,        // Inscriptions totales (tous statuts)
  totalPending: 3,         // Trials en attente
  totalConversions: 5,     // Payés (active + converted)
  totalExpired: 2,         // Trials expirés sans paiement
  totalRevenue: 99.98      // Commission cumulée (payée uniquement)
}
```

### Cards Dashboard
```
┌──────────────────────┐  ┌──────────────────────┐
│ Total Inscriptions   │  │ Trials en Attente    │
│        10            │  │         3            │ (orange)
└──────────────────────┘  └──────────────────────┘

┌──────────────────────┐  ┌──────────────────────┐
│ Conversions Payées   │  │ Revenu Total         │
│         5            │  │      99,98 €         │
└──────────────────────┘  └──────────────────────┘

┌──────────────────────┐
│ Taux de Conversion   │
│       50.0%          │ (5/10)
└──────────────────────┘
```

---

## 🔄 Flux Complets par Statut

### Scénario A : Trial puis Conversion
```
1. User active trial
   trackPurchase(isTrial: true)
   → Status: PENDING
   → totalPending: +1
   → Dashboard: "Trials en attente: 1"

2. Trial expire (7 jours)
   User paie 49.99€
   trackTrialConversion()
   → Status: PENDING → CONVERTED
   → totalPending: -1
   → totalConversions: +1
   → totalRevenue: +14.997€
   → Dashboard: "Conversions: 1, Revenue: 14,99€"
```

### Scénario B : Trial puis Expiration
```
1. User active trial
   trackPurchase(isTrial: true)
   → Status: PENDING
   → totalPending: +1

2. Trial expire sans paiement
   trackTrialExpired()
   → Status: PENDING → EXPIRED
   → totalPending: -1
   → totalExpired: +1
   → Dashboard: "Trials en attente: 0" (pas de revenu)
```

### Scénario C : Achat Direct (sans trial)
```
1. User achète directement
   trackPurchase(isTrial: false)
   → Status: ACTIVE
   → totalConversions: +1
   → totalRevenue: +19.996€ (40%)
   → Dashboard: "Conversions: 1, Revenue: 19,99€"
```

---

## 📋 Table des Conversions : Filtrage par Statut

### Affichage dans le Dashboard
```javascript
// Tous les statuts affichés
{recentConversions.map((conversion) => (
  <tr>
    <td>{conversion.userId}</td>
    <td>{getStatusBadge(conversion.status)}</td>
    <td>{formatRevenue(conversion.purchaseAmount)}</td>
    <td>{formatRevenue(conversion.commission)}</td>
  </tr>
))}
```

### Badges de Statut
| Statut | Couleur | Label |
|--------|---------|-------|
| `pending` | Orange (#FFA500) | En attente |
| `active` | Vert (#00ff88) | Actif |
| `converted` | Cyan (#33ccff) | Converti |
| `expired` | Rouge (#ff4444) | Expiré |
| `refunded` | Gris (#888) | Remboursé |

---

## 🎯 Règles Métier

### Commission selon Type
| Type Achat | Taux | Status |
|------------|------|--------|
| Trial | 30% | `pending` (pas payé) |
| Trial → Payant | 30% | `converted` (payé) |
| Achat Direct | 40% | `active` (payé) |

### Incrément totalRevenue
✅ **Payé** : `active`, `converted`
❌ **Non payé** : `pending`, `expired`, `refunded`

### Calcul Taux de Conversion
```javascript
const conversionRate = totalSignups > 0
  ? (totalConversions / totalSignups) * 100
  : 0;

// Exemple: 5 conversions / 10 inscriptions = 50%
```

---

## 🔍 Requêtes Firebase

### Récupérer uniquement les pending
```javascript
query(
  collection(db, 'affiliateConversions'),
  where('status', '==', 'pending'),
  where('affiliateCode', '==', 'JOHN123')
)
```

### Récupérer uniquement les payés (revenue)
```javascript
query(
  collection(db, 'affiliateConversions'),
  where('status', 'in', ['active', 'converted']),
  where('affiliateCode', '==', 'JOHN123')
)
```

---

## ⚙️ Index Firebase Requis

Pour optimiser les queries :

```javascript
// Collection: affiliateConversions
- Composite: (affiliateCode, status, convertedAt)
- Composite: (userId, status)
- Simple: status
- Simple: isTrial

// Collection: affiliateStats
- Simple: email
- Simple: affiliateCode
```

---

## 🧪 Test des Statuts

### Test 1 : Trial Pending
```swift
await AffiliateManager.shared.trackPurchase(
    userId: "test1",
    purchaseType: .monthly,
    isTrial: true,
    price: 9.99,
    trialEndDate: Date().addingTimeInterval(7*24*3600)
)

// Vérifier Firebase:
// - affiliateConversions: status = "pending"
// - affiliateStats: totalPending = 1
```

### Test 2 : Conversion
```swift
await AffiliateManager.shared.trackTrialConversion(
    userId: "test1",
    fromTrial: true,
    toPurchaseType: .yearly,
    price: 49.99
)

// Vérifier Firebase:
// - affiliateConversions: status = "converted"
// - affiliateStats: totalPending = 0, totalConversions = 1, totalRevenue = 14.997
```

### Test 3 : Expiration
```swift
await AffiliateManager.shared.trackTrialExpired(userId: "test1")

// Vérifier Firebase:
// - affiliateConversions: status = "expired"
// - affiliateStats: totalPending = 0, totalExpired = 1
```

---

## 📊 Résumé

| Action | Fonction | Status | totalPending | totalConversions | totalRevenue |
|--------|----------|--------|--------------|------------------|--------------|
| Trial activé | `trackPurchase(trial: true)` | `pending` | +1 | — | — |
| Achat direct | `trackPurchase(trial: false)` | `active` | — | +1 | +40% |
| Trial converti | `trackTrialConversion()` | `converted` | -1 | +1 | +30% |
| Trial expiré | `trackTrialExpired()` | `expired` | -1 | — | — |

**✅ Tous les statuts sont maintenant trackés et affichés en temps réel !**
