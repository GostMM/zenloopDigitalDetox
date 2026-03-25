# 🎉 Nouvelles Fonctionnalités Sociales - SocialTab

## Vue d'ensemble

Le SocialTab a été considérablement amélioré avec un système complet de notifications, de mentions, et de gestion des demandes de pause. Voici toutes les nouvelles fonctionnalités implémentées.

---

## 📬 1. Système de Notifications Sociales

### Fichier: `SocialNotificationManager.swift`

**Fonctionnalités:**
- Gestion centralisée de toutes les notifications sociales
- Listener temps réel avec Firestore
- Compteur de notifications non lues
- Création automatique de notifications pour tous les événements

**Types de notifications supportés:**
- ✉️ **Messages** - Nouveaux messages dans le chat
- 🎯 **Mentions** - Quand quelqu'un vous mentionne avec @username
- 🙋 **Demandes de pause** - Notifications pour le leader
- ✅ **Pause acceptée** - Confirmation pour le demandeur
- ❌ **Pause refusée** - Notification de refus
- 🚀 **Session démarrée** - Pour tous les membres
- ⏸️ **Session en pause** - Notification de pause
- ▶️ **Session reprise** - Notification de reprise
- 🏆 **Session terminée** - Fin de session
- 👥 **Membre rejoint/parti** - Changements de membres
- 📨 **Invitations** - Invitations à rejoindre une session

**API:**
```swift
// Créer une notification
try await SocialNotificationManager.shared.createNotification(
    userId: "user_id",
    type: .mention,
    sessionId: "session_id",
    sessionTitle: "Ma Session",
    fromUserId: "sender_id",
    fromUsername: "Alice",
    message: "Alice vous a mentionné",
    messageId: "msg_id",
    actionUrl: "zenloop://session/session_id?message=msg_id"
)

// Marquer comme lu
try await notificationManager.markAsRead(notificationId: "notif_id")

// Tout marquer comme lu
try await notificationManager.markAllAsRead(userId: "user_id")
```

---

## 🔔 2. Cloche de Notification dans le Header

### Fichier: `SocialTab.swift` (ligne 112)

**Fonctionnalités:**
- Badge rouge avec le nombre de notifications non lues
- Animation élégante d'apparition
- Clic pour ouvrir la vue des notifications
- Design cohérent avec l'interface existante

**Code:**
```swift
SocialHeader(
    showContent: showContent,
    unreadCount: notificationManager.unreadCount,
    onNotificationTap: { showNotifications = true }
)
```

---

## 📋 3. Vue des Notifications

### Fichier: `NotificationsView.swift`

**Fonctionnalités:**
- Liste complète des notifications avec scroll
- Icônes colorées par type de notification
- Badge "non lu" visible pour les nouvelles notifications
- Affichage du temps écoulé (ex: "Il y a 5 min", "Il y a 2h", "Il y a 3j")
- Navigation directe vers la session concernée
- Bouton "Tout marquer comme lu"
- État vide élégant quand aucune notification

**Design:**
- Fond sombre cohérent avec l'app
- Cartes avec fond légèrement bleuté pour les non lues
- Animations de transition
- Bouton "ScaleButtonStyle" pour feedback haptique

---

## 💬 4. Système de Mentions (@username)

### Fichier: `SessionDetailView.swift` (ligne 830)

**Fonctionnalités:**
- Auto-complétion intelligente quand on tape `@`
- Liste horizontale scrollable de tous les membres
- Filtrage en temps réel pendant la saisie
- Chips de sélection rapide avec icône utilisateur
- Détection automatique des mentions dans les messages
- Création automatique de notifications pour les utilisateurs mentionnés
- Navigation vers le message depuis la notification

**Utilisation:**
1. Dans le chat, tapez `@` pour ouvrir le sélecteur
2. Tapez les premières lettres pour filtrer
3. Cliquez sur un membre pour l'insérer
4. Le message est envoyé avec la mention
5. L'utilisateur mentionné reçoit une notification

**Code technique:**
```swift
private func checkForMentionTrigger(_ text: String) {
    if text.hasSuffix("@") {
        showMentionPicker = true
        mentionSearchText = ""
    } else if let lastAtIndex = text.lastIndex(of: "@") {
        let afterAt = String(text[text.index(after: lastAtIndex)...])
        if !afterAt.contains(" ") {
            showMentionPicker = true
            mentionSearchText = afterAt
        }
    } else {
        showMentionPicker = false
    }
}
```

