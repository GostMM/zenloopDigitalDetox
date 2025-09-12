//
//  AppRatingManager.swift
//  zenloop
//
//  Created by Claude Code on 07/09/2025.
//

import SwiftUI
import StoreKit

class AppRatingManager: ObservableObject {
    static let shared = AppRatingManager()
    
    // MARK: - UserDefaults Keys
    private let launchCountKey = "zenloop.appLaunchCount"
    private let hasRatedAppKey = "zenloop.hasRatedApp"
    private let dailyRequestCountKey = "zenloop.dailyRequestCount"
    private let lastRequestDateKey = "zenloop.lastRequestDate"
    
    // MARK: - Configuration
    private let requiredLaunchesForRating = 5  // Demander après 5 ouvertures
    private let maxDailyRequests = 3           // Maximum 3 demandes par jour
    private let minHoursBetweenRequests = 8    // Minimum 8h entre les demandes (3x/jour)
    
    private init() {
        print("🌟 [AppRatingManager] Initialized")
    }
    
    // MARK: - Public Methods
    
    /// À appeler à chaque ouverture de l'app
    func recordAppLaunch() {
        let currentCount = getLaunchCount()
        let newCount = currentCount + 1
        
        UserDefaults.standard.set(newCount, forKey: launchCountKey)
        
        print("🌟 [AppRatingManager] App launch #\(newCount)")
        
        // Vérifier si on doit demander une notation
        checkIfShouldRequestRating()
    }
    
    /// Vérifier si on doit afficher la demande de notation
    private func checkIfShouldRequestRating() {
        // Si l'utilisateur a déjà noté, ne plus demander
        if hasRatedApp() {
            return
        }
        
        let launchCount = getLaunchCount()
        
        // Si on n'a pas encore atteint le nombre requis d'ouvertures
        if launchCount < requiredLaunchesForRating {
            return
        }
        
        // À partir de 5 ouvertures, demander jusqu'à 3x par jour
        if canRequestRatingToday() {
            requestNativeRating()
        }
    }
    
    /// Demander la notation via StoreKit natif
    private func requestNativeRating() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ [AppRatingManager] Cannot get window scene for rating request")
            return
        }
        
        // Marquer qu'on a demandé une notation aujourd'hui
        markRatingRequestedToday()
        
        // Demander la notation via StoreKit natif
        DispatchQueue.main.async {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        
        print("🌟 [AppRatingManager] Native rating requested via StoreKit (request #\(getTodayRequestCount()) today)")
    }
    
    // MARK: - Private Methods
    
    private func getLaunchCount() -> Int {
        return UserDefaults.standard.integer(forKey: launchCountKey)
    }
    
    private func hasRatedApp() -> Bool {
        return UserDefaults.standard.bool(forKey: hasRatedAppKey)
    }
    
    /// Vérifier si on peut encore demander une notation aujourd'hui
    private func canRequestRatingToday() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Vérifier si on a déjà fait des demandes aujourd'hui
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let lastRequestDay = Calendar.current.startOfDay(for: lastRequestDate)
            
            // Si c'est le même jour
            if Calendar.current.isDate(today, inSameDayAs: lastRequestDay) {
                let todayCount = getTodayRequestCount()
                
                // Si on a déjà fait 3 demandes aujourd'hui
                if todayCount >= maxDailyRequests {
                    print("🌟 [AppRatingManager] Already requested \(todayCount) times today, max reached")
                    return false
                }
                
                // Vérifier si assez de temps s'est écoulé depuis la dernière demande
                let hoursSinceLastRequest = Calendar.current.dateComponents([.hour], from: lastRequestDate, to: Date()).hour ?? 0
                if hoursSinceLastRequest < minHoursBetweenRequests {
                    print("🌟 [AppRatingManager] Only \(hoursSinceLastRequest)h since last request, need \(minHoursBetweenRequests)h")
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Marquer qu'on a fait une demande aujourd'hui
    private func markRatingRequestedToday() {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        
        // Incrémenter le compteur du jour
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let lastRequestDay = Calendar.current.startOfDay(for: lastRequestDate)
            
            // Si c'est un nouveau jour, reset le compteur
            if !Calendar.current.isDate(today, inSameDayAs: lastRequestDay) {
                UserDefaults.standard.set(1, forKey: dailyRequestCountKey)
            } else {
                // Sinon, incrémenter
                let currentCount = UserDefaults.standard.integer(forKey: dailyRequestCountKey)
                UserDefaults.standard.set(currentCount + 1, forKey: dailyRequestCountKey)
            }
        } else {
            // Première demande
            UserDefaults.standard.set(1, forKey: dailyRequestCountKey)
        }
        
        // Sauvegarder la date de la dernière demande APRÈS avoir incrémenté
        UserDefaults.standard.set(now, forKey: lastRequestDateKey)
    }
    
    /// Obtenir le nombre de demandes faites aujourd'hui
    private func getTodayRequestCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let lastRequestDay = Calendar.current.startOfDay(for: lastRequestDate)
            
            // Si c'est le même jour, retourner le compteur
            if Calendar.current.isDate(today, inSameDayAs: lastRequestDay) {
                return UserDefaults.standard.integer(forKey: dailyRequestCountKey)
            }
        }
        
        // Si c'est un nouveau jour ou aucune demande précédente
        return 0
    }
    
    // MARK: - Debug Methods
    
    /// Reset pour les tests (à utiliser uniquement en debug)
    func resetForTesting() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: launchCountKey)
        UserDefaults.standard.removeObject(forKey: hasRatedAppKey)
        UserDefaults.standard.removeObject(forKey: dailyRequestCountKey)
        UserDefaults.standard.removeObject(forKey: lastRequestDateKey)
        print("🌟 [AppRatingManager] Reset for testing")
        #endif
    }
    
    /// Force la demande de notation (debug uniquement)
    func forceRatingRequest() {
        #if DEBUG
        print("🌟 [DEBUG] Force rating request triggered")
        requestNativeRating()
        #endif
    }
    
    /// Simuler une ouverture d'app supplémentaire (debug uniquement)
    func simulateAppLaunch() {
        #if DEBUG
        print("🌟 [DEBUG] Simulating app launch")
        recordAppLaunch()
        #endif
    }
    
    /// Marquer l'app comme notée (debug uniquement)
    func markAsRated() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: hasRatedAppKey)
        print("🌟 [DEBUG] Marked app as rated")
        #endif
    }
    
    /// Obtenir les stats actuelles (pour debug)
    func getDebugInfo() -> String {
        let launchCount = getLaunchCount()
        let hasRated = hasRatedApp()
        let todayCount = getTodayRequestCount()
        let canRequestToday = canRequestRatingToday()
        
        var lastRequestInfo = "Never"
        if let lastDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastRequestInfo = formatter.string(from: lastDate)
        }
        
        return """
        Launch Count: \(launchCount)
        Has Rated: \(hasRated)
        Today's Requests: \(todayCount)/\(maxDailyRequests)
        Can Request Today: \(canRequestToday)
        Last Request: \(lastRequestInfo)
        Required Launches: \(requiredLaunchesForRating)
        """
    }
}