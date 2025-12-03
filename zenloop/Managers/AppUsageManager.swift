//
//  AppUsageManager.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity

// MARK: - Modèles de données

struct AppUsageInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String // En réalité un token, mais gardons cette structure
    let dailyUsage: TimeInterval
    let isProductive: Bool
    
    var formattedTime: String {
        let hours = Int(dailyUsage) / 3600
        let minutes = Int(dailyUsage) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct HourlyUsageData {
    let hour: Int
    let categories: [CategoryHourlyData]
}

struct CategoryHourlyData {
    let name: String
    let seconds: TimeInterval
}

struct UsageStats {
    let dailyTotal: TimeInterval
    let weeklyTotal: TimeInterval
    let topApps: [AppUsageInfo]
    let productiveTime: TimeInterval
    let unproductiveTime: TimeInterval
    let hourlyData: [HourlyUsageData]  // ✅ Données horaires réelles
    let hasRealData: Bool  // ✅ Flag pour savoir si on a de vraies données

    var productivityPercentage: Int {
        let total = productiveTime + unproductiveTime
        return total > 0 ? Int((productiveTime / total) * 100) : 0
    }

    static let empty = UsageStats(
        dailyTotal: 0,
        weeklyTotal: 0,
        topApps: [],
        productiveTime: 0,
        unproductiveTime: 0,
        hourlyData: [],
        hasRealData: false
    )
}

// MARK: - DeviceActivity Context Extension
// Note: Context défini dans TotalActivityReport.swift pour éviter les doublons

// MARK: - AppUsageManager

@MainActor
class AppUsageManager: ObservableObject {
    static let shared = AppUsageManager()
    
    @Published var usageStats: UsageStats = .empty
    @Published var isLoading = false
    @Published var isAuthorized = false
    @Published var showTopAppToast = false
    @Published var topApp: AppUsageInfo?

    private let authorizationCenter = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    
    // Apps productives
    private let productiveApps: Set<String> = [
        "com.apple.MobileSMS",
        "com.apple.mobilemail", 
        "com.apple.mobilecal",
        "com.apple.reminders",
        "com.apple.MobileNotes",
        "com.notion.id",
        "com.microsoft.Office.Word",
        "com.apple.iBooks",
        "com.apple.podcasts",
        "com.duolingo.DuolingoMobile"
    ]
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = true
                debugPrint("✅ [APP_USAGE] Autorisation accordée pour Screen Time")
            }
            await loadRealUsageData()
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                debugPrint("❌ [APP_USAGE] Erreur d'autorisation: \(error)")
            }
            // Fallback vers données simulées
            await loadMockDataAsync()
        }
    }
    
    private func checkAuthorizationStatus() {
        switch authorizationCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
            Task { await loadRealUsageData() }
        case .denied, .notDetermined:
            isAuthorized = false
            // Utiliser des données simulées par défaut
            loadMockData()
        @unknown default:
            isAuthorized = false
            loadMockData()
        }
    }
    
    // MARK: - Real Data Loading avec DeviceActivity

    func loadUsageData() {
        Task {
            if isAuthorized {
                // Démarrer le monitoring DeviceActivity pour générer les rapports
                await startUsageMonitoring()

                // Essayer de charger les données de l'App Group (DeviceActivityReport)
                if loadDataFromAppGroup() {
                    debugPrint("✅ [APP_USAGE] Données chargées depuis DeviceActivityReport")
                } else {
                    debugPrint("⚠️ [APP_USAGE] Pas de données DeviceActivity, fallback vers load real")
                    await loadRealUsageData()
                }
            } else {
                await requestAuthorization()
            }
        }
    }

    // MARK: - Trigger DeviceActivity Report Generation

    @Published var shouldShowReportTrigger = false

    private func startUsageMonitoring() async {
        debugPrint("🚀 [APP_USAGE] === Déclenchement rapport DeviceActivity ===")

        // Pour que l'extension génère le rapport, on doit afficher DeviceActivityReport
        // On va notifier la vue pour qu'elle l'affiche (même invisible)
        await MainActor.run {
            shouldShowReportTrigger = true
        }

        // Attendre un peu pour laisser le rapport se générer
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes

        debugPrint("✅ [APP_USAGE] Rapport déclenché, attente des données...")
    }
    
    private func loadDataFromAppGroup() -> Bool {
        debugPrint("🔍 [APP_USAGE] === Tentative chargement VRAIES données App Group ===")

        guard let appGroup = UserDefaults(suiteName: "group.com.app.zenloop"),
              let data = appGroup.data(forKey: "DAReportLatest") else {
            debugPrint("❌ [APP_USAGE] Pas de données dans App Group")
            return false
        }

        do {
            // Décoder le SharedReportPayload depuis l'extension
            let payload = try JSONDecoder().decode(SharedReportPayload.self, from: data)

            debugPrint("✅ [APP_USAGE] === VRAIES DONNÉES DeviceActivity chargées ===")
            debugPrint("📊 [APP_USAGE] Total: \(payload.totalSeconds)s (\(formatTimeValue(payload.totalSeconds)))")
            debugPrint("📊 [APP_USAGE] Top apps: \(payload.topApps.count)")
            debugPrint("📊 [APP_USAGE] Hourly data points: \(payload.hourlyData.count)")

            // Convertir en AppUsageInfo
            let topApps = payload.topApps.map { app in
                AppUsageInfo(
                    name: app.name,
                    bundleId: app.bundleId ?? "unknown",
                    dailyUsage: app.seconds,
                    isProductive: true  // On peut améliorer en catégorisant
                )
            }

            // Convertir hourly data
            let hourlyData = payload.hourlyData.map { hourPoint in
                HourlyUsageData(
                    hour: hourPoint.hour,
                    categories: hourPoint.categories.map { cat in
                        CategoryHourlyData(name: cat.name, seconds: cat.seconds)
                    }
                )
            }

            // Calculer productive/unproductive à partir des catégories
            var productiveTime: TimeInterval = 0
            var unproductiveTime: TimeInterval = 0

            for cat in payload.topCategories {
                let name = cat.name.lowercased()
                if name.contains("productivity") || name.contains("business") || name.contains("education") {
                    productiveTime += cat.seconds
                } else {
                    unproductiveTime += cat.seconds
                }
            }

            // Créer UsageStats avec VRAIES données
            let newStats = UsageStats(
                dailyTotal: payload.totalSeconds,
                weeklyTotal: payload.totalSeconds * 7,  // Approximation
                topApps: topApps,
                productiveTime: productiveTime,
                unproductiveTime: unproductiveTime,
                hourlyData: hourlyData,
                hasRealData: true  // ✅ Flag pour indiquer vraies données
            )

            DispatchQueue.main.async {
                self.usageStats = newStats
                self.isLoading = false

                if let mostUsedApp = topApps.first {
                    self.topApp = mostUsedApp
                }

                debugPrint("✅ [APP_USAGE] Stats mis à jour avec VRAIES données DeviceActivity")
                debugPrint("✅ [APP_USAGE] Daily: \(self.formatTimeValue(payload.totalSeconds))")
                debugPrint("✅ [APP_USAGE] Hourly breakdown available: \(hourlyData.count) hours")
            }

            return true

        } catch {
            debugPrint("❌ [APP_USAGE] Erreur décodage SharedReportPayload: \(error)")
            return false
        }
    }

    // Struct pour décoder (doit matcher l'extension)
    private struct SharedReportPayload: Codable {
        let intervalStart: TimeInterval
        let intervalEnd: TimeInterval
        let totalSeconds: Double
        let averageDailySeconds: Double
        let updatedAt: TimeInterval
        let topCategories: [SharedReportCategory]
        let days: [SharedReportDayPoint]
        let todayScreenSeconds: Double
        let todayOffScreenSeconds: Double
        let topApps: [SharedReportApp]
        let hourlyData: [SharedReportHourPoint]
    }

    private struct SharedReportApp: Codable {
        let name: String
        let seconds: Double
        let bundleId: String?
    }

    private struct SharedReportCategory: Codable {
        let name: String
        let seconds: Double
        let appCount: Int
    }

    private struct SharedReportDayPoint: Codable {
        let dayStart: TimeInterval
        let seconds: Double
    }

    private struct SharedReportHourPoint: Codable {
        let hour: Int
        let categories: [SharedReportHourCategory]
    }

    private struct SharedReportHourCategory: Codable {
        let name: String
        let seconds: Double
    }
    
    private func formatTimeValue(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func loadRealUsageData() async {
        await MainActor.run {
            isLoading = true
        }
        
        debugPrint("📊 [APP_USAGE] Chargement des vraies données Screen Time...")
        
        // Créer le filtre pour les données quotidiennes
        let calendar = Calendar.current
        guard let todayInterval = calendar.dateInterval(of: .day, for: Date()) else {
            debugPrint("❌ [APP_USAGE] Impossible de créer l'intervalle quotidien")
            await loadMockDataAsync()
            return
        }
        
        // Utiliser DeviceActivityReport pour les vraies données
        await loadRealDeviceActivityData()
    }
    
    private func loadRealDeviceActivityData() async {
        // Créer le filtre DeviceActivity pour aujourd'hui
        let calendar = Calendar.current
        guard let todayInterval = calendar.dateInterval(of: .day, for: Date()) else {
            debugPrint("❌ [APP_USAGE] Impossible de créer l'intervalle quotidien")
            return
        }
        
        let dailyFilter = DeviceActivityFilter(
            segment: .daily(during: todayInterval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
        
        // Pour la semaine
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            debugPrint("❌ [APP_USAGE] Impossible de créer l'intervalle hebdomadaire")
            return
        }
        
        let weeklyFilter = DeviceActivityFilter(
            segment: .weekly(during: weekInterval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
        
        debugPrint("📊 [APP_USAGE] Configuration des filtres DeviceActivity")
        debugPrint("📅 [APP_USAGE] Période quotidienne: \(todayInterval)")
        debugPrint("📅 [APP_USAGE] Période hebdomadaire: \(weekInterval)")
        
        // Note: DeviceActivityReport nécessite une extension séparée
        // Pour l'instant, nous allons configurer le monitoring
        await setupDeviceActivityMonitoring()
    }
    
    private func setupDeviceActivityMonitoring() async {
        // Configuration d'une activité de monitoring pour récupérer les données
        let activityName = DeviceActivityName("ZenloopUsageTracking")
        
        // Créer un schedule pour toute la journée
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        do {
            // Démarrer le monitoring (nécessaire pour DeviceActivityReport)
            try deviceActivityCenter.startMonitoring(activityName, during: schedule)
            debugPrint("✅ [APP_USAGE] Monitoring DeviceActivity démarré")
            
            // Le monitoring est démarré, utilisons les données de fallback en attendant
            await loadMockDataAsync()
            debugPrint("✅ [APP_USAGE] Monitoring actif, données de fallback chargées")
        } catch {
            debugPrint("❌ [APP_USAGE] Erreur monitoring: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadMockDataAsync() async {
        await MainActor.run {
            self.loadMockData()
            self.isLoading = false
        }
    }
    
    private func loadMockData() {
        // Données de test visibles pour debugging
        let mockApps = [
            AppUsageInfo(name: "Instagram", bundleId: "com.burbn.instagram", dailyUsage: 5400, isProductive: false),
            AppUsageInfo(name: "Safari", bundleId: "com.apple.mobilesafari", dailyUsage: 3600, isProductive: true),
            AppUsageInfo(name: "Messages", bundleId: "com.apple.MobileSMS", dailyUsage: 2700, isProductive: true)
        ]
        
        usageStats = UsageStats(
            dailyTotal: 14400, // 4 heures
            weeklyTotal: 100800, // 28 heures par semaine
            topApps: mockApps,
            productiveTime: 6300, // 1h45 productive
            unproductiveTime: 8100, // 2h15 non-productive
            hourlyData: [],
            hasRealData: false
        )
        
        debugPrint("📱 [APP_USAGE] Données fallback chargées:")
        debugPrint("📱 [APP_USAGE] Temps quotidien: \(formatTime(14400))")
        debugPrint("📱 [APP_USAGE] Apps: \(mockApps.map(\.name).joined(separator: ", "))")
        debugPrint("📱 [APP_USAGE] Productivité: \(usageStats.productivityPercentage)%")
    }
    
    // MARK: - Helpers
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func formatTimeForStats(_ seconds: TimeInterval) -> (value: String, unit: String) {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return (value: "\(hours)h\(minutes > 0 ? "\(minutes)m" : "")", unit: "")
        } else {
            return (value: "\(minutes)", unit: "min")
        }
    }
    
    func refresh() {
        loadUsageData()
    }

    /// Afficher le toast de l'app la plus utilisée
    func showTopAppToastIfAvailable() {
        guard let topApp = topApp, !showTopAppToast else { return }

        debugPrint("📢 [APP_USAGE] Affichage du toast pour: \(topApp.name)")
        showTopAppToast = true
    }

    /// Mapper le bundleId vers une icône système
    func getSystemIcon(for bundleId: String) -> String? {
        switch bundleId {
        case "com.apple.mobilesafari": return "safari"
        case "com.apple.MobileSMS": return "message.fill"
        case "com.burbn.instagram": return "photo.on.rectangle.angled"
        case "com.apple.mobilemail": return "envelope.fill"
        case "com.apple.mobilecal": return "calendar"
        case "com.apple.reminders": return "checklist"
        case "com.apple.MobileNotes": return "note.text"
        case "com.tiktokv.TikTok": return "play.rectangle.fill"
        case "com.facebook.Facebook": return "person.2.fill"
        case "com.google.chrome.ios": return "globe"
        case "com.spotify.client": return "music.note"
        case "com.netflix.Netflix": return "tv.fill"
        case "com.snapchat.snapchat": return "camera.fill"
        default: return nil
        }
    }
}