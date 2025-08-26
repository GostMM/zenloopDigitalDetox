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
        // Strategy: Check cache freshness first
        let cached = loadCachedMetrics()
        let cacheAge = Date().timeIntervalSince(cached.updatedAt)
        
        // Return cache if fresh (<60s), otherwise calculate immediately
        if cacheAge < 60 {
            return cached
        }
        
        // Fast synchronous calculation - no background tasks
        return await calculateMetricsOptimized(data)
    }
    
    private func calculateMetricsOptimized(_ data: DeviceActivityResults<DeviceActivityData>) async -> MetricsData {
        let now = Date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let elapsedToday = now.timeIntervalSince(todayStart)
        
        var todayScreenTime: TimeInterval = 0
        
        // Pre-calculate today's day boundary to avoid repeated calculations
        guard let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart) else {
            return createDefaultMetrics()
        }
        
        // Fast iteration - only process today's segments
        for await datum in data {
            for await segment in datum.activitySegments {
                let segDur = segment.totalActivityDuration
                guard segDur > 0 else { continue }
                
                let segmentInterval = segment.dateInterval
                
                // Quick check: only process segments that overlap with today
                guard segmentInterval.end > todayStart && segmentInterval.start < tomorrowStart else { continue }
                
                // Calculate overlap with today efficiently
                let segStart = max(segmentInterval.start, todayStart)
                let segEnd = min(segmentInterval.end, tomorrowStart)
                let overlapDuration = segEnd.timeIntervalSince(segStart)
                
                if overlapDuration > 0 {
                    let proportion = overlapDuration / segmentInterval.duration
                    todayScreenTime += segDur * proportion
                }
            }
        }
        
        // Fast calculations
        let todayOffScreenTime = max(0, elapsedToday - todayScreenTime)
        let savedTime = UserDefaults.standard.double(forKey: "zenloop.savedSeconds")
        
        let metrics = MetricsData(
            todayScreenSeconds: todayScreenTime,
            todayOffScreenSeconds: todayOffScreenTime,
            savedSeconds: savedTime,
            updatedAt: now
        )
        
        // Single save operation
        saveMetricsToAppGroup(
            screenTime: todayScreenTime,
            offScreenTime: todayOffScreenTime,
            savedTime: savedTime,
            updatedAt: now
        )
        
        return metrics
    }
    
    private func loadCachedMetrics() -> MetricsData {
        guard let shared = UserDefaults(suiteName: "group.com.app.zenloop"),
              let cachedData = shared.dictionary(forKey: "TodayMetrics") else {
            return createDefaultMetrics()
        }
        
        let screenTime = cachedData["todayScreenSeconds"] as? Double ?? 0
        let offScreenTime = cachedData["todayOffScreenSeconds"] as? Double ?? 0
        let savedTime = cachedData["savedSeconds"] as? Double ?? 0
        let updatedAt = Date(timeIntervalSince1970: cachedData["updatedAt"] as? Double ?? 0)
        
        return MetricsData(
            todayScreenSeconds: screenTime,
            todayOffScreenSeconds: offScreenTime,
            savedSeconds: savedTime,
            updatedAt: updatedAt
        )
    }
    
    private func createDefaultMetrics() -> MetricsData {
        let now = Date()
        let savedTime = UserDefaults.standard.double(forKey: "zenloop.savedSeconds")
        
        return MetricsData(
            todayScreenSeconds: 0,
            todayOffScreenSeconds: 0,
            savedSeconds: savedTime,
            updatedAt: now
        )
    }
}

struct MetricsData {
    let todayScreenSeconds: TimeInterval
    let todayOffScreenSeconds: TimeInterval
    let savedSeconds: TimeInterval
    let updatedAt: Date
    
    // Structure pour StatsView
    var metricsForUI: [MetricUIData] {
        [
            MetricUIData(
                title: "Temps d'écran",
                value: todayScreenSeconds,
                icon: "iphone",
                color: .blue,
                subtitle: "aujourd'hui"
            ),
            MetricUIData(
                title: "Temps focus",
                value: todayOffScreenSeconds,
                icon: "leaf.fill",
                color: .green,
                subtitle: "hors écran"
            ),
            MetricUIData(
                title: "Temps économisé",
                value: savedSeconds,
                icon: "star.fill",
                color: .orange,
                subtitle: "par Zenloop"
            )
        ]
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
    
    @State private var selectedMetricIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isLoading = false
    
    // Cached computed property to avoid recalculation
    private var metrics: [MetricUIData] {
        metricsData.metricsForUI
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicateurs verticaux compacts optimisés
            VStack(spacing: 6) {
                ForEach(metrics.indices, id: \.self) { index in
                    IndicatorButton(
                        isSelected: index == selectedMetricIndex,
                        color: metrics[index].color,
                        onTap: {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedMetricIndex = index
                            }
                        }
                    )
                }
            }
            
            // Affichage compact de la métrique avec indicateur de chargement
            ZStack {
                if isLoading {
                    LoadingMetricCard()
                        .transition(.opacity)
                } else {
                    MetricDisplayCard(metric: metrics[selectedMetricIndex])
                        .transition(.asymmetric(
                            insertion: .move(edge: dragOffset > 0 ? .bottom : .top).combined(with: .opacity),
                            removal: .move(edge: dragOffset > 0 ? .top : .bottom).combined(with: .opacity)
                        ))
                        .id(selectedMetricIndex)
                }
            }
            .frame(minHeight: 90)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 25
                        
                        withAnimation(.spring(duration: 0.25)) {
                            if value.translation.height > threshold {
                                selectedMetricIndex = max(0, selectedMetricIndex - 1)
                            } else if value.translation.height < -threshold {
                                selectedMetricIndex = min(metrics.count - 1, selectedMetricIndex + 1)
                            }
                            dragOffset = 0
                        }
                    }
            )
            .scaleEffect(dragOffset == 0 ? 1.0 : 0.98)
            .animation(.spring(duration: 0.15), value: dragOffset)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                Text("Chargement...")
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
                
                Text("mise à jour...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - App Group Persistence
private func saveMetricsToAppGroup(
    screenTime: TimeInterval,
    offScreenTime: TimeInterval, 
    savedTime: TimeInterval,
    updatedAt: Date
) {
    let logger = Logger(subsystem: "com.app.zenloop.activity", category: "MetricsWidget")
    
    guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else {
        logger.error("❌ [METRICS] App Group indisponible")
        return
    }
    
    // Structure simple pour les métriques d'aujourd'hui
    let metricsData: [String: Any] = [
        "todayScreenSeconds": screenTime,
        "todayOffScreenSeconds": offScreenTime,
        "savedSeconds": savedTime,
        "updatedAt": updatedAt.timeIntervalSince1970
    ]
    
    shared.set(metricsData, forKey: "TodayMetrics")
    shared.synchronize()
    
    logger.info("💾 [METRICS] Données sauvegardées dans App Group")
}

// MARK: - Context Extension
extension DeviceActivityReport.Context {
    static let metrics = Self("Metrics")
}