//
//  TotalActivityReport.swift
//  zenloopactivity (Extension)
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Extension Types

struct ExtensionActivityReport {
    let totalDuration: TimeInterval
    let averageDaily: TimeInterval
    let averageWeekly: TimeInterval
    let allApps: [ExtensionAppUsage]
    let categories: [ExtensionCategoryUsage]
    let todayScreenSeconds: TimeInterval
    let todayOffScreenSeconds: TimeInterval
}

struct ExtensionAppUsage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    #if os(iOS)
    let token: ApplicationToken
    #endif
}

struct ExtensionCategoryUsage: Identifiable, Hashable {
    let id = UUID()
    let categoryName: String
    let duration: TimeInterval
    let appCount: Int
    
    var systemImage: String {
        let n = categoryName.lowercased()
        if n.contains("social") { return "person.2.fill" }
        if n.contains("productivity") || n.contains("business") { return "briefcase.fill" }
        if n.contains("finance") { return "creditcard.fill" }
        if n.contains("entertainment") || n.contains("games") { return "tv.fill" }
        if n.contains("education") { return "book.fill" }
        if n.contains("health") || n.contains("fitness") { return "heart.fill" }
        if n.contains("photo") || n.contains("video") { return "photo.on.rectangle.angled" }
        if n.contains("music") || n.contains("audio") { return "music.note" }
        if n.contains("navigation") || n.contains("travel") { return "location.fill" }
        if n.contains("shopping") { return "bag.fill" }
        if n.contains("news") || n.contains("reading") { return "newspaper.fill" }
        return "app.fill"
    }
    
    var color: Color {
        let n = categoryName.lowercased()
        if n.contains("social") { return .blue }
        if n.contains("productivity") || n.contains("business") { return .green }
        if n.contains("finance") { return .orange }
        if n.contains("entertainment") || n.contains("games") { return .purple }
        if n.contains("education") { return .teal }
        if n.contains("health") || n.contains("fitness") { return .pink }
        if n.contains("photo") || n.contains("video") { return .indigo }
        if n.contains("music") || n.contains("audio") { return .red }
        if n.contains("navigation") || n.contains("travel") { return .yellow }
        if n.contains("shopping") { return .mint }
        if n.contains("news") || n.contains("reading") { return .cyan }
        return .gray
    }
}

struct SharedReportPayload: Codable {
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
    let hourlyData: [SharedReportHourPoint]  // ✅ Nouvelles données horaires
}

struct SharedReportHourPoint: Codable {
    let hour: Int  // 0-23
    let categories: [SharedReportHourCategory]
}

struct SharedReportHourCategory: Codable {
    let name: String
    let seconds: Double
}

struct SharedReportApp: Codable {
    let name: String
    let seconds: Double
    let bundleId: String?  // Peut être nil si non disponible
}

struct SharedReportCategory: Codable {
    let name: String
    let seconds: Double
    let appCount: Int
}

struct SharedReportDayPoint: Codable {
    let dayStart: TimeInterval
    let seconds: Double
}


extension DeviceActivityReport.Context {
    static let totalActivity = Self("TotalActivity")
}

