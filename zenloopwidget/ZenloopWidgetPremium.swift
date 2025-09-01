//
//  ZenloopWidgetPremium.swift
//  zenloopwidget
//
//  Created by Claude Code on 31/08/2025.
//

import Foundation

// Extension pour ajouter les contrôles Premium aux widgets
extension ZenloopWidgetDataProvider {
    
    // MARK: - Premium Control
    
    func isPremiumUser() -> Bool {
        // Vérifier le statut Premium via UserDefaults partagé
        let shared = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        return shared.bool(forKey: "isPremium")
    }
    
    func storePendingSessionForPaywall(duration: Int, origin: ActiveSessionData.SessionOrigin) {
        // Stocker la session en attente pour l'ouvrir après payment
        let shared = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        shared.set(duration, forKey: "pendingSessionDuration")
        shared.set(origin.rawValue, forKey: "pendingSessionOrigin")
        shared.set(Date().timeIntervalSince1970, forKey: "pendingSessionTimestamp")
        shared.synchronize()
        
        print("💳 [WIDGET] Session en attente stockée pour paywall - durée: \(duration)min")
        
        // Déclencher l'ouverture de l'app avec paywall
        openAppForPaywall()
    }
    
    private func openAppForPaywall() {
        // Créer une URL personnalisée pour ouvrir l'app vers le paywall
        if let url = URL(string: "zenloop://paywall?source=widget") {
            // L'app principale doit gérer cette URL dans son AppDelegate/SceneDelegate
            print("🔗 [WIDGET] Ouverture de l'app pour paywall: \(url)")
        }
    }
    
    // MARK: - Premium-Gated Session Methods
    
    func startSessionIfPremium(duration: Int, origin: ActiveSessionData.SessionOrigin = .quickStart) {
        // Vérifier si l'utilisateur est Premium avant d'autoriser le lancement de session
        if !isPremiumUser() {
            print("🚫 [WIDGET] Session bloquée - utilisateur non Premium")
            // Stocker l'intent pour rediriger vers le paywall
            storePendingSessionForPaywall(duration: duration, origin: origin)
            return
        }
        
        // Utiliser la méthode existante si Premium
        startSession(duration: duration, origin: origin)
    }
    
    func startNewSessionIfPremium() {
        startSessionIfPremium(duration: 25, origin: .manual)
    }
    
    // MARK: - Premium Status Helpers
    
    func updatePremiumStatus(_ isPremium: Bool) {
        let shared = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        shared.set(isPremium, forKey: "isPremium")
        shared.synchronize()
        
        print("👑 [WIDGET] Premium status updated: \(isPremium)")
        
        // Si l'utilisateur devient Premium, vérifier s'il y a une session en attente
        if isPremium {
            executePendingSessionIfAny()
        }
    }
    
    private func executePendingSessionIfAny() {
        let shared = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        let duration = shared.integer(forKey: "pendingSessionDuration")
        let originString = shared.string(forKey: "pendingSessionOrigin") ?? ""
        let timestamp = shared.double(forKey: "pendingSessionTimestamp")
        
        // Vérifier si la session en attente est récente (moins de 5 minutes)
        let now = Date().timeIntervalSince1970
        if duration > 0 && !originString.isEmpty && (now - timestamp) < 300 {
            let origin = ActiveSessionData.SessionOrigin(rawValue: originString) ?? .quickStart
            
            print("🚀 [WIDGET] Exécution de la session en attente après upgrade Premium")
            startSession(duration: duration, origin: origin)
            
            // Nettoyer les données en attente
            shared.removeObject(forKey: "pendingSessionDuration")
            shared.removeObject(forKey: "pendingSessionOrigin")
            shared.removeObject(forKey: "pendingSessionTimestamp")
            shared.synchronize()
        }
    }
}