//
//  SplashScreenView.swift
//  zenloop
//
//  Launch screen animé avec effet WOW
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var pillsOpacity: Double = 0
    @State private var particlesOpacity: Double = 0
    @State private var rotationDegrees: Double = 0
    @State private var welcomeOpacity: Double = 0
    @State private var welcomeScale: CGFloat = 0.8

    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            // Background avec gradient animé
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.08, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Particules flottantes en arrière-plan
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.3),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat.random(in: 40...80))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -300...300)
                        )
                        .blur(radius: 20)
                }
            }
            .opacity(particlesOpacity)

            // Message d'accueil qui apparaît et disparaît
            VStack {
                Spacer()
                Text("Welcome")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.cyan,
                                Color.blue,
                                Color.purple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(welcomeScale)
                    .opacity(welcomeOpacity)
                    .shadow(color: .cyan.opacity(0.5), radius: 20, x: 0, y: 10)
                Spacer()
            }

            VStack(spacing: 20) {
                Spacer()

                // Logo avec effet glow et rotation
                ZStack {
                    // Glow rings animés (3 cercles concentriques)
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.6 - Double(index) * 0.2),
                                        Color.blue.opacity(0.3 - Double(index) * 0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(index * 25), height: 140 + CGFloat(index * 25))
                            .scaleEffect(glowScale)
                            .opacity(glowOpacity * (1.0 - Double(index) * 0.25))
                            .blur(radius: 3)
                    }

                    // Glow effect principal radial
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.5),
                                    Color.cyan.opacity(0.25),
                                    Color.blue.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                        .blur(radius: 30)

                    // Background circulaire du logo avec gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.8),
                                    Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 135, height: 135)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)

                    // Logo ARRONDI avec border gradient
                    Image("zenloop")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 115, height: 115)
                        .clipShape(Circle())
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .rotationEffect(.degrees(rotationDegrees))
                        .shadow(color: .cyan.opacity(0.7), radius: 30, x: 0, y: 12)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.6),
                                            Color.blue.opacity(0.4),
                                            Color.purple.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 115, height: 115)
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                        )
                        .overlay(
                            // Reflet lumineux sur le logo
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                                .frame(width: 115, height: 115)
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity * 0.6)
                        )
                }

                // Titre avec offset et fade
                Text("Zenloop")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                    .shadow(color: .cyan.opacity(0.3), radius: 10, x: 0, y: 5)

                // Tagline avec effet shimmer
                Text("Take Back Control")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.cyan)
                    .opacity(taglineOpacity)

                // Pills avec animation stagger
                HStack(spacing: 12) {
                    ForEach(["Focus", "Block", "Insights"], id: \.self) { text in
                        PillView(text: text)
                    }
                }
                .opacity(pillsOpacity)

                Spacer()

                // Loading indicator subtil
                LoadingDotsView()
                    .opacity(taglineOpacity)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Particules (immédiat)
        withAnimation(.easeOut(duration: 1.0)) {
            particlesOpacity = 1.0
        }

        // ✨ WELCOME apparaît (0.1s)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            welcomeOpacity = 1.0
            welcomeScale = 1.0
        }

        // WELCOME disparaît (0.7s)
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            welcomeOpacity = 0
            welcomeScale = 1.2
        }

        // Glow (0.9s - après welcome)
        withAnimation(.easeOut(duration: 0.8).delay(0.9)) {
            glowScale = 1.2
            glowOpacity = 1.0
        }

        // Logo scale + fade (1.0s)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Rotation subtile du logo
        withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true).delay(1.2)) {
            rotationDegrees = 5
        }

        // Titre (1.3s)
        withAnimation(.easeOut(duration: 0.6).delay(1.3)) {
            titleOffset = 0
            titleOpacity = 1.0
        }

        // Tagline (1.5s)
        withAnimation(.easeOut(duration: 0.5).delay(1.5)) {
            taglineOpacity = 1.0
        }

        // Pills (1.7s)
        withAnimation(.easeOut(duration: 0.6).delay(1.7)) {
            pillsOpacity = 1.0
        }

        // Pulse du glow
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.9)) {
            glowScale = 1.4
        }

        // Transition vers l'app (3.0s - durée prolongée pour welcome)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isActive = false
            }
        }
    }
}

// MARK: - Supporting Views

struct PillView: View {
    let text: String
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double.random(in: 0...0.3))) {
                    scale = 1.0
                }
            }
    }
}

struct LoadingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.cyan.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
}
