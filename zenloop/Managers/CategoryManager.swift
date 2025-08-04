//
//  CategoryManager.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import FamilyControls

@MainActor
class CategoryManager: ObservableObject {
    @Published var categories: [AppCategory] = []
    @Published var availableChallenges: [CategoryChallenge] = []
    @Published var isInitialized = false
    
    private let userDefaults = UserDefaults.standard
    private let categoriesKey = "zenloop_app_categories"
    private let challengesKey = "zenloop_category_challenges"
    
    static let shared = CategoryManager()
    
    private init() {
        loadCategories()
        loadChallenges() // Charger les challenges sauvegardés
        generateDefaultChallenges()
        isInitialized = true
        print("🎯 [CATEGORY_MANAGER] Initialisé avec \(categories.count) catégories")
    }
    
    // MARK: - Category Management
    
    func setupDefaultCategories() {
        print("🎯 [CATEGORY_MANAGER] Configuration des catégories par défaut")
        
        if categories.isEmpty {
            categories = AppCategory.defaultCategories
            saveCategories()
            print("✅ [CATEGORY_MANAGER] \(categories.count) catégories créées")
        }
    }
    
    func updateCategorySelection(_ categoryId: String, selection: FamilyActivitySelection) {
        print("📱 [CATEGORY_MANAGER] Mise à jour catégorie: \(categoryId)")
        
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index].updateSelection(selection)
            saveCategories()
            
            // Régénérer les défis pour cette catégorie
            generateChallengesForCategory(categories[index])
            saveChallenges() // Sauvegarder les nouveaux challenges
            
            print("✅ [CATEGORY_MANAGER] Catégorie \(categories[index].name) configurée avec \(categories[index].selectedAppsCount) apps")
            
            // Notifier les vues du changement
            objectWillChange.send()
        }
    }
    
    func getCategoryById(_ id: String) -> AppCategory? {
        return categories.first { $0.id == id }
    }
    
    var configuredCategories: [AppCategory] {
        return categories.filter { $0.isReadyForChallenges }
    }
    
    var unconfiguredCategories: [AppCategory] {
        return categories.filter { !$0.isConfigured }
    }
    
    // MARK: - Challenge Generation
    
    private func generateDefaultChallenges() {
        print("⚡ [CATEGORY_MANAGER] Génération des défis par défaut")
        
        // Ne supprimer que si pas de challenges sauvegardés
        let hasExistingChallenges = !availableChallenges.isEmpty
        
        if !hasExistingChallenges {
            availableChallenges.removeAll()
            
            for category in categories.filter({ $0.isReadyForChallenges }) {
                generateChallengesForCategory(category)
            }
            
            saveChallenges()
        }
        
        print("🎯 [CATEGORY_MANAGER] \(availableChallenges.count) défis disponibles")
    }
    
    private func generateChallengesForCategory(_ category: AppCategory) {
        let categoryName = category.name
        let baseChallenges: [(TimeInterval, DifficultyLevel, String)] = [
            (1 * 3600, .easy, "🥉"),      // 1h - Bronze
            (4 * 3600, .medium, "🥈"),    // 4h - Argent  
            (8 * 3600, .hard, "🥇"),      // 8h - Or
        ]
        
        // Supprimer les anciens défis de cette catégorie
        availableChallenges.removeAll { $0.categoryId == category.id }
        
        // Créer les nouveaux défis
        for (duration, difficulty, badge) in baseChallenges {
            let challenge = CategoryChallenge(
                categoryId: category.id,
                title: "0 \(categoryName.split(separator: " ").first ?? "") - \(formatDuration(duration))",
                duration: duration,
                difficulty: difficulty,
                badge: badge,
                description: "Défi sans \(categoryName.lowercased()) pendant \(formatDuration(duration))"
            )
            availableChallenges.append(challenge)
        }
        
        print("⚡ [CATEGORY_MANAGER] 3 défis créés pour \(categoryName)")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        return "\(hours)h"
    }
    
    // MARK: - Challenge Launch
    
    func startCategoryChallenge(_ challenge: CategoryChallenge, zenloopManager: ZenloopManager) {
        print("🚀 [CATEGORY_MANAGER] Lancement défi: \(challenge.title)")
        
        guard let category = getCategoryById(challenge.categoryId) else {
            print("⚠️ [CATEGORY_MANAGER] Catégorie introuvable: \(challenge.categoryId)")
            return
        }
        
        guard category.isReadyForChallenges else {
            print("⚠️ [CATEGORY_MANAGER] Catégorie non configurée: \(category.name)")
            return
        }
        
        // Convertir la sélection vers FamilyActivitySelection
        let selection = category.selectedApps.toFamilyActivitySelection()
        
        // Démarrer le défi via ZenloopManager
        zenloopManager.startCustomChallenge(
            title: challenge.title,
            duration: challenge.duration,
            difficulty: challenge.difficulty,
            apps: selection
        )
        
        print("✅ [CATEGORY_MANAGER] Défi \(challenge.title) démarré")
    }
    
    // MARK: - Statistics
    
    func getChallengesForCategory(_ categoryId: String) -> [CategoryChallenge] {
        return availableChallenges.filter { $0.categoryId == categoryId }
    }
    
    var totalConfiguredApps: Int {
        return categories.reduce(0) { $0 + $1.selectedAppsCount }
    }
    
    // MARK: - Persistence
    
    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)
            print("💾 [CATEGORY_MANAGER] Catégories sauvegardées")
        } catch {
            print("❌ [CATEGORY_MANAGER] Erreur sauvegarde catégories: \(error)")
        }
    }
    
    private func loadCategories() {
        guard let data = userDefaults.data(forKey: categoriesKey) else {
            print("📂 [CATEGORY_MANAGER] Aucune catégorie sauvegardée - création par défaut")
            setupDefaultCategories()
            return
        }
        
        do {
            categories = try JSONDecoder().decode([AppCategory].self, from: data)
            print("📂 [CATEGORY_MANAGER] \(categories.count) catégories chargées")
        } catch {
            print("❌ [CATEGORY_MANAGER] Erreur chargement catégories: \(error)")
            setupDefaultCategories()
        }
    }
    
    private func saveChallenges() {
        do {
            let data = try JSONEncoder().encode(availableChallenges)
            userDefaults.set(data, forKey: challengesKey)
            print("💾 [CATEGORY_MANAGER] Défis sauvegardés")
        } catch {
            print("❌ [CATEGORY_MANAGER] Erreur sauvegarde défis: \(error)")
        }
    }
    
    private func loadChallenges() {
        guard let data = userDefaults.data(forKey: challengesKey) else {
            print("📂 [CATEGORY_MANAGER] Aucun défi sauvegardé")
            return
        }
        
        do {
            availableChallenges = try JSONDecoder().decode([CategoryChallenge].self, from: data)
            print("📂 [CATEGORY_MANAGER] \(availableChallenges.count) défis chargés")
        } catch {
            print("❌ [CATEGORY_MANAGER] Erreur chargement défis: \(error)")
        }
    }
    
    // MARK: - Refresh Data
    
    func refreshData() {
        loadCategories()
        loadChallenges()
        generateDefaultChallenges()
        objectWillChange.send()
        print("🔄 [CATEGORY_MANAGER] Données rechargées")
    }
    
    // MARK: - Debug
    
    func printStatus() {
        print("📊 [CATEGORY_MANAGER] Status:")
        print("  - Catégories: \(categories.count)")
        print("  - Configurées: \(configuredCategories.count)")
        print("  - Défis: \(availableChallenges.count)")
        print("  - Apps totales: \(totalConfiguredApps)")
    }
}