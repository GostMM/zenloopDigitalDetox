//
//  ContentView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import SwiftUI
import FamilyControls

// MARK: - Navigation Notifications

extension Notification.Name {
    static let navigateToHome = Notification.Name("navigateToHome")
}

struct ContentView: View {
    @StateObject private var zenloopManager = ZenloopManager.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "has_completed_onboarding")
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
    @State private var selectedTab = 0
    @State private var isAppLoaded = false
    
    var body: some View {
        ZStack {
            if !isAppLoaded {
                // Écran de chargement discret
                SplashScreen()
            } else if showOnboarding && !isOnboardingComplete {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                mainInterface
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: showOnboarding)
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: isAppLoaded)
        .onAppear {
            // Préchargement optimisé et asynchrone
            Task {
                // Initialisation en background pour éviter les hangs
                await Task.detached(priority: .userInitiated) {
                    // Préchargement des données critiques
                    await MainActor.run {
                        zenloopManager.initialize()
                    }
                }.value
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SplashCompleted"))) { _ in
            // Transition plus rapide et fluide
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
                isAppLoaded = true
            }
        }
        .onChange(of: isOnboardingComplete) { _, isComplete in
            if isComplete {
                UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
                showOnboarding = false
            }
        }
    }
    
    private var mainInterface: some View {
        TabView(selection: $selectedTab) {
            // Accueil - Vue principale avec état adaptatif
            HomeView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Accueil")
                }
                .tag(0)
            
            // Défis - Nouvelle interface défis
            ModernChallengesView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "target" : "target")
                    Text("Défis")
                }
                .tag(1)
            
            // Stats - Vue statistiques
            StatsView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    Text("Stats")
                }
                .tag(2)
        }
        .tint(.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            // Navigation automatique vers l'onglet Home
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $zenloopManager.showBreathingMeditation) {
            BreathingMeditationView(zenloopManager: zenloopManager)
        }
    }
}

// MARK: - Vue Accueil
// HomeView est maintenant dans Views/HomeView.swift

// MARK: - Vue Stats
// StatsView est maintenant dans Views/StatsView.swift

// MARK: - Ultra Premium Splash Screen

struct SplashScreen: View {
    @State private var animationStep: Int = 0
    @State private var infinityProgress: CGFloat = 0
    @State private var slashProgress: CGFloat = 0
    @State private var showText = false
    @State private var showMotivation = false
    @State private var glowIntensity: Double = 0.3
    @State private var particleAnimation = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = -180
    @State private var textShimmer: CGFloat = -1
    @State private var backgroundRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var energyFieldOpacity: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    // Couleurs premium
    let premiumGradient = [
        Color(red: 0.4, green: 0.2, blue: 1.0),
        Color(red: 0.6, green: 0.1, blue: 0.9),
        Color(red: 0.8, green: 0.3, blue: 0.8),
        Color(red: 0.3, green: 0.5, blue: 1.0)
    ]
    
