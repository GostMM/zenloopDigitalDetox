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

// MARK: - SplashScreen is now in Views/Components/SplashScreen.swift

#Preview {
    ContentView()
}