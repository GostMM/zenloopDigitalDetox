# Firebase Cloud Functions - Zenloop

Ce dossier contient les Cloud Functions Firebase pour gérer les notifications push de l'application Zenloop.

## 📋 Table des matières

- [Fonctions disponibles](#fonctions-disponibles)
- [Installation](#installation)
- [Configuration](#configuration)
- [Déploiement](#déploiement)
- [Tests locaux](#tests-locaux)
- [Monitoring](#monitoring)

## 🎯 Fonctions disponibles

### 1. **sendPushNotification** 📲
- **Trigger**: `onCreate` sur `socialNotifications/{notificationId}`
- **Description**: Envoie une notification push via FCM quand une notification est créée dans Firestore
- **Use case**: Événements de session (membre rejoint, session démarrée, pause, etc.)

### 2. **cleanupOldNotifications** 🧹
- **Trigger**: Scheduled (tous les jours à minuit)
- **Description**: Supprime les notifications de plus de 30 jours
- **Use case**: Maintenance automatique de la base de données

### 3. **checkScheduledSessions** ⏰
- **Trigger**: Scheduled (toutes les 5 minutes)
- **Description**: Envoie des rappels 15min et 5min avant les sessions programmées
- **Use case**: Backup des notifications locales iOS

### 4. **notifySessionStarted** 🔔
- **Trigger**: `onCreate` sur `sessions/{sessionId}/events/{eventId}`
- **Description**: Notifie les membres quand une session programmée démarre
- **Use case**: Confirmation de démarrage des sessions

## 🚀 Installation

### Prérequis

- Node.js 22 ou supérieur
- Firebase CLI installé globalement
- Un projet Firebase configuré

### 1. Installer Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Se connecter à Firebase

```bash
firebase login
```

### 3. Lier le projet Firebase

Si ce n'est pas déjà fait :

```bash
# Depuis la racine du projet zenloop/
firebase init

# Sélectionner :
# - Functions
# - Use existing project
# - JavaScript
# - ESLint: No (ou Yes si vous voulez)
# - Install dependencies: Yes
```

Si déjà fait, vérifier la configuration :

```bash
firebase use --add
# Sélectionner votre projet Firebase
```

### 4. Installer les dépendances

```bash
cd functions
npm install
```

## ⚙️ Configuration

### 1. Configurer le Service Account (Important !)

Les Cloud Functions nécessitent les permissions Admin pour envoyer des notifications FCM.

**Vérifier que Firebase Admin SDK est initialisé** :
- Aucune action requise, l'initialisation se fait automatiquement dans `index.js`

### 2. Configurer APNs (Apple Push Notification service)

Pour que les notifications iOS fonctionnent :

1. Aller sur [Firebase Console](https://console.firebase.google.com)
2. Sélectionner votre projet
3. Project Settings → Cloud Messaging
4. Onglet "Apple app configuration"
5. Uploader votre certificat APNs :
   - **Recommandé** : APNs Authentication Key (.p8)
   - Ou : APNs Certificate (.p12)

#### Générer un APNs Authentication Key :

1. Aller sur [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys)
2. Create a Key → Enable "Apple Push Notifications service (APNs)"
3. Download le fichier .p8
4. Uploader dans Firebase Console avec :
   - **Key ID** : Fourni par Apple
   - **Team ID** : Trouvable dans Apple Developer Membership

### 3. Variables d'environnement (si nécessaire)

Si vous avez besoin de variables d'environnement personnalisées :

```bash
firebase functions:config:set someservice.key="THE API KEY"
```

Pour voir la configuration actuelle :

```bash
firebase functions:config:get
```

## 📤 Déploiement

### Déployer toutes les fonctions

```bash
# Depuis le dossier functions/
npm run deploy

# Ou depuis la racine du projet
firebase deploy --only functions
```

### Déployer une fonction spécifique

```bash
firebase deploy --only functions:sendPushNotification
firebase deploy --only functions:cleanupOldNotifications
firebase deploy --only functions:checkScheduledSessions
firebase deploy --only functions:notifySessionStarted
```

### Première fois : Activer les services requis

Si c'est votre premier déploiement, Firebase vous demandera d'activer :
- **Cloud Functions API**
- **Cloud Firestore API**
- **Cloud Messaging API**
- **Cloud Scheduler API** (pour les scheduled functions)

Cliquez sur les liens fournis ou activez manuellement dans :
https://console.cloud.google.com/apis/library

### Vérifier le déploiement

```bash
firebase functions:list
```

Vous devriez voir :
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

## 🧪 Tests locaux

### Utiliser l'émulateur Firebase

```bash
# Démarrer tous les émulateurs
firebase emulators:start

# Ou seulement Functions + Firestore
firebase emulators:start --only functions,firestore
```

L'interface web de l'émulateur sera disponible sur :
http://localhost:4000

### Tester une fonction manuellement

#### 1. Tester sendPushNotification

Créer un document de test dans Firestore (via l'émulateur UI) :

Collection: `socialNotifications`
```json
{
  "userId": "test_user_123",
  "type": "member_joined",
  "sessionId": "session_abc",
  "message": "Alice a rejoint la session",
  "pushTitle": "Nouveau membre",
  "pushBody": "Alice a rejoint la session Focus",
  "needsPush": true,
  "timestamp": "2024-03-30T10:00:00Z"
}
```

#### 2. Tester avec curl (production)

```bash
# Trigger via HTTP (si vous créez un endpoint HTTP)
curl -X POST https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/sendPushNotification \
  -H "Content-Type: application/json" \
  -d '{"userId": "test_user"}'
```

### Shell interactif

```bash
npm run shell

# Puis dans le shell :
sendPushNotification({ userId: "test_user" })
```

## 📊 Monitoring

### Voir les logs en temps réel

```bash
firebase functions:log --only sendPushNotification

# Ou tous les logs
npm run logs
```

### Voir les logs dans la console

1. Aller sur [Firebase Console](https://console.firebase.google.com)
2. Functions → Dashboard
3. Cliquer sur une fonction → Logs

### Voir les métriques

Firebase Console → Functions → sélectionner une fonction
- Invocations
- Temps d'exécution
- Erreurs
- Utilisation mémoire

### Alertes (recommandé)

Configurer des alertes pour :
- Taux d'erreur > 5%
- Temps d'exécution > 10s
- Nombre d'invocations anormal

Firebase Console → Functions → Alerting

## 🔧 Debugging

### Erreur commune : "Missing permissions"

**Solution** : Activer les APIs requises
```bash
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
```

### Erreur : "APNs certificate not configured"

**Solution** : Configurer APNs dans Firebase Console (voir Configuration)

### Erreur : "Insufficient permissions"

**Solution** : Vérifier que le Service Account a les rôles :
- Cloud Functions Admin
- Firebase Admin
- Cloud Messaging Admin

### Fonction ne se déclenche pas

**Vérifications** :
1. La fonction est bien déployée : `firebase functions:list`
2. Le trigger est correct (path Firestore, schedule)
3. Les logs montrent l'exécution : `firebase functions:log`
4. Pas d'erreur de quota dépassé

## 📝 Notes importantes

### Quotas et limites

- **Scheduled functions** : Limitées par défaut, upgrader au plan Blaze si nécessaire
- **FCM** : 1 million de messages gratuits/mois
- **Firestore** : 50k lectures gratuites/jour

### Coûts estimés

Pour **10 000 utilisateurs actifs** :
- Scheduled functions : ~$5/mois
- Trigger functions : ~$2/mois
- FCM : Gratuit (< 1M messages)

**Total estimé** : ~$7/mois

### Sécurité

- ✅ Les push tokens sont stockés dans Firestore (champ `pushToken`)
- ✅ Les fonctions vérifient l'existence de l'utilisateur
- ✅ Les notifications sont envoyées uniquement aux destinataires légitimes
- ⚠️ Ajouter des règles de sécurité Firestore pour protéger les données

### Performance

- **Latence moyenne** : 100-300ms pour sendPushNotification
- **Scheduled functions** : S'exécutent en max 60 secondes
- **Retry** : Automatique en cas d'erreur (max 7 jours)

## 🆘 Support

- [Documentation Firebase Functions](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Community StackOverflow](https://stackoverflow.com/questions/tagged/firebase-cloud-functions)

## 🔄 Mise à jour

Pour mettre à jour les dépendances :

```bash
cd functions
npm update
npm audit fix
```

Pour migrer vers Functions v2 (si nécessaire) :
https://firebase.google.com/docs/functions/2nd-gen-upgrade

---

**Auteur** : Zenloop Team
**Dernière mise à jour** : Mars 2024
