//
//  DailyReportManager.swift
//  zenloop
//
//  Gestionnaire des rapports quotidiens - 3x par jour (matin, midi, soir)
//

import Foundation
import SwiftUI
import os.log

@MainActor
final class DailyReportManager: ObservableObject {
    static let shared = DailyReportManager()
    
    @Published var shouldShowReport = false
    @Published var currentTimeOfDay: TimeOfDay = .morning
    
    private let logger = Logger(subsystem: "com.app.zenloop", category: "DailyReportManager")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Time of Day Definition
    
    enum TimeOfDay: String, CaseIterable {
        case morning = "morning"     // 7h - 11h59
        case afternoon = "afternoon" // 12h - 17h59  
        case evening = "evening"     // 18h - 22h
        
        var greeting: String {
            switch self {
            case .morning:
                return String(localized: "good_morning")
            case .afternoon:
                return String(localized: "good_afternoon") 
            case .evening:
                return String(localized: "good_evening")
            }
        }
        
        var subtitle: String {
            switch self {
            case .morning:
                return String(localized: "morning_report_subtitle")
            case .afternoon:
                return String(localized: "afternoon_report_subtitle")
            case .evening:
                return String(localized: "evening_report_subtitle")
            }
        }
        
        var motivationalMessage: String {
            switch self {
            case .morning:
                return String(localized: "morning_motivation")
            case .afternoon:
                return String(localized: "afternoon_motivation")
            case .evening:
                return String(localized: "evening_motivation")
            }
        }
        
        var actionTip: String {
            switch self {
            case .morning:
                return String(localized: "morning_action_tip")
            case .afternoon:
                return String(localized: "afternoon_action_tip")
            case .evening:
                return String(localized: "evening_action_tip")
            }
        }
        
        var emoji: String {
            switch self {
            case .morning:
                return "🌱"
            case .afternoon:
                return "⚡"
            case .evening:
                return "🌙"
            }
        }
        
        var timeRange: String {
            switch self {
            case .morning:
                return "7:00 - 11:59"
            case .afternoon:
                return "12:00 - 17:59"
            case .evening:
                return "18:00 - 22:00"
            }
        }
        
        static func current() -> TimeOfDay {
            let hour = Calendar.current.component(.hour, from: Date())
            
            switch hour {
            case 7..<12:
                return .morning
            case 12..<18:
                return .afternoon
            case 18...22:
                return .evening
            default:
                // En dehors des créneaux, retourner le prochain créneau
                if hour < 7 || hour > 22 {
                    return .morning // Le prochain sera le matin
                } else {
                    return .morning // Fallback
                }
            }
        }
        
        var isActiveTime: Bool {
            let hour = Calendar.current.component(.hour, from: Date())
            
            switch self {
            case .morning:
                return hour >= 7 && hour < 12
            case .afternoon:
                return hour >= 12 && hour < 18
            case .evening:
                return hour >= 18 && hour <= 22
            }
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let lastMorningReport = "lastMorningReportDate"
        static let lastAfternoonReport = "lastAfternoonReportDate"
        static let lastEveningReport = "lastEveningReportDate"
        static let hasSeenOnboarding = "hasSeenOnboarding"
    }
    
    private init() {
        self.currentTimeOfDay = TimeOfDay.current()
        logger.info("🕐 [DAILY_REPORT] Manager initialized - Current time: \(self.currentTimeOfDay.rawValue)")
    }
    
    // MARK: - Public API
    
