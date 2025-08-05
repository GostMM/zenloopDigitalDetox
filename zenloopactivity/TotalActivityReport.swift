//
//  TotalActivityReport.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import DeviceActivity
import SwiftUI
import os.log
import ManagedSettings
import FamilyControls

// MARK: - Data Models

struct ActivityReport {
    let totalDuration: TimeInterval
    let averageDaily: TimeInterval
    let averageWeekly: TimeInterval
    let top3Apps: [AppUsage]
}

struct AppUsage {
    let name: String
    let duration: TimeInterval
    let token: ApplicationToken
}

extension DeviceActivityReport.Context {
    static let totalActivity = Self("TotalActivity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityReport) -> TotalActivityView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityReport")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        var totalDuration: TimeInterval = 0
        var appUsages: [AppUsage] = []
        var segmentCount = 0
        
        logger.info("🔍 [ACTIVITY_REPORT] Début traitement données DeviceActivity...")
        print("🔍 [ACTIVITY_REPORT] Début traitement données DeviceActivity...")
        NSLog("🔍 [ACTIVITY_REPORT] Début traitement données DeviceActivity...")
        
        // Test immédiat: sauvegarder des données de test pour confirmer que l'extension s'exécute
        saveTestDataToAppGroup()
        
        // Traiter les données pour tous les segments
        for await datum in data {
            logger.info("📱 [ACTIVITY_REPORT] Device: \(datum.device.name ?? "Unknown")")
            logger.info("📱 [ACTIVITY_REPORT] Device type: \(String(describing: type(of: datum.device)))")
            
            for await segment in datum.activitySegments {
                totalDuration += segment.totalActivityDuration
                segmentCount += 1
                
                logger.info("⏱️ [ACTIVITY_REPORT] Segment: \(segment.totalActivityDuration)s")
                logger.info("⏱️ [ACTIVITY_REPORT] Segment type: \(String(describing: type(of: segment)))")
                logger.info("⏱️ [ACTIVITY_REPORT] Segment dateInterval: \(segment.dateInterval)")
                
                // Récupérer les applications via les catégories
                logger.info("📂 [ACTIVITY_REPORT] Categories found - Type: \(String(describing: type(of: segment.categories)))")
                var categoryIndex = 0
                for await category in segment.categories {
                    categoryIndex += 1
                    logger.info("📂 [ACTIVITY_REPORT] Catégorie \(categoryIndex) - Type: \(String(describing: type(of: category)))")
                    logger.info("📂 [ACTIVITY_REPORT] Catégorie duration: \(category.totalActivityDuration)s")
                    logger.info("📂 [ACTIVITY_REPORT] Applications found - Type: \(String(describing: type(of: category.applications)))")
                    
                    var appIndex = 0
                    for await app in category.applications {
                        appIndex += 1
                        logger.info("🔍 [ACTIVITY_REPORT] App \(appIndex) - Type: \(String(describing: type(of: app)))")
                        logger.info("🔍 [ACTIVITY_REPORT] App duration: \(app.totalActivityDuration)s")
                        
                        // Accéder aux vraies propriétés d'application
                        let duration = app.totalActivityDuration
                        let numberOfPickups = app.numberOfPickups
                        
                        // Dans une Device Activity Report Extension, on DEVRAIT avoir accès aux noms
                        let displayName = app.application.localizedDisplayName
                        let bundleId = app.application.bundleIdentifier
                        
                        logger.info("🔍 [ACTIVITY_REPORT] App \(appIndex) details:")
                        logger.info("  - Display Name: \(displayName ?? "nil")")
                        logger.info("  - Bundle ID: \(bundleId ?? "nil")")
                        logger.info("  - Duration: \(duration)s")
                        logger.info("  - Pickups: \(numberOfPickups)")
                        
                        let appName = displayName ?? bundleId ?? "Application \(appUsages.count + 1)"
                        
                        // Vérifier si le token existe
                        if let appToken = app.application.token {
                            logger.info("📱 [ACTIVITY_REPORT] App final: \(appName) - \(duration)s")
                            appUsages.append(AppUsage(name: appName, duration: duration, token: appToken))
                        } else {
                            logger.info("⚠️ [ACTIVITY_REPORT] App token is nil for: \(appName) - skipping")
                        }
                    }
                }
            }
        }
        
