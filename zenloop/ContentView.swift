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
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    @EnvironmentObject private var quickActionsBridge: QuickActionsBridge
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "has_completed_onboarding")
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
    @State private var selectedTab = 0
    @State private var isManagerReady = false
    @State private var showRetentionModal = false
    
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
        .fullScreenCover(isPresented: $showRetentionModal) {
            RetentionModal(zenloopManager: zenloopManager)
        }
        .onAppear {
            Task {
                await initializeManagerAsync()
                setupQuickActionsListeners()
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
        .onChange(of: zenloopManager.currentState) { _, _ in
            // Update Quick Actions when state changes
            quickActionsManager.updateOnStateChange()
        }
        .onChange(of: quickActionsBridge.pendingShortcutItem) { _, shortcutItem in
            // Process quick actions when they arrive
            if shortcutItem != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    quickActionsBridge.clearPendingShortcut()
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
                
                // Configure Quick Actions Manager with ZenloopManager
                quickActionsManager.configure(with: zenloopManager)
                
                // Log current Quick Actions for debugging
                quickActionsManager.logCurrentQuickActions()
            }
            
            // Petit délai pour s'assurer que l'initialisation est complète
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 secondes
        }.value
        
        // Marquer comme prêt
        isManagerReady = true
    }
    
    private func setupQuickActionsListeners() {
        // Listen for Quick Action navigation requests
        NotificationCenter.default.addObserver(
            forName: .quickActionNavigateToStats,
            object: nil,
            queue: .main
        ) { _ in
            // Navigate to stats tab (tab 2)
            selectedTab = 2
        }
        
        NotificationCenter.default.addObserver(
            forName: .quickActionEmergencyBreak,
            object: nil,
            queue: .main
        ) { _ in
            // Could show emergency break screen or breathing exercise
            // For now, just navigate to home to show the paused state
            selectedTab = 0
        }
        
        NotificationCenter.default.addObserver(
            forName: .quickActionShowRetention,
            object: nil,
            queue: .main
        ) { _ in
            // Show retention modal instead of just navigating
            showRetentionModal = true
            print("💚 [RETENTION] Showing retention modal...")
        }
    }
    
    // MARK: - Loading Interface
    
    private var loadingInterface: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
               Text(String(localized: "loading"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var mainInterface: some View {
        ZStack {
            // Content area
            TabContentView(selectedTab: $selectedTab)
                .environmentObject(zenloopManager)

            // Custom Opal-style tab bar
            VStack {
                Spacer()
                OpalTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(edges: .bottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            // Navigation automatique vers l'onglet Home
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $zenloopManager.showBreathingMeditation, onDismiss: {
            // Si l'utilisateur ferme la vue, on ne fait rien
            // La logique de stop est gérée par onStopRequested
        }) {
            BreathingMeditationView(
                zenloopManager: zenloopManager,
                onStopRequested: {
                    // Stop la session quand l'utilisateur choisit "Stop"
                    zenloopManager.stopCurrentChallenge()
                }
            )
        }
    }
}

// MARK: - Tab Content View

struct TabContentView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var zenloopManager: ZenloopManager

    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                NavigationStack {
                    HomeView()
                        .environmentObject(zenloopManager)
                        .navigationBarHidden(true)
                }
            case 1:
                NavigationStack {
                    FullStatsView()
                        .environmentObject(zenloopManager)
                        .navigationBarHidden(true)
                }
            case 2:
                NavigationStack {
                    SocialTab()
                        .environmentObject(zenloopManager)
                        .navigationBarHidden(true)
                }
            default:
                NavigationStack {
                    HomeView()
                        .environmentObject(zenloopManager)
                        .navigationBarHidden(true)
                }
            }
        }
        .transition(.opacity)
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