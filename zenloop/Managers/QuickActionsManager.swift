//
//  QuickActionsManager.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import UIKit
import SwiftUI

// MARK: - Quick Action Types

enum QuickActionType: String, CaseIterable {
    case quickFocus = "com.app.zenloop.quickfocus"
    case startScheduled = "com.app.zenloop.startscheduled"
    case viewStats = "com.app.zenloop.viewstats"
    case emergency = "com.app.zenloop.emergency"
    case resetAll = "com.app.zenloop.resetall"
    case dontDelete = "com.app.zenloop.dontdelete"
    
    var title: String {
        switch self {
        case .quickFocus:
            return String(localized: "quick_action_quick_focus_title", comment: "Quick focus action title")
        case .startScheduled:
            return String(localized: "quick_action_start_scheduled_title", comment: "Start scheduled session action title")
        case .viewStats:
            return String(localized: "quick_action_view_stats_title", comment: "View stats action title")
        case .emergency:
            return String(localized: "quick_action_emergency_title", comment: "Emergency break action title")
        case .resetAll:
            return String(localized: "reset_all_restrictions", comment: "Reset all restrictions action title")
        case .dontDelete:
            return String(localized: "quick_action_dont_delete_title", comment: "Don't delete retention action title")
        }
    }

    var subtitle: String {
        switch self {
        case .quickFocus:
            return String(localized: "quick_action_quick_focus_subtitle", comment: "Quick focus action subtitle")
        case .startScheduled:
            return String(localized: "quick_action_start_scheduled_subtitle", comment: "Start scheduled session subtitle")
        case .viewStats:
            return String(localized: "quick_action_view_stats_subtitle", comment: "View stats action subtitle")
        case .emergency:
            return String(localized: "quick_action_emergency_subtitle", comment: "Emergency break subtitle")
        case .resetAll:
            return String(localized: "reset_all_restrictions_description", comment: "Reset all restrictions subtitle")
        case .dontDelete:
            return String(localized: "quick_action_dont_delete_subtitle", comment: "Don't delete retention subtitle")
        }
    }

    var iconType: UIApplicationShortcutIcon {
        switch self {
        case .quickFocus:
            return UIApplicationShortcutIcon(systemImageName: "bolt.circle.fill")
        case .startScheduled:
            return UIApplicationShortcutIcon(systemImageName: "clock.circle.fill")
        case .viewStats:
            return UIApplicationShortcutIcon(systemImageName: "chart.bar.fill")
        case .emergency:
            return UIApplicationShortcutIcon(systemImageName: "cross.circle.fill")
        case .resetAll:
            return UIApplicationShortcutIcon(systemImageName: "arrow.counterclockwise.circle.fill")
        case .dontDelete:
            return UIApplicationShortcutIcon(systemImageName: "heart.circle.fill")
        }
    }
}

// MARK: - Quick Actions Manager

@MainActor
class QuickActionsManager: ObservableObject {
    static let shared = QuickActionsManager()
    
    @Published var pendingAction: QuickActionType?
    private var zenloopManager: ZenloopManager?
    
    private init() {
        setupInitialQuickActions()
    }
    
    // MARK: - Setup
    
    func configure(with manager: ZenloopManager) {
        self.zenloopManager = manager
    }
    
