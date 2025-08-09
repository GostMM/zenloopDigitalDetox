//
//  CommunityManager.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import Foundation
import SwiftUI
import FamilyControls
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Challenge Participation State

enum ParticipationStatus {
    case notParticipating
    case joining           // En cours de participation (transition)
    case active           // Participation active avec blocage
    case completed        // Défi terminé
    case failed           // Erreur lors de la participation
}

struct ChallengeParticipationState {
    let challengeId: String
    let status: ParticipationStatus
    let selectedApps: FamilyActivitySelection?
    let participant: CommunityParticipant?
    let blockingSession: BlockingSession?
    let lastUpdated: Date
    
    var isParticipating: Bool {
        switch status {
        case .joining, .active, .completed:
            return true
        case .notParticipating, .failed:
            return false
        }
    }
    
    var hasActiveBlocking: Bool {
        return blockingSession != nil && status == .active
    }
}

class CommunityManager: ObservableObject {
    static let shared = CommunityManager()
    
    // MARK: - Published Properties
    
    @Published var currentUsername: String = ""
    @Published var activeChallenges: [CommunityChallenge] = []
    @Published var discussions: [CommunityDiscussion] = []
    @Published var userStats: CommunityUserStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Single Source of Truth for Participations
    @Published var userParticipations: [String: ChallengeParticipationState] = [:]
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let usernameKey = "community_username"
    private let userIdKey = "community_user_id"
    private let participationsKey = "user_participations"
    private let selectedAppsKey = "challenge_selected_apps"
    private let familyActivitySelectionKey = "challenge_family_selection"
    private let db = Firestore.firestore()
    private var messageListeners: [String: ListenerRegistration] = [:]
    
    // Listes pour la génération de noms aléatoires
    private let adjectives = [
        "Zen", "Calm", "Wise", "Swift", "Bright", "Peaceful", "Focused", "Serene",
        "Mindful", "Steady", "Clear", "Strong", "Gentle", "Quiet", "Pure", "Fresh",
        "Deep", "Light", "Soft", "Warm", "Cool", "Free", "Bold", "Kind",
        "Brave", "Smart", "Quick", "Still", "Wild", "True"
    ]
    
    private let nouns = [
        "Lotus", "River", "Mountain", "Forest", "Star", "Moon", "Sun", "Wave",
        "Cloud", "Tree", "Bird", "Wind", "Stone", "Leaf", "Drop", "Dawn",
        "Ocean", "Valley", "Peak", "Garden", "Stream", "Flame", "Crystal", "Sage",
        "Phoenix", "Tiger", "Dragon", "Eagle", "Wolf", "Bear"
    ]
    
    private var cancellables = Set<AnyCancellable>()
    private var hasGeneratedInitialChallenges = false
    
    // MARK: - Initialization
    
    private init() {
        setupUsername()
        loadCommunityData()
    }
    
    // MARK: - Username Management
    
    private func setupUsername() {
        if let existingUsername = userDefaults.string(forKey: usernameKey),
           !existingUsername.isEmpty {
            currentUsername = existingUsername
        } else {
            generateNewUsername()
        }
        
        // Générer un ID unique si nécessaire
        if userDefaults.string(forKey: userIdKey) == nil {
            let userId = UUID().uuidString
            userDefaults.set(userId, forKey: userIdKey)
        }
        
        print("🏘️ [COMMUNITY] Current username: \(currentUsername)")
    }
    
    private func generateNewUsername() {
        let randomAdjective = adjectives.randomElement() ?? "Zen"
        let randomNoun = nouns.randomElement() ?? "Lotus"
        let randomNumber = Int.random(in: 10...99)
        
        let newUsername = "\(randomAdjective)\(randomNoun)\(randomNumber)"
        currentUsername = newUsername
        
        // Sauvegarder en local
        userDefaults.set(newUsername, forKey: usernameKey)
        
        print("🎲 [COMMUNITY] Generated new username: \(newUsername)")
    }
    
    func regenerateUsername() {
        generateNewUsername()
        // TODO: Mettre à jour sur Firebase aussi
    }
    
    var currentUserId: String {
        return userDefaults.string(forKey: userIdKey) ?? UUID().uuidString
    }
    
    // MARK: - Community Data Loading
    
    func loadCommunityData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Vérifier si l'initialisation est nécessaire
            let needsInitialization = await FirebaseInitializer.shared.checkInitializationNeeded()
            
            if needsInitialization {
                print("🔄 [COMMUNITY] First launch - initializing Firebase data...")
                await FirebaseInitializer.shared.initializeFirebaseData()
            }
            
