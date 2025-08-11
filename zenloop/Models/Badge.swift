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
        case .common: return String(localized: "rarity_common")
        case .rare: return String(localized: "rarity_rare")
        case .epic: return String(localized: "rarity_epic")
        case .legendary: return String(localized: "rarity_legendary")
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
            return String(localized: "requirement_complete_challenges", defaultValue: "Complete \(count) challenges", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(count)")
        case .totalFocusTime(let seconds):
            let hours = Int(seconds) / 3600
            return String(localized: "requirement_accumulate_focus_hours", defaultValue: "Accumulate \(hours)h of focus", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(hours)")
        case .consecutiveDays(let days):
            return String(localized: "requirement_consecutive_days", defaultValue: "\(days) consecutive days", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(days)")
        case .perfectWeek:
            return String(localized: "requirement_perfect_week")
        case .nightOwl:
            return String(localized: "requirement_challenge_after_10pm")
        case .earlyBird:
            return String(localized: "requirement_challenge_before_6am")
        case .marathon(let seconds):
            let hours = Int(seconds) / 3600
            return String(localized: "requirement_challenge_duration_hours", defaultValue: "\(hours)h+ challenge", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(hours)")
        case .multipleApps(let count):
            return String(localized: "requirement_block_apps", defaultValue: "Block \(count)+ apps", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(count)")
        case .firstChallenge:
            return String(localized: "requirement_first_challenge")
        case .speedster(let count):
            return String(localized: "requirement_challenges_in_24h", defaultValue: "\(count) challenges in 24h", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%d", with: "\(count)")
        }
    }
}

// MARK: - Badge Manager

@MainActor
class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    
    @Published var unlockedBadges: Set<String> = []
    @Published var recentlyUnlocked: [Badge] = []
    
    private var allBadges: [Badge] {
        return [
        // Badges de débutant
        Badge(id: "first_challenge", title: String(localized: "badge_first_step"), description: String(localized: "badge_first_step_desc"), 
              icon: "star.fill", color: .bronze, requirement: .firstChallenge, rarity: .common),
        
        Badge(id: "5_challenges", title: String(localized: "badge_regular"), description: String(localized: "badge_regular_desc"), 
              icon: "flame.fill", color: .bronze, requirement: .challengesCompleted(5), rarity: .common),
        
        Badge(id: "25_challenges", title: String(localized: "badge_determined"), description: String(localized: "badge_determined_desc"), 
              icon: "bolt.fill", color: .silver, requirement: .challengesCompleted(25), rarity: .rare),
        
        Badge(id: "100_challenges", title: String(localized: "badge_champion"), description: String(localized: "badge_champion_desc"), 
              icon: "crown.fill", color: .gold, requirement: .challengesCompleted(100), rarity: .epic),
        
        // Badges de temps
        Badge(id: "10h_focus", title: String(localized: "badge_focused"), description: String(localized: "badge_focused_desc"), 
              icon: "clock.fill", color: .bronze, requirement: .totalFocusTime(36000), rarity: .common),
        
        Badge(id: "50h_focus", title: String(localized: "badge_focus_master"), description: String(localized: "badge_focus_master_desc"), 
              icon: "brain.head.profile", color: .silver, requirement: .totalFocusTime(180000), rarity: .rare),
        
        Badge(id: "200h_focus", title: String(localized: "badge_concentration_guru"), description: String(localized: "badge_concentration_guru_desc"), 
              icon: "infinity", color: .gold, requirement: .totalFocusTime(720000), rarity: .epic),
        
        // Badges spéciaux
        Badge(id: "night_owl", title: String(localized: "badge_night_owl"), description: String(localized: "badge_night_owl_desc"), 
              icon: "moon.stars.fill", color: .diamond, requirement: .nightOwl, rarity: .rare),
        
        Badge(id: "early_bird", title: String(localized: "badge_early_bird"), description: String(localized: "badge_early_bird_desc"), 
              icon: "sunrise.fill", color: .diamond, requirement: .earlyBird, rarity: .rare),
        
        Badge(id: "marathon_3h", title: String(localized: "badge_marathoner"), description: String(localized: "badge_marathoner_desc"), 
              icon: "figure.run", color: .gold, requirement: .marathon(10800), rarity: .epic),
        
        Badge(id: "perfect_week", title: String(localized: "badge_perfect_week"), description: String(localized: "badge_perfect_week_desc"), 
              icon: "checkmark.seal.fill", color: .rainbow, requirement: .perfectWeek, rarity: .legendary),
        
        Badge(id: "app_master", title: String(localized: "badge_blocking_master"), description: String(localized: "badge_blocking_master_desc"), 
              icon: "shield.fill", color: .diamond, requirement: .multipleApps(10), rarity: .epic),
        
        Badge(id: "speedster", title: String(localized: "badge_speedster"), description: String(localized: "badge_speedster_desc"), 
              icon: "speedometer", color: .rainbow, requirement: .speedster(5), rarity: .legendary)
        ]
    }
    
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
    
    func getBadge(id: String) -> Badge? {
        return allBadges.first { $0.id == id }
    }
    
    func getUnlockedBadges() -> [Badge] {
        return allBadges.filter { unlockedBadges.contains($0.id) }
    }
    
    func getAllBadges() -> [Badge] {
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