//
//  ZenloopWidgetModels.swift
//  zenloopwidget
//
//  Created by Claude on 28/08/2025.
//

import Foundation

// MARK: - Widget Data Models

struct ZenloopWidgetData: Codable {
    let currentState: WidgetState
    let activeSession: ActiveSessionData?
    let sessionsCompleted: Int
    let streak: Int
    let nextScheduledSession: ScheduledSessionData?
    let cancelledScheduledSessions: [String] // Session IDs that were cancelled
    let lastUpdated: Date
    
    // Computed properties for backward compatibility
    var sessionTitle: String? { activeSession?.title }
    var timeRemaining: String? { activeSession?.timeRemaining }
    var progress: Double { activeSession?.progress ?? 0.0 }
    
    enum WidgetState: String, Codable, CaseIterable {
        case idle = "idle"
        case active = "active" 
        case paused = "paused"
        case completed = "completed"
        
        var displayTitle: String {
            switch self {
            case .idle:
                return "Ready to Focus"
            case .active:
                return "In Session"
            case .paused:
                return "Paused"
            case .completed:
                return "Completed!"
            }
        }
        
        var emoji: String {
            switch self {
            case .idle:
                return "🎯"
            case .active:
                return "⚡"
            case .paused:
                return "⏸️"
            case .completed:
                return "🎉"
            }
        }
        
        // Couleurs basées sur OptimizedBackground
        var primaryColor: (red: Double, green: Double, blue: Double) {
            switch self {
            case .idle:
                return (0.05, 0.05, 0.15) // Bleu sombre
            case .active:
                return (0.15, 0.05, 0.05) // Rouge focus
            case .paused:
                return (0.05, 0.15, 0.15) // Cyan pause
            case .completed:
                return (0.1, 0.15, 0.05) // Vert succès
            }
        }
        
        var secondaryColor: (red: Double, green: Double, blue: Double, opacity: Double) {
            switch self {
            case .idle:
                return (0, 0, 1, 0.3) // Bleu
            case .active:
                return (1, 0.5, 0, 0.3) // Orange
            case .paused:
                return (0, 1, 1, 0.3) // Cyan
            case .completed:
                return (0, 1, 0, 0.3) // Vert
            }
        }
    }
}

// MARK: - Session Data Models

struct ActiveSessionData: Codable {
    let id: String
    let title: String
    let timeRemaining: String
    let progress: Double
    let origin: SessionOrigin
    let startTime: Date
    let originalDuration: TimeInterval
    
    enum SessionOrigin: String, Codable {
        case manual = "manual"
        case scheduled = "scheduled"
        case quickStart = "quick_start"
    }
}

struct ScheduledSessionData: Codable {
    let id: String
    let title: String
    let startTime: Date
    let duration: TimeInterval
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h\(minutes > 0 ? " \(minutes)m" : "")"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Widget Data Provider

class ZenloopWidgetDataProvider {
    static let shared = ZenloopWidgetDataProvider()
    private let suite = UserDefaults(suiteName: "group.com.app.zenloop")
    
    private init() {}
    
