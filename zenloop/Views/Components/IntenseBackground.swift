//
//  IntenseBackground.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct IntenseBackground: View {
    let currentState: ZenloopState
    let concentrationType: ConcentrationType?
    @State private var animateGlow = false
    @State private var animateParticles = false
    @State private var animateWaves = false
    
    init(currentState: ZenloopState, concentrationType: ConcentrationType? = nil) {
        self.currentState = currentState
        self.concentrationType = concentrationType
    }
    
    var body: some View {
        ZStack {
            // Background image pour type de concentration (si applicable)
            if let concentrationType = concentrationType {
                AsyncImage(url: Bundle.main.url(forResource: concentrationType.backgroundImage, withExtension: "jpg")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .overlay(
                            // Overlay sombre pour maintenir la lisibilité
                            Rectangle()
                                .fill(.black.opacity(0.6))
                                .ignoresSafeArea()
                        )
                } placeholder: {
                    // Fallback vers gradient normal
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            } else {
                // Background principal sombre avec gradients multiples
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 3), value: currentState)
                    
                    // Gradient diagonal secondaire
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: secondaryGradientColors,
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .opacity(animateGlow ? 0.6 : 0.3)
                        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGlow)
                        .blendMode(.overlay)
                }
            }
            
            // Vagues de lumière en arrière-plan - contenues
            GeometryReader { geometry in
                ForEach(0..<3, id: \.self) { waveIndex in
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    waveColor.opacity(0.15),
                                    waveColor.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: min(geometry.size.width, geometry.size.height) * 0.6
                            )
                        )
                        .frame(
                            width: min(geometry.size.width * 1.2, 400), 
                            height: min(geometry.size.height * 0.4, 200)
                        )
                        .position(
                            x: geometry.size.width * 0.5 + (animateWaves ? CGFloat.random(in: -30...30) : CGFloat.random(in: -15...15)),
                            y: geometry.size.height * 0.5 + (animateWaves ? CGFloat.random(in: -50...50) : CGFloat.random(in: -25...25))
                        )
                        .rotationEffect(.degrees(animateWaves ? Double.random(in: 0...30) : 0))
                        .animation(
                            .easeInOut(duration: Double.random(in: 6...10))
                            .repeatForever(autoreverses: true)
                            .delay(Double(waveIndex) * 1.5),
                            value: animateWaves
                        )
                        .blendMode(.softLight)
                }
            }
            
            // Particules lumineuses flottantes - contenues dans l'écran
            GeometryReader { geometry in
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    particleColor.opacity(0.8),
                                    particleColor.opacity(0.4),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: CGFloat.random(in: 8...20))
                        .position(
                            x: animateParticles ? 
                                CGFloat.random(in: 0...geometry.size.width) : 
                                CGFloat.random(in: geometry.size.width * 0.2...geometry.size.width * 0.8),
                            y: animateParticles ? 
                                CGFloat.random(in: 0...geometry.size.height) : 
                                CGFloat.random(in: geometry.size.height * 0.2...geometry.size.height * 0.8)
                        )
                        .opacity(animateParticles ? Double.random(in: 0.3...0.8) : Double.random(in: 0.1...0.4))
                        .blur(radius: Double.random(in: 1...4))
                        .animation(
                            .easeInOut(duration: Double.random(in: 4...8))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.4),
                            value: animateParticles
                        )
                }
            }
            
            // Rayons de lumière centraux - contenues
            GeometryReader { geometry in
                ForEach(0..<4, id: \.self) { rayIndex in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    accentColor.opacity(animateGlow ? 0.12 : 0.06),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: geometry.size.height)
                        .position(
                            x: geometry.size.width * 0.5 + CGFloat(rayIndex * 60 - 90),
                            y: geometry.size.height * 0.5 + (animateGlow ? -30 : 30)
                        )
                        .rotationEffect(.degrees(Double(rayIndex * 15)))
                        .animation(
                            .easeInOut(duration: 5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(rayIndex) * 0.8),
                            value: animateGlow
                        )
                        .blendMode(.screen)
                }
            }
            
            // Effet de halo central pulsant - adaptatif
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(animateGlow ? 0.1 : 0.05),
                                accentColor.opacity(animateGlow ? 0.05 : 0.02),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: min(geometry.size.width, geometry.size.height) * 0.4
                        )
                    )
                    .frame(
                        width: min(geometry.size.width * 0.8, 400), 
                        height: min(geometry.size.height * 0.8, 400)
                    )
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
                    .scaleEffect(animateGlow ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGlow)
                    .blendMode(.screen)
            }
            
            // Overlay texture finale - adaptative
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.15)],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(geometry.size.width, geometry.size.height) * 0.6
                        )
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateGlow = true
                animateParticles = true
                animateWaves = true
            }
        }
    }
    
    private var gradientColors: [Color] {
        switch currentState {
        case .idle:
            return [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black
            ]
        case .active:
            return [
                Color.black,
                Color(red: 0.15, green: 0.08, blue: 0.02),
                Color.black
            ]
        case .paused:
            return [
                Color.black,
                Color(red: 0.02, green: 0.12, blue: 0.08),
                Color.black
            ]
        case .completed:
            return [
                Color.black,
                Color(red: 0.08, green: 0.02, blue: 0.15),
                Color.black
            ]
        }
    }
    
    private var secondaryGradientColors: [Color] {
        switch currentState {
        case .idle:
            return [
                .cyan.opacity(0.08),
                .blue.opacity(0.06),
                .clear
            ]
        case .active:
            return [
                .orange.opacity(0.12),
                .red.opacity(0.08),
                .clear
            ]
        case .paused:
            return [
                .mint.opacity(0.10),
                .green.opacity(0.07),
                .clear
            ]
        case .completed:
            return [
                .purple.opacity(0.12),
                .pink.opacity(0.08),
                .clear
            ]
        }
    }
    
    private var particleColor: Color {
        switch currentState {
        case .idle: return .cyan.opacity(0.12)
        case .active: return .orange.opacity(0.15)
        case .paused: return .mint.opacity(0.12)
        case .completed: return .purple.opacity(0.15)
        }
    }
    
    private var waveColor: Color {
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
    
    private var accentColor: Color {
        // Si on a un type de concentration, utiliser sa couleur
        if let concentrationType = concentrationType {
            return concentrationType.accentColor
        }
        
        // Sinon, utiliser la couleur basée sur l'état
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }
}