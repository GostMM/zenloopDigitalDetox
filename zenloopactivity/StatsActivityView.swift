//
//  StatsActivityView.swift
//  zenloopactivity
//
//  Vue dédiée pour les statistiques de la HomeView
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log

// MARK: - Stats Report Scene

struct StatsActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("StatsActivity")
    let content: (StatsReportData) -> StatsActivityView

    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "StatsActivityReport")

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> StatsReportData {
        logger.critical("🚀🚀🚀 [STATS_REPORT] === makeConfiguration CALLED ===")
        logger.critical("🚀 [STATS_REPORT] Context: StatsActivity")

        var totalDuration: TimeInterval = 0
        var hourlyData: [Int: [String: TimeInterval]] = [:]
        #if os(iOS)
        var appDurations: [ApplicationToken: (name: String, duration: TimeInterval, bundleId: String?)] = [:]
        #else
        var appDurations: [String: (name: String, duration: TimeInterval, bundleId: String?)] = [:]
        #endif

        let cal = Calendar.current

        // Extraire toutes les données
        for await datum in data {
            for await segment in datum.activitySegments {
                let seg = segment.dateInterval
                let segDur = segment.totalActivityDuration
                guard segDur > 0 else { continue }

                totalDuration += segDur
                let segmentHour = cal.component(.hour, from: seg.start)

                // Traiter chaque catégorie
                for await catActivity in segment.categories {
                    let cat: ActivityCategory = catActivity.category
                    let catName = displayName(for: cat)

                    // Ajouter aux données horaires
                    if hourlyData[segmentHour] == nil {
                        hourlyData[segmentHour] = [:]
                    }
                    hourlyData[segmentHour]![catName, default: 0] += catActivity.totalActivityDuration

                    // Traiter les applications avec TOKEN
                    for await app in catActivity.applications {
                        let dur = app.totalActivityDuration
                        guard dur > 0 else { continue }

                        let name = app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "App"
                        let bundleId = app.application.bundleIdentifier

                        #if os(iOS)
                        if let token = app.application.token {
                            var current = appDurations[token] ?? (name: name, duration: 0, bundleId: bundleId)
                            if current.name.isEmpty, !name.isEmpty { current.name = name }
                            current.duration += dur
                            appDurations[token] = current
                        }
                        #else
                        let key = bundleId ?? name
                        var current = appDurations[key] ?? (name: name, duration: 0, bundleId: bundleId)
                        if current.name.isEmpty, !name.isEmpty { current.name = name }
                        current.duration += dur
                        appDurations[key] = current
                        #endif
                    }
                }
            }
        }

        // Formater données horaires
        let hourlyDataFormatted = (0..<24).map { hour -> StatsHourPoint in
            let categories = (hourlyData[hour] ?? [:]).map { catName, secs in
                StatsHourCategory(name: catName, seconds: secs)
            }.sorted { $0.seconds > $1.seconds }
            return StatsHourPoint(hour: hour, categories: categories)
        }

        // Top 3 apps AVEC TOKENS
        #if os(iOS)
        let topApps = appDurations
            .sorted { $0.value.duration > $1.value.duration }
            .prefix(3)
            .map { token, value in
                StatsAppInfo(name: value.name, seconds: value.duration, bundleId: value.bundleId, token: token)
            }
        #else
        let topApps = appDurations.values
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { StatsAppInfo(name: $0.name, seconds: $0.duration, bundleId: $0.bundleId) }
        #endif

        logger.critical("✅ [STATS_REPORT] FINISHED!")
        logger.critical("✅ [STATS_REPORT] Total duration: \(totalDuration)s")
        logger.critical("✅ [STATS_REPORT] Apps found: \(topApps.count)")
        logger.critical("✅ [STATS_REPORT] Hours with data: \(hourlyData.count)")

        // ✅ SAVE TO APP GROUP
        let payload = StatsReportPayload(
            totalSeconds: totalDuration,
            hourlyData: hourlyDataFormatted.map { hour in
                StatsHourPayload(
                    hour: hour.hour,
                    categories: hour.categories.map { cat in
                        StatsHourCategoryPayload(name: cat.name, seconds: cat.seconds)
                    }
                )
            },
            topApps: Array(topApps).map { app in
                StatsAppPayload(name: app.name, seconds: app.seconds, bundleId: app.bundleId)
            },
            timestamp: Date().timeIntervalSince1970
        )
        persistStatsReport(payload)

        let result = StatsReportData(
            totalSeconds: totalDuration,
            hourlyData: hourlyDataFormatted,
            topApps: Array(topApps)
        )

        logger.critical("🎯 [STATS_REPORT] Returning data to view...")
        return result
    }
}