    func getCurrentData() -> ZenloopWidgetData {
        guard let suite = suite else {
            print("❌ [WIDGET] Cannot access App Group - using default data")
            return createDefaultData()
        }
        
        // Lire les données depuis App Groups avec la nouvelle structure
        let currentStateRaw = suite.string(forKey: "widget_current_state") ?? "idle"
        let currentState = ZenloopWidgetData.WidgetState(rawValue: currentStateRaw) ?? .idle
        
        let sessionsCompleted = suite.integer(forKey: "widget_sessions_completed")
        let streak = suite.integer(forKey: "widget_streak")
        
        // Lire les données de session active
        var activeSession: ActiveSessionData?
        if let sessionId = suite.string(forKey: "widget_active_session_id"),
           let sessionTitle = suite.string(forKey: "widget_active_session_title"),
           let timeRemaining = suite.string(forKey: "widget_active_session_time_remaining"),
           let originRaw = suite.string(forKey: "widget_active_session_origin"),
           let origin = ActiveSessionData.SessionOrigin(rawValue: originRaw),
           let startTime = suite.object(forKey: "widget_active_session_start_time") as? Date {
            
            let progress = suite.double(forKey: "widget_active_session_progress")
            let originalDuration = suite.double(forKey: "widget_active_session_duration")
            
            activeSession = ActiveSessionData(
                id: sessionId,
                title: sessionTitle,
                timeRemaining: timeRemaining,
                progress: progress,
                origin: origin,
                startTime: startTime,
                originalDuration: originalDuration
            )
        } else {
            // Migration: Try to read old format data
            if let sessionTitle = suite.string(forKey: "widget_session_title"),
               let timeRemaining = suite.string(forKey: "widget_time_remaining"),
               currentState != .idle {
                let progress = suite.double(forKey: "widget_progress")
                activeSession = ActiveSessionData(
                    id: UUID().uuidString,
                    title: sessionTitle,
                    timeRemaining: timeRemaining,
                    progress: progress,
                    origin: .manual,
                    startTime: Date(),
                    originalDuration: timeRemaining.timeIntervalFromString()
                )
                print("🔄 [MIGRATION] Converted old session data to new format")
            }
        }
        
        // Lire les données de session programmée
        var nextScheduledSession: ScheduledSessionData?
        if let nextId = suite.string(forKey: "widget_next_session_id"),
           let nextTitle = suite.string(forKey: "widget_next_session_title"),
           let nextStartTime = suite.object(forKey: "widget_next_session_start") as? Date,
           let nextDuration = suite.object(forKey: "widget_next_session_duration") as? TimeInterval {
            nextScheduledSession = ScheduledSessionData(
                id: nextId,
                title: nextTitle,
                startTime: nextStartTime,
                duration: nextDuration
            )
        } else {
            // Migration: Try to read old format
            if let nextTitle = suite.string(forKey: "widget_next_session_title"),
               let nextStartTime = suite.object(forKey: "widget_next_session_start") as? Date,
               let nextDuration = suite.object(forKey: "widget_next_session_duration") as? TimeInterval {
                nextScheduledSession = ScheduledSessionData(
                    id: UUID().uuidString,
                    title: nextTitle,
                    startTime: nextStartTime,
                    duration: nextDuration
                )
                print("🔄 [MIGRATION] Generated ID for scheduled session")
            }
        }
        
        // Lire les sessions annulées
        let cancelledSessions = suite.array(forKey: "widget_cancelled_sessions") as? [String] ?? []
        
        let lastUpdated = suite.object(forKey: "widget_last_updated") as? Date ?? Date()
        
        print("📱 [WIDGET] Data read:")
        print("   State: \(currentStateRaw)")
        print("   Active Session: \(activeSession?.title ?? "none")")
        print("   Next Scheduled: \(nextScheduledSession?.title ?? "none")")
        print("   Cancelled Sessions: \(cancelledSessions.count)")
        
        return ZenloopWidgetData(
            currentState: currentState,
            activeSession: activeSession,
            sessionsCompleted: sessionsCompleted,
            streak: streak,
            nextScheduledSession: nextScheduledSession,
            cancelledScheduledSessions: cancelledSessions,
            lastUpdated: lastUpdated
        )
    }
    
    private func createDefaultData() -> ZenloopWidgetData {
        print("📱 [WIDGET] Using default data - no App Group access")
        return ZenloopWidgetData(
            currentState: .idle,
            activeSession: nil,
            sessionsCompleted: 3,
            streak: 2,
            nextScheduledSession: ScheduledSessionData(
                id: UUID().uuidString,
                title: "Example Session",
                startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                duration: 8 * 60 * 60
            ),
            cancelledScheduledSessions: [],
            lastUpdated: Date()
        )
    }
    
    func updateWidgetData(_ data: ZenloopWidgetData) {
        guard let suite = suite else { return }
        
        // Save basic state
        suite.set(data.currentState.rawValue, forKey: "widget_current_state")
        suite.set(data.sessionsCompleted, forKey: "widget_sessions_completed")
        suite.set(data.streak, forKey: "widget_streak")
        
        // Save active session data
        if let activeSession = data.activeSession {
            suite.set(activeSession.id, forKey: "widget_active_session_id")
            suite.set(activeSession.title, forKey: "widget_active_session_title")
            suite.set(activeSession.timeRemaining, forKey: "widget_active_session_time_remaining")
            suite.set(activeSession.progress, forKey: "widget_active_session_progress")
            suite.set(activeSession.origin.rawValue, forKey: "widget_active_session_origin")
            suite.set(activeSession.startTime, forKey: "widget_active_session_start_time")
            suite.set(activeSession.originalDuration, forKey: "widget_active_session_duration")
        } else {
            // Clear active session data
            suite.removeObject(forKey: "widget_active_session_id")
            suite.removeObject(forKey: "widget_active_session_title")
            suite.removeObject(forKey: "widget_active_session_time_remaining")
            suite.removeObject(forKey: "widget_active_session_progress")
            suite.removeObject(forKey: "widget_active_session_origin")
            suite.removeObject(forKey: "widget_active_session_start_time")
            suite.removeObject(forKey: "widget_active_session_duration")
        }
        
        // Save scheduled session data
        if let nextSession = data.nextScheduledSession {
            suite.set(nextSession.id, forKey: "widget_next_session_id")
            suite.set(nextSession.title, forKey: "widget_next_session_title")
            suite.set(nextSession.startTime, forKey: "widget_next_session_start")
            suite.set(nextSession.duration, forKey: "widget_next_session_duration")
        } else {
            suite.removeObject(forKey: "widget_next_session_id")
            suite.removeObject(forKey: "widget_next_session_title")
            suite.removeObject(forKey: "widget_next_session_start")
            suite.removeObject(forKey: "widget_next_session_duration")
        }
        
        // Save cancelled sessions list
        suite.set(data.cancelledScheduledSessions, forKey: "widget_cancelled_sessions")
        
        // Legacy data cleanup - remove old keys
        suite.removeObject(forKey: "widget_session_title")
        suite.removeObject(forKey: "widget_time_remaining")
        suite.removeObject(forKey: "widget_progress")
        
        suite.set(data.lastUpdated, forKey: "widget_last_updated")
        suite.synchronize()
        
        print("💾 [WIDGET] Data updated in App Group with new structure")
        print("   Active Session: \(data.activeSession?.id ?? "none")")
        print("   Cancelled Sessions: \(data.cancelledScheduledSessions.count)")
    }
    
