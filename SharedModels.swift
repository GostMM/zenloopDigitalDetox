//
//  SharedModels.swift
//  zenloop (App + Extension)
//  Modèles partagés entre l’extension et l’app
//

import Foundation

// JSON écrit par l’extension (clé: DAReportLatest dans l’App Group)
struct SharedReportPayload: Codable {
    let intervalStart: TimeInterval
    let intervalEnd: TimeInterval
    let totalSeconds: Double
    let averageDailySeconds: Double
    let updatedAt: TimeInterval
    let topCategories: [SharedReportCategory]   // max 4
    let days: [SharedReportDayPoint]            // série journalière triée
}

struct SharedReportCategory: Codable {
    let name: String
    let seconds: Double
    let appCount: Int
}

struct SharedReportDayPoint: Codable {
    let dayStart: TimeInterval // startOfDay (UTC) en seconds since 1970
    let seconds: Double
}
