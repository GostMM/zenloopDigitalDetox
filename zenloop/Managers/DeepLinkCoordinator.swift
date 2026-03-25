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

    @Published var pendingSessionId: String?
    @Published var shouldNavigateToSession = false
    @Published var shouldNavigateToNotifications = false

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

    private func handleSessionDeepLink(url: URL) {
        // URL format: zenloop://session/{sessionId}?message={messageId}
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard !pathComponents.isEmpty else {
            deepLinkLogger.warning("⚠️ No session ID in deep link")
            return
        }

        let sessionId = pathComponents[0]
        pendingSessionId = sessionId
        shouldNavigateToSession = true

        deepLinkLogger.info("🎯 Navigating to session: \(sessionId)")

        // Extraire les query parameters si présents
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                deepLinkLogger.info("📋 Query param: \(item.name) = \(item.value ?? "nil")")
            }
        }
    }

    func clearNavigation() {
        shouldNavigateToSession = false
        shouldNavigateToNotifications = false
        pendingSessionId = nil
    }
}
