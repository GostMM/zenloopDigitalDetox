# 🎯 ZENLOOP SESSIONS - Architecture Complète (Firebase)

## 📋 Vision Produit

**Problème identifié :**
Les apps de blocage échouent car il est facile de contourner seul.

**Solution :**
Ajouter l'**accountability sociale** — se monitorer mutuellement avec amis/famille pour créer une motivation externe.

---

## 🏗️ Architecture Technique Complète

```
┌─────────────────────────────────────────────────────────────────┐
│                      ZENLOOP SOCIAL STACK                        │
│                        (Firebase Edition)                        │
└─────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                         LAYER 1: BACKEND                          │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │             Firebase (zenloop-app project)                │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  ▶ Firebase Auth (Sign in with Apple)                    │   │
│  │  ├─ Apple credential → Firebase UID                      │   │
│  │  ├─ Auto-creation du user dans Auth                      │   │
│  │  └─ Token refresh automatique                            │   │
│  │                                                          │   │
│  │  ▶ Cloud Firestore (NoSQL)                               │   │
│  │                                                          │   │
│  │  Collection: users/{uid}                                 │   │
│  │  ├─ username: String                                     │   │
│  │  ├─ appleUserId: String                                  │   │
│  │  ├─ createdAt: Timestamp                                 │   │
│  │  ├─ sessionHistory: [String]                             │   │
│  │  ├─ pushToken: String?                                   │   │
│  │  ├─ totalSessionsJoined: Int                             │   │
│  │  ├─ totalSessionsCreated: Int                            │   │
│  │  └─ currentStreak: Int                                   │   │
│  │                                                          │   │
│  │  Collection: sessions/{sessionId}                        │   │
│  │  ├─ title: String                                        │   │
│  │  ├─ description: String                                  │   │
│  │  ├─ leaderId: String (uid)                               │   │
│  │  ├─ leaderUsername: String                               │   │
│  │  ├─ visibility: String (public/private)                  │   │
│  │  ├─ inviteCode: String (6 chars)                         │   │
│  │  ├─ suggestedApps: [String]                              │   │
│  │  ├─ maxParticipants: Int?                                │   │
│  │  ├─ status: String (lobby/active/completed/dissolved)    │   │
│  │  ├─ createdAt: Timestamp                                 │   │
│  │  ├─ startedAt: Timestamp?                                │   │
│  │  ├─ endedAt: Timestamp?                                  │   │
│  │  └─ memberIds: [String] (pour queries)                   │   │
│  │                                                          │   │
│  │  Sub-collection: sessions/{id}/members/{uid}             │   │
│  │  ├─ username: String                                     │   │
│  │  ├─ role: String (leader/member)                         │   │
│  │  ├─ status: String (joined/ready/active/left)            │   │
│  │  ├─ joinedAt: Timestamp                                  │   │
│  │  ├─ leftAt: Timestamp?                                   │   │
│  │  ├─ selectedApps: [String]                               │   │
│  │  ├─ isReady: Bool                                        │   │
│  │  ├─ bypassAttempts: Int                                  │   │
│  │  └─ messagesCount: Int                                   │   │
│  │                                                          │   │
│  │  Sub-collection: sessions/{id}/messages/{msgId}          │   │
│  │  ├─ userId: String                                       │   │
│  │  ├─ username: String                                     │   │
│  │  ├─ content: String                                      │   │
│  │  ├─ messageType: String (text/encouragement/system)      │   │
│  │  └─ timestamp: Timestamp                                 │   │
│  │                                                          │   │
│  │  Sub-collection: sessions/{id}/events/{eventId}          │   │
│  │  ├─ userId: String                                       │   │
│  │  ├─ username: String                                     │   │
│  │  ├─ eventType: String                                    │   │
│  │  ├─ timestamp: Timestamp                                 │   │
│  │  └─ metadata: Map<String, Any>                           │   │
│  │                                                          │   │
│  │  Collection: invitations/{invitationId}                  │   │
│  │  ├─ sessionId: String                                    │   │
│  │  ├─ fromUserId: String                                   │   │
│  │  ├─ fromUsername: String                                  │   │
│  │  ├─ toUserId: String                                     │   │
│  │  ├─ toUsername: String                                    │   │
│  │  ├─ status: String (pending/accepted/declined/expired)   │   │
│  │  ├─ sentAt: Timestamp                                    │   │
│  │  ├─ respondedAt: Timestamp?                              │   │
│  │  ├─ sessionTitle: String                                 │   │
│  │  └─ sessionDescription: String                           │   │
│  │                                                          │   │
│  │  ▶ Firebase Cloud Messaging (FCM)                        │   │
│  │  └─ Push notifications pour tous les events              │   │
│  │                                                          │   │
│  │  ▶ Cloud Functions (optionnel mais recommandé)           │   │
│  │  ├─ onSessionStart → notify all members                  │   │
│  │  ├─ onMemberLeft → notify all + create event             │   │
│  │  ├─ onSessionDissolved → notify + cleanup                │   │
│  │  └─ onInvitationCreated → send push to target            │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           ▲                                       │
│                           │ Firebase SDK                          │
│                           │ + Firestore Listeners                 │
│                           │ + FCM                                 │
└───────────────────────────┼───────────────────────────────────────┘
                            │
┌───────────────────────────┼───────────────────────────────────────┐
│                         LAYER 2: SYNC                             │
├───────────────────────────┼───────────────────────────────────────┤
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         SessionManager (NEW - Firebase)                  │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  • Firestore real-time listeners (snapshotListener)      │   │
│  │  • CRUD via Firestore SDK                                │   │
│  │  • Offline persistence (Firestore built-in)              │   │
│  │  • Automatic sync on reconnect                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           ▲                                       │
│                           │                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           PushNotificationManager (NEW)                  │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  • Register APNs token → FCM                             │   │
│  │  • Store FCM token in user doc                           │   │
│  │  • Handle incoming push → Route to screens               │   │
│  │  • Badge management                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────┼───────────────────────────────────────┘
                            │
┌───────────────────────────┼───────────────────────────────────────┐
│                     LAYER 3: LOCAL DATA                           │
├───────────────────────────┼───────────────────────────────────────┤
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │       Firestore Offline Persistence (built-in)           │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  • Activé par défaut sur iOS                             │   │
│  │  • Cache local automatique                               │   │
│  │  • Writes queued offline → synced on reconnect           │   │
│  │  • Listeners fire with cached data first                 │   │
│  │  • Pas besoin de UserDefaults pour le cache              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │       DataManager (MODIFIED - Existing)                  │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  UserDefaults (données purement locales)                 │   │
│  │  ├─ Current Firebase UID                                 │   │
│  │  ├─ Notification preferences                             │   │
│  │  └─ App-specific settings                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
                            │
┌───────────────────────────┼───────────────────────────────────────┐
│                       LAYER 4: UI VIEWS                           │
├───────────────────────────┼───────────────────────────────────────┤
│                           ▼                                       │
│                                                                   │
│  HomeView (Enhanced)                                              │
│  ├─ Quick Actions                                                 │
│  ├─ Active Challenges                                             │
│  └─ ✨ NEW: Friends Activity Feed (3 recent events)              │
│                                                                   │
│  ✨ NEW: SocialTab                                                │
│  ├─ FriendsListView                                               │
│  │  ├─ List of friends with status                                │
│  │  ├─ Live streak indicators                                    │
│  │  └─ Tap → FriendDetailView                                    │
│  │                                                               │
│  ├─ FriendRequestsView                                            │
│  │  ├─ Pending incoming requests                                 │
│  │  └─ Accept/Reject buttons                                     │
│  │                                                               │
│  ├─ AddFriendView                                                 │
│  │  ├─ Search by username                                        │
│  │  └─ Send friend request                                       │
│  │                                                               │
│  └─ AccountabilitySetupView                                       │
│     ├─ Choose accountability partners (from friends)             │
│     ├─ Config: Notify on bypass? Share stats?                    │
│     └─ Enable/disable per friend                                 │
│                                                                   │
│  ✨ FriendDetailView (NEW)                                        │
│  ├─ Profile: username, badges, streak                            │
│  ├─ Shared stats (if enabled)                                    │
│  ├─ Recent activity timeline                                     │
│  ├─ "Send encouragement" button                                  │
│  └─ "Start shared challenge" button                              │
│                                                                   │
│  ✨ GroupChallengeView (NEW)                                      │
│  ├─ List of participants                                         │
│  ├─ Real-time progress bars                                      │
│  ├─ Chat/messages section                                        │
│  └─ Leaderboard                                                  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

---

## 🔥 Pourquoi Firebase > CloudKit pour ZenLoop

| Critère | CloudKit | Firebase |
|---------|----------|----------|
| Real-time listeners | CKSubscription (push only) | snapshotListener (instantané) |
| Offline persistence | Manuel (UserDefaults) | Built-in automatique |
| Auth providers | Apple only | Apple + Email + Google + anonymous |
| Push notifications | APNs direct | FCM (simplifie cross-platform) |
| Cloud Functions | ❌ Pas disponible | ✅ Logique serveur (notifications, cleanup) |
| Firestore queries | Limité | Compound queries, array-contains, etc. |
| Android futur | ❌ Impossible | ✅ Même backend |
| Console admin | CloudKit Dashboard (basique) | Firebase Console (complet) |

---

## 🔐 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── Helpers ──
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return request.auth.uid == uid;
    }

    // ── Users ──
    match /users/{uid} {
      allow read: if isAuthenticated();
      allow create: if isOwner(uid);
      allow update: if isOwner(uid);
      allow delete: if false; // jamais
    }

    // ── Sessions ──
    match /sessions/{sessionId} {
      allow read: if isAuthenticated() && (
        resource.data.visibility == 'public' ||
        request.auth.uid in resource.data.memberIds ||
        request.auth.uid == resource.data.leaderId
      );
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (
        request.auth.uid == resource.data.leaderId ||
        request.auth.uid in resource.data.memberIds
      );
      allow delete: if request.auth.uid == resource.data.leaderId;

      // ── Members sub-collection ──
      match /members/{memberId} {
        allow read: if isAuthenticated();
        allow create: if isAuthenticated();
        allow update: if isAuthenticated() && (
          isOwner(memberId) ||
          request.auth.uid == get(/databases/$(database)/documents/sessions/$(sessionId)).data.leaderId
        );
        allow delete: if false;
      }

      // ── Messages sub-collection ──
      match /messages/{messageId} {
        allow read: if isAuthenticated();
        allow create: if isAuthenticated()
          && request.auth.uid in get(/databases/$(database)/documents/sessions/$(sessionId)).data.memberIds;
        allow update, delete: if false;
      }

      // ── Events sub-collection ──
      match /events/{eventId} {
        allow read: if isAuthenticated();
        allow create: if isAuthenticated();
        allow update, delete: if false;
      }
    }

    // ── Invitations ──
    match /invitations/{invitationId} {
      allow read: if isAuthenticated() && (
        request.auth.uid == resource.data.fromUserId ||
        request.auth.uid == resource.data.toUserId
      );
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (
        request.auth.uid == resource.data.toUserId // seul le destinataire peut accept/decline
      );
      allow delete: if false;
    }
  }
}
```

