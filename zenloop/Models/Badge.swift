//
//  Badge.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: BadgeColor
    let requirement: BadgeRequirement
    let rarity: BadgeRarity
    var unlockedAt: Date?
    
    var isUnlocked: Bool {
        unlockedAt != nil
    }
}

enum BadgeColor: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver" 
    case gold = "gold"
    case diamond = "diamond"
    case rainbow = "rainbow"
    
    var color: Color {
        switch self {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        case .rainbow: return .purple
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .bronze:
            return LinearGradient(colors: [.brown, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .silver:
            return LinearGradient(colors: [.gray, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diamond:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rainbow:
            return LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

enum BadgeRarity: String, Codable, CaseIterable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var title: String {
        switch self {
        case .common: return "Commun"
        case .rare: return "Rare"
        case .epic: return "Épique"
        case .legendary: return "Légendaire"
        }
    }
}

enum BadgeRequirement: Codable, Hashable {
    case challengesCompleted(Int)
    case totalFocusTime(TimeInterval) // en secondes
    case consecutiveDays(Int)
    case perfectWeek
    case nightOwl // défi après 22h
    case earlyBird // défi avant 6h
    case marathon(TimeInterval) // défi de plus de X heures
    case multipleApps(Int) // bloquer X apps en même temps
    case firstChallenge
    case speedster(Int) // X défis en 24h
    
    var description: String {
        switch self {
        case .challengesCompleted(let count):
            return "Termine \(count) défis"
        case .totalFocusTime(let seconds):
            let hours = Int(seconds) / 3600
            return "Accumule \(hours)h de focus"
        case .consecutiveDays(let days):
            return "\(days) jours consécutifs"
        case .perfectWeek:
            return "Une semaine parfaite"
        case .nightOwl:
            return "Défi après 22h"
        case .earlyBird:
            return "Défi avant 6h"
        case .marathon(let seconds):
            let hours = Int(seconds) / 3600
            return "Défi de \(hours)h+"
        case .multipleApps(let count):
            return "Bloque \(count)+ apps"
        case .firstChallenge:
            return "Premier défi"
        case .speedster(let count):
            return "\(count) défis en 24h"
        }
    }
}

// MARK: - Badge Manager

@MainActor
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    
    @Published var unlockedBadges: Set<String> = []
    @Published var recentlyUnlocked: [Badge] = []
    
    private let allBadges: [Badge] = [
        // Badges de débutant
        Badge(id: "first_challenge", title: "Premier Pas", description: "Ton premier défi terminé !", 
              icon: "star.fill", color: .bronze, requirement: .firstChallenge, rarity: .common),
        
        Badge(id: "5_challenges", title: "Régulier", description: "5 défis terminés", 
              icon: "flame.fill", color: .bronze, requirement: .challengesCompleted(5), rarity: .common),
        
        Badge(id: "25_challenges", title: "Déterminé", description: "25 défis terminés", 
              icon: "bolt.fill", color: .silver, requirement: .challengesCompleted(25), rarity: .rare),
        
        Badge(id: "100_challenges", title: "Champion", description: "100 défis terminés", 
              icon: "crown.fill", color: .gold, requirement: .challengesCompleted(100), rarity: .epic),
        
        // Badges de temps
        Badge(id: "10h_focus", title: "Concentré", description: "10 heures de focus total", 
              icon: "clock.fill", color: .bronze, requirement: .totalFocusTime(36000), rarity: .common),
        
        Badge(id: "50h_focus", title: "Maître du Focus", description: "50 heures de focus total", 
              icon: "brain.head.profile", color: .silver, requirement: .totalFocusTime(180000), rarity: .rare),
        
        Badge(id: "200h_focus", title: "Guru de la Concentration", description: "200 heures de focus total", 
              icon: "infinity", color: .gold, requirement: .totalFocusTime(720000), rarity: .epic),
        
        // Badges spéciaux
        Badge(id: "night_owl", title: "Chouette de Nuit", description: "Défi terminé après 22h", 
              icon: "moon.stars.fill", color: .diamond, requirement: .nightOwl, rarity: .rare),
        
        Badge(id: "early_bird", title: "Lève-tôt", description: "Défi terminé avant 6h", 
              icon: "sunrise.fill", color: .diamond, requirement: .earlyBird, rarity: .rare),
        
        Badge(id: "marathon_3h", title: "Marathonien", description: "Défi de 3 heures", 
              icon: "figure.run", color: .gold, requirement: .marathon(10800), rarity: .epic),
        
        Badge(id: "perfect_week", title: "Semaine Parfaite", description: "7 jours consécutifs", 
              icon: "checkmark.seal.fill", color: .rainbow, requirement: .perfectWeek, rarity: .legendary),
        
        Badge(id: "app_master", title: "Maître du Blocage", description: "Bloque 10+ apps simultanément", 
              icon: "shield.fill", color: .diamond, requirement: .multipleApps(10), rarity: .epic),
        
        Badge(id: "speedster", title: "Speedster", description: "5 défis en 24h", 
              icon: "speedometer", color: .rainbow, requirement: .speedster(5), rarity: .legendary)
    ]
    
    private init() {
        loadUnlockedBadges()
    }
    
    nonisolated func checkForNewBadges(zenloopManager: ZenloopManager) {
        Task { @MainActor in
            for badge in allBadges {
                if !unlockedBadges.contains(badge.id) && shouldUnlockBadge(badge, zenloopManager: zenloopManager) {
                    unlockBadge(badge)
                }
            }
        }
    }
    
    private nonisolated func shouldUnlockBadge(_ badge: Badge, zenloopManager: ZenloopManager) -> Bool {
        switch badge.requirement {
        case .firstChallenge:
            return zenloopManager.completedChallengesCount >= 1
        case .challengesCompleted(let count):
            return zenloopManager.completedChallengesCount >= count
        case .totalFocusTime(let requiredSeconds):
            return zenloopManager.totalFocusTime >= requiredSeconds
        case .nightOwl:
            return checkNightOwlBadge(zenloopManager: zenloopManager)
        case .earlyBird:
            return checkEarlyBirdBadge(zenloopManager: zenloopManager)
        case .marathon(let minDuration):
            return checkMarathonBadge(minDuration: minDuration, zenloopManager: zenloopManager)
        case .multipleApps(let minCount):
            return zenloopManager.maxAppsBlockedSimultaneously >= minCount
        case .perfectWeek:
            return checkPerfectWeekBadge(zenloopManager: zenloopManager)
        case .consecutiveDays(let days):
            return zenloopManager.currentStreak >= days
        case .speedster(let count):
            return checkSpeedsterBadge(count: count, zenloopManager: zenloopManager)
        }
    }
    
    @MainActor
    private func unlockBadge(_ badge: Badge) {
        unlockedBadges.insert(badge.id)
        recentlyUnlocked.append(badge)
        saveUnlockedBadges()
        
        // Supprimer des récents après 5 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.recentlyUnlocked.removeAll { $0.id == badge.id }
        }
    }
    
    nonisolated func getBadge(id: String) -> Badge? {
        return allBadges.first { $0.id == id }
    }
    
    func getUnlockedBadges() -> [Badge] {
        return allBadges.filter { unlockedBadges.contains($0.id) }
    }
    
    nonisolated func getAllBadges() -> [Badge] {
        return allBadges
    }
    
    // MARK: - Persistence
    
    private func loadUnlockedBadges() {
        if let data = UserDefaults.standard.data(forKey: "unlocked_badges"),
           let badges = try? JSONDecoder().decode(Set<String>.self, from: data) {
            unlockedBadges = badges
        }
    }
    
    private func saveUnlockedBadges() {
        if let data = try? JSONEncoder().encode(unlockedBadges) {
            UserDefaults.standard.set(data, forKey: "unlocked_badges")
        }
    }
    
    // MARK: - Badge Checkers
    
    private nonisolated func checkNightOwlBadge(zenloopManager: ZenloopManager) -> Bool {
        // Logique pour vérifier les défis terminés après 22h
        return false // À implémenter
    }
    
    private nonisolated func checkEarlyBirdBadge(zenloopManager: ZenloopManager) -> Bool {
        // Logique pour vérifier les défis terminés avant 6h
        return false // À implémenter
    }
    
    private nonisolated func checkMarathonBadge(minDuration: TimeInterval, zenloopManager: ZenloopManager) -> Bool {
        // Logique pour vérifier les défis longs
        return false // À implémenter
    }
    
    private nonisolated func checkPerfectWeekBadge(zenloopManager: ZenloopManager) -> Bool {
        // Logique pour vérifier 7 jours consécutifs
        return false // À implémenter
    }
    
    private nonisolated func checkSpeedsterBadge(count: Int, zenloopManager: ZenloopManager) -> Bool {
        // Logique pour vérifier X défis en 24h
        return false // À implémenter
    }
}