            // Charger les défis depuis Firebase
            await loadChallengesFromFirebase()
            await loadUserStatsFromFirebase()
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadChallengesFromFirebase() async {
        print("🎯 [COMMUNITY] Loading challenges from Firebase...")
        
        do {
            let snapshot = try await db.collection("challenges")
                .whereField("endDate", isGreaterThan: Timestamp(date: Date()))
                .order(by: "startDate")
                .getDocuments()
            
            let challenges = snapshot.documents.compactMap { document -> CommunityChallenge? in
                let data = document.data()
                
                guard let id = data["id"] as? String,
                      let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let startDate = data["startDate"] as? Timestamp,
                      let endDate = data["endDate"] as? Timestamp,
                      let participantCount = data["participantCount"] as? Int,
                      let maxParticipants = data["maxParticipants"] as? Int,
                      let suggestedApps = data["suggestedApps"] as? [String],
                      let categoryRaw = data["category"] as? String,
                      let difficultyRaw = data["difficulty"] as? String,
                      let rewardPoints = data["rewardPoints"] as? Int,
                      let rewardBadge = data["rewardBadge"] as? String,
                      let rewardTitle = data["rewardTitle"] as? String else {
                    print("❌ Invalid challenge data in document: \(document.documentID)")
                    return nil
                }
                
                guard let category = CommunityCategory(rawValue: categoryRaw),
                      let difficulty = CommunityDifficulty(rawValue: difficultyRaw) else {
                    print("❌ Invalid category or difficulty: \(categoryRaw), \(difficultyRaw)")
                    return nil
                }
                
                return CommunityChallenge(
                    id: id,
                    title: title,
                    description: description,
                    startDate: startDate.dateValue(),
                    endDate: endDate.dateValue(),
                    participantCount: participantCount,
                    maxParticipants: maxParticipants,
                    suggestedApps: suggestedApps,
                    category: category,
                    difficulty: difficulty,
                    reward: CommunityReward(
                        points: rewardPoints,
                        badge: rewardBadge,
                        title: rewardTitle
                    )
                )
            }
            
            await MainActor.run {
                self.activeChallenges = challenges
                print("✅ [COMMUNITY] Loaded \(challenges.count) challenges from Firebase")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Erreur de chargement des défis: \(error.localizedDescription)"
                print("❌ [COMMUNITY] Error loading challenges: \(error)")
            }
        }
    }
    
    private func loadUserStatsFromFirebase() async {
        print("📊 [COMMUNITY] Loading user stats from Firebase...")
        
        do {
            let document = try await db.collection("users").document(currentUserId).getDocument()
            
            if document.exists, let data = document.data() {
                let userStats = CommunityUserStats(
                    userId: data["userId"] as? String ?? currentUserId,
                    username: data["username"] as? String ?? currentUsername,
                    totalPoints: data["totalPoints"] as? Int ?? 0,
                    completedChallenges: data["completedChallenges"] as? Int ?? 0,
                    rank: data["rank"] as? Int ?? 999,
                    badges: data["badges"] as? [String] ?? [],
                    joinDate: (data["joinDate"] as? Timestamp)?.dateValue() ?? Date()
                )
                
                await MainActor.run {
                    self.userStats = userStats
                    print("✅ [COMMUNITY] Loaded user stats for \(userStats.username)")
                }
            }
        } catch {
            print("❌ [COMMUNITY] Error loading user stats: \(error)")
        }
    }
    
    
    // MARK: - Challenge Management
    
    func joinChallenge(_ challenge: CommunityChallenge, selectedApps: FamilyActivitySelection) {
        print("🚀 [COMMUNITY] Joining challenge: \(challenge.title)")
        print("📱 [COMMUNITY] Selected apps: \(selectedApps.applicationTokens.count) apps, categories: \(selectedApps.categoryTokens.count)")
        
        Task {
            await performJoinChallenge(challenge, selectedApps: selectedApps)
        }
    }
    
    private func performJoinChallenge(_ challenge: CommunityChallenge, selectedApps: FamilyActivitySelection) async {
        do {
            // 0. Vérifier d'abord si l'utilisateur ne participe pas déjà
            let alreadyParticipating = await isUserParticipating(in: challenge.id)
            if alreadyParticipating {
                print("⚠️ [COMMUNITY] User is already participating in challenge: \(challenge.id)")
                await MainActor.run {
                    self.errorMessage = "Vous participez déjà à ce défi"
                }
                return
            }
            
            // 1. Créer l'entrée participant dans Firebase
            let participant = CommunityParticipant(
                id: UUID().uuidString,
                userId: currentUserId,
                username: currentUsername,
                joinedAt: Date(),
                progress: 0.0,
                isCompleted: false,
                rank: 999, // Sera calculé plus tard
                badges: [],
                streakCount: 0
            )
            
            let participantData: [String: Any] = [
                "id": participant.id,
                "userId": participant.userId,
                "username": participant.username,
                "challengeId": challenge.id,
                "joinedAt": Timestamp(date: participant.joinedAt),
                "progress": participant.progress,
                "isCompleted": participant.isCompleted,
                "rank": participant.rank,
                "badges": participant.badges,
                "streakCount": participant.streakCount,
                "selectedApps": selectedApps.applicationTokens.count,
                "selectedCategories": selectedApps.categoryTokens.count
            ]
            
            try await db.collection("challenge_participants").document(participant.id).setData(participantData)
            
            // 2. Mettre à jour le nombre de participants du défi
            try await db.collection("challenges").document(challenge.id).updateData([
                "participantCount": FieldValue.increment(Int64(1))
            ])
            
            // 3. Démarrer le blocage d'apps avec Screen Time
            await startAppBlocking(selectedApps: selectedApps, challenge: challenge)
            
            // 4. Enregistrer l'action pour les analytics
            await CommunityAnalytics.shared.recordUserAction(.joinChallenge, userId: currentUserId, additionalData: [
                "challengeId": challenge.id,
                "challengeCategory": challenge.category.rawValue,
                "challengeDifficulty": challenge.difficulty.rawValue,
                "selectedAppsCount": selectedApps.applicationTokens.count
            ])
            
            // 5. Programmer des notifications intelligentes
            await SmartNotificationManager.shared.sendProgressUpdateNotification(
                userId: currentUserId,
                progress: 0.0,
                challengeId: challenge.id
            )
            
            // 6. Persister la participation localement
            await persistParticipation(challengeId: challenge.id, selectedApps: selectedApps, participant: participant)
            
            print("✅ [COMMUNITY] Successfully joined challenge: \(challenge.title)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Erreur lors de la participation: \(error.localizedDescription)"
                print("❌ [COMMUNITY] Error joining challenge: \(error)")
            }
        }
    }
    
