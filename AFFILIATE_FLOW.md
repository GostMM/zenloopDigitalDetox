# 🔄 Système d'Affiliation Zenloop - Flux Bidirectionnel Complet

## 🎯 Architecture Globale

```
Web (React) ←→ Firebase ←→ iOS App (Swift)
```

## 📊 Collections Firebase

### 1. `affiliateStats` - Stats des Affiliés
**Document ID**: Firebase Auth UID de l'affilié
```javascript
{
  email: "affiliate@example.com",
  name: "John Doe",
  affiliateCode: "JOHN123",
  totalSignups: 0,        // Incrémenté à chaque inscription
  totalConversions: 0,    // Incrémenté à chaque achat payant
  totalRevenue: 0.0,      // Commission cumulée (30% ou 40%)
  createdAt: Timestamp,
  userId: "auth-uid"
}
```

### 2. `affiliates` - Utilisateurs Référés
**Document ID**: Firebase Auth UID de l'utilisateur
```javascript
{
  affiliateCode: "JOHN123",
  userId: "user-uid",
  deviceFingerprint: "IDFV-UUID",
  timestamp: Timestamp,
  status: "pending|converted|active|expired",
  purchaseType: "trial|monthly|yearly|lifetime",
  purchaseAmount: 9.99,
  revenue: 2.99,          // Commission affilié
  isTrial: true,
  deviceInfo: {...}
}
```

### 3. `affiliateConversions` - Conversions Détaillées
**Document ID**: Auto-généré
```javascript
{
  affiliateCode: "JOHN123",
  userId: "user-uid",
  purchaseType: "monthly|yearly|lifetime",
  purchaseAmount: 49.99,
  commission: 14.99,
  status: "converted|active",
  convertedAt: Timestamp
}
```

### 4. `affiliateClicks` - Tracking Clics & Server Recovery
**Document ID**: Auto-généré
```javascript
{
  affiliateCode: "JOHN123",
  timestamp: Timestamp,
  userAgent: "Mozilla/5.0...",
  deviceType: "iPhone",          // "iPhone", "iPad", "iPod"
  iOSVersion: "17.0",
  isMobile: true,
  claimed: false,                 // true quand récupéré par l'app
  claimedAt: null,                // Timestamp de récupération
  claimedByUserId: null,          // userId qui a récupéré
  deviceFingerprint: null         // IDFV ajouté lors du claim
}
```

## 🔄 Flux Complets

### Scénario A: App Déjà Installée

```
1. User clique https://zenloop.me/ref/JOHN123
   ↓
2. AffiliateLanding.js détecte mobile
   ↓
3. copyToClipboard("ZENLOOP_JOHN123")
   ↓
4. trackAffiliateClick() → Firebase.affiliateClicks
   ↓
5. Tente deep link: zenloop://affiliate?code=JOHN123
   ↓
6. iOS: processDeepLink(url) extrait "JOHN123"
   ↓
7. saveAffiliateCode("JOHN123") → UserDefaults
   ↓
8. User s'inscrit → registerAffiliation(userId)
   ↓
9. Vérification deviceFingerprint (IDFV)
   ↓
10. Firebase.affiliates[userId] = {...}
    Firebase.affiliateStats.totalSignups += 1
```

### Scénario B: App Non Installée (CLIPBOARD RECOVERY)

```
1. User clique https://zenloop.me/ref/JOHN123
   ↓
2. AffiliateLanding.js détecte mobile
   ↓
3. copyToClipboard("ZENLOOP_JOHN123") ✨ CODE SAUVEGARDÉ
   ↓
4. trackAffiliateClick() → Firebase avec deviceType + iOSVersion
   ↓
5. Deep link échoue → Redirect App Store
   ↓
6. User télécharge + ouvre app
   ↓
7. Premier lancement: checkClipboardForAffiliateCode()
   ↓
8. UIPasteboard.general.string = "ZENLOOP_JOHN123"
   ↓
9. Extrait "JOHN123" → saveAffiliateCode()
   ↓
10. Efface clipboard (sécurité)
    ↓
11. User s'inscrit → registerAffiliation(userId)
    ↓
12. markAffiliateClickAsClaimed() → claimed: true
    ↓
13. Firebase créé normalement
```