---

## 📊 Flow Utilisateur Complet

### **Landing — Page de Connexion**

```
┌──────────────────────────────────────────────────────────────────┐
│  1. LOGIN SCREEN (First launch)                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  🍎 Sign in with Apple                                 │     │
│  │  [Continue with Apple]                                 │     │
│  │                                                        │     │
│  │  → Firebase Auth crée le user automatiquement          │     │
│  │  → Si premier login: demander username                 │     │
│  │                                                        │     │
│  │  Create username                                       │     │
│  │  [_________________]                                   │     │
│  │                                                        │     │
│  │  [Get Started →]                                       │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### **Home — Sessions Dashboard**

```
┌──────────────────────────────────────────────────────────────────┐
│  2. SESSIONS HOME (Main screen after login)                      │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Navigation: [My Sessions] [Public Sessions]          │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  📝 Enter Invitation Code                             │     │
│  │  [__ __ __ __ __ __]  [Join]                          │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  🌍 Public Sessions                                    │     │
│  │                                                        │     │
│  │  ┌──────────────────────────────────────┐             │     │
│  │  │ 🎯 Focus Marathon                    │             │     │
│  │  │ by @Alice • 4/10 members             │             │     │
│  │  │ Status: ⏳ Starting in 15min         │             │     │
│  │  │ [Join Session →]                     │             │     │
│  │  └──────────────────────────────────────┘             │     │
│  │                                                        │     │
│  │  ┌──────────────────────────────────────┐             │     │
│  │  │ 🧘 Evening Detox                     │             │     │
│  │  │ by @Bob • 🔴 Live (2h left)          │             │     │
│  │  │ 12/20 members                        │             │     │
│  │  │ [Join Now →]                         │             │     │
│  │  └──────────────────────────────────────┘             │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  [+ Create New Session]                               │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### **Création de Session (Leader)**

```
┌──────────────────────────────────────────────────────────────────┐
│  3. CREATE SESSION (Leader flow)                                 │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Session Title                                         │     │
│  │  [_______________________________]                     │     │
│  │                                                        │     │
│  │  Description                                           │     │
│  │  [_______________________________]                     │     │
│  │  [_______________________________]                     │     │
│  │                                                        │     │
│  │  Visibility                                            │     │
│  │  ○ Public   ● Private                                 │     │
│  │                                                        │     │
│  │  Apps to Block (Leader selects)                       │     │
│  │  ☑️ Instagram    ☑️ TikTok                           │     │
│  │  ☑️ Twitter      ☐ YouTube                           │     │
│  │  [+ Add more apps]                                    │     │
│  │                                                        │     │
│  │  Max Participants: [___] (optional)                   │     │
│  │                                                        │     │
│  │  📋 Invitation Code: ABC123                           │     │
│  │     (auto-generated)                                  │     │
│  │                                                        │     │
│  │  [Create Session]                                     │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### **Lobby — Avant démarrage (Vue Leader)**

```
┌──────────────────────────────────────────────────────────────────┐
│  4. SESSION LOBBY (Before start - Leader view)                   │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  🎯 Focus Marathon                                     │     │
│  │  👑 You're the leader                                  │     │
│  │                                                        │     │
│  │  Status: ⏳ Waiting to start                           │     │
│  │  Code: ABC123  [Copy] [Share]                         │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  Members (4/10)                                        │     │
│  │                                                        │     │
│  │  👑 @Alice (you) • Leader • ✅ Ready                  │     │
│  │  👤 @Bob        • ✅ Ready                            │     │
│  │  👤 @Charlie    • ⏳ Choosing apps...                 │     │
│  │  👤 @Diana      • ✅ Ready                            │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  [Invite from Previous Sessions]                      │     │
│  │  [📢 Start Session]  (enabled when ≥1 ready)          │     │
│  │  [🗑️ Dissolve Session]                                │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### **Lobby — Membre rejoint**

```
┌──────────────────────────────────────────────────────────────────┐
│  5. SESSION LOBBY (Member joins)                                 │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  🎯 Focus Marathon                                     │     │
│  │  Leader: @Alice                                        │     │
│  │                                                        │     │
│  │  Status: ⏳ Starting soon                              │     │
│  │                                                        │     │
│  │  Select apps to block during this session:            │     │
│  │                                                        │     │
│  │  Suggested by leader:                                 │     │
│  │  ☑️ Instagram    ☑️ TikTok                           │     │
│  │  ☑️ Twitter      ☐ YouTube                           │     │
│  │                                                        │     │
│  │  Add your own:                                         │     │
│  │  [+ Select apps]                                      │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  [✅ I'm Ready]                                        │     │
│  │                                                        │     │
│  │  Once ready, you'll wait for the leader to start      │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### **Session Active (Live)**

```
┌──────────────────────────────────────────────────────────────────┐
│  6. SESSION ACTIVE (Leader started)                              │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  🎯 Focus Marathon                                     │     │
│  │  🔴 LIVE • 1h 43min remaining                          │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  Members Status:                                       │     │
│  │                                                        │     │
│  │  ✅ @Alice • 3 apps blocked                           │     │
│  │  ✅ @Bob • 4 apps blocked                             │     │
│  │  ⚠️ @Charlie • Left the session (2min ago)            │     │
│  │     💬 [Send encouragement]                            │     │
│  │  ✅ @Diana • 2 apps blocked                           │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  Group Chat                                            │     │
│  │  ┌──────────────────────────────┐                     │     │
│  │  │ @Bob: Let's do this! 💪       │                     │     │
│  │  │ @Alice: Stay strong everyone! │                     │     │
│  │  └──────────────────────────────┘                     │     │
│  │  [Type a message...]                                  │     │
│  │                                                        │     │
│  │  ─────────────────────────────────────────            │     │
│  │                                                        │     │
│  │  Leader controls:                                      │     │
│  │  [⏸️ End Session] [🗑️ Dissolve]                       │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Flows Détaillés par Scénario

### **Flow 1: Leader crée une session**

