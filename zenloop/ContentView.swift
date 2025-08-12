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
            // Initialisation immédiate et non-bloquante - différée pour éviter les lags
            DispatchQueue.main.async {
                zenloopManager.initialize()
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
                    Text(String(localized: "home"))
                }
                .tag(0)
            
            // Défis - Nouvelle interface défis
            ModernChallengesView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "target" : "target")
                    Text(String(localized: "challenges"))
                }
                .tag(1)
            
            // Stats - Vue statistiques
            StatsView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    Text(String(localized: "stats"))
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
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    
    // Couleurs premium
    let premiumGradient = [
        Color(red: 0.4, green: 0.2, blue: 1.0),
        Color(red: 0.6, green: 0.1, blue: 0.9),
        Color(red: 0.8, green: 0.3, blue: 0.8),
        Color(red: 0.3, green: 0.5, blue: 1.0)
    ]
    
    var body: some View {
        ZStack {
            // Simple background - no Metal effects
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Simple logo without Metal effects
                ZStack {
                    // Simple infinity symbol
                    Text("∞")
                        .font(.system(size: 120, weight: .ultraLight))
                        .foregroundColor(.white)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .animation(.easeOut(duration: 0.8), value: logoOpacity)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: logoScale)
                }
                
                // Simple app name
                Text("Zenloop")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                    .animation(.easeOut(duration: 0.6), value: textOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            startSimpleAnimation()
        }
    }
    
    private func startSimpleAnimation() {
        // Simple, fast animation - no Metal effects
        logoOpacity = 1.0
        logoScale = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            textOpacity = 1.0
        }
        
        // Quick transition - 0.8s total
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotificationCenter.default.post(name: Notification.Name("SplashCompleted"), object: nil)
        }
    }
}

// MARK: - Removed complex Metal components to prevent RenderBox errors

#Preview {
    ContentView()
}