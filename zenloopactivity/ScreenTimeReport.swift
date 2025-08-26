//
//  ScreenTimeReport.swift
//  zenloopactivity (Extension)
//
//  Vue spécialisée pour les métriques de temps d'écran
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Screen Time Report Scene
struct ScreenTimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("ScreenTimeMetrics")
    let content: (ScreenTimeData) -> ScreenTimeView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "ScreenTimeReport")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeData {
        var totalDuration: TimeInterval = 0
        var dailyBreakdown: [Date: TimeInterval] = [:]
        var hourlyBreakdown: [Int: TimeInterval] = [:] // 0-23 hours
        var weeklyAverage: TimeInterval = 0
        
        var globalStart: Date?
        var globalEnd: Date?
        
        let calendar = Calendar.current
        logger.info("🔍 [SCREEN-TIME] Processing screen time metrics...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                let segmentDuration = segment.totalActivityDuration
                guard segmentDuration > 0 else { continue }
                
                totalDuration += segmentDuration
                
                // Track global interval
                if globalStart == nil || segment.dateInterval.start < globalStart! {
                    globalStart = segment.dateInterval.start
                }
                if globalEnd == nil || segment.dateInterval.end > globalEnd! {
                    globalEnd = segment.dateInterval.end
                }
                
                // Daily breakdown
                let dayStart = calendar.startOfDay(for: segment.dateInterval.start)
                dailyBreakdown[dayStart, default: 0] += segmentDuration
                
                // Hourly breakdown (approximate)
                let hour = calendar.component(.hour, from: segment.dateInterval.start)
                hourlyBreakdown[hour, default: 0] += segmentDuration
            }
        }
        
        // Calculate weekly average
        let start = globalStart ?? Date()
        let end = globalEnd ?? start
        let dayCount = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
        let dailyAverage = totalDuration / Double(max(1, dayCount))
        weeklyAverage = dailyAverage * 7
        
        // Sort daily breakdown
        let sortedDailyData = dailyBreakdown
            .sorted { $0.key < $1.key }
            .map { DailyUsage(date: $0.key, duration: $0.value) }
        
        // Convert hourly breakdown
        let hourlyData = (0..<24).map { hour in
            HourlyUsage(hour: hour, duration: hourlyBreakdown[hour] ?? 0)
        }
        
        let screenTimeData = ScreenTimeData(
            totalDuration: totalDuration,
            dailyAverage: dailyAverage,
            weeklyAverage: weeklyAverage,
            dailyBreakdown: sortedDailyData,
            hourlyBreakdown: hourlyData,
            periodStart: start,
            periodEnd: end
        )
        
        logger.info("✅ [SCREEN-TIME] Total: \(totalDuration)s, Daily avg: \(dailyAverage)s, Days: \(dayCount)")
        
        return screenTimeData
    }
}

// MARK: - Data Models
struct ScreenTimeData {
    let totalDuration: TimeInterval
    let dailyAverage: TimeInterval
    let weeklyAverage: TimeInterval
    let dailyBreakdown: [DailyUsage]
    let hourlyBreakdown: [HourlyUsage]
    let periodStart: Date
    let periodEnd: Date
}

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
}

struct HourlyUsage: Identifiable {
    let id = UUID()
    let hour: Int
    let duration: TimeInterval
    
    var formattedHour: String {
        String(format: "%02d:00", hour)
    }
}

// MARK: - Screen Time View
struct ScreenTimeView: View {
    let screenTimeData: ScreenTimeData
    
    @State private var selectedMetric: MetricType = .daily
    
    enum MetricType: String, CaseIterable, Identifiable {
        case daily = "daily"
        case hourly = "hourly"
        case trends = "trends"
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            String(localized: String.LocalizationValue(rawValue))
        }
        
