# 🚀 Guide de Déploiement Rapide - Cloud Functions Zenloop

## ✅ Prérequis Complétés

- ✅ Firebase CLI installé
- ✅ Projet Firebase configuré (`zenloop-app`)
- ✅ 4 Cloud Functions implémentées dans `index.js`
- ✅ Script de déploiement `deploy.sh` prêt
- ✅ Dépendances installées

---

## 📋 Étapes de Déploiement

### 1️⃣ Vérifier la Connexion Firebase

```bash
cd /Users/gostmm/SaaS/zenloop
firebase login
firebase use zenloop-app
```

**Vérification** : Vous devriez voir "Now using project zenloop-app"

---

### 2️⃣ Déployer les Cloud Functions

**Option A - Tout déployer** :
```bash
cd functions
./deploy.sh
```

**Option B - Déployer une fonction spécifique** :
```bash
cd functions
./deploy.sh sendPushNotification
```

**Temps estimé** : 2-5 minutes pour le premier déploiement

**Ce qui va être déployé** :
- ✅ `sendPushNotification` → Trigger Firestore sur `socialNotifications/{id}`
- ✅ `cleanupOldNotifications` → Scheduled (tous les jours à minuit)
- ✅ `checkScheduledSessions` → Scheduled (toutes les 5 minutes)
- ✅ `notifySessionStarted` → Trigger Firestore sur `sessions/{id}/events/{eventId}`

---

### 3️⃣ Activer les APIs Requises

Si c'est votre **premier déploiement**, Firebase vous demandera d'activer ces APIs :

1. **Cloud Functions API**
   ```
   https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com?project=zenloop-app
   ```

2. **Cloud Scheduler API** (pour les scheduled functions)
   ```
   https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com?project=zenloop-app
   ```

3. **Cloud Messaging API**
   ```
   https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=zenloop-app
   ```

**Ou cliquez simplement sur les liens fournis par Firebase CLI pendant le déploiement**

---

### 4️⃣ Configurer APNs (CRUCIAL pour iOS)

Pour que les notifications push iOS fonctionnent, vous DEVEZ configurer APNs dans Firebase Console.

#### Option A - APNs Authentication Key (Recommandé) ⭐

1. **Générer une clé sur Apple Developer** :
   - Aller sur https://developer.apple.com/account/resources/authkeys
   - Cliquer sur **+** (Create a Key)
   - Nom : "Zenloop Push Notifications"
   - Cocher **Apple Push Notifications service (APNs)**
   - Cliquer **Continue** → **Register** → **Download**
   - ⚠️ **IMPORTANT** : Sauvegarder le fichier `.p8` et noter le **Key ID**