// MARK: - Data Models

struct StatsReportData {
    let totalSeconds: TimeInterval
    let hourlyData: [StatsHourPoint]
    let topApps: [StatsAppInfo]
}

struct StatsHourPoint {
    let hour: Int  // 0-23
    let categories: [StatsHourCategory]
}

struct StatsHourCategory {
    let name: String
    let seconds: TimeInterval
}

struct StatsAppInfo {
    let name: String
    let seconds: TimeInterval
    let bundleId: String?
    #if os(iOS)
    let token: ApplicationToken?  // ✅ Token pour afficher la vraie icône
    #endif
}

// MARK: - View

struct StatsActivityView: View {
    let reportData: StatsReportData
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "StatsActivityView")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header compact avec titre et total
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("screen_time", comment: "Screen Time title"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    Text(formattedTotalTime)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // App la plus utilisée (remplace l'icône chart)
                if let topApp = reportData.topApps.first {
                    #if os(iOS)
                    if let token = topApp.token {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        placeholderAppIcon
                    }
                    #else
                    placeholderAppIcon
                    #endif
                } else {
                    placeholderAppIcon
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Message si pas de données
            if reportData.totalSeconds == 0 {
                VStack(spacing: 16) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))

                    Text("No activity yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                // GRAPHIQUE ET LÉGENDES RETIRÉS POUR RÉDUIRE LA HAUTEUR
                // Seulement le séparateur + top apps

                // Séparateur subtil
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Top apps avec jauges colorées
                if !reportData.topApps.isEmpty {
                    let maxDuration = reportData.topApps.first?.seconds ?? 1

                    VStack(spacing: 0) {
                        ForEach(Array(reportData.topApps.prefix(3).enumerated()), id: \.offset) { index, app in
                            StatsAppRow(
                                app: app,
                                duration: formatTime(app.seconds),
                                rank: index + 1,
                                maxDuration: maxDuration
                            )

                            if index < min(2, reportData.topApps.count - 1) {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }

            // Padding bottom pour respirer
            Spacer()
                .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.18, blue: 0.18),
                            Color(red: 0.15, green: 0.15, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            logger.critical("📊 [STATS_VIEW] VIEW APPEARED!")
            logger.critical("📊 [STATS_VIEW] Total: \(reportData.totalSeconds)s")
            logger.critical("📊 [STATS_VIEW] Apps: \(reportData.topApps.count)")
        }
    }

    // MARK: - Helper pour couleur catégorie

    private func getCategoryColor(for bundleId: String) -> Color {
        let id = bundleId.lowercased()
        if id.contains("safari") || id.contains("chrome") || id.contains("notion") {
            return .blue
        } else if id.contains("instagram") || id.contains("facebook") || id.contains("twitter") {
            return .cyan
        } else if id.contains("game") {
            return .orange
        }
        return .purple
    }

    // MARK: - Computed Properties

    private var formattedTotalTime: String {
        let hours = Int(reportData.totalSeconds) / 3600
        let minutes = (Int(reportData.totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var hourlyChartData: [HourData] {
        reportData.hourlyData.map { hourPoint in
            let productivity = hourPoint.categories.first { isProductivity($0.name) }?.seconds ?? 0
            let social = hourPoint.categories.first { isSocial($0.name) }?.seconds ?? 0
            let games = hourPoint.categories.first { isGames($0.name) }?.seconds ?? 0

            return HourData(
                hour: hourPoint.hour,
                productivity: productivity,
                social: social,
                games: games
            )
        }
    }

    private var categoryDurations: (productivity: TimeInterval, social: TimeInterval, games: TimeInterval) {
        var prod: TimeInterval = 0
        var soc: TimeInterval = 0
        var gam: TimeInterval = 0

        for hourPoint in reportData.hourlyData {
            for category in hourPoint.categories {
                if isProductivity(category.name) {
                    prod += category.seconds
                } else if isSocial(category.name) {
                    soc += category.seconds
                } else if isGames(category.name) {
                    gam += category.seconds
                }
            }
        }

        return (prod, soc, gam)
    }

    // MARK: - Helper Functions

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }

    private func isProductivity(_ categoryName: String) -> Bool {
        let lower = categoryName.lowercased()
        return lower.contains("productivity") || lower.contains("business") ||
               lower.contains("education") || lower.contains("reference") ||
               lower.contains("utilities")
    }

    private func isSocial(_ categoryName: String) -> Bool {
        let lower = categoryName.lowercased()
        return lower.contains("social") || lower.contains("messaging")
    }

    private func isGames(_ categoryName: String) -> Bool {
        let lower = categoryName.lowercased()
        return lower.contains("game") || lower.contains("entertainment")
    }

    // Placeholder pour l'icône d'app quand token non disponible
    private var placeholderAppIcon: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            )
    }
}

// MARK: - Chart Components

struct HourData {
    let hour: Int
    let productivity: TimeInterval
    let social: TimeInterval
    let games: TimeInterval

    var total: TimeInterval {
        productivity + social + games
    }
}

struct BarChart: View {
    let data: [HourData]

    private var maxValue: TimeInterval {
        data.map(\.total).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<24) { hour in
                let hourData = data.first { $0.hour == hour } ?? HourData(hour: hour, productivity: 0, social: 0, games: 0)

                VStack(spacing: 0) {
                    if hourData.total > 0 {
                        // Stack des catégories
                        VStack(spacing: 0) {
                            if hourData.productivity > 0 {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(height: (hourData.productivity / maxValue) * 120)
                            }
                            if hourData.social > 0 {
                                Rectangle()
                                    .fill(Color.cyan)
                                    .frame(height: (hourData.social / maxValue) * 120)
                            }
                            if hourData.games > 0 {
                                Rectangle()
                                    .fill(Color.orange)
                                    .frame(height: (hourData.games / maxValue) * 120)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    } else {
                        // Barre vide
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                .frame(maxHeight: 140, alignment: .bottom)
            }
        }
    }
}

struct CategoryLegend: View {
    let color: Color
    let title: String
    let duration: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(duration)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TopAppRow: View {
    let appName: String
    let duration: String
    let bundleId: String

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder icon (l'extension ne peut pas accéder aux tokens)
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(duration)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
    }
}

// MARK: - Helper Functions

private func displayName(for category: ActivityCategory) -> String {
    if #available(iOS 17.0, *) {
        if let native = category.localizedDisplayName,
           !native.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return native
        }
    }
    let qualified = String(reflecting: category)
    let rawCase = qualified.split(separator: ".").last.map(String.init) ?? qualified
    return humanizeEnumCase(rawCase)
}

private func humanizeEnumCase(_ s: String) -> String {
    let base = s.replacingOccurrences(of: "_", with: " ")
    let spaced = base.replacingOccurrences(of: "([a-z])([A-Z])",
                                           with: "$1 $2",
                                           options: .regularExpression)
    let words = spaced.split(separator: " ").map { $0.lowercased().capitalized }
    let result = words.joined(separator: " ")
    switch result {
    case "Socialnetworking": return "Social Networking"
    case "Photovideo":       return "Photo & Video"
    case "Healthfitness":    return "Health & Fitness"
    default:                 return result
    }
}

// MARK: - Modern Components

struct ModernBarChart: View {
    let data: [HourData]

    private var maxValue: TimeInterval {
        data.map(\.total).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<24) { hour in
                let hourData = data.first { $0.hour == hour } ?? HourData(hour: hour, productivity: 0, social: 0, games: 0)

                VStack(spacing: 0) {
                    if hourData.total > 0 {
                        // Stack des catégories avec gradient
                        VStack(spacing: 0) {
                            if hourData.games > 0 {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: (hourData.games / maxValue) * 100)
                            }
                            if hourData.social > 0 {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.cyan.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: (hourData.social / maxValue) * 100)
                            }
                            if hourData.productivity > 0 {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: (hourData.productivity / maxValue) * 100)
                            }
                        }
                    } else {
                        // Barre vide minimaliste
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 3)
                    }
                }
                .frame(maxHeight: 100, alignment: .bottom)
            }
        }
    }
}

