//
//  zenloopApp.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        #if DEBUG
        // Activer le mode debug Analytics pour voir les données immédiatement
        print("🔥 Firebase configuré en mode DEBUG")
        #endif
        
        return true
    }
}

@main
struct zenloopApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Demander autorisation Screen Time et charger données
                    Task {
                        await AppUsageManager.shared.requestAuthorization()
                    }
                }
        }
    }
}
