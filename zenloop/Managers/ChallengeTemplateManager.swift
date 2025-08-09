//
//  ChallengeTemplateManager.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import Foundation

// MARK: - Intelligent Challenge Template System

class ChallengeTemplateManager: ObservableObject {
    static let shared = ChallengeTemplateManager()
    
    private var allTemplates: [ChallengeTemplate] = []
    
    private init() {
        loadTemplateLibrary()
    }
    
    // MARK: - Template Library
    
    private func loadTemplateLibrary() {
        allTemplates = [
            // MARK: - Productivity Templates (Lundi)
            ChallengeTemplate(
                id: "prod_monday_focus",
                title: "[DAY] Power Focus",
                description: "Démarre ta semaine en beauté ! Bloque tes apps de distraction pendant 4h pour une matinée ultra-productive. 🚀\n\nParfait pour : Terminer ce projet important, préparer tes objectifs de la semaine, ou simplement retrouver ta concentration.",
                category: .productivity,
                baseDifficulty: .medium,
                baseDuration: 4 * 3600, // 4 heures
                baseCapacity: 12,
                baseRewardPoints: 80,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "Twitter", "YouTube", "Snapchat"],
                rewardBadges: ["⚡", "🎯", "💪"],
                optimalDays: [2], // Lundi
                optimalHours: [6, 7, 8, 9],
                contextTags: ["morning", "work", "focus", "productivity"]
            ),
            
            ChallengeTemplate(
                id: "prod_deep_work",
                title: "Deep Work Session",
                description: "Plonge dans un travail profond sans distraction. 3h de focus pur pour accomplir l'impossible ! 🎯\n\nIdéal pour : Projets créatifs, apprentissage, résolution de problèmes complexes.",
                category: .productivity,
                baseDifficulty: .hard,
                baseDuration: 3 * 3600,
                baseCapacity: 8,
                baseRewardPoints: 120,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "YouTube", "Reddit", "LinkedIn"],
                rewardBadges: ["🧠", "💎", "🏆"],
                optimalDays: [2, 3, 4], // Lundi-Mercredi
                optimalHours: [8, 9, 10, 14, 15],
                contextTags: ["deep_work", "productivity", "focus"]
            ),
            