2. **Uploader dans Firebase Console** :
   - Aller sur https://console.firebase.google.com/project/zenloop-app/settings/cloudmessaging/ios
   - Section **APNs Authentication Key**
   - Cliquer **Upload**
   - Sélectionner votre fichier `.p8`
   - Remplir :
     - **Key ID** : Le Key ID fourni par Apple (ex: `ABC123XYZ`)
     - **Team ID** : Votre Team ID Apple (trouvable sur https://developer.apple.com/account, dans Membership)
   - Cliquer **Upload**

#### Option B - APNs Certificate (.p12)

Si vous préférez utiliser un certificat :
1. Créer un Push Notification Certificate sur Apple Developer Portal
2. Exporter en `.p12` depuis Keychain Access (Mac)
3. Uploader dans Firebase Console → APNs Certificates

**⚠️ Sans cette configuration, les notifications push iOS NE FONCTIONNERONT PAS**

---

### 5️⃣ Vérifier le Déploiement

```bash
firebase functions:list
```

**Résultat attendu** :
```
┌────────────────────────────┬──────────────────┬────────────┐
│ Function                   │ Trigger          │ Region     │
├────────────────────────────┼──────────────────┼────────────┤
│ sendPushNotification       │ firestore        │ us-central1│
│ cleanupOldNotifications    │ schedule         │ us-central1│
│ checkScheduledSessions     │ schedule         │ us-central1│
│ notifySessionStarted       │ firestore        │ us-central1│
└────────────────────────────┴──────────────────┴────────────┘
```

---

### 6️⃣ Voir les Logs en Temps Réel

```bash
firebase functions:log --only sendPushNotification

# Ou tous les logs
firebase functions:log
```

**Interface Web** :
https://console.firebase.google.com/project/zenloop-app/functions

---

## 🧪 Tester les Notifications Push

### Test 1 : Créer une Notification Manuellement (Firestore)

1. Aller sur Firebase Console → Firestore
2. Collection `socialNotifications`
3. Ajouter un document :

```json
{
  "userId": "VOTRE_USER_ID_TEST",
  "type": "member_joined",
  "sessionId": "session_test_123",
  "message": "Alice a rejoint la session",
  "pushTitle": "Nouveau membre",
  "pushBody": "Alice a rejoint la session Focus",
  "needsPush": true,
  "timestamp": "2024-03-30T10:00:00Z"
}
```

4. Vérifier les logs :
```bash
firebase functions:log --only sendPushNotification
```

**Résultat attendu** :
```
📲 New notification created: <notificationId>
📤 Sending push to user: <userId>
✅ Push notification sent successfully: <messageId>
```

---

### Test 2 : Déclencher via l'App iOS

1. **Joindre une session** → Devrait déclencher une notification "member_joined"
2. **Démarrer une session** → Devrait déclencher "session_started"
3. **Créer une session programmée** → Devrait programmer les rappels 15min/5min

**Vérifier dans les logs** :
```bash
firebase functions:log --follow
```

---

## 🔍 Monitoring

### Dashboard Firebase

https://console.firebase.google.com/project/zenloop-app/functions

**Métriques disponibles** :
- Nombre d'invocations
- Temps d'exécution moyen
- Taux d'erreur
- Utilisation mémoire

### Configurer des Alertes (Recommandé)

1. Aller sur Firebase Console → Functions → Alerting
2. Configurer des alertes pour :
   - ✅ Taux d'erreur > 5%
   - ✅ Temps d'exécution > 10s
   - ✅ Invocations anormales

---

## ⚠️ Problèmes Courants

### Erreur : "Missing permissions"

**Solution** :
```bash
gcloud auth login
gcloud config set project zenloop-app
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
```

### Erreur : "APNs certificate not configured"

**Solution** : Configurer APNs dans Firebase Console (voir Étape 4)

### Notification reçue sur Android mais pas iOS

**Causes possibles** :
1. ❌ APNs non configuré → Voir Étape 4
2. ❌ Push token non enregistré → Vérifier `users/{userId}.pushToken` dans Firestore
3. ❌ Notifications désactivées dans Settings iOS

**Debug** :
```bash
firebase functions:log --only sendPushNotification
```

Rechercher : `⚠️ No push token for user`

---

## 💰 Coûts Estimés

### Plan Spark (Gratuit) - Limites
- ❌ **Scheduled functions** ne fonctionneront PAS (Cloud Scheduler nécessite Blaze)
- ✅ Trigger functions fonctionnent (Firestore onCreate)
- ✅ 2M invocations/mois gratuites
- ✅ 400k Go-secondes/mois gratuits

### Plan Blaze (Pay-as-you-go) - Recommandé
Pour **10 000 utilisateurs actifs** :
- Scheduled functions : ~$5/mois
- Trigger functions : ~$2/mois
- FCM : Gratuit (< 1M messages)
- **Total estimé** : ~$7/mois

**⚠️ IMPORTANT** : Si vous voulez `cleanupOldNotifications` et `checkScheduledSessions`, vous DEVEZ upgrader au plan Blaze.

---

## 🚀 Prêt à Déployer !

**Commande finale** :
```bash
cd /Users/gostmm/SaaS/zenloop/functions
./deploy.sh
```

**Ensuite** :
1. Configurer APNs dans Firebase Console
2. Tester avec une notification manuelle
3. Configurer les alertes
4. Monitorer les logs

---

## 📚 Documentation Complète

Pour plus de détails, voir :
- [README.md](./README.md) - Documentation complète (1500+ lignes)
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)

---

**Dernière mise à jour** : 30 mars 2024
**Auteur** : Zenloop Team
