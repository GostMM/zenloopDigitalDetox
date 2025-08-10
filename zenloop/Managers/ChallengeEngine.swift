//
//  ChallengeEngine.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import Foundation
import FirebaseFirestore
import Combine

// MARK: - Challenge Generation Intelligence

class ChallengeEngine: ObservableObject {
    static let shared = ChallengeEngine()
    
    private let db = Firestore.firestore()
    private let analytics = CommunityAnalytics.shared
    private let participationIntelligence = ParticipationIntelligence.shared
    private let templateManager = ChallengeTemplateManager.shared
    
    @Published var isGenerating = false
    @Published var nextChallengeSchedule: Date?
    @Published var generatedChallengesCount = 0
    
    private var generationTimer: Timer?
    
    private init() {
        setupAutomaticGeneration()
    }
    
    // MARK: - Automatic Challenge Generation
    
    private func setupAutomaticGeneration() {
        // Planifier la génération automatique quotidienne à 6h du matin
        scheduleNextGeneration()
        
        // Timer de vérification toutes les heures
        generationTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.checkAndGenerateChallenges()
            }
        }
        
        print("🤖 [ENGINE] Automatic challenge generation initialized")
    }
    
    private func scheduleNextGeneration() {
        let calendar = Calendar.current
        let now = Date()
        
        // Prochaine génération à 6h du matin
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0
        
        var nextGeneration = calendar.date(from: components) ?? now
        
        // Si c'est déjà passé aujourd'hui, programmer pour demain
        if nextGeneration <= now {
            nextGeneration = calendar.date(byAdding: .day, value: 1, to: nextGeneration) ?? now
        }
        
        nextChallengeSchedule = nextGeneration
        print("⏰ [ENGINE] Next challenge generation scheduled for: \(nextGeneration)")
    }
    
    func checkAndGenerateChallenges() async {
        let calendar = Calendar.current
        let now = Date()
        
        // Vérifier s'il faut générer des défis
        guard let scheduledTime = nextChallengeSchedule,
              now >= scheduledTime else {
            return
        }
        
        print("🚀 [ENGINE] Starting automatic challenge generation...")
        await generateDailyChallenges()
        
        // Planifier la prochaine génération
        scheduleNextGeneration()
    }
    
    // MARK: - Smart Challenge Generation
    
    func generateDailyChallenges() async {
        isGenerating = true
        
        let context = await buildGenerationContext()
        let templates = await selectOptimalTemplates(for: context)
        
        var generatedCount = 0
        
        for template in templates {
            let challenge = await generateChallengeFromTemplate(template, context: context)
            let success = await saveChallengeToFirebase(challenge)
            
            if success {
                generatedCount += 1
                
                // Notifier les utilisateurs potentiellement intéressés
                await notifyRelevantUsers(for: challenge)
            }
            
            // Délai entre les générations pour éviter le spam
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconde
        }
        
        await MainActor.run {
            self.generatedChallengesCount += generatedCount
            self.isGenerating = false
        }
        
        print("✅ [ENGINE] Generated \(generatedCount) new challenges")
        
        // Analyser et optimiser les futures générations
        await analytics.recordChallengeGeneration(count: generatedCount, context: context)
    }
    
    // MARK: - Context Analysis
    
    private func buildGenerationContext() async -> GenerationContext {
        let calendar = Calendar.current
        let now = Date()
        
        let dayOfWeek = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7 // Dimanche ou Samedi
        
        let userStats = await analytics.getCurrentUserStats()
        let communityMetrics = await analytics.getCommunityMetrics()
        let popularApps = await analytics.getMostBlockedApps()
        
        let context = GenerationContext(
            dayOfWeek: dayOfWeek,
            hour: hour,
            isWeekend: isWeekend,
            season: getCurrentSeason(),
            userStats: userStats,
            communityMetrics: communityMetrics,
            popularApps: popularApps,
            weatherContext: await getWeatherContext()
        )
        
        print("📊 [ENGINE] Generation context: Day=\(dayOfWeek), Hour=\(hour), Weekend=\(isWeekend), Season=\(context.season), ActiveUsers=\(communityMetrics.activeUsers)")
        
        return context
    }
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .spring
        }
    }
    
    private func getWeatherContext() async -> WeatherContext {
        // En production, intégrer une API météo
        // Pour maintenant, simuler selon la saison
        return WeatherContext(
            condition: .clear,
            temperature: 20.0,
            isRainy: false
        )
    }
    
    // MARK: - Template Selection
    
    private func selectOptimalTemplates(for context: GenerationContext) async -> [ChallengeTemplate] {
        var selectedTemplates: [ChallengeTemplate] = []
        
        // Logique de sélection intelligente selon le contexte
        
        // Lundi : Focus productivité et motivation
        if context.dayOfWeek == 2 && context.hour >= 6 && context.hour <= 10 {
            selectedTemplates.append(contentsOf: templateManager.getProductivityTemplates())
            selectedTemplates.append(contentsOf: templateManager.getMotivationTemplates())
        }
        
        // Mercredi : Défis milieu de semaine, équilibre
        else if context.dayOfWeek == 4 {
            selectedTemplates.append(contentsOf: templateManager.getBalanceTemplates())
            selectedTemplates.append(contentsOf: templateManager.getMindfulnessTemplates())
        }
        
        // Vendredi : Préparation weekend, détox social
        else if context.dayOfWeek == 6 {
            selectedTemplates.append(contentsOf: templateManager.getSocialDetoxTemplates())
            selectedTemplates.append(contentsOf: templateManager.getWeekendPrepTemplates())
        }
        
        // Weekend : Digital detox complet, activités physiques
        else if context.isWeekend {
            selectedTemplates.append(contentsOf: templateManager.getDigitalDetoxTemplates())
            selectedTemplates.append(contentsOf: templateManager.getOutdoorTemplates())
        }
        
        // Soirée : Défis de sommeil et réduction d'écran
        if context.hour >= 18 {
            selectedTemplates.append(contentsOf: templateManager.getSleepTemplates())
            selectedTemplates.append(contentsOf: templateManager.getEveningTemplates())
        }
        
        // Saison spéciale
        if context.season == .winter {
            selectedTemplates.append(contentsOf: templateManager.getWinterTemplates())
        }
        
        // Fallback général : Si aucun template sélectionné par les règles spécifiques
        if selectedTemplates.isEmpty {
            print("⚠️ [ENGINE] No specific templates found, adding general templates")
            selectedTemplates.append(contentsOf: templateManager.getAllTemplates().shuffled().prefix(5))
        }
        
        print("🎯 [ENGINE] Selected \(selectedTemplates.count) templates before optimization")
        
        // Filtrer et optimiser la sélection
        selectedTemplates = await optimizeTemplateSelection(selectedTemplates, context: context)
        
        // Limiter à 2-4 défis par jour pour éviter la surcharge
        let maxChallenges = context.isWeekend ? 2 : 3
        let finalTemplates = Array(selectedTemplates.prefix(maxChallenges))
        
        // Fallback : Si aucun template sélectionné, prendre des templates de base
        if finalTemplates.isEmpty {
            print("⚠️ [ENGINE] No templates selected, using fallback templates")
            let fallbackTemplates = templateManager.getAllTemplates().shuffled().prefix(2)
            return Array(fallbackTemplates)
        }
        
        return finalTemplates
    }
    
    private func optimizeTemplateSelection(_ templates: [ChallengeTemplate], context: GenerationContext) async -> [ChallengeTemplate] {
        var optimized: [ChallengeTemplate] = []
        
        // Pour l'initialisation (première fois), être plus permissif
        let isInitialGeneration = context.communityMetrics.activeUsers == 0
        
        for template in templates {
            // Vérifier si un défi similaire existe déjà récemment
            let hasRecent = await hasRecentSimilarChallenge(template)
            if hasRecent && !isInitialGeneration { continue }
            
            // Analyser la pertinence pour les utilisateurs actuels
            let relevanceScore = await calculateRelevanceScore(template, context: context)
            let minScore = isInitialGeneration ? 0.3 : 0.6 // Seuil plus bas pour l'initialisation
            if relevanceScore < minScore { continue }
            
            // Vérifier la capacité de participation de la communauté
            let communityCapacity = await estimateCommunityCapacity(for: template)
            let minCapacity = isInitialGeneration ? 1 : 2 // Plus permissif pour l'initialisation
            if communityCapacity < minCapacity { continue }
            
            optimized.append(template)
        }
        
        // Calculer les scores et trier
        var templatesWithScores: [(ChallengeTemplate, Double)] = []
        for template in optimized {
            let score = await calculateRelevanceScore(template, context: context)
            templatesWithScores.append((template, score))
        }
        
        // Trier par score de pertinence
        return templatesWithScores.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
    
    // MARK: - Challenge Generation
    
    private func generateChallengeFromTemplate(_ template: ChallengeTemplate, context: GenerationContext) async -> GeneratedChallenge {
        let challengeId = UUID().uuidString
        
        // Personnaliser selon le contexte
        let personalizedTitle = personalizeTitle(template.title, context: context)
        let personalizedDescription = personalizeDescription(template.description, context: context)
        let suggestedApps = await selectRelevantApps(for: template, context: context)
        let duration = calculateOptimalDuration(template: template, context: context)
        let difficulty = calculateOptimalDifficulty(template: template, context: context)
        let maxParticipants = calculateOptimalCapacity(template: template, context: context)
        
        let startDate = calculateStartDate(context: context)
        let endDate = Calendar.current.date(byAdding: .second, value: Int(duration), to: startDate) ?? startDate
        
        return GeneratedChallenge(
            id: challengeId,
            title: personalizedTitle,
            description: personalizedDescription,
            startDate: startDate,
            endDate: endDate,
            maxParticipants: maxParticipants,
            suggestedApps: suggestedApps,
            category: template.category,
            difficulty: difficulty,
            reward: generateReward(for: template, difficulty: difficulty),
            templateId: template.id,
            generationContext: context
        )
    }
    
    // MARK: - Personalization Algorithms
    
    private func personalizeTitle(_ baseTitle: String, context: GenerationContext) -> String {
        var title = baseTitle
        
        // Personnalisation selon le jour
        if context.dayOfWeek == 2 { // Lundi
            title = title.replacingOccurrences(of: "[DAY]", with: "Lundi Motivation")
        } else if context.isWeekend {
            title = title.replacingOccurrences(of: "[DAY]", with: "Weekend Zen")
        }
        
        // Personnalisation selon la saison
        switch context.season {
        case .winter:
            title = title.replacingOccurrences(of: "[SEASON]", with: "Hiver Cocooning")
        case .summer:
            title = title.replacingOccurrences(of: "[SEASON]", with: "Été Actif")
        default:
            title = title.replacingOccurrences(of: "[SEASON]", with: "")
        }
        
        return title
    }
    
    private func personalizeDescription(_ baseDescription: String, context: GenerationContext) -> String {
        var description = baseDescription
        
        // Ajouter du contexte temporel
        if context.isWeekend {
            description += "\n\n🌅 Profite du weekend pour te reconnecter avec ce qui compte vraiment."
        } else if context.dayOfWeek == 2 {
            description += "\n\n💪 Démarre cette semaine avec motivation et intention !"
        }
        
        return description
    }
    
    private func calculateOptimalDuration(template: ChallengeTemplate, context: GenerationContext) -> TimeInterval {
        var baseDuration = template.baseDuration
        
        // Adapter selon le jour
        if context.isWeekend {
            baseDuration *= 1.5 // Week-ends plus longs
        } else if context.dayOfWeek == 2 { // Lundi
            baseDuration *= 0.8 // Lundi plus court pour encourager
        }
        
        // Adapter selon l'heure
        if context.hour >= 18 {
            baseDuration *= 0.7 // Défis du soir plus courts
        }
        
        return baseDuration
    }
    
    private func calculateOptimalDifficulty(template: ChallengeTemplate, context: GenerationContext) -> CommunityDifficulty {
        var difficulty = template.baseDifficulty
        
        // Analyser les performances récentes de la communauté
        let recentSuccessRate = context.communityMetrics.recentSuccessRate
        
        if recentSuccessRate < 0.3 {
            // Si peu de succès récents, réduire la difficulté
            switch difficulty {
            case .hard: difficulty = .medium
            case .medium: difficulty = .easy
            case .easy: break
            }
        } else if recentSuccessRate > 0.8 {
            // Si beaucoup de succès, augmenter la difficulté
            switch difficulty {
            case .easy: difficulty = .medium
            case .medium: difficulty = .hard
            case .hard: break
            }
        }
        
        return difficulty
    }
    
    // MARK: - Utility Functions
    
    private func hasRecentSimilarChallenge(_ template: ChallengeTemplate) async -> Bool {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        
        do {
            let snapshot = try await db.collection("challenges")
                .whereField("templateId", isEqualTo: template.id)
                .whereField("startDate", isGreaterThan: Timestamp(date: twoDaysAgo))
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }
    
    private func calculateRelevanceScore(_ template: ChallengeTemplate, context: GenerationContext) async -> Double {
        var score = 0.5 // Base score
        
        // Bonus selon le jour de la semaine
        if template.optimalDays.contains(context.dayOfWeek) {
            score += 0.3
        }
        
        // Bonus selon l'heure
        if template.optimalHours.contains(context.hour) {
            score += 0.2
        }
        
        // Bonus selon les apps populaires
        let commonApps = Set(template.suggestedApps).intersection(Set(context.popularApps))
        score += Double(commonApps.count) * 0.1
        
        return min(score, 1.0)
    }
    
    private func estimateCommunityCapacity(for template: ChallengeTemplate) async -> Int {
        // Simuler une estimation basée sur l'historique
        return Int.random(in: 3...15)
    }
    
    private func selectRelevantApps(for template: ChallengeTemplate, context: GenerationContext) async -> [String] {
        var apps = template.suggestedApps
        
        // Prioriser les apps populaires dans la communauté
        let popularApps = context.popularApps.prefix(3)
        apps.append(contentsOf: popularApps)
        
        // Retirer les doublons et limiter
        return Array(Set(apps)).prefix(6).shuffled()
    }
    
    private func calculateStartDate(context: GenerationContext) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Démarrer dans 30 minutes à 2 heures
        let delayMinutes = Int.random(in: 30...120)
        return calendar.date(byAdding: .minute, value: delayMinutes, to: now) ?? now
    }
    
    private func calculateOptimalCapacity(template: ChallengeTemplate, context: GenerationContext) -> Int {
        var capacity = template.baseCapacity
        
        // Adapter selon le jour
        if context.isWeekend {
            capacity = Int(Double(capacity) * 1.3) // Plus de monde le weekend
        }
        
        // Adapter selon les métriques communautaires
        if context.communityMetrics.activeUsers > 50 {
            capacity = Int(Double(capacity) * 1.2)
        }
        
        return max(capacity, 5) // Minimum 5 places
    }
    
    private func generateReward(for template: ChallengeTemplate, difficulty: CommunityDifficulty) -> CommunityReward {
        let basePoints = template.baseRewardPoints
        
        let multiplier: Double = switch difficulty {
        case .easy: 1.0
        case .medium: 1.5
        case .hard: 2.0
        }
        
        let finalPoints = Int(Double(basePoints) * multiplier)
        
        return CommunityReward(
            points: finalPoints,
            badge: selectRewardBadge(for: template, difficulty: difficulty),
            title: generateRewardTitle(for: template, points: finalPoints)
        )
    }
    
    private func selectRewardBadge(for template: ChallengeTemplate, difficulty: CommunityDifficulty) -> String {
        let badges = template.rewardBadges
        
        switch difficulty {
        case .easy:
            return badges.first ?? "🌟"
        case .medium:
            return badges.count > 1 ? badges[1] : "🏆"
        case .hard:
            return badges.last ?? "💎"
        }
    }
    
    private func generateRewardTitle(for template: ChallengeTemplate, points: Int) -> String {
        switch points {
        case 0..<50:
            return "Explorateur Digital"
        case 50..<100:
            return "Maître du Focus"
        case 100..<200:
            return "Champion Zen"
        default:
            return "Légende du Détox"
        }
    }
    
    // MARK: - Firebase Operations
    
    private func saveChallengeToFirebase(_ challenge: GeneratedChallenge) async -> Bool {
        let challengeData: [String: Any] = [
            "id": challenge.id,
            "title": challenge.title,
            "description": challenge.description,
            "startDate": Timestamp(date: challenge.startDate),
            "endDate": Timestamp(date: challenge.endDate),
            "participantCount": 0,
            "maxParticipants": challenge.maxParticipants,
            "suggestedApps": challenge.suggestedApps,
            "category": challenge.category.rawValue,
            "difficulty": challenge.difficulty.rawValue,
            "rewardPoints": challenge.reward.points,
            "rewardBadge": challenge.reward.badge,
            "rewardTitle": challenge.reward.title,
            "templateId": challenge.templateId,
            "isGenerated": true,
            "generatedAt": Timestamp(date: Date()),
            "generationContext": [
                "dayOfWeek": challenge.generationContext.dayOfWeek,
                "hour": challenge.generationContext.hour,
                "isWeekend": challenge.generationContext.isWeekend,
                "season": challenge.generationContext.season.rawValue
            ]
        ]
        
        do {
            try await db.collection("challenges").document(challenge.id).setData(challengeData)
            return true
        } catch {
            print("❌ [ENGINE] Failed to save challenge: \(error)")
            return false
        }
    }
    
    private func notifyRelevantUsers(for challenge: GeneratedChallenge) async {
        let relevantUsers = await participationIntelligence.findRelevantUsers(for: challenge)
        
        for userId in relevantUsers {
            await SmartNotificationManager.shared.sendChallengeRecommendation(
                userId: userId,
                challenge: challenge
            )
        }
    }
    
    // MARK: - Public Interface
    
    func generateChallengeNow() async {
        await generateDailyChallenges()
    }
    
    func getGenerationStats() -> (scheduled: Date?, generated: Int) {
        return (nextChallengeSchedule, generatedChallengesCount)
    }
    
    deinit {
        generationTimer?.invalidate()
    }
}

// MARK: - Supporting Data Structures

struct GenerationContext {
    let dayOfWeek: Int
    let hour: Int
    let isWeekend: Bool
    let season: Season
    let userStats: CommunityUserStats
    let communityMetrics: CommunityMetrics
    let popularApps: [String]
    let weatherContext: WeatherContext
}

struct GeneratedChallenge {
    let id: String
    let title: String
    let description: String
    let startDate: Date
    let endDate: Date
    let maxParticipants: Int
    let suggestedApps: [String]
    let category: CommunityCategory
    let difficulty: CommunityDifficulty
    let reward: CommunityReward
    let templateId: String
    let generationContext: GenerationContext
}

enum Season: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
}

struct WeatherContext {
    let condition: WeatherCondition
    let temperature: Double
    let isRainy: Bool
}

enum WeatherCondition {
    case clear, cloudy, rainy, stormy
}

// UserStats is now CommunityUserStats - removed duplicate

struct CommunityMetrics {
    let activeUsers: Int
    let recentSuccessRate: Double
    let popularCategories: [CommunityCategory]
    let averageParticipation: Int
}

*/