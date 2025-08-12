//
//  zenloopApp.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI

@main
struct zenloopApp: App {
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
                    }
                }
        }
    }
}