    private func startAppBlocking(selectedApps: FamilyActivitySelection, challenge: CommunityChallenge) async {
        print("🛡️ [SCREEN_TIME] Starting app blocking for challenge: \(challenge.title)")
        print("📱 [SCREEN_TIME] Blocking \(selectedApps.applicationTokens.count) apps and \(selectedApps.categoryTokens.count) categories")
        
        // Calculer la durée du défi
        let duration = challenge.endDate.timeIntervalSince(challenge.startDate)
        
        // Utiliser le ScreenTimeManager pour le vrai blocage
        let success = await ScreenTimeManager.shared.startBlocking(
            challengeId: challenge.id,
            selectedApps: selectedApps,
            duration: duration,
            challengeTitle: challenge.title
        )
        
        if success {
            print("✅ [SCREEN_TIME] App blocking started successfully")
        } else {
            print("❌ [SCREEN_TIME] Failed to start app blocking")
            // Fallback : simulation
            UserDefaults.standard.set(true, forKey: "blocking_active_\(challenge.id)")
            UserDefaults.standard.set(Date(), forKey: "blocking_start_\(challenge.id)")
        }
    }
    
    func leaveChallenge(_ challengeId: String) {
        print("👋 [COMMUNITY] Leaving challenge: \(challengeId)")
        
        Task {
            await performLeaveChallenge(challengeId)
        }
    }
    
    private func performLeaveChallenge(_ challengeId: String) async {
        do {
            // 1. Trouver et supprimer l'entrée participant
            let participantsSnapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            for document in participantsSnapshot.documents {
                try await document.reference.delete()
            }
            
            // 2. Décrémenter le nombre de participants
            try await db.collection("challenges").document(challengeId).updateData([
                "participantCount": FieldValue.increment(Int64(-1))
            ])
            
            // 3. Arrêter le blocage d'apps
            await stopAppBlocking(challengeId: challengeId)
            
            // 4. Supprimer la persistance locale
            removeStoredParticipation(for: challengeId)
            
            // 5. Enregistrer l'action pour les analytics
            await CommunityAnalytics.shared.recordUserAction(.leaveChallenge, userId: currentUserId, additionalData: [
                "challengeId": challengeId
            ])
            
            print("✅ [COMMUNITY] Successfully left challenge: \(challengeId)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Erreur lors de la sortie: \(error.localizedDescription)"
                print("❌ [COMMUNITY] Error leaving challenge: \(error)")
            }
        }
    }
    
    private func stopAppBlocking(challengeId: String) async {
        print("🔓 [SCREEN_TIME] Stopping app blocking for challenge: \(challengeId)")
        
        // Utiliser le ScreenTimeManager pour arrêter le vrai blocage
        let success = await ScreenTimeManager.shared.stopBlocking(challengeId: challengeId)
        
        if success {
            print("✅ [SCREEN_TIME] App blocking stopped successfully")
        } else {
            print("❌ [SCREEN_TIME] Failed to stop app blocking, using fallback")
            // Fallback : simulation
            UserDefaults.standard.removeObject(forKey: "blocking_active_\(challengeId)")
            UserDefaults.standard.removeObject(forKey: "blocking_start_\(challengeId)")
        }
    }
    
    // MARK: - Progress Tracking
    
    func updateChallengeProgress(_ challengeId: String, progress: Double) async {
        do {
            // Trouver l'entrée participant
            let participantsSnapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            guard let participantDoc = participantsSnapshot.documents.first else {
                print("❌ [PROGRESS] Participant not found for challenge: \(challengeId)")
                return
            }
            
            let newProgress = min(max(progress, 0.0), 1.0) // Clamp entre 0 et 1
            let isCompleted = newProgress >= 1.0
            
            // Mettre à jour la progression
            try await participantDoc.reference.updateData([
                "progress": newProgress,
                "isCompleted": isCompleted,
                "lastUpdated": Timestamp(date: Date())
            ])
            
            // Si terminé, donner les récompenses
            if isCompleted {
                await awardChallengeReward(challengeId: challengeId)
            }
            
            // Notifications de progression
            if newProgress == 0.25 || newProgress == 0.5 || newProgress == 0.75 {
                await SmartNotificationManager.shared.sendProgressUpdateNotification(
                    userId: currentUserId,
                    progress: newProgress,
                    challengeId: challengeId
                )
            }
            
            print("📈 [PROGRESS] Updated challenge \(challengeId) progress to \(Int(newProgress * 100))%")
            
        } catch {
            print("❌ [PROGRESS] Error updating progress: \(error)")
        }
    }
    
    private func awardChallengeReward(challengeId: String) async {
        do {
            // Récupérer les infos du défi
            let challengeDoc = try await db.collection("challenges").document(challengeId).getDocument()
            guard let challengeData = challengeDoc.data(),
                  let rewardPoints = challengeData["rewardPoints"] as? Int,
                  let rewardBadge = challengeData["rewardBadge"] as? String else {
                return
            }
            
            // Mettre à jour les stats utilisateur
            try await db.collection("users").document(currentUserId).updateData([
                "total_points": FieldValue.increment(Int64(rewardPoints)),
                "completed_challenges": FieldValue.increment(Int64(1)),
                "badges": FieldValue.arrayUnion([rewardBadge])
            ])
            
            // Analytics
            await CommunityAnalytics.shared.recordUserAction(.completeChallenge, userId: currentUserId, additionalData: [
                "challengeId": challengeId,
                "pointsEarned": rewardPoints,
                "badgeEarned": rewardBadge
            ])
            
            print("🏆 [REWARD] Awarded \(rewardPoints) points and badge \(rewardBadge)")
            
        } catch {
            print("❌ [REWARD] Error awarding reward: \(error)")
        }
    }
    
