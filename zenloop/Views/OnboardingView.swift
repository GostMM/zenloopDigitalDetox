//
//  OnboardingView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showContent = false
    @State private var showPaywall = false
    @Binding var isOnboardingComplete: Bool
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        ZStack {
            // Background optimisé pour de meilleures performances
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack(spacing: 0) {
                // Header avec logo et progress
                OnboardingHeader(
                    currentPage: currentPage,
                    totalPages: pages.count,
                    showContent: showContent
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Contenu principal
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            showContent: showContent
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom actions
                OnboardingBottomActions(
                    currentPage: currentPage,
                    totalPages: pages.count,
                    showContent: showContent,
                    onNext: { nextPage() },
                    onSkip: { showPaywall = true },
                    onGetStarted: { showPaywall = true }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                showContent = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isOnboardingComplete: $isOnboardingComplete)
        }
    }
    
    private func nextPage() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage += 1
            }
        } else {
            showPaywall = true
        }
    }
}

// MARK: - Onboarding Header

struct OnboardingHeader: View {
    let currentPage: Int
    let totalPages: Int
    let showContent: Bool
    
    var body: some View {
        HStack {
            // Logo Zenloop
            VStack(alignment: .leading, spacing: 4) {
                Text("Zenloop")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(String(localized: "digital_wellness"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
            }
            
            Spacer()
            
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index <= currentPage ? .cyan : .white.opacity(0.3))
                        .frame(width: index <= currentPage ? 24 : 8, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon principal avec animations
            ZStack {
                // Cercles d'animation concentriques
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(page.color.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
                        .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                        .scaleEffect(showContent ? 1.0 + Double(index) * 0.1 : 0.8)
                        .animation(
                            .easeInOut(duration: 2.0 + Double(index) * 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: showContent
                        )
                }
                
                // Cercle principal avec dégradé
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.color.opacity(0.4),
                                page.color.opacity(0.2),
                                page.color.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(page.color.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: page.color.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Icône principale
                Image(systemName: page.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(page.color)
                    .shadow(color: page.color.opacity(0.4), radius: 8, x: 0, y: 2)
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showContent)
            
            // Contenu textuel
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text(page.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Bottom Actions

struct OnboardingBottomActions: View {
    let currentPage: Int
    let totalPages: Int
    let showContent: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Bouton principal
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                if currentPage == totalPages - 1 {
                    onGetStarted()
                } else {
                    onNext()
                }
            }) {
                HStack(spacing: 12) {
                    Text(currentPage == totalPages - 1 ? String(localized: "get_started") : String(localized: "continue"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .cyan.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            // Bouton skip (sauf sur la dernière page)
            if currentPage < totalPages - 1 {
                Button(String(localized: "skip")) {
                    onSkip()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: showContent)
    }
}

// MARK: - Onboarding Pages Data

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            title: String(localized: "take_back_control"),
            description: String(localized: "take_back_control_desc"),
            icon: "brain.head.profile",
            color: .cyan
        ),
        OnboardingPage(
            title: String(localized: "focus_sessions"),
            description: String(localized: "focus_sessions_desc"),
            icon: "target",
            color: .blue
        ),
        OnboardingPage(
            title: String(localized: "challenges_gamification"),
            description: String(localized: "challenges_gamification_desc"),
            icon: "trophy.fill",
            color: .purple
        ),
        OnboardingPage(
            title: String(localized: "advanced_insights"),
            description: String(localized: "advanced_insights_desc"),
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        )
    ]
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}