struct CompactLegend: View {
    let icon: String
    let color: Color
    let title: String
    let duration: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 16, height: 16)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Text(duration)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatsAppRow: View {
    let app: StatsAppInfo
    let duration: String
    let rank: Int
    let maxDuration: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            // ✅ VRAIE ICÔNE D'APP via Label(token)
            #if os(iOS)
            if let token = app.token {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                placeholderIcon
            }
            #else
            placeholderIcon
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(duration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Mini jauge horizontale compacte à droite (comme badge)
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 6)

                // Progression colorée
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: getIntensityGradient(percentage: app.seconds / maxDuration),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50 * CGFloat(app.seconds / maxDuration), height: 6)
                    .shadow(color: getIntensityColor(percentage: app.seconds / maxDuration).opacity(0.5), radius: 3, x: 0, y: 1)
            }
        }
        .padding(.vertical, 8)
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.blue.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
            )
    }

    // Couleur selon l'intensité d'usage (0.0 à 1.0)
    private func getIntensityColor(percentage: Double) -> Color {
        switch percentage {
        case 0.9...1.0:  // 90-100% = Violet/Magenta (EXTRÊME)
            return Color(red: 0.8, green: 0.2, blue: 0.8)
        case 0.7..<0.9:  // 70-90% = Rouge (Très élevé)
            return Color(red: 1.0, green: 0.2, blue: 0.3)
        case 0.5..<0.7:  // 50-70% = Orange (Élevé)
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case 0.3..<0.5:  // 30-50% = Jaune (Modéré)
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        default:         // 0-30% = Vert (Faible)
            return Color(red: 0.3, green: 0.8, blue: 0.4)
        }
    }

    // Dégradé premium selon l'intensité
    private func getIntensityGradient(percentage: Double) -> [Color] {
        switch percentage {
        case 0.9...1.0:  // Violet extrême
            return [
                Color(red: 0.6, green: 0.1, blue: 0.8),  // Violet foncé
                Color(red: 0.9, green: 0.3, blue: 0.9),  // Magenta
                Color(red: 0.8, green: 0.2, blue: 1.0)   // Violet clair
            ]
        case 0.7..<0.9:  // Rouge intense
            return [
                Color(red: 0.8, green: 0.1, blue: 0.2),  // Rouge foncé
                Color(red: 1.0, green: 0.2, blue: 0.3),  // Rouge vif
                Color(red: 1.0, green: 0.4, blue: 0.4)   // Rouge clair
            ]
        case 0.5..<0.7:  // Orange élevé
            return [
                Color(red: 1.0, green: 0.4, blue: 0.1),  // Orange foncé
                Color(red: 1.0, green: 0.6, blue: 0.2),  // Orange
                Color(red: 1.0, green: 0.7, blue: 0.3)   // Orange clair
            ]
        case 0.3..<0.5:  // Jaune modéré
            return [
                Color(red: 1.0, green: 0.7, blue: 0.1),  // Jaune doré
                Color(red: 1.0, green: 0.8, blue: 0.2),  // Jaune
                Color(red: 1.0, green: 0.9, blue: 0.4)   // Jaune clair
            ]
        default:         // Vert faible
            return [
                Color(red: 0.2, green: 0.7, blue: 0.3),  // Vert foncé
                Color(red: 0.3, green: 0.8, blue: 0.4),  // Vert
                Color(red: 0.5, green: 0.9, blue: 0.5)   // Vert clair
            ]
        }
    }
}