    var body: some View {
        ZStack {
            // Ultra Premium Background
            ZStack {
                // Base gradient
                RadialGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.0, blue: 0.15),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                // Animated gradient overlay
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.3),
                        Color.blue.opacity(0.2),
                        Color.cyan.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(backgroundRotation))
                .ignoresSafeArea()
                .blur(radius: 30)
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: backgroundRotation)
                
                // Energy field effect
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    premiumGradient[index].opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(
                            x: index == 0 ? -100 : (index == 1 ? 100 : 0),
                            y: index == 2 ? -150 : 50
                        )
                        .blur(radius: 40)
                        .opacity(energyFieldOpacity)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.5),
                            value: pulseScale
                        )
                }
                
                // Premium particles (optimisées)
                GeometryReader { geometry in
                    ForEach(0..<25, id: \.self) { index in
                        ParticleView(
                            color: premiumGradient[index % premiumGradient.count],
                            animating: particleAnimation,
                            delay: Double(index) * 0.1,
                            size: geometry.size
                        )
                    }
                }
                .ignoresSafeArea()
                .drawingGroup() // Optimise le rendu
            }
            
            VStack(spacing: 50) {
                Spacer()
                
                // Ultra Premium Logo Animation
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.cyan.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 200 + CGFloat(index * 40), height: 200 + CGFloat(index * 40))
                            .scaleEffect(animationStep >= 2 ? 1.2 : 0.8)
                            .opacity(animationStep >= 2 ? 0.0 : 0.8)
                            .animation(
                                .easeOut(duration: 2)
                                .delay(Double(index) * 0.1),
                                value: animationStep
                            )
                    }
                    
                    // Main logo container with effects
                    ZStack {
                        // Background pulse effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.cyan.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 250, height: 250)
                            .scaleEffect(pulseScale * 1.2)
                            .blur(radius: 20)
                            .opacity(0.6)
                        
                        // Infinity sign
                        InfinityLogoShape()
                            .trim(from: 0, to: infinityProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95),
                                        Color.cyan.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 160, height: 80)
                            .shadow(color: .white, radius: 0, x: 0, y: 0)
                            .shadow(color: .cyan.opacity(0.8), radius: 10, x: 0, y: 0)
                            .shadow(color: .blue.opacity(0.6), radius: 20, x: 0, y: 0)
                        
                        // Slash with premium effect
                        SlashShape()
                            .trim(from: 0, to: slashProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95),
                                        Color.cyan.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .frame(width: 160, height: 80)
                            .shadow(color: .white, radius: 0, x: 0, y: 0)
                            .shadow(color: .cyan.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        // Multiple glow layers
                        InfinityLogoShape()
                            .trim(from: 0, to: infinityProgress)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 160, height: 80)
                            .blur(radius: 8)
                            .opacity(glowIntensity * 0.8)
                        
                        InfinityLogoShape()
                            .trim(from: 0, to: infinityProgress)
                            .stroke(Color.cyan, lineWidth: 5)
                            .frame(width: 160, height: 80)
                            .blur(radius: 20)
                            .opacity(glowIntensity * 0.6)
                        
                        SlashShape()
                            .trim(from: 0, to: slashProgress)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 160, height: 80)
                            .blur(radius: 8)
                            .opacity(glowIntensity * 0.8)
                        
                        // Particle explosion optimisée
                        if animationStep >= 4 {
                            ForEach(0..<8, id: \.self) { index in
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 3, height: 3)
                                    .offset(x: animationStep >= 4 ? CGFloat(cos(Double(index) * .pi / 4)) * 80 : 0,
                                           y: animationStep >= 4 ? CGFloat(sin(Double(index) * .pi / 4)) * 80 : 0)
                                    .opacity(animationStep >= 4 ? 0 : 1)
                                    .animation(
                                        .easeOut(duration: 1.0)
                                        .delay(Double(index) * 0.03),
                                        value: animationStep
                                    )
                            }
                        }
                    }
                    .scaleEffect(logoScale)
                    .rotationEffect(.degrees(logoRotation))
                    .animation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0), value: logoScale)
                    .animation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0), value: logoRotation)
                }
                
                // Premium Text with Shimmer Effect
                if showText {
                    ZStack {
                        // Background glow for text
                        Text("Zenloop")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .blur(radius: 20)
                            .opacity(0.5)
                        
                        // Main text with shimmer
                        Text("Zenloop")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white,
                                        Color.cyan.opacity(0.9),
                                        Color.white,
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.8),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 60)
                                .offset(x: textShimmer * 200)
                                .mask(
                                    Text("Zenloop")
                                        .font(.system(size: 42, weight: .black, design: .rounded))
                                )
                            )
                            .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(showText ? 1.0 : 0.5)
                    .opacity(showText ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showText)
                }
                
                Spacer()
                
                // Premium Motivation Text
                if showMotivation {
                    VStack(spacing: 12) {
                        Text("Reprends le contrôle")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color.cyan.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 5)
                        
                        Text("Une session à la fois")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 2)
                        
                        // Premium loading indicator
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(animationStep >= 5 ? 1.2 : 0.8)
                                    .opacity(animationStep >= 5 ? 1.0 : 0.3)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: animationStep
                                    )
                            }
                        }
                        .padding(.top, 20)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(showMotivation ? 1.0 : 0.0)
                    .offset(y: showMotivation ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: showMotivation)
                }
                
                Spacer()
            }
        }
        .onAppear {
            startPremiumAnimation()
        }
    }
    
    private func startPremiumAnimation() {
        // Initial setup
        withAnimation(.linear(duration: 20)) {
            backgroundRotation = 360
        }
        
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
        
        // Phase 1: Energy field activation
        withAnimation(.easeIn(duration: 0.8)) {
            energyFieldOpacity = 1.0
        }
        
        // Phase 2: Logo entrance with scale and rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            logoScale = 1.0
            logoRotation = 0
            
            // Start drawing infinity
            withAnimation(.easeInOut(duration: 1.8)) {
                infinityProgress = 1.0
            }
            
            // Activate particles
            particleAnimation = true
        }
        
        // Phase 3: Add slash with dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                slashProgress = 1.0
            }
            
            // Trigger explosion effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                animationStep = 4
                
                // Enhanced glow
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 1.0
                }
            }
        }
        
        // Phase 4: Text appearance with shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            showText = true
            
            // Shimmer animation
            withAnimation(.linear(duration: 2).delay(0.5)) {
                textShimmer = 1
            }
        }
        
        // Phase 5: Motivation text et transition rapide (2s au lieu de 3.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showMotivation = true
            animationStep = 5
        }
        
        // Phase 6: Transition ultra-rapide (2.5s au lieu de 3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NotificationCenter.default.post(name: Notification.Name("SplashCompleted"), object: nil)
        }
    }
}

