//  ChallengeStateManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import SwiftUI
import FamilyControls
import UserNotifications
import os

// MARK: - Challenge State Management

protocol ChallengeStateManagerDelegate: AnyObject {
    func stateDidChange(to state: ZenloopState, challenge: ZenloopChallenge?)
    func challengeProgressUpdated(timeRemaining: String, progress: Double)
    func pauseTimeUpdated(timeRemaining: String)
    func challengeCompleted(challenge: ZenloopChallenge)
}

@MainActor
final class ChallengeStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentState: ZenloopState = .idle
    @Published var currentTimeRemaining = "00:00"
    @Published var currentProgress: Double = 0.0
    @Published var pauseTimeRemaining = "00:00"
    
    // MARK: - Private Properties
    private var currentChallenge: ZenloopChallenge?
    private var pauseEndTime: Date?
    
    private let ticker = Ticker()
    private var lastSecondBroadcast: Int? = nil
    private var lastProgress: Double = -1
    private var lastPauseSecondBroadcast: Int? = nil
    private var lastEventsCheck: TimeInterval = 0
    
    weak var delegate: ChallengeStateManagerDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "ChallengeState")
    private let verboseLogging = false
    #endif
    
    // MARK: - Public Interface
    
    var canStartChallenge: Bool {
        return currentState == .idle
    }
    
    var hasActiveChallenge: Bool {
        return currentChallenge != nil && (currentState == .active || currentState == .paused)
    }
    
    func getCurrentChallenge() -> ZenloopChallenge? {
        return currentChallenge
    }
    
    // MARK: - Challenge Lifecycle
    
    func startChallenge(_ challenge: ZenloopChallenge) {
        guard currentState == .idle else { return }

        var startingChallenge = challenge

        // CORRIGÉ: Ne pas écraser startTime si c'est une session programmée qui a déjà commencé
        if startingChallenge.startTime == nil {
            // Session manuelle - utiliser l'heure actuelle
            startingChallenge.startTime = Date()
        }
        // Sinon, conserver l'heure de démarrage réelle de l'extension

        startingChallenge.isActive = true
        startingChallenge.isCompleted = false

        currentChallenge = startingChallenge
        currentState = .active

        // Programmer une notification silencieuse pour réveiller l'app à la fin
        scheduleSessionEndNotification(for: startingChallenge)
        
        currentTimeRemaining = startingChallenge.timeRemaining
        currentProgress = startingChallenge.safeProgress
        
        startStateMonitoring()
        scheduleAutoCompletion()
        
        delegate?.stateDidChange(to: .active, challenge: startingChallenge)
        
        #if DEBUG
        logger.debug("🚀 [ChallengeState] Challenge started: \(challenge.title)")
        #endif
    }
    
    func pauseChallenge() {
        guard let challenge = currentChallenge, currentState == .active else { return }
        
        var pausedChallenge = challenge
        pausedChallenge.pausedTime = Date()
        pausedChallenge.isActive = false  // Arrêter le timer principal
        currentChallenge = pausedChallenge
        currentState = .paused
        
        // Pause de 5 minutes par défaut
        pauseEndTime = Date().addingTimeInterval(5 * 60)
        
        delegate?.stateDidChange(to: .paused, challenge: pausedChallenge)
        
        #if DEBUG
        logger.debug("⏸️ [ChallengeState] Challenge paused for 5 minutes")
        #endif
    }
    
    func resumeChallenge() {
        guard let challenge = currentChallenge, currentState == .paused else { return }
        
        if let pausedTime = challenge.pausedTime {
            let pauseDuration = Date().timeIntervalSince(pausedTime)
            var resumedChallenge = challenge
            resumedChallenge.pauseDuration += pauseDuration
            resumedChallenge.pausedTime = nil
            resumedChallenge.isActive = true
            currentChallenge = resumedChallenge
        }
        
        currentState = .active
        pauseEndTime = nil
        pauseTimeRemaining = "00:00"
        
        scheduleAutoCompletion()
        
        if let resumedChallenge = currentChallenge {
            delegate?.stateDidChange(to: .active, challenge: resumedChallenge)
        }
        
        #if DEBUG
        logger.debug("▶️ [ChallengeState] Challenge resumed")
        #endif
    }
    
    func completeChallenge() {
        guard let challenge = currentChallenge, currentState == .active else {
            #if DEBUG
            logger.warning("⚠️ [ChallengeState] Cannot complete - no active challenge (state: \(String(describing: self.currentState)))")
            #endif
            return
        }

        #if DEBUG
        logger.debug("🏁 [ChallengeState] Starting challenge completion for: \(challenge.title)")
        #endif

        var completedChallenge = challenge
        completedChallenge.isActive = false
        completedChallenge.isCompleted = true
        currentChallenge = completedChallenge
        currentState = .completed

        cancelTimers()

        #if DEBUG
        logger.debug("📢 [ChallengeState] Notifying delegates of completion...")
        #endif

        delegate?.challengeCompleted(challenge: completedChallenge)
        delegate?.stateDidChange(to: .completed, challenge: completedChallenge)

        #if DEBUG
        logger.debug("🔓 [ChallengeState] Restrictions should now be removed by stateDidChange")
        #endif

        // Auto-reset to idle after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.resetToIdle()
        }

        #if DEBUG
        logger.debug("✅ [ChallengeState] Challenge completed: \(challenge.title)")
        #endif
    }
    
    func stopChallenge() {
        guard let challenge = currentChallenge, currentState == .active || currentState == .paused else { return }

        var stoppedChallenge = challenge
        stoppedChallenge.isActive = false
        currentChallenge = stoppedChallenge
        currentState = .idle

        cancelTimers()
        cancelSessionEndNotification()
        resetState()

        delegate?.stateDidChange(to: .idle, challenge: nil)

        #if DEBUG
        logger.debug("⏹️ [ChallengeState] Challenge stopped: \(challenge.title)")
        #endif
    }
    
    func resetToIdle() {
        // Annuler la notification de fin de session
        cancelSessionEndNotification()

        currentChallenge = nil
        currentState = .idle
        pauseEndTime = nil

        cancelTimers()
        resetState()

        delegate?.stateDidChange(to: .idle, challenge: nil)
    }
    
    private func resetState() {
        currentTimeRemaining = "00:00"
        currentProgress = 0.0
        pauseTimeRemaining = "00:00"
    }

    // MARK: - Background Session End Notifications

    private func scheduleSessionEndNotification(for challenge: ZenloopChallenge) {
        guard let startTime = challenge.startTime else { return }
        let endTime = startTime.addingTimeInterval(challenge.duration)
        let timeInterval = endTime.timeIntervalSinceNow

        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "session_completed")
        content.body = challenge.title
        content.sound = .default
        content.categoryIdentifier = "session_end"
        content.userInfo = ["sessionId": challenge.id, "action": "complete_session"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_end_\(challenge.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                self.logger.debug("❌ [ChallengeState] Failed to schedule session end notification: \(error.localizedDescription)")
            } else {
                self.logger.debug("🔔 [ChallengeState] Session end notification scheduled for \(timeInterval)s from now")
            }
            #endif
        }
    }

    private func cancelSessionEndNotification() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let sessionEndIds = requests
                .filter { $0.identifier.starts(with: "session_end_") }
                .map { $0.identifier }

            if !sessionEndIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: sessionEndIds)

                #if DEBUG
                Task { @MainActor in
                    self.logger.debug("🔕 [ChallengeState] Cancelled \(sessionEndIds.count) session end notification(s)")
                }
                #endif
            }
        }
    }

    func checkAndCompleteExpiredSession() {
        guard let challenge = currentChallenge,
              let startTime = challenge.startTime,
              currentState == .active else {
            #if DEBUG
            logger.debug("⏰ [ChallengeState] checkAndCompleteExpiredSession - no active session to check")
            #endif
            return
        }

        let elapsed = Date().timeIntervalSince(startTime) - challenge.pauseDuration
        let timeRemaining = challenge.duration - elapsed

        #if DEBUG
        logger.debug("⏰ [ChallengeState] Checking expired session: elapsed=\(elapsed)s, duration=\(challenge.duration)s, remaining=\(timeRemaining)s")
        #endif

        // Ajouter une petite tolérance de 2 secondes pour éviter les problèmes de timing
        if elapsed >= (challenge.duration - 2.0) {
            #if DEBUG
            logger.debug("⏰ [ChallengeState] Session expired while in background - completing now (elapsed: \(Int(elapsed))s)")
            #endif

            completeChallenge()
        } else {
            #if DEBUG
            logger.debug("⏰ [ChallengeState] Session still active - \(Int(timeRemaining))s remaining")
            #endif
        }
    }

    // MARK: - App Attempt Tracking
    
    func recordAppOpenAttempt(appName: String? = nil) {
        guard var challenge = currentChallenge, currentState == .active else { return }
        challenge.appOpenAttempts += 1
        if let appName = appName {
            challenge.attemptedApps[appName, default: 0] += 1
        }
        currentChallenge = challenge
        
        #if DEBUG
        let appInfo = appName != nil ? " (\(appName!))" : ""
        logger.debug("🚫 [ChallengeState] App access attempt blocked\(appInfo)")
        #endif
    }
    
    func getTopAttemptedApps() -> [(String, Int)] {
        guard let challenge = currentChallenge else { return [] }
        return challenge.attemptedApps.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    // MARK: - State Monitoring & Ticker
    
    func startStateMonitoring() {
        ticker.start(every: 1.0) { [weak self] in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    func restoreActiveSession(_ challenge: ZenloopChallenge) {
        // Restaurer l'état complet après un reload
        currentChallenge = challenge
        currentState = challenge.isActive ? .active : .paused
        currentTimeRemaining = challenge.timeRemaining
        currentProgress = challenge.safeProgress
        
        // Redémarrer le monitoring
        startStateMonitoring()
        
        #if DEBUG
        logger.debug("🔄 [ChallengeState] Session restored after reload: \(challenge.title)")
        #endif
    }
    
    func resumeStateMonitoringAfterReload() {
        // Redémarrer le monitoring s'il y a une session active
        if currentChallenge != nil && (currentState == .active || currentState == .paused) {
            startStateMonitoring()
            
            #if DEBUG
            logger.debug("🔄 [ChallengeState] Timer restored after app reload")
            #endif
        }
    }
    
    private func tick() {
        let now = Date()
        
        // 1) Challenge actif
        if let challenge = currentChallenge, challenge.isActive, let startTime = challenge.startTime {
            let elapsed = now.timeIntervalSince(startTime) - challenge.pauseDuration
            let remaining = max(0, challenge.duration - elapsed)
            let seconds = Int(remaining.rounded(.down))
            let progress = min(1, max(0, elapsed / max(1, challenge.duration)))
            
            // Mettre à jour seulement si changement significatif
            if lastSecondBroadcast != seconds || abs(progress - lastProgress) > 0.001 {
                lastSecondBroadcast = seconds
                lastProgress = progress
                
                let timeString = formatTime(seconds)
                if currentTimeRemaining != timeString {
                    currentTimeRemaining = timeString
                }
                if abs(currentProgress - progress) > 0.001 {
                    currentProgress = progress
                }
                
                delegate?.challengeProgressUpdated(timeRemaining: timeString, progress: progress)
                
                // Auto-completion si terminé
                if progress >= 1.0 && currentState == .active {
                    completeChallenge()
                }
            }
            return
        }
        
        // 2) Pause en cours
        if currentState == .paused, let endTime = pauseEndTime {
            let remainingSeconds = max(0, Int(endTime.timeIntervalSinceNow.rounded(.down)))
            if lastPauseSecondBroadcast != remainingSeconds {
                lastPauseSecondBroadcast = remainingSeconds
                let timeString = formatTime(remainingSeconds)
                
                if pauseTimeRemaining != timeString {
                    pauseTimeRemaining = timeString
                }
                
                delegate?.pauseTimeUpdated(timeRemaining: timeString)
                
                // Auto-resume si temps écoulé
                if remainingSeconds == 0 {
                    resumeChallenge()
                }
            }
            return
        }
        
        // 3) État inactif - reset des valeurs si nécessaire
        if currentState != .active {
            if currentTimeRemaining != "00:00" { 
                currentTimeRemaining = "00:00"
                delegate?.challengeProgressUpdated(timeRemaining: "00:00", progress: 0.0)
            }
            if currentProgress != 0 { 
                currentProgress = 0
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3600
        let minutes = (clampedSeconds % 3600) / 60
        let secs = clampedSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Auto-completion
    
    private func scheduleAutoCompletion() {
        guard let challenge = currentChallenge, let startTime = challenge.startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime) - challenge.pauseDuration
        let remainingTime = max(challenge.duration - elapsedTime, 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) { [weak self] in
            if self?.currentState == .active {
                self?.completeChallenge()
            }
        }
    }
    
    // MARK: - Timer Management
    
    func cancelTimers() {
        ticker.stop()
    }
    
    // MARK: - Validation
    
    func validateState() -> Bool {
        if let challenge = currentChallenge {
            if challenge.isActive && currentState != .active { return false }
            if !challenge.isActive && currentState == .active { return false }
            if challenge.startTime == nil && challenge.isActive { return false }
        }
        if currentChallenge == nil && currentState != .idle { return false }
        return true
    }
    
    deinit {
        ticker.stop()
    }
}