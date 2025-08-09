//
//  CommunityModels.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import Foundation
import SwiftUI

// MARK: - Community Challenge

struct CommunityChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let startDate: Date
    let endDate: Date
    let participantCount: Int
    let maxParticipants: Int
    let suggestedApps: [String]
    let category: CommunityCategory
    let difficulty: CommunityDifficulty
    let reward: CommunityReward
    var participants: [CommunityParticipant] = [] // Non-Codable, chargé séparément
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, startDate, endDate
        case participantCount, maxParticipants, suggestedApps
        case category, difficulty, reward
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var timeRemaining: TimeInterval {
        max(0, endDate.timeIntervalSince(Date()))
    }
    
    var timeRemainingFormatted: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: Date(), to: endDate) ?? "Terminé"
    }
    
    var formattedParticipants: String {
        return "\(participantCount)/\(maxParticipants) participants"
    }
}

// MARK: - Community Message

struct CommunityMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let content: String
    let timestamp: Date
    let challengeId: String
    let likes: Int
    let replies: [CommunityMessage]
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Community Discussion

struct CommunityDiscussion: Identifiable, Codable {
    let id: String
    let challengeId: String
    let title: String
    let participantCount: Int
    let lastActivity: Date
    let messages: [CommunityMessage]
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Community User Stats

struct CommunityUserStats: Identifiable, Codable {
    let id: String = UUID().uuidString
    let userId: String
    let username: String
    let totalPoints: Int
    let completedChallenges: Int
    let rank: Int
    let badges: [String]
    let joinDate: Date
}

// MARK: - Community Reward

struct CommunityReward: Codable {
    let points: Int
    let badge: String
    let title: String
}

// MARK: - Community Category

enum CommunityCategory: String, CaseIterable, Codable {
    case productivity = "productivity"
    case social = "social"
    case entertainment = "entertainment"
    case wellness = "wellness"
    case focus = "focus"
    
    var displayName: String {
        switch self {
        case .productivity: return "Productivité"
        case .social: return "Réseaux Sociaux"
        case .entertainment: return "Divertissement"
        case .wellness: return "Bien-être"
        case .focus: return "Concentration"
        }
    }
    
    var color: Color {
        switch self {
        case .productivity: return .blue
        case .social: return .green
        case .entertainment: return .purple
        case .wellness: return .orange
        case .focus: return .cyan
        }
    }
    
    var icon: String {
        switch self {
        case .productivity: return "briefcase.fill"
        case .social: return "person.3.fill"
        case .entertainment: return "gamecontroller.fill"
        case .wellness: return "heart.fill"
        case .focus: return "target"
        }
    }
}

// MARK: - Community Difficulty

enum CommunityDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "star"
        case .medium: return "star.fill"
        case .hard: return "flame.fill"
        }
    }
}

// MARK: - Community Participant

struct CommunityParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let joinedAt: Date
    let progress: Double
    let isCompleted: Bool
    let rank: Int
    let badges: [String]
    let streakCount: Int
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var formattedJoinDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: joinedAt, relativeTo: Date())
    }
    
    var statusText: String {
        if isCompleted {
            return "Terminé"
        } else if progress > 0 {
            return "En cours"
        } else {
            return "Pas commencé"
        }
    }
    
    var statusColor: Color {
        if isCompleted {
            return .green
        } else if progress > 0 {
            return .orange
        } else {
            return .gray
        }
    }
}