---

## 🙋 5. Affichage des Demandes de Pause (Leader)

### Fichier: `SocialTab.swift` (ligne 347)

**Fonctionnalités:**
- Carte spéciale `LeaderPauseRequestsCard` visible uniquement pour le leader
- Affiche toutes les demandes de pause en attente
- Affiche la raison fournie par le membre (si disponible)
- Affichage du temps écoulé depuis la demande
- Boutons Accepter ✅ / Refuser ❌
- Actions immédiates avec feedback haptique
- Design orange distinctif pour attirer l'attention

**Visibilité:**
```swift
if let currentSession = sessionManager.currentSession,
   let currentUserId = sessionManager.currentUser?.id,
   currentSession.leaderId == currentUserId,
   !sessionManager.pendingPauseRequests.isEmpty {
    LeaderPauseRequestsCard(...)
}
```

**Actions:**
- **Accepter:** Met la session en pause et notifie le demandeur
- **Refuser:** Envoie une notification de refus au demandeur

---

## 🌐 6. Sessions Publiques Fonctionnelles

### Fichier: `SessionManager.swift` (ligne 543)

**Fonctionnalités:**
- Listener temps réel pour les sessions publiques
- Filtrage automatique (exclut les sessions dont on est déjà membre)
- Affichage dans `PublicSessionsSection`
- État vide élégant si aucune session publique
- Navigation vers les détails de session

**Code de filtrage:**
```swift
let allPublic = snapshot.documents.compactMap { try? $0.data(as: Session.self) }
let uid = self.currentUser?.id ?? ""
self.publicSessions = allPublic.filter { !$0.memberIds.contains(uid) }
```

---

## 🔗 7. Navigation Deep Link

### Fichier: `DeepLinkCoordinator.swift`

**Fonctionnalités:**
- Gère les URL schemes `zenloop://session/{id}` et `zenloop://notifications`
- Navigation automatique depuis les notifications
- Support des query parameters (ex: `?message=msg_id`)
- Intégration transparente avec SocialTab
- Logging détaillé pour debugging

**URLs supportées:**
- `zenloop://session/{sessionId}` - Ouvre la session directement
- `zenloop://session/{sessionId}?message={messageId}` - Ouvre la session et scroll vers le message
- `zenloop://notifications` - Ouvre la vue des notifications

**Intégration:**
```swift
.onChange(of: deepLinkCoordinator.shouldNavigateToSession) { _, shouldNavigate in
    if shouldNavigate, let sessionId = deepLinkCoordinator.pendingSessionId {
        selectedSessionId = sessionId
        showSessionDetail = true
        deepLinkCoordinator.clearNavigation()
    }
}
```

---

## 🔄 8. Notifications Automatiques dans SessionManager

### Fichier: `SessionManager.swift`

**Événements notifiés automatiquement:**

### Démarrage de session
- ✅ Notifie tous les membres (sauf le leader)
- Message: "La session {title} a démarré !"
- Navigation: `zenloop://session/{sessionId}`

### Demande de pause
- ✅ Notifie le leader uniquement
- Message: "{username} demande une pause : {raison}"
- Navigation: `zenloop://session/{sessionId}?tab=pauseRequests`

### Réponse à une demande de pause
- ✅ Notifie le demandeur
- Messages:
  - Acceptée: "{leader} a accepté votre demande de pause"
  - Refusée: "{leader} a refusé votre demande de pause"
- Navigation: `zenloop://session/{sessionId}`

### Mentions dans le chat
- ✅ Notifie les utilisateurs mentionnés (via `@username`)
- Message: "{username} vous a mentionné : {message}"
- Navigation: `zenloop://session/{sessionId}?message={messageId}`

**Code d'exemple:**
```swift
// Dans startSession()
let notifManager = SocialNotificationManager.shared
for memberDoc in membersSnapshot.documents where memberDoc.documentID != uid {
    try? await notifManager.createNotification(
        userId: memberDoc.documentID,
        type: .sessionStarted,
        sessionId: sessionId,
        sessionTitle: session.title,
        fromUserId: uid,
        fromUsername: currentUser?.username,
        message: "La session \(session.title) a démarré !",
        actionUrl: "zenloop://session/\(sessionId)"
    )
}
```

---

## 🎨 Design & UX

### Cohérence Visuelle
- Même palette de couleurs que l'app (fond sombre, cartes avec dégradés)
- Animations Spring élégantes
- Feedback haptique sur toutes les actions
- ScaleButtonStyle pour les boutons interactifs

