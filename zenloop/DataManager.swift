//
//  DataManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import Foundation
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var userStats = UserStats()
    @Published var completedChallenges: [Challenge] = []
    @Published var availableChallenges: [Challenge] = []
    @Published var achievements: [Achievement] = []
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadData()
        setupDefaultChallenges()
        setupDefaultAchievements()
    }
    
    // MARK: - Data Persistence
    
    func saveData() {
        // Sauvegarder les stats utilisateur
        if let userData = try? JSONEncoder().encode(userStats) {
            userDefaults.set(userData, forKey: "userStats")
        }
        
        // Sauvegarder les défis complétés
        if let challengesData = try? JSONEncoder().encode(completedChallenges) {
            userDefaults.set(challengesData, forKey: "completedChallenges")
        }
        
        // Sauvegarder les succès
        if let achievementsData = try? JSONEncoder().encode(achievements) {
            userDefaults.set(achievementsData, forKey: "achievements")
        }
    }
    
    func loadData() {
        // Charger les stats utilisateur
        if let userData = userDefaults.data(forKey: "userStats"),
           let stats = try? JSONDecoder().decode(UserStats.self, from: userData) {
            userStats = stats
        }
        
        // Charger les défis complétés
        if let challengesData = userDefaults.data(forKey: "completedChallenges"),
           let challenges = try? JSONDecoder().decode([Challenge].self, from: challengesData) {
            completedChallenges = challenges
        }
        
        // Charger les succès
        if let achievementsData = userDefaults.data(forKey: "achievements"),
           let loadedAchievements = try? JSONDecoder().decode([Achievement].self, from: achievementsData) {
            achievements = loadedAchievements
        }
    }
    
    // MARK: - Challenge Management
    
    func completeChallenge(_ challenge: Challenge) {
        completedChallenges.append(challenge)
        updateUserStats(for: challenge)
        checkForNewAchievements()
        saveData()
    }
    
    func updateUserStats(for challenge: Challenge) {
        userStats.totalChallengesCompleted += 1
        userStats.totalTimeSaved += challenge.duration
        
        // Mettre à jour la série
        let today = Calendar.current.startOfDay(for: Date())
        if let lastChallengeDate = userStats.lastChallengeDate {
            let lastDate = Calendar.current.startOfDay(for: lastChallengeDate)
            let daysDifference = Calendar.current.dateComponents([.day], from: lastDate, to: today).day ?? 0
            
            if daysDifference == 1 {
                // Série continue
                userStats.currentStreak += 1
            } else if daysDifference > 1 {
                // Série cassée
                userStats.currentStreak = 1
            }
            // Si c'est le même jour, on ne change pas la série
        } else {
            userStats.currentStreak = 1
        }
        
        userStats.lastChallengeDate = Date()
        userStats.bestStreak = max(userStats.bestStreak, userStats.currentStreak)
        
        // Mettre à jour les stats par difficulté
        switch challenge.difficulty {
        case .easy:
            userStats.easyChallengesCompleted += 1
        case .medium:
            userStats.mediumChallengesCompleted += 1
        case .hard:
            userStats.hardChallengesCompleted += 1
        }
    }
    
    func checkForNewAchievements() {
        for achievement in achievements where !achievement.isUnlocked {
            if achievement.checkCondition(userStats) {
                achievement.unlock()
            }
        }
    }
    
    // MARK: - Default Data Setup
    
    func setupDefaultChallenges() {
        if availableChallenges.isEmpty {
            availableChallenges = [
                Challenge(
                    id: "focus-30min",
                    title: "Focus Mode",
                    description: "Méditation de 30 minutes",
                    duration: 30 * 60,
                    blockedApps: [],
                    blockedCategories: [],
                    difficulty: .easy,
                    isActive: false
                ),
                Challenge(
                    id: "productivity-2h",
                    title: "Mode Productivité",
                    description: "Bloquer les réseaux sociaux pendant 2h",
                    duration: 2 * 60 * 60,
                    blockedApps: [],
                    blockedCategories: [],
                    difficulty: .medium,
                    isActive: false
                ),
                Challenge(
                    id: "digital-detox-24h",
                    title: "Détox Digitale",
                    description: "Limiter l'usage du téléphone à 1h/jour",
                    duration: 24 * 60 * 60,
                    blockedApps: [],
                    blockedCategories: [],
                    difficulty: .hard,
                    isActive: false
                ),
                Challenge(
                    id: "reading-focus-30min",
                    title: "Lecture Focus",
                    description: "30 min de lecture sans distraction",
                    duration: 30 * 60,
                    blockedApps: [],
                    blockedCategories: [],
                    difficulty: .easy,
                    isActive: false
                )
            ]
        }
    }
    
    func setupDefaultAchievements() {
        if achievements.isEmpty {
            achievements = [
                Achievement(
                    id: "first-challenge",
                    title: "Premier Défi",
                    description: "Complétez votre premier défi",
                    icon: "star.fill",
                    color: .yellow,
                    condition: { stats in stats.totalChallengesCompleted >= 1 }
                ),
                Achievement(
                    id: "week-streak",
                    title: "Série de 7 jours",
                    description: "Défis quotidiens pendant une semaine",
                    icon: "flame.fill",
                    color: .orange,
                    condition: { stats in stats.currentStreak >= 7 }
                ),
                Achievement(
                    id: "5h-focus",
                    title: "5h Focus",
                    description: "Cumulez 5h de focus en une journée",
                    icon: "clock.fill",
                    color: .blue,
                    condition: { stats in
                        // Logique pour vérifier 5h en une journée
                        return stats.totalTimeSaved >= 5 * 60 * 60
                    }
                ),
                Achievement(
                    id: "productivity-master",
                    title: "Mode Productivité",
                    description: "Complétez 100 défis de productivité",
                    icon: "shield.fill",
                    color: .green,
                    condition: { stats in stats.mediumChallengesCompleted >= 100 }
                ),
                Achievement(
                    id: "zen-master",
                    title: "Maître Zen",
                    description: "Cumulez 50h de méditation",
                    icon: "leaf.fill",
                    color: .purple,
                    condition: { stats in stats.totalTimeSaved >= 50 * 60 * 60 }
                )
            ]
        }
    }
}

