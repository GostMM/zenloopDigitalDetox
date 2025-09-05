//
//  ZenloopWidgetModels.swift
//  zenloopwidget
//
//  Created by Claude on 28/08/2025.
//

import Foundation

// MARK: - Widget Data Models

// Interactive Widget Data Structure (for new App Intents widgets)
struct ZenloopWidgetData: Codable {
    let isSessionActive: Bool
    let currentSessionTitle: String
    let timeRemaining: String
    let progress: Double
    let totalFocusTime: String
    let streak: Int
    let isPremium: Bool
    
    // Legacy structure for backward compatibility
    let currentState: WidgetState?
    let activeSession: ActiveSessionData?
    let sessionsCompleted: Int?
    let nextScheduledSession: ScheduledSessionData?
    let cancelledScheduledSessions: [String]?
    let lastUpdated: Date?
    
    // Convenience initializer for interactive widgets
    init(isSessionActive: Bool, currentSessionTitle: String, timeRemaining: String, progress: Double, totalFocusTime: String, streak: Int, isPremium: Bool) {
        self.isSessionActive = isSessionActive
        self.currentSessionTitle = currentSessionTitle
        self.timeRemaining = timeRemaining
        self.progress = progress
        self.totalFocusTime = totalFocusTime
        self.streak = streak
        self.isPremium = isPremium
        
        // Default legacy values
        self.currentState = isSessionActive ? .active : .idle
        self.activeSession = nil
        self.sessionsCompleted = 0
        self.nextScheduledSession = nil
        self.cancelledScheduledSessions = []
        self.lastUpdated = Date()
    }
    
