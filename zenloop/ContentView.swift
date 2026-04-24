//
//  ContentView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import SwiftUI
import FamilyControls


struct ContentView: View {
    @StateObject private var zenloopManager = ZenloopManager.shared
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator.shared // ✅ Observe le deep link
    @EnvironmentObject private var quickActionsBridge: QuickActionsBridge
    @Environment(\.scenePhase) var scenePhase
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
        // Détecte le retour en foreground pour traiter les signaux du Monitor
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await SessionManager.shared.handleAppBecameActive()
                }
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
            quickActionsManager.updateOnStateChange()
        }
        .onChange(of: quickActionsBridge.pendingShortcutItem) { _, shortcutItem in
            if shortcutItem != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    quickActionsBridge.clearPendingShortcut()
                }
            }
        }
        // ✅ DEEP LINK: Réagit aux demandes de changement de tab du DeepLinkCoordinator
        .onChange(of: deepLinkCoordinator.targetTab) { _, newTab in
            guard let tab = newTab else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = tab
            }
        }
    }

    // MARK: - Async Initialization

    @MainActor
    private func initializeManagerAsync() async {
        await Task.detached(priority: .userInitiated) {
            await MainActor.run {
                zenloopManager.initialize()
                quickActionsManager.configure(with: zenloopManager)
                quickActionsManager.logCurrentQuickActions()
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }.value

        isManagerReady = true
    }

    private func setupQuickActionsListeners() {
        NotificationCenter.default.addObserver(
            forName: .quickActionNavigateToStats,
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 1
        }

        NotificationCenter.default.addObserver(
            forName: .quickActionEmergencyBreak,
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 0
        }

        NotificationCenter.default.addObserver(
            forName: .quickActionShowRetention,
            object: nil,
            queue: .main
        ) { _ in
            showRetentionModal = true
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

    // MARK: - Main Interface

    private var mainInterface: some View {
        ZStack {
            TabContentView(selectedTab: $selectedTab)
                .environmentObject(zenloopManager)
                .environmentObject(deepLinkCoordinator) // ✅ Passer aux tabs

            VStack {
                Spacer()
                OpalTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
            .ignoresSafeArea(edges: .bottom)
        }
        .fullScreenCover(isPresented: $zenloopManager.showBreathingMeditation, onDismiss: {}) {
            BreathingMeditationView(
                zenloopManager: zenloopManager,
                onStopRequested: {
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
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator // ✅

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
                        .environmentObject(deepLinkCoordinator) // ✅ Passer au SocialTab
                        .navigationBarHidden(true)
                        .onAppear {
                            // ✅ Signaler au coordinator que le tab est monté
                            deepLinkCoordinator.onTargetTabAppeared()
                        }
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


#Preview {
    ContentView()
}