            // MARK: - Social Detox Templates (Vendredi)
            ChallengeTemplate(
                id: "social_friday_detox",
                title: "Vendredi Détox Social",
                description: "Libère-toi des réseaux sociaux avant le weekend ! 6h sans scrolling pour retrouver le vrai monde. 🌟\n\nTu vas redécouvrir : Les conversations réelles, tes hobbies oubliés, et cette sensation de calme mental.",
                category: .social,
                baseDifficulty: .medium,
                baseDuration: 6 * 3600,
                baseCapacity: 15,
                baseRewardPoints: 90,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "Twitter", "Snapchat", "LinkedIn"],
                rewardBadges: ["🌟", "💫", "🦋"],
                optimalDays: [6], // Vendredi
                optimalHours: [12, 13, 14, 15, 16],
                contextTags: ["social_detox", "weekend_prep", "mental_health"]
            ),
            
            ChallengeTemplate(
                id: "social_connection_real",
                title: "Connexion Réelle",
                description: "Challenge : passe 4h à créer de vraies connexions ! Appelle un ami, rencontre quelqu'un, ou écris une vraie lettre. 💝\n\nObjectif : Remplacer les likes virtuels par des sourires réels.",
                category: .social,
                baseDifficulty: .easy,
                baseDuration: 4 * 3600,
                baseCapacity: 20,
                baseRewardPoints: 60,
                suggestedApps: ["Instagram", "Facebook", "Twitter", "Snapchat", "TikTok"],
                rewardBadges: ["💝", "🤗", "🌈"],
                optimalDays: [5, 6, 7], // Jeudi-Dimanche
                optimalHours: [16, 17, 18, 19],
                contextTags: ["social_connection", "real_world", "relationships"]
            ),
            
            // MARK: - Weekend Digital Detox
            ChallengeTemplate(
                id: "weekend_full_detox",
                title: "[SEASON] Weekend Liberté",
                description: "Le défi ultime : 24h complètement déconnecté ! Redécouvre le plaisir simple d'exister sans écran. 🌅\n\nTu vas vivre : Des moments magiques, une créativité débordante, et un sommeil réparateur comme jamais.",
                category: .wellness,
                baseDifficulty: .hard,
                baseDuration: 24 * 3600,
                baseCapacity: 8,
                baseRewardPoints: 200,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "Twitter", "YouTube", "Snapchat", "Reddit", "LinkedIn"],
                rewardBadges: ["🏆", "🌅", "💎"],
                optimalDays: [7, 1], // Samedi-Dimanche
                optimalHours: [6, 7, 8],
                contextTags: ["digital_detox", "weekend", "wellness", "freedom"]
            ),
            
            ChallengeTemplate(
                id: "weekend_nature_connect",
                title: "Weekend Nature",
                description: "Échange tes écrans contre la nature ! 8h dehors sans apps pour te reconnecter à l'essentiel. 🌲\n\nAu programme : Balade, pique-nique, lecture sous un arbre, ou simplement respirer l'air pur.",
                category: .wellness,
                baseDifficulty: .medium,
                baseDuration: 8 * 3600,
                baseCapacity: 12,
                baseRewardPoints: 100,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "YouTube", "Twitter"],
                rewardBadges: ["🌲", "🌸", "🦋"],
                optimalDays: [7, 1], // Weekend
                optimalHours: [8, 9, 10, 14],
                contextTags: ["nature", "outdoor", "weekend", "wellness"]
            ),
            
            // MARK: - Midweek Balance Templates
            ChallengeTemplate(
                id: "midweek_balance",
                title: "Mercredi Équilibre",
                description: "Milieu de semaine = temps de rééquilibrage ! 5h sans distractions pour retrouver ton centre. ⚖️\n\nParfait pour : Méditation, yoga, lecture, ou simplement faire le point sur tes objectifs.",
                category: .wellness,
                baseDifficulty: .medium,
                baseDuration: 5 * 3600,
                baseCapacity: 10,
                baseRewardPoints: 75,
                suggestedApps: ["Instagram", "TikTok", "YouTube", "Facebook", "Twitter"],
                rewardBadges: ["⚖️", "🧘", "🌟"],
                optimalDays: [4], // Mercredi
                optimalHours: [12, 13, 14, 18, 19],
                contextTags: ["balance", "midweek", "mindfulness"]
            ),
            
            // MARK: - Evening / Sleep Templates
            ChallengeTemplate(
                id: "evening_digital_sunset",
                title: "Coucher de Soleil Digital",
                description: "Éteins tes écrans 2h avant le coucher pour un sommeil de rêve ! Ta mélatonine va te remercier. 🌙\n\nBénéfices : Endormissement plus rapide, sommeil plus profond, réveil plus énergique.",
                category: .wellness,
                baseDifficulty: .easy,
                baseDuration: 2 * 3600,
                baseCapacity: 25,
                baseRewardPoints: 40,
                suggestedApps: ["Instagram", "TikTok", "YouTube", "Facebook", "Twitter", "Reddit"],
                rewardBadges: ["🌙", "😴", "✨"],
                optimalDays: [1, 2, 3, 4, 5], // Dimanche-Jeudi
                optimalHours: [20, 21, 22],
                contextTags: ["sleep", "evening", "health", "routine"]
            ),
            
            ChallengeTemplate(
                id: "evening_mindful_wind_down",
                title: "Soirée Zen",
                description: "Transforme ta soirée en rituel de bien-être ! 3h sans écran pour te préparer à une nuit paisible. 🕯️\n\nActivités suggérées : Bain relaxant, lecture, journal intime, étirements doux.",
                category: .wellness,
                baseDifficulty: .medium,
                baseDuration: 3 * 3600,
                baseCapacity: 15,
                baseRewardPoints: 65,
                suggestedApps: ["Instagram", "TikTok", "YouTube", "Facebook", "Twitter", "Snapchat"],
                rewardBadges: ["🕯️", "🛁", "📚"],
                optimalDays: [1, 2, 3, 4, 5, 6, 7],
                optimalHours: [19, 20, 21],
                contextTags: ["mindful", "evening", "relaxation", "self_care"]
            ),
            
            // MARK: - Focus Templates
            ChallengeTemplate(
                id: "focus_morning_ritual",
                title: "Rituel Matinal Focus",
                description: "Commence ta journée sans distraction ! 2h de matin sacré pour définir tes intentions. ☀️\n\nPourquoi ça marche : Ton cerveau est frais, ta willpower au max, et tu donnes le ton pour toute la journée.",
                category: .focus,
                baseDifficulty: .easy,
                baseDuration: 2 * 3600,
                baseCapacity: 20,
                baseRewardPoints: 50,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "YouTube", "Twitter"],
                rewardBadges: ["☀️", "🎯", "💪"],
                optimalDays: [1, 2, 3, 4, 5, 6, 7],
                optimalHours: [6, 7, 8, 9],
                contextTags: ["morning", "ritual", "focus", "intention"]
            ),
            
            ChallengeTemplate(
                id: "focus_creative_flow",
                title: "Flow Créatif",
                description: "Libère ta créativité ! 4h sans interruption pour créer, inventer, imaginer. L'art de la concentration pure. 🎨\n\nParfait pour : Écriture, dessin, musique, coding, ou tout projet créatif qui t'attend.",
                category: .focus,
                baseDifficulty: .medium,
                baseDuration: 4 * 3600,
                baseCapacity: 12,
                baseRewardPoints: 85,
                suggestedApps: ["Instagram", "TikTok", "YouTube", "Facebook", "Twitter", "Reddit"],
                rewardBadges: ["🎨", "✨", "🌟"],
                optimalDays: [3, 4, 6, 7], // Mardi, Mercredi, Vendredi, Samedi
                optimalHours: [9, 10, 14, 15, 16],
                contextTags: ["creativity", "flow", "focus", "art"]
            ),
            
            // MARK: - Entertainment Detox Templates
            ChallengeTemplate(
                id: "entertainment_mindful_break",
                title: "Pause Divertissement Consciente",
                description: "Stop aux vidéos infinies ! 6h sans contenu passif pour redécouvrir les plaisirs actifs. 🎭\n\nAlternatives : Jouer d'un instrument, cuisiner, jardiner, faire du sport, apprendre quelque chose de nouveau.",
                category: .entertainment,
                baseDifficulty: .medium,
                baseDuration: 6 * 3600,
                baseCapacity: 18,
                baseRewardPoints: 70,
                suggestedApps: ["YouTube", "TikTok", "Netflix", "Instagram", "Twitch", "Reddit"],
                rewardBadges: ["🎭", "🎪", "🌈"],
                optimalDays: [6, 7], // Vendredi-Samedi
                optimalHours: [14, 15, 16, 17],
                contextTags: ["entertainment", "active", "mindful", "hobby"]
            ),
            
            // MARK: - Winter Seasonal Templates
            ChallengeTemplate(
                id: "winter_cocooning_detox",
                title: "Cocooning Hivernal",
                description: "L'hiver parfait pour se reconnecter à soi ! 8h sans écran pour créer ton cocon de bien-être. ❄️\n\nAmbiance : Thé chaud, plaid, livre, musique douce, et cette sensation unique de paix hivernale.",
                category: .wellness,
                baseDifficulty: .easy,
                baseDuration: 8 * 3600,
                baseCapacity: 15,
                baseRewardPoints: 90,
                suggestedApps: ["Instagram", "TikTok", "Facebook", "YouTube", "Twitter"],
                rewardBadges: ["❄️", "🏠", "☕"],
                optimalDays: [6, 7], // Weekend
                optimalHours: [10, 11, 14, 15],
                contextTags: ["winter", "cocooning", "self_care", "hygge"],
                seasonal: .winter
            ),
            
            ChallengeTemplate(
                id: "winter_warm_connections",
                title: "Connexions Chaleureuses",
                description: "L'hiver, c'est fait pour se rapprocher ! 5h à cultiver la chaleur humaine sans écrans froids. 🔥\n\nIdées : Appeler famille/amis, écrire des cartes, préparer un repas ensemble, jouer à des jeux de société.",
                category: .social,
                baseDifficulty: .easy,
                baseDuration: 5 * 3600,
                baseCapacity: 20,
                baseRewardPoints: 60,
                suggestedApps: ["Instagram", "Facebook", "Twitter", "TikTok", "Snapchat"],
                rewardBadges: ["🔥", "💝", "🤗"],
                optimalDays: [6, 7, 1], // Weekend + Dimanche
                optimalHours: [15, 16, 17, 18],
                contextTags: ["winter", "connections", "warmth", "family"],
                seasonal: .winter
            )
        ]
        
        print("📚 [TEMPLATES] Loaded \(allTemplates.count) challenge templates")
    }
    
    // MARK: - Template Retrieval by Category
    
    func getProductivityTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { $0.category == .productivity }
    }
    
    func getSocialDetoxTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { $0.category == .social }
    }
    
    func getDigitalDetoxTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("digital_detox") || 
            $0.contextTags.contains("weekend") 
        }
    }
    
    func getBalanceTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("balance") || 
            $0.contextTags.contains("midweek") 
        }
    }
    
    func getMindfulnessTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("mindfulness") || 
            $0.contextTags.contains("mindful") 
        }
    }
    
    func getWeekendPrepTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("weekend_prep") || 
            $0.optimalDays.contains(6) 
        }
    }
    
    func getOutdoorTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("outdoor") || 
            $0.contextTags.contains("nature") 
        }
    }
    
    func getSleepTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("sleep") || 
            $0.contextTags.contains("evening") 
        }
    }
    
    func getEveningTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("evening") || 
            $0.optimalHours.contains(where: { $0 >= 18 }) 
        }
    }
    
    func getMotivationTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { 
            $0.contextTags.contains("morning") && 
            $0.optimalDays.contains(2) // Lundi
        }
    }
    
    func getWinterTemplates() -> [ChallengeTemplate] {
        return allTemplates.filter { $0.seasonal == .winter }
    }
    
    // MARK: - Smart Template Selection
    
    func getTemplatesForContext(
        dayOfWeek: Int,
        hour: Int,
        season: Season
    ) -> [ChallengeTemplate] {
        return allTemplates.filter { template in
            // Vérifier le jour optimal
            let dayMatch = template.optimalDays.isEmpty || template.optimalDays.contains(dayOfWeek)
            
            // Vérifier l'heure optimale (avec tolérance de 2h)
            let hourMatch = template.optimalHours.isEmpty || 
                            template.optimalHours.contains { abs($0 - hour) <= 2 }
            
            // Vérifier la saison
            let seasonMatch = template.seasonal == nil || template.seasonal == season
            
            return dayMatch && hourMatch && seasonMatch
        }
    }
    
    func getTemplateById(_ id: String) -> ChallengeTemplate? {
        return allTemplates.first { $0.id == id }
    }
    
    func getAllTemplates() -> [ChallengeTemplate] {
        return allTemplates
    }
    
    // MARK: - Template Analytics
    
    func getTemplateStats() -> TemplateStats {
        return TemplateStats(
            totalTemplates: allTemplates.count,
            categoriesCount: Dictionary(grouping: allTemplates, by: { $0.category })
                .mapValues { $0.count },
            avgDuration: allTemplates.map { $0.baseDuration }.reduce(0, +) / TimeInterval(allTemplates.count),
            difficultyDistribution: Dictionary(grouping: allTemplates, by: { $0.baseDifficulty })
                .mapValues { $0.count }
        )
    }
}

