//  AppRestrictionCoordinator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings
import os

// MARK: - App Restriction Management

protocol AppRestrictionCoordinatorDelegate: AnyObject {
    func selectedAppsCountChanged(_ count: Int)
    func appsSelectionUpdated(_ selection: FamilyActivitySelection)
}

@MainActor
final class AppRestrictionCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedAppsCount = 0
    @Published var isAuthorized = false
    
    // MARK: - Private Properties
    private let store = ManagedSettingsStore()
    private var blockedAppsSelection = FamilyActivitySelection()
    
    // Helper pour obtenir le store approprié selon le contexte
    private func getManagedStore(for sessionId: String? = nil) -> ManagedSettingsStore {
        if let sessionId = sessionId {
            // Utiliser un store nommé pour les sessions programmées
            return ManagedSettingsStore(named: ManagedSettingsStore.Name("scheduled_\(sessionId)"))
        } else {
            // Utiliser le store par défaut pour les sessions manuelles
            return store
        }
    }
    
    weak var delegate: AppRestrictionCoordinatorDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "AppRestriction")
    #endif
    
    // MARK: - Initialization
    
    init() {
        loadPersistedAppsSelection()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization Management
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)

            // Attendre un court délai pour que le statut soit propagé
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondes

            checkAuthorizationStatus()
            #if DEBUG
            logger.debug("✅ [AppRestriction] Authorization granted, final status: \(self.isAuthorized)")
            #endif
        } catch {
            #if DEBUG
            logger.error("❌ [AppRestriction] Authorization error: \(error.localizedDescription)")
            #endif
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        let wasAuthorized = isAuthorized
        isAuthorized = status == .approved
        #if DEBUG
        logger.debug("🔐 [AppRestriction] Authorization status: \(String(describing: status)) (was: \(wasAuthorized), now: \(self.isAuthorized))")
        #endif
    }
    
    // MARK: - App Selection Management
    
    func updateAppsSelection(_ selection: FamilyActivitySelection) {
        blockedAppsSelection = selection
        selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        persistAppsSelection()
        
        delegate?.selectedAppsCountChanged(self.selectedAppsCount)
        delegate?.appsSelectionUpdated(selection)
        
        #if DEBUG
        self.logger.debug("📱 [AppRestriction] Selection updated: \(self.selectedAppsCount) apps/categories")
        #endif
    }
    
    func getAppsSelection() -> FamilyActivitySelection {
        return blockedAppsSelection
    }
    
    func isAppsSelectionValid() -> Bool {
        return (!blockedAppsSelection.applicationTokens.isEmpty) || (!blockedAppsSelection.categoryTokens.isEmpty)
    }
    
    var canStartCustomSession: Bool {
        return isAppsSelectionValid()
    }
    
    func syncSelectedAppsCount() {
        let actualCount = blockedAppsSelection.applicationTokens.count + blockedAppsSelection.categoryTokens.count
        if selectedAppsCount != actualCount {
            selectedAppsCount = actualCount
            persistAppsSelection()
            delegate?.selectedAppsCountChanged(self.selectedAppsCount)
        }
    }
    
    // MARK: - Restriction Application
    
    func applyRestrictions(for sessionId: String? = nil) {
        guard isAuthorized else { 
            #if DEBUG
            logger.warning("⚠️ [AppRestriction] Cannot apply restrictions - not authorized")
            #endif
            return 
        }
        
        // Ne pas appliquer de restrictions si une session programmée est active
        if hasActiveScheduledSession() && sessionId == nil {
            #if DEBUG
            logger.debug("⚠️ [AppRestriction] Skipping manual restrictions - scheduled session active")
            #endif
            return
        }
        
        let targetStore = getManagedStore(for: sessionId)
        let appTokens = blockedAppsSelection.applicationTokens
        targetStore.shield.applications = appTokens
        
        if !blockedAppsSelection.categoryTokens.isEmpty {
            targetStore.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
                .specific(blockedAppsSelection.categoryTokens)
        }
        
        #if DEBUG
        let storeType = sessionId != nil ? "named(\(sessionId!))" : "default"
        self.logger.debug("🛡️ [AppRestriction] Restrictions applied to \(storeType): \(appTokens.count) apps, \(self.blockedAppsSelection.categoryTokens.count) categories")
        #endif
    }
    
    func removeRestrictions(for sessionId: String? = nil) {
        #if DEBUG
        let storeType = sessionId != nil ? "named(\(sessionId!))" : "default"
        logger.debug("🔓 [AppRestriction] Starting to remove restrictions from \(storeType)")
        #endif

        let targetStore = getManagedStore(for: sessionId)

        #if DEBUG
        logger.debug("   Clearing shield.applications...")
        #endif
        targetStore.shield.applications = nil

        #if DEBUG
        logger.debug("   Clearing shield.applicationCategories...")
        #endif
        targetStore.shield.applicationCategories = nil

        #if DEBUG
        logger.debug("✅ [AppRestriction] Restrictions removed successfully from \(storeType)")
        logger.debug("   Apps should now be accessible")
        #endif
    }
    
    // Vérifier s'il y a des sessions programmées actives (accessible publiquement)
    func hasActiveScheduledSession() -> Bool {
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        // Vérifier la queue d'activation des extensions
        if let activationQueue = suite?.array(forKey: "extension_activation_queue") as? [[String: Any]],
           !activationQueue.isEmpty {
            
            let now = Date().timeIntervalSince1970
            for session in activationQueue {
                if let triggerTime = session["extensionTriggeredAt"] as? Double,
                   (now - triggerTime) < 300 { // Moins de 5 minutes
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - App Details & Names
    
    func getSelectedAppsDetails() async -> [AppDetail] {
        var details: [AppDetail] = []
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            let detail = AppDetail(
                token: token,
                displayName: "App sélectionnée",
                bundleIdentifier: app.bundleIdentifier ?? "",
                isApplication: true
            )
            details.append(detail)
        }
        return details
    }
    
    func getSelectedAppsNames() -> [String] {
        var names: [String] = []
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    func generateAppNamesFromSelection(_ selection: FamilyActivitySelection) -> [String] {
        var names: [String] = []
        for token in selection.applicationTokens {
            let app = Application(token: token)
            let bundleId = app.bundleIdentifier ?? "com.unknown.app"
            let name = bundleId.components(separatedBy: ".").last ?? "App"
            names.append(name.capitalized)
        }
        if !selection.categoryTokens.isEmpty {
            names.append(contentsOf: Array(repeating: "Catégorie", count: selection.categoryTokens.count))
        }
        return names.isEmpty ? ["Apps sélectionnées"] : names
    }
    
    func isAppSelected(bundleIdentifier: String) -> Bool {
        for token in blockedAppsSelection.applicationTokens {
            let app = Application(token: token)
            if app.bundleIdentifier == bundleIdentifier { return true }
        }
        return false
    }
    
    func updateAppsSelectionWithDetails(_ selection: FamilyActivitySelection) {
        blockedAppsSelection = selection
        selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        
        Task { [weak self] in
            guard let self = self else { return }
            let appDetails = await self.getSelectedAppsDetails()
            let appNames = appDetails.map { $0.displayName }
            await MainActor.run {
                #if DEBUG
                debugPrint("📱 [AppRestriction] Apps sélectionnées: \(appNames.joined(separator: ", "))")
                #endif
            }
        }
        
        persistAppsSelection()
        delegate?.selectedAppsCountChanged(self.selectedAppsCount)
        delegate?.appsSelectionUpdated(selection)
    }
    
    // MARK: - Quick Challenge Support
    
    func getQuickChallengeConfiguration() -> (hasSelectedApps: Bool, appNames: [String], appCount: Int) {
        let hasSelectedApps = !self.blockedAppsSelection.applicationTokens.isEmpty || !self.blockedAppsSelection.categoryTokens.isEmpty
        
        if hasSelectedApps {
            let appNames = self.generateAppNamesFromSelection(self.blockedAppsSelection)
            let appCount = self.blockedAppsSelection.applicationTokens.count + self.blockedAppsSelection.categoryTokens.count
            return (true, appNames, appCount)
        } else {
            // Fallback vers une liste par défaut
            let defaultApps = ["Instagram", "TikTok", "Twitter", "Facebook", "YouTube"]
            return (false, defaultApps, defaultApps.count)
        }
    }
    
    // MARK: - Persistence
    
    private func persistAppsSelection() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self.blockedAppsSelection)
            UserDefaults.standard.set(data, forKey: "zenloop_apps_selection")
            UserDefaults.standard.set(self.selectedAppsCount, forKey: "zenloop_selected_apps_count")
            #if DEBUG
            self.logger.debug("💾 [AppRestriction] Selection persisted: \(self.selectedAppsCount) items")
            #endif
        } catch {
            UserDefaults.standard.set(self.selectedAppsCount, forKey: "zenloop_selected_apps_count")
            #if DEBUG
            self.logger.error("❌ [AppRestriction] Failed to persist selection: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func loadPersistedAppsSelection() {
        if let data = UserDefaults.standard.data(forKey: "zenloop_apps_selection") {
            do {
                let decoder = JSONDecoder()
                self.blockedAppsSelection = try decoder.decode(FamilyActivitySelection.self, from: data)
                self.selectedAppsCount = self.blockedAppsSelection.applicationTokens.count + self.blockedAppsSelection.categoryTokens.count
                #if DEBUG
                self.logger.debug("📥 [AppRestriction] Loaded persisted selection: \(self.selectedAppsCount) items")
                #endif
            } catch {
                self.selectedAppsCount = 0
                self.blockedAppsSelection = FamilyActivitySelection()
                #if DEBUG
                self.logger.error("❌ [AppRestriction] Failed to load selection: \(error.localizedDescription)")
                #endif
            }
        } else {
            self.selectedAppsCount = UserDefaults.standard.integer(forKey: "zenloop_selected_apps_count")
            if self.selectedAppsCount > 0 {
                // Réinitialiser si pas de données valides
                self.selectedAppsCount = 0
                UserDefaults.standard.set(0, forKey: "zenloop_selected_apps_count")
            }
            #if DEBUG
            self.logger.debug("📥 [AppRestriction] No persisted selection found, using default")
            #endif
        }
    }
    
    // MARK: - Validation & Diagnostics
    
    func validateConfiguration() -> Bool {
        let hasValidSelection = isAppsSelectionValid()
        let countMatches = selectedAppsCount == (blockedAppsSelection.applicationTokens.count + blockedAppsSelection.categoryTokens.count)
        return hasValidSelection && countMatches
    }
    
    func getDiagnosticsInfo() -> [String: Any] {
        return [
            "isAuthorized": isAuthorized,
            "selectedAppsCount": selectedAppsCount,
            "hasValidSelection": isAppsSelectionValid(),
            "applicationTokensCount": blockedAppsSelection.applicationTokens.count,
            "categoryTokensCount": blockedAppsSelection.categoryTokens.count
        ]
    }
}