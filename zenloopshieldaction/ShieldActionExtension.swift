//
//  ShieldActionExtension.swift
//  zenloopshieldaction
//
//  Zenloop — Shield Action Extension (iOS 16+)
//

import Foundation
import ManagedSettings
import ManagedSettingsUI

// IMPORTANT (configuration):
// - Target: Extension "zenloopshieldaction"
// - Entitlements: App Group "group.com.app.zenloop" (même que l’app)
// - Info.plist (extension):
//     NSExtension -> NSExtensionPointIdentifier = com.apple.ManagedSettings.shield-action-service
//     NSExtension -> NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).ShieldActionExtension
// - L’icône/texte du Shield est géré par l’autre extension (ShieldConfiguration)

/// Clefs & constantes partagées
private enum AppGroup {
    static let id = "group.com.app.zenloop"
}
private enum StoreKey {
    static let pendingAction      = "pendingShieldAction"
    static let actionHistory      = "shieldActionHistory"
    static let motivationCount    = "motivationClicksCount"
    static let pauseRequestsCount = "pauseRequestsCount"
    static let urgentPause        = "urgentPauseRequest"
    static let openAttemptsTotal  = "app_open_attempts"
    static let openAttemptsLog    = "app_attempt_log"
}
private enum DarwinNotify {
    // Utilisé pour réveiller l’app (observer via CFNotificationCenterGetDarwinNotifyCenter dans l’app)
    static let name = "com.app.zenloop.shieldAction"
}

/// Extension d’actions du Shield.
/// Le système appelle ces méthodes quand l’utilisateur appuie sur les boutons du Shield.
final class ShieldActionExtension: ShieldActionDelegate {

