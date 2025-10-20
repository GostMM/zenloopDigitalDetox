//
//  SharedModels.swift
//  zenloop
//
//  Created by Claude on 14/08/2025.
//

import Foundation
import SwiftUI

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
    let todayScreenSeconds: Double
    let todayOffScreenSeconds: Double
    let topApps: [SharedReportApp]  // ✅ Ajout des top apps
}

struct SharedReportApp: Codable {
    let name: String
    let seconds: Double
    let bundleId: String?
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

// MARK: - Shared Activity Store (moved from StatsView for reuse)

final class SharedActivityStore: ObservableObject {
    struct DayPoint: Identifiable { let id = UUID(); let date: Date; let seconds: Double }
    struct CategorySlice: Identifiable { let id = UUID(); let name: String; let seconds: Double; let appCount: Int }
    
    @Published var interval: DateInterval = .init(start: Date(), end: Date())
    @Published var totalSeconds: Double = 0
    @Published var averageDailySeconds: Double = 0
    @Published var days: [DayPoint] = []
    @Published var topCategories: [CategorySlice] = []
    @Published var updatedAt: Date = Date()
    @Published var savedSeconds: Double = 0
    @Published var todayScreenSeconds: Double = 0
    @Published var todayOffScreenSeconds: Double = 0
    @Published var isLoading: Bool = false
    
    private let appGroup = AppGroupConfig.suiteName
    private let reportKey = AppGroupConfig.Keys.deviceActivityReport
    private let savedKey  = "zenloop.savedSeconds"
    
    // Débouncing pour éviter les rechargements excessifs
    private var lastLoadTime: Date = Date.distantPast
    private let minLoadInterval: TimeInterval = 2.0 // 2 secondes minimum entre les loads
    private var hasEverLoaded: Bool = false
    
    func load(force: Bool = false) {
        let now = Date()
        
        // Premier chargement toujours autorisé
        if !hasEverLoaded {
            hasEverLoaded = true
            print("🚀 [SHARED_STORE] First load - bypassing debouncing")
        } else {
            // Débouncing : éviter les rechargements trop fréquents
            if !force && now.timeIntervalSince(lastLoadTime) < minLoadInterval {
                print("⏱️ [SHARED_STORE] Load debounced - too frequent")
                return
            }
            
            if isLoading && !force {
                print("⏱️ [SHARED_STORE] Already loading - skipping")
                return
            }
        }
        
        isLoading = true
        lastLoadTime = now
        print("📊 [SHARED_STORE] Loading data...")
        
        // Utilisation sécurisée de UserDefaults avec gestion d'erreurs et fallback
        do {
            // Essayer d'abord l'App Group, avec fallback vers UserDefaults standard
            let shared = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
            
            if let data = shared.data(forKey: reportKey) {
                let p = try JSONDecoder().decode(SharedReportPayload.self, from: data)
                interval = .init(start: Date(timeIntervalSince1970: p.intervalStart),
                                 end:   Date(timeIntervalSince1970: p.intervalEnd))
                totalSeconds        = p.totalSeconds
                averageDailySeconds = p.averageDailySeconds
                updatedAt           = Date(timeIntervalSince1970: p.updatedAt)
                todayScreenSeconds  = p.todayScreenSeconds
                todayOffScreenSeconds = p.todayOffScreenSeconds
                days = p.days.map { .init(date: Date(timeIntervalSince1970: $0.dayStart), seconds: $0.seconds) }
                topCategories = p.topCategories.map { .init(name: $0.name, seconds: $0.seconds, appCount: $0.appCount) }
                print("✅ [SHARED_STORE] Loaded from App Group: totalSeconds=\(totalSeconds), todayScreenSeconds=\(todayScreenSeconds)")
            } else {
                // Si pas de données de l'extension, tout à zéro
                print("⚠️ [SHARED_STORE] No data found in App Group - using defaults")
                resetToDefaults()
            }
        } catch {
            print("❌ [SHARED_STORE] Error loading: \(error)")
            resetToDefaults()
        }
        
        // Chargement local sécurisé avec sync App Group
        savedSeconds = UserDefaults.standard.double(forKey: savedKey)
        
        // Sync savedSeconds to App Group for widget access
        if let appGroupSuite = UserDefaults(suiteName: appGroup) {
            appGroupSuite.set(savedSeconds, forKey: savedKey)
            appGroupSuite.synchronize()
        }
        isLoading = false
        print("✅ [SHARED_STORE] Data loaded successfully")
    }
    
    private func resetToDefaults() {
        interval = .init(start: Calendar.current.startOfDay(for: Date()), end: Date())
        totalSeconds = 0
        averageDailySeconds = 0
        todayScreenSeconds = 0
        todayOffScreenSeconds = 0
        days = []
        topCategories = []
        updatedAt = Date()
    }
    
    func addSaved(seconds: Double) {
        let v = max(0, savedSeconds + seconds)
        savedSeconds = v
        UserDefaults.standard.set(v, forKey: savedKey)
        
        // Also save to App Group for widget access
        if let appGroupSuite = UserDefaults(suiteName: appGroup) {
            appGroupSuite.set(v, forKey: savedKey)
            appGroupSuite.synchronize()
        }
    }
}