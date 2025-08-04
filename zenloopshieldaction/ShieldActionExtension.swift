//
//  ShieldActionExtension.swift
//  zenloopshieldaction
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import Foundation
import ManagedSettings
import ManagedSettingsUI

// Pour iOS 16+, nous devons créer une extension qui implémente les bons protocoles
@main
struct ShieldActionApp {
    static func main() {
        // Point d'entrée de l'extension
        ShieldActionHandler.shared.start()
    }
}

class ShieldActionHandler {
    static let shared = ShieldActionHandler()
    
    private init() {}
    
    func start() {
        print("🛡️ [SHIELD ACTION] Extension démarrée")
        
        // L'extension restera active pour écouter les événements
        RunLoop.main.run()
    }
    
    // Cette méthode sera appelée par le système quand l'utilisateur tape un bouton
    @objc func handleShieldButtonPressed(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String,
              let context = userInfo["context"] as? String else {
            print("❌ [SHIELD ACTION] Données manquantes dans la notification")
            return
        }
        
        print("🛡️ [SHIELD ACTION] Bouton pressé: \(action) - contexte: \(context)")
        
        switch action {
        case "primary":
            handleContinueChallenge(context: context)
        case "secondary":
            handlePauseRequest(context: context)
        default:
            print("⚠️ [SHIELD ACTION] Action inconnue: \(action)")
        }
    }
    
    private func handleContinueChallenge(context: String) {
        print("💪 [SHIELD ACTION] Utilisateur continue le défi - contexte: \(context)")
        
        // IMPORTANT: Enregistrer cette tentative d'ouverture d'app bloquée
        recordAppOpenAttempt(appName: extractAppNameFromContext(context))
        
        // Envoyer l'événement à l'app principale
        notifyMainApp(action: "continue_challenge", context: context)
        
        // Incrémenter les stats de motivation
        incrementMotivationStats()
    }
    
    private func handlePauseRequest(context: String) {
        print("⏸️ [SHIELD ACTION] Demande de pause 5 minutes - contexte: \(context)")
        
        // IMPORTANT: Enregistrer cette tentative d'ouverture d'app bloquée
        recordAppOpenAttempt(appName: extractAppNameFromContext(context))
        
        // Envoyer l'événement de pause à l'app principale
        notifyMainApp(action: "request_pause_5min", context: context)
        
        // Sauvegarder la demande de pause
        savePauseRequest(context: context)
    }
    
    private func notifyMainApp(action: String, context: String) {
        // Utiliser UserDefaults avec App Group pour communication
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        let timestamp = Date().timeIntervalSince1970
        
        let actionData: [String: Any] = [
            "action": action,
            "context": context,
            "timestamp": timestamp,
            "source": "shield_extension",
            "processed": false // Flag pour éviter le double traitement
        ]
        
        userDefaults?.set(actionData, forKey: "pendingShieldAction")
        userDefaults?.synchronize()
        
        print("📱 [SHIELD ACTION] Action envoyée à l'app principale: \(action) - \(context)")
        
        // Sauvegarder aussi dans l'historique
        var actionHistory = userDefaults?.array(forKey: "shieldActionHistory") as? [[String: Any]] ?? []
        actionHistory.append(actionData)
        
        // Garder seulement les 20 dernières actions
        if actionHistory.count > 20 {
            actionHistory = Array(actionHistory.suffix(20))
        }
        
        userDefaults?.set(actionHistory, forKey: "shieldActionHistory")
        userDefaults?.synchronize()
    }
    
    private func incrementMotivationStats() {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        let currentCount = userDefaults?.integer(forKey: "motivationClicksCount") ?? 0
        userDefaults?.set(currentCount + 1, forKey: "motivationClicksCount")
        userDefaults?.synchronize()
        
        print("📊 [SHIELD ACTION] Stats motivation: \(currentCount + 1) clics")
    }
    
    private func savePauseRequest(context: String) {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Incrémenter le compteur de pauses demandées
        let pauseCount = userDefaults?.integer(forKey: "pauseRequestsCount") ?? 0
        userDefaults?.set(pauseCount + 1, forKey: "pauseRequestsCount")
        
        // Sauvegarder la dernière demande de pause avec flag urgent
        let pauseData: [String: Any] = [
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "date": ISO8601DateFormatter().string(from: Date()),
            "urgent": true // Flag pour traitement prioritaire
        ]
        
        userDefaults?.set(pauseData, forKey: "urgentPauseRequest")
        userDefaults?.synchronize()
        
        print("🚨 [SHIELD ACTION] PAUSE URGENTE demandée #\(pauseCount + 1) - contexte: \(context)")
    }
    
    // MARK: - App Attempt Tracking
    
    private func recordAppOpenAttempt(appName: String?) {
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Incrémenter le compteur total
        let currentCount = userDefaults?.integer(forKey: "app_open_attempts") ?? 0
        userDefaults?.set(currentCount + 1, forKey: "app_open_attempts")
        
        // Enregistrer la tentative avec timestamp
        var attempts = userDefaults?.array(forKey: "app_attempt_log") as? [[String: Any]] ?? []
        let attempt: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "appName": appName ?? "app inconnue",
            "source": "shield_action"
        ]
        attempts.append(attempt)
        
        // Garder seulement les 100 dernières tentatives
        if attempts.count > 100 {
            attempts = Array(attempts.suffix(100))
        }
        
        userDefaults?.set(attempts, forKey: "app_attempt_log")
        userDefaults?.synchronize()
        
        print("🚫 [SHIELD ACTION] Tentative d'ouverture #\(currentCount + 1): \(appName ?? "app inconnue")")
        
        // Notifier l'app principale de la tentative
        notifyMainApp(action: "app_open_attempt", context: appName ?? "unknown")
    }
    
    private func extractAppNameFromContext(_ context: String) -> String? {
        // Essayer d'extraire le nom de l'app depuis le contexte
        // Le contexte peut contenir des infos comme "com.instagram.app" ou "Instagram"
        
        if context.contains(".") {
            // C'est probablement un bundle identifier
            let components = context.split(separator: ".")
            if let lastComponent = components.last {
                return String(lastComponent).capitalized
            }
        }
        
        // Sinon retourner le contexte tel quel s'il semble être un nom d'app
        if context.count > 2 && context.count < 50 {
            return context
        }
        
        return nil
    }
}