// MARK: - Report Scene

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TotalActivity")
    let content: (ExtensionActivityReport) -> TotalActivityView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityReport")
    private let appGroupSuite = "group.com.app.zenloop" // ← adapte si besoin
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ExtensionActivityReport {
        logger.critical("🚀 [REPORT] === TotalActivityReport makeConfiguration CALLED ===")
        logger.critical("🚀 [REPORT] Context: \(context.rawValue)")
        logger.critical("🚀 [REPORT] App Group Suite: \(appGroupSuite)")
        
        var totalDuration: TimeInterval = 0
        
        // Agrégations
        var appDurations: [ApplicationToken: (name: String, duration: TimeInterval)] = [:]
        var categoryDurationsByID: [String: TimeInterval] = [:]
        var categoryDisplayNameByID: [String: String] = [:]
        var categoryAppTokensByID: [String: Set<ApplicationToken>] = [:]

        // Série journalière découpée finement
        var dailyDurations: [Date: TimeInterval] = [:]

        // ✅ Données horaires par catégorie (pour le graphique)
        var hourlyData: [Int: [String: TimeInterval]] = [:]  // [hour: [categoryName: duration]]
        
        // Intervalle global
        var globalStart: Date?
        var globalEnd: Date?
        
        let cal = Calendar.current
        logger.critical("🔍 [REPORT] Start processing DeviceActivity data...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                let seg = segment.dateInterval
                let segDur = segment.totalActivityDuration
                guard segDur > 0 else { continue }
                
                totalDuration += segDur
                if globalStart == nil || seg.start < globalStart! { globalStart = seg.start }
                if globalEnd == nil || seg.end > globalEnd! { globalEnd = seg.end }
                
                // Répartition par jour
                distribute(segment: seg, duration: segDur, calendar: cal) { dayStart, secs in
                    dailyDurations[dayStart, default: 0] += secs
                }

                // ✅ Extraire l'heure pour les données horaires
                let segmentHour = cal.component(.hour, from: seg.start)

                // Catégories & apps
                for await catActivity in segment.categories {
                    let cat: ActivityCategory = catActivity.category
                    let catID = stableCategoryID(cat)
                    let catName = displayName(for: cat)

                    categoryDisplayNameByID[catID] = catName
                    categoryDurationsByID[catID, default: 0] += catActivity.totalActivityDuration

                    // ✅ Ajouter aux données horaires
                    if hourlyData[segmentHour] == nil {
                        hourlyData[segmentHour] = [:]
                    }
                    hourlyData[segmentHour]![catName, default: 0] += catActivity.totalActivityDuration
                    
                    for await app in catActivity.applications {
                        let dur = app.totalActivityDuration
                        guard dur > 0 else { continue }
                        let name = app.application.localizedDisplayName
                            ?? app.application.bundleIdentifier
                            ?? "Application"
                        if let token = app.application.token {
                            var cur = appDurations[token] ?? (name: name, duration: 0)
                            if cur.name.isEmpty, !name.isEmpty { cur.name = name }
                            cur.duration += dur
                            appDurations[token] = cur
                            
                            var set = categoryAppTokensByID[catID] ?? []
                            set.insert(token)
                            categoryAppTokensByID[catID] = set
                        }
                    }
                }
            }
        }
        
        // Apps triées
        let allApps: [ExtensionAppUsage] = appDurations
            .map { (token, v) in 
                #if os(iOS)
                ExtensionAppUsage(name: v.name, duration: v.duration, token: token)
                #else
                ExtensionAppUsage(name: v.name, duration: v.duration)
                #endif
            }
            .sorted { $0.duration > $1.duration }
        
        // Catégories triées
        let allCategories: [ExtensionCategoryUsage] = categoryDurationsByID.map { (catID, secs) in
            let name = categoryDisplayNameByID[catID] ?? catID
            let appCount = categoryAppTokensByID[catID]?.count ?? 0
            return ExtensionCategoryUsage(categoryName: name, duration: secs, appCount: appCount)
        }
        .sorted { $0.duration > $1.duration }
        
        // Top 4
        let top4 = Array(allCategories.prefix(4))
        
        // Jours uniques (après répartition)
        let daysSorted = dailyDurations
            .map { (cal.startOfDay(for: $0.key), $0.value) }
            .reduce(into: [Date: TimeInterval]()) { acc, pair in
                acc[pair.0, default: 0] += pair.1
            }
            .sorted { $0.key < $1.key }
        
        let dayCount = max(1, daysSorted.count)
        let averageDaily = totalDuration / Double(dayCount)
        
        let start = globalStart ?? Date()
        let end = globalEnd ?? start
        
        // Calcul du temps d'écran et hors écran d'aujourd'hui
        let todayStart = cal.startOfDay(for: Date())
        let todayScreen = dailyDurations[todayStart] ?? 0
        let elapsedToday = max(0, Date().timeIntervalSince(todayStart))
        let todayOff = max(0, elapsedToday - todayScreen)
        
        // — App Group JSON partagé —
        let topAppsShared = Array(allApps.prefix(10)).map { app in
            SharedReportApp(
                name: app.name,
                seconds: app.duration,
                bundleId: nil  // Token non-sérialisable, on mettra nil côté app
            )
        }

        // ✅ Formater les données horaires
        let hourlyDataShared = (0..<24).map { hour -> SharedReportHourPoint in
            let categories = (hourlyData[hour] ?? [:]).map { catName, secs in
                SharedReportHourCategory(name: catName, seconds: secs)
            }.sorted { $0.seconds > $1.seconds }
            return SharedReportHourPoint(hour: hour, categories: categories)
        }

        let payload = SharedReportPayload(
            intervalStart: start.timeIntervalSince1970,
            intervalEnd: end.timeIntervalSince1970,
            totalSeconds: totalDuration,
            averageDailySeconds: averageDaily,
            updatedAt: Date().timeIntervalSince1970,
            topCategories: top4.map {
                SharedReportCategory(name: $0.categoryName, seconds: $0.duration, appCount: $0.appCount)
            },
            days: daysSorted.map {
                SharedReportDayPoint(dayStart: $0.key.timeIntervalSince1970, seconds: $0.value)
            },
            todayScreenSeconds: todayScreen,
            todayOffScreenSeconds: todayOff,
            topApps: topAppsShared,
            hourlyData: hourlyDataShared  // ✅ Ajouter les données horaires
        )
        persistSharedReport(payload)
        
        // Legacy miroir simple (si tu l'utilisais côté app)
        persistLegacyMirror(total: totalDuration,
                            averageDaily: averageDaily,
                            periodTotal: end.timeIntervalSince(start),
                            topApps: allApps)
        
        logger.info("✅ [REPORT] total=\(totalDuration, privacy: .public)s avgDaily=\(averageDaily, privacy: .public)s days=\(dayCount, privacy: .public)")
        logger.info("📊 [REPORT] apps=\(allApps.count, privacy: .public) topCats=\(top4.count, privacy: .public)")
        logger.info("📅 [REPORT] todayScreen=\(todayScreen, privacy: .public)s todayOff=\(todayOff, privacy: .public)s")
        
        return ExtensionActivityReport(
            totalDuration: totalDuration,
            averageDaily: averageDaily,
            averageWeekly: end.timeIntervalSince(start),
            allApps: allApps,
            categories: top4,
            todayScreenSeconds: todayScreen,
            todayOffScreenSeconds: todayOff
        )
    }
}