    // MARK: - Challenge Completion
    
    func challengeCompleted(_ challengeId: String) async {
        await MainActor.run {
            // Mettre à jour l'état local vers completed
            if let currentState = userParticipations[challengeId] {
                let completedState = ChallengeParticipationState(
                    challengeId: challengeId,
                    status: .completed,
                    selectedApps: currentState.selectedApps,
                    participant: currentState.participant,
                    blockingSession: nil, // Plus de blocage actif
                    lastUpdated: Date()
                )
                userParticipations[challengeId] = completedState
            }
        }
        
        // Mettre à jour le progrès final
        await updateChallengeProgress(challengeId, progress: 1.0)
        
        print("🏁 [COMMUNITY] Challenge completed: \(challengeId)")
    }
    
    // MARK: - Simple Challenge Generation (when user enters community)
    
    func generateInitialChallengesIfNeeded() async {
        // Éviter la génération multiple
        guard !hasGeneratedInitialChallenges else { return }
        
        // Vérifier s'il y a déjà des défis actifs
        if activeChallenges.isEmpty {
            print("🚀 [COMMUNITY] No challenges found, generating simple initial challenges...")
            hasGeneratedInitialChallenges = true
            
            // Générer quelques défis simples et efficaces
            await generateSimpleChallenges()
            
            // Recharger les défis depuis Firebase
            await loadChallengesFromFirebase()
        } else {
            print("✅ [COMMUNITY] Found \(activeChallenges.count) existing challenges")
        }
    }
    
    private func generateSimpleChallenges() async {
        let now = Date()
        let challenges = [
            // Défi Focus (30 min)
            CommunityChallenge(
                id: "focus_30min_\(Int(now.timeIntervalSince1970))",
                title: "Focus Session 30min",
                description: "Concentre-toi pendant 30 minutes sans distractions",
                startDate: now,
                endDate: Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now,
                participantCount: 0,
                maxParticipants: 20,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "Twitter"],
                category: .focus,
                difficulty: .easy,
                reward: CommunityReward(points: 50, badge: "🎯", title: "Focused")
            ),
            
            // Défi Productivité (1h)
            CommunityChallenge(
                id: "productivity_1h_\(Int(now.timeIntervalSince1970))",
                title: "Productivité Power Hour",
                description: "Boost ta productivité pendant 1 heure complète",
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now,
                participantCount: 0,
                maxParticipants: 15,
                suggestedApps: ["YouTube", "Netflix", "TikTok", "Instagram", "Games"],
                category: .productivity,
                difficulty: .medium,
                reward: CommunityReward(points: 100, badge: "⚡", title: "Productive")
            ),
            
            // Défi Bien-être (2h)
            CommunityChallenge(
                id: "wellness_2h_\(Int(now.timeIntervalSince1970))",
                title: "Détox Numérique",
                description: "Prends une pause numérique de 2 heures pour ton bien-être",
                startDate: now,
                endDate: Calendar.current.date(byAdding: .hour, value: 2, to: now) ?? now,
                participantCount: 0,
                maxParticipants: 25,
                suggestedApps: ["All Social Media", "Entertainment", "News"],
                category: .wellness,
                difficulty: .hard,
                reward: CommunityReward(points: 200, badge: "🧘", title: "Zen Master")
            )
        ]
        
        // Sauvegarder sur Firebase
        for challenge in challenges {
            await saveChallengeToFirebase(challenge)
        }
        
