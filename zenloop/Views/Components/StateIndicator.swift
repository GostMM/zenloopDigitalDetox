//
//  StateIndicator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct StateIndicator: View {
    let currentState: ZenloopState
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(stateColor, lineWidth: 2)
                )
            
            Image(systemName: stateIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(stateColor)
                .scaleEffect(currentState == .active ? 1.1 : 1.0)
                .animation(
                    currentState == .active ?
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .easeOut(duration: 0.3),
                    value: currentState
                )
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
    
    private var stateIcon: String {
        switch currentState {
        case .idle: return "circle.dashed"
        case .active: return "flame.fill"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        }
    }
}