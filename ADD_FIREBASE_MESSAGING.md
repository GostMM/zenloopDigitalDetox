# 📦 Ajouter FirebaseMessaging à Xcode

## ✅ APNs Configuré

Tu as déjà importé le fichier `.p8` dans Firebase Console. Parfait ! ✅

Il ne reste plus qu'à ajouter le package `FirebaseMessaging` dans Xcode.

---

## 🎯 Méthode : Swift Package Manager

### Étape 1 : Vérifier les Packages Existants

1. **Ouvrir Xcode**
2. **Ouvrir le projet** : `/Users/gostmm/SaaS/zenloop/zenloop.xcodeproj`
3. **Dans le Project Navigator** (sidebar gauche) :
   - Cliquer sur le projet **zenloop** (tout en haut)
4. **Sélectionner le projet** (pas le target) dans la colonne du milieu
5. **Onglet "Package Dependencies"**

Tu devrais voir :
```
Firebase
https://github.com/firebase/firebase-ios-sdk
Version: 11.x.x (ou similaire)
```

### Étape 2 : Ajouter FirebaseMessaging au Target

Puisque Firebase SDK est déjà installé, il suffit d'ajouter le produit au target :

1. **Dans le Project Navigator**, cliquer sur **zenloop** (projet)
2. **Sélectionner le target "zenloop"** (dans la colonne du milieu)
3. **Onglet "General"**
4. **Section "Frameworks, Libraries, and Embedded Content"**

Tu devrais voir :
```
FirebaseAuth
FirebaseFirestore
... (autres)
```

5. **Cliquer sur le "+"** en bas de cette liste
6. **Rechercher** : `FirebaseMessaging`
7. **Sélectionner** : `FirebaseMessaging`
8. **Cliquer sur "Add"**

---

## 🔄 Alternative : Si Firebase n'est pas encore en Package

Si tu ne vois pas Firebase dans les Package Dependencies :

### Option A - Ajouter via Package Dependencies

1. **Xcode** → **File** → **Add Package Dependencies...**
2. **URL** :
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. **Dependency Rule** : "Up to Next Major Version" → `11.0.0`
4. **Add Package**
5. **Sélectionner les produits** :
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseMessaging ⭐ (nouveau)
6. **Add Package**

---

## 🏗️ Build et Vérification

### 1. Build le Projet

```bash
cd /Users/gostmm/SaaS/zenloop
xcodebuild -project zenloop.xcodeproj -scheme zenloop -configuration Debug clean build
```

**Ou dans Xcode** :
- **Product** → **Clean Build Folder** (⇧⌘K)
- **Product** → **Build** (⌘B)

### 2. Vérifier qu'il n'y a pas d'erreurs

Le build doit réussir sans erreurs. Si tu vois des erreurs de type :
```
Cannot find 'Messaging' in scope
```

C'est que le package n'est pas correctement ajouté.

### 3. Vérifier les Imports

Les fichiers suivants importent `FirebaseMessaging` :
- [PushNotificationManager.swift](zenloop/Managers/PushNotificationManager.swift:10)
- [ZenloopAppDelegate.swift](zenloop/Managers/ZenloopAppDelegate.swift:11)

Ouvrir ces fichiers dans Xcode :
- Les imports ne doivent **pas être en rouge** ✅
- Pas d'erreur "No such module 'FirebaseMessaging'"

---

## 🧪 Tester l'Installation

### 1. Lancer l'App sur un iPhone Physique

⚠️ **Les notifications push ne fonctionnent PAS sur simulateur** (APNs requis)

**Connecter un iPhone** et lancer l'app :
1. Brancher l'iPhone via USB
2. **Xcode** → Sélectionner l'iPhone dans la liste des devices
3. **Product** → **Run** (⌘R)

### 2. Accepter les Permissions

Au démarrage, l'app va demander :
```
┌─────────────────────────────────────────┐
│  "zenloop" Would Like to Send You       │
│  Notifications                           │
├─────────────────────────────────────────┤
│  Notifications may include alerts,      │
│  sounds, and icon badges.               │
│                                          │
│         [Don't Allow]    [Allow]        │
└─────────────────────────────────────────┘
```

**Cliquer sur "Allow"** ✅

### 3. Vérifier les Logs Xcode