// MARK: - Data Models

struct UserStats: Codable {
    var totalChallengesCompleted: Int = 0
    var totalTimeSaved: TimeInterval = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastChallengeDate: Date?
    
    var easyChallengesCompleted: Int = 0
    var mediumChallengesCompleted: Int = 0
    var hardChallengesCompleted: Int = 0
    
    var successRate: Double {
        guard totalChallengesCompleted > 0 else { return 0.0 }
        // Logique simplifiée - dans une vraie app, on tracerait les échecs aussi
        return 0.87 // 87% par défaut
    }
    
    var averageChallengeTime: String {
        guard totalChallengesCompleted > 0 else { return "0 min" }
        let average = totalTimeSaved / Double(totalChallengesCompleted)
        let minutes = Int(average / 60)
        return "\(minutes) min"
    }
    
    var formattedTotalTime: String {
        let hours = Int(totalTimeSaved / 3600)
        let minutes = Int(totalTimeSaved.truncatingRemainder(dividingBy: 3600) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var mostBlockedApps: String {
        // Dans une vraie app, on tracerait les apps les plus bloquées
        return "Instagram, TikTok"
    }
}

class Achievement: Identifiable, Codable, ObservableObject {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: CodableColor
    @Published var isUnlocked: Bool = false
    @Published var unlockedDate: Date?
    
    private let condition: (UserStats) -> Bool
    
    init(id: String, title: String, description: String, icon: String, color: Color, condition: @escaping (UserStats) -> Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.color = CodableColor(color)
        self.condition = condition
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(CodableColor.self, forKey: .color)
        isUnlocked = try container.decode(Bool.self, forKey: .isUnlocked)
        unlockedDate = try container.decodeIfPresent(Date.self, forKey: .unlockedDate)
        
        // Condition par défaut (à améliorer)
        condition = { _ in false }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(isUnlocked, forKey: .isUnlocked)
        try container.encodeIfPresent(unlockedDate, forKey: .unlockedDate)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, icon, color, isUnlocked, unlockedDate
    }
    
    func checkCondition(_ stats: UserStats) -> Bool {
        return condition(stats)
    }
    
    func unlock() {
        isUnlocked = true
        unlockedDate = Date()
    }
}

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        // Conversion simplifiée - dans une vraie app, utilisez UIColor
        self.red = 0.5
        self.green = 0.5
        self.blue = 0.5
        self.alpha = 1.0
    }
    
    var color: Color {
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}