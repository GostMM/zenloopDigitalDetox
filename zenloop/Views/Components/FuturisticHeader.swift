//
//  FuturisticHeader.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticHeader: View {
    let showContent: Bool
    let currentState: ZenloopState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentGreeting)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
            }
            
            Spacer()
            
            // Indicateur d'état compact
            StateIndicator(currentState: currentState)
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.5)
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
    
    private var currentGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "greeting_morning")
        case 12..<17: return String(localized: "greeting_afternoon")
        case 17..<21: return String(localized: "greeting_evening")
        default: return String(localized: "greeting_night")
        }
    }
    
    private var statusText: String {
        switch currentState {
        case .idle: return String(localized: "status_ready_new_challenge")
        case .active: return String(localized: "status_focus_in_progress")
        case .paused: return String(localized: "status_active_pause")
        case .completed: return String(localized: "status_mission_accomplished")
        }
    }
}