        var icon: String {
            switch self {
            case .daily: return "calendar"
            case .hourly: return "clock"
            case .trends: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with key metrics
            headerSection
            
            // Metric selector
            metricSelector
            
            // Content based on selected metric
            Group {
                switch selectedMetric {
                case .daily: dailyContent
                case .hourly: hourlyContent
                case .trends: trendsContent
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedMetric)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Key metrics cards
            HStack(spacing: 10) {
                MetricCard(
                    title: String(localized: "total"),
                    value: formatTime(screenTimeData.totalDuration),
                    icon: "clock.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: String(localized: "daily_avg"),
                    value: formatTime(screenTimeData.dailyAverage),
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                MetricCard(
                    title: String(localized: "period"),
                    value: formatPeriod(),
                    icon: "calendar.badge.clock",
                    color: .orange
                )
            }
            
            // Trend indicator
            if screenTimeData.dailyBreakdown.count >= 2 {
                trendIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.white.opacity(0.05))
    }
    
    private var trendIndicator: some View {
        let recent = screenTimeData.dailyBreakdown.suffix(3)
        let older = screenTimeData.dailyBreakdown.prefix(screenTimeData.dailyBreakdown.count - 3).suffix(3)
        
        let recentAvg = recent.isEmpty ? 0 : recent.reduce(0) { $0 + $1.duration } / Double(recent.count)
        let olderAvg = older.isEmpty ? recentAvg : older.reduce(0) { $0 + $1.duration } / Double(older.count)
        
        let trend = recentAvg - olderAvg
        let isIncreasing = trend > 0
        let changePercent = olderAvg > 0 ? abs(trend / olderAvg) * 100 : 0
        
        return HStack(spacing: 8) {
            Image(systemName: isIncreasing ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isIncreasing ? .red : .green)
            
            Text(String(localized: isIncreasing ? "usage_increasing" : "usage_decreasing"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            if changePercent > 1 {
                Text("\(Int(changePercent))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isIncreasing ? .red : .green)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Metric Selector
    private var metricSelector: some View {
        HStack(spacing: 4) {
            ForEach(MetricType.allCases) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(metric.localizedTitle)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectedMetric == metric ? .black : .white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedMetric == metric ? .white : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Daily Content
    private var dailyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(screenTimeData.dailyBreakdown.reversed()) { dailyUsage in
                    DailyUsageRow(dailyUsage: dailyUsage, averageDuration: screenTimeData.dailyAverage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Hourly Content
    private var hourlyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Peak hours summary
                let peakHours = screenTimeData.hourlyBreakdown.sorted { $0.duration > $1.duration }.prefix(3)
                if !peakHours.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "peak_hours"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(Array(peakHours), id: \.id) { hourlyUsage in
                                VStack(spacing: 4) {
                                    Text(hourlyUsage.formattedHour)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(formatTime(hourlyUsage.duration))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Hourly breakdown
                LazyVStack(spacing: 4) {
                    ForEach(screenTimeData.hourlyBreakdown) { hourlyUsage in
                        HourlyUsageRow(hourlyUsage: hourlyUsage, maxDuration: screenTimeData.hourlyBreakdown.map(\.duration).max() ?? 1)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Trends Content
    private var trendsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Weekly comparison
                if screenTimeData.dailyBreakdown.count >= 7 {
                    weeklyComparisonCard
                }
                
                // Best/worst days
                bestWorstDaysCard
                
                // Usage patterns
                usagePatternsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private var weeklyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "weekly_comparison"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // Simple week-by-week comparison
            let weeks = groupDailyDataByWeek()
            if weeks.count >= 2 {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    HStack {
                        Text(String(localized: "week") + " \(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(formatTime(week.totalDuration))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("(\(formatTime(week.dailyAverage))/day)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var bestWorstDaysCard: some View {
        let sortedDays = screenTimeData.dailyBreakdown.sorted { $0.duration < $1.duration }
        let bestDay = sortedDays.first
        let worstDay = sortedDays.last
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "best_worst_days"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            if let best = bestDay {
                DayComparisonRow(
                    title: String(localized: "best_day"),
                    date: best.date,
                    duration: best.duration,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
            }
            
            if let worst = worstDay {
                DayComparisonRow(
                    title: String(localized: "challenging_day"),
                    date: worst.date,
                    duration: worst.duration,
                    color: .orange,
                    icon: "exclamationmark.circle.fill"
                )
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var usagePatternsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "usage_patterns"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // Weekday vs weekend
            let weekdayAvg = calculateWeekdayAverage()
            let weekendAvg = calculateWeekendAverage()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "weekdays"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    Text(formatTime(weekdayAvg))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "weekends"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    Text(formatTime(weekendAvg))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: max(0, duration)) ?? "0m"
    }
    
    private func formatPeriod() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: screenTimeData.periodStart)
        let end = formatter.string(from: screenTimeData.periodEnd)
        return start == end ? start : "\(start) - \(end)"
    }
    
    private func groupDailyDataByWeek() -> [WeeklyData] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: screenTimeData.dailyBreakdown) { usage in
            calendar.component(.weekOfYear, from: usage.date)
        }
        
        return grouped.values.map { weekData in
            let total = weekData.reduce(0) { $0 + $1.duration }
            let average = total / Double(weekData.count)
            return WeeklyData(totalDuration: total, dailyAverage: average)
        }
    }
    
    private func calculateWeekdayAverage() -> TimeInterval {
        let calendar = Calendar.current
        let weekdays = screenTimeData.dailyBreakdown.filter { usage in
            let weekday = calendar.component(.weekday, from: usage.date)
            return weekday >= 2 && weekday <= 6 // Monday to Friday
        }
        guard !weekdays.isEmpty else { return 0 }
        return weekdays.reduce(0) { $0 + $1.duration } / Double(weekdays.count)
    }
    
    private func calculateWeekendAverage() -> TimeInterval {
        let calendar = Calendar.current
        let weekends = screenTimeData.dailyBreakdown.filter { usage in
            let weekday = calendar.component(.weekday, from: usage.date)
            return weekday == 1 || weekday == 7 // Saturday and Sunday
        }
        guard !weekends.isEmpty else { return 0 }
        return weekends.reduce(0) { $0 + $1.duration } / Double(weekends.count)
    }
}

// MARK: - Supporting Views
private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DailyUsageRow: View {
    let dailyUsage: DailyUsage
    let averageDuration: TimeInterval
    
    var body: some View {
        HStack(spacing: 12) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(dateString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 80, alignment: .leading)
            
            // Duration
            Text(formatTime(dailyUsage.duration))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Comparison to average
            comparisonToAverage
            
            // Usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    
                    Rectangle()
                        .fill(usageColor)
                        .frame(width: max(2, geometry.size.width * min(1, averageDuration > 0 ? dailyUsage.duration / (averageDuration * 2) : 0)), height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: dailyUsage.date)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: dailyUsage.date)
    }
    
    private var comparisonToAverage: some View {
        let difference = dailyUsage.duration - averageDuration
        let isAboveAverage = difference > 0
        
        return HStack(spacing: 4) {
            Image(systemName: isAboveAverage ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isAboveAverage ? .red : .green)
            
            if abs(difference) > 60 { // More than 1 minute difference
                Text(formatTime(abs(difference)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 50, alignment: .trailing)
    }
    
    private var usageColor: Color {
        let ratio = averageDuration > 0 ? dailyUsage.duration / averageDuration : 0
        switch ratio {
        case 1.5...: return .red
        case 1.2..<1.5: return .orange
        case 0.8..<1.2: return .blue
        default: return .green
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct HourlyUsageRow: View {
    let hourlyUsage: HourlyUsage
    let maxDuration: TimeInterval
    
    var body: some View {
        HStack(spacing: 12) {
            Text(hourlyUsage.formattedHour)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    Rectangle()
                        .fill(hourColor)
                        .frame(width: max(1, geometry.size.width * (maxDuration > 0 ? hourlyUsage.duration / maxDuration : 0)), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
            
            Text(formatTime(hourlyUsage.duration))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private var hourColor: Color {
        switch hourlyUsage.hour {
        case 6..<12: return .yellow    // Morning
        case 12..<18: return .orange   // Afternoon
        case 18..<22: return .red      // Evening
        case 22..<24, 0..<6: return .purple // Night
        default: return .blue
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct DayComparisonRow: View {
    let title: String
    let date: Date
    let duration: TimeInterval
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(formatDate())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text(formatTime(duration))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - Supporting Data Models
private struct WeeklyData {
    let totalDuration: TimeInterval
    let dailyAverage: TimeInterval
}

// MARK: - Extension for Context
extension DeviceActivityReport.Context {
    static let screenTimeMetrics = Self("ScreenTimeMetrics")
}