//
//  SharedModels.swift
//  zenloop
//
//  Created by Claude on 14/08/2025.
//

import Foundation

// MARK: - Shared Data Models between App and Extensions

/// Données partagées depuis TotalActivityReport via App Group
struct SharedReportPayload: Codable {
    let intervalStart: TimeInterval
    let intervalEnd: TimeInterval
    let totalSeconds: Double
    let averageDailySeconds: Double
    let updatedAt: TimeInterval
    let topCategories: [SharedReportCategory]
    let days: [SharedReportDayPoint]
}

struct SharedReportCategory: Codable {
    let name: String
    let seconds: Double
    let appCount: Int
}

struct SharedReportDayPoint: Codable {
    let dayStart: TimeInterval
    let seconds: Double
    
    var date: Date { 
        Date(timeIntervalSince1970: dayStart) 
    }
    
    var hours: Double { 
        seconds / 3600 
    }
}

// MARK: - App Group Configuration

struct AppGroupConfig {
    static let suiteName = "group.com.app.zenloop"
    
    struct Keys {
        static let deviceActivityReport = "DAReportLatest"
        static let deviceActivityReportLegacy = "DeviceActivityData"
    }
}