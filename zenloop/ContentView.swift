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
    @State private var isManagerReady = false
    
    var body: some View {
        ZStack {
            if showOnboarding && !isOnboardingComplete {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .zIndex(1)
            } else {
                if isManagerReady {
                    mainInterface
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                        .zIndex(0)
                } else {
                    loadingInterface
                        .zIndex(0)
                }
            }
        }
        .animation(.easeOut(duration: 0.4), value: showOnboarding)
        .onAppear {
            Task {
                await initializeManagerAsync()
            }
        }
        .onChange(of: isOnboardingComplete) { _, isComplete in
            if isComplete {
                UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
                withAnimation(.easeOut(duration: 0.3)) {
                    showOnboarding = false
                }
            }
        }
    }
    
    // MARK: - Async Initialization
    
    @MainActor
    private func initializeManagerAsync() async {
        // Initialiser pendant que le splash screen s'affiche
        await Task.detached(priority: .userInitiated) {
            // Simulation d'initialisation asynchrone
            await MainActor.run {
                zenloopManager.initialize()
            }
            
            // Petit délai pour s'assurer que l'initialisation est complète
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondes
        }.value
        
        // Marquer comme prêt
        isManagerReady = true
    }
    
    // MARK: - Loading Interface
    
    private var loadingInterface: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Chargement...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var mainInterface: some View {
        TabView(selection: $selectedTab) {
            // Accueil - Vue principale avec chargement lazy
            LazyTabView(selectedTab: selectedTab, targetTab: 0) {
                HomeView()
                    .environmentObject(zenloopManager)
            }
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text(String(localized: "home"))
            }
            .tag(0)
            
            // Défis - Chargement lazy
            LazyTabView(selectedTab: selectedTab, targetTab: 1) {
                ModernChallengesView()
                    .environmentObject(zenloopManager)
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "target" : "target")
                Text(String(localized: "challenges"))
            }
            .tag(1)
            
            // Stats - Chargement lazy
            LazyTabView(selectedTab: selectedTab, targetTab: 2) {
                StatsView()
                    .environmentObject(zenloopManager)
            }
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

// MARK: - Lazy Tab View Helper

struct LazyTabView<Content: View>: View {
    let selectedTab: Int
    let targetTab: Int
    let content: () -> Content
    
    @State private var hasLoaded = false
    
    var body: some View {
        Group {
            if hasLoaded || selectedTab == targetTab {
                content()
                    .onAppear {
                        hasLoaded = true
                    }
            } else {
                // Vue de chargement léger pendant que l'onglet se prépare
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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