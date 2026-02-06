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
    @StateObject private var onboardingManager = OnboardingManager.shared

    private let pages = OnboardingPage.allPages
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            // Background noir avec jeu de lumière subtil
            Color.black
                .ignoresSafeArea()

            // Lumière douce en haut
            RadialGradient(
                colors: [
                    .white.opacity(0.05),
                    .clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Lumière douce en bas
            RadialGradient(
                colors: [
                    .white.opacity(0.03),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header minimaliste
                OnboardingHeader(
                    currentPage: currentPage,
                    totalPages: pages.count,
                    showContent: showContent
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Contenu principal
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            showContent: showContent,
                            onboardingManager: onboardingManager
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Bottom actions
                OnboardingBottomActions(
                    currentPage: currentPage,
                    totalPages: pages.count,
                    showContent: showContent,
                    onNext: { nextPage() },
                    onGetStarted: { handleOnboardingComplete() },
                    onboardingManager: onboardingManager
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isOnboardingComplete: $isOnboardingComplete)
        }
        .onAppear {
            // Animation d'entrée plus pro avec délai écheloné
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8, blendDuration: 0.3)) {
                showContent = true
            }

            // Vérifier les permissions au démarrage
            onboardingManager.checkPermissionStatuses()

            // Debug des pages
            print("🚨🚨 [ONBOARDING] OnboardingView appeared")
            for (index, page) in OnboardingPage.allPages.enumerated() {
                print("🚨🚨 [ONBOARDING] Page \(index): \(page.title) - isPermission: \(page.isPermissionPage) - type: \(String(describing: page.permissionType))")
            }
        }
        .onChange(of: currentPage) { _, newPage in
            // Vérifier les permissions à chaque changement de page
            onboardingManager.checkPermissionStatuses()
        }
    }
    
    private func nextPage() {
        // Feedback haptique AVANT le changement de page
        impactFeedback.impactOccurred()

        if currentPage < pages.count - 1 {
            // Changement immédiat sans animation pour éviter re-renders
            currentPage += 1
        } else {
            handleOnboardingComplete()
        }
    }
    
    private func handleOnboardingComplete() {
        print("🚀 [ONBOARDING] Onboarding complete - showing paywall")

        // Afficher le paywall
        showPaywall = true

        // Désactivé: Configuration des rapports quotidiens
        // DailyReportManager.shared.setOnboardingCompleted()
    }
}

// MARK: - Onboarding Header

struct OnboardingHeader: View {
    let currentPage: Int
    let totalPages: Int
    let showContent: Bool

