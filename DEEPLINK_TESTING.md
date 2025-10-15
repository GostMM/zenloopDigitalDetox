# 🔗 Guide de Test Deep Linking

## Méthode 1 : Via Simulator (Recommandé)

### Utiliser `xcrun simctl`

```bash
# Lancer l'app d'abord sur le simulator
# Puis dans le terminal :

xcrun simctl openurl booted "zenloop://affiliate?code=JOHN123"
```

**Avantages :**
- Fonctionne à 100%
- Rapide à tester
- Logs visibles dans Xcode console

---

## Méthode 2 : Via Notes App (Simulator/Device)

### Étapes :

1. Ouvrir **Notes** sur le simulator/device
2. Créer une nouvelle note
3. Taper : `zenloop://affiliate?code=TEST123`
4. Le lien devient cliquable automatiquement
5. **Taper dessus** pour ouvrir l'app

**Avantages :**
- Proche de l'expérience réelle utilisateur
- Fonctionne sur device physique aussi

---

## Méthode 3 : Via Safari (Device Physique)

### Option A : Page HTML Test

Créer une page HTML simple :

```html
<!DOCTYPE html>
<html>
<head>
    <title>Zenloop Affiliate Test</title>
</head>
<body>
    <h1>Test Affiliation Zenloop</h1>
    <p>Cliquez sur un lien pour tester :</p>

    <ul>
        <li><a href="zenloop://affiliate?code=JOHN123">Code JOHN123</a></li>
        <li><a href="zenloop://affiliate?code=MARIA456">Code MARIA456</a></li>
        <li><a href="zenloop://affiliate?code=TEST123">Code TEST123</a></li>
    </ul>

    <script>
        // Auto-redirect après 2 secondes si rien ne se passe
        setTimeout(() => {
            window.location.href = "zenloop://affiliate?code=AUTO123";
        }, 2000);
    </script>
</body>
</html>
```

Héberger sur GitHub Pages ou serveur local.

### Option B : URL Redirect

Si vous avez un domaine (ex: `zenloop.app`), créer une page de redirect :

```
https://zenloop.app/ref/JOHN123
    ↓
zenloop://affiliate?code=JOHN123
```

**Exemple avec JavaScript :**
```javascript
const code = window.location.pathname.split('/').pop();
window.location.href = `zenloop://affiliate?code=${code}`;
```

---

## Méthode 4 : Via QR Code

### Générer un QR Code

Utiliser un générateur de QR code avec l'URL :
```
zenloop://affiliate?code=JOHN123
```

**Sites recommandés :**
- https://www.qr-code-generator.com/
- https://qrcode.tec-it.com/

**Usage :**
1. Scanner le QR avec l'appareil photo
2. Notification apparaît "Ouvrir dans Zenloop"
3. Tap → App s'ouvre avec le code

**Parfait pour :**
- Marketing physique
- Flyers, posters
- Cartes de visite

---

## Méthode 5 : Via Terminal (Device Physique)

### Utiliser `idevicediagnostics` (libimobiledevice)

```bash
# Installer libimobiledevice si pas déjà fait
brew install libimobiledevice

# Ouvrir l'URL sur le device connecté
idevicediagnostics openurl "zenloop://affiliate?code=JOHN123"
```

---

## Vérification du Deep Link

### Dans Xcode Console

Quand le deep link fonctionne, vous devriez voir :

```
🔗 [AFFILIATE] Processing deep link: zenloop://affiliate?code=JOHN123
✅ [AFFILIATE] Code saved: JOHN123
💾 [AFFILIATE] Code saved to UserDefaults: JOHN123
```

### Vérifier la Sauvegarde

```swift
// Dans l'app ou via debug
let code = UserDefaults.standard.string(forKey: "zenloop.affiliate.code")
print("Code sauvegardé: \(code ?? "aucun")")

// Ou utiliser la méthode debug
AffiliateManager.shared.printDebugInfo()
```

**Output attendu :**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 AFFILIATE DEBUG INFO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Code: JOHN123
Processed: true
Data: JOHN123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Troubleshooting

### Erreur : "Safari cannot open the page"

**Cause :** URL Scheme pas configuré dans Info.plist

**Solution :** Vérifier que `Info.plist` contient :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zenloop</string>
        </array>
    </dict>
</array>
```

### Erreur : "No app available to open URL"

**Cause :** App pas installée sur le device/simulator

**Solution :**
1. Build & Run l'app dans Xcode
2. Réessayer le deep link

