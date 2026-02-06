//
//  zenloopApp.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import DeviceActivity
import UserNotifications
import Firebase
import FamilyControls
import ManagedSettings
import os.log

@main
struct zenloopApp: App {
    @UIApplicationDelegateAdaptor(ZenloopAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    @StateObject private var quickActionsBridge = QuickActionsBridge.shared
    @State private var showSplash = true
    @State private var isFirebaseConfigured = false

    init() {
        // OPTIMIZATION: Firebase configuration moved to async Task
        // This prevents blocking the main thread before first frame

        // ✅ CRITIQUE: Initialiser le GlobalShieldManager (store par défaut)
        // C'EST LUI qui gère la persistance !
        Task { @MainActor in
            _ = GlobalShieldManager.shared
        }

        // ✅ NOUVEAU: Initialiser BlockController pour écouter les demandes de blocage
        // depuis l'extension DeviceActivityReport
        _ = BlockController.shared

        // Écouter les Darwin Notifications (inter-process)
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, name, _, _ in
                if let notificationName = name?.rawValue as String? {
                    if notificationName == "com.app.zenloop.ApplyBlock" {
                        print("📬 [MAIN APP] Received Darwin notification: ApplyBlock")

                        // Traiter le blocage depuis App Group
                        DispatchQueue.main.async {
                            if let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
                               let blockId = suite.string(forKey: "pending_apply_block_id") {
                                print("🔒 [MAIN APP] Applying block: \(blockId)")
                                // Appliquer depuis ici
                                Self.applyBlockStatic(blockId: blockId)

                                // Nettoyer
                                suite.removeObject(forKey: "pending_apply_block_id")
                                suite.removeObject(forKey: "pending_apply_block_timestamp")
                                suite.synchronize()
                            }
                        }
                    }

                    // ✅ NOUVEAU: Écouter les demandes de blocage depuis Report Extension
                    if notificationName == "com.app.zenloop.RequestBlockFromReport" {
                        print("📬 [MAIN APP] Received block request from Report Extension")

                        DispatchQueue.main.async {
                            Self.processReportExtensionBlockRequest()
                        }
                    }
                }
            },
            "com.app.zenloop.ApplyBlock" as CFString,
            nil,
            .deliverImmediately
        )

