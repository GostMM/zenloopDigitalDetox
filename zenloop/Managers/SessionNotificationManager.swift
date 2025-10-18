//
//  SessionNotificationManager.swift
//  zenloop
//
//  Created by Claude on 12/08/2025.
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Session Notification Manager

@MainActor
final class SessionNotificationManager: NSObject, ObservableObject {
    static let shared = SessionNotificationManager()
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var scheduledNotifications: [ScheduledNotification] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    
    // Clés de stockage
    private let scheduledNotificationsKey = "scheduled_notifications"
    private let notificationSettingsKey = "notification_settings"
    
    private override init() {
        super.init()
        setupNotificationCenter()
        loadScheduledNotifications()
        
        // Ne plus demander automatiquement les permissions - c'est géré par l'onboarding
        Task {
            await updatePermissionStatus()
            
            // Si les permissions sont déjà accordées, activer le système
            if notificationPermissionStatus == .authorized {
                await setupDailyWellnessNotifications()
            }
        }
        
        print("🚀 [SESSION_NOTIFICATIONS] Notification system initialized")
    }
    
    func setupDailyWellnessNotifications() async {
        guard notificationPermissionStatus == .authorized else {
            print("⚠️ [SESSION_NOTIFICATIONS] No permission for daily wellness notifications")
            return
        }
        
        // Programmer tous les types de notifications bien-être
        scheduleDailyTips()
        scheduleMotivationalReminders()
        scheduleWeeklyEncouragement()
        
        print("✅ [SESSION_NOTIFICATIONS] Daily wellness notifications system activated")
        
        // Debug pour vérifier
        await debugScheduledNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        
        // Configurer les catégories de notifications pour les actions
        setupNotificationCategories()
        
        // Écouter les changements d'état de l'app
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        print("📱 [SESSION_NOTIFICATIONS] Session Notification Manager initialized")
    }
    
