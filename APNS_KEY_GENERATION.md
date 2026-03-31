# 🔑 Générer une Clé APNs pour Zenloop

## 📋 Prérequis

- Compte Apple Developer actif
- Accès au portail Apple Developer
- Team ID : `BJN2XLBCFS`
- Bundle ID : `com.app.zenloop`

---

## 🎯 Étape 1 : Créer la Clé APNs

### 1. Aller sur Apple Developer Portal

Ouvrir : https://developer.apple.com/account/resources/authkeys/list

**Ou naviguer manuellement** :
1. https://developer.apple.com
2. Se connecter avec ton Apple ID
3. **Account** → **Certificates, Identifiers & Profiles**
4. **Keys** (dans la sidebar)

### 2. Créer une Nouvelle Clé

1. Cliquer sur le bouton **"+"** (en haut à droite)

2. **Remplir le formulaire** :
   - **Key Name** : `Zenloop Push Notifications`
   - **Cocher** : `Apple Push Notifications service (APNs)`

   ```
   ┌─────────────────────────────────────────┐
   │ Register a New Key                       │
   ├─────────────────────────────────────────┤
   │                                          │
   │ Key Name:                                │
   │ ┌─────────────────────────────────────┐ │
   │ │ Zenloop Push Notifications          │ │
   │ └─────────────────────────────────────┘ │
   │                                          │
   │ Key Services:                            │
   │ ☑ Apple Push Notifications service      │
   │   (APNs)                                 │
   │ ☐ DeviceCheck                            │
   │ ☐ Sign in with Apple                     │
   │ ☐ ...                                    │
   │                                          │
   │         [Continue]                       │
   └─────────────────────────────────────────┘
   ```

3. Cliquer sur **Continue**

### 3. Confirmer et Enregistrer

1. **Écran de confirmation** :
   - Vérifier le nom : `Zenloop Push Notifications`
   - Vérifier : APNs est coché ✅

2. Cliquer sur **Register**

### 4. Télécharger la Clé

⚠️ **IMPORTANT** : Tu ne pourras télécharger cette clé qu'**UNE SEULE FOIS** !

1. **Écran "Download Your Key"** :
   - **Key ID** : Note ce code (ex: `ABC123XYZ`) ✍️
   - Bouton **Download** : Télécharge le fichier `.p8`

2. Cliquer sur **Download**

3. **Le fichier téléchargé** s'appellera quelque chose comme :
   ```
   AuthKey_ABC123XYZ.p8
   ```

4. ⚠️ **SAUVEGARDER CE FICHIER EN LIEU SÛR** :
   - Créer un dossier sécurisé : `/Users/gostmm/Documents/Zenloop_Certificates/`
   - Y copier le fichier `.p8`
   - **Ne jamais commit ce fichier dans Git !**

5. Cliquer sur **Done**

---

## 📝 Informations à Noter

Après avoir créé la clé, tu auras besoin de **3 informations** pour configurer Firebase :

### 1. Key ID
**Où le trouver** : Écran de téléchargement ou liste des clés

**Exemple** : `ABC123XYZ` (10 caractères alphanumériques)

### 2. Team ID
**Où le trouver** : En haut à droite de toutes les pages du Developer Portal

**Pour Zenloop** : `BJN2XLBCFS`

**Ou aller sur** : https://developer.apple.com/account
- Section **Membership** → **Team ID**

### 3. Fichier .p8
**Nom du fichier** : `AuthKey_ABC123XYZ.p8`

**Localisation** : Dossier de téléchargement ou là où tu l'as sauvegardé

---

## 🔥 Étape 2 : Uploader dans Firebase Console

### 1. Aller sur Firebase Console

Ouvrir : https://console.firebase.google.com/project/zenloop-app/settings/cloudmessaging/ios

**Ou naviguer manuellement** :
1. https://console.firebase.google.com
2. Sélectionner le projet **zenloop-app**
3. ⚙️ **Settings** (en haut à gauche) → **Project settings**
4. Onglet **Cloud Messaging**
5. Faire défiler jusqu'à **iOS app configuration**

### 2. Trouver la Section APNs

Chercher la section :
```
Apple Push Notification service (APNs)
```

Il y a 2 options :
- **APNs Authentication Key** ⭐ (Recommandé)
- **APNs Certificates**

### 3. Uploader la Clé

1. Dans **APNs Authentication Key**, cliquer sur **Upload**