### Scénario B-bis: Clipboard Écrasé (SERVER RECOVERY) 🆕

```
1. User clique https://zenloop.me/ref/JOHN123
   ↓
2. trackAffiliateClick() → Firebase {
     affiliateCode: "JOHN123",
     deviceType: "iPhone",
     iOSVersion: "17.0",
     claimed: false
   }
   ↓
3. copyToClipboard("ZENLOOP_JOHN123")
   ↓
4. ⚠️ User copie autre chose → clipboard écrasé
   ↓
5. User télécharge + ouvre app
   ↓
6. checkClipboardForAffiliateCode()
   ↓
7. ❌ Clipboard ne contient pas "ZENLOOP_"
   ↓
8. 🔍 FALLBACK: tryRecoverFromFirebaseClicks()
   ↓
9. Query affiliateClicks:
     - deviceType == "iPhone"
     - iOSVersion == "17.0"
     - claimed == false
     - timestamp > (now - 48h)
   ↓
10. 🎯 Trouve le clic le plus récent
    ↓
11. Extrait "JOHN123" → saveAffiliateCode()
    ↓
12. Marque le clic: claimed: true
    ↓
13. ✅ Code récupéré même sans clipboard!
```

### Scénario C: Achat Trial (30% commission)

```swift
trackPurchase(
  userId: "user-123",
  purchaseType: .monthly,
  isTrial: true,
  price: 9.99
)
```

```
1. Commission = 9.99 * 0.30 = 2.99
   ↓
2. Firebase.affiliates[userId].setData({
     status: "pending",
     isTrial: true,
     purchaseAmount: 9.99
   })
   ↓
3. PAS de création dans affiliateConversions
   ↓
4. PAS d'incrément totalRevenue/totalConversions
   ↓
5. Dashboard affiche 0€ (trial en attente)
```

### Scénario D: Achat Direct (40% commission)

```swift
trackPurchase(
  userId: "user-123",
  purchaseType: .yearly,
  isTrial: false,
  price: 49.99
)
```

```
1. Commission = 49.99 * 0.40 = 19.99
   ↓
2. Firebase.affiliates[userId].setData({
     status: "active",
     purchaseAmount: 49.99,
     revenue: 19.99
   })
   ↓
3. Firebase.affiliateConversions.add({
     purchaseAmount: 49.99,
     commission: 19.99
   })
   ↓
4. Firebase.affiliateStats.update({
     totalRevenue: +19.99,
     totalConversions: +1
   })
   ↓
5. Dashboard affiche 19.99€ immédiatement
```

### Scénario E: Conversion Trial → Paid (30% commission)

```swift
trackTrialConversion(
  userId: "user-123",
  toPurchaseType: .yearly,
  price: 49.99
)
```

```
1. Commission = 49.99 * 0.30 = 14.99
   ↓
2. Firebase.affiliates[userId].update({
     status: "converted",
     revenue: 14.99
   })
   ↓
3. Firebase.affiliateConversions.add({
     purchaseAmount: 49.99,
     commission: 14.99,
     status: "converted"
   })
   ↓
4. Firebase.affiliateStats.update({
     totalRevenue: +14.99,
     totalConversions: +1
   })
   ↓
5. Dashboard affiche 14.99€
```

## 🛡️ Anti-Fraude

### 1. Device Fingerprint (IDFV)
```swift
let deviceFingerprint = UIDevice.current.identifierForVendor?.uuidString
```
- Unique par device
- Vérifié avant `registerAffiliation()`
- Empêche inscriptions multiples

### 2. Clipboard Check (Une fois)
```swift
let clipboardCheckedKey = "zenloop.affiliate.clipboardChecked"
if !userDefaults.bool(forKey: clipboardCheckedKey) {
  // Check clipboard
  userDefaults.set(true, forKey: clipboardCheckedKey)
}
```

### 3. Affiliation Processed Flag
```swift
let affiliateProcessedKey = "zenloop.affiliate.processed"
```
- Empêche appels multiples à `registerAffiliation()`

### 4. Format Clipboard Spécial
```
ZENLOOP_JOHN123
```
- Préfixe unique pour éviter faux positifs
- Effacé après extraction

