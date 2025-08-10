//
//  ParticipationIntelligence.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import Foundation
import Combine

// MARK: - AI-Powered Participation Intelligence

class ParticipationIntelligence: ObservableObject {
    static let shared = ParticipationIntelligence()
    
    private let db = Firestore.firestore()
    private let analytics = CommunityAnalytics.shared
    
    // ML Models (simulés avec des algorithmes intelligents)
    private var userProfiles: [String: UserProfile] = [:]
    private var challengeAffinityMatrix: [String: [CommunityCategory: Double]] = [:]
    private var successPredictionModel: SuccessPredictionModel = SuccessPredictionModel()
    
    @Published var recommendations: [ChallengeRecommendation] = []
    @Published var matchingScore: Double = 0.0
    
    private init() {
        startIntelligenceEngine()
    }
    
    // MARK: - Intelligence Engine
    
    private func startIntelligenceEngine() {
        // Charger les profils utilisateurs périodiquement
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in // 30 minutes
            Task {
                await self.updateUserProfiles()
                await self.recalculateAffinityMatrix()
            }
        }
        
        print("🧠 [INTELLIGENCE] Participation Intelligence Engine started")
    }
    
    // MARK: - User Profiling & Behavior Analysis
    
    private func updateUserProfiles() async {
        let activeUsers = await getActiveUsers()
        
        for userId in activeUsers {
            let profile = await buildUserProfile(userId: userId)
            userProfiles[userId] = profile
        }
        
        print("🎯 [INTELLIGENCE] Updated \(userProfiles.count) user profiles")
    }
    
    private func buildUserProfile(userId: String) async -> UserProfile {
        do {
            // Récupérer l'historique de participation
            let participationsSnapshot = try await db.collection("challenge_participants")
                .whereField("userId", isEqualTo: userId)
                .limit(to: 50) // Dernières 50 participations
                .getDocuments()
            
            let participations = participationsSnapshot.documents.map { doc in
                doc.data()
            }
            
            // Analyser les patterns temporels
            let temporalPattern = analyzeTemporalPatterns(participations)
            
            // Analyser les préférences de catégories
            let categoryPreferences = await analyzeCategoryPreferences(userId: userId, participations: participations)
            
            // Analyser les patterns de succès
            let successFactors = analyzeSuccessFactors(participations)
            
            // Calculer le niveau d'engagement
            let engagementLevel = calculateEngagementLevel(participations)
            
            // Identifier la personnalité de défi
            let challengePersonality = identifyChallengePersonality(participations)
            
            // Analyser les préférences sociales
            let socialPreferences = await analyzeSocialPreferences(userId: userId)
            
            return UserProfile(
                userId: userId,
                temporalPattern: temporalPattern,
                categoryPreferences: categoryPreferences,
                successFactors: successFactors,
                engagementLevel: engagementLevel,
                challengePersonality: challengePersonality,
                socialPreferences: socialPreferences,
                lastUpdated: Date()
            )
            
        } catch {
            print("❌ [INTELLIGENCE] Error building profile for \(userId): \(error)")
            return UserProfile.default(userId: userId)
        }
    }
    
    private func analyzeTemporalPatterns(_ participations: [[String: Any]]) -> TemporalPattern {
        var hourCounts: [Int: Int] = [:]
        var dayCounts: [Int: Int] = [:]
        
        for participation in participations {
            if let joinedAt = participation["joinedAt"] as? Timestamp {
                let date = joinedAt.dateValue()
                let hour = Calendar.current.component(.hour, from: date)
                let weekday = Calendar.current.component(.weekday, from: date)
                
                hourCounts[hour, default: 0] += 1
                dayCounts[weekday, default: 0] += 1
            }
        }
        
        let preferredHours = hourCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let preferredDays = dayCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        return TemporalPattern(
            preferredHours: preferredHours,
            preferredDays: preferredDays,
            consistencyScore: calculateConsistencyScore(hourCounts: hourCounts, dayCounts: dayCounts)
        )
    }
    
    private func analyzeCategoryPreferences(userId: String, participations: [[String: Any]]) async -> [CommunityCategory: Double] {
        var categoryScores: [CommunityCategory: CategoryScore] = [:]
        
        // Initialiser les scores
        for category in CommunityCategory.allCases {
            categoryScores[category] = CategoryScore()
        }
        
        // Analyser chaque participation
        for participation in participations {
            guard let challengeId = participation["challengeId"] as? String,
                  let progress = participation["progress"] as? Double,
                  let isCompleted = participation["isCompleted"] as? Bool else {
                continue
            }
            
            // Récupérer la catégorie du défi
            if let category = await getChallengeCategory(challengeId: challengeId) {
                categoryScores[category]!.participationCount += 1
                categoryScores[category]!.totalProgress += progress
                
                if isCompleted {
                    categoryScores[category]!.completionCount += 1
                }
            }
        }
        
        // Calculer les scores finaux (pondération: participation, progression, complétion)
        var finalScores: [CommunityCategory: Double] = [:]
        
        for (category, score) in categoryScores {
            let participationScore = Double(score.participationCount) / 10.0 // Normalisé sur 10
            let progressScore = score.participationCount > 0 ? 
                score.totalProgress / Double(score.participationCount) : 0.0
            let completionScore = score.participationCount > 0 ? 
                Double(score.completionCount) / Double(score.participationCount) : 0.0
            
            // Pondération: 30% participation, 40% progression, 30% complétion
            finalScores[category] = (participationScore * 0.3) + (progressScore * 0.4) + (completionScore * 0.3)
        }
        
        return finalScores
    }
    
    private func analyzeSuccessFactors(_ participations: [[String: Any]]) -> SuccessFactors {
        let completed = participations.filter { ($0["isCompleted"] as? Bool) == true }
        let failed = participations.filter { 
            let progress = ($0["progress"] as? Double) ?? 0.0
            return progress < 0.2 // Moins de 20% = échec
        }
        
        // Analyser les durées optimales
        var optimalDurations: [TimeInterval] = []
        // Analyser les tailles de groupes optimales
        var optimalGroupSizes: [Int] = []
        // Analyser les difficultés préférées
        var preferredDifficulties: [CommunityDifficulty] = []
        
        // Simulation basée sur les données (en production, analyser les vraies données)
        return SuccessFactors(
            optimalDuration: optimalDurations.isEmpty ? 4 * 3600 : optimalDurations.reduce(0, +) / Double(optimalDurations.count),
            preferredDifficulty: preferredDifficulties.first ?? .medium,
            socialInfluence: calculateSocialInfluence(completed, failed),
            consistencyImportance: calculateConsistencyImportance(participations)
        )
    }
    
    private func calculateEngagementLevel(_ participations: [[String: Any]]) -> EngagementLevel {
        let recentParticipations = participations.prefix(10) // 10 dernières
        let avgProgress = recentParticipations.compactMap { $0["progress"] as? Double }
            .reduce(0, +) / Double(max(recentParticipations.count, 1))
        
        let completionRate = recentParticipations.filter { ($0["isCompleted"] as? Bool) == true }.count
        let engagementScore = (avgProgress * 0.6) + (Double(completionRate) / Double(max(recentParticipations.count, 1)) * 0.4)
        
        switch engagementScore {
        case 0.8...: return .high
        case 0.5..<0.8: return .medium
        case 0.2..<0.5: return .low
        default: return .minimal
        }
    }
    
    private func identifyChallengePersonality(_ participations: [[String: Any]]) -> ChallengePersonality {
        let totalParticipations = participations.count
        let completedCount = participations.filter { ($0["isCompleted"] as? Bool) == true }.count
        let highProgressCount = participations.filter { 
            let progress = ($0["progress"] as? Double) ?? 0.0
            return progress > 0.8
        }.count
        
        let completionRate = Double(completedCount) / Double(max(totalParticipations, 1))
        let highEffortRate = Double(highProgressCount) / Double(max(totalParticipations, 1))
        
        // Classification basée sur les patterns
        if completionRate > 0.8 && highEffortRate > 0.7 {
            return .achiever // Finit tout, donne son maximum
        } else if completionRate > 0.6 && totalParticipations > 10 {
            return .consistent // Régulier et fiable
        } else if totalParticipations > 20 && completionRate < 0.4 {
            return .explorer // Teste beaucoup, finit peu
        } else if highEffortRate > 0.6 && totalParticipations < 10 {
            return .perfectionist // Peu de défis, mais excellents résultats
        } else {
            return .casual // Participation occasionnelle
        }
    }
    
    private func analyzeSocialPreferences(userId: String) async -> SocialPreferences {
        do {
            // Analyser l'activité dans les discussions
            let messagesSnapshot = try await db.collection("messages")
                .whereField("userId", isEqualTo: userId)
                .limit(to: 50)
                .getDocuments()
            
            let messageCount = messagesSnapshot.documents.count
            
            // Analyser les likes donnés/reçus
            // (Simulation - en production, analyser les vraies interactions)
            
            let interactionLevel: InteractionLevel = switch messageCount {
            case 20...: .high
            case 5..<20: .medium
            case 1..<5: .low
            default: .minimal
            }
            
            return SocialPreferences(
                interactionLevel: interactionLevel,
                prefersGroupChallenges: messageCount > 10,
                leadershipTendency: messageCount > 15 && Int.random(in: 0...1) == 1,
                supportiveness: calculateSupportiveness(messagesSnapshot.documents)
            )
            
        } catch {
            return SocialPreferences.default()
        }
    }
    
    // MARK: - Challenge Matching Algorithm
    
    func findOptimalChallenges(for userId: String, availableChallenges: [GeneratedChallenge]) async -> [ChallengeRecommendation] {
        let userProfile: UserProfile
        if let existingProfile = userProfiles[userId] {
            userProfile = existingProfile
        } else {
            userProfile = await buildUserProfile(userId: userId)
        }
        var recommendations: [ChallengeRecommendation] = []
        
        for challenge in availableChallenges {
            let matchScore = await calculateMatchScore(challenge: challenge, userProfile: userProfile)
            let successPrediction = await predictSuccess(challenge: challenge, userProfile: userProfile)
            
            let recommendation = ChallengeRecommendation(
                challenge: challenge,
                matchScore: matchScore,
                successPrediction: successPrediction,
                reasons: generateRecommendationReasons(challenge: challenge, userProfile: userProfile, score: matchScore),
                personalizedMessage: generatePersonalizedMessage(challenge: challenge, userProfile: userProfile)
            )
            
            recommendations.append(recommendation)
        }
        
        // Trier par score de matching et diversifier
        recommendations = recommendations.sorted { $0.matchScore > $1.matchScore }
        recommendations = diversifyRecommendations(recommendations)
        
        return Array(recommendations.prefix(5)) // Top 5
    }
    
    private func calculateMatchScore(challenge: GeneratedChallenge, userProfile: UserProfile) async -> Double {
        var score = 0.0
        
        // Facteur 1: Préférence de catégorie (30%)
        let categoryScore = userProfile.categoryPreferences[challenge.category] ?? 0.3
        score += categoryScore * 0.3
        
        // Facteur 2: Compatibilité temporelle (25%)
        let dayOfWeek = Calendar.current.component(.weekday, from: challenge.startDate)
        let hour = Calendar.current.component(.hour, from: challenge.startDate)
        
        let dayMatch = userProfile.temporalPattern.preferredDays.contains(dayOfWeek)
        let hourMatch = userProfile.temporalPattern.preferredHours.contains(hour)
        
        var temporalScore = 0.0
        if dayMatch { temporalScore += 0.6 }
        if hourMatch { temporalScore += 0.4 }
        
        score += temporalScore * 0.25
        
        // Facteur 3: Difficulté adaptée (20%)
        let difficultyMatch = challenge.difficulty == userProfile.successFactors.preferredDifficulty
        let difficultyScore = difficultyMatch ? 1.0 : 0.5
        score += difficultyScore * 0.2
        
        // Facteur 4: Durée optimale (15%)
        let durationDifference = abs(challenge.endDate.timeIntervalSince(challenge.startDate) - userProfile.successFactors.optimalDuration)
        let durationScore = max(0.0, 1.0 - (durationDifference / (4 * 3600))) // Pénalité progressive
        score += durationScore * 0.15
        
        // Facteur 5: Engagement historique (10%)
        let engagementBonus = switch userProfile.engagementLevel {
        case .high: 0.9
        case .medium: 0.7
        case .low: 0.5
        case .minimal: 0.3
        }
        score += engagementBonus * 0.1
        
        return min(score, 1.0)
    }
    
    private func predictSuccess(challenge: GeneratedChallenge, userProfile: UserProfile) async -> Double {
        // Modèle de prédiction basé sur l'historique et les patterns
        var prediction = 0.5 // Base
        
        // Facteur personnalité
        switch userProfile.challengePersonality {
        case .achiever:
            prediction += 0.3
        case .consistent:
            prediction += 0.2
        case .perfectionist:
            if challenge.difficulty == .hard {
                prediction += 0.25
            } else {
                prediction += 0.1
            }
        case .explorer:
            prediction += 0.1
        case .casual:
            if challenge.difficulty == .easy {
                prediction += 0.15
            }
        }
        
        // Facteur catégorie préférée
        let categoryPreference = userProfile.categoryPreferences[challenge.category] ?? 0.3
        prediction += categoryPreference * 0.2
        
        // Facteur temporel
        if isOptimalTiming(challenge: challenge, userProfile: userProfile) {
            prediction += 0.15
        }
        
        // Facteur social
        if challenge.maxParticipants > 10 && userProfile.socialPreferences.prefersGroupChallenges {
            prediction += 0.1
        }
        
        return min(prediction, 1.0)
    }
    
    // MARK: - Smart User Matching
    
    func findRelevantUsers(for challenge: GeneratedChallenge) async -> [String] {
        var relevantUsers: [String] = []
        
        for (userId, profile) in userProfiles {
            let relevanceScore = await calculateUserRelevance(userId: userId, profile: profile, challenge: challenge)
            
            if relevanceScore > 0.6 { // Seuil de pertinence
                relevantUsers.append(userId)
            }
        }
        
        // Limiter à 50 utilisateurs max pour éviter le spam
        return Array(relevantUsers.prefix(50))
    }
    
    private func calculateUserRelevance(userId: String, profile: UserProfile, challenge: GeneratedChallenge) async -> Double {
        var score = 0.0
        
        // Préférence de catégorie
        score += (profile.categoryPreferences[challenge.category] ?? 0.0) * 0.4
        
        // Compatibilité temporelle
        let dayOfWeek = Calendar.current.component(.weekday, from: challenge.startDate)
        let hour = Calendar.current.component(.hour, from: challenge.startDate)
        
        if profile.temporalPattern.preferredDays.contains(dayOfWeek) {
            score += 0.2
        }
        
        if profile.temporalPattern.preferredHours.contains(hour) {
            score += 0.15
        }
        
        // Niveau d'engagement
        switch profile.engagementLevel {
        case .high: score += 0.2
        case .medium: score += 0.15
        case .low: score += 0.1
        case .minimal: score += 0.05
        }
        
        // Éviter la surcharge pour les utilisateurs très actifs
        let recentActivity = await getRecentUserActivity(userId: userId)
        if recentActivity > 3 { // Plus de 3 défis actifs
            score *= 0.5 // Réduire la priorité
        }
        
        return score
    }
    
    // MARK: - Group Formation Intelligence
    
    func formOptimalGroups(participants: [CommunityParticipant], groupSize: Int) async -> [[CommunityParticipant]] {
        var groups: [[CommunityParticipant]] = []
        var remainingParticipants = participants
        
        while remainingParticipants.count >= groupSize {
            let optimalGroup = findOptimalGroup(from: remainingParticipants, size: groupSize)
            groups.append(optimalGroup)
            
            // Retirer les participants du groupe du pool
            remainingParticipants.removeAll { participant in
                optimalGroup.contains { $0.id == participant.id }
            }
        }
        
        // Ajouter les participants restants au dernier groupe ou créer un nouveau groupe
        if !remainingParticipants.isEmpty && !groups.isEmpty {
            groups[groups.count - 1].append(contentsOf: remainingParticipants)
        } else if !remainingParticipants.isEmpty {
            groups.append(remainingParticipants)
        }
        
        return groups
    }
    
    private func findOptimalGroup(from participants: [CommunityParticipant], size: Int) -> [CommunityParticipant] {
        // Algorithme d'optimisation pour former des groupes équilibrés
        // Facteurs: niveau d'engagement, expérience, complémentarité
        
        var bestGroup: [CommunityParticipant] = []
        var bestScore = 0.0
        
        // Sélection glouton amélioré
        var selectedParticipants: [CommunityParticipant] = []
        var availableParticipants = participants
        
        // Commencer par un participant avec engagement élevé
        if let leader = availableParticipants.max(by: { $0.progress < $1.progress }) {
            selectedParticipants.append(leader)
            availableParticipants.removeAll { $0.id == leader.id }
        }
        
        // Ajouter les participants complémentaires
        while selectedParticipants.count < size && !availableParticipants.isEmpty {
            var bestCandidate: CommunityParticipant?
            var bestCandidateScore = 0.0
            
            for candidate in availableParticipants {
                let score = calculateGroupFitScore(candidate: candidate, existingGroup: selectedParticipants)
                if score > bestCandidateScore {
                    bestCandidateScore = score
                    bestCandidate = candidate
                }
            }
            
            if let best = bestCandidate {
                selectedParticipants.append(best)
                availableParticipants.removeAll { $0.id == best.id }
            } else {
                break
            }
        }
        
        return selectedParticipants.count >= 2 ? selectedParticipants : Array(participants.prefix(size))
    }
    
    private func calculateGroupFitScore(candidate: CommunityParticipant, existingGroup: [CommunityParticipant]) -> Double {
        var score = 0.0
        
        // Diversité des niveaux d'expérience
        let avgExperience = existingGroup.map { Double($0.badges.count) }.reduce(0, +) / Double(max(existingGroup.count, 1))
        let candidateExperience = Double(candidate.badges.count)
        
        // Bonus pour la complémentarité (pas trop similaire, pas trop différent)
        let experienceDiff = abs(candidateExperience - avgExperience)
        if experienceDiff > 1 && experienceDiff < 4 { // Sweet spot
            score += 0.3
        }
        
        // Équilibre des progressions
        let avgProgress = existingGroup.map { $0.progress }.reduce(0, +) / Double(max(existingGroup.count, 1))
        let progressBalance = 1.0 - abs(candidate.progress - avgProgress)
        score += progressBalance * 0.2
        
        // Bonus pour les streaks complémentaires
        let hasHighStreak = existingGroup.contains { $0.streakCount > 7 }
        if !hasHighStreak && candidate.streakCount > 7 {
            score += 0.2
        }
        
        // Bonus pour motivation mutuelle
        if candidate.progress > 0.5 && avgExperience > 2 {
            score += 0.3
        }
        
        return score
    }
    
    // MARK: - Utility Functions
    
    private func getActiveUsers() async -> [String] {
        do {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let snapshot = try await db.collection("challenge_participants")
                .whereField("createdAt", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            
            return Array(Set(snapshot.documents.compactMap { $0.data()["userId"] as? String }))
        } catch {
            return []
        }
    }
    
    private func getChallengeCategory(challengeId: String) async -> CommunityCategory? {
        do {
            let doc = try await db.collection("challenges").document(challengeId).getDocument()
            
            if let categoryRaw = doc.data()?["category"] as? String {
                return CommunityCategory(rawValue: categoryRaw)
            }
        } catch {
            print("❌ Error fetching challenge category: \(error)")
        }
        
        return nil
    }
    
    private func calculateConsistencyScore(hourCounts: [Int: Int], dayCounts: [Int: Int]) -> Double {
        // Mesure de la régularité des patterns temporels
        let hourVariance = calculateVariance(hourCounts.values.map { Double($0) })
        let dayVariance = calculateVariance(dayCounts.values.map { Double($0) })
        
        return 1.0 - min((hourVariance + dayVariance) / 20.0, 1.0) // Normalisé
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        
        return variance
    }
    
    private func calculateSocialInfluence(_ completed: [[String: Any]], _ failed: [[String: Any]]) -> Double {
        // Analyser si les défis en groupe ont plus de succès
        // Simulation - en production, analyser les vraies données
        return Double.random(in: 0.3...0.8)
    }
    
    private func calculateConsistencyImportance(_ participations: [[String: Any]]) -> Double {
        // Mesurer l'importance de la régularité pour ce utilisateur
        // Simulation - en production, analyser les patterns temporels réels
        return Double.random(in: 0.4...0.9)
    }
    
    private func calculateSupportiveness(_ documents: [QueryDocumentSnapshot]) -> Double {
        // Analyser le ton des messages pour mesurer le support apporté aux autres
        // Simulation - en production, utiliser NLP
        return Double.random(in: 0.2...0.9)
    }
    
    private func isOptimalTiming(challenge: GeneratedChallenge, userProfile: UserProfile) -> Bool {
        let dayOfWeek = Calendar.current.component(.weekday, from: challenge.startDate)
        let hour = Calendar.current.component(.hour, from: challenge.startDate)
        
        return userProfile.temporalPattern.preferredDays.contains(dayOfWeek) &&
               userProfile.temporalPattern.preferredHours.contains(hour)
    }
    
    private func getRecentUserActivity(userId: String) async -> Int {
        do {
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            let snapshot = try await db.collection("challenge_participants")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThan: Timestamp(date: threeDaysAgo))
                .getDocuments()
            
            return snapshot.documents.count
        } catch {
            return 0
        }
    }
    
    private func diversifyRecommendations(_ recommendations: [ChallengeRecommendation]) -> [ChallengeRecommendation] {
        var diversified: [ChallengeRecommendation] = []
        var usedCategories: Set<CommunityCategory> = []
        
        // Première passe: une recommandation par catégorie
        for recommendation in recommendations {
            if !usedCategories.contains(recommendation.challenge.category) {
                diversified.append(recommendation)
                usedCategories.insert(recommendation.challenge.category)
            }
        }
        
        // Deuxième passe: compléter avec les meilleures recommandations restantes
        for recommendation in recommendations {
            if diversified.count >= 5 { break }
            if !diversified.contains(where: { $0.challenge.id == recommendation.challenge.id }) {
                diversified.append(recommendation)
            }
        }
        
        return diversified
    }
    
    private func generateRecommendationReasons(challenge: GeneratedChallenge, userProfile: UserProfile, score: Double) -> [String] {
        var reasons: [String] = []
        
        if let categoryScore = userProfile.categoryPreferences[challenge.category], categoryScore > 0.6 {
            reasons.append("Tu excelles dans les défis \(challenge.category.displayName)")
        }
        
        let dayOfWeek = Calendar.current.component(.weekday, from: challenge.startDate)
        if userProfile.temporalPattern.preferredDays.contains(dayOfWeek) {
            let dayName = DateFormatter().weekdaySymbols[dayOfWeek - 1]
            reasons.append("Parfait pour ton planning du \(dayName)")
        }
        
        if challenge.difficulty == userProfile.successFactors.preferredDifficulty {
            reasons.append("Niveau de difficulté adapté à tes préférences")
        }
        
        if userProfile.challengePersonality == .achiever && challenge.reward.points > 100 {
            reasons.append("Récompense élevée digne de ton niveau")
        }
        
        if reasons.isEmpty {
            reasons.append("Nouveau défi pour élargir tes horizons")
        }
        
        return reasons
    }
    
    private func generatePersonalizedMessage(challenge: GeneratedChallenge, userProfile: UserProfile) -> String {
        let personality = userProfile.challengePersonality
        let category = challenge.category
        
        switch (personality, category) {
        case (.achiever, .productivity):
            return "🎯 Un défi fait pour toi ! Ton historique montre que tu excelles dans ce domaine."
            
        case (.perfectionist, .focus):
            return "💎 Ce défi de concentration semble parfait pour ton style méticuleux."
            
        case (.explorer, _):
            return "🚀 Nouveau territoire à explorer ! Prêt pour l'aventure ?"
            
        case (.consistent, .wellness):
            return "🌱 Un défi bien-être qui s'intègre parfaitement à ta routine équilibrée."
            
        default:
            return "✨ Ce défi pourrait être exactement ce qu'il te faut aujourd'hui !"
        }
    }
    
    private func recalculateAffinityMatrix() async {
        // Mise à jour de la matrice d'affinité pour améliorer les recommandations
        for (userId, profile) in userProfiles {
            challengeAffinityMatrix[userId] = profile.categoryPreferences
        }
        
        print("🔄 [INTELLIGENCE] Affinity matrix updated for \(challengeAffinityMatrix.count) users")
    }
}