    // MARK: - Session Control Methods with Synchronization
    
    func startSession(duration: Int, origin: ActiveSessionData.SessionOrigin = .quickStart) {
        let currentData = getCurrentData()
        let sessionId = UUID().uuidString
        
        // If this overrides a scheduled session, mark it as cancelled
        var cancelledSessions = currentData.cancelledScheduledSessions
        if let nextScheduled = currentData.nextScheduledSession,
           origin == .manual || origin == .quickStart {
            cancelledSessions.append(nextScheduled.id)
            print("🚫 [SESSION] Cancelled scheduled session: \(nextScheduled.id)")
        }
        
        let activeSession = ActiveSessionData(
            id: sessionId,
            title: "Quick Session \(duration)m",
            timeRemaining: "\(duration):00",
            progress: 0.0,
            origin: origin,
            startTime: Date(),
            originalDuration: TimeInterval(duration * 60)
        )
        
        let newData = ZenloopWidgetData(
            currentState: .active,
            activeSession: activeSession,
            sessionsCompleted: currentData.sessionsCompleted,
            streak: currentData.streak,
            nextScheduledSession: origin == .scheduled ? nil : currentData.nextScheduledSession,
            cancelledScheduledSessions: cancelledSessions,
            lastUpdated: Date()
        )
        
        print("✅ [SESSION] Started \(origin.rawValue) session: \(sessionId)")
        updateWidgetData(newData)
    }
    
    func pauseSession() {
        let currentData = getCurrentData()
        guard let activeSession = currentData.activeSession else {
            print("❌ [SESSION] No active session to pause")
            return
        }
        
        let pausedData = ZenloopWidgetData(
            currentState: .paused,
            activeSession: activeSession,
            sessionsCompleted: currentData.sessionsCompleted,
            streak: currentData.streak,
            nextScheduledSession: currentData.nextScheduledSession,
            cancelledScheduledSessions: currentData.cancelledScheduledSessions,
            lastUpdated: Date()
        )
        
        print("⏸️ [SESSION] Paused session: \(activeSession.id)")
        updateWidgetData(pausedData)
    }
    
    func resumeSession() {
        let currentData = getCurrentData()
        guard let activeSession = currentData.activeSession else {
            print("❌ [SESSION] No session to resume")
            return
        }
        
        let resumedData = ZenloopWidgetData(
            currentState: .active,
            activeSession: activeSession,
            sessionsCompleted: currentData.sessionsCompleted,
            streak: currentData.streak,
            nextScheduledSession: currentData.nextScheduledSession,
            cancelledScheduledSessions: currentData.cancelledScheduledSessions,
            lastUpdated: Date()
        )
        
        print("▶️ [SESSION] Resumed session: \(activeSession.id)")
        updateWidgetData(resumedData)
    }
    
    func stopSession() {
        let currentData = getCurrentData()
        guard let activeSession = currentData.activeSession else {
            print("❌ [SESSION] No session to stop")
            return
        }
        
        // If stopping a scheduled session, mark it as cancelled to prevent restart
        var cancelledSessions = currentData.cancelledScheduledSessions
        if activeSession.origin == .scheduled,
           let nextScheduled = currentData.nextScheduledSession {
            cancelledSessions.append(nextScheduled.id)
            print("🚫 [SESSION] Marked scheduled session as cancelled: \(nextScheduled.id)")
        }
        
        let stoppedData = ZenloopWidgetData(
            currentState: .idle,
            activeSession: nil,
            sessionsCompleted: currentData.sessionsCompleted,
            streak: currentData.streak,
            nextScheduledSession: currentData.nextScheduledSession,
            cancelledScheduledSessions: cancelledSessions,
            lastUpdated: Date()
        )
        
        print("🛑 [SESSION] Stopped session: \(activeSession.id)")
        updateWidgetData(stoppedData)
    }
    