    var body: some View {
        HStack {
            // Logo simple
            Text("Zenloop")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            // Progress dots minimalistes
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? .white : .white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let showContent: Bool
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icône avec léger halo
            ZStack {
                // Halo doux
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.1),
                                .white.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Icône
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.3), radius: 20)
            }
            .padding(.bottom, 40)

            // Contenu textuel
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .shadow(color: .white.opacity(0.2), radius: 10)

                Text(page.description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Bottom Actions

struct OnboardingBottomActions: View {
    let currentPage: Int
    let totalPages: Int
    let showContent: Bool
    let onNext: () -> Void
    let onGetStarted: () -> Void

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var isRequesting = false

    // Cache les computed properties pour éviter recalculs
    private var currentPage_: OnboardingPage {
        OnboardingPage.allPages[currentPage]
    }

    private var cachedButtonText: String {
        if isRequesting {
            return String(localized: "processing")
        }
        return String(localized: "continue")
    }

    private var cachedButtonIcon: String {
        return "arrow.right"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Bouton principal intelligent
            Button {
                // Désactiver temporairement le bouton pour éviter double tap
                guard !isRequesting else { return }

                impactFeedback.impactOccurred()

                print("🚨🚨 [ONBOARDING] BUTTON TAPPED!")
                print("🚨🚨 [ONBOARDING] Current page: \(currentPage)")
                print("🚨🚨 [ONBOARDING] Total pages: \(totalPages)")
                print("🚨🚨 [ONBOARDING] Page title: '\(currentPage_.title)'")
                print("🚨🚨 [ONBOARDING] IsPermissionPage: \(currentPage_.isPermissionPage)")
                print("🚨🚨 [ONBOARDING] PermissionType: \(String(describing: currentPage_.permissionType))")

                // Exécution directe sans délai
                if currentPage_.isPermissionPage {
                    print("🚨🚨 [ONBOARDING] Permission page - calling handlePermissionAction()")
                    handlePermissionAction()
                } else {
                    print("🚨🚨 [ONBOARDING] Regular page - calling onNext()")
                    onNext()
                }
            } label: {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(cachedButtonText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isRequesting)

        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
    }
    
    
    
    private func handlePermissionAction() {
        print("🚨 [ONBOARDING] handlePermissionAction called for page \(currentPage) (\(currentPage_.title))")
        print("🚨 [ONBOARDING] IsPermissionPage: \(currentPage_.isPermissionPage)")
        print("🚨 [ONBOARDING] PermissionType: \(currentPage_.permissionType?.description ?? "nil")")
        
        guard currentPage_.isPermissionPage else {
            print("⚠️ [ONBOARDING] Not a permission page, calling onNext()")
            onNext()
            return
        }
        
        print("🔍 [ONBOARDING] Processing permission type: \(currentPage_.permissionType?.description ?? "none")")
        
        switch currentPage_.permissionType {
        case .screenTime:
            if onboardingManager.screenTimeStatus == .granted {
                print("🔍 [ONBOARDING] Screen Time already granted - continuing to next page")
                onNext()
            } else {
                print("🔍 [ONBOARDING] Requesting Screen Time permission")
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestScreenTimePermission()
                    await MainActor.run {
                        isRequesting = false
                        if granted {
                            // Permission accordée, passer à la page suivante
                            onNext()
                        } else {
                            // Permission refusée, rester sur cette page
                            // L'utilisateur doit réessayer pour continuer
                            print("🚫 [ONBOARDING] Screen Time refusé - impossible de continuer")
                        }
                    }
                }
            }
            
        case .notifications:
            print("🔍 [ONBOARDING] Notification permission action - Status: \(onboardingManager.notificationStatus)")
            if onboardingManager.notificationStatus == .granted {
                print("🔍 [ONBOARDING] Notifications already granted - continuing")
                onNext()
            } else {
                print("🔍 [ONBOARDING] Requesting notification permission")
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestNotificationPermission()
                    if granted {
                        await SessionNotificationManager.shared.setupDailyWellnessNotifications()
                        print("✅ [NOTIFICATION] Notifications activated successfully")
                    }
                    await MainActor.run {
                        isRequesting = false
                        onNext()
                    }
                }
            }
            
        default:
            print("⚠️ [ONBOARDING] Unknown permission type, calling onNext()")
            onNext()
        }
    }
}

// MARK: - Onboarding Pages Data

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isPermissionPage: Bool
    let permissionType: PermissionType?
    
    enum PermissionType {
        case screenTime
        case notifications
        
        var description: String {
            switch self {
            case .screenTime: return "screenTime"
            case .notifications: return "notifications"
            }
        }
    }
    
    static let allPages: [OnboardingPage] = [
        // Page 1: Introduction - Le problème
        OnboardingPage(
            title: String(localized: "take_back_control"),
            description: String(localized: "take_back_control_desc"),
            icon: "brain.head.profile",
            color: .cyan,
            isPermissionPage: false,
            permissionType: nil
        ),
        // Page 2: La solution - Comment ça marche
        OnboardingPage(
            title: String(localized: "focus_sessions_and_insights"),
            description: String(localized: "focus_sessions_and_insights_desc"),
            icon: "target",
            color: .blue,
            isPermissionPage: false,
            permissionType: nil
        ),
        // Page 3: Les résultats - Preuve sociale et impact
        OnboardingPage(
            title: String(localized: "join_thousands_users"),
            description: String(localized: "join_thousands_users_desc"),
            icon: "chart.line.uptrend.xyaxis",
            color: .green,
            isPermissionPage: false,
            permissionType: nil
        )
        // Note: Le paywall s'affichera après cette page
    ]
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}