// MARK: - Supporting Data Structures

struct UserProfile {
    let userId: String
    let temporalPattern: TemporalPattern
    let categoryPreferences: [CommunityCategory: Double]
    let successFactors: SuccessFactors
    let engagementLevel: EngagementLevel
    let challengePersonality: ChallengePersonality
    let socialPreferences: SocialPreferences
    let lastUpdated: Date
    
    static func `default`(userId: String) -> UserProfile {
        return UserProfile(
            userId: userId,
            temporalPattern: TemporalPattern(preferredHours: [9, 14, 19], preferredDays: [2, 3, 4], consistencyScore: 0.5),
            categoryPreferences: [:],
            successFactors: SuccessFactors(optimalDuration: 4 * 3600, preferredDifficulty: .medium, socialInfluence: 0.5, consistencyImportance: 0.5),
            engagementLevel: .medium,
            challengePersonality: .casual,
            socialPreferences: SocialPreferences.default(),
            lastUpdated: Date()
        )
    }
}

struct TemporalPattern {
    let preferredHours: [Int]
    let preferredDays: [Int]
    let consistencyScore: Double
}

struct SuccessFactors {
    let optimalDuration: TimeInterval
    let preferredDifficulty: CommunityDifficulty
    let socialInfluence: Double // 0-1, importance des défis de groupe
    let consistencyImportance: Double // 0-1, importance de la régularité
}