// MARK: - Premium Particle View

struct ParticleView: View {
    let color: Color
    let animating: Bool
    let delay: Double
    let size: CGSize
    
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 3
                )
            )
            .frame(width: 6, height: 6)
            .shadow(color: color, radius: 3)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                if animating {
                    animateParticle()
                }
            }
            .onChange(of: animating) { newValue in
                if newValue {
                    animateParticle()
                }
            }
    }
    
    private func animateParticle() {
        let startX = CGFloat.random(in: -size.width/2...size.width/2)
        let startY = size.height/2 + 50
        let endX = CGFloat.random(in: -100...100)
        let endY = -size.height/2 - 50
        
        offset = CGSize(width: startX, height: startY)
        opacity = 0
        
        withAnimation(.easeOut(duration: Double.random(in: 3...5)).delay(delay)) {
            offset = CGSize(width: endX, height: endY)
            opacity = 0.8
        }
        
        withAnimation(.easeIn(duration: 1).delay(delay + 2)) {
            opacity = 0
        }
        
        // Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 5) {
            if animating {
                animateParticle()
            }
        }
    }
}

// MARK: - Infinity Logo Shape

struct InfinityLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerY = rect.midY
        let centerX = rect.midX
        
        let loopRadius = height * 0.35
        let leftCenter = CGPoint(x: centerX - width * 0.25, y: centerY)
        let rightCenter = CGPoint(x: centerX + width * 0.25, y: centerY)
        let startPoint = CGPoint(x: centerX, y: centerY)
        
        path.move(to: startPoint)
        
        // Left loop - top
        path.addCurve(
            to: CGPoint(x: leftCenter.x, y: leftCenter.y - loopRadius),
            control1: CGPoint(x: centerX - width * 0.1, y: centerY - loopRadius * 0.5),
            control2: CGPoint(x: leftCenter.x + loopRadius * 0.5, y: leftCenter.y - loopRadius)
        )
        
        // Left loop - left curve
        path.addCurve(
            to: CGPoint(x: leftCenter.x - loopRadius, y: leftCenter.y),
            control1: CGPoint(x: leftCenter.x - loopRadius * 0.5, y: leftCenter.y - loopRadius),
            control2: CGPoint(x: leftCenter.x - loopRadius, y: leftCenter.y - loopRadius * 0.5)
        )
        
        // Left loop - bottom
        path.addCurve(
            to: CGPoint(x: leftCenter.x, y: leftCenter.y + loopRadius),
            control1: CGPoint(x: leftCenter.x - loopRadius, y: leftCenter.y + loopRadius * 0.5),
            control2: CGPoint(x: leftCenter.x - loopRadius * 0.5, y: leftCenter.y + loopRadius)
        )
        
        // Back to center
        path.addCurve(
            to: startPoint,
            control1: CGPoint(x: leftCenter.x + loopRadius * 0.5, y: leftCenter.y + loopRadius),
            control2: CGPoint(x: centerX - width * 0.1, y: centerY + loopRadius * 0.5)
        )
        
        // Right loop - bottom
        path.addCurve(
            to: CGPoint(x: rightCenter.x, y: rightCenter.y + loopRadius),
            control1: CGPoint(x: centerX + width * 0.1, y: centerY + loopRadius * 0.5),
            control2: CGPoint(x: rightCenter.x - loopRadius * 0.5, y: rightCenter.y + loopRadius)
        )
        
        // Right loop - right curve
        path.addCurve(
            to: CGPoint(x: rightCenter.x + loopRadius, y: rightCenter.y),
            control1: CGPoint(x: rightCenter.x + loopRadius * 0.5, y: rightCenter.y + loopRadius),
            control2: CGPoint(x: rightCenter.x + loopRadius, y: rightCenter.y + loopRadius * 0.5)
        )
        
        // Right loop - top
        path.addCurve(
            to: CGPoint(x: rightCenter.x, y: rightCenter.y - loopRadius),
            control1: CGPoint(x: rightCenter.x + loopRadius, y: rightCenter.y - loopRadius * 0.5),
            control2: CGPoint(x: rightCenter.x + loopRadius * 0.5, y: rightCenter.y - loopRadius)
        )
        
        // Back to center
        path.addCurve(
            to: startPoint,
            control1: CGPoint(x: rightCenter.x - loopRadius * 0.5, y: rightCenter.y - loopRadius),
            control2: CGPoint(x: centerX + width * 0.1, y: centerY - loopRadius * 0.5)
        )
        
        return path
    }
}

// MARK: - Slash Shape

struct SlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        let startPoint = CGPoint(x: width * 0.25, y: height * 0.75)
        let endPoint = CGPoint(x: width * 0.75, y: height * 0.25)
        
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        return path
    }
}

#Preview {
    ContentView()
}