//
//  MetricsWidget.swift
//  zenloopactivity (Extension)
//
//  Widget pour les métriques principales : temps d'écran, focus, économisé
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Metrics Widget
struct MetricsWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("Metrics")
    let content: (MetricsData) -> MetricsView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "MetricsWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> MetricsData {
        // Always read from SharedReportPayload created by TotalActivityReport
        // This ensures consistency and avoids duplicate calculation
        return loadSharedMetrics()
    }
    
    
    private func formatMetricTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
    
    private func loadSharedMetrics() -> MetricsData {
        guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.error("❌ [METRICS] App Group indisponible")
            return createDefaultMetrics()
        }
        
        // Try to decode SharedReportPayload JSON data
        if let data = shared.data(forKey: "DAReportLatest") {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let todayScreenSeconds = json["todayScreenSeconds"] as? Double ?? 0
                    let updatedAt = json["updatedAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    
                    logger.info("✅ [METRICS] Loaded from JSON: todayScreenSeconds=\(todayScreenSeconds)s")
                    return MetricsData(
                        todayScreenSeconds: todayScreenSeconds,
                        updatedAt: Date(timeIntervalSince1970: updatedAt)
                    )
                }
            } catch {
                logger.error("❌ [METRICS] Failed to decode JSON: \(error.localizedDescription)")
            }
        } else {
            logger.error("❌ [METRICS] No data found for key 'DAReportLatest' in App Group")
            
            // Also check legacy key as fallback
            if let legacyDict = shared.dictionary(forKey: "DeviceActivityData") {
                logger.info("🔄 [METRICS] Trying legacy key...")
                // Legacy doesn't have todayScreenSeconds, use totalDuration as fallback
                let totalDuration = legacyDict["totalDuration"] as? TimeInterval ?? 0
                let lastUpdated = legacyDict["lastUpdated"] as? TimeInterval ?? Date().timeIntervalSince1970
                
                return MetricsData(
                    todayScreenSeconds: totalDuration,
                    updatedAt: Date(timeIntervalSince1970: lastUpdated)
                )
            }
        }
        
        logger.info("🔄 [METRICS] Using default metrics (0m)")
        return createDefaultMetrics()
    }
    
    private func createDefaultMetrics() -> MetricsData {
        let now = Date()
        
        return MetricsData(
            todayScreenSeconds: 0,
            updatedAt: now
        )
    }
}

struct MetricsData {
    let todayScreenSeconds: TimeInterval
    let updatedAt: Date
    
    // Métrique unique simplifiée pour StatsView
    var screenTimeMetric: MetricUIData {
        MetricUIData(
            title: String(localized: "screen_time"),
            value: todayScreenSeconds,
            icon: "iphone",
            color: .blue,
            subtitle: String(localized: "today")
        )
    }
}

struct MetricUIData: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: TimeInterval
    let icon: String
    let color: Color
    let subtitle: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MetricUIData, rhs: MetricUIData) -> Bool {
        lhs.id == rhs.id
    }
}

struct MetricsView: View {
    let metricsData: MetricsData
    
    @State private var isLoading = false
    
    // Single metric - no array needed
    private var metric: MetricUIData {
        metricsData.screenTimeMetric
    }
    
    var body: some View {
        // Affichage simple d'une seule métrique - temps d'écran réel
        ZStack {
            if isLoading {
                LoadingMetricCard()
                    .transition(.opacity)
            } else {
                MetricDisplayCard(metric: metric)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 90)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.gray.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            checkForDataUpdates()
        }
    }
    
    private func checkForDataUpdates() {
        // Simplified check - avoid UserDefaults access on every appear
        let timeSinceUpdate = Date().timeIntervalSince(metricsData.updatedAt)
        
        if timeSinceUpdate > 60 {
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isLoading = false
            }
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - Metric Display Card
private struct MetricDisplayCard: View {
    let metric: MetricUIData
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône compacte
            Image(systemName: metric.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(metric.color)
                .frame(width: 36, height: 36)
            
            // Contenu principal compact
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Valeur avec vraies données - plus compacte
                Text(formatMetricTime(metric.value))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(metric.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatMetricTime(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

// MARK: - Optimized Indicator Button
private struct IndicatorButton: View {
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? color : color.opacity(0.3))
                .frame(width: 4, height: isSelected ? 20 : 10)
        }
        .animation(.spring(duration: 0.15), value: isSelected)
    }
}

// MARK: - Loading Card
private struct LoadingMetricCard: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône de chargement
            Image(systemName: "clock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "loading"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("---")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(opacity))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            opacity = 0.8
                        }
                    }
                
                Text(String(localized: "updating"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



// MARK: - Context Extension
extension DeviceActivityReport.Context {
    static let metrics = Self("Metrics")
}