enum EngagementLevel: CaseIterable {
    case minimal, low, medium, high
}

enum ChallengePersonality: CaseIterable {
    case achiever        // Finit tout, vise l'excellence
    case consistent      // Régulier, fiable
    case explorer        // Teste beaucoup, finit peu
    case perfectionist   // Peu de défis, résultats parfaits
    case casual          // Participation occasionnelle
}

struct SocialPreferences {
    let interactionLevel: InteractionLevel
    let prefersGroupChallenges: Bool
    let leadershipTendency: Bool
    let supportiveness: Double // 0-1, tendance à aider les autres
    
    static func `default`() -> SocialPreferences {
        return SocialPreferences(
            interactionLevel: .medium,
            prefersGroupChallenges: false,
            leadershipTendency: false,
            supportiveness: 0.5
        )
    }
}

enum InteractionLevel: CaseIterable {
    case minimal, low, medium, high
}

struct CategoryScore {
    var participationCount: Int = 0
    var totalProgress: Double = 0.0
    var completionCount: Int = 0
}

struct ChallengeRecommendation {
    let challenge: GeneratedChallenge
    let matchScore: Double
    let successPrediction: Double
    let reasons: [String]
    let personalizedMessage: String
}

struct SuccessPredictionModel {
    // Modèle ML simulé avec des heuristiques intelligentes
    // En production, utiliser Core ML ou TensorFlow Lite
}

*/
