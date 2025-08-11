//
//  MinimalHeader.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct MinimalHeader: View {
    let showContent: Bool
    let currentState: ZenloopState
    let isPremium: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentGreeting)
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
            }
            
            Spacer()
            
            // Badge PRO si premium
            if isPremium {
                ProBadge()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
            }
            
            // Indicateur d'état minimal
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(currentState == .active ? 1.3 : 1.0)
                .animation(
                    currentState == .active ?
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .easeOut(duration: 0.3),
                    value: currentState
                )
                .opacity(showContent ? 1 : 0)
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
    
    private var stateColor: Color {
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}