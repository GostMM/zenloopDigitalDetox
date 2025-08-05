//
//  TotalActivityReport.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import DeviceActivity
import SwiftUI

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
}

extension DeviceActivityReport.Context {
    static let totalActivity = Self("TotalActivity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityReport) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        var totalDuration: TimeInterval = 0
        var appUsages: [AppUsage] = []
        var segmentCount = 0
        
        debugPrint("🔍 [ACTIVITY_REPORT] Début traitement données DeviceActivity...")
        
        // Traiter les données pour tous les segments
        for await datum in data {
            debugPrint("📱 [ACTIVITY_REPORT] Device: \(datum.device.name ?? "Unknown")")
            
            for await segment in datum.activitySegments {
                totalDuration += segment.totalActivityDuration
                segmentCount += 1
                
                debugPrint("⏱️ [ACTIVITY_REPORT] Segment: \(segment.totalActivityDuration)s")
                
                // Récupérer les applications via les catégories
                for await category in segment.categories {
                    debugPrint("📂 [ACTIVITY_REPORT] Catégorie trouvée")
                    
                    for await app in category.applications {
                        let appName = "App \(appUsages.count + 1)" // Les noms ne sont pas accessibles via token
                        let duration = app.totalActivityDuration
                        
                        debugPrint("📱 [ACTIVITY_REPORT] App: \(appName) - \(duration)s")
                        appUsages.append(AppUsage(name: appName, duration: duration))
                    }
                }
            }
        }
        
        // Trier les apps par durée descendante et prendre les top 3
        let top3Apps = appUsages.sorted { $0.duration > $1.duration }.prefix(3)
        
        // Calculer moyennes selon votre guide
        let averageDaily: TimeInterval = segmentCount > 0 ? totalDuration / Double(segmentCount) : totalDuration
        let averageWeekly: TimeInterval = totalDuration * 7 // Estimation hebdomadaire
        
        debugPrint("✅ [ACTIVITY_REPORT] Configuration créée:")
        debugPrint("⏱️ [ACTIVITY_REPORT] Temps total: \(totalDuration)s")
        debugPrint("📊 [ACTIVITY_REPORT] Moyenne quotidienne: \(averageDaily)s")
        debugPrint("📈 [ACTIVITY_REPORT] Estimation hebdomadaire: \(averageWeekly)s")
        debugPrint("🏆 [ACTIVITY_REPORT] Apps trouvées: \(appUsages.count)")
        debugPrint("🥇 [ACTIVITY_REPORT] Top 3: \(top3Apps.map(\.name).joined(separator: ", "))")
        
        return ActivityReport(
            totalDuration: totalDuration,
            averageDaily: averageDaily,
            averageWeekly: averageWeekly,
            top3Apps: Array(top3Apps)
        )
    }
}