```
Leader (Alice)                    Firebase                  Members
     │                                │                         │
     │ 1. Tap "Create Session"        │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │ 2. Fill form:                  │                         │
     │    - Title: "Focus Marathon"   │                         │
     │    - Visibility: Public        │                         │
     │    - Apps: IG, TikTok          │                         │
     │    - Max: 10 members           │                         │
     │                                │                         │
     │ 3. Submit                      │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore:    │                         │
     │                  4a. Create sessions/{id}                │
     │                  4b. Generate inviteCode                 │
     │                  4c. status = "lobby"                    │
     │                  4d. Add leader to members/              │
     │                      sub-collection                      │
     │                  4e. Add leaderId to memberIds[]         │
     │                                │                         │
     │ 5. snapshotListener fires      │                         │
     │    Navigate to Session Lobby   │                         │
     │<────────────────────────────────                         │
     │                                │                         │
     │ Session visible via query:     │                         │
     │ visibility == "public" &&      │                         │
     │ status == "lobby"              │                         │
     │                                │────────────────────────>│
     │                                │ (real-time listener)    │
```

### **Flow 2: Membre rejoint via code**

```
Member (Bob)                      Firebase                  Leader
     │                                │                         │
     │ 1. Enter code "ABC123"         │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore:    │                         │
     │                  2. Query:     │                         │
     │                  sessions where│                         │
     │                  inviteCode == "ABC123"                  │
     │                                │                         │
     │ 3. Show session details        │                         │
     │<────────────────────────────────                         │
     │                                │                         │
     │ 4. Tap "Join"                  │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore (batch write):               │
     │                  5a. Add doc to members/{bobUid}        │
     │                      status: "joined", isReady: false   │
     │                  5b. arrayUnion memberIds[] += bobUid    │
     │                                │                         │
     │                  6. Cloud Function triggers:             │
     │                     → FCM push to leader                │
     │                                │────────────────────────>│
     │                                │ "Bob joined your        │
     │                                │  session"               │
     │                                │                         │
     │ 7. snapshotListener on         │                         │
     │    members/ → show lobby       │                         │
     │<────────────────────────────────                         │
     │                                │                         │
     │ 8. Select apps (IG, Twitter)   │                         │
     │ 9. Tap "I'm Ready"             │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore:    │                         │
     │                  10. Update members/{bobUid}             │
     │                      isReady: true                      │
     │                      selectedApps: [...]                │
     │                      status: "ready"                    │
     │                                │                         │
     │                  11. Leader's snapshotListener fires     │
     │                                │────────────────────────>│
     │                                │ "Bob is ready ✅"       │
     │                                │ (real-time, no push     │
     │                                │  needed)                │
```

### **Flow 3: Membre rejoint session EN COURS (late join)**

```
Member (Charlie)                  Firebase              Active Session
     │                                │                         │
     │ 1. Join session ABC123         │                         │
     │    (Session already started)   │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore:    │                         │
     │                  2. Read session.status == "active"      │
     │                                │                         │
     │ 3. Show warning:               │                         │
     │    "⚠️ Session already live"   │                         │
     │    "Your blocks will start     │                         │
     │     immediately after ready"   │                         │
     │<────────────────────────────────                         │
     │                                │                         │
     │ 4. Select apps                 │                         │
     │ 5. Tap "I'm Ready"             │                         │
     │────────────────────────────────>                         │
     │                                │                         │
     │                  Firestore (batch write):               │
     │                  6a. Create members/{charlieUid}        │
     │                      status: "active"                   │
     │                  6b. arrayUnion memberIds[]              │
     │                                │                         │
     │                  7. ⚡ APPLY BLOCKS IMMEDIATELY          │
     │                     (on Charlie's device locally)        │
     │                                │                         │
     │ Apps blocked instantly         │                         │
     │ (GlobalShieldManager.apply)    │                         │
     │<────────────────────────────────                         │
     │                                │                         │
     │                  8. Cloud Function → FCM to all         │
     │                                │────────────────────────>│
     │                                │ "Charlie joined live!"  │
```

### **Flow 4: Leader lance la session**

```
Leader (Alice)              Firebase              All Members (ready)
     │                          │                         │
     │ 1. Tap "Start Session"   │                         │
     │──────────────────────────>                         │
     │                          │                         │
     │              Firestore:  │                         │
     │              2. Transaction:                       │
     │                 - Read session                     │
     │                 - Validate ≥1 ready member         │
     │                 - Update session:                  │
     │                   status = "active"                │
     │                   startedAt = serverTimestamp()    │
     │                 - For each ready member:           │
     │                   update status → "active"         │
     │                          │                         │
     │              3. Cloud Function onUpdate:           │
     │                 status changed to "active"         │
     │                 → FCM to all members               │
     │                          │────────────────────────>│
     │                          │ "🎯 Session started!"   │
     │                          │                         │
     │                          │ 4. Each device's        │
     │                          │ snapshotListener fires   │
     │                          │ → applies blocks locally │
     │                          │<────────────────────────│
     │                          │                         │
     │ 5. snapshotListener      │                         │
     │    → navigate to Active  │                         │
     │<──────────────────────────                         │
```

### **Flow 5: Membre quitte la session en cours**

```
Member (Bob)                 Firebase              All Other Members
     │                           │                         │
     │ 1. Tap "Leave Session"    │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │ Show confirmation:        │                         │
     │ "⚠️ Leave active session?"│                         │
     │ "Blocks will be removed"  │                         │
     │                           │                         │
     │ 2. Confirm                │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │               Firestore (batch write):              │
     │               3a. Update members/{bobUid}           │
     │                   status = "left"                   │
     │                   leftAt = serverTimestamp()         │
     │               3b. Create events/{eventId}           │
     │                   type: "memberLeft"                │
     │               3c. Create messages/{msgId}           │
     │                   type: "systemAlert"               │
     │                   "Bob left 💔"                     │
     │                           │                         │
     │ 4. Remove blocks locally  │                         │
     │ (GlobalShieldManager)     │                         │
     │<───────────────────────────                         │
     │                           │                         │
     │               5. Cloud Function → FCM               │
     │                           │────────────────────────>│
     │                           │ "⚠️ Bob left"           │
     │                           │ [Send encouragement]    │
     │                           │                         │
     │               6. snapshotListeners fire             │
     │               on members/ and messages/             │
     │                           │────────────────────────>│
     │                           │ (real-time UI update)   │
```

### **Flow 6: Leader dissout la session**

```
Leader (Alice)               Firebase              All Members
     │                           │                         │
     │ 1. Tap "Dissolve Session" │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │ Show warning:             │                         │
     │ "⚠️ Dissolve will end     │                         │
     │  session for ALL members" │                         │
     │                           │                         │
     │ 2. Confirm                │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │               Firestore:  │                         │
     │               3. Update session:                    │
     │                  status = "dissolved"               │
     │                  endedAt = serverTimestamp()         │
     │                           │                         │
     │               4. Cloud Function onUpdate:           │
     │                  status changed to "dissolved"      │
     │                  → For each member:                 │
     │                    FCM: "Session dissolved"         │
     │                           │────────────────────────>│
     │                           │ "🗑️ Session dissolved"  │
     │                           │ "All blocks removed"    │
     │                           │                         │
     │               5. Each device's                      │
     │               snapshotListener fires                │
     │               → removeSessionBlocks()               │
     │                           │<────────────────────────│
     │                           │                         │
     │ 6. Navigate to Home       │                         │
     │<───────────────────────────                         │
```

### **Flow 7: Leader invite des membres d'anciennes sessions**

```
Leader (Alice)               Firebase              Invited User (Bob)
     │                           │                         │
     │ 1. In session lobby       │                         │
     │ 2. Tap "Invite from       │                         │
     │    Previous Sessions"     │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │               Firestore:  │                         │
     │               3. Query sessions where               │
     │                  leaderId == aliceUid                │
     │                  status in [completed, dissolved]    │
     │               → Get all memberIds                   │
     │               → Fetch user docs for each            │
     │                           │                         │
     │ 4. Show list:             │                         │
     │    Bob (last: 2h ago)     │                         │
     │    Charlie (last: 1d ago) │                         │
     │<───────────────────────────                         │
     │                           │                         │
     │ 5. Select Bob & Charlie   │                         │
     │ 6. Tap "Send Invites"     │                         │
     │───────────────────────────>                         │
     │                           │                         │
     │               Firestore:  │                         │
     │               7. Create invitations/{id}            │
     │                  status: "pending"                   │
     │                           │                         │
     │               8. Cloud Function                     │
     │                  onInvitationCreated →               │
     │                  FCM to Bob                         │
     │                           │────────────────────────>│
     │                           │ "Alice invited you to"  │
     │                           │ "Focus Marathon 🎯"     │
     │                           │ [Accept] [Decline]      │
     │                           │                         │
     │                           │ 9. Bob taps Accept      │
     │                           │<────────────────────────│
     │                           │                         │
     │               Firestore:  │                         │
     │               10a. Update invitation                │
     │                    status: "accepted"               │
     │               10b. Add Bob to session               │
     │                    members/ + memberIds[]            │
     │                           │                         │
     │ 11. snapshotListener on   │                         │
     │     members/ fires        │                         │
     │<───────────────────────────                         │
     │ "Bob accepted! ✅"         │                         │
```