## 📈 Commissions

| Type | Taux | Exemple (49.99€) |
|------|------|------------------|
| Trial → Paid | 30% | 14.99€ |
| Achat Direct | 40% | 19.99€ |

## 🔍 Dashboard Web - Queries

```javascript
// Stats de l'affilié connecté
const statsQuery = query(
  collection(db, 'affiliateStats'),
  where('email', '==', currentUser.email)
);

// Conversions récentes
const conversionsQuery = query(
  collection(db, 'affiliateConversions'),
  where('affiliateCode', '==', statsData.affiliateCode),
  orderBy('convertedAt', 'desc'),
  limit(10)
);
```

## ⚠️ Points Critiques

### ✅ CE QUI EST BON

1. **Commission dans totalRevenue** (pas prix total)
2. **Device fingerprint** empêche doublons
3. **Clipboard recovery** fonctionne même app non installée
4. **FieldValue.increment()** évite race conditions
5. **Query par affiliateCode** au lieu d'utiliser comme ID

### ⚠️ CE QUI POURRAIT POSER PROBLÈME

1. ~~**Clipboard peut être écrasé** par user avant ouverture app~~
   - ✅ **RÉSOLU**: Fallback automatique via `tryRecoverFromFirebaseClicks()`
   - Matching par deviceType + iOSVersion + timestamp (48h)
   - Marque les clics comme "claimed" pour éviter collisions

2. **Plusieurs users avec même device** (rare)
   - Le premier qui ouvre l'app récupère le clic
   - Fenêtre de 48h pour réduire les faux positifs

3. **IDFV change si user supprime toutes les apps du vendor**
   - Rare en pratique, négligeable

4. **Firebase Auth UID requis** pour `registerAffiliation()`
   - Appeler après création compte Firebase Auth

## 🧪 Tests

### Test 1: Clipboard Recovery (Succès)
```swift
// Simuler app non installée avec clipboard valide
AffiliateManager.shared.clearAffiliateData()
UIPasteboard.general.string = "ZENLOOP_TEST123"

// Redémarrer app → init() appelle checkClipboardForAffiliateCode()

// Vérifier
print(AffiliateManager.shared.currentAffiliateCode) // "TEST123"
```

### Test 2: Server Recovery (Clipboard écrasé) 🆕
```swift
// 1. Créer un clic dans Firebase (simuler le web)
let db = Firestore.firestore()
await db.collection("affiliateClicks").addDocument(data: [
  "affiliateCode": "SERVER123",
  "deviceType": UIDevice.current.model,
  "iOSVersion": UIDevice.current.systemVersion,
  "claimed": false,
  "timestamp": Timestamp(date: Date())
])

// 2. Simuler clipboard écrasé
AffiliateManager.shared.clearAffiliateData()
UIPasteboard.general.string = "Autre chose"

// 3. Redémarrer app
// checkClipboardForAffiliateCode() échoue
// → tryRecoverFromFirebaseClicks() s'exécute

// 4. Vérifier après 2 secondes (async)
Task {
  try? await Task.sleep(nanoseconds: 2_000_000_000)
  print(AffiliateManager.shared.currentAffiliateCode) // "SERVER123"
}
```

### Test 3: Deep Link
```swift
let url = URL(string: "zenloop://affiliate?code=TEST456")!
AffiliateManager.shared.processDeepLink(url: url)
```

### Test 4: Debug Info
```swift
AffiliateManager.shared.printDebugInfo()
```

## 🚀 Déploiement

1. **Web**: `npm run build && firebase deploy`
2. **iOS**: Build Xcode → App Store Connect
3. **Firebase Rules**: Ajouter permissions lecture/écriture

## 📝 Checklist Intégration

- [ ] Firebase Auth configuré
- [ ] Collections créées
- [ ] Index Firebase (affiliateCode, email)
- [ ] Deep link configuré (Associated Domains)
- [ ] Clipboard permissions iOS
- [ ] Build web avec firebase.json rewrites
- [ ] Test clipboard recovery
- [ ] Test deep link
- [ ] Test achats (trial + direct)
- [ ] Vérifier dashboard affiche données