    // MARK: - Application

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let ctx = contextString(from: application)
        route(action: action, context: ctx)
        completionHandler(response(for: action))
    }

    // MARK: - WebDomain

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let ctx = contextString(from: webDomain)
        route(action: action, context: ctx)
        completionHandler(response(for: action))
    }

    // MARK: - Category

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let ctx = contextString(from: category)
        route(action: action, context: ctx)
        completionHandler(response(for: action))
    }

    // MARK: - Routing

    private func route(action: ShieldAction, context: String) {
        switch action {
        case .primaryButtonPressed:
            handleContinueChallenge(context: context)
        case .secondaryButtonPressed:
            handlePauseRequest(context: context)
        @unknown default:
            // Rien à faire
            break
        }
    }

    // MARK: - Actions

    private func handleContinueChallenge(context: String) {
        // Comptabiliser la tentative d’ouverture (utile pour stats/UX)
        recordAppOpenAttempt(appName: extractAppName(from: context))

        // Notifier l’app principale
        notifyMainApp(action: "continue_challenge", context: context)

        // Incrémenter compteur motivation
        incrementMotivationStats()

        debugLog("💪 [SHIELD ACTION] Continue challenge — \(context)")
    }

    private func handlePauseRequest(context: String) {
        // Comptabiliser la tentative d'ouverture
        recordAppOpenAttempt(appName: extractAppName(from: context))
        
        // Déterminer le type d'action secondaire basé sur le contexte
        let actionType = determineSecondaryAction(context: context)
        
        // Notifier l'app principale avec l'action spécifique
        notifyMainApp(action: actionType, context: context)

        // Sauvegarder la requête selon le type
        saveSecondaryAction(action: actionType, context: context)

        debugLog("🔧 [SHIELD ACTION] \(actionType) — \(context)")
    }
    
    private func determineSecondaryAction(context: String) -> String {
        // Analyser le contexte pour déterminer l'action appropriée
        if context.contains("focus") || context.contains("Focus") {
            return "open_pause_options"
        } else if context.contains("challenge") || context.contains("Défi") {
            return "open_challenge_settings"
        } else if context.contains("detox") || context.contains("Detox") {
            return "open_exception_request"
        } else if context.contains("flow") || context.contains("Flow") {
            return "open_flow_adjustments"
        } else {
            return "open_session_options" // Fallback générique
        }
    }

    // MARK: - Réponse UI du Shield

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // Bouton unique: fermer le shield avec motivation
            debugLog("💪 User chose to stay focused - closing shield")
            incrementMotivationStats() // Compter comme victoire de discipline
            return .close
        case .secondaryButtonPressed:
            // Plus de bouton secondaire, mais on garde le case pour compatibilité
            debugLog("⚠️ Secondary button pressed but should not exist")
            return .none
        @unknown default:
            debugLog("❓ Unknown action - no response")
            return .none
        }
    }

    // MARK: - Persistence & Notifications

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private func notifyMainApp(action: String, context: String) {
        let stamp = Date().timeIntervalSince1970
        let payload: [String: Any] = [
            "action": action,
            "context": context,
            "timestamp": stamp,
            "source": "shield_action_extension",
            "processed": false,
            "requiresAppOpen": shouldOpenApp(for: action)
        ]

        defaults?.set(payload, forKey: StoreKey.pendingAction)

        // Historique limité (20)
        var history = defaults?.array(forKey: StoreKey.actionHistory) as? [[String: Any]] ?? []
        history.append(payload)
        if history.count > 20 { history = Array(history.suffix(20)) }
        defaults?.set(history, forKey: StoreKey.actionHistory)

        defaults?.synchronize()

        // Ping l'app via Darwin notification (à écouter dans l'app)
        postDarwinNotification(DarwinNotify.name)
        
        // Si l'action nécessite d'ouvrir l'app, créer un deep link
        if shouldOpenApp(for: action) {
            triggerAppDeepLink(action: action, context: context)
        }

        debugLog("📱 Action envoyée à l'app: \(action) | \(context) | OpenApp: \(shouldOpenApp(for: action))")
    }
    
    private func shouldOpenApp(for action: String) -> Bool {
        // Actions qui nécessitent d'ouvrir l'app pour interaction utilisateur
        return action.hasPrefix("open_")
    }
    
    private func triggerAppDeepLink(action: String, context: String) {
        let deepLinkURL = createDeepLinkURL(action: action, context: context)
        
        // Ouvrir l'app via URL scheme
        if let url = URL(string: deepLinkURL) {
            // iOS 16+: utiliser les API d'ouverture depuis l'extension
            DispatchQueue.main.async {
                if #available(iOS 16.0, *) {
                    // Sauvegarder la demande d'ouverture
                    self.defaults?.set([
                        "url": deepLinkURL,
                        "timestamp": Date().timeIntervalSince1970
                    ], forKey: "pendingDeepLink")
                    
                    // Notifier que l'app doit être ouverte
                    self.postDarwinNotification("com.app.zenloop.openApp")
                    
                    self.debugLog("🔗 Deep link créé: \(deepLinkURL)")
                }
            }
        }
    }
    
    private func createDeepLinkURL(action: String, context: String) -> String {
        let baseURL = "zenloop://"
        let encodedContext = context.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch action {
        case "open_pause_options":
            return "\(baseURL)pause?context=\(encodedContext)"
        case "open_challenge_settings":
            return "\(baseURL)challenge/settings?context=\(encodedContext)"
        case "open_exception_request":
            return "\(baseURL)exception?context=\(encodedContext)"
        case "open_flow_adjustments":
            return "\(baseURL)flow/settings?context=\(encodedContext)"
        default:
            return "\(baseURL)session?action=\(action)&context=\(encodedContext)"
        }
    }

    private func incrementMotivationStats() {
        let current = defaults?.integer(forKey: StoreKey.motivationCount) ?? 0
        defaults?.set(current + 1, forKey: StoreKey.motivationCount)
        defaults?.synchronize()
        debugLog("📊 Motivation clicks: \(current + 1)")
    }

    private func saveSecondaryAction(action: String, context: String) {
        let count = (defaults?.integer(forKey: StoreKey.pauseRequestsCount) ?? 0) + 1
        defaults?.set(count, forKey: StoreKey.pauseRequestsCount)

        let data: [String: Any] = [
            "action": action,
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "date": ISO8601DateFormatter().string(from: Date()),
            "urgent": action == "request_pause_5min",
            "count": count
        ]
        defaults?.set(data, forKey: StoreKey.urgentPause)

        // Sauvegarder aussi dans l'historique des actions secondaires
        var secondaryHistory = defaults?.array(forKey: "secondaryActionHistory") as? [[String: Any]] ?? []
        secondaryHistory.append(data)
        if secondaryHistory.count > 50 { 
            secondaryHistory = Array(secondaryHistory.suffix(50)) 
        }
        defaults?.set(secondaryHistory, forKey: "secondaryActionHistory")

        defaults?.synchronize()
        debugLog("🔧 Action secondaire (#\(count)): \(action) — \(context)")
    }

    private func recordAppOpenAttempt(appName: String?) {
        // Total
        let total = (defaults?.integer(forKey: StoreKey.openAttemptsTotal) ?? 0) + 1
        defaults?.set(total, forKey: StoreKey.openAttemptsTotal)

        // Log (100 derniers)
        var log = defaults?.array(forKey: StoreKey.openAttemptsLog) as? [[String: Any]] ?? []
        log.append([
            "timestamp": Date().timeIntervalSince1970,
            "appName": appName ?? "inconnue",
            "source": "shield_action"
        ])
        if log.count > 100 { log = Array(log.suffix(100)) }
        defaults?.set(log, forKey: StoreKey.openAttemptsLog)

        defaults?.synchronize()
        debugLog("🚫 Tentative #\(total) — \(appName ?? "inconnue")")
    }

    // MARK: - Helpers: context & nom d’app

    private func contextString(from application: ApplicationToken) -> String {
        // ApplicationToken ne fournit pas forcément un nom lisible;
        // on se rabat sur sa description (inclura souvent le bundle id).
        String(describing: application)
    }

    private func contextString(from webDomain: WebDomainToken) -> String {
        String(describing: webDomain)
    }

    private func contextString(from category: ActivityCategoryToken) -> String {
        String(describing: category)
    }

    private func extractAppName(from context: String) -> String? {
        // Essaye de dériver un nom à partir d’un bundle id ou d’une string simple
        if context.contains(".") {
            let parts = context.split(separator: ".")
            if let last = parts.last, last.count > 1 {
                return String(last).replacingOccurrences(of: ")", with: "").capitalized
            }
        }
        if context.count >= 3 && context.count <= 50 {
            return context
        }
        return nil
    }

    // MARK: - Darwin Notification

    private func postDarwinNotification(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterPostNotification(center, cfName, nil, nil, true)
    }

    // MARK: - Debug

    private func debugLog(_ text: String) {
        #if DEBUG
        print(text)
        #endif
    }
}
