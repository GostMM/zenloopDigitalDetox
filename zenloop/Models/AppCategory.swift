//
//  AppCategory.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - App Category Model

struct AppCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let color: CodableColor
    let description: String
    let suggestedApps: [String] // Bundle IDs suggérés
    var selectedApps: CodableFamilyActivitySelection
    var isConfigured: Bool = false
    let createdAt: Date
    
    init(id: String, name: String, icon: String, color: Color, description: String, suggestedApps: [String] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = CodableColor(color)
        self.description = description
        self.suggestedApps = suggestedApps
        self.selectedApps = CodableFamilyActivitySelection()
        self.isConfigured = false
        self.createdAt = Date()
    }
    
    // Nombre d'apps sélectionnées
    var selectedAppsCount: Int {
        return selectedApps.applicationCount + selectedApps.categoryCount + selectedApps.webDomainCount
    }
    
    // Vérifie si la catégorie est prête pour les défis
    var isReadyForChallenges: Bool {
        return isConfigured && selectedAppsCount > 0
    }
    
    // Met à jour la sélection d'apps
    mutating func updateSelection(_ selection: FamilyActivitySelection) {
        self.selectedApps = CodableFamilyActivitySelection(selection)
        self.isConfigured = selectedApps.applicationCount > 0 || selectedApps.categoryCount > 0 || selectedApps.webDomainCount > 0
    }
}

// MARK: - Category Challenge Model

struct CategoryChallenge: Identifiable, Codable {
    let id: String
    let categoryId: String
    let title: String
    let duration: TimeInterval
    let difficulty: DifficultyLevel
    let badge: String
    let description: String
    let createdAt: Date
    
    init(categoryId: String, title: String, duration: TimeInterval, difficulty: DifficultyLevel, badge: String, description: String) {
        self.id = UUID().uuidString
        self.categoryId = categoryId
        self.title = title
        self.duration = duration
        self.difficulty = difficulty
        self.badge = badge
        self.description = description
        self.createdAt = Date()
    }
    
    // Formatage de durée
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Codable Family Activity Selection

struct CodableFamilyActivitySelection: Codable {
    // Stocker directement la FamilyActivitySelection encodée
    private var encodedSelection: Data?
    
    // Counts pour compatibilité et performance
    var applicationCount: Int = 0
    var categoryCount: Int = 0
    var webDomainCount: Int = 0
    
    init() {}
    
    init(_ selection: FamilyActivitySelection) {
        // Encoder directement FamilyActivitySelection qui est Codable
        do {
            let encoder = JSONEncoder()
            self.encodedSelection = try encoder.encode(selection)
            
            // Mettre à jour les counts
            self.applicationCount = selection.applicationTokens.count
            self.categoryCount = selection.categoryTokens.count
            self.webDomainCount = selection.webDomainTokens.count
            
            print("✅ [CODABLE_SELECTION] Sélection encodée: \(applicationCount) apps, \(categoryCount) catégories")
        } catch {
            print("❌ [CODABLE_SELECTION] Erreur encodage: \(error)")
            self.encodedSelection = nil
        }
    }
    
    // Conversion vers FamilyActivitySelection
    func toFamilyActivitySelection() -> FamilyActivitySelection {
        guard let data = encodedSelection else {
            print("⚠️ [CODABLE_SELECTION] Aucune sélection encodée")
            return FamilyActivitySelection()
        }
        
        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
            print("✅ [CODABLE_SELECTION] Sélection décodée: \(selection.applicationTokens.count) apps")
            return selection
        } catch {
            print("❌ [CODABLE_SELECTION] Erreur décodage: \(error)")
            return FamilyActivitySelection()
        }
    }
    
    var isEmpty: Bool {
        return applicationCount == 0 && categoryCount == 0 && webDomainCount == 0
    }
    
    // Méthodes utilitaires
    func hasApplications() -> Bool {
        return applicationCount > 0
    }
    
    func hasCategories() -> Bool {
        return categoryCount > 0
    }
    
    func hasWebDomains() -> Bool {
        return webDomainCount > 0
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case encodedSelection, applicationCount, categoryCount, webDomainCount
    }
}

// MARK: - Predefined Categories

extension AppCategory {
    static let defaultCategories: [AppCategory] = [
        AppCategory(
            id: "ai_productivity",
            name: "IA & Productivité",
            icon: "brain.head.profile",
            color: .purple,
            description: "Apps d'intelligence artificielle et d'assistance",
            suggestedApps: ["com.openai.chat", "com.anthropic.claude", "com.notion.id"]
        ),
        
        AppCategory(
            id: "social_media",
            name: "Réseaux Sociaux",
            icon: "person.2.fill",
            color: .pink,
            description: "Plateformes sociales et messagerie",
            suggestedApps: ["com.burbn.instagram", "com.zhiliaoapp.musically", "com.twitter.twitter"]
        ),
        
        AppCategory(
            id: "games_entertainment",
            name: "Jeux & Entertainment",
            icon: "gamecontroller.fill",
            color: .orange,
            description: "Jeux vidéo et divertissement",
            suggestedApps: ["com.supercell.clashroyale", "com.king.candycrushsaga", "com.netflix.Netflix"]
        )
    ]
}