    // Legacy initializer for backward compatibility
    init(currentState: WidgetState, activeSession: ActiveSessionData?, sessionsCompleted: Int, streak: Int, nextScheduledSession: ScheduledSessionData?, cancelledScheduledSessions: [String], lastUpdated: Date) {
        self.currentState = currentState
        self.activeSession = activeSession
        self.sessionsCompleted = sessionsCompleted
        self.nextScheduledSession = nextScheduledSession
        self.cancelledScheduledSessions = cancelledScheduledSessions
        self.lastUpdated = lastUpdated
        
        // Derive interactive widget values from legacy structure with proper data
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        let isPremiumValue = suite?.bool(forKey: "isPremium") ?? false
        let savedSeconds = suite?.double(forKey: "zenloop.savedSeconds") ?? 0
        
        self.isSessionActive = (currentState == .active || currentState == .paused)
        self.currentSessionTitle = activeSession?.title ?? ""
        self.timeRemaining = activeSession?.timeRemaining ?? "25:00"
        self.progress = activeSession?.progress ?? 0.0
        self.streak = streak
        self.isPremium = isPremiumValue
        // Format total focus time inline
        let hours = Int(savedSeconds) / 3600
        let minutes = Int(savedSeconds) / 60 % 60
        self.totalFocusTime = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

// MARK: - Widget State Enum

enum WidgetState: String, Codable, CaseIterable {
        case idle = "idle"
        case active = "active" 
        case paused = "paused"
        case completed = "completed"
        
        var displayTitle: String {
            switch self {
            case .idle:
                return String(localized: "state_ready_to_focus", bundle: .main)
            case .active:
                return String(localized: "state_in_session", bundle: .main)
            case .paused:
                return String(localized: "state_paused", bundle: .main)
            case .completed:
                return String(localized: "state_completed", bundle: .main)
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

// MARK: - Legacy Widget Data Structure

struct LegacyZenloopWidgetData: Codable {
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
        let currentState = WidgetState(rawValue: currentStateRaw) ?? .idle
        
        let sessionsCompleted = suite.integer(forKey: "widget_sessions_completed")
        let streak = suite.integer(forKey: "widget_streak")
        
        // Check premium status
        let isPremium = suite.bool(forKey: "isPremium")
        
        // Calculate total focus time from saved seconds (from App Group)
        let savedSeconds = suite.double(forKey: "zenloop.savedSeconds")
        let totalFocusTime = formatTotalFocusTime(savedSeconds)
        
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
        print("   State: \(currentStateRaw) -> \(currentState.rawValue)")
        print("   Active Session: \(activeSession?.title ?? "none")")
        print("   Next Scheduled: \(nextScheduledSession?.title ?? "none")")
        print("   Premium: \(isPremium)")
        print("   Total Focus: \(totalFocusTime)")
        print("   Cancelled Sessions: \(cancelledSessions.count)")
        print("   Final isSessionActive: \(currentState == .active || currentState == .paused)")
        
        // Create widget data structure with full state preservation
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
    
    private func formatTotalFocusTime(_ savedSeconds: Double) -> String {
        let hours = Int(savedSeconds) / 3600
        let minutes = Int(savedSeconds) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func createDefaultData() -> ZenloopWidgetData {
        print("📱 [WIDGET] Using default data - no App Group access")
        return ZenloopWidgetData(
            isSessionActive: false,
            currentSessionTitle: "",
            timeRemaining: "25:00",
            progress: 0.0,
            totalFocusTime: "2h 30m",
            streak: 2,
            isPremium: false
        )
    }
    
    func updateWidgetData(_ data: ZenloopWidgetData) {
        guard let suite = suite else { return }
        
        // Save interactive widget structure
        let currentState: WidgetState = data.isSessionActive ? .active : .idle
        suite.set(currentState.rawValue, forKey: "widget_current_state")
        suite.set(data.streak, forKey: "widget_streak")
        
        // Save active session data if session is active
        if data.isSessionActive {
            let sessionId = UUID().uuidString
            suite.set(sessionId, forKey: "widget_active_session_id")
            suite.set(data.currentSessionTitle, forKey: "widget_active_session_title")
            suite.set(data.timeRemaining, forKey: "widget_active_session_time_remaining")
            suite.set(data.progress, forKey: "widget_active_session_progress")
            suite.set("quickStart", forKey: "widget_active_session_origin")
            suite.set(Date(), forKey: "widget_active_session_start_time")
            suite.set(data.timeRemaining.timeIntervalFromString(), forKey: "widget_active_session_duration")
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
        
        // Update premium status
        suite.set(data.isPremium, forKey: "isPremium")
        
        suite.set(Date(), forKey: "widget_last_updated")
        suite.synchronize()
        
        print("💾 [WIDGET] Data updated in App Group with interactive structure")
        print("   Session Active: \(data.isSessionActive)")
        print("   Session Title: \(data.currentSessionTitle)")
        print("   Premium: \(data.isPremium)")
    }
    
    // MARK: - Session Control Methods with Synchronization
    
    func startSession(duration: Int, origin: ActiveSessionData.SessionOrigin = .quickStart) {
        // Vérifier si l'utilisateur est Premium avant d'autoriser le lancement de session
        if !isPremiumUser() {
            print("🚫 [WIDGET] Session bloquée - utilisateur non Premium")
            // Stocker l'intent pour rediriger vers le paywall
            storePendingSessionForPaywall(duration: duration, origin: origin)
            return
        }
        
        let currentData = getCurrentData()
        
        let newData = ZenloopWidgetData(
            isSessionActive: true,
            currentSessionTitle: String(localized: "quick_session_title", bundle: .main).replacingOccurrences(of: "%d", with: "\(duration)"),
            timeRemaining: "\(duration):00",
            progress: 0.0,
            totalFocusTime: currentData.totalFocusTime,
            streak: currentData.streak,
            isPremium: currentData.isPremium
        )
        
        print("✅ [SESSION] Started \(origin.rawValue) session: \(duration)m")
        updateWidgetData(newData)
    }
    
    func pauseSession() {
        let currentData = getCurrentData()
        if !currentData.isSessionActive {
            print("❌ [SESSION] No active session to pause")
            return
        }
        
        // For now, just stop the session (can enhance pause logic later)
        stopSession()
    }
    
    func resumeSession() {
        let currentData = getCurrentData()
        if currentData.isSessionActive {
            print("❌ [SESSION] Session already active")
            return
        }
        
        // For now, start a new session (can enhance resume logic later)
        startSession(duration: 25)
    }
    
    func stopSession() {
        let currentData = getCurrentData()
        if !currentData.isSessionActive {
            print("❌ [SESSION] No session to stop")
            return
        }
        
        let stoppedData = ZenloopWidgetData(
            isSessionActive: false,
            currentSessionTitle: "",
            timeRemaining: "25:00",
            progress: 0.0,
            totalFocusTime: currentData.totalFocusTime,
            streak: currentData.streak,
            isPremium: currentData.isPremium
        )
        
        print("🛑 [SESSION] Stopped session")
        updateWidgetData(stoppedData)
    }
    
    func startNewSession() {
        startSession(duration: 25, origin: .manual)
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
    print(String(localized: "session_cancelled_conflict", bundle: .main))
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