        // ✅ Écouter aussi les demandes depuis Report Extension
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, name, _, _ in
                if let notificationName = name?.rawValue as String?,
                   notificationName == "com.app.zenloop.RequestBlockFromReport" {
                    print("📬 [MAIN APP] Received block request from Report Extension")

                    DispatchQueue.main.async {
                        Self.processReportExtensionBlockRequest()
                    }
                }
            },
            "com.app.zenloop.RequestBlockFromReport" as CFString,
            nil,
            .deliverImmediately
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(quickActionsBridge)

                // Splash Screen animé par-dessus
                if showSplash {
                    SplashScreenView(isActive: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
                .onAppear {
                    // 🌟 Compter l'ouverture de l'app pour le système de notation
                    AppRatingManager.shared.recordAppLaunch()

                    // ✅ CRUCIAL: Écouter les URL schemes depuis le SceneDelegate
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("HandleURLScheme"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let url = notification.userInfo?["url"] as? URL {
                            print("🔗 [APP] Received URL from notification: \(url.absoluteString)")
                            self.handleURL(url)
                        }
                    }

                    // 🎧 NOUVEAU: Démarrer l'écoute des commandes depuis l'extension
                    Task { @MainActor in
                        BlockCommandCoordinator.shared.startMonitoring()
                    }

                    // 🚀 CRUCIAL: Activer le Monitor Extension pour qu'il puisse traiter les blocages
                    MonitorActivator.shared.activateMonitor()

                    // ✅ CRUCIAL: Vérifier IMMÉDIATEMENT s'il y a un block en attente
                    checkAndApplyPendingBlocks()

                    // ✅ NOUVEAU: Vérifier s'il y a des pending blocks depuis l'extension
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        BlockController.shared.processPendingBlockRequest()
                    }

                    // Initialisation asynchrone pour éviter les lags au démarrage
                    Task {
                        // OPTIMIZATION: Configure Firebase asynchronously (200-500ms saved on main thread)
                        if !isFirebaseConfigured {
                            FirebaseApp.configure()
                            isFirebaseConfigured = true
                        }

                        // Firebase: Enregistrer le device au premier lancement
                        await FirebaseManager.shared.registerDeviceOnFirstLaunch()

                        // Clean up obsolete App Group keys
                        cleanupAppGroup()

                        // REMOVED: Debug code that forced PurchaseManager initialization
                        // This was causing 200-500ms delay at startup
                        // PurchaseManager should be lazy-loaded only when needed

                        // REMOVED: Ne plus demander autorisation Screen Time automatiquement
                        // Les permissions seront demandées dans l'onboarding uniquement

                        // NOUVEAU: Précharger les données stats en arrière-plan
                        preloadStatsData()

                        // DISABLED: Debug code that creates test payloads and polls App Group
                        // try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 secondes
                        // testExtensionResponse()
                        // startExtensionMonitoring()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        print("📱 App entered background")
                        // Update Quick Actions when app goes to background
                        quickActionsManager.updateOnAppBackground()
                        // DISABLED: Test code that was creating payload_test_extension_* keys
                        // scheduleAppTerminationTest()
                    case .inactive:
                        print("📱 App became inactive")
                    case .active:
                        print("📱 App became active")

                        // 🔥 CRITIQUE: Vérifier les événements DeviceActivity en premier
                        // Cela permet de traiter les fins de session qui se sont produites en arrière-plan
                        ZenloopManager.shared.deviceActivityCoordinator.checkDeviceActivityEvents()

                        // Check if any session expired while in background
                        ZenloopManager.shared.challengeStateManager.checkAndCompleteExpiredSession()
                        // Process any pending Quick Actions
                        quickActionsManager.processPendingAction()
                        // Process any pending widget actions
                        checkForWidgetActions()
                        // Firebase: Mettre à jour lastSeen
                        Task {
                            await FirebaseManager.shared.updateLastSeen()
                        }
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    // Handle URL schemes (Quick Actions + Affiliation)
                    handleURL(url)

                    // 🔗 Traiter les liens d'affiliation
                    Task {
                        await AffiliateManager.shared.processDeepLink(url: url)
                    }
                }
        }
    }
    
    func testExtensionResponse() {
        print("🧪 [APP] Starting extension test...")
        
        // Créer un DeviceActivity très court pour tester l'extension
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName("test_extension_\(UUID().uuidString)")
        
        // Créer un schedule de 10 minutes (pour être sûr que c'est assez long)
        let calendar = Calendar.current
        let now = Date()
        let startTime = calendar.date(byAdding: .minute, value: 1, to: now)! // Commence dans 1 minute
        let endTime = calendar.date(byAdding: .minute, value: 11, to: now)! // Se termine dans 11 minutes
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: calendar.component(.hour, from: startTime),
                minute: calendar.component(.minute, from: startTime)
            ),
            intervalEnd: DateComponents(
                hour: calendar.component(.hour, from: endTime),
                minute: calendar.component(.minute, from: endTime)
            ),
            repeats: false
        )
        
        // Sauvegarder un payload de test simple
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set("test_payload_data", forKey: "payload_\(activityName.rawValue)")
        suite?.synchronize()
        
        // Démarrer le monitoring
        do {
            try center.startMonitoring(activityName, during: schedule)
            print("🧪 [APP] Extension test started - monitoring for 10 minutes (starts in 1 minute)")
        } catch {
            print("🧪 [APP] Failed to start extension test: \(error)")
        }
    }
    
    func scheduleAppTerminationTest() {
        // Signaler à l'extension de tester sa connectivité
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        suite?.set(Date().timeIntervalSince1970, forKey: "test_extension_signal")
        suite?.set(true, forKey: "request_extension_test")
        suite?.synchronize()
        
        print("🧪 [APP] Extension test signal sent")
    }
    
    func startExtensionMonitoring() {
        // Surveiller l'extension status toutes les 2 secondes
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            let suite = UserDefaults(suiteName: "group.com.app.zenloop")
            
            // Vérifier si l'extension s'est initialisée
            if let timestamp = suite?.object(forKey: "extension_initialized_timestamp") as? Double {
                let initTime = Date(timeIntervalSince1970: timestamp)
                let status = suite?.string(forKey: "extension_status") ?? "unknown"
                
                print("📡 [APP] Extension status: \(status) at \(initTime)")
                
                // Extension detected - debug notification removed
                // sendAppNotification(
                //     title: "📡 EXTENSION DÉTECTÉE", 
                //     body: "Extension initialisée: \(status)"
                // )
                
                // Arrêter le timer après avoir détecté l'extension
                timer.invalidate()
            }
        }
    }
    
    // Extension debug notifications disabled - function commented out
    /*
    func sendAppNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "app_notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur notification app: \(error)")
            }
        }
    }
    */
    
    // MARK: - App Group Cleanup

    func cleanupAppGroup() {
        // OPTIMIZATION: Only run cleanup weekly to avoid I/O overhead at every launch
        let lastCleanupKey = "last_appgroup_cleanup"
        let weekInSeconds: TimeInterval = 7 * 24 * 60 * 60

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("⚠️ [CLEANUP] Cannot access App Group")
            return
        }

        // Check if cleanup is needed
        let lastCleanup = suite.double(forKey: lastCleanupKey)
        let timeSinceLastCleanup = Date().timeIntervalSince1970 - lastCleanup

        if lastCleanup > 0 && timeSinceLastCleanup < weekInSeconds {
            print("⏭️ [CLEANUP] Skipping - last cleanup was \(Int(timeSinceLastCleanup / 3600)) hours ago")
            return
        }

        let allKeys = Array(suite.dictionaryRepresentation().keys)
        var removedCount = 0

        print("🧹 [CLEANUP] Starting App Group cleanup - \(allKeys.count) total keys")

        // Keys to remove
        let keysToRemove = allKeys.filter { key in
            // Remove all test extension payloads
            if key.hasPrefix("payload_test_extension_") {
                return true
            }

            // Remove obsolete test keys
            if key == "test_extension_signal" || key == "request_extension_test" {
                return true
            }

            return false
        }

        // Remove the keys
        for key in keysToRemove {
            suite.removeObject(forKey: key)
            removedCount += 1
        }

        // Update last cleanup timestamp
        suite.set(Date().timeIntervalSince1970, forKey: lastCleanupKey)
        suite.synchronize()

        print("✅ [CLEANUP] Removed \(removedCount) obsolete keys")
        print("📊 [CLEANUP] Remaining keys: \(allKeys.count - removedCount)")
    }

    // NOUVEAU: Préchargement des données stats
    func preloadStatsData() {
        Task(priority: .background) {
            print("📊 [PRELOAD] Début préchargement données stats...")
            
            // Précharger les UserDefaults des statistiques
            let appGroup = "group.com.app.zenloop"
            let reportKey = "deviceActivityReport"
            let savedKey = "zenloop.savedSeconds"
            
            // Charger les données partagées en arrière-plan pour les mettre en cache
            let shared = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
            let _ = shared.data(forKey: reportKey) // Charge en cache
            let _ = UserDefaults.standard.double(forKey: savedKey) // Charge en cache
            
            print("📊 [PRELOAD] Données stats UserDefaults préchargées")
        }
    }
    
    func handleURL(_ url: URL) {
        print("🔗 [APP] Received URL: \(url.absoluteString)")

        // Handle URL schemes for Quick Actions or deep linking
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              scheme == "zenloop" else {
            return
        }

        // ✅ NEW: Gérer save-block depuis Report Extension (via URL scheme)
        if components.host == "save-block" {
            print("💾 [DEEP_LINK] Received save-block request from Report Extension")

            let queryItems = components.queryItems ?? []

            guard let appName = queryItems.first(where: { $0.name == "appName" })?.value,
                  let durationStr = queryItems.first(where: { $0.name == "duration" })?.value,
                  let duration = TimeInterval(durationStr),
                  let activityName = queryItems.first(where: { $0.name == "activityName" })?.value,
                  let tokenBase64 = queryItems.first(where: { $0.name == "tokenData" })?.value,
                  let tokenData = Data(base64Encoded: tokenBase64) else {
                print("❌ [DEEP_LINK] Missing or invalid parameters in save-block URL")
                return
            }

            print("✅ [DEEP_LINK] Parsed: \(appName), \(Int(duration/60))min, activityName: \(activityName)")
            print("   → Token data: \(tokenData.count) bytes")

            // Traiter le blocage depuis l'app principale (qui a les permissions d'écriture)
            Self.handleSaveBlockRequest(
                appName: appName,
                duration: duration,
                activityName: activityName,
                tokenData: tokenData
            )
            return
        }

        // ✅ NEW: Gérer unblock depuis Report Extension (via URL scheme)
        if components.host == "unblock" {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🔓 [DEEP_LINK] ========== UNBLOCK URL RECEIVED ==========")
            print("🔓 [DEEP_LINK] Full URL: \(url.absoluteString)")
            print("🔓 [DEEP_LINK] Scheme: \(url.scheme ?? "nil")")
            print("🔓 [DEEP_LINK] Host: \(url.host ?? "nil")")

            let queryItems = components.queryItems ?? []
            print("🔓 [DEEP_LINK] Query items count: \(queryItems.count)")

            for (index, item) in queryItems.enumerated() {
                print("   → Item \(index): name=\(item.name), value=\(item.value?.prefix(50) ?? "nil")...")
            }

            print("🔍 [DEEP_LINK] Extracting parameters...")

            guard let blockId = queryItems.first(where: { $0.name == "blockId" })?.value else {
                print("❌❌❌ [DEEP_LINK] ERROR: Missing blockId parameter!")
                return
            }
            print("   ✅ blockId: \(blockId)")

            guard let appName = queryItems.first(where: { $0.name == "appName" })?.value else {
                print("❌❌❌ [DEEP_LINK] ERROR: Missing appName parameter!")
                return
            }
            print("   ✅ appName: \(appName)")

            guard let tokenBase64 = queryItems.first(where: { $0.name == "tokenData" })?.value else {
                print("❌❌❌ [DEEP_LINK] ERROR: Missing tokenData parameter!")
                return
            }
            print("   ✅ tokenBase64 length: \(tokenBase64.count) chars")
            print("   → tokenBase64 preview: \(tokenBase64.prefix(50))...")

            print("🔍 [DEEP_LINK] Decoding base64 to Data...")
            guard let tokenData = Data(base64Encoded: tokenBase64) else {
                print("❌❌❌ [DEEP_LINK] ERROR: Failed to decode base64 to Data!")
                print("   → Base64 string might be invalid")
                return
            }

            print("✅✅✅ [DEEP_LINK] All parameters parsed successfully!")
            print("   → blockId: \(blockId)")
            print("   → appName: \(appName)")
            print("   → tokenData: \(tokenData.count) bytes")

            print("🔍 [DEEP_LINK] Calling handleUnblockRequest()...")

            // Traiter le déblocage depuis l'app principale
            Self.handleUnblockRequest(
                blockId: blockId,
                appName: appName,
                tokenData: tokenData
            )

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        // ✅ CRUCIAL: Gérer apply-block depuis Report Extension
        if components.host == "apply-block" {
            let queryItems = components.queryItems ?? []
            if let blockId = queryItems.first(where: { $0.name == "id" })?.value {
                print("🔒 [DEEP_LINK] Applying block from Report Extension: \(blockId)")

                // IMPORTANT: Traiter depuis App Group, pas depuis BlockManager
                // Car le BlockManager pourrait ne pas encore avoir le block
                // Il faut lire depuis les clés pending_block_*
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Self.processReportExtensionBlockRequest()
                }
            }
            return
        }
        
        // Handle special widget actions with parameters
        if components.host == "quickfocus" {
            // Check for duration parameter
            let queryItems = components.queryItems ?? []
            let duration = queryItems.first(where: { $0.name == "duration" })?.value
            let sessionName = queryItems.first(where: { $0.name == "name" })?.value
            
            handleQuickFocusWithParameters(duration: duration, sessionName: sessionName)
            return
        }
        
        // Handle session control actions directly
        switch components.host {
        case "pause":
            handleSessionControl(.pause)
            return
        case "resume":
            handleSessionControl(.resume)
            return
        case "stop":
            handleSessionControl(.stop)
            return
        case "newsession":
            handleSessionControl(.start)
            return
        case "block-app":
            // Trigger immediate processing of pending app block
            ZenloopManager.shared.checkForPendingAppBlock()
            return
        default:
            break
        }
        
        // Map URL hosts to Quick Action types
        let actionType: QuickActionType?
        
        switch components.host {
        case "startscheduled":
            actionType = .startScheduled
        case "stats", "viewstats":
            actionType = .viewStats
        case "emergency":
            actionType = .emergency
        case "dontdelete", "retention":
            actionType = .dontDelete
        default:
            actionType = nil
        }
        
        guard let action = actionType else {
            print("❌ [DEEP_LINK] Unknown URL host: \(components.host ?? "nil")")
            return
        }
        
        // Create shortcut item for the action
        let shortcutItem = UIApplicationShortcutItem(
            type: action.rawValue,
            localizedTitle: action.title,
            localizedSubtitle: action.subtitle,
            icon: action.iconType,
            userInfo: ["source": "deeplink"] as [String: NSSecureCoding]
        )
        
        // Handle the action through the Quick Actions system
        quickActionsManager.handleQuickAction(shortcutItem)
    }
    
    func handleQuickFocusWithParameters(duration: String?, sessionName: String?) {
        print("🎯 [WIDGET_ACTION] Quick Focus with duration: \(duration ?? "nil"), name: \(sessionName ?? "nil")")
        
        let focusDuration = Int(duration ?? "25") ?? 25
        let title = sessionName ?? "Widget Focus Session"
        
        // Create a custom challenge with widget parameters
        let widgetChallenge = ZenloopChallenge(
            id: "widget-focus-\(UUID().uuidString)",
            title: title,
            description: "Session démarrée depuis le widget",
            duration: TimeInterval(focusDuration * 60), // Convert to seconds
            difficulty: .medium,
            startTime: Date(),
            isActive: true
        )
        
        // Delay execution to ensure ZenloopManager is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ZenloopManager.shared.startSavedCustomChallenge(widgetChallenge)
            
            // Send haptic feedback for widget interaction
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    func checkAndApplyPendingBlocks() {
        print("🔍 [CHECK_PENDING] Checking for pending blocks...")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop"),
              let blockId = suite.string(forKey: "pending_apply_block_id") else {
            print("   → No pending blocks")
            return
        }

        let timestamp = suite.double(forKey: "pending_apply_block_timestamp")
        let age = Date().timeIntervalSince1970 - timestamp

        // Si le block a plus de 5 minutes, l'ignorer
        guard age < 300 else {
            print("   → Pending block too old (\(Int(age))s), ignoring")
            suite.removeObject(forKey: "pending_apply_block_id")
            suite.removeObject(forKey: "pending_apply_block_timestamp")
            suite.synchronize()
            return
        }

        print("🚨 [CHECK_PENDING] Found pending block: \(blockId) (age: \(Int(age))s)")
        print("   → Applying NOW...")

        // Appliquer le block
        Self.applyBlockStatic(blockId: blockId)

        // Nettoyer
        suite.removeObject(forKey: "pending_apply_block_id")
        suite.removeObject(forKey: "pending_apply_block_timestamp")
        suite.synchronize()

        print("✅ [CHECK_PENDING] Pending block applied and cleared")
    }

    static func applyBlockStatic(blockId: String) {
        print("🔒 [APPLY_BLOCK] Starting block application for ID: \(blockId)")

        let blockManager = BlockManager()
        guard let block = blockManager.getBlock(id: blockId) else {
            print("❌ [APPLY_BLOCK] Block not found: \(blockId)")
            return
        }

        #if os(iOS)
        // Décoder le token
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [APPLY_BLOCK] Failed to decode token")
            return
        }

        print("✅ [APPLY_BLOCK] Token decoded for: \(block.appName)")

        // ✅ UTILISER LE GLOBAL SHIELD MANAGER (store par défaut)
        Task { @MainActor in
            GlobalShieldManager.shared.addBlock(
                token: token,
                blockId: blockId,
                appName: block.appName
            )
        }

        print("🛡️ [APPLY_BLOCK] Block added to global shield")

        // Notification de succès
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("app_blocked_title", comment: "App blocked notification title")
        content.body = String(format: NSLocalizedString("app_blocked_body", comment: "App blocked notification body"), block.appName, Int(block.originalDuration/60))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "block_applied_\(blockId)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [APPLY_BLOCK] Notification error: \(error)")
            }
        }
        #endif
    }

    // ✅ NEW: Traiter les demandes de déblocage via URL scheme
    static func handleUnblockRequest(blockId: String, appName: String, tokenData: Data) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔓 [MAIN_APP] ========== UNBLOCK HANDLER CALLED ==========")
        print("🔓 [MAIN_APP] App: \(appName)")
        print("🔓 [MAIN_APP] BlockID: \(blockId)")
        print("🔓 [MAIN_APP] Token Data: \(tokenData.count) bytes")
        print("🔓 [MAIN_APP] Current thread: \(Thread.current)")

        #if os(iOS)
        // 1. Décoder le token pour validation
        print("🔍 [MAIN_APP] Step 1: Decoding token from data...")
        print("   → TokenData bytes: \(tokenData.count)")

        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData) else {
            print("❌❌❌ [MAIN_APP] ERROR: Failed to decode FamilyActivitySelection!")
            print("   → TokenData might be corrupted")
            print("   → TokenData hex: \(tokenData.prefix(50).map { String(format: "%02x", $0) }.joined())")
            return
        }

        print("✅ [MAIN_APP] FamilyActivitySelection decoded")
        print("   → Application tokens count: \(selection.applicationTokens.count)")

        guard let token = selection.applicationTokens.first else {
            print("❌❌❌ [MAIN_APP] ERROR: No application token in selection!")
            print("   → Selection has 0 tokens")
            return
        }

        print("✅✅✅ [MAIN_APP] Token decoded successfully!")
        print("   → Token obtained from selection")

        // 2. Retirer le shield via GlobalShieldManager
        print("🔍 [MAIN_APP] Step 2: Removing shield via GlobalShieldManager...")
        print("   → Calling GlobalShieldManager.shared.removeBlock()")
        print("   → This will update the global ManagedSettingsStore")

        Task { @MainActor in
            print("🔍 [MAIN_APP] → Running on MainActor...")
            GlobalShieldManager.shared.removeBlock(
                token: token,
                blockId: blockId,
                appName: appName
            )
            print("✅✅✅ [MAIN_APP] GlobalShieldManager.removeBlock() COMPLETED!")
            print("   → Shield should be removed now")
        }

        // 3. Supprimer le block du BlockManager
        print("🔍 [MAIN_APP] Step 3: Removing block from BlockManager...")
        let blockManager = BlockManager()

        // Vérifier si le block existe avant de le supprimer
        if let existingBlock = blockManager.getBlock(id: blockId) {
            print("   → Block found in storage:")
            print("   → Name: \(existingBlock.appName)")
            print("   → Status: \(existingBlock.status.rawValue)")
            print("   → StoreName: \(existingBlock.storeName)")
        } else {
            print("⚠️ [MAIN_APP] Block not found in BlockManager (might be already removed)")
        }

        blockManager.removeBlock(id: blockId)
        print("✅ [MAIN_APP] BlockManager.removeBlock() called")

        // Vérifier que le block a bien été supprimé
        let remainingBlocks = blockManager.getActiveBlocks()
        print("   → Remaining active blocks: \(remainingBlocks.count)")
        for block in remainingBlocks {
            print("     - \(block.appName) (\(block.status.rawValue))")
        }

        print("💾 [MAIN_APP] Block removed from persistence")

        // 4. Nettoyer aussi le store individuel (au cas où)
        print("🔍 [MAIN_APP] Step 4: Cleaning individual store as fallback...")
        if let block = blockManager.getAllBlocks().first(where: { $0.id == blockId }) {
            let store = ManagedSettingsStore(named: .init(block.storeName))
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.clearAllSettings()
            print("✅ [MAIN_APP] Individual store cleared: \(block.storeName)")
        } else {
            print("⚠️ [MAIN_APP] Block not found, cannot clear individual store")
        }

        // 5. Notification de confirmation
        print("🔍 [MAIN_APP] Step 5: Sending notification...")
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("app_unblocked_title", comment: "App unblocked notification title")
        content.body = String(format: NSLocalizedString("app_unblocked_body", comment: "App unblocked notification body"), appName)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "unblock_\(blockId)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [MAIN_APP] Notification error: \(error)")
            } else {
                print("✅ [MAIN_APP] Notification scheduled")
            }
        }

        print("🔓 [MAIN_APP] ========== UNBLOCK HANDLER COMPLETE ==========")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
    }

    // ✅ NEW: Traiter les demandes de blocage via URL scheme
    static func handleSaveBlockRequest(appName: String, duration: TimeInterval, activityName: String, tokenData: Data) {
        let logger = Logger(subsystem: "com.app.zenloop", category: "SaveBlock")

        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        logger.critical("🔐 [SAVE_BLOCK] ========== MAIN APP SAVE REQUEST ==========")
        logger.critical("🔐 [SAVE_BLOCK] App: \(appName)")
        logger.critical("🔐 [SAVE_BLOCK] Duration: \(Int(duration/60)) minutes")
        logger.critical("🔐 [SAVE_BLOCK] Activity: \(activityName)")
        logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔐 [SAVE_BLOCK] ========== MAIN APP SAVE REQUEST ==========")
        print("🔐 [SAVE_BLOCK] App: \(appName)")
        print("🔐 [SAVE_BLOCK] Duration: \(Int(duration/60))min")
        print("🔐 [SAVE_BLOCK] ActivityName: \(activityName)")
        print("🔐 [SAVE_BLOCK] Token Data: \(tokenData.count) bytes")

        #if os(iOS)
        // 1. Décoder le token pour validation
        print("🔍 [SAVE_BLOCK] Step 1: Decoding token...")
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [SAVE_BLOCK] Failed to decode token")
            return
        }

        print("✅ [SAVE_BLOCK] Token decoded successfully")
        print("   → Token obtained from selection")

        // 1.5. VÉRIFIER L'ÉTAT ACTUEL DU STORE AVANT DE SAUVEGARDER
        print("🔍 [SAVE_BLOCK] Step 1.5: Checking current DEFAULT store state...")
        let checkStore = ManagedSettingsStore()
        let currentBlockedInStore = checkStore.shield.applications?.count ?? 0
        print("🔐 [SAVE_BLOCK] Current blocked apps in DEFAULT store: \(currentBlockedInStore)")

        // 2. Sauvegarder le block dans BlockManager (l'app a les permissions!)
        print("🔍 [SAVE_BLOCK] Step 2: Saving block to BlockManager...")
        let blockManager = BlockManager()

        // Vérifier si ce block existe déjà
        let existingBlocks = blockManager.getAllBlocks()
        print("🔐 [SAVE_BLOCK] Current blocks in BlockManager: \(existingBlocks.count)")
        for existingBlock in existingBlocks {
            print("   → \(existingBlock.appName) | Status: \(existingBlock.status.rawValue) | ID: \(existingBlock.id)")
        }

        let block = blockManager.addBlock(
            appName: appName,
            duration: duration,
            tokenData: tokenData,
            context: "FullStatsPageView (URL Scheme)"
        )

        print("💾 [SAVE_BLOCK] Block saved with ID: \(block.id)")

        // ✅ CRUCIAL: Stocker le mapping activityName → blockId pour le Monitor
        logger.critical("🔗 [SAVE_BLOCK] Storing activityName → blockId mapping")
        logger.critical("   → Activity: \(activityName)")
        logger.critical("   → BlockID: \(block.id)")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.critical("❌ [SAVE_BLOCK] Cannot store mapping - no App Group access")
            return
        }

        suite.set(block.id, forKey: "blockId_for_activity_\(activityName)")
        suite.synchronize()

        logger.critical("✅ [SAVE_BLOCK] Mapping stored: blockId_for_activity_\(activityName) = \(block.id)")

        // Vérifier combien de blocks on a maintenant
        let updatedBlocks = blockManager.getAllBlocks()
        print("🔐 [SAVE_BLOCK] After save, blocks in BlockManager: \(updatedBlocks.count)")

        // 3. ✅ PAS BESOIN D'APPLIQUER LE SHIELD ICI!
        // L'extension l'a déjà appliqué dans le store par défaut
        // On sauvegarde juste les métadonnées pour la persistence
        print("🔍 [SAVE_BLOCK] Step 3: Checking if shield needs to be applied...")
        print("✅ [SAVE_BLOCK] Shield already applied by extension")
        print("   → Extension applied shield to DEFAULT store BEFORE sending URL")
        print("   → Main app is ONLY saving metadata (no re-blocking)")

        // 3.5. VÉRIFIER L'ÉTAT DU STORE APRÈS SAUVEGARDE
        print("🔍 [SAVE_BLOCK] Step 3.5: Verifying DEFAULT store state after save...")
        let verifyStore = ManagedSettingsStore()
        let afterBlockedInStore = verifyStore.shield.applications?.count ?? 0
        print("🔐 [SAVE_BLOCK] After save, blocked apps in DEFAULT store: \(afterBlockedInStore)")

        if afterBlockedInStore != currentBlockedInStore {
            print("⚠️⚠️⚠️ [SAVE_BLOCK] STORE COUNT CHANGED!")
            print("   → Before: \(currentBlockedInStore)")
            print("   → After: \(afterBlockedInStore)")
            print("   → Something modified the store during save!")
        } else {
            print("✅ [SAVE_BLOCK] Store count unchanged (good - no duplicate blocking)")
        }

        // 4. Programmer le déblocage automatique
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⏰ [SAVE_BLOCK] ========== SCHEDULING AUTO-UNBLOCK ==========")

        let minimumDuration: TimeInterval = 16 * 60 // 16 minutes minimum pour DeviceActivity (Apple requirement)

        if duration >= minimumDuration {
            // ✅ Durée >= 16min : Utiliser DeviceActivity (fonctionne en background)
            logger.critical("⏰ [SAVE_BLOCK] Duration >= 16min, using DeviceActivity")

            let center = DeviceActivityCenter()
            let deviceActivityName = DeviceActivityName(activityName)
            let now = Date()
            let calendar = Calendar.current

            // ✅ IMPORTANT: Démarrer dans 1 seconde (contourner le problème "now")
            let startTime = now.addingTimeInterval(1)
            let endTime = now.addingTimeInterval(duration)

            let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startTime)
            let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endTime)

            logger.critical("⏰ [SAVE_BLOCK] Now: \(now)")
            logger.critical("⏰ [SAVE_BLOCK] Start: \(startComponents.hour ?? 0):\(String(format: "%02d", startComponents.minute ?? 0)):\(String(format: "%02d", startComponents.second ?? 0))")
            logger.critical("⏰ [SAVE_BLOCK] End: \(endComponents.hour ?? 0):\(String(format: "%02d", endComponents.minute ?? 0)):\(String(format: "%02d", endComponents.second ?? 0))")
            logger.critical("⏰ [SAVE_BLOCK] Total duration: \(Int(duration))s (\(Int(duration/60))min)")

            let schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )

            logger.critical("📅 [SAVE_BLOCK] DeviceActivitySchedule created (repeats: false)")

            do {
                logger.critical("🚀 [SAVE_BLOCK] Calling center.startMonitoring()...")
                try center.startMonitoring(deviceActivityName, during: schedule)
                logger.critical("✅✅✅ [SAVE_BLOCK] DeviceActivity.startMonitoring() SUCCESS!")
                logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                logger.critical("🎯 [SAVE_BLOCK] Monitor will call intervalDidStart in ~1 second")
                logger.critical("🎯 [SAVE_BLOCK] Monitor will call intervalDidEnd at: \(endTime)")
                logger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("✅ [SAVE_BLOCK] DeviceActivity scheduled for auto-unblock")
            } catch {
                logger.critical("❌❌❌ [SAVE_BLOCK] DeviceActivity failed: \(error.localizedDescription)")
                logger.critical("⚠️ [SAVE_BLOCK] Falling back to Timer")
                print("❌ [SAVE_BLOCK] DeviceActivity failed, using Timer fallback")
                scheduleTimerUnblock(blockId: block.id, duration: duration, appName: appName, tokenData: tokenData)
            }
        } else {
            // ⚠️ Durée < 16min : DeviceActivity ne supporte pas, utiliser Timer
            logger.critical("⚠️ [SAVE_BLOCK] Duration < 16min (\(Int(duration/60))min)")
            logger.critical("⚠️ [SAVE_BLOCK] DeviceActivity minimum is 16min, using Timer fallback")
            logger.critical("⚠️ [SAVE_BLOCK] NOTE: Timer won't work if app is closed!")
            print("⚠️ [SAVE_BLOCK] Duration too short for DeviceActivity (< 16min)")
            print("⚠️ [SAVE_BLOCK] Using Timer (requires app to stay open)")
            scheduleTimerUnblock(blockId: block.id, duration: duration, appName: appName, tokenData: tokenData)
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 5. Notification de succès
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("app_blocked_title", comment: "App blocked notification title")
        content.body = String(format: NSLocalizedString("app_blocked_body", comment: "App blocked notification body"), appName, Int(duration/60))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "block_saved_\(block.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [SAVE_BLOCK] Notification error: \(error)")
            }
        }

        print("🔐 [SAVE_BLOCK] ========================================")
        print("✅ [SAVE_BLOCK] BLOCK REQUEST COMPLETED SUCCESSFULLY")
        print("🔐 [SAVE_BLOCK] ========================================")
        #endif
    }

    /// Fallback pour les durées < 15min : utiliser un Timer local
    static func scheduleTimerUnblock(blockId: String, duration: TimeInterval, appName: String, tokenData: Data) {
        let logger = Logger(subsystem: "com.app.zenloop", category: "TimerUnblock")

        logger.critical("⏰ [TIMER_UNBLOCK] Scheduling Timer for \(Int(duration))s")
        logger.critical("⏰ [TIMER_UNBLOCK] Block: \(appName) (ID: \(blockId))")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            logger.critical("🔓 [TIMER_UNBLOCK] ===== TIMER FIRED =====")
            logger.critical("🔓 [TIMER_UNBLOCK] Unblocking: \(appName)")

            // Décoder le token
            guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData),
                  let token = selection.applicationTokens.first else {
                logger.critical("❌ [TIMER_UNBLOCK] Failed to decode token")
                return
            }

            // Retirer du DEFAULT store
            let defaultStore = ManagedSettingsStore()
            var blockedApps = defaultStore.shield.applications ?? Set()
            let beforeCount = blockedApps.count

            blockedApps.remove(token)
            let afterCount = blockedApps.count

            defaultStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps

            logger.critical("✅ [TIMER_UNBLOCK] Removed from DEFAULT store:")
            logger.critical("   → Before: \(beforeCount) apps")
            logger.critical("   → After: \(afterCount) apps")
            logger.critical("   → Removed: \(beforeCount - afterCount) app(s)")

            // Supprimer du BlockManager
            let blockManager = BlockManager()
            blockManager.removeBlock(id: blockId)

            logger.critical("✅ [TIMER_UNBLOCK] App unblocked: \(appName)")

            // Notification
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("app_unblocked_title", comment: "")
            content.body = String(format: NSLocalizedString("app_unblocked_body", comment: ""), appName)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "timer_unblock_\(blockId)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            UNUserNotificationCenter.current().add(request)
        }

        print("⏰ [TIMER_UNBLOCK] Timer scheduled for \(Int(duration/60)) minutes")
    }

    // ✅ NOUVEAU: Traiter les demandes de blocage depuis Report Extension
    static func processReportExtensionBlockRequest() {
        print("🔍 [REPORT_BLOCK] Processing block request from Report Extension")

        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [REPORT_BLOCK] Cannot access App Group")
            return
        }

        // Lire les données du blocage
        guard let tokenData = suite.data(forKey: "pending_block_tokenData"),
              let appName = suite.string(forKey: "pending_block_appName"),
              let duration = suite.object(forKey: "pending_block_duration") as? TimeInterval,
              let storeName = suite.string(forKey: "pending_block_storeName"),
              let blockId = suite.string(forKey: "pending_block_id") else {
            print("⚠️ [REPORT_BLOCK] No pending block data found")
            return
        }

        print("📨 [REPORT_BLOCK] Found block request: \(appName) for \(Int(duration/60))min")

        #if os(iOS)
        // Décoder le token
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: tokenData),
              let token = selection.applicationTokens.first else {
            print("❌ [REPORT_BLOCK] Failed to decode token")
            return
        }

        print("✅ [REPORT_BLOCK] Token decoded successfully")

        // Créer le block dans BlockManager
        let blockManager = BlockManager()
        let block = blockManager.addBlock(
            appName: appName,
            duration: duration,
            tokenData: tokenData,
            context: "FullStatsPageView"
        )

        print("💾 [REPORT_BLOCK] Block saved: \(block.id)")

        // Appliquer le shield via GlobalShieldManager
        Task { @MainActor in
            GlobalShieldManager.shared.addBlock(
                token: token,
                blockId: block.id,
                appName: appName
            )
            print("🛡️ [REPORT_BLOCK] Shield applied for: \(appName)")
        }

        // Programmer le déblocage automatique
        let unblockTime = Date().timeIntervalSince1970 + duration
        let unblockInfo: [String: Any] = [
            "blockId": block.id,
            "storeName": storeName,
            "appName": appName,
            "unblockTime": unblockTime
        ]

        var scheduledUnblocks = suite.array(forKey: "scheduled_unblocks") as? [[String: Any]] ?? []
        scheduledUnblocks.append(unblockInfo)
        suite.set(scheduledUnblocks, forKey: "scheduled_unblocks")

        // Nettoyer les clés pending_block_*
        suite.removeObject(forKey: "pending_block_tokenData")
        suite.removeObject(forKey: "pending_block_appName")
        suite.removeObject(forKey: "pending_block_duration")
        suite.removeObject(forKey: "pending_block_storeName")
        suite.removeObject(forKey: "pending_block_id")
        suite.removeObject(forKey: "pending_block_timestamp")
        suite.synchronize()

        print("✅ [REPORT_BLOCK] Block request processed successfully")

        // Notification de confirmation
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("app_blocked_title", comment: "App blocked notification title")
        content.body = String(format: NSLocalizedString("app_blocked_body", comment: "App blocked notification body"), appName, Int(duration/60))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "block_from_report_\(block.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ [REPORT_BLOCK] Notification error: \(error)")
            }
        }
        #endif
    }

    func checkForWidgetActions() {
        // Check for pending widget actions in App Group
        let suite = UserDefaults(suiteName: "group.com.app.zenloop")
        
        if let widgetAction = suite?.object(forKey: "widget_pending_action") as? [String: Any],
           let actionURL = widgetAction["url"] as? String,
           let timestamp = widgetAction["timestamp"] as? TimeInterval {
            
            // Check if action is recent (less than 30 seconds old)
            let actionAge = Date().timeIntervalSince1970 - timestamp
            if actionAge < 30 {
                print("🔄 [WIDGET_ACTION] Processing pending action: \(actionURL)")
                
                // Clear the action and process it
                suite?.removeObject(forKey: "widget_pending_action")
                suite?.synchronize()
                
                if let url = URL(string: actionURL) {
                    handleURL(url)
                }
            }
        }
    }
    
    enum SessionControlAction {
        case start, pause, resume, stop
    }
    
    func handleSessionControl(_ action: SessionControlAction) {
        print("🎮 [SESSION_CONTROL] Handling action: \(action)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let manager = ZenloopManager.shared
            
            switch action {
            case .start:
                // Start a new quick session
                let quickChallenge = ZenloopChallenge(
                    id: "widget-quick-\(UUID().uuidString)",
                    title: "Widget Quick Session",
                    description: "Session démarrée depuis le widget",
                    duration: 25 * 60, // 25 minutes in seconds
                    difficulty: .medium,
                    startTime: Date(),
                    isActive: true
                )
                manager.startSavedCustomChallenge(quickChallenge)
                
            case .pause:
                manager.requestPause()
                
            case .resume:
                manager.resumeChallenge()
                
            case .stop:
                manager.stopCurrentChallenge()
            }
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
}
