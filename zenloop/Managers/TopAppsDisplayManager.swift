//
//  TopAppsDisplayManager.swift
//  zenloop
//
//  Gestionnaire pour afficher la card des top apps 3x par jour (matin, après-midi, soir)
//

import Foundation
import SwiftUI

@MainActor
class TopAppsDisplayManager: ObservableObject {
    static let shared = TopAppsDisplayManager()

    @Published var shouldShowCard = false

    private let userDefaults = UserDefaults.standard
    private let lastShowKey = "TopAppsCard_LastShown"
    private let showCountKey = "TopAppsCard_ShowCountToday"

    enum TimeOfDay: String, CaseIterable {
        case morning = "morning"      // 8h-12h
        case afternoon = "afternoon"  // 12h-18h
        case evening = "evening"      // 18h-22h

        var timeRange: (start: Int, end: Int) {
            switch self {
            case .morning: return (8, 12)
            case .afternoon: return (12, 18)
            case .evening: return (18, 22)
            }
        }

        var localizedName: String {
            switch self {
            case .morning: return String(localized: "morning")
            case .afternoon: return String(localized: "afternoon")
            case .evening: return String(localized: "evening")
            }
        }
    }

    private init() {
        print("🏁 [TOP_APPS_MANAGER] Initialisation")
        // Affichage permanent au lancement
        DispatchQueue.main.async {
            self.shouldShowCard = true
            print("🔧 [TOP_APPS_MANAGER] shouldShowCard = true")
        }
    }

    /// Vérifier si on doit afficher la card
    func checkIfShouldShow() {
        print("🕐 [TOP_APPS_MANAGER] === Vérification affichage ===")

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // Vérifier si c'est le premier lancement de l'app aujourd'hui
        let isFirstLaunchToday = checkFirstLaunchToday()

        if isFirstLaunchToday {
            print("🎯 [TOP_APPS_MANAGER] PREMIER LANCEMENT AUJOURD'HUI - Affichage permanent")
            DispatchQueue.main.async {
                self.shouldShowCard = true
            }
            markFirstLaunchToday()
            return
        }

        // Déterminer la période actuelle (matin/après-midi/soir)
        guard let currentPeriod = getCurrentTimeOfDay(hour: currentHour) else {
            print("⏰ [TOP_APPS_MANAGER] Hors des heures d'affichage (actuel: \(currentHour)h)")
            DispatchQueue.main.async {
                self.shouldShowCard = false
            }
            return
        }

        print("⏰ [TOP_APPS_MANAGER] Période actuelle: \(currentPeriod.localizedName) (\(currentHour)h)")

        // Vérifier si déjà affiché aujourd'hui pour cette période
        if hasShownToday(for: currentPeriod) {
            print("✅ [TOP_APPS_MANAGER] Déjà affiché pour \(currentPeriod.localizedName)")
            DispatchQueue.main.async {
                self.shouldShowCard = false
            }
            return
        }

        print("🎯 [TOP_APPS_MANAGER] Affichage autorisé pour \(currentPeriod.localizedName)")
        DispatchQueue.main.async {
            self.shouldShowCard = true
        }

        // Marquer comme affiché
        markAsShown(for: currentPeriod)
    }

    /// Vérifier si c'est le premier lancement aujourd'hui
    private func checkFirstLaunchToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let key = "TopAppsCard_FirstLaunchDate"

        if let lastLaunchTimestamp = userDefaults.object(forKey: key) as? TimeInterval {
            let lastLaunchDate = Date(timeIntervalSince1970: lastLaunchTimestamp)
            let lastLaunchDay = calendar.startOfDay(for: lastLaunchDate)

            // Si dernier lancement était aujourd'hui, ce n'est pas le premier
            return lastLaunchDay != today
        }

        // Aucun lancement enregistré = premier lancement
        return true
    }

    /// Marquer le premier lancement d'aujourd'hui
    private func markFirstLaunchToday() {
        let key = "TopAppsCard_FirstLaunchDate"
        userDefaults.set(Date().timeIntervalSince1970, forKey: key)
        userDefaults.synchronize()
        print("💾 [TOP_APPS_MANAGER] Premier lancement marqué")
    }

    /// Obtenir la période actuelle
    private func getCurrentTimeOfDay(hour: Int) -> TimeOfDay? {
        for period in TimeOfDay.allCases {
            let range = period.timeRange
            if hour >= range.start && hour < range.end {
                return period
            }
        }
        return nil
    }

    /// Vérifier si déjà affiché aujourd'hui pour cette période
    private func hasShownToday(for period: TimeOfDay) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Clé spécifique par période
        let key = "\(lastShowKey)_\(period.rawValue)"

        if let lastShownTimestamp = userDefaults.object(forKey: key) as? TimeInterval {
            let lastShownDate = Date(timeIntervalSince1970: lastShownTimestamp)
            let lastShownDay = calendar.startOfDay(for: lastShownDate)

            if lastShownDay == today {
                print("✅ [TOP_APPS_MANAGER] Déjà affiché aujourd'hui pour \(period.localizedName)")
                return true
            }
        }

        return false
    }

    /// Marquer comme affiché pour la période actuelle
    private func markAsShown(for period: TimeOfDay) {
        let key = "\(lastShowKey)_\(period.rawValue)"
        userDefaults.set(Date().timeIntervalSince1970, forKey: key)
        userDefaults.synchronize()
        print("💾 [TOP_APPS_MANAGER] Marqué comme affiché pour \(period.localizedName)")
    }

    /// Masquer la card (appelé quand l'utilisateur ferme)
    func dismissCard() {
        DispatchQueue.main.async {
            self.shouldShowCard = false
            print("❌ [TOP_APPS_MANAGER] Card masquée par l'utilisateur")
        }
    }

    /// Forcer l'affichage (pour debug)
    func forceShow() {
        shouldShowCard = true
        print("🔧 [TOP_APPS_MANAGER] Affichage forcé (debug)")
    }

    /// Reset pour aujourd'hui (pour debug)
    func resetToday() {
        // Reset toutes les clés liées à l'affichage
        for period in TimeOfDay.allCases {
            let key = "\(lastShowKey)_\(period.rawValue)"
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.removeObject(forKey: "TopAppsCard_FirstLaunchDate")
        userDefaults.synchronize()
        print("🔄 [TOP_APPS_MANAGER] Reset complet des affichages")

        // Forcer l'affichage immédiatement
        DispatchQueue.main.async {
            self.shouldShowCard = true
        }
        checkIfShouldShow()
    }
}
