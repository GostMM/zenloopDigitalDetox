//
//  OptimizedBackground.swift
//  zenloop
//
//  Created for Performance Optimization - Lightweight version of IntenseBackground
//

import SwiftUI

struct OptimizedBackground: View {
    let currentState: ZenloopState
    let concentrationType: ConcentrationType?
    @State private var animateGlow = false
    
    init(currentState: ZenloopState, concentrationType: ConcentrationType? = nil) {
        self.currentState = currentState
        self.concentrationType = concentrationType
    }
    
    var body: some View {
        ZStack {
            // Background statique simple - pas d'animations lourdes
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .animation(.easeInOut(duration: 2), value: currentState)
            
            // UN SEUL gradient secondaire avec animation douce
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: secondaryGradientColors,
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .opacity(animateGlow ? 0.4 : 0.2)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGlow)
                .blendMode(.overlay)
        }
        .onAppear {
            animateGlow = true
        }
    }
    
    // MARK: - Colors (simplifié)
    
    private var gradientColors: [Color] {
        switch currentState {
        case .idle:
            return [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color.black
            ]
        case .active:
            return [
                Color(red: 0.15, green: 0.05, blue: 0.05),
                Color(red: 0.2, green: 0.1, blue: 0.1),
                Color.black
            ]
        case .paused:
            return [
                Color(red: 0.05, green: 0.15, blue: 0.15),
                Color(red: 0.1, green: 0.2, blue: 0.2),
                Color.black
            ]
        case .completed:
            return [
                Color(red: 0.1, green: 0.15, blue: 0.05),
                Color(red: 0.15, green: 0.2, blue: 0.1),
                Color.black
            ]
        }
    }
    
    private var secondaryGradientColors: [Color] {
        switch currentState {
        case .idle:
            return [Color.blue.opacity(0.3), Color.purple.opacity(0.2), Color.clear]
        case .active:
            return [Color.orange.opacity(0.3), Color.red.opacity(0.2), Color.clear]
        case .paused:
            return [Color.mint.opacity(0.3), Color.cyan.opacity(0.2), Color.clear]
        case .completed:
            return [Color.green.opacity(0.3), Color.mint.opacity(0.2), Color.clear]
        }
    }
}

#Preview {
    OptimizedBackground(currentState: .idle)
}