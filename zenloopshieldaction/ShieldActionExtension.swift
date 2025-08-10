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
        // Comptabiliser la tentative d’ouverture
        recordAppOpenAttempt(appName: extractAppName(from: context))

        // Notifier l’app principale (elle décidera d’accorder ou non la pause)
        notifyMainApp(action: "request_pause_5min", context: context)

        // Sauvegarder la requête de pause (flag urgent)
        savePauseRequest(context: context)

        debugLog("⏸️ [SHIELD ACTION] Pause 5 min — \(context)")
    }

    // MARK: - Réponse UI du Shield

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // Souvent: on ferme le shield après "continuer"
            return .close
        case .secondaryButtonPressed:
            // Souvent: on laisse le shield, le temps que l’app décide (ou affiche une notif)
            return .defer
        @unknown default:
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
            "processed": false
        ]

        defaults?.set(payload, forKey: StoreKey.pendingAction)

        // Historique limité (20)
        var history = defaults?.array(forKey: StoreKey.actionHistory) as? [[String: Any]] ?? []
        history.append(payload)
        if history.count > 20 { history = Array(history.suffix(20)) }
        defaults?.set(history, forKey: StoreKey.actionHistory)

        defaults?.synchronize()

        // Ping l’app via Darwin notification (à écouter dans l’app)
        postDarwinNotification(DarwinNotify.name)

        debugLog("📱 Action envoyée à l’app: \(action) | \(context)")
    }

    private func incrementMotivationStats() {
        let current = defaults?.integer(forKey: StoreKey.motivationCount) ?? 0
        defaults?.set(current + 1, forKey: StoreKey.motivationCount)
        defaults?.synchronize()
        debugLog("📊 Motivation clicks: \(current + 1)")
    }

    private func savePauseRequest(context: String) {
        let count = (defaults?.integer(forKey: StoreKey.pauseRequestsCount) ?? 0) + 1
        defaults?.set(count, forKey: StoreKey.pauseRequestsCount)

        let data: [String: Any] = [
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "date": ISO8601DateFormatter().string(from: Date()),
            "urgent": true
        ]
        defaults?.set(data, forKey: StoreKey.urgentPause)

        defaults?.synchronize()
        debugLog("🚨 Pause demandée (#\(count)) — \(context)")
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
