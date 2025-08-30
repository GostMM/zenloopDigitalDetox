//
//  PopularSession.swift
//  zenloop
//
//  Created by Claude on 27/08/2025.
//

import SwiftUI
import Foundation
import FamilyControls

struct PopularSession: Identifiable {
    let id = UUID()
    let sessionId: String // Identifiant unique pour la persistance
    let title: String
    let description: String
    let duration: TimeInterval // en secondes
    let iconName: String
    let imageName: String
    let accentColor: AppColor
    let targetedApps: [String] // Noms des apps pour affichage seulement
    let category: SessionCategory
    
    var formattedDuration: String {
        let totalMinutes = Int(duration) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes > 0 {
                return "\(hours)h \(minutes)min"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(totalMinutes)min"
        }
    }
    
    var targetedAppsText: String {
        if targetedApps.count <= 3 {
            return targetedApps.joined(separator: ", ")
        } else {
            let first = Array(targetedApps.prefix(2))
            return "\(first.joined(separator: ", ")) +\(targetedApps.count - 2)"
        }
    }
}

enum SessionCategory: String, CaseIterable {
    case socialMedia = "social_media"
    case productivity = "productivity"
    case entertainment = "entertainment"
    case aiTools = "ai_tools"
    case mixed = "mixed"
    
    var localizedName: String {
        switch self {
        case .socialMedia:
            return String(localized: "social_media")
        case .productivity:
            return String(localized: "productivity")
        case .entertainment:
            return String(localized: "entertainment")
        case .aiTools:
            return String(localized: "ai_tools")
        case .mixed:
            return String(localized: "mixed")
        }
    }
}

enum AppColor: String, CaseIterable {
    case purple = "purple"
    case cyan = "cyan"
    case orange = "orange"
    case pink = "pink"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case yellow = "yellow"
    
    var color: Color {
        switch self {
        case .purple:
            return .purple
        case .cyan:
            return .cyan
        case .orange:
            return .orange
        case .pink:
            return .pink
        case .green:
            return .green
        case .blue:
            return .blue
        case .red:
            return .red
        case .yellow:
            return .yellow
        }
    }
}

// MARK: - Session Planning Manager

@MainActor
class SessionPlanningManager: ObservableObject {
    static let shared = SessionPlanningManager()
    
    @Published var popularSessions: [PopularSession] = []
    private let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
    
    // Dictionnaire pour stocker les sélections d'apps par session
    private var sessionAppSelections: [String: FamilyActivitySelection] = [:]
    
    private init() {
        loadPopularSessions()
    }
    
    func refreshSessions() {
        loadPopularSessions()
    }
    
    private func loadPopularSessions() {
        popularSessions = [
            // Sessions anti-réseaux sociaux
            PopularSession(
                sessionId: "no_tiktok_8h",
                title: String(localized: "no_tiktok_8h"),
                description: String(localized: "block_tiktok_8h_desc"),
                duration: 8 * 60 * 60, // 8 heures
                iconName: "video.slash",
                imageName: "tiktok",
                accentColor: .pink,
                targetedApps: ["TikTok", "Reels"],
                category: .socialMedia
            ),
            
            PopularSession(
                sessionId: "no_instagram_8h",
                title: String(localized: "no_instagram_8h"),
                description: String(localized: "block_instagram_8h_desc"),
                duration: 8 * 60 * 60,
                iconName: "photo.slash",
                imageName: "instagram",
                accentColor: .purple,
                targetedApps: ["Instagram", "Stories"],
                category: .socialMedia
            ),
            
            PopularSession(
                sessionId: "no_social_8h",
                title: String(localized: "no_social_8h"),
                description: String(localized: "block_all_social_8h_desc"),
                duration: 8 * 60 * 60,
                iconName: "person.2.slash",
                imageName: "no-social",
                accentColor: .red,
                targetedApps: ["TikTok", "Instagram", "Snapchat", "Twitter"],
                category: .socialMedia
            ),
            
            // Session anti-IA (une seule)
            PopularSession(
                sessionId: "no_chatgpt_8h",
                title: String(localized: "no_chatgpt_8h"),
                description: String(localized: "block_chatgpt_8h_desc"),
                duration: 8 * 60 * 60,
                iconName: "brain.head.profile",
                imageName: "chatgpt",
                accentColor: .green,
                targetedApps: ["ChatGPT", "Claude", "Gemini"],
                category: .aiTools
            ),
            
            // Sessions mixtes
            
            PopularSession(
                sessionId: "study_mode_4h",
                title: String(localized: "study_mode_4h"),
                description: String(localized: "study_mode_desc"),
                duration: 4 * 60 * 60,
                iconName: "book.closed",
                imageName: "focus", // Utilise social car on bloque les distractions sociales pour étudier
                accentColor: .yellow,
                targetedApps: ["Games", "TikTok", "Netflix", "YouTube"],
                category: .mixed
            )
        ]
    }
    
    func schedulePopularSession(_ session: PopularSession, with zenloopManager: AnyObject) {
        print("🗓️ [SESSION_PLANNING] Programmation de la session: \(session.title)")
        
        // Cette méthode sera implémentée quand l'utilisateur aura sélectionné les apps
        // Pour l'instant, nous stockons juste la session comme template
        
        // Notification à l'utilisateur pour qu'il sélectionne les apps
        NotificationCenter.default.post(
            name: NSNotification.Name("SessionScheduleRequested"),
            object: session
        )
    }
    
    private func calculateNextOptimalTime() -> Date {
        // Calculer le prochain moment optimal (par exemple demain matin à 8h)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        let components = DateComponents(
            year: calendar.component(.year, from: tomorrow),
            month: calendar.component(.month, from: tomorrow),
            day: calendar.component(.day, from: tomorrow),
            hour: 8,
            minute: 0
        )
        
        return calendar.date(from: components) ?? Date()
    }
    
    // MARK: - Apps Persistence per Session
    
    func saveAppsForSession(_ sessionId: String, apps: Any) {
        let key = "session_apps_\(sessionId)"
        
        // Utiliser la même approche que ZenloopManager avec App Group
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            // Marquer cette session comme ayant des apps configurées
            appGroup.set(true, forKey: "\(key)_configured")
            appGroup.set(Date().timeIntervalSince1970, forKey: "\(key)_timestamp")
            
            appGroup.synchronize()
            print("💾 [SESSION_PERSISTENCE] Session \(sessionId) marquée comme configurée")
        }
    }
    
    func loadAppsForSession(_ sessionId: String, zenloopManager: AnyObject) -> Any {
        // Pour simplifier, on utilise la sélection globale du ZenloopManager
        // L'utilisateur devra re-sélectionner, mais on garde la trace qu'il avait configuré
        print("📱 [SESSION_PERSISTENCE] Chargement pour session: \(sessionId)")
        return "loaded" // Placeholder pour éviter les erreurs de compilation
    }
    
    func hasPersistedAppsForSession(_ sessionId: String) -> Bool {
        let key = "session_apps_\(sessionId)"
        
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            return appGroup.bool(forKey: "\(key)_configured")
        }
        return false
    }
    
    func clearAppsForSession(_ sessionId: String) {
        let key = "session_apps_\(sessionId)"
        
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            appGroup.removeObject(forKey: "\(key)_configured")
            appGroup.removeObject(forKey: "\(key)_timestamp")
            appGroup.synchronize()
            print("🗑️ [SESSION_PERSISTENCE] Configuration effacée pour session: \(sessionId)")
        }
    }
}