//
//  DeepLinkCoordinator.swift
//  zenloop
//
//  Coordinateur pour la navigation deep link vers les sessions
//

import Foundation
import SwiftUI
import os.log

private let deepLinkLogger = Logger(subsystem: "com.app.zenloop", category: "DeepLink")

@MainActor
class DeepLinkCoordinator: ObservableObject {

    static let shared = DeepLinkCoordinator()

    // MARK: - Published State

    /// Session ID en attente d'ouverture (set par le deep link, consommé par SocialTab)
    @Published var pendingSessionId: String?

    /// Indique qu'on doit naviguer vers une session (consommé par SocialTab)
    @Published var shouldNavigateToSession = false

    /// Indique qu'on doit naviguer vers les notifications
    @Published var shouldNavigateToNotifications = false

    /// Tab cible pour la navigation (0: Home, 1: Stats, 2: Social)
    /// Consommé par ContentView via .onChange
    @Published var targetTab: Int?

    /// Flag mis à true quand le tab cible est effectivement monté.
    /// Permet de séquencer proprement : changement de tab → attente du mount → navigation.
    @Published var isTargetTabReady = false

    private init() {
        deepLinkLogger.info("DeepLinkCoordinator initialized")
    }

    // MARK: - Handle Deep Links

    func handleDeepLink(url: URL) {
        deepLinkLogger.info("🔗 Handling deep link: \(url.absoluteString)")

        guard url.scheme == "zenloop" else {
            deepLinkLogger.warning("⚠️ Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }

        let path = url.host ?? ""

        switch path {
        case "session":
            handleSessionDeepLink(url: url)

        case "notifications":
            shouldNavigateToNotifications = true
            deepLinkLogger.info("📬 Navigating to notifications")

        default:
            deepLinkLogger.warning("⚠️ Unknown deep link path: \(path)")
        }
    }

    // MARK: - Session Deep Link

    private func handleSessionDeepLink(url: URL) {
        // URL format: zenloop://session/{sessionId}?message={messageId}
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let sessionId = pathComponents.first, !sessionId.isEmpty else {
            deepLinkLogger.warning("⚠️ No session ID in deep link")
            return
        }

        deepLinkLogger.info("📍 Deep link requests session: \(sessionId)")

        // Stocker la session en attente
        pendingSessionId = sessionId

        // Demander le changement de tab vers Social (index 2)
        // ContentView observe targetTab et met à jour selectedTab
        targetTab = 2

        // La navigation effective vers la session se fera quand
        // isTargetTabReady passera à true (voir onTargetTabAppeared())

        // Extraire les query parameters si présents (pour usage futur)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                deepLinkLogger.info("📋 Query param: \(item.name) = \(item.value ?? "nil")")
            }
        }
    }

    // MARK: - Tab Readiness (appelé par le tab cible dans .onAppear)

    /// Appelé par le tab de destination quand il est monté et prêt.
    /// Déclenche la navigation vers la session en attente.
    func onTargetTabAppeared() {
        guard pendingSessionId != nil else { return }

        isTargetTabReady = true
        shouldNavigateToSession = true
        deepLinkLogger.info("🎯 Target tab ready — navigating to session: \(self.pendingSessionId ?? "nil")")
    }

    // MARK: - Clear State

    /// Réinitialise tout l'état de navigation.
    /// À appeler une fois que la destination a consommé le deep link.
    func clearNavigation() {
        shouldNavigateToSession = false
        shouldNavigateToNotifications = false
        pendingSessionId = nil
        targetTab = nil
        isTargetTabReady = false
        deepLinkLogger.info("🧹 Navigation state cleared")
    }

    // MARK: - Safe URL Builder

    /// Construit une URL deep link de manière sûre (pas de force unwrap)
    static func buildSessionURL(sessionId: String, messageId: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "zenloop"
        components.host = "session"
        components.path = "/\(sessionId)"

        if let messageId = messageId {
            components.queryItems = [URLQueryItem(name: "message", value: messageId)]
        }

        guard let url = components.url else {
            deepLinkLogger.error("❌ Failed to build deep link URL for session: \(sessionId)")
            return nil
        }

        return url
    }
}