2. **Formulaire d'upload** :
   ```
   ┌─────────────────────────────────────────┐
   │ Upload APNs Authentication Key           │
   ├─────────────────────────────────────────┤
   │                                          │
   │ APNs auth key (.p8 file)                │
   │ ┌─────────────────────────────────────┐ │
   │ │ [Choose File] No file chosen        │ │
   │ └─────────────────────────────────────┘ │
   │                                          │
   │ Key ID                                   │
   │ ┌─────────────────────────────────────┐ │
   │ │ ABC123XYZ                           │ │
   │ └─────────────────────────────────────┘ │
   │                                          │
   │ Team ID                                  │
   │ ┌─────────────────────────────────────┐ │
   │ │ BJN2XLBCFS                          │ │
   │ └─────────────────────────────────────┘ │
   │                                          │
   │         [Upload]                         │
   └─────────────────────────────────────────┘
   ```

3. **Remplir** :
   - **APNs auth key** : Sélectionner ton fichier `AuthKey_ABC123XYZ.p8`
   - **Key ID** : Coller le Key ID noté précédemment (ex: `ABC123XYZ`)
   - **Team ID** : `BJN2XLBCFS`

4. Cliquer sur **Upload**

### 4. Vérifier la Configuration

Après l'upload, tu devrais voir :
```
✅ APNs Authentication Key configured
   Key ID: ABC123XYZ
   Team ID: BJN2XLBCFS
   Uploaded: Mar 30, 2026
```

---

## ✅ Vérification

### Vérifier dans Apple Developer Portal

1. Retourner sur https://developer.apple.com/account/resources/authkeys/list
2. Tu devrais voir ta clé :
   ```
   Name: Zenloop Push Notifications
   Key ID: ABC123XYZ
   Services: APNs
   Status: Active
   ```

### Vérifier dans Firebase Console

1. https://console.firebase.google.com/project/zenloop-app/settings/cloudmessaging/ios
2. Section **Apple Push Notification service (APNs)** :
   ```
   ✅ APNs Authentication Key configured
   ```

---

## 🐛 Problèmes Courants

### "You've reached the maximum number of keys"

**Limite** : 2 clés APNs par compte Apple Developer

**Solution** :
1. Supprimer une ancienne clé non utilisée
2. Ou réutiliser une clé existante (si tu en as une pour d'autres apps)

**Note** : Une même clé APNs peut être utilisée pour plusieurs apps du même compte.

### "Invalid Key ID"

**Cause** : Key ID mal copié (espaces, casse incorrecte)

**Solution** :
- Le Key ID fait **exactement 10 caractères**
- Sensible à la casse (majuscules/minuscules)
- Pas d'espaces avant/après

### "Invalid Team ID"

**Cause** : Team ID incorrect

**Solution** :
- Pour Zenloop : `BJN2XLBCFS`
- Vérifier sur https://developer.apple.com/account → Membership

### "File upload failed"

**Cause** : Mauvais format de fichier

**Solution** :
- Le fichier doit avoir l'extension `.p8`
- Ne pas renommer le fichier téléchargé depuis Apple Developer
- Taille du fichier : environ 1-2 KB

---

## 🔒 Sécurité

### ⚠️ NE JAMAIS :
- ❌ Commit le fichier `.p8` dans Git
- ❌ Partager le fichier `.p8` publiquement
- ❌ L'envoyer par email non chiffré

### ✅ TOUJOURS :
- ✅ Sauvegarder dans un dossier sécurisé local
- ✅ Backup sur un drive chiffré (iCloud, Google Drive avec encryption)
- ✅ Ajouter `*.p8` dans `.gitignore`

**Ajouter à `.gitignore`** :
```bash
echo "*.p8" >> .gitignore
echo "AuthKey_*.p8" >> .gitignore
```

---

## 📚 Ressources

- **Apple Developer - Keys** : https://developer.apple.com/account/resources/authkeys
- **Firebase - Cloud Messaging iOS Setup** : https://firebase.google.com/docs/cloud-messaging/ios/client
- **Apple - APNs Documentation** : https://developer.apple.com/documentation/usernotifications

---

## 🎯 Checklist Finale

Après avoir suivi ce guide :

- [ ] Clé APNs créée sur Apple Developer Portal
- [ ] Fichier `.p8` téléchargé et sauvegardé en lieu sûr
- [ ] Key ID noté (10 caractères)
- [ ] Team ID confirmé : `BJN2XLBCFS`
- [ ] Clé uploadée dans Firebase Console
- [ ] Statut "APNs Authentication Key configured" ✅ dans Firebase
- [ ] `.p8` ajouté au `.gitignore`

---

**Prochaine étape** : Retourner au guide [PUSH_NOTIFICATIONS_SETUP.md](PUSH_NOTIFICATIONS_SETUP.md) pour tester les notifications.

**Dernière mise à jour** : 30 mars 2026
