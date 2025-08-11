//
//  HomeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @StateObject private var badgeManager = BadgeManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showContent = false
    @StateObject private var backgroundAnimator = BackgroundAnimator()
    
    // MARK: - Computed Properties
    
    private var isIdle: Bool {
        zenloopManager.currentState == .idle
    }
    
    private var isActive: Bool {
        zenloopManager.currentState != .idle
    }
    
    
    var body: some View {
        ZStack {
            // Background plus sombre et intense pour focus sur les badges
            IntenseBackground(currentState: zenloopManager.currentState)
                .ignoresSafeArea(.all, edges: .all)
            
            // Interface principale
            VStack(spacing: 0) {
                // Header minimaliste
                MinimalHeader(
                    showContent: showContent,
                    currentState: zenloopManager.currentState,
                    isPremium: purchaseManager.isPremium
                )
                .padding(.horizontal, 20)
               
                
                // Contenu principal avec espacement amélioré
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 32) {
                        // Timer Card en priorité absolue (toujours au top si idle)
                        if isIdle {
                            TimerCard(zenloopManager: zenloopManager, showContent: showContent)
                                .padding(.top, 20)
                        }
                        
                        // Section principale selon l'état
                        primarySection
                        
                        // Sections conditionnelles selon l'état avec transitions fluides
                        Group {
                            if isIdle {
                                idleSections
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            } else {
                                activeSections
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isIdle)
                        
                        // Sections communes
                        commonSections
                        
                        // Espace de respiration en bas
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 0)
                }
                .frame(maxHeight: .infinity)
            }
            
            // Plus de bottom bar - maintenant intégrée en carte
            
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                showContent = true
            }
            backgroundAnimator.startAnimation()
            badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
        }
        .onDisappear {
            backgroundAnimator.stopAnimation()
        }
        .onChange(of: zenloopManager.currentState) { oldValue, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
            }
            
            // Feedback haptique lors des changements d'état
            if oldValue != newValue {
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var primarySection: some View {
        HeroSection(
            currentState: zenloopManager.currentState,
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var idleSections: some View {
        CategoryChallengesRow(
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        
        MotivationSection(showContent: showContent, zenloopManager: zenloopManager)
    }
    
    @ViewBuilder
    private var activeSections: some View {
        ActiveChallengeSection(
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        .padding(.top, 30)
    }
    
    @ViewBuilder
    private var commonSections: some View {
        StatsInsightsSection(
            badgeManager: badgeManager,
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        
        RecentActivitySection(
            zenloopManager: zenloopManager,
            showContent: showContent
        )
    }
    
    // MARK: - Safe Area helpers
    
    private func getSafeAreaTop() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.top
    }
    
    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
    
    private func getTabBarHeight() -> CGFloat {
        // Hauteur standard de la tab bar iOS (49pt + safe area)
        return 49
    }
    
}

#Preview {
    HomeView()
        .environmentObject(ZenloopManager.shared)
}