---

## 🗄️ Data Models Swift (Firebase)

### **User Model**

```swift
import FirebaseFirestore

struct SessionUser: Codable, Identifiable {
    @DocumentID var id: String?     // Firebase UID (auto from Firestore)
    var username: String
    var appleUserId: String         // From Sign in with Apple
    var createdAt: Timestamp
    var sessionHistory: [String]    // Session IDs
    var pushToken: String?          // FCM token

    // Stats
    var totalSessionsJoined: Int = 0
    var totalSessionsCreated: Int = 0
    var currentStreak: Int = 0
}
```

### **Session Model**

```swift
struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var leaderId: String            // Firebase UID
    var leaderUsername: String       // Denormalized for display

    // Session config
    var visibility: SessionVisibility
    var inviteCode: String          // 6-digit code (e.g., "ABC123")
    var suggestedApps: [String]     // Bundle IDs suggested by leader
    var maxParticipants: Int?       // nil = unlimited

    // Status
    var status: SessionStatus
    var createdAt: Timestamp
    var startedAt: Timestamp?
    var endedAt: Timestamp?
    var scheduledStartTime: Timestamp?

    // Member IDs (pour queries Firestore rapides)
    var memberIds: [String]

    // Pas stockés en Firestore — peuplés via sub-collection
    @ExcludedFromFirestore var members: [SessionMember] = []
    @ExcludedFromFirestore var invitations: [SessionInvitation] = []

    // Computed
    var isActive: Bool {
        status == .active
    }

    var canJoin: Bool {
        if let max = maxParticipants {
            return memberIds.count < max && status != .completed && status != .dissolved
        }
        return status != .completed && status != .dissolved
    }
}

enum SessionVisibility: String, Codable {
    case publicSession = "public"
    case privateSession = "private"
}

enum SessionStatus: String, Codable {
    case lobby
    case active
    case paused
    case completed
    case dissolved
}

// Property wrapper to exclude fields from Firestore encoding
@propertyWrapper
struct ExcludedFromFirestore<T: Codable>: Codable {
    var wrappedValue: T
    init(wrappedValue: T) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws { wrappedValue = try T(from: decoder) }
    func encode(to encoder: Encoder) throws { /* skip */ }
}
```

### **Session Member (sub-collection)**

```swift
struct SessionMember: Codable, Identifiable {
    @DocumentID var id: String?     // = User UID
    var username: String
    var role: MemberRole
    var status: MemberStatus
    var joinedAt: Timestamp
    var leftAt: Timestamp?

    // Member's choices
    var selectedApps: [String]      // Bundle IDs chosen by this member
    var isReady: Bool

    // Stats for this session
    var bypassAttempts: Int = 0
    var messagesCount: Int = 0
}

enum MemberRole: String, Codable {
    case leader
    case member
}

enum MemberStatus: String, Codable {
    case invited
    case joined
    case ready
    case active
    case left
    case kicked
}
```

### **Session Invitation**

```swift
struct SessionInvitation: Codable, Identifiable {
    @DocumentID var id: String?
    let sessionId: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let toUsername: String
    var status: InvitationStatus
    var sentAt: Timestamp
    var respondedAt: Timestamp?

    // Session details for push notification
    var sessionTitle: String
    var sessionDescription: String
}

enum InvitationStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
}
```

### **Session Event (Activity Feed)**

```swift
struct SessionEvent: Codable, Identifiable {
    @DocumentID var id: String?
    let sessionId: String
    let userId: String
    let username: String
    var eventType: SessionEventType
    var timestamp: Timestamp
    var metadata: [String: String]?
}

enum SessionEventType: String, Codable {
    case sessionCreated
    case sessionStarted
    case sessionEnded
    case sessionDissolved
    case memberJoined
    case memberReady
    case memberLeft
    case memberRejoined
    case bypassAttempted
    case messageSent
    case encouragementSent
}
```

### **Session Message (Chat)**

```swift
struct SessionMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let sessionId: String
    let userId: String
    let username: String
    var content: String
    var messageType: MessageType
    var timestamp: Timestamp
}

enum MessageType: String, Codable {
    case text
    case encouragement
    case systemAlert
}
```

---

## 📱 UI Views Implementation

### **Main Navigation**

```swift
import SwiftUI
import FirebaseAuth

struct SessionsRootView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.needsUsername {
                    UsernameSetupView()
                } else {
                    SessionsHomeView()
                }
            } else {
                LoginView()
            }
        }
    }
}
```

### **Login Screen (Firebase Auth + Apple)**

```swift
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Welcome to Zenloop Sessions")
                .font(.title)
                .bold()

            Text("Team up for digital detox")
                .foregroundColor(.secondary)

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    Task {
                        await authManager.handleAppleSignIn(
                            authorization: authorization,
                            nonce: currentNonce
                        )
                    }
                case .failure(let error):
                    print("❌ Apple Sign In failed: \(error)")
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Nonce helpers (required by Firebase)

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce.")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

### **AuthManager (Firebase)**

```swift
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?

    @Published var currentUser: SessionUser?
    @Published var isAuthenticated = false
    @Published var needsUsername = false

    init() {
        // Listen for auth state changes
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.isAuthenticated = true
                    await self?.fetchOrCreateUser(firebaseUser: user)
                } else {
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
            }
        }
    }

    // MARK: - Apple Sign In → Firebase

    func handleAppleSignIn(authorization: ASAuthorization, nonce: String?) async {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8),
              let nonce = nonce else {
            print("❌ Invalid Apple credential")
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)
            print("✅ Firebase Auth success: \(result.user.uid)")
            // authListener will fire and call fetchOrCreateUser
        } catch {
            print("❌ Firebase Auth failed: \(error)")
        }
    }

    // MARK: - User Management

    private func fetchOrCreateUser(firebaseUser: User) async {
        let uid = firebaseUser.uid
        let docRef = db.collection("users").document(uid)

        do {
            let document = try await docRef.getDocument()

            if document.exists, let user = try? document.data(as: SessionUser.self) {
                self.currentUser = user
                self.needsUsername = false
            } else {
                // New user — needs to set username
                self.needsUsername = true
            }
        } catch {
            print("❌ Failed to fetch user: \(error)")
        }
    }

    func setUsername(_ username: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let user = SessionUser(
            username: username,
            appleUserId: uid,
            createdAt: Timestamp(),
            sessionHistory: [],
            pushToken: nil,
            totalSessionsJoined: 0,
            totalSessionsCreated: 0,
            currentStreak: 0
        )

        do {
            try db.collection("users").document(uid).setData(from: user)
            self.currentUser = user
            self.needsUsername = false
            print("✅ Username set: \(username)")
        } catch {
            print("❌ Failed to set username: \(error)")
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
```

### **Sessions Home**

```swift
struct SessionsHomeView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var inviteCode = ""
    @State private var showCreateSheet = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Invite code input
                HStack(spacing: 12) {
                    TextField("Enter code", text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: inviteCode) { _, new in
                            inviteCode = new.uppercased()
                        }

                    Button("Join") {
                        Task {
                            await sessionManager.joinByCode(inviteCode)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inviteCode.count != 6)
                }
                .padding()
                .background(.ultraThinMaterial)

                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("My Sessions").tag(0)
                    Text("Public").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if selectedTab == 0 {
                    MySessionsListView()
                } else {
                    PublicSessionsListView()
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Create", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateSessionView()
            }
            .onAppear {
                sessionManager.startListening()
            }
        }
    }
}
```

### **Public Sessions List**

```swift
struct PublicSessionsListView: View {
    @StateObject private var sessionManager = SessionManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sessionManager.publicSessions) { session in
                    NavigationLink(destination: SessionLobbyView(session: session)) {
                        PublicSessionCard(session: session)
                    }
                }

                if sessionManager.publicSessions.isEmpty {
                    ContentUnavailableView(
                        "No Public Sessions",
                        systemImage: "person.3",
                        description: Text("Be the first to create one!")
                    )
                }
            }
            .padding()
        }
    }
}