### Le code ne se sauvegarde pas

**Cause :** Parsing échoue

**Debug :**
```swift
// Ajouter dans processDeepLink()
print("URL components: \(components)")
print("Query items: \(queryItems)")
print("Code found: \(code)")
```

---

## Scénarios de Test Complets

### Test 1 : Premier Lancement avec Code

```bash
# 1. Supprimer l'app du simulator
# 2. Relancer l'app depuis Xcode
# 3. Immédiatement après le splash screen :
xcrun simctl openurl booted "zenloop://affiliate?code=TEST123"

# 4. Vérifier dans Xcode Console
# Expected: Code saved, Firebase registration triggered
```

### Test 2 : Code Déjà Sauvegardé

```bash
# 1. App déjà installée avec code TEST123
# 2. Envoyer un nouveau code :
xcrun simctl openurl booted "zenloop://affiliate?code=NEWCODE456"

# 3. Vérifier quel code est actif
# Expected: Code ne change pas (premier code est gardé)
```

### Test 3 : Achat après Affiliation

```bash
# 1. Deep link avec code
xcrun simctl openurl booted "zenloop://affiliate?code=COMMISSION123"

# 2. Dans l'app : Aller sur Paywall
# 3. Acheter Yearly (trial ou paid)
# 4. Vérifier Firebase :
#    - Collection "affiliates" a un nouveau document
#    - Collection "affiliateStats" incrémentée
```

### Test 4 : Conversion Trial → Paid

```bash
# 1. User a démarré un trial
# 2. 3 jours plus tard, convertit en paid
# 3. Vérifier Firebase :
#    - Collection "affiliateConversions" a un document
#    - Status passe de "pending" à "converted"
#    - Revenue mis à jour
```

---

## Codes de Test Recommandés

```
TEST123      - Testing général
DEBUG001     - Debug mode
PROMO50      - Promotion
PARTNER2024  - Partenaire
JOHN123      - Affilié fictif
MARIA456     - Affilié fictif
```

---

## Integration Web → App

### Redirect Server-Side (Recommandé)

**PHP Example :**
```php
<?php
$code = $_GET['ref'] ?? 'DEFAULT';
$deeplink = "zenloop://affiliate?code=" . urlencode($code);

// Détection mobile
$mobile = preg_match('/iPhone|iPad|Android/', $_SERVER['HTTP_USER_AGENT']);

if ($mobile) {
    header("Location: $deeplink");
} else {
    // Desktop : Afficher QR code ou lien App Store
    echo "Scannez le QR code ou téléchargez l'app";
}
?>
```

### Redirect Client-Side (JavaScript)

```javascript
// URL format : https://zenloop.app/ref/JOHN123
const urlParams = new URLSearchParams(window.location.search);
const code = urlParams.get('ref') || 'DEFAULT';

// Essayer d'ouvrir l'app
window.location.href = `zenloop://affiliate?code=${code}`;

// Fallback vers App Store après 2s
setTimeout(() => {
    window.location.href = 'https://apps.apple.com/app/zenloop/id123456789';
}, 2000);
```

---

## Commandes Rapides (Cheat Sheet)

```bash
# Simulator
xcrun simctl openurl booted "zenloop://affiliate?code=CODE123"

# Device physique (libimobiledevice)
idevicediagnostics openurl "zenloop://affiliate?code=CODE123"

# Nettoyer les données
# Dans l'app Swift :
AffiliateManager.shared.clearAffiliateData()

# Debug info
AffiliateManager.shared.printDebugInfo()

# Simuler un lien (sans ouvrir URL)
AffiliateManager.shared.simulateAffiliateLink(code: "TEST123")
```

---

## Monitoring Firebase

### Requêtes Firestore Console

**Vérifier les affiliations :**
```
Collection: affiliates
Filter: affiliateCode == "JOHN123"
```

**Vérifier les stats :**
```
Collection: affiliateStats
Document: JOHN123
```

**Vérifier les conversions :**
```
Collection: affiliateConversions
Filter: affiliateCode == "JOHN123"
Order by: conversionDate desc
```

---

## Next Steps

Une fois le deep linking fonctionnel :

1. ✅ Tester avec différents codes
2. ✅ Vérifier la persistance (fermer/rouvrir app)
3. ✅ Tester un achat complet
4. ✅ Vérifier Firebase data
5. 🔜 Créer landing page web avec redirect
6. 🔜 Implémenter dashboard affiliés

---

**Dernière mise à jour :** Janvier 2025