### Accessibilité
- Tailles de police appropriées
- Contraste de couleurs optimisé
- Icônes avec labels
- Support du Dynamic Type

### Performance
- Listeners temps réel optimisés
- Limit de 50 notifications par utilisateur
- Cleanup automatique des anciennes notifications
- Lazy loading des listes

---

## 📊 Architecture

```
┌─────────────────────────────────────────┐
│         SocialTab (Vue principale)       │
│  - Cloche de notification avec badge    │
│  - Demandes de pause (leader)           │
│  - Navigation deep link                 │
│  - Intégration avec tous les managers   │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼────────┐  ┌────▼──────────────┐
│ NotifView  │  │ SessionDetailView │
│ - Liste    │  │ - Chat mentions   │
│ - Actions  │  │ - @ autocomplete  │
│ - Naviga   │  │ - Chip selection  │
└────────────┘  └───────────────────┘
                        │
                ┌───────┴────────┐
                │                │
     ┌──────────▼───┐  ┌────────▼────────┐
     │ SessionMgr   │  │ SocialNotifMgr  │
     │ - Sessions   │  │ - Firestore     │
     │ - Events     │  │ - Real-time     │
     │ - Notifs     │  │ - CRUD notifs   │
     └──────────────┘  └─────────────────┘
                │
         ┌──────┴──────┐
         │             │
   ┌─────▼─────┐ ┌────▼──────────┐
   │ DeepLink  │ │ Firebase      │
   │ Coord     │ │ (Firestore)   │
   └───────────┘ └───────────────┘
```

---

## 🔥 Firestore Schema

### Collection: `socialNotifications`

```typescript
{
  id: string (auto)
  userId: string                    // Destinataire
  type: SocialNotificationType      // Type de notification
  sessionId?: string                // ID de la session concernée
  sessionTitle?: string             // Titre de la session
  fromUserId?: string               // Expéditeur
  fromUsername?: string             // Nom de l'expéditeur
  message: string                   // Message de la notification
  messageId?: string                // ID du message (pour mentions)
  isRead: boolean                   // Lu/non lu
  timestamp: Timestamp              // Date de création
  actionUrl?: string                // URL pour navigation
}
```

**Indexes recommandés:**
- `userId` + `timestamp` (descending)
- `userId` + `isRead` + `timestamp` (descending)
- `sessionId` + `timestamp` (descending)

---

## 🚀 Utilisation

### Pour tester les notifications:

1. **Créer une session:**
   - Connectez-vous avec deux comptes différents
   - Créez une session publique avec le compte A
   - Rejoignez avec le compte B

2. **Tester les mentions:**
   - Dans le chat, tapez `@` et sélectionnez un membre
   - Envoyez le message
   - L'utilisateur mentionné reçoit une notification

3. **Tester les demandes de pause:**
   - En tant que membre (non-leader), demandez une pause
   - Le leader reçoit une notification et voit la carte dans SocialTab
   - Le leader peut accepter ou refuser

4. **Tester la navigation:**
   - Recevez une notification
   - Cliquez dessus pour ouvrir la session concernée

---

## 📝 Notes Importantes

### Permissions Firestore
Assurez-vous que les règles Firestore permettent:
- Lecture des notifications par le propriétaire (`userId`)
- Écriture par n'importe quel utilisateur authentifié
- Suppression uniquement par le propriétaire

**Exemple de règles:**
```javascript
match /socialNotifications/{notifId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow create: if request.auth != null;
  allow update, delete: if request.auth.uid == resource.data.userId;
}
```

### Performance
- Les listeners sont démarrés uniquement quand SocialTab est visible
- Arrêt automatique des listeners sur `onDisappear`
- Limit de 50 notifications pour éviter les surcharges
- Cleanup automatique des notifications expirées (optionnel)

### Future Améliorations Possibles
- [ ] Notifications push (via Firebase Cloud Messaging)
- [ ] Sons personnalisés par type de notification
- [ ] Vibrations haptiques différenciées
- [ ] Marquage groupé comme lu
- [ ] Filtrage par type de notification
- [ ] Recherche dans les notifications
- [ ] Archive des notifications anciennes

---

## ✅ Status

**Toutes les fonctionnalités sont implémentées et fonctionnelles !**

Le build réussit sans erreur. Prêt pour les tests en production.

---

**Développé avec ❤️ pour Zenloop**
