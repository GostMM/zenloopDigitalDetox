//
//  ScheduledSessionCoordinator.swift
//  zenloop
//
//  Gère les sessions programmées avec démarrage/arrêt automatique via DeviceActivity
//
//  ✅ FIX: Écrit le SelectionPayload pour que le Monitor puisse appliquer le shield
//  ✅ FIX: Écrit aussi dans le DEFAULT store mapping pour le déblocage
//  ✅ NEW: checkPendingActions() pour traiter les signaux App Group du Monitor
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications
import os.log

private let scheduledLogger = Logger(subsystem: "com.app.zenloop", category: "ScheduledSession")

@MainActor
class ScheduledSessionCoordinator {
    static let shared = ScheduledSessionCoordinator()

    private let center = DeviceActivityCenter()
    private let appGroup = UserDefaults(suiteName: "group.com.app.zenloop")!

    private init() {
        scheduledLogger.info("✅ ScheduledSessionCoordinator initialized")
    }

    // MARK: - Schedule Session

    /// Planifie une session avec démarrage et arrêt automatiques
    func scheduleSession(
        sessionId: String,
        startTime: Date,
        endTime: Date,
        apps: FamilyActivitySelection
    ) async throws {
        scheduledLogger.critical("📅 Scheduling session: \(sessionId)")
        scheduledLogger.info("⏰ Start: \(startTime.formatted())")
        scheduledLogger.info("⏰ End: \(endTime.formatted())")

        // Vérifier que les dates sont valides
        guard startTime < endTime else {
            scheduledLogger.error("❌ Invalid dates: start must be before end")
            throw ScheduledSessionError.invalidDates
        }

        guard startTime > Date() else {
            scheduledLogger.error("❌ Start time must be in the future")
            throw ScheduledSessionError.startTimeInPast
        }

        // Créer le nom d'activité unique
        let activityName = DeviceActivityName("scheduled_session_\(sessionId)")

        // ──────────────────────────────────────────────────────────────
        // ✅ FIX 1: Sauvegarder le SelectionPayload pour le Monitor
        // Le Monitor cherche la clé "payload_<activityName>" pour appliquer le shield.
        // Sans cette clé, applyShield() ne trouvait rien et le blocage ne se faisait pas.
        // ──────────────────────────────────────────────────────────────
        let payload = SelectionPayload(
            sessionId: sessionId,
            apps: Array(apps.applicationTokens),
            categories: Array(apps.categoryTokens),
            restrictionMode: .shield
        )

        if let payloadData = try? JSONEncoder().encode(payload) {
            let payloadKey = "payload_scheduled_session_\(sessionId)"
            appGroup.set(payloadData, forKey: payloadKey)
            scheduledLogger.info("✅ SelectionPayload saved under key: \(payloadKey)")
        } else {
            scheduledLogger.error("❌ Failed to encode SelectionPayload")
        }

        // Sauvegarder les infos dans App Group pour le Monitor
        let scheduledInfo = ScheduledSessionInfo(
            sessionId: sessionId,
            startTime: startTime,
            endTime: endTime,
            status: .scheduled
        )

        if let data = try? JSONEncoder().encode(scheduledInfo) {
            appGroup.set(data, forKey: "scheduled_session_\(sessionId)")
            appGroup.synchronize()
        }

        // Sauvegarder les apps sélectionnées (encodées) — backup complet
        if let selectionData = try? JSONEncoder().encode(apps) {
            appGroup.set(selectionData, forKey: "scheduled_session_apps_\(sessionId)")
            appGroup.synchronize()
        }

        // Créer le schedule DeviceActivity
        let startComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: startTime
        )
        let endComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: endTime
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        // Démarrer le monitoring
        do {
            try center.startMonitoring(activityName, during: schedule)
            scheduledLogger.info("✅ DeviceActivity monitoring started for \(sessionId)")

            // Enregistrer l'activité active
            var activeSchedules = appGroup.stringArray(forKey: "active_scheduled_sessions") ?? []
            if !activeSchedules.contains(sessionId) {
                activeSchedules.append(sessionId)
                appGroup.set(activeSchedules, forKey: "active_scheduled_sessions")
                appGroup.synchronize()
            }

            // ✅ NEW: Programmer les notifications push
            await scheduleNotifications(sessionId: sessionId, startTime: startTime, endTime: endTime)

        } catch {
            scheduledLogger.error("❌ Failed to start monitoring: \(error.localizedDescription)")
            // Nettoyer les données sauvegardées en cas d'échec
            cleanupSessionData(sessionId: sessionId)
            throw error
        }
    }

    // MARK: - Notifications

    /// Programme les notifications pour une session programmée
    private func scheduleNotifications(sessionId: String, startTime: Date, endTime: Date) async {
        let notificationCenter = UNUserNotificationCenter.current()

        // Vérifier les permissions
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            scheduledLogger.warning("⚠️ Notifications not authorized, skipping")
            return
        }

        scheduledLogger.info("📲 Scheduling notifications for session \(sessionId)")

        // 1. Notification 15 minutes avant le début
        if startTime.timeIntervalSinceNow > 900 { // Plus de 15 min
            scheduleNotification(
                identifier: "\(sessionId)_15min",
                title: String(localized: "scheduled_session_reminder"),
                body: String(localized: "session_starts_in_15_minutes"),
                triggerDate: startTime.addingTimeInterval(-900),
                sessionId: sessionId
            )
        }

        // 2. Notification 5 minutes avant le début
        if startTime.timeIntervalSinceNow > 300 { // Plus de 5 min
            scheduleNotification(
                identifier: "\(sessionId)_5min",
                title: String(localized: "scheduled_session_reminder"),
                body: String(localized: "session_starts_in_5_minutes"),
                triggerDate: startTime.addingTimeInterval(-300),
                sessionId: sessionId
            )
        }

        // 3. Notification au démarrage
        scheduleNotification(
            identifier: "\(sessionId)_start",
            title: String(localized: "session_started"),
            body: String(localized: "your_scheduled_session_has_started"),
            triggerDate: startTime,
            sessionId: sessionId
        )

        // 4. Notification à la fin
        scheduleNotification(
            identifier: "\(sessionId)_end",
            title: String(localized: "session_completed"),
            body: String(localized: "your_scheduled_session_has_ended"),
            triggerDate: endTime,
            sessionId: sessionId
        )

        scheduledLogger.info("✅ Notifications scheduled for session \(sessionId)")
    }

    /// Programme une notification individuelle
    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        triggerDate: Date,
        sessionId: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SCHEDULED_SESSION"
        content.userInfo = [
            "sessionId": sessionId,
            "type": "scheduled_session"
        ]

        // Calculer le trigger
        let timeInterval = triggerDate.timeIntervalSinceNow
        guard timeInterval > 0 else {
            scheduledLogger.warning("⚠️ Notification \(identifier) is in the past, skipping")
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                scheduledLogger.error("❌ Failed to schedule notification \(identifier): \(error.localizedDescription)")
            } else {
                scheduledLogger.info("✅ Notification scheduled: \(identifier) at \(triggerDate.formatted())")
            }
        }
    }

    /// Annule toutes les notifications d'une session programmée
    private func cancelNotifications(sessionId: String) {
        let identifiers = [
            "\(sessionId)_15min",
            "\(sessionId)_5min",
            "\(sessionId)_start",
            "\(sessionId)_end"
        ]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        scheduledLogger.info("🔕 Cancelled notifications for session \(sessionId)")
    }

    // MARK: - Cancel Scheduled Session

    /// Annule une session programmée
    func cancelScheduledSession(sessionId: String) {
        scheduledLogger.info("🚫 Cancelling scheduled session: \(sessionId)")

        let activityName = DeviceActivityName("scheduled_session_\(sessionId)")
        center.stopMonitoring([activityName])

        // Annuler les notifications
        cancelNotifications(sessionId: sessionId)

        cleanupSessionData(sessionId: sessionId)

        scheduledLogger.info("✅ Scheduled session cancelled")
    }

    // MARK: - ✅ NEW: Check Pending Actions from Monitor

    /// Vérifie si le DeviceActivityMonitor a signalé un démarrage ou arrêt automatique.
    /// Doit être appelé depuis ScenePhase .active, applicationDidBecomeActive, ou un timer.
    func checkPendingActions() async {
        scheduledLogger.info("🔍 Checking pending scheduled session actions...")

        // ── Auto-Start ──
        if let sessionId = appGroup.string(forKey: "auto_start_session_id") {
            let timestamp = appGroup.double(forKey: "auto_start_session_timestamp")
            let age = Date().timeIntervalSince1970 - timestamp

            scheduledLogger.critical("🚀 Found pending auto-start for session: \(sessionId) (age: \(Int(age))s)")

            // Toujours nettoyer le signal AVANT de traiter (évite les doubles exécutions)
            appGroup.removeObject(forKey: "auto_start_session_id")
            appGroup.removeObject(forKey: "auto_start_session_timestamp")
            appGroup.synchronize()

            // Ignorer si le signal est trop vieux (> 30 minutes)
            if age < 1800 {
                do {
                    try await SessionManager.shared.startSession(sessionId: sessionId)
                    scheduledLogger.info("✅ Scheduled session auto-started via Firebase: \(sessionId)")
                } catch {
                    // Si l'erreur est "pas le bon état", la session est peut-être déjà active
                    // (le Monitor a pu la démarrer ou un autre appareil l'a fait)
                    scheduledLogger.error("❌ Failed to auto-start session: \(error.localizedDescription)")
                }

                // ✅ CRUCIAL: Redémarrer le listener pour que l'UI se mette à jour
                // Même si startSession a échoué (session déjà active), on veut le listener
                SessionManager.shared.startSessionListener(sessionId: sessionId)
                scheduledLogger.info("🔄 Session listener restarted for: \(sessionId)")
            } else {
                scheduledLogger.warning("⚠️ Auto-start signal too old (\(Int(age))s), ignoring")
            }
        }

        // ── Auto-Stop ──
        if let sessionId = appGroup.string(forKey: "auto_stop_session_id") {
            let timestamp = appGroup.double(forKey: "auto_stop_session_timestamp")
            let age = Date().timeIntervalSince1970 - timestamp

            scheduledLogger.critical("🛑 Found pending auto-stop for session: \(sessionId) (age: \(Int(age))s)")

            // Toujours nettoyer le signal AVANT de traiter
            appGroup.removeObject(forKey: "auto_stop_session_id")
            appGroup.removeObject(forKey: "auto_stop_session_timestamp")
            appGroup.synchronize()

            if age < 1800 {
                do {
                    try await SessionManager.shared.stopSession(sessionId: sessionId)
                    scheduledLogger.info("✅ Scheduled session auto-stopped via Firebase: \(sessionId)")
                } catch {
                    scheduledLogger.error("❌ Failed to auto-stop session: \(error.localizedDescription)")
                }

                // ✅ Redémarrer le listener pour que l'UI voie le status "completed"
                SessionManager.shared.startSessionListener(sessionId: sessionId)
            } else {
                scheduledLogger.warning("⚠️ Auto-stop signal too old (\(Int(age))s), ignoring")
            }

            // Nettoyer la session programmée
            cleanupSessionData(sessionId: sessionId)
        }

        // ── Vérification supplémentaire: session déjà démarrée par le Monitor ──
        // Si le Monitor a déjà mis à jour le status dans App Group mais le signal
        // a été nettoyé, vérifier quand même les sessions programmées actives
        await checkForAlreadyStartedSessions()
    }

    /// Vérifie si des sessions programmées sont marquées comme "started" dans App Group
    /// mais que l'app n'a pas encore traité (cas où le signal a été perdu)
    private func checkForAlreadyStartedSessions() async {
        let activeSessionIds = getActiveScheduledSessions()

        for sessionId in activeSessionIds {
            guard let info = getScheduledSessionInfo(sessionId: sessionId) else { continue }

            switch info.status {
            case .started:
                // La session a été démarrée par le Monitor — vérifier Firebase
                scheduledLogger.info("🔍 Found already-started scheduled session: \(sessionId)")

                // S'assurer que le listener est actif
                if SessionManager.shared.currentSession?.id != sessionId {
                    SessionManager.shared.startSessionListener(sessionId: sessionId)
                    scheduledLogger.info("🔄 Reconnected listener for started session: \(sessionId)")
                }

            case .completed:
                // Session terminée par le Monitor — s'assurer que Firebase est à jour
                scheduledLogger.info("🔍 Found completed scheduled session: \(sessionId)")
                do {
                    try await SessionManager.shared.stopSession(sessionId: sessionId)
                } catch {
                    // Peut échouer si déjà stoppée — c'est OK
                    scheduledLogger.info("ℹ️ Session \(sessionId) already stopped or error: \(error.localizedDescription)")
                }
                cleanupSessionData(sessionId: sessionId)

            default:
                break
            }
        }
    }

    // MARK: - Get Active Scheduled Sessions

    /// Récupère la liste des sessions programmées actives
    func getActiveScheduledSessions() -> [String] {
        return appGroup.stringArray(forKey: "active_scheduled_sessions") ?? []
    }

    // MARK: - Session Info

    /// Récupère les infos d'une session programmée
    func getScheduledSessionInfo(sessionId: String) -> ScheduledSessionInfo? {
        guard let data = appGroup.data(forKey: "scheduled_session_\(sessionId)"),
              let info = try? JSONDecoder().decode(ScheduledSessionInfo.self, from: data) else {
            return nil
        }
        return info
    }

    // MARK: - Private Helpers

    /// Nettoie toutes les données App Group liées à une session programmée
    private func cleanupSessionData(sessionId: String) {
        appGroup.removeObject(forKey: "scheduled_session_\(sessionId)")
        appGroup.removeObject(forKey: "scheduled_session_apps_\(sessionId)")
        appGroup.removeObject(forKey: "payload_scheduled_session_\(sessionId)")
        appGroup.removeObject(forKey: "auto_start_session_id")
        appGroup.removeObject(forKey: "auto_start_session_timestamp")
        appGroup.removeObject(forKey: "auto_stop_session_id")
        appGroup.removeObject(forKey: "auto_stop_session_timestamp")

        var activeSchedules = appGroup.stringArray(forKey: "active_scheduled_sessions") ?? []
        activeSchedules.removeAll { $0 == sessionId }
        appGroup.set(activeSchedules, forKey: "active_scheduled_sessions")
        appGroup.synchronize()
    }
}

// MARK: - Models

struct ScheduledSessionInfo: Codable {
    let sessionId: String
    let startTime: Date
    let endTime: Date
    var status: ScheduledSessionStatus
    var actualStartTime: Date?
    var actualEndTime: Date?
}

enum ScheduledSessionStatus: String, Codable {
    case scheduled  // Planifiée, en attente
    case started    // Démarrée automatiquement
    case completed  // Terminée automatiquement
    case cancelled  // Annulée manuellement
}

enum ScheduledSessionError: LocalizedError {
    case invalidDates
    case startTimeInPast
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidDates:
            return "La date de début doit être avant la date de fin"
        case .startTimeInPast:
            return "La date de début doit être dans le futur"
        case .sessionNotFound:
            return "Session programmée introuvable"
        }
    }
}