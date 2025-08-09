//
//  CommunityAnalytics.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Advanced Community Analytics & Intelligence

class CommunityAnalytics: ObservableObject {
    static let shared = CommunityAnalytics()
    
    private let db = Firestore.firestore()
    @Published var analyticsData: AnalyticsData = AnalyticsData()
    
    // Cache pour améliorer les performances
    private var userStatsCache: [String: CommunityUserStats] = [:]
    private var communityMetricsCache: CommunityMetrics?
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    private init() {
        startAnalyticsCollection()
    }
    
    // MARK: - Analytics Collection Setup
    
    private func startAnalyticsCollection() {
        // Observer les changements de participants
        db.collection("challenge_participants")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [ANALYTICS] Error observing participants: \(error)")
                    return
                }
                
                Task {
                    await self?.processParticipantChanges(snapshot)
                }
            }
        
        // Observer les changements de défis
        db.collection("challenges")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [ANALYTICS] Error observing challenges: \(error)")
                    return
                }
                
                Task {
                    await self?.processChallengeChanges(snapshot)
                }
            }
        
        print("📊 [ANALYTICS] Analytics collection started")
    }
    
    // MARK: - Real-time Data Processing
    
    private func processParticipantChanges(_ snapshot: QuerySnapshot?) async {
        guard let documents = snapshot?.documents else { return }
        
        let participants = documents.compactMap { doc -> CommunityParticipant? in
            let data = doc.data()
            
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
        
        await analyzeParticipationPatterns(participants)
        await updateCommunityMetrics(participants)
    }
    
    private func processChallengeChanges(_ snapshot: QuerySnapshot?) async {
        guard let documents = snapshot?.documents else { return }
        
        await analyzeChallengePerformance(documents)
        invalidateCache()
    }
    
    // MARK: - User Analytics
    
    func getCurrentUserStats() async -> CommunityUserStats {
        let userId = CommunityManager.shared.currentUserId
        
        // Vérifier le cache
        if let cachedStats = userStatsCache[userId],
           Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration {
            return cachedStats
        }
        
        let stats = await fetchUserStats(userId: userId)
        userStatsCache[userId] = stats
        
        return stats
    }
    
    private func fetchUserStats(userId: String) async -> CommunityUserStats {
        do {
            // Récupérer les participations de l'utilisateur
            let participationsSnapshot = try await db.collection("challenge_participants")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let participations = participationsSnapshot.documents
            let totalChallenges = participations.count
            let completedChallenges = participations.filter { 
                ($0.data()["isCompleted"] as? Bool) == true 
            }.count
            
            let successRate = totalChallenges > 0 ? Double(completedChallenges) / Double(totalChallenges) : 0.0
            
            // Analyser les catégories préférées
            let challengeIds = participations.compactMap { $0.data()["challengeId"] as? String }
            let preferredCategories = await analyzePreferredCategories(challengeIds: challengeIds)
            
            // Calculer la participation moyenne (progression moyenne)
            let progressions = participations.compactMap { $0.data()["progress"] as? Double }
            let averageParticipation = progressions.isEmpty ? 0.0 : progressions.reduce(0, +) / Double(progressions.count)
            
            return CommunityUserStats(
                userId: userId,
                username: CommunityManager.shared.currentUsername,
                totalPoints: totalChallenges * 10, // Simulation
                completedChallenges: completedChallenges,
                rank: 999, // À calculer
                badges: [], // À implémenter
                joinDate: Date()
            )
            
        } catch {
            print("❌ [ANALYTICS] Error fetching user stats: \(error)")
            return CommunityUserStats(
                userId: userId,
                username: "Unknown",
                totalPoints: 0,
                completedChallenges: 0,
                rank: 999,
                badges: [],
                joinDate: Date()
            )
        }
    }
    
    private func analyzePreferredCategories(challengeIds: [String]) async -> [CommunityCategory] {
        var categoryCounts: [CommunityCategory: Int] = [:]
        
        for challengeId in challengeIds {
            do {
                let challengeDoc = try await db.collection("challenges").document(challengeId).getDocument()
                
                if let categoryRaw = challengeDoc.data()?["category"] as? String,
                   let category = CommunityCategory(rawValue: categoryRaw) {
                    categoryCounts[category, default: 0] += 1
                }
            } catch {
                continue
            }
        }
        
        // Retourner les catégories triées par préférence
        return categoryCounts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    // MARK: - Community Analytics
    
    func getCommunityMetrics() async -> CommunityMetrics {
        // Vérifier le cache
        if let cachedMetrics = communityMetricsCache,
           Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration {
            return cachedMetrics
        }
        
        let metrics = await fetchCommunityMetrics()
        communityMetricsCache = metrics
        lastCacheUpdate = Date()
        
        return metrics
    }
    
    private func fetchCommunityMetrics() async -> CommunityMetrics {
        do {
            // Compter les utilisateurs actifs (qui ont participé dans les 7 derniers jours)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            
            let activeUsersSnapshot = try await db.collection("challenge_participants")
                .whereField("createdAt", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments()
            
            let uniqueActiveUsers = Set(activeUsersSnapshot.documents.compactMap { 
                $0.data()["userId"] as? String 
            }).count
            
            // Calculer le taux de succès récent (dernière semaine)
            let recentParticipations = activeUsersSnapshot.documents
            let recentCompletions = recentParticipations.filter { 
                ($0.data()["isCompleted"] as? Bool) == true 
            }.count
            
            let recentSuccessRate = recentParticipations.count > 0 ? 
                Double(recentCompletions) / Double(recentParticipations.count) : 0.0
            
            // Analyser les catégories populaires
            let challengeIds = recentParticipations.compactMap { $0.data()["challengeId"] as? String }
            let popularCategories = await analyzePopularCategories(challengeIds: challengeIds)
            
            // Calculer la participation moyenne
            let progressions = recentParticipations.compactMap { $0.data()["progress"] as? Double }
            let averageParticipation = progressions.isEmpty ? 0 : Int(progressions.reduce(0, +) / Double(progressions.count) * 100)
            
            return CommunityMetrics(
                activeUsers: uniqueActiveUsers,
                recentSuccessRate: recentSuccessRate,
                popularCategories: popularCategories,
                averageParticipation: averageParticipation
            )
            
        } catch {
            print("❌ [ANALYTICS] Error fetching community metrics: \(error)")
            return CommunityMetrics(activeUsers: 0, recentSuccessRate: 0.0, popularCategories: [], averageParticipation: 0)
        }
    }
    
    private func analyzePopularCategories(challengeIds: [String]) async -> [CommunityCategory] {
        var categoryCounts: [CommunityCategory: Int] = [:]
        
        for challengeId in challengeIds {
            do {
                let challengeDoc = try await db.collection("challenges").document(challengeId).getDocument()
                
                if let categoryRaw = challengeDoc.data()?["category"] as? String,
                   let category = CommunityCategory(rawValue: categoryRaw) {
                    categoryCounts[category, default: 0] += 1
                }
            } catch {
                continue
            }
        }
        
        return categoryCounts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    // MARK: - App Usage Analytics
    
    func getMostBlockedApps() async -> [String] {
        do {
            // Analyser les apps les plus fréquemment bloquées
            let challengesSnapshot = try await db.collection("challenges")
                .limit(to: 50)
                .getDocuments()
            
            var appCounts: [String: Int] = [:]
            
            for document in challengesSnapshot.documents {
                if let suggestedApps = document.data()["suggestedApps"] as? [String] {
                    for app in suggestedApps {
                        appCounts[app, default: 0] += 1
                    }
                }
            }
            
            return appCounts
                .sorted { $0.value > $1.value }
                .map { $0.key }
                .prefix(10)
                .map { String($0) }
            
        } catch {
            print("❌ [ANALYTICS] Error fetching popular apps: \(error)")
            return ["Instagram", "TikTok", "Facebook", "YouTube", "Twitter"]
        }
    }
    
    // MARK: - Participation Pattern Analysis
    
    private func analyzeParticipationPatterns(_ participants: [CommunityParticipant]) async {
        // Analyser les patterns temporels
        let hourlyParticipation = analyzeHourlyParticipation(participants)
        let dailyParticipation = analyzeDailyParticipation(participants)
        let successPatterns = analyzeSuccessPatterns(participants)
        
        await MainActor.run {
            analyticsData.hourlyParticipation = hourlyParticipation
            analyticsData.dailyParticipation = dailyParticipation
            analyticsData.successPatterns = successPatterns
        }
        
        // Stocker les insights pour optimisation future
        await storeAnalyticsInsights()
    }
    
    private func analyzeHourlyParticipation(_ participants: [CommunityParticipant]) -> [Int: Int] {
        var hourlyStats: [Int: Int] = [:]
        
        for participant in participants {
            let hour = Calendar.current.component(.hour, from: participant.joinedAt)
            hourlyStats[hour, default: 0] += 1
        }
        
        return hourlyStats
    }
    
    private func analyzeDailyParticipation(_ participants: [CommunityParticipant]) -> [Int: Int] {
        var dailyStats: [Int: Int] = [:]
        
        for participant in participants {
            let weekday = Calendar.current.component(.weekday, from: participant.joinedAt)
            dailyStats[weekday, default: 0] += 1
        }
        
        return dailyStats
    }
    
    private func analyzeSuccessPatterns(_ participants: [CommunityParticipant]) -> SuccessPatterns {
        let completed = participants.filter { $0.isCompleted }
        let inProgress = participants.filter { $0.progress > 0 && !$0.isCompleted }
        let notStarted = participants.filter { $0.progress == 0 }
        
        return SuccessPatterns(
            completionRate: participants.count > 0 ? Double(completed.count) / Double(participants.count) : 0.0,
            averageProgress: participants.isEmpty ? 0.0 : participants.reduce(0) { $0 + $1.progress } / Double(participants.count),
            dropoffRate: participants.count > 0 ? Double(notStarted.count) / Double(participants.count) : 0.0,
            engagementScore: calculateEngagementScore(participants)
        )
    }
    
    private func calculateEngagementScore(_ participants: [CommunityParticipant]) -> Double {
        // Score basé sur : progression, badges, streaks
        var totalScore = 0.0
        
        for participant in participants {
            var score = participant.progress * 100 // 0-100 points pour la progression
            score += Double(participant.badges.count * 10) // 10 points par badge
            score += Double(participant.streakCount * 5) // 5 points par jour de streak
            
            totalScore += score
        }
        
        return participants.isEmpty ? 0.0 : totalScore / Double(participants.count)
    }
    
    // MARK: - Challenge Performance Analysis
    
    private func analyzeChallengePerformance(_ documents: [QueryDocumentSnapshot]) async {
        var categoryPerformance: [CommunityCategory: ChallengePerformance] = [:]
        var difficultyPerformance: [CommunityDifficulty: ChallengePerformance] = [:]
        
        for document in documents {
            let data = document.data()
            
            guard let categoryRaw = data["category"] as? String,
                  let category = CommunityCategory(rawValue: categoryRaw),
                  let difficultyRaw = data["difficulty"] as? String,
                  let difficulty = CommunityDifficulty(rawValue: difficultyRaw),
                  let participantCount = data["participantCount"] as? Int,
                  let maxParticipants = data["maxParticipants"] as? Int else {
                continue
            }
            
            // Calculer les métriques de performance
            let fillRate = Double(participantCount) / Double(maxParticipants)
            
            // Analyser par catégorie
            if categoryPerformance[category] == nil {
                categoryPerformance[category] = ChallengePerformance(
                    totalChallenges: 0,
                    averageFillRate: 0.0,
                    averageCompletionRate: 0.0,
                    popularityScore: 0.0
                )
            }
            
            categoryPerformance[category]!.totalChallenges += 1
            categoryPerformance[category]!.averageFillRate += fillRate
            
            // Analyser par difficulté
            if difficultyPerformance[difficulty] == nil {
                difficultyPerformance[difficulty] = ChallengePerformance(
                    totalChallenges: 0,
                    averageFillRate: 0.0,
                    averageCompletionRate: 0.0,
                    popularityScore: 0.0
                )
            }
            
            difficultyPerformance[difficulty]!.totalChallenges += 1
            difficultyPerformance[difficulty]!.averageFillRate += fillRate
        }
        
        // Normaliser les moyennes
        for (category, performance) in categoryPerformance {
            categoryPerformance[category]!.averageFillRate = performance.averageFillRate / Double(performance.totalChallenges)
            categoryPerformance[category]!.popularityScore = calculatePopularityScore(performance)
        }
        
        await MainActor.run {
            analyticsData.categoryPerformance = categoryPerformance
            analyticsData.difficultyPerformance = difficultyPerformance
        }
    }
    
    private func calculatePopularityScore(_ performance: ChallengePerformance) -> Double {
        // Score basé sur le nombre de défis et le taux de remplissage
        let volumeScore = min(Double(performance.totalChallenges) / 10.0, 1.0) // Max 1.0 à 10+ défis
        let fillScore = performance.averageFillRate // 0.0 - 1.0
        
        return (volumeScore + fillScore) / 2.0
    }
    
    // MARK: - Predictive Analytics
    
    func predictOptimalChallengeTime() async -> (day: Int, hour: Int) {
        // Analyser les patterns historiques pour prédire le meilleur moment
        let dayStats = analyticsData.dailyParticipation
        let hourStats = analyticsData.hourlyParticipation
        
        let optimalDay = dayStats.max { $0.value < $1.value }?.key ?? 2 // Défaut: Lundi
        let optimalHour = hourStats.max { $0.value < $1.value }?.key ?? 9 // Défaut: 9h
        
        return (day: optimalDay, hour: optimalHour)
    }
    
    func predictChallengeSuccess(_ challenge: GeneratedChallenge) async -> Double {
        // Prédire le succès d'un défi basé sur l'historique
        var score = 0.5 // Score de base
        
        // Facteur catégorie
        if let categoryPerf = analyticsData.categoryPerformance[challenge.category] {
            score += categoryPerf.popularityScore * 0.3
        }
        
        // Facteur difficulté
        if let difficultyPerf = analyticsData.difficultyPerformance[challenge.difficulty] {
            score += difficultyPerf.averageFillRate * 0.2
        }
        
        // Facteur temporel
        let dayOfWeek = Calendar.current.component(.weekday, from: challenge.startDate)
        let hour = Calendar.current.component(.hour, from: challenge.startDate)
        
        if analyticsData.dailyParticipation[dayOfWeek] ?? 0 > 5 { // Jour populaire
            score += 0.15
        }
        
        if analyticsData.hourlyParticipation[hour] ?? 0 > 3 { // Heure populaire
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Insights Generation
    
    func generateCommunityInsights() async -> [CommunityInsight] {
        var insights: [CommunityInsight] = []
        
        // Insight sur la participation
        let metrics = await getCommunityMetrics()
        if metrics.recentSuccessRate > 0.7 {
            insights.append(CommunityInsight(
                type: .positive,
                title: "🔥 Communauté en Feu !",
                description: "Taux de succès exceptionnel de \(Int(metrics.recentSuccessRate * 100))% cette semaine !",
                actionable: false
            ))
        } else if metrics.recentSuccessRate < 0.3 {
            insights.append(CommunityInsight(
                type: .warning,
                title: "⚠️ Défis Trop Difficiles ?",
                description: "Taux de succès faible (\(Int(metrics.recentSuccessRate * 100))%). Peut-être proposer des défis plus accessibles ?",
                actionable: true
            ))
        }
        
        // Insight sur les catégories populaires
        if let mostPopular = metrics.popularCategories.first {
            insights.append(CommunityInsight(
                type: .info,
                title: "📈 Tendance : \(mostPopular.displayName)",
                description: "La catégorie la plus populaire cette semaine. Plus de défis similaires arrivent !",
                actionable: false
            ))
        }
        
        // Insight sur l'engagement
        if analyticsData.successPatterns.engagementScore > 200 {
            insights.append(CommunityInsight(
                type: .positive,
                title: "🎯 Engagement Élevé",
                description: "Score d'engagement de \(Int(analyticsData.successPatterns.engagementScore)). La communauté est très active !",
                actionable: false
            ))
        }
        
        return insights
    }
    
    // MARK: - Data Recording
    
    func recordChallengeGeneration(count: Int, context: GenerationContext) async {
        let record: [String: Any] = [
            "generatedCount": count,
            "dayOfWeek": context.dayOfWeek,
            "hour": context.hour,
            "isWeekend": context.isWeekend,
            "season": context.season.rawValue,
            "timestamp": Timestamp(date: Date()),
            "communityActiveUsers": context.communityMetrics.activeUsers,
            "communitySuccessRate": context.communityMetrics.recentSuccessRate
        ]
        
        do {
            try await db.collection("analytics_generation").document().setData(record)
        } catch {
            print("❌ [ANALYTICS] Error recording generation: \(error)")
        }
    }
    
    func recordUserAction(_ action: UserAction, userId: String, additionalData: [String: Any] = [:]) async {
        var actionData: [String: Any] = [
            "action": action.rawValue,
            "userId": userId,
            "timestamp": Timestamp(date: Date())
        ]
        
        actionData.merge(additionalData) { _, new in new }
        
        do {
            try await db.collection("analytics_actions").document().setData(actionData)
        } catch {
            print("❌ [ANALYTICS] Error recording action: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    private func invalidateCache() {
        userStatsCache.removeAll()
        communityMetricsCache = nil
        lastCacheUpdate = Date.distantPast
    }
    
    private func updateCommunityMetrics(_ participants: [CommunityParticipant]) async {
        // Force un refresh des métriques si beaucoup de changements
        if participants.count > 10 {
            communityMetricsCache = nil
        }
    }
    
    private func storeAnalyticsInsights() async {
        // Convertir les dictionnaires en format sérialisable
        let hourlyData: [String: Int] = analyticsData.hourlyParticipation.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
        
        let dailyData: [String: Int] = analyticsData.dailyParticipation.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
        
        let insights: [String: Any] = [
            "hourlyParticipation": hourlyData,
            "dailyParticipation": dailyData,
            "successRate": analyticsData.successPatterns.completionRate,
            "engagementScore": analyticsData.successPatterns.engagementScore,
            "updatedAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("analytics_insights").document("community").setData(insights)
        } catch {
            print("❌ [ANALYTICS] Error storing insights: \(error)")
        }
    }
}

// MARK: - Supporting Data Structures

struct AnalyticsData {
    var hourlyParticipation: [Int: Int] = [:]
    var dailyParticipation: [Int: Int] = [:]
    var successPatterns: SuccessPatterns = SuccessPatterns()
    var categoryPerformance: [CommunityCategory: ChallengePerformance] = [:]
    var difficultyPerformance: [CommunityDifficulty: ChallengePerformance] = [:]
}

struct SuccessPatterns {
    var completionRate: Double = 0.0
    var averageProgress: Double = 0.0
    var dropoffRate: Double = 0.0
    var engagementScore: Double = 0.0
}

struct ChallengePerformance {
    var totalChallenges: Int
    var averageFillRate: Double
    var averageCompletionRate: Double
    var popularityScore: Double
}

struct CommunityInsight {
    let type: InsightType
    let title: String
    let description: String
    let actionable: Bool
}

enum InsightType {
    case positive, warning, info, critical
}

enum UserAction: String, CaseIterable {
    case joinChallenge = "join_challenge"
    case leaveChallenge = "leave_challenge"
    case completeChallenge = "complete_challenge"
    case viewChallenge = "view_challenge"
    case sendMessage = "send_message"
    case likeMessage = "like_message"
    case shareChallenge = "share_challenge"
    case openApp = "open_app"
    case appBlocked = "app_blocked"
}