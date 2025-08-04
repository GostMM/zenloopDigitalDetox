//
//  zenloopmonitor.swift
//  zenloopmonitor
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import DeviceActivity
import Foundation
import UserNotifications

class ZenloopDeviceActivityMonitor: DeviceActivityMonitor {
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Logique quand un défi commence
        print("🎯 [DeviceActivity] Défi commencé: \(activity)")
        
        // Notifier l'app principale
        notifyMainApp(event: "intervalDidStart", activity: activity.rawValue)
        
        // Envoyer une notification locale
        scheduleNotification(
            title: "Défi Zenloop démarré",
            body: "Votre défi de bien-être numérique a commencé. Restez concentré !",
            identifier: "challenge_started_\(activity.rawValue)"
        )
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Logique quand un défi se termine
        print("✅ [DeviceActivity] Défi terminé: \(activity)")
        
        // Notifier l'app principale
        notifyMainApp(event: "intervalDidEnd", activity: activity.rawValue)
        
        // Envoyer une notification de félicitations
        scheduleNotification(
            title: "Défi Zenloop terminé !",
            body: "Félicitations ! Vous avez réussi votre défi de bien-être numérique.",
            identifier: "challenge_completed_\(activity.rawValue)"
        )
        
        // Sauvegarder les statistiques
        saveChallengeCompletion(activityName: activity)
    }
    
    // Note: Les méthodes d'avertissement ne sont pas disponibles dans DeviceActivityMonitor
    // Elles sont gérées automatiquement par le système
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Logique quand un seuil est atteint (par exemple, limite de temps d'app)
        print("⚠️ [DeviceActivity] Seuil atteint pour l'événement: \(event) dans l'activité: \(activity)")
        
        // Notifier l'app principale
        notifyMainApp(event: "thresholdReached", activity: activity.rawValue, eventName: event.rawValue)
        
        scheduleNotification(
            title: "Limite atteinte",
            body: "Vous avez atteint votre limite d'utilisation. Temps de faire une pause !",
            identifier: "threshold_reached_\(event.rawValue)"
        )
    }
    
    // Note: eventWillReachThresholdWarning n'est pas disponible non plus
    
    // MARK: - Helper Methods
    
    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Déclencher immédiatement
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur notification: \(error)")
            }
        }
    }
    
    private func saveChallengeCompletion(activityName: DeviceActivityName) {
        // Utiliser App Groups pour partager les données avec l'app principale
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Récupérer les défis complétés existants
        var completedChallenges = userDefaults?.array(forKey: "completedChallengeIds") as? [String] ?? []
        
        // Ajouter le nouveau défi complété
        completedChallenges.append(activityName.rawValue)
        
        // Sauvegarder
        userDefaults?.set(completedChallenges, forKey: "completedChallengeIds")
        userDefaults?.set(Date(), forKey: "lastChallengeCompletedDate")
        
        print("Défi sauvegardé: \(activityName.rawValue)")
    }
    
    // MARK: - Communication avec l'app principale
    
    private func notifyMainApp(event: String, activity: String, eventName: String? = nil) {
        // Utiliser UserDefaults pour communiquer avec l'app principale
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        let notification: [String: Any] = [
            "event": event,
            "activity": activity,
            "timestamp": Date().timeIntervalSince1970,
            "eventName": eventName as Any
        ]
        
        // Sauvegarder la notification
        var notifications = defaults.array(forKey: "device_activity_events") as? [[String: Any]] ?? []
        notifications.append(notification)
        
        // Garder seulement les 50 dernières notifications
        if notifications.count > 50 {
            notifications = Array(notifications.suffix(50))
        }
        
        defaults.set(notifications, forKey: "device_activity_events")
        defaults.synchronize()
        
        print("📤 [DeviceActivity] Notification envoyée: \(event) pour \(activity)")
    }
    
    private func recordAppAttempt(appName: String? = nil) {
        // Enregistrer les tentatives d'ouverture d'apps bloquées
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        // Incrementer le compteur total
        let currentCount = defaults.integer(forKey: "app_open_attempts")
        defaults.set(currentCount + 1, forKey: "app_open_attempts")
        
        // Enregistrer la tentative avec timestamp
        var attempts = defaults.array(forKey: "app_attempt_log") as? [[String: Any]] ?? []
        let attempt: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "appName": appName ?? "unknown"
        ]
        attempts.append(attempt)
        
        // Garder seulement les 100 dernières tentatives
        if attempts.count > 100 {
            attempts = Array(attempts.suffix(100))
        }
        
        defaults.set(attempts, forKey: "app_attempt_log")
        defaults.synchronize()
        
        print("🚫 [DeviceActivity] Tentative d'ouverture enregistrée: \(appName ?? "app inconnue")")
    }
}

// Point d'entrée de l'extension - Device Activity Monitor n'a pas besoin de @main
// L'extension est automatiquement activée par le système