// MARK: - Challenge Template Data Structure

struct ChallengeTemplate: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: CommunityCategory
    let baseDifficulty: CommunityDifficulty
    let baseDuration: TimeInterval
    let baseCapacity: Int
    let baseRewardPoints: Int
    let suggestedApps: [String]
    let rewardBadges: [String]
    let optimalDays: [Int] // 1-7 (Dimanche-Samedi)
    let optimalHours: [Int] // 0-23
    let contextTags: [String]
    let seasonal: Season?
    
    init(
        id: String,
        title: String,
        description: String,
        category: CommunityCategory,
        baseDifficulty: CommunityDifficulty,
        baseDuration: TimeInterval,
        baseCapacity: Int,
        baseRewardPoints: Int,
        suggestedApps: [String],
        rewardBadges: [String],
        optimalDays: [Int],
        optimalHours: [Int],
        contextTags: [String],
        seasonal: Season? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.baseDifficulty = baseDifficulty
        self.baseDuration = baseDuration
        self.baseCapacity = baseCapacity
        self.baseRewardPoints = baseRewardPoints
        self.suggestedApps = suggestedApps
        self.rewardBadges = rewardBadges
        self.optimalDays = optimalDays
        self.optimalHours = optimalHours
        self.contextTags = contextTags
        self.seasonal = seasonal
    }
}

// MARK: - Template Statistics

struct TemplateStats {
    let totalTemplates: Int
    let categoriesCount: [CommunityCategory: Int]
    let avgDuration: TimeInterval
    let difficultyDistribution: [CommunityDifficulty: Int]
}