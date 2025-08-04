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
        case 5..<12: return "Bonjour"
        case 12..<17: return "Bel après-midi"
        case 17..<21: return "Bonsoir"
        default: return "Bonne nuit"
        }
    }
    
    private var statusText: String {
        switch currentState {
        case .idle: return "Prêt pour un nouveau défi"
        case .active: return "Focus en cours"
        case .paused: return "Pause active"
        case .completed: return "Mission accomplie"
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