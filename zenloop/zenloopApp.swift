//
//  zenloopApp.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import DeviceActivity
import UserNotifications

@main
struct zenloopApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Initialisation asynchrone pour éviter les lags au démarrage
                    Task {
                        // DEBUG: Test PurchaseManager initialization (background)
                        print("🎯 App started - Testing PurchaseManager...")
                        let manager = PurchaseManager.shared
                        print("🎯 PurchaseManager instance created: \(manager)")
                        print("🎯 Current products count: \(manager.products.count)")
                        
                        // Demander autorisation Screen Time de manière asynchrone
                        await AppUsageManager.shared.requestAuthorization()
                        
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
                        // Programmer une notification depuis l'extension pour tester
                        scheduleAppTerminationTest()
                    case .inactive:
                        print("📱 App became inactive")
                    case .active:
                        print("📱 App became active")
                    @unknown default:
                        break
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
                
                // Envoyer une notification depuis l'app pour confirmer
                sendAppNotification(
                    title: "📡 EXTENSION DÉTECTÉE",
                    body: "Extension initialisée: \(status)"
                )
                
                // Arrêter le timer après avoir détecté l'extension
                timer.invalidate()
            }
        }
    }
    
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
}
