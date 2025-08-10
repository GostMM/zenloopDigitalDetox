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
                    // Demander autorisation Screen Time de manière asynchrone
                    Task {
                        await AppUsageManager.shared.requestAuthorization()
                    }
                }
        }
    }
}