// MARK: - Codable Payload Models

struct StatsReportPayload: Codable {
    let totalSeconds: TimeInterval
    let hourlyData: [StatsHourPayload]
    let topApps: [StatsAppPayload]
    let timestamp: TimeInterval
}

struct StatsHourPayload: Codable {
    let hour: Int
    let categories: [StatsHourCategoryPayload]
}

struct StatsHourCategoryPayload: Codable {
    let name: String
    let seconds: TimeInterval
}

struct StatsAppPayload: Codable {
    let name: String
    let seconds: TimeInterval
    let bundleId: String?
}

// MARK: - Persistence

private func persistStatsReport(_ payload: StatsReportPayload) {
    let logger = Logger(subsystem: "com.app.zenloop.activity", category: "StatsActivityReport")
    logger.critical("💾 [STATS_REPORT] === PERSIST STATS REPORT CALLED ===")
    logger.critical("💾 [STATS_REPORT] Payload totalSeconds: \(payload.totalSeconds)")
    logger.critical("💾 [STATS_REPORT] Payload topApps count: \(payload.topApps.count)")

    guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else {
        logger.error("❌ [STATS_REPORT] App Group indisponible")
        return
    }

    logger.critical("💾 [STATS_REPORT] App Group UserDefaults OK")

    do {
        let data = try JSONEncoder().encode(payload)
        shared.set(data, forKey: "StatsReportLatest")
        let success = shared.synchronize()
        logger.critical("💾 [STATS_REPORT] JSON written to StatsReportLatest, sync success: \(success)")

        // Verify immediately
        if let readBack = shared.data(forKey: "StatsReportLatest") {
            logger.critical("✅ [STATS_REPORT] Verification: Data read back successfully, size: \(readBack.count) bytes")
        } else {
            logger.error("❌ [STATS_REPORT] Verification failed: Cannot read back data!")
        }

    } catch {
        logger.error("❌ [STATS_REPORT] Encodage JSON: \(error.localizedDescription, privacy: .public)")
    }
}