struct PublicSessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title)
                    .font(.headline)

                Spacer()

                SessionStatusBadge(status: session.status)
            }

            if !session.description.isEmpty {
                Text(session.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Label("by @\(session.leaderUsername)", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.orange)

                Spacer()

                Label("\(session.memberIds.count)/\(session.maxParticipants ?? 99)",
                      systemImage: "person.2.fill")
                    .font(.caption)
            }

            Button {
                Task {
                    await SessionManager.shared.joinSession(session.id!)
                }
            } label: {
                Text(session.status == .active ? "Join Now" : "Join Session")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!session.canJoin)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct SessionStatusBadge: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .bold()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }

    var statusColor: Color {
        switch status {
        case .lobby: return .orange
        case .active: return .red
        case .completed: return .green
        case .paused: return .yellow
        case .dissolved: return .gray
        }
    }

    var statusText: String {
        switch status {
        case .lobby: return "Lobby"
        case .active: return "Live"
        case .completed: return "Ended"
        case .paused: return "Paused"
        case .dissolved: return "Dissolved"
        }
    }
}
```

### **Create Session**

```swift
struct CreateSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionManager = SessionManager.shared

    @State private var title = ""
    @State private var description = ""
    @State private var visibility: SessionVisibility = .publicSession
    @State private var selectedApps: [String] = []
    @State private var maxParticipants: Int? = nil
    @State private var showAppPicker = false
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Session Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Visibility") {
                    Picker("", selection: $visibility) {
                        Text("Public").tag(SessionVisibility.publicSession)
                        Text("Private").tag(SessionVisibility.privateSession)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Apps to Block") {
                    if selectedApps.isEmpty {
                        Text("No apps selected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(selectedApps, id: \.self) { bundleId in
                            HStack {
                                Image(systemName: "app.fill")
                                Text(bundleId)
                                Spacer()
                                Button {
                                    selectedApps.removeAll { $0 == bundleId }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Button("Select Apps") {
                        showAppPicker = true
                    }
                }

                Section("Limits") {
                    Toggle("Limit participants", isOn: Binding(
                        get: { maxParticipants != nil },
                        set: { maxParticipants = $0 ? 10 : nil }
                    ))

                    if let max = maxParticipants {
                        Stepper("Max: \(max)", value: Binding(
                            get: { maxParticipants ?? 10 },
                            set: { maxParticipants = $0 }
                        ), in: 2...50)
                    }
                }
            }
            .navigationTitle("Create Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            await sessionManager.createSession(
                                title: title,
                                description: description,
                                visibility: visibility,
                                suggestedApps: selectedApps,
                                maxParticipants: maxParticipants
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showAppPicker) {
                AppPickerView(selectedApps: $selectedApps)
            }
        }
    }
}
```

### **Session Lobby (Before Start)**

```swift
struct SessionLobbyView: View {
    let session: Session
    @StateObject private var sessionManager = SessionManager.shared
    @State private var showInviteSheet = false
    @State private var members: [SessionMember] = []
    @State private var listener: ListenerRegistration?