// MARK: - Catégories & libellés

private func stableCategoryID(_ category: ActivityCategory) -> String {
    String(reflecting: category) // ex: "ManagedSettings.ActivityCategory.socialNetworking"
}

private func displayName(for category: ActivityCategory) -> String {
    if #available(iOS 17.0, *) {
        if let native = category.localizedDisplayName,
           !native.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return native
        }
    }
    let qualified = String(reflecting: category) // "...ActivityCategory.socialNetworking"
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

// MARK: - Répartition par jour

private func distribute(segment: DateInterval,
                        duration: TimeInterval,
                        calendar: Calendar,
                        sink: (Date, TimeInterval) -> Void) {
    guard duration > 0, segment.duration > 0 else { return }
    var cursor = segment.start
    let end = segment.end
    while cursor < end {
        let dayStart = calendar.startOfDay(for: cursor)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
        let intervalEnd = min(dayEnd, end)
        let overlap = intervalEnd.timeIntervalSince(cursor)
        if overlap > 0 {
            let proportion = overlap / segment.duration
            sink(dayStart, duration * proportion)
        }
        cursor = intervalEnd
    }
}

// MARK: - Persistance App Group

private func persistSharedReport(_ payload: SharedReportPayload) {
    let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityReport")
    logger.critical("💾 [REPORT] === PERSIST SHARED REPORT CALLED ===")
    logger.critical("💾 [REPORT] Payload totalSeconds: \(payload.totalSeconds)")
    logger.critical("💾 [REPORT] Payload todayScreenSeconds: \(payload.todayScreenSeconds)")
    
    guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else {
        logger.error("❌ [REPORT] App Group indisponible")
        return
    }
    
    logger.critical("💾 [REPORT] App Group UserDefaults OK")
    
    do {
        let data = try JSONEncoder().encode(payload)
        shared.set(data, forKey: "DAReportLatest")
        let success = shared.synchronize()
        logger.critical("💾 [REPORT] JSON written to DAReportLatest, sync success: \(success)")
        
        // Test read back immediately
        if let readBack = shared.data(forKey: "DAReportLatest") {
            logger.critical("✅ [REPORT] Verification: Data read back successfully, size: \(readBack.count) bytes")
        } else {
            logger.error("❌ [REPORT] Verification failed: Cannot read back data!")
        }
        
    } catch {
        logger.error("❌ [REPORT] Encodage JSON: \(error.localizedDescription, privacy: .public)")
    }
}

private func persistLegacyMirror(total: TimeInterval,
                                 averageDaily: TimeInterval,
                                 periodTotal: TimeInterval,
                                 topApps: [ExtensionAppUsage]) {
    let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityReport")
    guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else {
        logger.error("❌ [REPORT] Legacy: App Group indisponible")
        return
    }
    let dict: [String: Any] = [
        "totalDuration": total,
        "averageDaily": averageDaily,
        "averageWeekly": periodTotal,
        "lastUpdated": Date().timeIntervalSince1970,
        "topAppsCount": topApps.count,
        "topAppsNames": topApps.map(\.name)
    ]
    shared.set(dict, forKey: "DeviceActivityData")
    shared.synchronize()
    logger.info("💾 [REPORT] Legacy mirror écrit (DeviceActivityData)")
}

