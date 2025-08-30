//
//  AppWidgets.swift
//  zenloopactivity (Extension)
//
//  Composants modulaires réutilisables pour les applications
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log

// MARK: - Top Apps Widget
struct TopAppsWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TopApps")
    let content: (TopAppsData) -> TopAppsView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TopAppsWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TopAppsData {
        var apps: [AppItem] = []
        var totalDuration: TimeInterval = 0
        
        logger.info("🔍 [TOP-APPS] Processing top apps data...")
        
        var segmentCount = 0
        for await datum in data {
            logger.info("📊 [TOP-APPS] Processing datum...")
            for await segment in datum.activitySegments {
                segmentCount += 1
                totalDuration += segment.totalActivityDuration
                logger.info("📈 [TOP-APPS] Segment \(segmentCount): \(segment.totalActivityDuration)s")
                
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let duration = appActivity.totalActivityDuration
                        guard duration > 0 else { continue }
                        
                        let name = appActivity.application.localizedDisplayName?.isEmpty == false 
                            ? appActivity.application.localizedDisplayName!
                            : (appActivity.application.bundleIdentifier?.isEmpty == false 
                               ? appActivity.application.bundleIdentifier! 
                               : "Application")
                            
                        if let token = appActivity.application.token {
                            // Vérifier que le token est valide avant de l'utiliser
                            let bundleID = appActivity.application.bundleIdentifier ?? "unknown"
                            logger.info("📱 [TOP-APPS] Processing app: \(name) - Bundle: \(bundleID)")
                            
                            if let existingIndex = apps.firstIndex(where: { $0.token == token }) {
                                apps[existingIndex].duration += duration
                            } else {
                                apps.append(AppItem(
                                    name: name,
                                    duration: duration,
                                    token: token
                                ))
                            }
                        } else {
                            logger.warning("⚠️ [TOP-APPS] No token for app: \(name)")
                        }
                    }
                }
            }
        }
        
        // Garde seulement le top 5
        apps.sort { $0.duration > $1.duration }
        let topApps = Array(apps.prefix(5))
        
        logger.info("✅ [TOP-APPS] Found \(topApps.count) top apps from \(segmentCount) segments, total: \(totalDuration)s")
        
        return TopAppsData(apps: topApps, totalDuration: totalDuration)
    }
}

struct TopAppsData {
    let apps: [AppItem]
    let totalDuration: TimeInterval
}

struct AppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var duration: TimeInterval
    let token: ApplicationToken
}

struct TopAppsView: View {
    let topAppsData: TopAppsData
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(topAppsData.apps.enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 10) {
                    // Rang
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(rankColor(index + 1))
                        .frame(width: 16)
                    
                    // Icône app avec validation du token
                    if isValidToken(app.token) {
                        Label(app.token)
                            .labelStyle(.iconOnly)
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue.opacity(0.8))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .background(.blue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    
                    // Nom et durée
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(formatTime(app.duration))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Pourcentage
                    Text("\(percentage(app.duration))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .white.opacity(0.6)
        }
    }
    
    private func percentage(_ duration: TimeInterval) -> Int {
        guard topAppsData.totalDuration > 0 else { return 0 }
        return Int(round((duration / topAppsData.totalDuration) * 100))
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - App Usage Summary Widget
struct AppSummaryWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("AppSummary")
    let content: (AppSummaryData) -> AppSummaryView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "AppSummaryWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> AppSummaryData {
        var appCount = 0
        var totalDuration: TimeInterval = 0
        var mostUsedApp: AppItem?
        var maxDuration: TimeInterval = 0
        
        logger.info("🔍 [APP-SUMMARY] Processing app summary data...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let duration = appActivity.totalActivityDuration
                        guard duration > 0 else { continue }
                        
                        appCount += 1
                        
                        if duration > maxDuration {
                            maxDuration = duration
                            let name = appActivity.application.localizedDisplayName?.isEmpty == false 
                                ? appActivity.application.localizedDisplayName!
                                : (appActivity.application.bundleIdentifier?.isEmpty == false 
                                   ? appActivity.application.bundleIdentifier! 
                                   : "Application")
                                
                            if let token = appActivity.application.token {
                                mostUsedApp = AppItem(name: name, duration: duration, token: token)
                            }
                        }
                    }
                }
            }
        }
        
        let averageTime = appCount > 0 ? totalDuration / Double(appCount) : 0
        
        logger.info("✅ [APP-SUMMARY] \(appCount) apps, most used: \(mostUsedApp?.name ?? "none")")
        
        return AppSummaryData(
            appCount: appCount,
            totalDuration: totalDuration,
            averageTime: averageTime,
            mostUsedApp: mostUsedApp
        )
    }
}

struct AppSummaryData {
    let appCount: Int
    let totalDuration: TimeInterval
    let averageTime: TimeInterval
    let mostUsedApp: AppItem?
}

struct AppSummaryView: View {
    let appSummaryData: AppSummaryData
    
    var body: some View {
        VStack(spacing: 12) {
            // Statistiques principales
            HStack(spacing: 16) {
                StatItem(
                    title: "Apps",
                    value: "\(appSummaryData.appCount)",
                    color: .blue
                )
                
                StatItem(
                    title: "Total",
                    value: formatTime(appSummaryData.totalDuration),
                    color: .purple
                )
                
                StatItem(
                    title: "Moyenne",
                    value: formatTime(appSummaryData.averageTime),
                    color: .green
                )
            }
            
            // App la plus utilisée
            if let mostUsed = appSummaryData.mostUsedApp {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if isValidToken(mostUsed.token) {
                        Label(mostUsed.token)
                            .labelStyle(.iconOnly)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 20, height: 20)
                            .background(.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("App favorite")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(mostUsed.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(formatTime(mostUsed.duration))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Helper Functions
private func isValidToken(_ token: ApplicationToken) -> Bool {
    // Toujours afficher les vraies icônes d'applications
    return true
}

// MARK: - Context Extensions
extension DeviceActivityReport.Context {
    static let appSummary = Self("AppSummary")
}