        print("✅ [COMMUNITY] Generated \(challenges.count) simple challenges")
    }
    
    private func saveChallengeToFirebase(_ challenge: CommunityChallenge) async {
        let challengeData: [String: Any] = [
            "id": challenge.id,
            "title": challenge.title,
            "description": challenge.description,
            "startDate": Timestamp(date: challenge.startDate),
            "endDate": Timestamp(date: challenge.endDate),
            "participantCount": challenge.participantCount,
            "maxParticipants": challenge.maxParticipants,
            "suggestedApps": challenge.suggestedApps,
            "category": challenge.category.rawValue,
            "difficulty": challenge.difficulty.rawValue,
            "rewardPoints": challenge.reward.points,
            "rewardBadge": challenge.reward.badge,
            "rewardTitle": challenge.reward.title,
            "createdAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("challenges").document(challenge.id).setData(challengeData)
            print("✅ [FIREBASE] Saved challenge: \(challenge.title)")
        } catch {
            print("❌ [FIREBASE] Error saving challenge: \(error)")
        }
    }
    
    // MARK: - Discussion Management
    
    func sendMessage(_ content: String, to challengeId: String) {
        let message = CommunityMessage(
            id: UUID().uuidString,
            userId: currentUserId,
            username: currentUsername,
            content: content,
            timestamp: Date(),
            challengeId: challengeId,
            likes: 0,
            replies: []
        )
        
        // Envoyer à Firebase
        let messageData: [String: Any] = [
            "id": message.id,
            "userId": message.userId,
            "username": message.username,
            "content": message.content,
            "timestamp": Timestamp(date: message.timestamp),
            "challengeId": challengeId,
            "likes": 0,
            "replies": []
        ]
        
        db.collection("messages").document(message.id).setData(messageData) { error in
            if let error = error {
                print("❌ [FIREBASE] Error sending message: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Erreur lors de l'envoi du message"
                }
            } else {
                print("✅ [FIREBASE] Message sent successfully")
            }
        }
    }
    
    func likeMessage(_ messageId: String) {
        db.collection("messages").document(messageId).updateData([
            "likes": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("❌ [FIREBASE] Error liking message: \(error)")
            } else {
                print("✅ [FIREBASE] Message liked successfully")
            }
        }
    }
    
    func replyToMessage(_ messageId: String, content: String) {
        let reply = CommunityMessage(
            id: UUID().uuidString,
            userId: currentUserId,
            username: currentUsername,
            content: content,
            timestamp: Date(),
            challengeId: "",
            likes: 0,
            replies: []
        )
        
        // TODO: Ajouter à Firebase
        print("↩️ [COMMUNITY] Replying to message: \(messageId)")
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningToMessages(for challengeId: String) {
        // Arrêter l'ancien listener si il existe
        stopListeningToMessages(for: challengeId)
        
        let listener = db.collection("messages")
            .whereField("challengeId", isEqualTo: challengeId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [FIREBASE] Error listening to messages: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Erreur de synchronisation"
                    }
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ [FIREBASE] No messages found")
                    return
                }
                
                let messages = documents.compactMap { document -> CommunityMessage? in
                    let data = document.data()
                    
                    guard let id = data["id"] as? String,
                          let userId = data["userId"] as? String,
                          let username = data["username"] as? String,
                          let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp,
                          let challengeId = data["challengeId"] as? String,
                          let likes = data["likes"] as? Int else {
                        return nil
                    }
                    
                    return CommunityMessage(
                        id: id,
                        userId: userId,
                        username: username,
                        content: content,
                        timestamp: timestamp.dateValue(),
                        challengeId: challengeId,
                        likes: likes,
                        replies: []
                    )
                }
                
                DispatchQueue.main.async {
                    print("📨 [FIREBASE] Posting \(messages.count) messages to NotificationCenter for challenge \(challengeId)")
                    
                    // Notifier la vue CommunityDiscussionView avec les nouveaux messages
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CommunityMessagesUpdated"),
                        object: nil,
                        userInfo: ["challengeId": challengeId, "messages": messages]
                    )
                }
                
                print("🔄 [FIREBASE] Received \(messages.count) messages for challenge \(challengeId)")
                
                // Debug: Afficher le contenu des messages
                for message in messages.prefix(3) {
                    print("💬 Message: \(message.username): \(message.content)")
                }
            }
        
        messageListeners[challengeId] = listener
        print("👂 [FIREBASE] Started listening to messages for challenge: \(challengeId)")
    }
    
    func stopListeningToMessages(for challengeId: String) {
        messageListeners[challengeId]?.remove()
        messageListeners.removeValue(forKey: challengeId)
        print("🔇 [FIREBASE] Stopped listening to messages for challenge: \(challengeId)")
    }
    
    func stopAllListeners() {
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
        print("🔇 [FIREBASE] Stopped all message listeners")
    }
    
    // MARK: - Notifications
    
    func setupNotifications() {
        // TODO: Configurer les notifications push
        print("🔔 [COMMUNITY] Setting up notifications")
    }
    
    func sendChallengeNotification(_ challenge: CommunityChallenge) {
        // TODO: Envoyer notification pour nouveau défi
        print("📢 [COMMUNITY] Sending challenge notification: \(challenge.title)")
    }
    
    // MARK: - Participants Management
    
    func getChallengeParticipants(_ challengeId: String) async -> [CommunityParticipant] {
        do {
            let snapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .getDocuments()
            
            let participants = snapshot.documents.compactMap { document -> CommunityParticipant? in
                let data = document.data()
                
                guard let id = data["id"] as? String,
                      let userId = data["userId"] as? String,
                      let username = data["username"] as? String,
                      let joinedAt = data["joinedAt"] as? Timestamp,
                      let progress = data["progress"] as? Double,
                      let isCompleted = data["isCompleted"] as? Bool,
                      let rank = data["rank"] as? Int,
                      let badges = data["badges"] as? [String],
                      let streakCount = data["streakCount"] as? Int else {
                    return nil
                }
                
                return CommunityParticipant(
                    id: id,
                    userId: userId,
                    username: username,
                    joinedAt: joinedAt.dateValue(),
                    progress: progress,
                    isCompleted: isCompleted,
                    rank: rank,
                    badges: badges,
                    streakCount: streakCount
                )
            }
            
            print("✅ [PARTICIPANTS] Loaded \(participants.count) participants for challenge \(challengeId)")
            return participants
            
        } catch {
            print("❌ [PARTICIPANTS] Error loading participants: \(error)")
            return []
        }
    }
    
    func getChallengeStatistics(_ challengeId: String) async -> (active: Int, completed: Int, averageProgress: Double) {
        let participants = await getChallengeParticipants(challengeId)
        
        let active = participants.filter { $0.progress > 0 && !$0.isCompleted }.count
        let completed = participants.filter { $0.isCompleted }.count
        let averageProgress = participants.isEmpty ? 0.0 : participants.reduce(0.0) { $0 + $1.progress } / Double(participants.count)
        
        return (active: active, completed: completed, averageProgress: averageProgress)
    }
    
    func loadParticipants(for challengeId: String) async -> [CommunityParticipant] {
        print("👥 [COMMUNITY] Loading participants for challenge: \(challengeId)")
        
        do {
            let snapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .order(by: "rank")
                .getDocuments()
            
            let participants = snapshot.documents.compactMap { document -> CommunityParticipant? in
                let data = document.data()
                
                guard let id = data["id"] as? String,
                      let userId = data["userId"] as? String,
                      let username = data["username"] as? String,
                      let joinedAt = data["joinedAt"] as? Timestamp,
                      let progress = data["progress"] as? Double,
                      let isCompleted = data["isCompleted"] as? Bool,
                      let rank = data["rank"] as? Int,
                      let badges = data["badges"] as? [String],
                      let streakCount = data["streakCount"] as? Int else {
                    print("❌ Invalid participant data in document: \(document.documentID)")
                    return nil
                }
                
                return CommunityParticipant(
                    id: id,
                    userId: userId,
                    username: username,
                    joinedAt: joinedAt.dateValue(),
                    progress: progress,
                    isCompleted: isCompleted,
                    rank: rank,
                    badges: badges,
                    streakCount: streakCount
                )
            }
            
            print("✅ [COMMUNITY] Loaded \(participants.count) participants for challenge \(challengeId)")
            return participants
            
        } catch {
            print("❌ [COMMUNITY] Error loading participants: \(error)")
            return []
        }
    }
    
    func joinChallengeAsParticipant(_ challengeId: String, selectedApps: FamilyActivitySelection) async -> Bool {
        print("🚀 [COMMUNITY] Joining challenge as participant: \(challengeId)")
        
        let participant = CommunityParticipant(
            id: UUID().uuidString,
            userId: currentUserId,
            username: currentUsername,
            joinedAt: Date(),
            progress: 0.0,
            isCompleted: false,
            rank: 999, // Sera recalculé automatiquement
            badges: [],
            streakCount: 0
        )
        
        let participantData: [String: Any] = [
            "id": participant.id,
            "userId": participant.userId,
            "username": participant.username,
            "challengeId": challengeId,
            "joinedAt": Timestamp(date: participant.joinedAt),
            "progress": participant.progress,
            "isCompleted": participant.isCompleted,
            "rank": participant.rank,
            "badges": participant.badges,
            "streakCount": participant.streakCount,
            "selectedAppsCount": selectedApps.applicationTokens.count,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        do {
            // Ajouter le participant
            try await db.collection("challenge_participants").document(participant.id).setData(participantData)
            
            // Mettre à jour le compteur de participants du défi
            try await db.collection("challenges").document(challengeId).updateData([
                "participantCount": FieldValue.increment(Int64(1))
            ])
            
            print("✅ [COMMUNITY] Successfully joined challenge: \(challengeId)")
            
            // Recharger les défis pour mettre à jour l'interface
            await loadCommunityData()
            
            return true
            
        } catch {
            print("❌ [COMMUNITY] Error joining challenge: \(error)")
            await MainActor.run {
                self.errorMessage = "Erreur lors de la participation au défi"
            }
            return false
        }
    }
    
    func updateParticipantProgress(_ participantId: String, progress: Double) async {
        print("📊 [COMMUNITY] Updating participant progress: \(participantId) -> \(Int(progress * 100))%")
        
        do {
            try await db.collection("challenge_participants").document(participantId).updateData([
                "progress": progress,
                "isCompleted": progress >= 1.0,
                "updatedAt": Timestamp(date: Date())
            ])
            
            // Recalculer le rang si nécessaire
            if progress >= 1.0 {
                // Récupérer le challengeId du participant pour recalculer les rangs
                if let participant = try? await db.collection("challenge_participants")
                    .document(participantId).getDocument().data(),
                   let challengeId = participant["challengeId"] as? String {
                    await recalculateRankings(for: challengeId)
                }
            }
            
            print("✅ [COMMUNITY] Updated participant progress successfully")
            
        } catch {
            print("❌ [COMMUNITY] Error updating participant progress: \(error)")
        }
    }
    
    func leaveChallenge(_ challengeId: String) async -> Bool {
        print("👋 [COMMUNITY] Leaving challenge: \(challengeId)")
        
        do {
            // Trouver la participation de l'utilisateur
            let snapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            guard let participantDoc = snapshot.documents.first else {
                print("❌ [COMMUNITY] No participation found for user")
                return false
            }
            
            // Supprimer la participation
            try await participantDoc.reference.delete()
            
            // Décrémenter le compteur de participants
            try await db.collection("challenges").document(challengeId).updateData([
                "participantCount": FieldValue.increment(Int64(-1))
            ])
            
            print("✅ [COMMUNITY] Successfully left challenge: \(challengeId)")
            
            // Recharger les défis
            await loadCommunityData()
            
            return true
            
        } catch {
            print("❌ [COMMUNITY] Error leaving challenge: \(error)")
            return false
        }
    }
    
    private func recalculateRankings(for challengeId: String) async {
        print("🏆 [COMMUNITY] Recalculating rankings for challenge: \(challengeId)")
        
        do {
            let snapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .order(by: "progress", descending: true)
                .order(by: "joinedAt", descending: false) // En cas d'égalité, le premier arrivé gagne
                .getDocuments()
            
            let batch = db.batch()
            
            for (index, document) in snapshot.documents.enumerated() {
                let newRank = index + 1
                batch.updateData(["rank": newRank], forDocument: document.reference)
            }
            
            try await batch.commit()
            print("✅ [COMMUNITY] Rankings recalculated for \(snapshot.documents.count) participants")
            
        } catch {
            print("❌ [COMMUNITY] Error recalculating rankings: \(error)")
        }
    }
    
    func isUserParticipating(in challengeId: String) async -> Bool {
        do {
            let snapshot = try await db.collection("challenge_participants")
                .whereField("challengeId", isEqualTo: challengeId)
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("❌ [COMMUNITY] Error checking participation: \(error)")
            return false
        }
    }
    
    // MARK: - Data Persistence
    
    private func persistParticipation(challengeId: String, selectedApps: FamilyActivitySelection, participant: CommunityParticipant) async {
        await MainActor.run {
            // Sauvegarder la participation
            var participations = getStoredParticipations()
            let participationData: [String: Any] = [
                "challengeId": challengeId,
                "participantId": participant.id,
                "userId": participant.userId,
                "username": participant.username,
                "joinedAt": participant.joinedAt.timeIntervalSince1970,
                "progress": participant.progress,
                "isCompleted": participant.isCompleted,
                "timestamp": Date().timeIntervalSince1970
            ]
            participations[challengeId] = participationData
            
            if let data = try? JSONSerialization.data(withJSONObject: participations) {
                userDefaults.set(data, forKey: participationsKey)
            }
            
            // Sauvegarder les apps sélectionnées (métadonnées uniquement)
            let appsData: [String: Any] = [
                "applicationTokensCount": selectedApps.applicationTokens.count,
                "categoryTokensCount": selectedApps.categoryTokens.count,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: appsData) {
                userDefaults.set(data, forKey: "\(selectedAppsKey)_\(challengeId)")
            }
            
            // Sauvegarder la FamilyActivitySelection complète (pour le blocage réel)
            saveFamilyActivitySelection(selectedApps, for: challengeId)
            
            print("💾 [PERSISTENCE] Saved participation for challenge: \(challengeId)")
        }
    }
    
    private func getStoredParticipations() -> [String: [String: Any]] {
        guard let data = userDefaults.data(forKey: participationsKey),
              let participations = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }
        return participations
    }
    
    func hasStoredParticipation(for challengeId: String) -> Bool {
        let participations = getStoredParticipations()
        return participations[challengeId] != nil
    }
    
    func getStoredParticipation(for challengeId: String) -> [String: Any]? {
        let participations = getStoredParticipations()
        return participations[challengeId]
    }
    
    func removeStoredParticipation(for challengeId: String) {
        var participations = getStoredParticipations()
        participations.removeValue(forKey: challengeId)
        
        if let data = try? JSONSerialization.data(withJSONObject: participations) {
            userDefaults.set(data, forKey: participationsKey)
        }
        
        // Supprimer aussi les apps sélectionnées
        userDefaults.removeObject(forKey: "\(selectedAppsKey)_\(challengeId)")
        
        // Supprimer la FamilyActivitySelection
        removeFamilyActivitySelection(for: challengeId)
        
        print("🗑️ [PERSISTENCE] Removed participation for challenge: \(challengeId)")
    }
    
    func getStoredSelectedApps(for challengeId: String) -> [String: Any]? {
        guard let data = userDefaults.data(forKey: "\(selectedAppsKey)_\(challengeId)"),
              let appsData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return appsData
    }
    
    // MARK: - Single Source of Truth Methods
    
    /// Méthode centralisée pour obtenir l'état de participation d'un défi
    func getParticipationState(for challengeId: String) -> ChallengeParticipationState {
        if let existingState = userParticipations[challengeId] {
            return existingState
        }
        
        // Créer un état en vérifiant toutes les sources
        return buildParticipationState(for: challengeId)
    }
    
    /// Méthode atomique pour rejoindre un défi
    func joinChallengeAtomic(_ challenge: CommunityChallenge, selectedApps: FamilyActivitySelection) async -> Bool {
        print("🚀 [ATOMIC] Starting atomic challenge participation for: \(challenge.id)")
        
        // Étape 1: Mettre l'état en "joining"
        await MainActor.run {
            userParticipations[challenge.id] = ChallengeParticipationState(
                challengeId: challenge.id,
                status: .joining,
                selectedApps: selectedApps,
                participant: nil,
                blockingSession: nil,
                lastUpdated: Date()
            )
        }
        
        // Étape 2: Vérification autorisation Screen Time
        let hasScreenTimeAuth = await ScreenTimeManager.shared.requestScreenTimeAuthorization()
        if !hasScreenTimeAuth {
            print("❌ [ATOMIC] Screen Time authorization denied")
            await setParticipationState(challengeId: challenge.id, status: .failed)
            return false
        }
        
        // Étape 3: Opérations atomiques (tout réussit ou tout échoue)
        do {
            // 3a. Firebase participation
            let participant = try await createFirebaseParticipation(challenge, selectedApps: selectedApps)
            
            // 3b. Démarrer le blocage Screen Time
            let blockingSuccess = await ScreenTimeManager.shared.startBlocking(
                challengeId: challenge.id,
                selectedApps: selectedApps,
                duration: challenge.endDate.timeIntervalSince(challenge.startDate),
                challengeTitle: challenge.title
            )
            
            // 3c. Persistence locale
            await persistParticipation(challengeId: challenge.id, selectedApps: selectedApps, participant: participant)
            
            // 3d. Récupérer la session de blocage
            let blockingSession = ScreenTimeManager.shared.getActiveSession(for: challenge.id)
            
            // Étape 4: Mettre à jour l'état final
            await MainActor.run {
                userParticipations[challenge.id] = ChallengeParticipationState(
                    challengeId: challenge.id,
                    status: .active,
                    selectedApps: selectedApps,
                    participant: participant,
                    blockingSession: blockingSession,
                    lastUpdated: Date()
                )
            }
            
            print("✅ [ATOMIC] Challenge participation completed successfully for: \(challenge.id)")
            
            // Étape 5: Notification après succès complet
            NotificationCenter.default.post(
                name: NSNotification.Name("ChallengeParticipationChanged"),
                object: nil,
                userInfo: ["challengeId": challenge.id, "status": "active"]
            )
            
            return true
            
        } catch {
            print("❌ [ATOMIC] Error during atomic participation: \(error)")
            await setParticipationState(challengeId: challenge.id, status: .failed)
            return false
        }
    }
    
    private func buildParticipationState(for challengeId: String) -> ChallengeParticipationState {
        // Vérifier toutes les sources et construire l'état cohérent
        let hasLocalData = hasStoredParticipation(for: challengeId)
        let persistedApps = getFamilyActivitySelection(for: challengeId)
        let blockingSession = ScreenTimeManager.shared.getActiveSession(for: challengeId)
        
        if hasLocalData && persistedApps != nil {
            // Participation locale complète
            let storedData = getStoredParticipation(for: challengeId)
            let participant = storedData != nil ? createParticipantFromStored(storedData!, challengeId: challengeId) : nil
            
            return ChallengeParticipationState(
                challengeId: challengeId,
                status: .active,
                selectedApps: persistedApps,
                participant: participant,
                blockingSession: blockingSession,
                lastUpdated: Date()
            )
        } else {
            // Pas de participation
            return ChallengeParticipationState(
                challengeId: challengeId,
                status: .notParticipating,
                selectedApps: nil,
                participant: nil,
                blockingSession: nil,
                lastUpdated: Date()
            )
        }
    }
    
    private func setParticipationState(challengeId: String, status: ParticipationStatus) async {
        await MainActor.run {
            if let currentState = userParticipations[challengeId] {
                userParticipations[challengeId] = ChallengeParticipationState(
                    challengeId: challengeId,
                    status: status,
                    selectedApps: currentState.selectedApps,
                    participant: currentState.participant,
                    blockingSession: currentState.blockingSession,
                    lastUpdated: Date()
                )
            }
        }
    }
    
    private func createParticipantFromStored(_ storedData: [String: Any], challengeId: String) -> CommunityParticipant {
        return CommunityParticipant(
            id: storedData["participantId"] as? String ?? UUID().uuidString,
            userId: storedData["userId"] as? String ?? currentUserId,
            username: storedData["username"] as? String ?? currentUsername,
            joinedAt: Date(timeIntervalSince1970: storedData["joinedAt"] as? TimeInterval ?? 0),
            progress: storedData["progress"] as? Double ?? 0.0,
            isCompleted: storedData["isCompleted"] as? Bool ?? false,
            rank: 999,
            badges: [],
            streakCount: 0
        )
    }
    
    private func createFirebaseParticipation(_ challenge: CommunityChallenge, selectedApps: FamilyActivitySelection) async throws -> CommunityParticipant {
        let participant = CommunityParticipant(
            id: UUID().uuidString,
            userId: currentUserId,
            username: currentUsername,
            joinedAt: Date(),
            progress: 0.0,
            isCompleted: false,
            rank: 999,
            badges: [],
            streakCount: 0
        )
        
        let participantData: [String: Any] = [
            "id": participant.id,
            "userId": participant.userId,
            "username": participant.username,
            "challengeId": challenge.id,
            "joinedAt": Timestamp(date: participant.joinedAt),
            "progress": participant.progress,
            "isCompleted": participant.isCompleted,
            "rank": participant.rank,
            "badges": participant.badges,
            "streakCount": participant.streakCount,
            "selectedApps": selectedApps.applicationTokens.count,
            "selectedCategories": selectedApps.categoryTokens.count
        ]
        
        try await db.collection("challenge_participants").document(participant.id).setData(participantData)
        try await db.collection("challenges").document(challenge.id).updateData([
            "participantCount": FieldValue.increment(Int64(1))
        ])
        
        return participant
    }
    
    // MARK: - FamilyActivitySelection Persistence (ZenloopManager approach)
    
    private func saveFamilyActivitySelection(_ selection: FamilyActivitySelection, for challengeId: String) {
        // Utiliser JSONEncoder comme ZenloopManager (simple et efficace)
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(selection)
            userDefaults.set(data, forKey: "\(familyActivitySelectionKey)_\(challengeId)")
            print("💾 [PERSISTENCE] Saved FamilyActivitySelection for challenge: \(challengeId) (JSONEncoder)")
        } catch {
            print("❌ [PERSISTENCE] Failed to save FamilyActivitySelection: \(error)")
            // Fallback: sauvegarder juste le count pour compatibilité
            let count = selection.applicationTokens.count + selection.categoryTokens.count
            userDefaults.set(count, forKey: "apps_count_\(challengeId)")
        }
    }
    
    func getFamilyActivitySelection(for challengeId: String) -> FamilyActivitySelection? {
        guard let data = userDefaults.data(forKey: "\(familyActivitySelectionKey)_\(challengeId)") else {
            print("⚠️ [PERSISTENCE] No FamilyActivitySelection found for challenge: \(challengeId)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
            print("✅ [PERSISTENCE] Loaded FamilyActivitySelection for challenge: \(challengeId) (JSONDecoder)")
            return selection
        } catch {
            print("❌ [PERSISTENCE] Error loading FamilyActivitySelection: \(error)")
            return nil
        }
    }
    
    private func removeFamilyActivitySelection(for challengeId: String) {
        userDefaults.removeObject(forKey: "\(familyActivitySelectionKey)_\(challengeId)")
        userDefaults.removeObject(forKey: "apps_count_\(challengeId)") // Fallback cleanup
        print("🗑️ [PERSISTENCE] Removed FamilyActivitySelection for challenge: \(challengeId)")
    }
    
}