        // Trier les apps par durée descendante et prendre les top 3
        let top3Apps = appUsages.sorted { $0.duration > $1.duration }.prefix(3)
        
        // Calculer moyennes selon votre guide
        let averageDaily: TimeInterval = segmentCount > 0 ? totalDuration / Double(segmentCount) : totalDuration
        let averageWeekly: TimeInterval = totalDuration * 7 // Estimation hebdomadaire
        
        logger.info("✅ [ACTIVITY_REPORT] Configuration créée:")
        logger.info("⏱️ [ACTIVITY_REPORT] Temps total: \(totalDuration)s")
        logger.info("📊 [ACTIVITY_REPORT] Moyenne quotidienne: \(averageDaily)s")
        logger.info("📈 [ACTIVITY_REPORT] Estimation hebdomadaire: \(averageWeekly)s")
        logger.info("🏆 [ACTIVITY_REPORT] Apps trouvées: \(appUsages.count)")
        logger.info("🥇 [ACTIVITY_REPORT] Top 3: \(top3Apps.map(\.name).joined(separator: ", "))")
        
        // Sauvegarder les données dans App Group pour l'app principale
        saveDataToAppGroup(totalDuration: totalDuration, averageDaily: averageDaily, averageWeekly: averageWeekly, topApps: Array(top3Apps))
        
        return ActivityReport(
            totalDuration: totalDuration,
            averageDaily: averageDaily,
            averageWeekly: averageWeekly,
            top3Apps: Array(top3Apps)
        )
    }
    
    private func saveDataToAppGroup(totalDuration: TimeInterval, averageDaily: TimeInterval, averageWeekly: TimeInterval, topApps: [AppUsage]) {
        // Utiliser App Group pour partager les données avec l'app principale
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.error("❌ [ACTIVITY_REPORT] Impossible d'accéder à App Group")
            return
        }
        
        // Pour debug : utilisons des valeurs distinctes pour confirmer le bridge
        let testDaily = totalDuration > 0 ? averageDaily : 7200 // 2h au lieu de 4h
        let testWeekly = totalDuration > 0 ? averageWeekly : 50400 // 14h au lieu de 28h
        
        let activityData: [String: Any] = [
            "totalDuration": totalDuration,
            "averageDaily": testDaily,
            "averageWeekly": testWeekly,
            "lastUpdated": Date().timeIntervalSince1970,
            "topAppsCount": topApps.count,
            "topAppsNames": topApps.map(\.name)
        ]
        
        logger.info("💾 [ACTIVITY_REPORT] Sauvegarde test - Daily: \(testDaily)s, Weekly: \(testWeekly)s")
        
        sharedDefaults.set(activityData, forKey: "DeviceActivityData")
        sharedDefaults.synchronize()
        
        logger.info("💾 [ACTIVITY_REPORT] Données sauvegardées dans App Group")
        logger.info("💾 [ACTIVITY_REPORT] Daily: \(averageDaily)s, Weekly: \(averageWeekly)s")
    }
    
    private func saveTestDataToAppGroup() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.error("❌ [ACTIVITY_REPORT] TEST: Impossible d'accéder à App Group")
            print("❌ [ACTIVITY_REPORT] TEST: Impossible d'accéder à App Group")
            NSLog("❌ [ACTIVITY_REPORT] TEST: Impossible d'accéder à App Group")
            return
        }
        
        // Sauvegarder des données de test distinctes (3h daily, 21h weekly)
        let testData: [String: Any] = [
            "totalDuration": 10800, // 3h
            "averageDaily": 10800,  // 3h (différent de 4h mock)
            "averageWeekly": 75600, // 21h (différent de 28h mock)
            "lastUpdated": Date().timeIntervalSince1970,
            "topAppsCount": 3,
            "topAppsNames": ["Safari", "Messages", "Instagram"],
            "testMarker": "EXTENSION_EXECUTED_\(Date().timeIntervalSince1970)"
        ]
        
        sharedDefaults.set(testData, forKey: "DeviceActivityData")
        sharedDefaults.synchronize()
        
        logger.info("💾 [ACTIVITY_REPORT] TEST: Données test sauvegardées (3h daily, 21h weekly)")
        print("💾 [ACTIVITY_REPORT] TEST: Données test sauvegardées (3h daily, 21h weekly)")
        NSLog("💾 [ACTIVITY_REPORT] TEST: Données test sauvegardées (3h daily, 21h weekly)")
    }
}
