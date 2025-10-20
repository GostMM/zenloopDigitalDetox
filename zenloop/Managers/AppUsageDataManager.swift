//
//  AppUsageDataManager.swift
//  zenloop
//
//  Gestionnaire pour récupérer les vraies données DeviceActivity depuis l'App Group
//

import Foundation
import SwiftUI

// MARK: - Modèles d'usage pour l'app

struct TopAppInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let bundleId: String?

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }

    static func == (lhs: TopAppInfo, rhs: TopAppInfo) -> Bool {
        lhs.name == rhs.name && lhs.duration == rhs.duration
    }
}

// MARK: - AppUsageDataManager

@MainActor
class AppUsageDataManager: ObservableObject {
    static let shared = AppUsageDataManager()

    @Published var topApp: TopAppInfo?
    @Published var topApps: [TopAppInfo] = []
    @Published var lastUpdateDate: Date?
    @Published var isDataAvailable = false

    private let appGroupSuite = "group.com.app.zenloop"

    private init() {
        loadDataFromAppGroup()
    }

    /// Charger les données depuis l'App Group (écrites par DeviceActivityReport)
    func loadDataFromAppGroup() {
        print("🔍 [USAGE_DATA] === Chargement données App Group ===")

        guard let shared = UserDefaults(suiteName: appGroupSuite) else {
            print("❌ [USAGE_DATA] App Group indisponible - FALLBACK MOCK DATA")
            loadMockData()
            return
        }

        guard let data = shared.data(forKey: "DAReportLatest") else {
            print("⚠️ [USAGE_DATA] Aucune donnée dans App Group (clé: DAReportLatest) - FALLBACK MOCK DATA")
            loadMockData()
            return
        }

        do {
            let payload = try JSONDecoder().decode(SharedReportPayload.self, from: data)
            print("✅ [USAGE_DATA] Payload décodé avec succès")
            print("📊 [USAGE_DATA] Total apps: \(payload.topApps.count)")
            print("📊 [USAGE_DATA] Updated at: \(Date(timeIntervalSince1970: payload.updatedAt))")

            // Convertir en TopAppInfo
            topApps = payload.topApps.map { app in
                TopAppInfo(
                    name: app.name,
                    duration: app.seconds,
                    bundleId: app.bundleId
                )
            }

            // App la plus utilisée (première de la liste)
            if let first = topApps.first {
                topApp = first
                print("🏆 [USAGE_DATA] App #1: \(first.name) - \(first.formattedDuration)")
            }

            lastUpdateDate = Date(timeIntervalSince1970: payload.updatedAt)
            isDataAvailable = true

            print("✅ [USAGE_DATA] Chargement réussi - \(topApps.count) apps")

        } catch {
            print("❌ [USAGE_DATA] Erreur décodage: \(error) - FALLBACK MOCK DATA")
            loadMockData()
        }
    }

    /// Charger des données simulées pour test (quand App Group vide)
    private func loadMockData() {
        print("🎭 [USAGE_DATA] === Chargement données SIMULÉES ===")

        // Créer des apps simulées réalistes
        topApps = [
            TopAppInfo(name: "Instagram", duration: 7200, bundleId: "com.burbn.instagram"),  // 2h
            TopAppInfo(name: "Safari", duration: 5400, bundleId: "com.apple.mobilesafari"),    // 1h30
            TopAppInfo(name: "Messages", duration: 3600, bundleId: "com.apple.MobileSMS"),     // 1h
            TopAppInfo(name: "TikTok", duration: 2700, bundleId: "com.tiktokv.TikTok"),        // 45min
            TopAppInfo(name: "YouTube", duration: 1800, bundleId: "com.google.ios.youtube")    // 30min
        ]

        topApp = topApps.first
        lastUpdateDate = Date()
        isDataAvailable = true

        if let first = topApps.first {
            print("🏆 [USAGE_DATA] Mock App #1: \(first.name) - \(first.formattedDuration)")
        }
        print("✅ [USAGE_DATA] Mock data chargé - \(topApps.count) apps")
    }

    /// Rafraîchir les données
    func refresh() {
        loadDataFromAppGroup()
    }

    /// Mapper nom d'app vers icône SF Symbol
    func getSystemIcon(for appName: String) -> String? {
        let name = appName.lowercased()

        switch true {
        case name.contains("safari"): return "safari"
        case name.contains("message"): return "message.fill"
        case name.contains("instagram"): return "photo.on.rectangle.angled"
        case name.contains("mail"): return "envelope.fill"
        case name.contains("calendar"): return "calendar"
        case name.contains("reminder"): return "checklist"
        case name.contains("notes"): return "note.text"
        case name.contains("tiktok"): return "play.rectangle.fill"
        case name.contains("facebook"): return "person.2.fill"
        case name.contains("chrome"): return "globe"
        case name.contains("spotify"): return "music.note"
        case name.contains("netflix"): return "tv.fill"
        case name.contains("snapchat"): return "camera.fill"
        case name.contains("youtube"): return "play.tv.fill"
        case name.contains("whatsapp"): return "message.badge.fill"
        case name.contains("twitter"), name.contains("x"): return "bird.fill"
        case name.contains("telegram"): return "paperplane.fill"
        case name.contains("phone"): return "phone.fill"
        case name.contains("photo"): return "photo.fill"
        case name.contains("settings"): return "gearshape.fill"
        default: return "app.fill"
        }
    }

    /// Obtenir couleur associée à l'app
    func getAppColor(for appName: String) -> Color {
        let name = appName.lowercased()

        switch true {
        case name.contains("instagram"): return .pink
        case name.contains("facebook"): return .blue
        case name.contains("tiktok"): return Color(red: 0.0, green: 0.9, blue: 0.8)
        case name.contains("twitter"), name.contains("x"): return .cyan
        case name.contains("youtube"): return .red
        case name.contains("spotify"): return .green
        case name.contains("snapchat"): return .yellow
        case name.contains("whatsapp"): return Color(red: 0.15, green: 0.68, blue: 0.38)
        case name.contains("telegram"): return Color(red: 0.2, green: 0.6, blue: 0.9)
        case name.contains("safari"): return .blue
        case name.contains("chrome"): return Color(red: 0.26, green: 0.52, blue: 0.96)
        case name.contains("netflix"): return .red
        default: return .purple
        }
    }
}