Dans la console Xcode, tu devrais voir :
```
🔔 Setting up push notifications...
✅ Notification permissions granted
📱 [APP_DELEGATE] Registered for remote notifications
🔄 FCM token refreshed: dXyzABC123...
💾 Saving push token to Firestore for user: QnKXyxroJ8gg1AtYoMhaewLl5oH3
✅ Push token saved successfully
```

### 4. Vérifier dans Firestore

1. Aller sur Firebase Console → Firestore
2. Collection `users` → Ton document user
3. **Vérifier que le champ existe** :
   ```json
   {
     "username": "...",
     "pushToken": "dXyzABC123...", ⭐
     "pushTokenUpdatedAt": "2026-03-30T10:30:00Z",
     "platform": "ios"
   }
   ```

Si le champ `pushToken` existe → **Installation réussie !** 🎉

---

## 🐛 Résolution de Problèmes

### Erreur : "Cannot find 'Messaging' in scope"

**Cause** : Package non ajouté au target

**Solution** :
1. Project Navigator → zenloop (projet)
2. Target "zenloop" → General
3. Frameworks, Libraries, and Embedded Content → +
4. Ajouter `FirebaseMessaging`

### Erreur : "Module 'FirebaseMessaging' not found"

**Cause** : Firebase SDK pas installé via SPM

**Solution** :
1. File → Add Package Dependencies
2. URL : `https://github.com/firebase/firebase-ios-sdk`
3. Ajouter `FirebaseMessaging`

### Erreur : "Failed to get FCM token"

**Cause** : Permissions refusées ou APNs non configuré

**Solution** :
1. Vérifier APNs dans Firebase Console ✅ (déjà fait)
2. Supprimer l'app de l'iPhone
3. Réinstaller
4. Accepter les permissions

### Log : "No push token for user" (toujours)

**Cause** : Token pas sauvegardé

**Debug** :
1. Vérifier que l'utilisateur est **authentifié** (pas en mode onboarding)
2. Vérifier les logs Xcode pour voir si `setup()` est appelé
3. Vérifier Firestore pour voir si le token apparaît

---

## 📊 Vérification Finale

### Cloud Functions Logs

```bash
firebase functions:log --only sendPushNotification --follow
```

**Avant** (problème) :
```
⚠️ No push token for user: QnKXyxroJ8gg1AtYoMhaewLl5oH3
```

**Après** (résolu) :
```
📲 New notification created: xyz123
📤 Sending push to user: QnKXyxroJ8gg1AtYoMhaewLl5oH3
✅ Push notification sent successfully: projects/.../messages/abc789
```

---

## 🧪 Test End-to-End

### Test 1 : Notification Manuelle

1. Aller sur Firebase Console → Firestore
2. Collection `socialNotifications` → Add document
3. **Données** :
   ```json
   {
     "userId": "TON_USER_ID",
     "type": "member_joined",
     "sessionId": "session_test",
     "message": "Test notification",
     "pushTitle": "Zenloop Test",
     "pushBody": "Ceci est un test",
     "needsPush": true
   }
   ```
4. **Fermer l'app** (ou passer en background)
5. **Attendre 2-3 secondes**
6. **Notification reçue !** 🎉

### Test 2 : Rejoindre une Session

1. Ouvrir l'app sur 2 iPhones (ou 1 iPhone + 1 simulateur pour l'autre user)
2. Créer une session sociale
3. Rejoindre la session avec le 2ème user
4. **Le 1er user reçoit une notification** : "Alice a rejoint la session" 🎉

---

## ✅ Checklist

- [ ] Xcode ouvert
- [ ] Package FirebaseMessaging ajouté au target
- [ ] Build réussi sans erreurs
- [ ] App lancée sur iPhone physique
- [ ] Permissions de notification acceptées
- [ ] Logs Xcode montrent "✅ Push token saved successfully"
- [ ] Firestore montre le champ `pushToken`
- [ ] Test manuel → notification reçue ✅

---

**Une fois tout validé, les notifications fonctionneront pour tous les événements de session !** 🚀

**Fichiers à consulter** :
- [PUSH_NOTIFICATIONS_SETUP.md](PUSH_NOTIFICATIONS_SETUP.md) - Guide complet
- [APNS_KEY_GENERATION.md](APNS_KEY_GENERATION.md) - Générer clé APNs (déjà fait ✅)

**Dernière mise à jour** : 30 mars 2026