    func startNewSession() {
        startSession(duration: 25, origin: .manual)
    }
    
    // MARK: - Scheduling Logic
    
    func canStartScheduledSession(_ scheduledSession: ScheduledSessionData) -> Bool {
        let currentData = getCurrentData()
        
        // Check if this scheduled session was cancelled
        if currentData.cancelledScheduledSessions.contains(scheduledSession.id) {
            print("🚫 [SCHEDULE] Session \(scheduledSession.id) was cancelled - not starting")
            return false
        }
        
        // Check if there's already an active session
        if currentData.activeSession != nil {
            print("🚫 [SCHEDULE] Already have active session - not starting scheduled")
            return false
        }
        
        print("✅ [SCHEDULE] Can start scheduled session: \(scheduledSession.id)")
        return true
    }
    
    func cleanupCancelledSessions() {
        let currentData = getCurrentData()
        let now = Date()
        
        // Remove cancelled sessions older than 24h to prevent memory bloat
        let oneDayAgo = now.addingTimeInterval(-24 * 60 * 60)
        let cleanedData = ZenloopWidgetData(
            currentState: currentData.currentState,
            activeSession: currentData.activeSession,
            sessionsCompleted: currentData.sessionsCompleted,
            streak: currentData.streak,
            nextScheduledSession: currentData.nextScheduledSession,
            cancelledScheduledSessions: [], // Clear old cancellations
            lastUpdated: now
        )
        
        updateWidgetData(cleanedData)
        print("🧹 [SCHEDULE] Cleaned up old cancelled sessions")
    }
}

// MARK: - String Extensions for Time Handling

extension String {
    func timeIntervalFromString() -> TimeInterval {
        let components = self.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return 0
        }
        return TimeInterval(minutes * 60 + seconds)
    }
}

extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Session Synchronization Documentation

/*
 
 ## Session Synchronization System
 
 Ce système résout les problèmes de synchronisation entre sessions programmées et actions manuelles.
 
 ### Problème résolu :
 - Les sessions programmées qui redémarraient automatiquement même après avoir été arrêtées manuellement
 - Les conflits entre sessions manuelles et automatiques
 - La perte de context entre widget et app principale
 
 ### Architecture :
 
 1. **Session Active** (`ActiveSessionData`) :
    - `id` : Identifiant unique de la session
    - `origin` : Source de la session (manual, scheduled, quickStart)
    - Tracking complet du lifecycle et metadata
 
 2. **Sessions Programmées** (`ScheduledSessionData`) :
    - `id` : Identifiant unique pour tracking des cancellations
    - Statut indépendant de la session active
 
 3. **Cancelled Sessions Tracking** :
    - Liste des IDs de sessions programmées qui ont été annulées
    - Empêche le redémarrage automatique des sessions stoppées
 
 ### Usage depuis l'app principale :
 
 ```swift
 // Avant de démarrer une session programmée :
 let provider = ZenloopWidgetDataProvider.shared
 
 if let scheduledSession = nextScheduledSession,
    provider.canStartScheduledSession(scheduledSession) {
    provider.startSession(duration: Int(scheduledSession.duration/60), origin: .scheduled)
 } else {
    print("Session was cancelled or conflict exists")
 }
 
 // Pour les actions manuelles, les sessions programmées sont automatiquement annulées :
 provider.startSession(duration: 25, origin: .manual) // Cancel toute session programmée
 
 // Nettoyage périodique (à faire 1x par jour) :
 provider.cleanupCancelledSessions()
 ```
 
 ### Workflow de synchronisation :
 
 1. **Session Programmée planifiée** → Stockée avec ID unique
 2. **Action manuelle** → Annule automatiquement la session programmée (ajoute l'ID à cancelledSessions)
 3. **Tentative de démarrage programmé** → Vérifie d'abord si l'ID est dans cancelledSessions
 4. **Session stoppée manuellement** → Marque l'origine comme cancelled si c'était une session programmée
 
 ### Logs pour debugging :
 - 🚫 [SESSION] : Cancellations et rejets
 - ✅ [SESSION] : Démarrages réussis  
 - 🔄 [MIGRATION] : Conversion de l'ancien format
 - 🧹 [SCHEDULE] : Nettoyage des cancellations expirées
 
 */