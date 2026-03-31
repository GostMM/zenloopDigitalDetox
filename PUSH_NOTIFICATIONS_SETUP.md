# 🔔 Configuration des Notifications Push - Zenloop

## ❌ Problème Identifié

Les logs Cloud Functions montrent :
```
⚠️ No push token for user: QnKXyxroJ8gg1AtYoMhaewLl5oH3
```

**Cause** : L'app iOS n'enregistre pas le token FCM (Firebase Cloud Messaging) dans Firestore.

**Solution** : Ajouter `FirebaseMessaging` SDK et implémenter l'enregistrement du token.

---

## ✅ Ce qui a été implémenté

### 1. Nouveau fichier : `PushNotificationManager.swift`

Gestionnaire complet des notifications push :
- ✅ Demande les permissions de notification
- ✅ Récupère le token FCM
- ✅ Sauvegarde le token dans Firestore (`users/{userId}.pushToken`)
- ✅ Gère le rafraîchissement du token
- ✅ Supprime le token lors de la déconnexion

**Localisation** : [zenloop/Managers/PushNotificationManager.swift](zenloop/Managers/PushNotificationManager.swift)

### 2. Modifications : `ZenloopAppDelegate.swift`

Ajout des callbacks pour les remote notifications :
- ✅ `didRegisterForRemoteNotificationsWithDeviceToken` : Transmet le token à FCM
- ✅ `didFailToRegisterForRemoteNotificationsWithError` : Log les erreurs
- ✅ `didReceiveRemoteNotification` : Traite les notifications en background
- ✅ Configuration du delegate `UNUserNotificationCenter`

**Localisation** : [zenloop/Managers/ZenloopAppDelegate.swift](zenloop/Managers/ZenloopAppDelegate.swift:35-60)

### 3. Modifications : `zenloopApp.swift`

Appel de `PushNotificationManager.shared.setup()` après configuration Firebase.

**Localisation** : [zenloop/zenloopApp.swift](zenloop/zenloopApp.swift:176-179)

### 4. Modifications : `AuthenticationManager.swift`

- ✅ Appel de `setup()` après authentification réussie
- ✅ Suppression du token lors de la déconnexion

**Localisation** :
- [AuthenticationManager.swift:161](zenloop/Managers/AuthenticationManager.swift:161) (setup)
- [AuthenticationManager.swift:126-128](zenloop/Managers/AuthenticationManager.swift:126-128) (cleanup)

---

## 📦 ÉTAPE REQUISE : Ajouter FirebaseMessaging au Projet

### Option A - Swift Package Manager (Recommandé)

1. **Ouvrir Xcode**
2. **File → Add Package Dependencies...**
3. **URL du package** :
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. **Version** : Utiliser la même version que `FirebaseAuth` et `FirebaseFirestore` (probablement 11.x.x)
5. **Sélectionner le produit** : Cocher `FirebaseMessaging`
6. **Cliquer sur Add Package**

### Option B - Vérifier les packages existants

Si Firebase est déjà installé via SPM :

1. **Xcode → Project Navigator**
2. **Sélectionner le projet "zenloop"**
3. **Target "zenloop" → General → Frameworks, Libraries, and Embedded Content**
4. **Cliquer sur "+" → Rechercher "FirebaseMessaging"**
5. **Ajouter**

---

## 🔧 Configuration APNs (OBLIGATOIRE)

### 1. Générer une Clé APNs sur Apple Developer

1. Aller sur https://developer.apple.com/account/resources/authkeys
2. Cliquer sur **+** (Create a Key)
3. **Nom** : "Zenloop Push Notifications"
4. Cocher **Apple Push Notifications service (APNs)**
5. Cliquer **Continue** → **Register** → **Download**
6. ⚠️ **SAUVEGARDER** le fichier `.p8` et noter le **Key ID**

### 2. Uploader dans Firebase Console

1. Aller sur https://console.firebase.google.com/project/zenloop-app/settings/cloudmessaging/ios
2. Section **APNs Authentication Key**
3. Cliquer **Upload**
4. Sélectionner votre fichier `.p8`
5. Remplir :
   - **Key ID** : Le Key ID fourni par Apple (ex: `ABC123XYZ`)
   - **Team ID** : `BJN2XLBCFS` (votre Team ID)
6. Cliquer **Upload**

---

## 🧪 Test de l'Installation

### 1. Build et Run

```bash
cd /Users/gostmm/SaaS/zenloop
xcodebuild -project zenloop.xcodeproj -scheme zenloop -configuration Debug
```

**Vérifier les logs Xcode** :
```
🔔 Setting up push notifications...
✅ Notification permissions granted
📱 Registered for remote notifications
✅ FCM Token retrieved: <long_token>
💾 Saving push token to Firestore for user: <userId>
✅ Push token saved successfully
```

