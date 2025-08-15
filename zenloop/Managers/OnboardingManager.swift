//
//  OnboardingManager.swift
//  zenloop
//
//  Created by Claude on 14/08/2025.
//

import Foundation
import SwiftUI
import UserNotifications
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import os.log

// MARK: - Daily Activity Data

struct DailyActivityData: Codable {
    let totalSeconds: Double
    let averageDailySeconds: Double
    let topCategories: [ActivityCategoryData]
    let days: [DayActivityPoint]
    let updatedAt: TimeInterval
    
    var totalHours: Double { totalSeconds / 3600 }
    var averageDailyHours: Double { averageDailySeconds / 3600 }
    
    var formattedTotalTime: String {
        let hours = Int(totalHours)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    var formattedDailyAverage: String {
        let hours = Int(averageDailyHours)
        let minutes = Int((averageDailySeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

struct ActivityCategoryData: Codable {
    let name: String
    let seconds: Double
    let appCount: Int
}

struct DayActivityPoint: Codable {
    let dayStart: TimeInterval
    let seconds: Double
    
    var date: Date { Date(timeIntervalSince1970: dayStart) }
    var hours: Double { seconds / 3600 }
}

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
    case restricted
    
    var isGranted: Bool {
        return self == .granted
    }
}

// MARK: - Onboarding Manager

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var screenTimeStatus: PermissionStatus = .notDetermined
    @Published var notificationStatus: PermissionStatus = .notDetermined
    @Published var dailyActivityData: DailyActivityData?
    @Published var showPermissionExplanation = false
    
    private let logger = Logger(subsystem: "com.app.zenloop", category: "OnboardingManager")
    private let appGroupSuite = AppGroupConfig.suiteName
    
    private init() {
        loadDailyActivityData()
        checkPermissionStatuses()
    }
    
    // MARK: - Data Loading
    
    func loadDailyActivityData() {
        guard let shared = UserDefaults(suiteName: appGroupSuite) else {
            logger.warning("⚠️ [ONBOARDING] App Group unavailable")
            return
        }
        
        // Essayer d'abord le nouveau format JSON
        if let data = shared.data(forKey: AppGroupConfig.Keys.deviceActivityReport) {
            do {
                let payload = try JSONDecoder().decode(SharedReportPayload.self, from: data)
                
                dailyActivityData = DailyActivityData(
                    totalSeconds: payload.totalSeconds,
                    averageDailySeconds: payload.averageDailySeconds,
                    topCategories: payload.topCategories.map { 
                        ActivityCategoryData(name: $0.name, seconds: $0.seconds, appCount: $0.appCount) 
                    },
                    days: payload.days.map { 
                        DayActivityPoint(dayStart: $0.dayStart, seconds: $0.seconds) 
                    },
                    updatedAt: payload.updatedAt
                )
                
                logger.info("✅ [ONBOARDING] Activity data loaded: \(payload.totalSeconds)s total")
                return
            } catch {
                logger.error("❌ [ONBOARDING] Failed to decode activity data: \(error)")
            }
        }
        
        // Fallback vers le format legacy
        if let legacyData = shared.dictionary(forKey: AppGroupConfig.Keys.deviceActivityReportLegacy) {
            let totalDuration = legacyData["totalDuration"] as? TimeInterval ?? 0
            let averageDaily = legacyData["averageDaily"] as? TimeInterval ?? 0
            let lastUpdated = legacyData["lastUpdated"] as? TimeInterval ?? 0
            
            if totalDuration > 0 {
                dailyActivityData = DailyActivityData(
                    totalSeconds: totalDuration,
                    averageDailySeconds: averageDaily,
                    topCategories: [],
                    days: [],
                    updatedAt: lastUpdated
                )
                
                logger.info("📊 [ONBOARDING] Legacy activity data loaded: \(totalDuration)s total")
            }
        }
    }
    
    // MARK: - Permission Checking
    
    func checkPermissionStatuses() {
        checkScreenTimeStatus()
        checkNotificationStatus()
    }
    
    private func checkScreenTimeStatus() {
        #if canImport(FamilyControls)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            screenTimeStatus = .notDetermined
        case .denied:
            screenTimeStatus = .denied
        case .approved:
            screenTimeStatus = .granted
        @unknown default:
            screenTimeStatus = .notDetermined
        }
        #else
        screenTimeStatus = .notDetermined
        #endif
    }
    
    private func checkNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                switch settings.authorizationStatus {
                case .notDetermined:
                    notificationStatus = .notDetermined
                case .denied:
                    notificationStatus = .denied
                case .authorized, .provisional, .ephemeral:
                    notificationStatus = .granted
                @unknown default:
                    notificationStatus = .notDetermined
                }
            }
        }
    }
    
    // MARK: - Permission Requests
    
    func requestScreenTimePermission() async -> Bool {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                checkScreenTimeStatus()
            }
            logger.info("✅ [ONBOARDING] Screen Time permission granted")
            return screenTimeStatus.isGranted
        } catch {
            logger.error("❌ [ONBOARDING] Screen Time permission failed: \(error)")
            await MainActor.run {
                screenTimeStatus = .denied
            }
            return false
        }
        #else
        await MainActor.run {
            screenTimeStatus = .denied
        }
        logger.warning("⚠️ [ONBOARDING] FamilyControls not available on this platform")
        return false
        #endif
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            await MainActor.run {
                notificationStatus = granted ? .granted : .denied
            }
            
            logger.info("✅ [ONBOARDING] Notification permission: \(granted)")
            return granted
        } catch {
            logger.error("❌ [ONBOARDING] Notification permission failed: \(error)")
            await MainActor.run {
                notificationStatus = .denied
            }
            return false
        }
    }
    
    // MARK: - Insights Generation
    
    func generateInsightMessage() -> String {
        guard let data = dailyActivityData, data.totalSeconds > 0 else {
            return String(localized: "unlock_insights_with_screen_time")
        }
        
        if data.averageDailyHours >= 6 {
            return String(localized: "high_usage_insight", defaultValue: "You spend an average of \(data.formattedDailyAverage) daily on your phone. Let's optimize that time together!", table: nil, bundle: .main, comment: "")
        } else if data.averageDailyHours >= 3 {
            return String(localized: "moderate_usage_insight", defaultValue: "With \(data.formattedDailyAverage) daily screen time, you're on track! Let's help you stay focused on what matters.", table: nil, bundle: .main, comment: "")
        } else {
            return String(localized: "low_usage_insight", defaultValue: "Great job! Your \(data.formattedDailyAverage) daily usage shows healthy digital habits. Let's maintain that balance.", table: nil, bundle: .main, comment: "")
        }
    }
    
    func getTopCategoryName() -> String {
        guard let data = dailyActivityData,
              let topCategory = data.topCategories.first else {
            return "apps"
        }
        
        return topCategory.name
    }
    
    func getDailyTrendEmoji() -> String {
        guard let data = dailyActivityData, data.days.count >= 2 else {
            return "📊"
        }
        
        let recent = data.days.suffix(3).map(\.hours)
        let earlier = data.days.prefix(data.days.count - 3).map(\.hours)
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.reduce(0, +) / Double(earlier.count)
        
        if recentAvg < earlierAvg * 0.8 {
            return "📉" // Trending down - good
        } else if recentAvg > earlierAvg * 1.2 {
            return "📈" // Trending up - attention
        } else {
            return "➡️" // Stable
        }
    }
    
    // MARK: - Public API for App Integration
    
    /// Obtient le temps d'écran total aujourd'hui en secondes
    func getTodayScreenTime() -> TimeInterval {
        guard let data = dailyActivityData else { return 0 }
        
        let today = Calendar.current.startOfDay(for: Date())
        return data.days.first { Calendar.current.isDate($0.date, inSameDayAs: today) }?.seconds ?? 0
    }
    
    /// Obtient la moyenne hebdomadaire en heures formatées
    func getWeeklyAverage() -> String {
        guard let data = dailyActivityData, !data.days.isEmpty else {
            return "0min"
        }
        
        let lastWeekDays = data.days.suffix(7)
        let weeklyTotal = lastWeekDays.reduce(0) { $0 + $1.seconds }
        let weeklyAverage = weeklyTotal / Double(lastWeekDays.count)
        
        let hours = Int(weeklyAverage / 3600)
        let minutes = Int((weeklyAverage.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    /// Vérifie si l'utilisateur a une utilisation élevée (>6h/jour)
    var hasHighUsage: Bool {
        guard let data = dailyActivityData else { return false }
        return data.averageDailyHours >= 6
    }
    
    /// Obtient un message d'encouragement basé sur l'utilisation
    func getEncouragementMessage() -> String {
        guard let data = dailyActivityData else {
            return String(localized: "start_your_digital_wellness_journey")
        }
        
        let todayUsage = getTodayScreenTime() / 3600 // en heures
        let average = data.averageDailyHours
        
        if todayUsage < average * 0.8 {
            return String(localized: "great_progress_today")
        } else if todayUsage > average * 1.2 {
            return String(localized: "time_for_focus_break")
        } else {
            return String(localized: "stay_mindful_of_usage")
        }
    }
}

// MARK: - Additional Localizations Needed
// These keys should be added to Localizable.strings files:
// "start_your_digital_wellness_journey" = "Commencez votre parcours de bien-être numérique"
// "great_progress_today" = "Excellent progrès aujourd'hui ! Continuez comme ça"
// "time_for_focus_break" = "Il est temps de faire une pause focus et de vous reconnecter"
// "stay_mindful_of_usage" = "Restez conscient de votre utilisation, vous êtes sur la bonne voie"