    private func setupNotificationCategories() {
        let sessionStartAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: String(localized: "start_session"),
            options: [.foreground]
        )
        
        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_SESSION",
            title: "Reporter 5 min",
            options: []
        )
        
        let sessionReminderCategory = UNNotificationCategory(
            identifier: "SESSION_REMINDER",
            actions: [sessionStartAction, postponeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let sessionStartCategory = UNNotificationCategory(
            identifier: "SESSION_START",
            actions: [sessionStartAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let dailyTipCategory = UNNotificationCategory(
            identifier: "DAILY_TIP",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        notificationCenter.setNotificationCategories([
            sessionReminderCategory,
            sessionStartCategory,
            dailyTipCategory
        ])
    }
    
    @objc private func appDidEnterBackground() {
        print("🌙 [SESSION_NOTIFICATIONS] App entered background - notifications will continue")
    }
    
    @objc private func appWillEnterForeground() {
        Task {
            await updatePermissionStatus()
            await cleanupExpiredNotifications()
            await debugScheduledNotifications()
        }
        
        print("☀️ [SESSION_NOTIFICATIONS] App returned to foreground")
    }
    
    // MARK: - Permission Management
    
    private func requestPermissions() {
        // Demander d'abord les permissions standards
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                self?.notificationPermissionStatus = granted ? .authorized : .denied
                
                if granted {
                    print("✅ [SESSION_NOTIFICATIONS] Permissions granted")
                    
                    // Ensuite demander les permissions critiques si nécessaire
                    self?.requestCriticalAlertPermission()
                } else if let error = error {
                    print("❌ [SESSION_NOTIFICATIONS] Permission error: \(error)")
                }
            }
        }
    }
    
    private func requestCriticalAlertPermission() {
        // Les alertes critiques nécessitent une autorisation spéciale d'Apple
        // Pour l'instant, on utilise les notifications normales
        notificationCenter.requestAuthorization(options: [.criticalAlert]) { granted, error in
            if granted {
                print("✅ [SESSION_NOTIFICATIONS] Critical alert permission granted")
            } else {
                print("⚠️ [SESSION_NOTIFICATIONS] Critical alert permission denied - using standard notifications")
            }
        }
    }
    
    private func updatePermissionStatus() async {
        let settings = await notificationCenter.notificationSettings()
        notificationPermissionStatus = settings.authorizationStatus
    }
    
    // MARK: - Session Scheduling
    
    func scheduleSessionReminder(
        sessionId: String,
        title: String,
        startTime: Date,
        duration: TimeInterval,
        apps: [String] = []
    ) {
        guard notificationPermissionStatus == .authorized else {
            print("⚠️ [SESSION_NOTIFICATIONS] No permission to schedule notifications")
            return
        }
        
        let scheduledNotification = ScheduledNotification(
            id: sessionId,
            type: .sessionReminder,
            title: title,
            scheduledFor: startTime,
            duration: duration,
            apps: apps,
            isActive: true
        )
        
        // Planifier les notifications
        Task {
            await scheduleNotificationSequence(for: scheduledNotification)
            
            // Ajouter à la liste
            scheduledNotifications.append(scheduledNotification)
            saveScheduledNotifications()
            
            print("📅 [SESSION_NOTIFICATIONS] Scheduled reminders for session: \(title) at \(startTime)")
        }
    }
    
    private func scheduleNotificationSequence(for session: ScheduledNotification) async {
        let notifications = createNotificationSequence(for: session)
        
        for notification in notifications {
            do {
                try await notificationCenter.add(notification.request)
                print("⏰ [SESSION_NOTIFICATIONS] Scheduled: \(notification.title) for \(notification.scheduledTime)")
            } catch {
                print("❌ [SESSION_NOTIFICATIONS] Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func createNotificationSequence(for session: ScheduledNotification) -> [NotificationInfo] {
        var notifications: [NotificationInfo] = []
        let baseId = session.id
        
        // NOUVEAU: Système dynamique basé sur le temps restant
        let timeUntilSession = session.scheduledFor.timeIntervalSinceNow
        let minutesUntilSession = Int(timeUntilSession / 60)
        
        print("📅 [SESSION_NOTIFICATIONS] Session in \(minutesUntilSession) minutes - creating dynamic notifications")
        
        // Logique dynamique adaptée au timing réel
        if minutesUntilSession > 15 {
            // Session dans plus de 15 minutes : notification à -15min ET -2min
            createReminderNotification(
                baseId: baseId, 
                session: session, 
                minutesBefore: 15, 
                messageKey: "session_starts_in_15_minutes",
                notifications: &notifications
            )
            createReminderNotification(
                baseId: baseId, 
                session: session, 
                minutesBefore: 2, 
                messageKey: "session_starts_in_2_minutes",
                notifications: &notifications
            )
        } else if minutesUntilSession > 5 {
            // Session dans 6-15 minutes : notification à -5min et -1min
            createReminderNotification(
                baseId: baseId, 
                session: session, 
                minutesBefore: 5, 
                messageKey: "session_starts_in_5_minutes",
                notifications: &notifications
            )
            createReminderNotification(
                baseId: baseId, 
                session: session, 
                minutesBefore: 1, 
                messageKey: "session_starts_in_1_minute",
                notifications: &notifications
            )
        } else if minutesUntilSession > 2 {
            // Session dans 3-5 minutes : notification à -1min seulement
            createReminderNotification(
                baseId: baseId, 
                session: session, 
                minutesBefore: 1, 
                messageKey: "session_starts_in_1_minute",
                notifications: &notifications
            )
        } else if minutesUntilSession > 0 {
            // Session dans 1-2 minutes : notification immédiate
            createImmediateReminderNotification(
                baseId: baseId, 
                session: session, 
                notifications: &notifications
            )
        }
        
        // Toujours ajouter les notifications de progression et de fin
        addProgressAndEndNotifications(baseId: baseId, session: session, notifications: &notifications)
        
        return notifications
    }
    
    private func createReminderNotification(
        baseId: String, 
        session: ScheduledNotification, 
        minutesBefore: Int, 
        messageKey: String,
        notifications: inout [NotificationInfo]
    ) {
        guard let reminderTime = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: session.scheduledFor),
              reminderTime > Date() else { return }
        
        let body = createDynamicMessage(key: messageKey, sessionTitle: session.title, minutes: minutesBefore)
        
        let content = createReminderContent(
            title: String(localized: "session_starting_soon"),
            body: body,
            sound: minutesBefore <= 2 ? .critical : .default
        )
        
        notifications.append(NotificationInfo(
            id: "\(baseId)_reminder_\(minutesBefore)",
            title: session.title,
            content: content,
            scheduledTime: reminderTime,
            request: createNotificationRequest(
                identifier: "\(baseId)_reminder_\(minutesBefore)",
                content: content,
                triggerDate: reminderTime,
                categoryIdentifier: "SESSION_REMINDER"
            )
        ))
    }
    
    private func createDynamicMessage(key: String, sessionTitle: String, minutes: Int) -> String {
        switch minutes {
        case 15:
            return "\(sessionTitle) démarre dans 15 minutes. Prépare-toi !"
        case 5:
            return "\(sessionTitle) démarre dans 5 minutes. C'est bientôt !"
        case 2:
            return "\(sessionTitle) démarre dans 2 minutes. C'est l'heure de focus !"
        case 1:
            return "\(sessionTitle) démarre dans 1 minute. Prépare-toi maintenant !"
        default:
            return "\(sessionTitle) démarre bientôt."
        }
    }
    
    private func createImmediateReminderNotification(
        baseId: String, 
        session: ScheduledNotification, 
        notifications: inout [NotificationInfo]
    ) {
        let content = createReminderContent(
            title: String(localized: "session_starting_now"),
            body: "\(session.title) démarre maintenant ! 🚀",
            sound: .critical
        )
        
        notifications.append(NotificationInfo(
            id: "\(baseId)_starting_now",
            title: session.title,
            content: content,
            scheduledTime: Date().addingTimeInterval(5), // Dans 5 secondes
            request: createNotificationRequest(
                identifier: "\(baseId)_starting_now",
                content: content,
                triggerDate: Date().addingTimeInterval(5),
                categoryIdentifier: "SESSION_STARTING"
            )
        ))
    }
    
    private func addProgressAndEndNotifications(
        baseId: String, 
        session: ScheduledNotification, 
        notifications: inout [NotificationInfo]
    ) {
        // Notification de progression (à mi-parcours)
        let progressTime = session.scheduledFor.addingTimeInterval(session.duration / 2)
        let progressContent = createReminderContent(
            title: String(localized: "session_progress"),
            body: String(localized: "session_progress_halfway", defaultValue: "You're halfway through your focus session. Keep going!", table: nil, bundle: .main, comment: ""),
            sound: .default
        )
        
        notifications.append(NotificationInfo(
            id: "\(baseId)_progress",
            title: "session_progress",
            content: progressContent,
            scheduledTime: progressTime,
            request: createNotificationRequest(
                identifier: "\(baseId)_progress",
                content: progressContent,
                triggerDate: progressTime,
                categoryIdentifier: "SESSION_PROGRESS"
            )
        ))
        
        // Notification de fin
        let endTime = session.scheduledFor.addingTimeInterval(session.duration)
        let endContent = createReminderContent(
            title: String(localized: "session_complete"),
            body: String(localized: "session_completed_congratulations", defaultValue: "Congratulations! You've completed your focus session.", table: nil, bundle: .main, comment: ""),
            sound: .default
        )
        
        notifications.append(NotificationInfo(
            id: "\(baseId)_end",
            title: "session_end",
            content: endContent,
            scheduledTime: endTime,
            request: createNotificationRequest(
                identifier: "\(baseId)_end",
                content: endContent,
                triggerDate: endTime,
                categoryIdentifier: "SESSION_END"
            )
        ))
    }
    
    // MARK: - Conflict Resolution
    
    func notifySessionConflict(existing: String, new: String, timeRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Conflit de Sessions"
        content.body = "Session '\(existing)' active (encore \(timeRemaining)min). '\(new)' sera reportée."
        content.sound = .default
        content.categoryIdentifier = "SESSION_CONFLICT"
        
        let request = UNNotificationRequest(
            identifier: "session_conflict_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ [SESSION_NOTIFICATIONS] Failed to schedule conflict notification: \(error)")
            } else {
                print("⚠️ [SESSION_NOTIFICATIONS] Session conflict notification scheduled")
            }
        }
    }
    
    // MARK: - Content Creation
    
    private func createReminderContent(title: String, body: String, sound: NotificationSoundType) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound.unSound
        content.badge = 1
        content.userInfo = [
            "type": "session_reminder",
            "action": "prepare"
        ]
        return content
    }
    
    private func createSessionStartContent(for session: ScheduledNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "focus_time")
        content.body = String(localized: "session_ready_to_start", defaultValue: "\(session.title) is ready to start! Tap to begin your focus session.", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: session.title)
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "type": "session_start",
            "sessionId": session.id,
            "action": "start_session"
        ]
        return content
    }
    
    private func createProgressContent(title: String, body: String, sound: NotificationSoundType) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound.unSound
        content.userInfo = [
            "type": "session_progress",
            "action": "encouragement"
        ]
        return content
    }
    
    private func createSessionEndContent(for session: ScheduledNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "session_complete")
        content.body = String(localized: "session_completed_successfully", defaultValue: "Your focus session is complete! Well done on staying focused.", table: nil, bundle: .main, comment: "")
        content.sound = UNNotificationSound(named: UNNotificationSoundName("success.wav"))
        content.userInfo = [
            "type": "session_end",
            "sessionId": session.id,
            "action": "celebrate"
        ]
        return content
    }
    
    // MARK: - Notification Request Creation
    
    private func createNotificationRequest(
        identifier: String,
        content: UNMutableNotificationContent,
        triggerDate: Date,
        categoryIdentifier: String? = nil
    ) -> UNNotificationRequest {
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        let timeInterval = triggerDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )
        
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }
    
    private func createCriticalNotificationRequest(
        identifier: String,
        content: UNMutableNotificationContent,
        triggerDate: Date
    ) -> UNNotificationRequest {
        // Notification critique pour les rappels importants
        content.interruptionLevel = .critical
        content.sound = UNNotificationSound.defaultCritical
        
        let timeInterval = triggerDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )
        
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
    }
    
    // MARK: - Session Management
    
    func cancelSessionNotifications(sessionId: String) {
        let scheduledIdentifiers = [
            "\(sessionId)_reminder_15",
            "\(sessionId)_final_reminder",
            "\(sessionId)_start",
            "\(sessionId)_progress",
            "\(sessionId)_end"
        ]
        
        let immediateIdentifiers = [
            "session_started_\(sessionId)",
            "session_progress_\(sessionId)",
            "session_completed_\(sessionId)"
        ]
        
        let allIdentifiers = scheduledIdentifiers + immediateIdentifiers
        notificationCenter.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        
        // Marquer comme inactive dans la liste
        if let index = scheduledNotifications.firstIndex(where: { $0.id == sessionId }) {
            scheduledNotifications[index].isActive = false
            saveScheduledNotifications()
        }
        
        print("🗑️ [SESSION_NOTIFICATIONS] Cancelled \(allIdentifiers.count) notifications for session: \(sessionId)")
    }
    
    func rescheduleSession(
        sessionId: String,
        newStartTime: Date,
        newDuration: TimeInterval? = nil
    ) {
        // Annuler les anciennes notifications
        cancelSessionNotifications(sessionId: sessionId)
        
        // Replanifier avec les nouveaux paramètres
        if let index = scheduledNotifications.firstIndex(where: { $0.id == sessionId }) {
            var session = scheduledNotifications[index]
            session.scheduledFor = newStartTime
            if let newDuration = newDuration {
                session.duration = newDuration
            }
            session.isActive = true
            
            Task {
                await scheduleNotificationSequence(for: session)
            }
            
            scheduledNotifications[index] = session
            saveScheduledNotifications()
            
            print("🔄 [SESSION_NOTIFICATIONS] Rescheduled session: \(sessionId) for \(newStartTime)")
        }
    }
    
    // MARK: - Immediate Session Notifications
    
    func notifySessionStarted(sessionTitle: String, sessionId: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "session_started")
        content.body = String(localized: "session_started_successfully", defaultValue: "\(sessionTitle) has started successfully! Stay focused.", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: sessionTitle)
        content.sound = .default
        content.userInfo = [
            "type": "session_active",
            "sessionId": sessionId
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_started_\(sessionId)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        Task {
            try? await notificationCenter.add(request)
            print("✅ [SESSION_NOTIFICATIONS] Session started notification sent for: \(sessionTitle)")
        }
    }
    
    func scheduleProgressNotification(sessionTitle: String, sessionId: String, duration: TimeInterval) {
        // Notification à mi-parcours pour les sessions > 10 minutes
        guard duration > 600 else { return }
        
        let progressContent = UNMutableNotificationContent()
        progressContent.title = String(localized: "session_progress_halfway")
        progressContent.body = String(localized: "halfway_through_session")
        progressContent.sound = UNNotificationSound(named: UNNotificationSoundName("gentle.wav"))
        progressContent.userInfo = [
            "type": "session_progress",
            "sessionId": sessionId
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_progress_\(sessionId)",
            content: progressContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: duration / 2, repeats: false)
        )
        
        Task {
            try? await notificationCenter.add(request)
            print("⏰ [SESSION_NOTIFICATIONS] Progress notification scheduled for: \(sessionTitle) in \(Int(duration/2/60)) minutes")
        }
    }
    
    func notifySessionCompleted(sessionTitle: String, sessionId: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "session_complete")
        content.body = String(localized: "session_completed_successfully")
        content.sound = UNNotificationSound(named: UNNotificationSoundName("success.wav"))
        content.userInfo = [
            "type": "session_end",
            "sessionId": sessionId
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_completed_\(sessionId)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        Task {
            try? await notificationCenter.add(request)
            print("🎉 [SESSION_NOTIFICATIONS] Session completed notification sent for: \(sessionTitle)")
        }
    }
    
    func notifyAppAttempted(appName: String, sessionTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "app_blocked")
        content.body = String(localized: "app_blocked_during_session", defaultValue: "\(appName) is blocked during your focus session. Stay on track!", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: appName)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("block.wav"))
        content.userInfo = [
            "type": "app_blocked",
            "appName": appName,
            "sessionTitle": sessionTitle
        ]
        
        let request = UNNotificationRequest(
            identifier: "app_blocked_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        
        Task {
            try? await notificationCenter.add(request)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveScheduledNotifications() {
        if let encoded = try? JSONEncoder().encode(scheduledNotifications) {
            userDefaults.set(encoded, forKey: scheduledNotificationsKey)
        }
    }
    
    private func loadScheduledNotifications() {
        if let data = userDefaults.data(forKey: scheduledNotificationsKey),
           let decoded = try? JSONDecoder().decode([ScheduledNotification].self, from: data) {
            scheduledNotifications = decoded
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupExpiredNotifications() async {
        let now = Date()
        let activeNotifications = scheduledNotifications.filter { notification in
            // Garder les notifications qui ne sont pas encore expirées
            let sessionEndTime = notification.scheduledFor.addingTimeInterval(notification.duration + 3600) // +1h de marge
            return sessionEndTime > now && notification.isActive
        }
        
        if activeNotifications.count != scheduledNotifications.count {
            scheduledNotifications = activeNotifications
            saveScheduledNotifications()
            print("🧹 [SESSION_NOTIFICATIONS] Cleaned up expired notifications")
        }
    }
    
    // MARK: - Daily Tips & Motivational Reminders
    
    func scheduleDailyTips() {
        guard notificationPermissionStatus == .authorized else { return }
        
        // Programmer un tip quotidien à 9h du matin
        let calendar = Calendar.current
        guard let tomorrow9AM = calendar.nextDate(after: Date(), 
                                                 matching: DateComponents(hour: 9, minute: 0), 
                                                 matchingPolicy: .nextTime) else { return }
        
        let tipContent = generateRandomTipContent()
        
        let content = UNMutableNotificationContent()
        content.title = "💡 " + String(localized: "daily_wellness_tip")
        content.body = tipContent.message
        content.sound = .default
        content.categoryIdentifier = "DAILY_TIP"
        content.userInfo = [
            "type": "daily_tip",
            "tip_id": tipContent.id
        ]
        
        // Programmer avec répétition quotidienne
        let dateComponents = calendar.dateComponents([.hour, .minute], from: tomorrow9AM)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_tip_9am",
            content: content,
            trigger: trigger
        )
        
        Task {
            try? await notificationCenter.add(request)
            print("💡 [SESSION_NOTIFICATIONS] Daily tips scheduled for 9AM")
        }
    }
    
    func scheduleMotivationalReminders() {
        guard notificationPermissionStatus == .authorized else { return }
        
        // Programmer des rappels motivationnels à des moments stratégiques
        let reminderTimes = [
            (hour: 14, minute: 0), // 14h - après-midi
            (hour: 20, minute: 0)  // 20h - soirée
        ]
        
        for time in reminderTimes {
            let calendar = Calendar.current
            guard let nextTime = calendar.nextDate(after: Date(),
                                                  matching: DateComponents(hour: time.hour, minute: time.minute),
                                                  matchingPolicy: .nextTime) else { continue }
            
            let motivationContent = generateMotivationalReminderContent()
            
            let content = UNMutableNotificationContent()
            content.title = "🌟 " + String(localized: "stay_motivated")
            content.body = motivationContent
            content.sound = .default
            content.categoryIdentifier = "MOTIVATION_REMINDER"
            content.userInfo = [
                "type": "motivational_reminder",
                "time_slot": "\(time.hour)h"
            ]
            
            let dateComponents = calendar.dateComponents([.hour, .minute], from: nextTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "motivation_reminder_\(time.hour)h",
                content: content,
                trigger: trigger
            )
            
            Task {
                try? await notificationCenter.add(request)
            }
        }
        
        print("🌟 [SESSION_NOTIFICATIONS] Motivational reminders scheduled")
    }
    
    func scheduleWeeklyEncouragement() {
        guard notificationPermissionStatus == .authorized else { return }
        
        // Notification d'encouragement le dimanche soir pour préparer la semaine
        let calendar = Calendar.current
        guard let nextSunday = calendar.nextDate(after: Date(),
                                               matching: DateComponents(hour: 18, minute: 0, weekday: 1),
                                               matchingPolicy: .nextTime) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 " + String(localized: "weekly_preparation")
        content.body = String(localized: "prepare_for_productive_week")
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_ENCOURAGEMENT"
        content.userInfo = ["type": "weekly_encouragement"]
        
        let dateComponents = calendar.dateComponents([.weekday, .hour, .minute], from: nextSunday)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_encouragement_sunday",
            content: content,
            trigger: trigger
        )
        
        Task {
            try? await notificationCenter.add(request)
            print("🎯 [SESSION_NOTIFICATIONS] Weekly encouragement scheduled for Sundays")
        }
    }
    
    private func generateRandomTipContent() -> (id: String, message: String) {
        let tips = [
            "take_regular_breaks_tip",
            "single_tasking_tip", 
            "notification_silence_tip",
            "morning_routine_tip",
            "deep_work_blocks_tip"
        ]
        
        let randomTip = tips.randomElement() ?? tips[0]
        let message = String(localized: LocalizedStringResource(stringLiteral: randomTip))
        
        return (id: randomTip, message: message)
    }
    
    private func generateMotivationalReminderContent() -> String {
        let motivations = [
            "small_steps_big_impact",
            "consistency_beats_intensity", 
            "focus_is_superpower",
            "digital_wellness_journey",
            "proud_of_progress"
        ]
        
        let randomMotivation = motivations.randomElement() ?? motivations[0]
        return String(localized: LocalizedStringResource(stringLiteral: randomMotivation))
    }
    
    // MARK: - Debugging
    
    func debugScheduledNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let delivered = await notificationCenter.deliveredNotifications()
        
        print("📋 [SESSION_NOTIFICATIONS] ========== DEBUG INFO ==========")
        print("  - Permission status: \(notificationPermissionStatus)")
        print("  - Scheduled sessions: \(scheduledNotifications.count)")
        print("  - Pending system notifications: \(pending.count)")
        print("  - Delivered notifications: \(delivered.count)")
        
        print("📅 [SESSION_NOTIFICATIONS] Scheduled Sessions:")
        for notification in scheduledNotifications {
            let timeUntil = notification.scheduledFor.timeIntervalSinceNow
            let status = timeUntil > 0 ? "in \(Int(timeUntil/60))min" : "expired"
            print("  - \(notification.title) at \(notification.scheduledFor) (\(status), active: \(notification.isActive))")
        }
        
        print("⏰ [SESSION_NOTIFICATIONS] Pending System Notifications:")
        for request in pending {
            let type = request.content.userInfo["type"] as? String ?? "unknown"
            print("  - \(request.identifier): \(type) - \(request.content.title)")
        }
        
        print("📋 [SESSION_NOTIFICATIONS] ==============================")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SessionNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        // Si c'est une notification de fin de session, traiter immédiatement
        if let type = userInfo["type"] as? String,
           (type == "session_end" || type == "complete_session") {
            print("⏰ [SESSION_NOTIFICATIONS] Session end notification will present - triggering completion")
            await MainActor.run {
                ZenloopManager.shared.challengeStateManager.checkAndCompleteExpiredSession()
            }
        }

        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            await handleNotificationAction(userInfo: userInfo, actionIdentifier: response.actionIdentifier)
        }

        completionHandler()
    }
    
    private func handleNotificationAction(userInfo: [AnyHashable: Any], actionIdentifier: String) async {
        guard let type = userInfo["type"] as? String else { return }

        print("🔔 [SESSION_NOTIFICATIONS] Handling notification action: \(actionIdentifier) for type: \(type)")

        switch type {
        case "session_start":
            if let sessionId = userInfo["sessionId"] as? String {
                // Notifier l'app de démarrer la session
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .startScheduledSession,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
                print("🚀 [SESSION_NOTIFICATIONS] Session start notification sent for: \(sessionId)")
            }

        case "session_end", "complete_session":
            // CRUCIAL: Compléter la session immédiatement quand la notification arrive
            print("⏰ [SESSION_NOTIFICATIONS] Session end notification received - checking for expired session")
            await MainActor.run {
                ZenloopManager.shared.challengeStateManager.checkAndCompleteExpiredSession()
            }

        case "session_reminder":
            if actionIdentifier == "POSTPONE_SESSION" {
                // Reporter la session de 5 minutes
                if let sessionId = userInfo["sessionId"] as? String {
                    postponeSession(sessionId: sessionId, by: 300) // 5 minutes
                }
            }

        case "app_blocked":
            // Envoyer feedback haptique et encouragement
            #if canImport(UIKit)
            await MainActor.run {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            #endif

        case "daily_tip", "motivational_reminder", "weekly_encouragement":
            print("💫 [SESSION_NOTIFICATIONS] Wellness notification received: \(type)")

        default:
            print("⚠️ [SESSION_NOTIFICATIONS] Unknown notification type: \(type)")
        }
    }
    
    private func postponeSession(sessionId: String, by timeInterval: TimeInterval) {
        guard let index = scheduledNotifications.firstIndex(where: { $0.id == sessionId }) else {
            return
        }
        
        let newStartTime = scheduledNotifications[index].scheduledFor.addingTimeInterval(timeInterval)
        rescheduleSession(sessionId: sessionId, newStartTime: newStartTime)
        
        print("⏰ [SESSION_NOTIFICATIONS] Session \(sessionId) postponed by \(Int(timeInterval/60)) minutes")
    }
}

// MARK: - Supporting Data Structures

struct ScheduledNotification: Codable {
    let id: String
    let type: SessionNotificationType
    let title: String
    var scheduledFor: Date
    var duration: TimeInterval
    let apps: [String]
    var isActive: Bool
}

struct NotificationInfo {
    let id: String
    let title: String
    let content: UNMutableNotificationContent
    let scheduledTime: Date
    let request: UNNotificationRequest
}

enum SessionNotificationType: String, Codable, CaseIterable {
    case sessionReminder = "session_reminder"
    case sessionStart = "session_start" 
    case sessionProgress = "session_progress"
    case sessionEnd = "session_end"
    case appBlocked = "app_blocked"
    case dailyTip = "daily_tip"
    case motivationalReminder = "motivational_reminder"
}

enum NotificationSoundType {
    case `default`
    case gentle
    case critical
    case success
    
    var unSound: UNNotificationSound {
        switch self {
        case .default:
            return .default
        case .gentle:
            return UNNotificationSound(named: UNNotificationSoundName("gentle.wav"))
        case .critical:
            return .defaultCritical
        case .success:
            return UNNotificationSound(named: UNNotificationSoundName("success.wav"))
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startScheduledSession = Notification.Name("startScheduledSession")
}