//  StatisticsCoordinator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import FamilyControls
import os

// MARK: - Statistics Management

protocol StatisticsCoordinatorDelegate: AnyObject {
    func statisticsDidUpdate()
    func badgeEarned(type: BadgeType, value: Any)
    func streakUpdated(newStreak: Int)
}

enum BadgeType: String, CaseIterable {
    case completedChallenges = "completed_challenges"
    case totalFocusTime = "total_focus_time"
    case maxAppsBlocked = "max_apps_blocked"
    case currentStreak = "current_streak"
    case longestStreak = "longest_streak"
    case perfectWeek = "perfect_week"
    case focusMonk = "focus_monk"
}

@MainActor
final class StatisticsCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var totalSavedTime: TimeInterval = 0.0
    @Published var completedChallengesTotal: Int = 0
    @Published var currentStreakCount: Int = 0
    @Published var longestStreak: Int = 0
    
    // MARK: - Private Properties
    weak var delegate: StatisticsCoordinatorDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "Statistics")
    #endif
    
    // MARK: - Constants
    private struct Keys {
        static let completedChallengesCount = "completed_challenges_count"
        static let totalFocusTime = "total_focus_time"
        static let maxAppsBlocked = "max_apps_blocked"
        static let currentStreak = "current_streak"
        static let longestStreak = "longest_streak"
        static let lastChallengeDate = "last_challenge_date"
        static let weeklyCompletions = "weekly_completions"
        static let monthlyCompletions = "monthly_completions"
    }
    
    // MARK: - Initialization
    
    init() {
        loadStatistics()
    }
    
    // MARK: - Nonisolated Properties for Badges
    
    nonisolated var completedChallengesCount: Int { 
        UserDefaults.standard.integer(forKey: Keys.completedChallengesCount) 
    }
    
    nonisolated var totalFocusTime: TimeInterval { 
        UserDefaults.standard.double(forKey: Keys.totalFocusTime) 
    }
    
    nonisolated var maxAppsBlockedSimultaneously: Int { 
        UserDefaults.standard.integer(forKey: Keys.maxAppsBlocked) 
    }
    
    nonisolated var currentStreak: Int { 
        UserDefaults.standard.integer(forKey: Keys.currentStreak) 
    }
    
    // MARK: - Statistics Loading
    
    func loadStatistics() {
        self.totalSavedTime = UserDefaults.standard.double(forKey: Keys.totalFocusTime)
        self.completedChallengesTotal = UserDefaults.standard.integer(forKey: Keys.completedChallengesCount)
        self.currentStreakCount = UserDefaults.standard.integer(forKey: Keys.currentStreak)
        self.longestStreak = UserDefaults.standard.integer(forKey: Keys.longestStreak)
        
        #if DEBUG
        self.logger.debug("📊 [Statistics] Loaded: \(self.completedChallengesTotal) challenges, \(self.formatTime(self.totalSavedTime)) saved, streak \(self.currentStreakCount)")
        #endif
        
        delegate?.statisticsDidUpdate()
    }
    
    // MARK: - Challenge Completion Statistics
    
    func updateChallengeStatistics(challenge: ZenloopChallenge) {
        let previousCount = UserDefaults.standard.integer(forKey: Keys.completedChallengesCount)
        let newCount = previousCount + 1
        UserDefaults.standard.set(newCount, forKey: Keys.completedChallengesCount)
        
        let previousFocusTime = UserDefaults.standard.double(forKey: Keys.totalFocusTime)
        let newFocusTime = previousFocusTime + challenge.duration
        UserDefaults.standard.set(newFocusTime, forKey: Keys.totalFocusTime)
        
        let previousMaxApps = UserDefaults.standard.integer(forKey: Keys.maxAppsBlocked)
        if challenge.blockedAppsCount > previousMaxApps {
            UserDefaults.standard.set(challenge.blockedAppsCount, forKey: Keys.maxAppsBlocked)
            delegate?.badgeEarned(type: .maxAppsBlocked, value: challenge.blockedAppsCount)
        }
        
        // Update published properties
        self.totalSavedTime = newFocusTime
        self.completedChallengesTotal = newCount
        
        // Update streak
        self.updateConsecutiveDays()
        
        // Check for new badges
        self.checkForNewBadges(challengeCount: newCount, focusTime: newFocusTime)
        
        self.delegate?.statisticsDidUpdate()
        
        #if DEBUG
        self.logger.debug("📈 [Statistics] Updated after challenge: \(newCount) total, \(self.formatTime(newFocusTime)) focus time")
        #endif
    }
    
    // MARK: - Streak Management
    
    private func updateConsecutiveDays() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastChallengeDate = UserDefaults.standard.object(forKey: Keys.lastChallengeDate) as? Date
        
        if let lastDate = lastChallengeDate {
            let lastChallengeDay = Calendar.current.startOfDay(for: lastDate)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastChallengeDay, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Jour consécutif
                let currentStreak = UserDefaults.standard.integer(forKey: Keys.currentStreak)
                let newStreak = currentStreak + 1
                UserDefaults.standard.set(newStreak, forKey: Keys.currentStreak)
                self.currentStreakCount = newStreak
                
                // Vérifier record de streak
                let previousLongest = UserDefaults.standard.integer(forKey: Keys.longestStreak)
                if newStreak > previousLongest {
                    UserDefaults.standard.set(newStreak, forKey: Keys.longestStreak)
                    self.longestStreak = newStreak
                    self.delegate?.badgeEarned(type: .longestStreak, value: newStreak)
                }
                
                self.delegate?.streakUpdated(newStreak: newStreak)
                
            } else if daysBetween > 1 {
                // Streak cassé
                UserDefaults.standard.set(1, forKey: Keys.currentStreak)
                self.currentStreakCount = 1
                self.delegate?.streakUpdated(newStreak: 1)
            }
        } else {
            // Premier challenge
            UserDefaults.standard.set(1, forKey: Keys.currentStreak)
            self.currentStreakCount = 1
            self.delegate?.streakUpdated(newStreak: 1)
        }
        
        UserDefaults.standard.set(today, forKey: Keys.lastChallengeDate)
        
        #if DEBUG
        self.logger.debug("🔥 [Statistics] Streak updated: \(self.currentStreakCount) days")
        #endif
    }
    
    // MARK: - Badge System
    
    private func checkForNewBadges(challengeCount: Int, focusTime: TimeInterval) {
        // Badge pour nombre de challenges
        let challengeMilestones = [1, 5, 10, 25, 50, 100, 250, 500, 1000]
        if challengeMilestones.contains(challengeCount) {
            self.delegate?.badgeEarned(type: .completedChallenges, value: challengeCount)
        }
        
        // Badge pour temps de focus (en heures)
        let focusHours = Int(focusTime / 3600)
        let focusMilestones = [1, 5, 10, 25, 50, 100, 250, 500]
        if focusMilestones.contains(focusHours) {
            self.delegate?.badgeEarned(type: .totalFocusTime, value: focusHours)
        }
        
        // Badge moine focus (100 heures)
        if focusHours >= 100 {
            self.delegate?.badgeEarned(type: .focusMonk, value: focusHours)
        }
        
        // Badge semaine parfaite
        if self.currentStreakCount >= 7 && self.currentStreakCount % 7 == 0 {
            self.delegate?.badgeEarned(type: .perfectWeek, value: self.currentStreakCount / 7)
        }
    }
    
    // MARK: - Weekly/Monthly Statistics
    
    func updateWeeklyStats() {
        let now = Date()
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.year, from: now)
        let weekKey = "week_\(year)_\(weekOfYear)"
        
        let currentWeekCompletions = UserDefaults.standard.integer(forKey: weekKey)
        UserDefaults.standard.set(currentWeekCompletions + 1, forKey: weekKey)
        
        #if DEBUG
        self.logger.debug("📅 [Statistics] Weekly stats updated: \(currentWeekCompletions + 1) this week")
        #endif
    }
    
    func updateMonthlyStats() {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let monthKey = "month_\(year)_\(month)"
        
        let currentMonthCompletions = UserDefaults.standard.integer(forKey: monthKey)
        UserDefaults.standard.set(currentMonthCompletions + 1, forKey: monthKey)
        
        #if DEBUG
        self.logger.debug("📅 [Statistics] Monthly stats updated: \(currentMonthCompletions + 1) this month")
        #endif
    }
    
    // MARK: - Statistics Queries
    
    func getWeeklyCompletions() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.year, from: now)
        let weekKey = "week_\(year)_\(weekOfYear)"
        
        return UserDefaults.standard.integer(forKey: weekKey)
    }
    
    func getMonthlyCompletions() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let monthKey = "month_\(year)_\(month)"
        
        return UserDefaults.standard.integer(forKey: monthKey)
    }
    
    func getAverageSessionDuration() -> TimeInterval {
        let totalChallenges = self.completedChallengesTotal
        guard totalChallenges > 0 else { return 0 }
        return self.totalSavedTime / Double(totalChallenges)
    }
    
    func getLongestSession() -> TimeInterval {
        return UserDefaults.standard.double(forKey: "longest_session_duration")
    }
    
    func updateLongestSession(_ duration: TimeInterval) {
        let currentLongest = getLongestSession()
        if duration > currentLongest {
            UserDefaults.standard.set(duration, forKey: "longest_session_duration")
            #if DEBUG
            self.logger.debug("🏆 [Statistics] New longest session record: \(self.formatTime(duration))")
            #endif
        }
    }
    
    // MARK: - Statistics Reset
    
    func resetAllStatistics() {
        let keys = [
            Keys.completedChallengesCount,
            Keys.totalFocusTime,
            Keys.maxAppsBlocked,
            Keys.currentStreak,
            Keys.longestStreak,
            Keys.lastChallengeDate,
            "longest_session_duration"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        self.loadStatistics()
        
        #if DEBUG
        self.logger.debug("🔄 [Statistics] All statistics reset")
        #endif
    }
    
    func resetStreak() {
        UserDefaults.standard.set(0, forKey: Keys.currentStreak)
        self.currentStreakCount = 0
        self.delegate?.streakUpdated(newStreak: 0)
        
        #if DEBUG
        self.logger.debug("🔄 [Statistics] Streak reset to 0")
        #endif
    }
    
    // MARK: - Export Statistics
    
    func getStatisticsSummary() -> [String: Any] {
        return [
            "completedChallenges": self.completedChallengesTotal,
            "totalFocusTime": self.totalSavedTime,
            "totalFocusHours": self.totalSavedTime / 3600,
            "maxAppsBlocked": self.maxAppsBlockedSimultaneously,
            "currentStreak": self.currentStreakCount,
            "longestStreak": self.longestStreak,
            "averageSessionDuration": self.getAverageSessionDuration(),
            "longestSession": self.getLongestSession(),
            "weeklyCompletions": self.getWeeklyCompletions(),
            "monthlyCompletions": self.getMonthlyCompletions()
        ]
    }
    
    // MARK: - Utility
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}