### 2. Vérifier dans Firestore

1. Aller sur Firebase Console → Firestore
2. Collection `users` → Document de ton user ID
3. **Vérifier que le champ existe** :
   ```json
   {
     "pushToken": "dXyzABC123...",
     "pushTokenUpdatedAt": "2026-03-30T10:00:00Z",
     "platform": "ios"
   }
   ```

### 3. Tester une Notification Manuelle

Créer un document dans `socialNotifications` :

```json
{
  "userId": "TON_USER_ID",
  "type": "member_joined",
  "sessionId": "session_test_123",
  "message": "Test notification",
  "pushTitle": "Zenloop Test",
  "pushBody": "Ceci est un test de notification push",
  "needsPush": true,
  "timestamp": "2026-03-30T10:00:00Z"
}
```

**Résultat attendu** :
- ✅ Cloud Function déclenchée
- ✅ Notification push reçue sur ton iPhone
- ✅ Log dans Firebase Functions :
  ```
  📲 New notification created: <notificationId>
  📤 Sending push to user: <userId>
  ✅ Push notification sent successfully: <messageId>
  ```

### 4. Tester via l'App (Rejoindre une Session)

1. Ouvrir l'app
2. Rejoindre une session sociale
3. **Attendre 2-3 secondes**
4. **Vérifier que l'autre membre reçoit une notification** :
   ```
   "Alice a rejoint la session Focus"
   ```

---

## 🐛 Debugging

### Erreur : "No push token for user"

**Cause** : Le token n'est pas sauvegardé dans Firestore

**Solution** :
1. Vérifier que `FirebaseMessaging` est bien ajouté au projet
2. Vérifier les logs Xcode pour voir si `setup()` est appelé
3. Vérifier que l'utilisateur est authentifié

### Erreur : "APNs device token not set"

**Cause** : APNs non configuré dans Firebase Console

**Solution** : Uploader la clé APNs (voir section Configuration APNs)

### Erreur : "Failed to get FCM token"

**Cause** : Permissions de notification refusées

**Solution** :
1. Supprimer l'app de l'iPhone
2. Réinstaller
3. Accepter les permissions de notification

### Notification non reçue (mais Cloud Function s'exécute)

**Vérifier** :
1. ✅ APNs configuré dans Firebase Console
2. ✅ Notifications activées dans Réglages iPhone
3. ✅ App fermée (les notifications push ne s'affichent pas toujours en foreground)
4. ✅ Token récent (pas expiré)

**Log à chercher** :
```bash
firebase functions:log --only sendPushNotification
```

Chercher :
```
✅ Push notification sent successfully: projects/.../messages/...
```

Si ce log apparaît, FCM a bien envoyé la notification. Le problème est alors côté Apple (APNs).

---

## 📊 Monitoring

### Dashboard Firebase

https://console.firebase.google.com/project/zenloop-app/functions

**Métriques à surveiller** :
- Taux d'invocations de `sendPushNotification`
- Taux d'erreur (doit être < 5%)
- Warnings "No push token" (doivent disparaître après cette fix)

### Logs en Temps Réel

```bash
firebase functions:log --only sendPushNotification --follow
```

---

## ✅ Checklist Finale

Avant de tester end-to-end, vérifier :

- [ ] `FirebaseMessaging` ajouté au projet Xcode
- [ ] Build réussi sans erreurs
- [ ] APNs clé uploadée dans Firebase Console
- [ ] App installée sur iPhone physique (ou simulateur avec iOS 16+)
- [ ] Permissions de notification acceptées
- [ ] Token FCM sauvegardé dans Firestore (`users/{userId}.pushToken`)
- [ ] Cloud Function `sendPushNotification` déployée
- [ ] Test manuel dans Firestore → notification reçue ✅

---

## 🎯 Prochaines Étapes

Une fois les notifications fonctionnelles :

1. **Tester tous les types de notifications** :
   - ✅ member_joined
   - ✅ member_left
   - ✅ session_started
   - ✅ session_paused
   - ✅ session_resumed
   - ✅ session_ended
   - ✅ scheduled_session_reminder (15min avant)
   - ✅ scheduled_session_reminder (5min avant)
   - ✅ scheduled_session_started
   - ✅ scheduled_session_ended

2. **Configurer le deep linking** :
   - Cliquer sur une notification → ouvrir la session directement

3. **Personnaliser les actions rapides** :
   - Notifications avec boutons (Rejoindre, Ignorer, etc.)

4. **Badge count** :
   - Afficher le nombre de notifications non lues sur l'icône de l'app

---

**Dernière mise à jour** : 30 mars 2026
**Status** : ✅ Implémentation complète (reste à ajouter le package et tester)