    private func setupInitialQuickActions() {
        // Add initial static actions - always show retention message
        let staticActions = [
            createShortcutItem(for: .dontDelete), // Most important for retention
            createShortcutItem(for: .resetAll),    // Always visible - lever restrictions
            createShortcutItem(for: .quickFocus),
            createShortcutItem(for: .viewStats)
        ]
        
        UIApplication.shared.shortcutItems = staticActions
        print("📱 [QUICK_ACTIONS] Initial static actions set: \(staticActions.count)")
        
        // Then update with dynamic conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateQuickActions()
        }
    }
    
    // MARK: - Dynamic Updates
    
    func updateQuickActions() {
        var actions: [UIApplicationShortcutItem] = []
        
        // ALWAYS FIRST: Retention message - most important for user retention
        actions.append(createShortcutItem(for: .dontDelete))

        // ALWAYS SECOND: Reset All - toujours visible pour lever les restrictions
        actions.append(createShortcutItem(for: .resetAll))

        // Always available: Quick Focus
        actions.append(createShortcutItem(for: .quickFocus))

        // Conditional: Emergency break (only if session is active) - higher priority
        if hasActiveSession() && actions.count < 4 {
            actions.append(createShortcutItem(for: .emergency))
        }

        // Conditional: Start Scheduled (if there are upcoming sessions)
        if hasUpcomingScheduledSessions() && actions.count < 4 {
            actions.append(createShortcutItem(for: .startScheduled))
        }

        // Always available: View Stats (if space allows)
        if actions.count < 4 {
            actions.append(createShortcutItem(for: .viewStats))
        }
        
        // Update the shortcut items (max 4 items)
        UIApplication.shared.shortcutItems = Array(actions.prefix(4))
        
        print("📱 [QUICK_ACTIONS] Updated with \(actions.count) actions")
    }
    
    private func createShortcutItem(for actionType: QuickActionType) -> UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: actionType.rawValue,
            localizedTitle: actionType.title,
            localizedSubtitle: actionType.subtitle,
            icon: actionType.iconType,
            userInfo: ["timestamp": Date().timeIntervalSince1970] as [String: NSSecureCoding]
        )
    }
    
    // MARK: - Conditions
    
    private func hasUpcomingScheduledSessions() -> Bool {
        // Check if there are upcoming scheduled sessions
        let activeSessions = BlockScheduler.shared.getActiveSchedules()
        return !activeSessions.isEmpty
    }
    
    private func hasActiveSession() -> Bool {
        return zenloopManager?.currentState == .active
    }
    
    // MARK: - Action Handling
    
    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        guard let actionType = QuickActionType(rawValue: shortcutItem.type) else {
            print("❌ [QUICK_ACTIONS] Unknown action type: \(shortcutItem.type)")
            return
        }
        
        let source = shortcutItem.userInfo?["source"] as? String ?? "shortcut"
        print("🎯 [QUICK_ACTIONS] Handling action: \(actionType.title) (source: \(source))")
        
        // Store the action to be processed when the app is fully loaded
        pendingAction = actionType
        
        // Process immediately if manager is available, otherwise wait for app to be ready
        if zenloopManager != nil {
            processAction(actionType)
        } else {
            // App is cold starting - set up a timer to retry processing
            setupColdStartProcessing(for: actionType)
        }
    }
    
    private func setupColdStartProcessing(for actionType: QuickActionType) {
        print("🔄 [QUICK_ACTIONS] Setting up cold start processing for: \(actionType.title)")
        
        var retryCount = 0
        let maxRetries = 20 // 10 seconds maximum (0.5s * 20)
        
        // Retry processing every 0.5 seconds until ZenloopManager is available
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            retryCount += 1
            
            if let manager = self.zenloopManager {
                print("✅ [QUICK_ACTIONS] Manager available after \(retryCount) retries, processing action")
                self.processAction(actionType)
                timer.invalidate()
            } else if retryCount >= maxRetries {
                print("❌ [QUICK_ACTIONS] Timeout waiting for manager after \(retryCount) retries")
                timer.invalidate()
            } else {
                print("⏳ [QUICK_ACTIONS] Still waiting for manager... (\(retryCount)/\(maxRetries))")
            }
        }
        
        // Store timer reference to be able to invalidate it if needed
        // (In a real implementation, you might want to store this in an instance variable)
    }
    
    func processPendingAction() {
        guard let action = pendingAction else { return }
        processAction(action)
        pendingAction = nil
    }
    
    private func processAction(_ actionType: QuickActionType) {
        guard let manager = zenloopManager else {
            print("❌ [QUICK_ACTIONS] ZenloopManager not available")
            return
        }
        
        switch actionType {
        case .quickFocus:
            startQuickFocusSession(with: manager)

        case .startScheduled:
            startScheduledSession(with: manager)

        case .viewStats:
            navigateToStats()

        case .emergency:
            handleEmergencyBreak(with: manager)

        case .resetAll:
            handleResetAllRestrictions(with: manager)

        case .dontDelete:
            handleRetentionMessage(with: manager)
        }
    }
    
    // MARK: - Action Implementations
    
    private func startQuickFocusSession(with manager: ZenloopManager) {
        print("🚀 [QUICK_ACTIONS] Starting Quick Focus (25 min)")
        
        // Check if apps are selected
        guard manager.isAppsSelectionValid() else {
            print("⚠️ [QUICK_ACTIONS] No apps selected - need to configure first")
            // Could show an alert or navigate to app selection
            return
        }
        
        // Start a 25-minute focus session
        let quickChallenge = ZenloopChallenge(
            id: "quick-focus-\(UUID().uuidString)",
            title: "Quick Focus",
            description: "25-minute focus session started from Home Screen",
            duration: 25 * 60, // 25 minutes
            difficulty: .medium,
            startTime: Date(),
            isActive: true
        )
        
        manager.startSavedCustomChallenge(quickChallenge)
        
        // Send haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func startScheduledSession(with manager: ZenloopManager) {
        print("⏰ [QUICK_ACTIONS] Starting next scheduled session")
        
        let activeSessions = BlockScheduler.shared.getActiveSchedules()
        guard let nextSession = activeSessions.first else {
            print("⚠️ [QUICK_ACTIONS] No scheduled sessions available")
            return
        }
        
        // Start the scheduled session immediately
        let challenge = ZenloopChallenge(
            id: "scheduled-\(nextSession.sessionId)",
            title: nextSession.title,
            description: "Scheduled session started from Home Screen",
            duration: nextSession.duration,
            difficulty: .medium,
            startTime: Date(),
            isActive: true
        )
        
        manager.startSavedCustomChallenge(challenge)
        
        // Send haptic feedback
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    private func navigateToStats() {
        print("📊 [QUICK_ACTIONS] Navigating to Stats")
        
        // Post notification to navigate to stats tab
        NotificationCenter.default.post(name: .quickActionNavigateToStats, object: nil)
        
        // Send light haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func handleEmergencyBreak(with manager: ZenloopManager) {
        print("🛟 [QUICK_ACTIONS] Emergency break requested")

        // Pause the current session
        manager.requestPause()

        // Send strong haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        // Could show a breathing exercise or motivational message
        NotificationCenter.default.post(name: .quickActionEmergencyBreak, object: nil)
    }

    private func handleResetAllRestrictions(with manager: ZenloopManager) {
        print("🔄 [QUICK_ACTIONS] Reset all restrictions requested")

        // Stop current challenge/session
        manager.stopCurrentChallenge()

        // Clear all restrictions
        Task {
            await ScreenTimeManager.shared.stopAllBlocking()
            await manager.deviceActivityCoordinator.stopAllMonitoring()

            await MainActor.run {
                // Send strong haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                print("✅ [QUICK_ACTIONS] All restrictions cleared successfully")
            }
        }
    }

    private func handleRetentionMessage(with manager: ZenloopManager) {
        print("🫢 [QUICK_ACTIONS] Retention message selected - user considering keeping the app!")
        
        // Send positive haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Show the intelligent retention modal
        showRetentionEncouragement()
    }
    
    private func showRetentionEncouragement() {
        // Post notification to show special retention content
        NotificationCenter.default.post(name: .quickActionShowRetention, object: nil)
        
        // Track analytics event (user actively chose not to delete)
        print("📊 [ANALYTICS] User engaged with retention message - positive signal!")
        
        // Could trigger:
        // - Achievement unlock
        // - Streak bonus
        // - Special badge
        // - Motivational quote
    }
    
    // MARK: - Background Updates
    
    func updateOnAppBackground() {
        // Update quick actions when app goes to background
        updateQuickActions()
    }
    
    func updateOnStateChange() {
        // Update quick actions when app state changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateQuickActions()
        }
    }
    
    // MARK: - Testing & Debug
    
    func logCurrentQuickActions() {
        let items = UIApplication.shared.shortcutItems ?? []
        print("📱 [QUICK_ACTIONS] Current items: \(items.count)")
        for (index, item) in items.enumerated() {
            print("  \(index + 1). \(item.localizedTitle) (\(item.type))")
        }
    }
    
    func testQuickActionResponse() {
        print("🧪 [QUICK_ACTIONS] Testing Quick Action response...")
        
        // Test quick focus action
        let testAction = UIApplicationShortcutItem(
            type: QuickActionType.quickFocus.rawValue,
            localizedTitle: "Test Quick Focus",
            localizedSubtitle: "Testing shortcut functionality",
            icon: QuickActionType.quickFocus.iconType,
            userInfo: nil
        )
        
        handleQuickAction(testAction)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let quickActionNavigateToStats = Notification.Name("quickActionNavigateToStats")
    static let quickActionEmergencyBreak = Notification.Name("quickActionEmergencyBreak")
    static let quickActionShowRetention = Notification.Name("quickActionShowRetention")
}

// MARK: - App Integration

extension UIApplication {
    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        QuickActionsManager.shared.handleQuickAction(shortcutItem)
        return true
    }
}