    var isLeader: Bool {
        session.leaderId == Auth.auth().currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(session.title)
                        .font(.title)
                        .bold()

                    if isLeader {
                        Label("You're the leader", systemImage: "crown.fill")
                            .foregroundColor(.orange)
                    } else {
                        Text("Leader: @\(session.leaderUsername)")
                            .foregroundColor(.secondary)
                    }

                    SessionStatusBadge(status: session.status)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                // Invite code
                HStack {
                    VStack(alignment: .leading) {
                        Text("Invite Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.inviteCode)
                            .font(.title2)
                            .bold()
                            .monospaced()
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = session.inviteCode
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: "Join my ZenLoop session! Code: \(session.inviteCode)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                // Members list (real-time via snapshotListener)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Members (\(members.count)/\(session.maxParticipants ?? 99))")
                        .font(.headline)

                    ForEach(members) { member in
                        MemberRowView(member: member)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

                // Leader controls
                if isLeader {
                    VStack(spacing: 12) {
                        Button {
                            showInviteSheet = true
                        } label: {
                            Label("Invite from Previous Sessions", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task {
                                await sessionManager.startSession(session.id!)
                            }
                        } label: {
                            Label("Start Session", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(members.filter { $0.isReady }.isEmpty)

                        Button(role: .destructive) {
                            Task {
                                await sessionManager.dissolveSession(session.id!)
                            }
                        } label: {
                            Label("Dissolve Session", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                // Member controls
                else {
                    let currentUid = Auth.auth().currentUser?.uid
                    if let currentMember = members.first(where: { $0.id == currentUid }) {
                        if !currentMember.isReady {
                            NavigationLink {
                                SelectAppsView(session: session)
                            } label: {
                                Label("Select Apps & Get Ready", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Label("You're ready! Waiting for leader...", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Lobby")
        .sheet(isPresented: $showInviteSheet) {
            InvitePreviousMembersView(session: session)
        }
        .onAppear { startListeningToMembers() }
        .onDisappear { listener?.remove() }
    }

    private func startListeningToMembers() {
        guard let sessionId = session.id else { return }
        let db = Firestore.firestore()

        listener = db.collection("sessions").document(sessionId)
            .collection("members")
            .order(by: "joinedAt")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self.members = documents.compactMap { doc in
                    try? doc.data(as: SessionMember.self)
                }
            }
    }
}

struct MemberRowView: View {
    let member: SessionMember

    var body: some View {
        HStack {
            if member.role == .leader {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            Text("@\(member.username)")
                .font(.subheadline)

            Spacer()

            switch member.status {
            case .ready, .active:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            case .joined:
                Label("Choosing apps...", systemImage: "clock")
                    .foregroundColor(.orange)
                    .font(.caption)
            case .left:
                Label("Left", systemImage: "xmark.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}
```

### **Session Active (Live)**

```swift
struct ActiveSessionView: View {
    let session: Session
    @StateObject private var sessionManager = SessionManager.shared
    @State private var messageText = ""
    @State private var members: [SessionMember] = []
    @State private var messages: [SessionMessage] = []
    @State private var membersListener: ListenerRegistration?
    @State private var messagesListener: ListenerRegistration?

    var isLeader: Bool {
        session.leaderId == Auth.auth().currentUser?.uid
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with timer
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    Text("LIVE")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                if let startedAt = session.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(timeElapsed(from: startedAt.dateValue()))
                            .font(.title)
                            .bold()
                            .monospacedDigit()
                    }
                }

                Text(session.title)
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            // Members status
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(members) { member in
                        ActiveMemberRow(member: member, session: session)
                    }
                }
                .padding()
            }

            Divider()

            // Chat section
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 200)
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider()

                HStack {
                    TextField("Send encouragement...", text: $messageText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await sessionManager.sendMessage(
                                sessionId: session.id!,
                                content: messageText
                            )
                            messageText = ""
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }

            // Leader controls
            if isLeader {
                HStack(spacing: 12) {
                    Button {
                        Task { await sessionManager.endSession(session.id!) }
                    } label: {
                        Label("End Session", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        Task { await sessionManager.dissolveSession(session.id!) }
                    } label: {
                        Label("Dissolve", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListeningToMembers()
            startListeningToMessages()
        }
        .onDisappear {
            membersListener?.remove()
            messagesListener?.remove()
        }
    }

    private func startListeningToMembers() {
        guard let sessionId = session.id else { return }
        let db = Firestore.firestore()
        membersListener = db.collection("sessions").document(sessionId)
            .collection("members")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.members = docs.compactMap { try? $0.data(as: SessionMember.self) }
            }
    }

    private func startListeningToMessages() {
        guard let sessionId = session.id else { return }
        let db = Firestore.firestore()
        messagesListener = db.collection("sessions").document(sessionId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { try? $0.data(as: SessionMessage.self) }
            }
    }

    func timeElapsed(from startDate: Date) -> String {
        let elapsed = Date().timeIntervalSince(startDate)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct ActiveMemberRow: View {
    let member: SessionMember
    let session: Session

    var body: some View {
        HStack {
            if member.role == .leader {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
            }

            Text("@\(member.username)")
                .font(.headline)

            Spacer()

            if member.status == .left {
                HStack(spacing: 8) {
                    Label("Left", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)

                    Button {
                        // Send encouragement
                    } label: {
                        Image(systemName: "message.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Label("\(member.selectedApps.count) apps blocked",
                      systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(member.status == .left ? Color.orange.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct MessageBubble: View {
    let message: SessionMessage
    var isCurrentUser: Bool {
        message.userId == Auth.auth().currentUser?.uid
    }

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text("@\(message.username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(message.content)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
            }

            if !isCurrentUser { Spacer() }
        }
    }

    var backgroundColor: Color {
        switch message.messageType {
        case .systemAlert: return .gray.opacity(0.3)
        case .encouragement: return .orange
        case .text: return isCurrentUser ? .blue : Color(.systemGray5)
        }
    }
}
```

---

## 🔧 SessionManager Implementation (Firebase)

```swift
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    private let db = Firestore.firestore()
    private var publicSessionsListener: ListenerRegistration?
    private var mySessionsListener: ListenerRegistration?
    private var currentSessionListener: ListenerRegistration?

    @Published var publicSessions: [Session] = []
    @Published var mySessions: [Session] = []
    @Published var currentSession: Session?

    // MARK: - Real-time Listeners

    func startListening() {
        listenToPublicSessions()
        listenToMySessions()
    }

    private func listenToPublicSessions() {
        publicSessionsListener?.remove()

        publicSessionsListener = db.collection("sessions")
            .whereField("visibility", isEqualTo: "public")
            .whereField("status", in: ["lobby", "active"])
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.publicSessions = documents.compactMap { doc in
                    try? doc.data(as: Session.self)
                }
            }
    }

    private func listenToMySessions() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        mySessionsListener?.remove()

        mySessionsListener = db.collection("sessions")
            .whereField("memberIds", arrayContains: uid)
            .whereField("status", in: ["lobby", "active"])
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.mySessions = documents.compactMap { doc in
                    try? doc.data(as: Session.self)
                }
            }
    }

    // MARK: - Create Session

    func createSession(
        title: String,
        description: String,
        visibility: SessionVisibility,
        suggestedApps: [String],
        maxParticipants: Int?
    ) async {
        guard let currentUser = AuthManager.shared.currentUser,
              let uid = Auth.auth().currentUser?.uid else { return }

        let sessionRef = db.collection("sessions").document()
        let inviteCode = generateInviteCode()

        let session = Session(
            title: title,
            description: description,
            leaderId: uid,
            leaderUsername: currentUser.username,
            visibility: visibility,
            inviteCode: inviteCode,
            suggestedApps: suggestedApps,
            maxParticipants: maxParticipants,
            status: .lobby,
            createdAt: Timestamp(),
            memberIds: [uid]
        )

        let leaderMember = SessionMember(
            username: currentUser.username,
            role: .leader,
            status: .ready,
            joinedAt: Timestamp(),
            selectedApps: suggestedApps,
            isReady: true
        )

        do {
            // Batch write: session + leader member
            let batch = db.batch()

            try batch.setData(from: session, forDocument: sessionRef)

            let memberRef = sessionRef.collection("members").document(uid)
            try batch.setData(from: leaderMember, forDocument: memberRef)

            try await batch.commit()
            print("✅ Session created: \(sessionRef.documentID)")
        } catch {
            print("❌ Failed to create session: \(error)")
        }
    }

    // MARK: - Join Session

    func joinByCode(_ code: String) async {
        let query = db.collection("sessions")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)

        do {
            let snapshot = try await query.getDocuments()
            guard let doc = snapshot.documents.first,
                  let session = try? doc.data(as: Session.self),
                  let sessionId = session.id else {
                print("❌ Session not found for code: \(code)")
                return
            }

            await joinSession(sessionId)
        } catch {
            print("❌ Failed to find session: \(error)")
        }
    }

    func joinSession(_ sessionId: String) async {
        guard let currentUser = AuthManager.shared.currentUser,
              let uid = Auth.auth().currentUser?.uid else { return }

        let sessionRef = db.collection("sessions").document(sessionId)

        do {
            // Use transaction to check capacity + add member atomically
            try await db.runTransaction { transaction, errorPointer in
                let sessionDoc: DocumentSnapshot
                do {
                    sessionDoc = try transaction.getDocument(sessionRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                guard let session = try? sessionDoc.data(as: Session.self) else {
                    return nil
                }

                // Check capacity
                if let max = session.maxParticipants, session.memberIds.count >= max {
                    print("⚠️ Session is full")
                    return nil
                }

                // Check not already a member
                guard !session.memberIds.contains(uid) else {
                    print("⚠️ Already a member")
                    return nil
                }

                // Add to memberIds array
                transaction.updateData([
                    "memberIds": FieldValue.arrayUnion([uid])
                ], forDocument: sessionRef)

                // Add member document
                let memberRef = sessionRef.collection("members").document(uid)
                let member = SessionMember(
                    username: currentUser.username,
                    role: .member,
                    status: session.status == .active ? .joined : .joined,
                    joinedAt: Timestamp(),
                    selectedApps: [],
                    isReady: false
                )

                do {
                    try transaction.setData(from: member, forDocument: memberRef)
                } catch {
                    return nil
                }

                // Add event
                let eventRef = sessionRef.collection("events").document()
                transaction.setData([
                    "userId": uid,
                    "username": currentUser.username,
                    "eventType": SessionEventType.memberJoined.rawValue,
                    "timestamp": FieldValue.serverTimestamp()
                ], forDocument: eventRef)

                return nil
            }

            print("✅ Joined session: \(sessionId)")
        } catch {
            print("❌ Failed to join: \(error)")
        }
    }

    // MARK: - Start Session (Leader only)

    func startSession(_ sessionId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let sessionRef = db.collection("sessions").document(sessionId)

        do {
            try await db.runTransaction { transaction, errorPointer in
                let sessionDoc: DocumentSnapshot
                do {
                    sessionDoc = try transaction.getDocument(sessionRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                guard let session = try? sessionDoc.data(as: Session.self),
                      session.leaderId == uid,
                      session.status == .lobby else {
                    return nil
                }

                // Update session status
                transaction.updateData([
                    "status": SessionStatus.active.rawValue,
                    "startedAt": FieldValue.serverTimestamp()
                ], forDocument: sessionRef)

                return nil
            }

            // Update all ready members to active (batch)
            let membersSnapshot = try await sessionRef.collection("members")
                .whereField("isReady", isEqualTo: true)
                .getDocuments()

            let batch = db.batch()
            for doc in membersSnapshot.documents {
                batch.updateData(["status": MemberStatus.active.rawValue], forDocument: doc.reference)
            }
            try await batch.commit()

            print("✅ Session started: \(sessionId)")
            // Cloud Function handles FCM push to all members
        } catch {
            print("❌ Failed to start session: \(error)")
        }
    }

    // MARK: - End Session

    func endSession(_ sessionId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("sessions").document(sessionId).updateData([
                "status": SessionStatus.completed.rawValue,
                "endedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Session ended: \(sessionId)")
        } catch {
            print("❌ Failed to end session: \(error)")
        }
    }

    // MARK: - Dissolve Session (Leader only)

    func dissolveSession(_ sessionId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("sessions").document(sessionId).updateData([
                "status": SessionStatus.dissolved.rawValue,
                "endedAt": FieldValue.serverTimestamp()
            ])
            // Cloud Function handles: FCM to all, block removal trigger
            currentSession = nil
            print("✅ Session dissolved: \(sessionId)")
        } catch {
            print("❌ Failed to dissolve: \(error)")
        }
    }

    // MARK: - Member Actions

    func setMemberReady(_ sessionId: String, selectedApps: [String]) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let memberRef = db.collection("sessions").document(sessionId)
            .collection("members").document(uid)

        do {
            try await memberRef.updateData([
                "selectedApps": selectedApps,
                "isReady": true,
                "status": MemberStatus.ready.rawValue
            ])

            // Check if session is already active → apply blocks immediately
            let sessionDoc = try await db.collection("sessions").document(sessionId).getDocument()
            if let session = try? sessionDoc.data(as: Session.self),
               session.status == .active {
                try await memberRef.updateData(["status": MemberStatus.active.rawValue])
                GlobalShieldManager.shared.applySessionBlocks(apps: selectedApps)
            }

            print("✅ Member ready with \(selectedApps.count) apps")
        } catch {
            print("❌ Failed to set ready: \(error)")
        }
    }

    func leaveSession(_ sessionId: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let username = AuthManager.shared.currentUser?.username else { return }

        let sessionRef = db.collection("sessions").document(sessionId)
        let memberRef = sessionRef.collection("members").document(uid)

        do {
            let batch = db.batch()

            // Update member status
            batch.updateData([
                "status": MemberStatus.left.rawValue,
                "leftAt": FieldValue.serverTimestamp()
            ], forDocument: memberRef)

            // Add system message
            let msgRef = sessionRef.collection("messages").document()
            batch.setData([
                "userId": uid,
                "username": username,
                "content": "\(username) left the session 💔",
                "messageType": MessageType.systemAlert.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: msgRef)

            // Add event
            let eventRef = sessionRef.collection("events").document()
            batch.setData([
                "userId": uid,
                "username": username,
                "eventType": SessionEventType.memberLeft.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ], forDocument: eventRef)

            try await batch.commit()

            // Remove blocks locally
            GlobalShieldManager.shared.removeSessionBlocks()
            currentSession = nil

            print("✅ Left session: \(sessionId)")
            // Cloud Function handles FCM to remaining members
        } catch {
            print("❌ Failed to leave: \(error)")
        }
    }

    // MARK: - Messages

    func sendMessage(sessionId: String, content: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let username = AuthManager.shared.currentUser?.username else { return }

        let msgRef = db.collection("sessions").document(sessionId)
            .collection("messages").document()

        do {
            try await msgRef.setData([
                "userId": uid,
                "username": username,
                "content": content,
                "messageType": MessageType.text.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }

    func sendEncouragement(sessionId: String, toUserId: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let username = AuthManager.shared.currentUser?.username else { return }

        let msgRef = db.collection("sessions").document(sessionId)
            .collection("messages").document()

        do {
            try await msgRef.setData([
                "userId": uid,
                "username": username,
                "content": "💪 Stay strong! You got this!",
                "messageType": MessageType.encouragement.rawValue,
                "timestamp": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to send encouragement: \(error)")
        }
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    deinit {
        publicSessionsListener?.remove()
        mySessionsListener?.remove()
        currentSessionListener?.remove()
    }
}
```

---

## 🔥 Cloud Functions (Node.js)

```javascript
// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ── Helper: Send FCM to user ──
async function sendPushToUser(userId, title, body, data = {}) {
  const userDoc = await db.collection("users").doc(userId).get();
  const pushToken = userDoc.data()?.pushToken;

  if (!pushToken) return;

  try {
    await messaging.send({
      token: pushToken,
      notification: { title, body },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
  } catch (error) {
    console.error(`Failed to send push to ${userId}:`, error);
  }
}

// ── Helper: Send FCM to all session members ──
async function notifyAllMembers(sessionId, excludeUserId, title, body, data = {}) {
  const membersSnap = await db
    .collection("sessions")
    .doc(sessionId)
    .collection("members")
    .where("status", "!=", "left")
    .get();

  const promises = membersSnap.docs
    .filter((doc) => doc.id !== excludeUserId)
    .map((doc) => sendPushToUser(doc.id, title, body, { sessionId, ...data }));

  await Promise.all(promises);
}

// ── 1. Session started → Notify all members ──
exports.onSessionStatusChanged = functions.firestore
  .document("sessions/{sessionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const sessionId = context.params.sessionId;

    // Session started
    if (before.status === "lobby" && after.status === "active") {
      await notifyAllMembers(
        sessionId,
        after.leaderId,
        "🎯 Session Started!",
        `${after.title} is now live. Applying blocks...`,
        { type: "session_started" }
      );
    }

    // Session dissolved
    if (after.status === "dissolved" && before.status !== "dissolved") {
      await notifyAllMembers(
        sessionId,
        after.leaderId,
        "🗑️ Session Dissolved",
        `${after.title} has been dissolved. All blocks removed.`,
        { type: "session_dissolved" }
      );
    }

    // Session completed
    if (after.status === "completed" && before.status !== "completed") {
      await notifyAllMembers(
        sessionId,
        after.leaderId,
        "✅ Session Complete!",
        `${after.title} has ended. Great job!`,
        { type: "session_completed" }
      );
    }
  });

// ── 2. Member joined → Notify leader ──
exports.onMemberJoined = functions.firestore
  .document("sessions/{sessionId}/members/{memberId}")
  .onCreate(async (snap, context) => {
    const member = snap.data();
    const sessionId = context.params.sessionId;

    const sessionDoc = await db.collection("sessions").doc(sessionId).get();
    const session = sessionDoc.data();

    if (!session) return;

    await sendPushToUser(
      session.leaderId,
      "New Member!",
      `${member.username} joined your session`,
      { sessionId, type: "member_joined" }
    );
  });

// ── 3. Member left → Notify all ──
exports.onMemberStatusChanged = functions.firestore
  .document("sessions/{sessionId}/members/{memberId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const sessionId = context.params.sessionId;
    const memberId = context.params.memberId;

    // Member left
    if (before.status !== "left" && after.status === "left") {
      await notifyAllMembers(
        sessionId,
        memberId,
        "⚠️ Member Left",
        `${after.username} left the session`,
        { type: "member_left" }
      );
    }

    // Member became ready
    if (!before.isReady && after.isReady) {
      const sessionDoc = await db.collection("sessions").doc(sessionId).get();
      const session = sessionDoc.data();
      if (session) {
        await sendPushToUser(
          session.leaderId,
          "Member Ready!",
          `${after.username} is ready ✅`,
          { sessionId, type: "member_ready" }
        );
      }
    }
  });

// ── 4. Invitation created → Notify target user ──
exports.onInvitationCreated = functions.firestore
  .document("invitations/{invitationId}")
  .onCreate(async (snap, context) => {
    const invitation = snap.data();

    await sendPushToUser(
      invitation.toUserId,
      `${invitation.fromUsername} invited you!`,
      `Join "${invitation.sessionTitle}"`,
      {
        type: "invitation",
        sessionId: invitation.sessionId,
        invitationId: context.params.invitationId,
      }
    );
  });

// ── 5. Cleanup: Auto-expire old sessions ──
exports.cleanupOldSessions = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 48 * 60 * 60 * 1000) // 48 hours ago
    );

    const oldSessions = await db
      .collection("sessions")
      .where("status", "in", ["lobby"])
      .where("createdAt", "<", cutoff)
      .get();

    const batch = db.batch();
    oldSessions.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: "dissolved",
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    console.log(`Cleaned up ${oldSessions.size} old sessions`);
  });
```

---

## 🔔 Push Notification Manager (FCM)

```swift
import FirebaseMessaging
import FirebaseAuth
import UserNotifications

class PushNotificationManager: NSObject, ObservableObject,
    UNUserNotificationCenterDelegate, MessagingDelegate {

    static let shared = PushNotificationManager()

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken,
              let uid = Auth.auth().currentUser?.uid else { return }

        // Store FCM token in user document
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData([
            "pushToken": token
        ])

        print("📱 FCM Token stored: \(token.prefix(20))...")
    }

    // MARK: - Handle notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Route to appropriate screen based on notification type
        if let type = userInfo["type"] as? String,
           let sessionId = userInfo["sessionId"] as? String {
            handleNotificationTap(type: type, sessionId: sessionId)
        }

        completionHandler()
    }

    private func handleNotificationTap(type: String, sessionId: String) {
        // Navigate to session based on notification type
        switch type {
        case "session_started", "session_dissolved", "session_completed":
            // Navigate to session view
            NotificationCenter.default.post(
                name: .navigateToSession,
                object: nil,
                userInfo: ["sessionId": sessionId]
            )

        case "invitation":
            // Navigate to invitations
            NotificationCenter.default.post(
                name: .navigateToInvitations,
                object: nil
            )

        case "member_left":
            // Navigate to active session
            NotificationCenter.default.post(
                name: .navigateToSession,
                object: nil,
                userInfo: ["sessionId": sessionId]
            )

        default:
            break
        }
    }
}

extension Notification.Name {
    static let navigateToSession = Notification.Name("navigateToSession")
    static let navigateToInvitations = Notification.Name("navigateToInvitations")
}
```

---

## 📦 Firebase Setup (AppDelegate / App)

```swift
import SwiftUI
import FirebaseCore

@main
struct ZenLoopApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            SessionsRootView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Enable Firestore offline persistence (enabled by default, but explicit)
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        // Setup push notifications
        PushNotificationManager.shared.setup()

        return true
    }

    // Required for FCM
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
```

---

## 🗂️ Fichiers à Créer / Modifier

```
zenloop/
├─ GoogleService-Info.plist          (NEW - Firebase config)
│
├─ Models/
│  ├─ SessionModels.swift            (NEW)
│  │  └─ SessionUser, Session, SessionMember,
│  │     SessionInvitation, SessionEvent, SessionMessage
│  │     + Tous les enums
│  │
│  ├─ CommunityModels.swift          (EXISTING - keep)
│  └─ SharedModels.swift             (EXISTING - keep)
│
├─ Managers/
│  ├─ SessionManager.swift           (NEW)
│  │  └─ Firestore CRUD, real-time listeners,
│  │     transactions, batch writes
│  │
│  ├─ AuthManager.swift              (NEW)
│  │  └─ Firebase Auth + Sign in with Apple
│  │     nonce generation, user creation
│  │
│  ├─ PushNotificationManager.swift  (NEW)
│  │  └─ FCM token, notification handling,
│  │     deep link routing
│  │
│  ├─ DataManager.swift              (MODIFY)
│  │  └─ Add Firebase UID storage
│  │
│  └─ GlobalShieldManager.swift      (MODIFY)
│     └─ Add applySessionBlocks(), removeSessionBlocks()
│
├─ Views/
│  ├─ Sessions/                      (NEW FOLDER)
│  │  ├─ SessionsRootView.swift
│  │  ├─ LoginView.swift
│  │  ├─ UsernameSetupView.swift
│  │  ├─ SessionsHomeView.swift
│  │  ├─ PublicSessionsListView.swift
│  │  ├─ MySessionsListView.swift
│  │  ├─ CreateSessionView.swift
│  │  ├─ SessionLobbyView.swift
│  │  ├─ ActiveSessionView.swift
│  │  ├─ SelectAppsView.swift
│  │  └─ InvitePreviousMembersView.swift
│  │
│  ├─ Components/                    (EXISTING)
│  │  ├─ SessionCard.swift           (NEW)
│  │  ├─ SessionStatusBadge.swift    (NEW)
│  │  ├─ MemberRowView.swift         (NEW)
│  │  ├─ ActiveMemberRow.swift       (NEW)
│  │  └─ MessageBubble.swift         (NEW)
│  │
│  └─ HomeView.swift                 (MODIFY)
│     └─ Add navigation to Sessions
│
├─ zenloop.entitlements              (MODIFY)
│  └─ Add: Push Notifications, Sign in with Apple,
│     Background Modes (remote-notification)
│
├─ Podfile OR Package.swift          (MODIFY)
│  └─ Add: firebase-ios-sdk
│     (FirebaseAuth, FirebaseFirestore,
│      FirebaseMessaging, FirebaseFunctions)
│
└─ functions/                        (NEW - Cloud Functions)
   ├─ package.json
   ├─ index.js
   └─ .eslintrc.js
```

---

## 📦 Dependencies (SPM)

```swift
// Package.swift ou via Xcode > Add Package
// URL: https://github.com/firebase/firebase-ios-sdk

// Products à importer:
// - FirebaseAuth
// - FirebaseFirestore
// - FirebaseMessaging
// - FirebaseFunctions (optionnel)

// Aussi nécessaire pour Sign in with Apple nonce:
// - CryptoKit (built-in Apple framework)
```

---

## 📅 Timeline d'Implémentation

### **PHASE 1: FOUNDATION (Semaine 1)**

**Day 1-2: Firebase Setup**
- Firebase project creation + GoogleService-Info.plist
- SPM: FirebaseAuth, FirebaseFirestore, FirebaseMessaging
- Entitlements: Push Notifications, Sign in with Apple
- AppDelegate: FirebaseApp.configure()
- Firestore security rules (v1)

**Day 3-4: Auth + User**
- AuthManager avec Firebase Auth + Apple Sign In
- Nonce generation (CryptoKit)
- User creation dans Firestore
- LoginView + UsernameSetupView

**Day 5: Core SessionManager**
- Firestore CRUD (create, join, read)
- Real-time listeners (snapshotListener)
- SessionsHomeView + PublicSessionsListView

### **PHASE 2: SESSIONS FLOW (Semaine 2)**

**Day 1-2: Lobby & Member Management**
- SessionLobbyView (leader + member views)
- Members sub-collection listeners
- Ready/not ready states
- App selection for members (SelectAppsView)

**Day 3-4: Session Lifecycle**
- Start session (Firestore transaction)
- Late join (apply blocks immediately)
- Leave session (batch write)
- Dissolve session
- End session

**Day 5: Push Notifications**
- PushNotificationManager + FCM setup
- Cloud Functions deployment
- onSessionStarted, onMemberJoined, onMemberLeft
- Deep link handling (navigate to session)

### **PHASE 3: ADVANCED FEATURES (Semaine 3)**

**Day 1-2: Invitations**
- Invite from previous sessions
- Invitations collection
- Accept/decline flow
- Cloud Function: onInvitationCreated

**Day 3-4: Chat & Encouragement**
- Messages sub-collection
- Real-time chat listener
- System alerts (member left, etc.)
- Quick encouragement messages

**Day 5: Polish**
- Loading states + error handling
- Offline support testing (Firestore cache)
- ShareLink for invite codes
- Badge management

### **PHASE 4: TESTING & RELEASE (Semaine 4)**

- Multi-device testing
- Push notification testing (TestFlight)
- Edge cases (network loss, concurrent joins, etc.)
- Security rules testing
- Performance: Firestore indexes
- App Store submission

---

## 🔑 Firestore Indexes Requis

```
// firebase.json ou via Firebase Console

// Composite indexes:
1. sessions: visibility ASC, status ASC, createdAt DESC
2. sessions: memberIds ARRAY, status ASC, createdAt DESC
3. invitations: toUserId ASC, status ASC, sentAt DESC
4. sessions/{id}/messages: timestamp ASC
5. sessions/{id}/members: joinedAt ASC
```

---

## 💰 Coûts & Ressources

### **Firebase (Spark Plan = Gratuit)**
- Auth: Illimité (Sign in with Apple)
- Firestore: 1 GiB storage, 50K reads/day, 20K writes/day
- FCM: Illimité
- Cloud Functions: 2M invocations/month (Blaze plan requis)

### **Firebase (Blaze Plan = Pay-as-you-go)**
- Firestore: $0.06/100K reads, $0.18/100K writes
- Cloud Functions: $0.40/million invocations
- Storage: $0.18/GiB/month

### **Estimation**
- Phase MVP (< 1000 users): **0€** (Spark plan suffit sauf Cloud Functions)
- Scale (10K users): **~$5-10/mois**
- Scale (100K users): **~$30-50/mois**

> **Note:** Cloud Functions nécessite le Blaze plan (pay-as-you-go). Possibilité de commencer sans Cloud Functions en envoyant les notifications directement depuis le client via Firestore triggers, puis migrer vers Cloud Functions plus tard.

---

## 🎯 Résumé Exécutif

### **Stack Technique**
- **Auth:** Firebase Auth + Sign in with Apple
- **Database:** Cloud Firestore (NoSQL, real-time, offline)
- **Push:** Firebase Cloud Messaging (FCM)
- **Server Logic:** Cloud Functions (Node.js)
- **Client:** SwiftUI + Firebase iOS SDK

### **Avantages Firebase vs CloudKit**
1. **Real-time natif** — snapshotListener = updates instantanés sans polling
2. **Offline built-in** — Firestore cache automatique, sync on reconnect
3. **Cloud Functions** — logique serveur pour notifications, cleanup, validation
4. **Scalabilité** — pricing prévisible, pas de limites Apple
5. **Cross-platform ready** — même backend pour Android futur
6. **Console admin** — monitoring, analytics, debugging en temps réel
7. **Security Rules** — granulaires, testables, versionnables

### **Flow Complet Implémenté**

1. ✅ Login obligatoire (Firebase Auth + Sign in with Apple)
2. ✅ Page d'accueil avec sessions publiques + code d'invitation
3. ✅ Création de session (public/privé, leader)
4. ✅ Lobby avec statuts membres real-time (snapshotListener)
5. ✅ Late join (rejoindre session en cours = blocage immédiat)
6. ✅ Leader lance → blocage auto pour tous les ready
7. ✅ Notifications push FCM pour tous les événements
8. ✅ Dissolution par leader → déblocage de tous
9. ✅ Membre quitte → notification + encouragement possible
10. ✅ Chat de groupe en temps réel
11. ✅ Invitations de membres d'anciennes sessions

### **Go-to-Market**

"L'app de digital detox qu'on fait en équipe" 🤝

---

## 🚀 Ready to Start

Prochaines étapes:
1. Créer le projet Firebase + ajouter GoogleService-Info.plist
2. Ajouter firebase-ios-sdk via SPM
3. Configurer les entitlements (Push, Sign in with Apple)
4. Implémenter AuthManager (Firebase Auth + Apple)
5. Créer SessionModels + SessionManager (Firestore)
6. Builder les UI views (Login → Home → Create → Lobby → Active)
7. Déployer Cloud Functions
8. Intégrer FCM + PushNotificationManager
9. Testing multi-devices via TestFlight

**Temps estimé: 3-4 semaines pour MVP complet**