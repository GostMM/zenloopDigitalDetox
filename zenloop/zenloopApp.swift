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

@main
struct zenloopApp: App {
    @UIApplicationDelegateAdaptor(ZenloopAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    @StateObject private var quickActionsBridge = QuickActionsBridge.shared
    @State private var showSplash = true

    init() {
        FirebaseApp.configure()
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
                    // Initialisation asynchrone pour éviter les lags au démarrage
                    Task {
                        // Firebase: Enregistrer le device au premier lancement
                        await FirebaseManager.shared.registerDeviceOnFirstLaunch()
                        
                        // DEBUG: Test PurchaseManager initialization (background)
                        print("🎯 App started - Testing PurchaseManager...")
                        let manager = PurchaseManager.shared
                        print("🎯 PurchaseManager instance created: \(manager)")
                        print("🎯 Current products count: \(manager.products.count)")
                        
                        // REMOVED: Ne plus demander autorisation Screen Time automatiquement
                        // Les permissions seront demandées dans l'onboarding uniquement
                        
                        // NOUVEAU: Précharger les données stats en arrière-plan
                        preloadStatsData()
                        
                        // TEST: Déclencher l'extension après 3 secondes pour voir si elle répond
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 secondes
                        testExtensionResponse()
                        
                        // Surveiller l'extension status périodiquement
                        startExtensionMonitoring()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        print("📱 App entered background")
                        // Update Quick Actions when app goes to background
                        quickActionsManager.updateOnAppBackground()
                        // Programmer une notification depuis l'extension pour tester
                        scheduleAppTerminationTest()
                    case .inactive:
                        print("📱 App became inactive")
                    case .active:
                        print("📱 App became active")
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
                    // Handle URL schemes if needed for Quick Actions
                    handleURL(url)
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
