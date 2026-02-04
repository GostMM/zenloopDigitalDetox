//
//  MonitorActivator.swift
//  zenloop
//
//  Active le Monitor Extension pour qu'il puisse recevoir les commandes de blocage
//

import Foundation
import DeviceActivity
import os

private let logger = Logger(subsystem: "com.app.zenloop", category: "MonitorActivator")

class MonitorActivator {
    static let shared = MonitorActivator()
    private let center = DeviceActivityCenter()

    private init() {}

    /// Active le Monitor Extension avec une schedule permanente
    func activateMonitor() {
        logger.critical("🚀 [ACTIVATOR] Starting Monitor Extension activation...")

        // Créer une schedule qui couvre toute la journée (24h)
        // Cela garantit que le Monitor Extension est toujours actif
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true // Répéter tous les jours
        )

        let activityName = DeviceActivityName("monitor_always_active")

        do {
            // Arrêter toute activité précédente
            try center.stopMonitoring([activityName])

            // Démarrer le monitoring permanent
            try center.startMonitoring(activityName, during: schedule)

            logger.critical("✅ [ACTIVATOR] Monitor Extension activated successfully!")
            logger.critical("   → Activity: \(activityName.rawValue)")
            logger.critical("   → Schedule: 00:00 - 23:59 (daily)")

            // Sauvegarder dans App Group pour debug
            if let suite = UserDefaults(suiteName: "group.com.app.zenloop") {
                suite.set(true, forKey: "monitor_extension_active")
                suite.set(Date().timeIntervalSince1970, forKey: "monitor_activation_timestamp")
                suite.synchronize()
            }

        } catch {
            logger.error("❌ [ACTIVATOR] Failed to activate Monitor Extension: \(error.localizedDescription)")
        }
    }

    /// Vérifie si le Monitor Extension est actif
    func isMonitorActive() -> Bool {
        // Vérifier si l'activité est en cours
        let activities = center.activities
        return activities.contains(DeviceActivityName("monitor_always_active"))
    }

    /// Désactive le Monitor Extension (pour debug uniquement)
    func deactivateMonitor() {
        do {
            try center.stopMonitoring([DeviceActivityName("monitor_always_active")])
            logger.info("🛑 [ACTIVATOR] Monitor Extension deactivated")
        } catch {
            logger.error("❌ [ACTIVATOR] Failed to deactivate: \(error)")
        }
    }
}