//
//  TimeWidgets.swift
//  zenloopactivity (Extension)
//
//  Widgets modulaires pour les métriques de temps d'écran
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Daily Usage Widget
struct DailyUsageWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("DailyUsage")
    let content: (DailyUsageData) -> DailyUsageView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "DailyUsageWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DailyUsageData {
        var totalDuration: TimeInterval = 0
        var dailyBreakdown: [Date: TimeInterval] = [:]
        
        let calendar = Calendar.current
        logger.info("🔍 [DAILY-USAGE] Processing daily usage data...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                let segmentDuration = segment.totalActivityDuration
                guard segmentDuration > 0 else { continue }
                
                totalDuration += segmentDuration
                
                let dayStart = calendar.startOfDay(for: segment.dateInterval.start)
                dailyBreakdown[dayStart, default: 0] += segmentDuration
            }
        }
        
        let days = dailyBreakdown
            .sorted { $0.key < $1.key }
            .map { DayUsage(date: $0.key, duration: $0.value) }
        
        let dailyAverage = days.isEmpty ? 0 : totalDuration / Double(days.count)
        
        logger.info("✅ [DAILY-USAGE] \(days.count) days, avg: \(dailyAverage)s")
        
        return DailyUsageData(
            totalDuration: totalDuration,
            dailyAverage: dailyAverage,
            days: days
        )
    }
}

struct DailyUsageData {
    let totalDuration: TimeInterval
    let dailyAverage: TimeInterval
    let days: [DayUsage]
}

struct DayUsage: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
}

struct DailyUsageView: View {
    let dailyUsageData: DailyUsageData
    
    var body: some View {
        VStack(spacing: 12) {
            // Métriques principales
            HStack(spacing: 12) {
                MetricBox(
                    title: String(localized: "total"),
                    value: formatTime(dailyUsageData.totalDuration),
                    color: .blue
                )
                
                MetricBox(
                    title: String(localized: "daily_average"),
                    value: formatTime(dailyUsageData.dailyAverage),
                    color: .green
                )
                
                MetricBox(
                    title: String(localized: "days"),
                    value: "\(dailyUsageData.days.count)",
                    color: .orange
                )
            }
            
            // Graphique des derniers jours (max 7)
            if !dailyUsageData.days.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "recent_days"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(dailyUsageData.days.suffix(7)) { day in
                                DayBar(
                                    dayUsage: day,
                                    maxDuration: dailyUsageData.days.map(\.duration).max() ?? 1
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, 8)
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

private struct MetricBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct DayBar: View {
    let dayUsage: DayUsage
    let maxDuration: TimeInterval
    
    private var heightRatio: CGFloat {
        maxDuration > 0 ? CGFloat(dayUsage.duration / maxDuration) : 0
    }
    
    var body: some View {
        VStack(spacing: 3) {
            // Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 16, height: max(4, 40 * heightRatio))
            
            // Day label
            Text(dayLabel)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: dayUsage.date).prefix(1))
    }
    
    private var barColor: Color {
        let hours = dayUsage.duration / 3600
        switch hours {
        case 4...: return .red
        case 2..<4: return .orange
        case 1..<2: return .yellow
        default: return .green
        }
    }
}

// MARK: - Time Comparison Widget
struct TimeComparisonWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TimeComparison")
    let content: (TimeComparisonData) -> TimeComparisonView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TimeComparisonWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TimeComparisonData {
        var weekdayTotal: TimeInterval = 0
        var weekendTotal: TimeInterval = 0
        var weekdayCount = 0
        var weekendCount = 0
        
        let calendar = Calendar.current
        logger.info("🔍 [TIME-COMPARISON] Processing time comparison data...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                let duration = segment.totalActivityDuration
                guard duration > 0 else { continue }
                
                let weekday = calendar.component(.weekday, from: segment.dateInterval.start)
                
                if weekday == 1 || weekday == 7 { // Weekend (Sunday = 1, Saturday = 7)
                    weekendTotal += duration
                    weekendCount += 1
                } else { // Weekday
                    weekdayTotal += duration
                    weekdayCount += 1
                }
            }
        }
        
        let weekdayAverage = weekdayCount > 0 ? weekdayTotal / Double(weekdayCount) : 0
        let weekendAverage = weekendCount > 0 ? weekendTotal / Double(weekendCount) : 0
        
        logger.info("✅ [TIME-COMPARISON] Weekday avg: \(weekdayAverage)s, Weekend avg: \(weekendAverage)s")
        
        return TimeComparisonData(
            weekdayAverage: weekdayAverage,
            weekendAverage: weekendAverage
        )
    }
}

struct TimeComparisonData {
    let weekdayAverage: TimeInterval
    let weekendAverage: TimeInterval
}

struct TimeComparisonView: View {
    let timeComparisonData: TimeComparisonData
    
    private var difference: TimeInterval {
        timeComparisonData.weekendAverage - timeComparisonData.weekdayAverage
    }
    
    private var isWeekendHigher: Bool {
        difference > 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Titre
            Text(String(localized: "weekday_vs_weekend"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            // Comparaison visuelle
            HStack(spacing: 16) {
                // Semaine
                ComparisonItem(
                    title: String(localized: "weekdays"),
                    time: formatTime(timeComparisonData.weekdayAverage),
                    color: .blue,
                    isHigher: !isWeekendHigher && difference != 0
                )
                
                // Indicateur de différence
                VStack(spacing: 2) {
                    Image(systemName: difference > 0 ? "arrow.right" : difference < 0 ? "arrow.left" : "equal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if abs(difference) > 60 {
                        Text(formatTime(abs(difference)))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(minWidth: 30)
                
                // Weekend
                ComparisonItem(
                    title: String(localized: "weekend"),
                    time: formatTime(timeComparisonData.weekendAverage),
                    color: .orange,
                    isHigher: isWeekendHigher && difference != 0
                )
            }
            
            // Message contextuel
            if abs(difference) > 1800 { // Plus de 30 minutes de différence
                Text(isWeekendHigher ? String(localized: "more_active_weekend") : String(localized: "more_active_weekday"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isWeekendHigher ? .orange : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isWeekendHigher ? Color.orange : Color.blue).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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

private struct ComparisonItem: View {
    let title: String
    let time: String
    let color: Color
    let isHigher: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                if isHigher {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            Text(time)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(isHigher ? 0.3 : 0.1), lineWidth: isHigher ? 1 : 0.5)
        )
    }
}

// MARK: - Context Extensions
extension DeviceActivityReport.Context {
    static let dailyUsage = Self("DailyUsage")
    static let timeComparison = Self("TimeComparison")
}