    /// Vérifie si on doit afficher le rapport au lancement de l'app
    func checkShouldShowReport() {
        logger.info("🔍 [DAILY_REPORT] Checking if report should be shown")
        
        // Ne pas afficher si l'onboarding n'est pas terminé
        guard userDefaults.bool(forKey: Keys.hasSeenOnboarding) else {
            logger.info("⏭️ [DAILY_REPORT] Skipping - onboarding not completed")
            shouldShowReport = false
            return
        }
        
        self.currentTimeOfDay = TimeOfDay.current()
        
        // Vérifier si on est dans un créneau actif
        guard self.currentTimeOfDay.isActiveTime else {
            logger.info("⏰ [DAILY_REPORT] Not in active time range for \(self.currentTimeOfDay.rawValue)")
            self.shouldShowReport = false
            return
        }
        
        // Vérifier si on a déjà montré le rapport aujourd'hui pour ce créneau
        let hasShownToday = hasShownReportToday(for: self.currentTimeOfDay)
        
        if !hasShownToday {
            logger.info("✅ [DAILY_REPORT] Should show \(self.currentTimeOfDay.rawValue) report")
            self.shouldShowReport = true
        } else {
            logger.info("⏭️ [DAILY_REPORT] Already shown \(self.currentTimeOfDay.rawValue) report today")
            self.shouldShowReport = false
        }
    }
    
    /// Marque le rapport comme affiché pour la période courante
    func markReportAsShown() {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        
        switch self.currentTimeOfDay {
        case .morning:
            userDefaults.set(today, forKey: Keys.lastMorningReport)
        case .afternoon:
            userDefaults.set(today, forKey: Keys.lastAfternoonReport)
        case .evening:
            userDefaults.set(today, forKey: Keys.lastEveningReport)
        }
        
        self.shouldShowReport = false
        logger.info("✅ [DAILY_REPORT] Marked \(self.currentTimeOfDay.rawValue) report as shown for \(today)")
    }
    
    /// Force l'affichage du rapport pour test
    func forceShowReport(timeOfDay: TimeOfDay? = nil) {
        if let timeOfDay = timeOfDay {
            self.currentTimeOfDay = timeOfDay
        } else {
            self.currentTimeOfDay = TimeOfDay.current()
        }
        
        self.shouldShowReport = true
        logger.info("🧪 [DAILY_REPORT] Forced \(self.currentTimeOfDay.rawValue) report display")
    }
    
    /// Marque l'onboarding comme terminé
    func setOnboardingCompleted() {
        userDefaults.set(true, forKey: Keys.hasSeenOnboarding)
        logger.info("✅ [DAILY_REPORT] Onboarding marked as completed")
    }
    
    /// Remet à zéro tous les rapports (pour debug)
    func resetAllReports() {
        userDefaults.removeObject(forKey: Keys.lastMorningReport)
        userDefaults.removeObject(forKey: Keys.lastAfternoonReport)
        userDefaults.removeObject(forKey: Keys.lastEveningReport)
        logger.info("🔄 [DAILY_REPORT] All reports reset")
    }
    
    // MARK: - Private Methods
    
    private func hasShownReportToday(for timeOfDay: TimeOfDay) -> Bool {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        
        let lastShownKey: String
        switch timeOfDay {
        case .morning:
            lastShownKey = Keys.lastMorningReport
        case .afternoon:
            lastShownKey = Keys.lastAfternoonReport
        case .evening:
            lastShownKey = Keys.lastEveningReport
        }
        
        let lastShown = userDefaults.string(forKey: lastShownKey) ?? ""
        let hasShown = lastShown == today
        
        logger.info("📅 [DAILY_REPORT] \(timeOfDay.rawValue) - Today: \(today), Last shown: \(lastShown), Has shown: \(hasShown)")
        
        return hasShown
    }
    
    // MARK: - Debug Helpers
    
    func getDebugInfo() -> String {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let morningShown = userDefaults.string(forKey: Keys.lastMorningReport) ?? "never"
        let afternoonShown = userDefaults.string(forKey: Keys.lastAfternoonReport) ?? "never"
        let eveningShown = userDefaults.string(forKey: Keys.lastEveningReport) ?? "never"
        let onboardingDone = userDefaults.bool(forKey: Keys.hasSeenOnboarding)
        
        return """
        📊 Daily Report Debug Info:
        • Today: \(today)
        • Current time of day: \(self.currentTimeOfDay.rawValue) (\(self.currentTimeOfDay.isActiveTime ? "ACTIVE" : "INACTIVE"))
        • Onboarding completed: \(onboardingDone)
        • Morning last shown: \(morningShown)
        • Afternoon last shown: \(afternoonShown)
        • Evening last shown: \(eveningShown)
        • Should show report: \(self.shouldShowReport)
        """
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}