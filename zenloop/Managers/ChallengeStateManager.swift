//  ChallengeStateManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability
//  Fixed on 06/04/2026: triple completion, pause display, ticker restart, notif cleanup

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
    private var isMonitoring = false                // FIX Bug 1: guard against double ticker start
    private var isCompleting = false                // FIX Bug 2: mutex for completion
    private var lastSecondBroadcast: Int? = nil
    private var lastProgress: Double = -1
    private var lastPauseSecondBroadcast: Int? = nil
    private var lastEventsCheck: TimeInterval = 0
    private var autoCompletionWorkItem: DispatchWorkItem?  // FIX Bug 2: cancellable autoCompletion
    
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

        // FIX Bug 2: Reset completion flag for new challenge
        isCompleting = false

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
        
        let now = Date()
        var pausedChallenge = challenge
        pausedChallenge.pausedTime = now
        // Garder isActive = true pour que la restauration fonctionne après un kill app
        // On utilise currentState == .paused pour contrôler le comportement du ticker
        currentChallenge = pausedChallenge
        currentState = .paused
        
        // FIX Bug 2: Annuler l'autoCompletion pendant la pause
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil
        
        // Pause de 5 minutes par défaut
        // FIX: Stocker aussi dans UserDefaults pour survivre au kill app
        let pauseEnd = now.addingTimeInterval(5 * 60)
        pauseEndTime = pauseEnd
        UserDefaults.standard.set(pauseEnd.timeIntervalSince1970, forKey: "zenloop_pause_end_time")
        
        delegate?.stateDidChange(to: .paused, challenge: pausedChallenge)
        
        #if DEBUG
        logger.debug("⏸️ [ChallengeState] Challenge paused for 5 minutes (endTime persisted)")
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
        lastPauseSecondBroadcast = nil  // Reset pour forcer mise à jour
        
        // FIX: Nettoyer la pauseEndTime persistée
        UserDefaults.standard.removeObject(forKey: "zenloop_pause_end_time")
        
        scheduleAutoCompletion()
        
        if let resumedChallenge = currentChallenge {
            delegate?.stateDidChange(to: .active, challenge: resumedChallenge)
        }
        
        #if DEBUG
        logger.debug("▶️ [ChallengeState] Challenge resumed")
        #endif
    }
    
    func completeChallenge() {
        // FIX Bug 2: Mutex — un seul chemin peut compléter
        guard !isCompleting else {
            #if DEBUG
            logger.debug("⚠️ [ChallengeState] completeChallenge() called but already completing — skipping")
            #endif
            return
        }
        guard let challenge = currentChallenge, currentState == .active else {
            #if DEBUG
            logger.warning("⚠️ [ChallengeState] Cannot complete - no active challenge (state: \(String(describing: self.currentState)))")
            #endif
            return
        }

        // FIX Bug 2: Verrouiller immédiatement
        isCompleting = true

        #if DEBUG
        logger.debug("🏁 [ChallengeState] Starting challenge completion for: \(challenge.title)")
        #endif

        var completedChallenge = challenge
        completedChallenge.isActive = false
        completedChallenge.isCompleted = true
        currentChallenge = completedChallenge
        currentState = .completed

        // FIX Bug 2: Annuler l'autoCompletion (empêche double appel)
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil

        cancelTimers()

        // FIX Bug 7: Annuler la notification de fin de manière synchrone
        cancelSessionEndNotificationSync()

        #if DEBUG
        logger.debug("📢 [ChallengeState] Notifying delegates of completion...")
        #endif

        delegate?.challengeCompleted(challenge: completedChallenge)
        delegate?.stateDidChange(to: .completed, challenge: completedChallenge)

        #if DEBUG
        logger.debug("🔓 [ChallengeState] Restrictions should now be removed by stateDidChange")
        #endif

        // FIX Bug 3: Un seul resetToIdle programmé — ICI seulement
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

        // FIX Bug 2: Reset completion flag
        isCompleting = false

        // FIX Bug 2: Annuler l'autoCompletion
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil

        // FIX: Nettoyer la pauseEndTime persistée
        UserDefaults.standard.removeObject(forKey: "zenloop_pause_end_time")

        cancelTimers()
        cancelSessionEndNotificationSync()
        resetState()

        delegate?.stateDidChange(to: .idle, challenge: nil)

        #if DEBUG
        logger.debug("⏹️ [ChallengeState] Challenge stopped: \(challenge.title)")
        #endif
    }
    
    func resetToIdle() {
        // FIX Bug 7: Annuler la notification de fin de session
        cancelSessionEndNotificationSync()

        // FIX Bug 2: Reset le flag de completion
        isCompleting = false

        // FIX Bug 2: Annuler l'autoCompletion
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil

        // FIX: Nettoyer la pauseEndTime persistée
        UserDefaults.standard.removeObject(forKey: "zenloop_pause_end_time")

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
        lastSecondBroadcast = nil
        lastProgress = -1
        lastPauseSecondBroadcast = nil
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
                print("❌ [ChallengeState] Failed to schedule session end notification: \(error.localizedDescription)")
            } else {
                print("🔔 [ChallengeState] Session end notification scheduled for \(timeInterval)s from now")
            }
            #endif
        }
    }

    // FIX Bug 7: Version synchrone — annule sans attendre le callback async
    private func cancelSessionEndNotificationSync() {
        guard let challenge = currentChallenge else {
            // Fallback: supprimer toutes les notifications session_end_
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [] // On ne peut pas lister sync, mais on peut supprimer par pattern
            )
            return
        }
        // Annuler directement par identifiant connu — pas besoin de query d'abord
        let identifier = "session_end_\(challenge.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        #if DEBUG
        logger.debug("🔕 [ChallengeState] Cancelled session end notification: \(identifier)")
        #endif
    }

    // Garder l'ancienne méthode pour nettoyage global (fallback)
    private func cancelAllSessionEndNotifications() {
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
        // FIX Bug 2: Ne pas compléter si déjà en cours de completion
        guard !isCompleting else {
            #if DEBUG
            logger.debug("⏰ [ChallengeState] checkAndCompleteExpiredSession - already completing, skip")
            #endif
            return
        }

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
        // FIX Bug 1: Ne pas redémarrer si déjà actif
        guard !isMonitoring else {
            #if DEBUG
            if verboseLogging {
                logger.debug("⏭️ [ChallengeState] Ticker already running, skipping restart")
            }
            #endif
            return
        }
        isMonitoring = true

        ticker.start(every: 1.0) { [weak self] in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    func restoreActiveSession(_ challenge: ZenloopChallenge) {
        // FIX Bug 8: Vérifier si la session a expiré pendant la fermeture
        if let startTime = challenge.startTime {
            let elapsed = Date().timeIntervalSince(startTime) - challenge.pauseDuration
            // Ne vérifier l'expiration que si la session n'est pas en pause
            // (une session en pause ne compte pas le temps)
            if challenge.pausedTime == nil && elapsed >= challenge.duration {
                #if DEBUG
                logger.debug("⏰ [ChallengeState] Session expired during app closure — completing")
                #endif
                currentChallenge = challenge
                currentState = .active
                isCompleting = false
                completeChallenge()
                return
            }
        }

        // Restaurer l'état complet après un reload
        currentChallenge = challenge
        isCompleting = false

        // FIX PAUSE RESTORE: Déterminer l'état correct
        if challenge.pausedTime != nil {
            // La session était en pause quand l'app a été tuée
            currentState = .paused

            // Restaurer pauseEndTime depuis UserDefaults
            let persistedPauseEnd = UserDefaults.standard.double(forKey: "zenloop_pause_end_time")
            if persistedPauseEnd > 0 {
                let pauseEnd = Date(timeIntervalSince1970: persistedPauseEnd)

                if pauseEnd > Date() {
                    // La pause n'est pas encore finie — restaurer le décompte
                    pauseEndTime = pauseEnd
                    let remaining = Int(pauseEnd.timeIntervalSinceNow)
                    pauseTimeRemaining = formatTime(remaining)

                    #if DEBUG
                    logger.debug("⏸️ [ChallengeState] Pause restored — \(remaining)s remaining")
                    #endif
                } else {
                    // La pause est expirée pendant que l'app était fermée → auto-resume
                    #if DEBUG
                    logger.debug("⏸️ [ChallengeState] Pause expired during closure — auto-resuming")
                    #endif

                    // Calculer combien de temps la pause a duré (jusqu'à son expiration)
                    if let pausedTime = challenge.pausedTime {
                        let actualPauseDuration = pauseEnd.timeIntervalSince(pausedTime)
                        var resumedChallenge = challenge
                        resumedChallenge.pauseDuration += actualPauseDuration
                        resumedChallenge.pausedTime = nil
                        resumedChallenge.isActive = true
                        currentChallenge = resumedChallenge
                    }

                    currentState = .active
                    pauseEndTime = nil
                    UserDefaults.standard.removeObject(forKey: "zenloop_pause_end_time")

                    // Maintenant vérifier si la session elle-même a expiré après le resume
                    if let updatedChallenge = currentChallenge, let startTime = updatedChallenge.startTime {
                        let elapsed = Date().timeIntervalSince(startTime) - updatedChallenge.pauseDuration
                        if elapsed >= updatedChallenge.duration {
                            #if DEBUG
                            logger.debug("⏰ [ChallengeState] Session also expired after pause — completing")
                            #endif
                            completeChallenge()
                            return
                        }
                    }

                    scheduleAutoCompletion()
                }
            } else {
                // Pas de pauseEndTime persistée — la pause est "perdue", auto-resume
                #if DEBUG
                logger.debug("⚠️ [ChallengeState] No persisted pauseEndTime — auto-resuming")
                #endif

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
                scheduleAutoCompletion()
            }
        } else {
            // Session active (pas en pause)
            currentState = .active
            scheduleAutoCompletion()
        }

        currentTimeRemaining = currentChallenge?.timeRemaining ?? "00:00"
        currentProgress = currentChallenge?.safeProgress ?? 0.0
        
        // Redémarrer le monitoring
        isMonitoring = false
        startStateMonitoring()

        // Notifier le delegate de l'état restauré
        delegate?.stateDidChange(to: currentState, challenge: currentChallenge)
        
        #if DEBUG
        logger.debug("🔄 [ChallengeState] Session restored after reload: \(challenge.title) (state: \(self.currentState.rawValue))")
        #endif
    }
    
    func resumeStateMonitoringAfterReload() {
        // Redémarrer le monitoring s'il y a une session active
        if currentChallenge != nil && (currentState == .active || currentState == .paused) {
            isMonitoring = false  // Reset pour permettre le démarrage
            startStateMonitoring()
            
            #if DEBUG
            logger.debug("🔄 [ChallengeState] Timer restored after app reload")
            #endif
        }
    }
    
    private func tick() {
        let now = Date()
        
        // 1) Challenge actif — timer principal
        if let challenge = currentChallenge, currentState == .active, let startTime = challenge.startTime {
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
                
                // Auto-completion si terminé (FIX Bug 2: protégé par isCompleting dans completeChallenge)
                if progress >= 1.0 && currentState == .active {
                    completeChallenge()
                }
            }
            return
        }
        
        // 2) Pause en cours — FIX Bug 5: afficher le temps de pause ET garder le timer principal figé
        if currentState == .paused {
            // Afficher le décompte de pause
            if let endTime = pauseEndTime {
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
            }
            
            // FIX Bug 5: NE PAS reset currentTimeRemaining ni currentProgress pendant la pause
            // Le timer principal reste figé à sa dernière valeur
            return
        }
        
        // 3) État inactif (idle/completed) - reset des valeurs si nécessaire
        // FIX Bug 5: Ce bloc ne s'exécute QUE si on est idle ou completed (pas paused)
        if currentState == .idle || currentState == .completed {
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
        // FIX Bug 2: Annuler toute autoCompletion précédente
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil

        guard let challenge = currentChallenge, let startTime = challenge.startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime) - challenge.pauseDuration
        let remainingTime = max(challenge.duration - elapsedTime, 0)
        
        guard remainingTime > 0 else {
            // Déjà expiré — compléter immédiatement
            if currentState == .active {
                completeChallenge()
            }
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.currentState == .active {
                self.completeChallenge()
            }
        }
        autoCompletionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime, execute: workItem)
    }
    
    // MARK: - Timer Management
    
    func cancelTimers() {
        ticker.stop()
        isMonitoring = false  // FIX Bug 1: Reset le flag quand on arrête
        
        // FIX Bug 2: Annuler aussi l'autoCompletion
        autoCompletionWorkItem?.cancel()
        autoCompletionWorkItem = nil
    }
    
    // MARK: - Validation
    
    func validateState() -> Bool {
        if let challenge = currentChallenge {
            if challenge.isActive && currentState != .active && currentState != .paused { return false }
            if !challenge.isActive && currentState == .active { return false }
            if challenge.startTime == nil && challenge.isActive { return false }
        }
        if currentChallenge == nil && currentState != .idle && currentState != .completed { return false }
        return true
    }
    
    deinit {
        ticker.stop()
    }
}