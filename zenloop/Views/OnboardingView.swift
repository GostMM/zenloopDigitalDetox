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
                            showContent: showContent,
                            onboardingManager: onboardingManager
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3), value: currentPage)
                
                // Bottom actions
                OnboardingBottomActions(
                    currentPage: currentPage,
                    totalPages: pages.count,
                    showContent: showContent,
                    onNext: { nextPage() },
                    onSkip: { handleOnboardingComplete() },
                    onGetStarted: { handleOnboardingComplete() },
                    onboardingManager: onboardingManager
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(isOnboardingComplete: $isOnboardingComplete)
                .onDisappear {
                    // Marquer l'onboarding comme terminé pour le système de rapport quotidien
                    if isOnboardingComplete {
                        DailyReportManager.shared.setOnboardingCompleted()
                    }
                }
        }
    }
    
    private func nextPage() {
        if currentPage < pages.count - 1 {
            // Animation plus pro avec bounce léger
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)) {
                currentPage += 1
            }
            
            // Feedback haptique subtil
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            handleOnboardingComplete()
        }
    }
    
    private func handleOnboardingComplete() {
        // Demander les permissions avant d'aller au paywall
        Task {
            await requestAllPermissionsBeforePaywall()
        }
    }
    
    private func requestAllPermissionsBeforePaywall() async {
        print("🚀 [ONBOARDING] Opening paywall - permissions already handled")
        
        // Les permissions ont déjà été gérées sur leurs pages respectives
        // Plus besoin de les redemander ici
        
        await MainActor.run {
            print("💰 [ONBOARDING] Opening paywall")
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
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon principal avec animations améliorées
            if page.title.contains("Sessions") && page.title.contains("Insights") {
                // Page 2 : Animation spéciale avec multiples icônes
                ProFeatureAnimation(showContent: showContent, color: page.color)
            } else {
                // Pages normales : Animation standard
                StandardIconAnimation(icon: page.icon, color: page.color, showContent: showContent)
            }
            
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
                
                // Contenu spécifique pour les pages de permission
                if page.isPermissionPage {
                    permissionContent
                        .padding(.top, 20)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var permissionContent: some View {
        switch page.permissionType {
        case .screenTime:
            screenTimePermissionContent
        case .notifications:
            notificationPermissionContent
        case .none:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var screenTimePermissionContent: some View {
        VStack(spacing: 16) {
            // Bénéfices Screen Time
            VStack(spacing: 12) {
                PermissionBenefit(
                    icon: "apps.iphone",
                    text: String(localized: "block_distracting_apps"),
                    color: .cyan
                )
                
                PermissionBenefit(
                    icon: "chart.bar.fill",
                    text: String(localized: "track_usage_patterns"),
                    color: .cyan
                )
                
                PermissionBenefit(
                    icon: "target",
                    text: String(localized: "create_focus_sessions"),
                    color: .cyan
                )
            }
            
            // Status uniquement
            if onboardingManager.screenTimeStatus == .granted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(String(localized: "authorized"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.green.opacity(0.15), in: Capsule())
            }
        }
    }
    
    @ViewBuilder
    private var notificationPermissionContent: some View {
        VStack(spacing: 16) {
            // Exemples de notifications (compactés)
            VStack(spacing: 8) {
                CompactNotificationExample(
                    icon: "clock.badge.checkmark",
                    text: "Rappels 15 min avant vos sessions",
                    color: .orange
                )
                
                CompactNotificationExample(
                    icon: "lightbulb.fill",
                    text: "Conseils quotidiens de bien-être",
                    color: .orange
                )
                
                CompactNotificationExample(
                    icon: "shield.checkered",
                    text: "Alertes quand vous ouvrez une app bloquée",
                    color: .orange
                )
            }
            
            // Status - montrer tous les états
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    if onboardingManager.notificationStatus == .granted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "enabled"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    } else if onboardingManager.notificationStatus == .denied {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Refusé - Aller dans Réglages")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Pas encore demandé")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(backgroundColorForStatus.opacity(0.15), in: Capsule())
            }
        }
    }
    
    private var backgroundColorForStatus: Color {
        switch onboardingManager.notificationStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        default:
            return .orange
        }
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
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var isRequesting = false
    
    private var currentPage_: OnboardingPage {
        OnboardingPage.allPages[currentPage]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Bouton principal intelligent
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                print("🚨🚨 [ONBOARDING] BUTTON TAPPED!")
                print("🚨🚨 [ONBOARDING] Current page: \(currentPage)")
                print("🚨🚨 [ONBOARDING] Total pages: \(totalPages)")
                print("🚨🚨 [ONBOARDING] Page title: '\(currentPage_.title)'")
                print("🚨🚨 [ONBOARDING] IsPermissionPage: \(currentPage_.isPermissionPage)")
                print("🚨🚨 [ONBOARDING] PermissionType: \(String(describing: currentPage_.permissionType))")
                
                if currentPage_.isPermissionPage {
                    print("🚨🚨 [ONBOARDING] Permission page - calling handlePermissionAction()")
                    handlePermissionAction()
                } else {
                    print("🚨🚨 [ONBOARDING] Regular page - calling onNext()")
                    onNext()
                }
            }) {
                HStack(spacing: 12) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(buttonText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    if !isRequesting {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
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
            
            // Bouton skip (sauf sur la dernière page et pages permission déjà accordées)
            if currentPage < totalPages - 1 && shouldShowSkipButton {
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
    
    private var buttonText: String {
        let text: String
        if isRequesting {
            text = String(localized: "processing")
        } else if currentPage_.isPermissionPage {
            switch currentPage_.permissionType {
            case .screenTime:
                // Bouton pour demander Screen Time
                if onboardingManager.screenTimeStatus == .granted {
                    text = String(localized: "continue")
                } else {
                    text = String(localized: "authorize_screen_time")
                }
            case .notifications:
                // Le bouton principal est maintenant toujours "Continuer"
                // L'activation se fait via le bouton orange dédié
                text = String(localized: "continue")
            default:
                text = String(localized: "continue")
            }
        } else {
            text = String(localized: "continue")
        }
        
        print("🔍 [ONBOARDING] Button text for page \(currentPage): '\(text)' (isPermissionPage: \(currentPage_.isPermissionPage))")
        return text
    }
    
    private var buttonIcon: String {
        // Toujours flèche vers la droite
        return "arrow.right"
    }
    
    private var shouldShowSkipButton: Bool {
        // Toujours montrer le skip sauf sur la dernière page
        return currentPage < totalPages - 1
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
                            // Permission refusée, on peut quand même continuer
                            // L'utilisateur pourra réessayer plus tard
                            onNext()
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
        OnboardingPage(
            title: String(localized: "take_back_control"),
            description: String(localized: "take_back_control_desc"),
            icon: "brain.head.profile",
            color: .cyan,
            isPermissionPage: false,
            permissionType: nil
        ),
        OnboardingPage(
            title: String(localized: "focus_sessions_and_insights"),
            description: String(localized: "focus_sessions_and_insights_desc"),
            icon: "target",
            color: .blue,
            isPermissionPage: false,
            permissionType: nil
        ),
        OnboardingPage(
            title: String(localized: "screen_time_access"),
            description: String(localized: "screen_time_explanation"),
            icon: "lock.shield.fill",
            color: .cyan,
            isPermissionPage: true,
            permissionType: .screenTime
        ),
        OnboardingPage(
            title: String(localized: "smart_notifications"),
            description: String(localized: "notification_explanation"),
            icon: "bell.badge.fill",
            color: .orange,
            isPermissionPage: true,
            permissionType: .notifications
        )
    ]
}

// MARK: - Supporting Components

struct PermissionBenefit: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

struct CompactNotificationExample: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

struct NotificationExample: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Enhanced Animations

struct StandardIconAnimation: View {
    let icon: String
    let color: Color
    let showContent: Bool
    
    var body: some View {
        ZStack {
            // Cercles d'animation concentriques
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.2 - Double(index) * 0.05), lineWidth: 2)
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
                            color.opacity(0.4),
                            color.opacity(0.2),
                            color.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Icône principale
            Image(systemName: icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 2)
        }
        .scaleEffect(showContent ? 1.0 : 0.5)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showContent)
    }
}

struct ProFeatureAnimation: View {
    let showContent: Bool
    let color: Color
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    private let features = [
        (icon: "target", color: Color.blue, position: CGPoint(x: 0, y: -60)),
        (icon: "trophy.fill", color: Color.purple, position: CGPoint(x: -50, y: 30)),
        (icon: "chart.line.uptrend.xyaxis", color: Color.green, position: CGPoint(x: 50, y: 30))
    ]
    
    var body: some View {
        ZStack {
            // Cercle central animé
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.3),
                            color.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: showContent
                )
            
            // Fonctionnalités orbitales
            ForEach(0..<features.count, id: \.self) { index in
                let feature = features[index]
                
                VStack(spacing: 4) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [feature.color, feature.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: feature.color.opacity(0.4), radius: 8, x: 0, y: 2)
                }
                .offset(x: feature.position.x, y: feature.position.y)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.3)
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.7)
                    .delay(0.5 + Double(index) * 0.2),
                    value: showContent
                )
            }
            
            // Icône centrale
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: color.opacity(0.5), radius: 12, x: 0, y: 4)
                .scaleEffect(showContent ? 1.0 : 0.1)
                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3), value: showContent)
        }
        .onAppear {
            if showContent {
                startAnimations()
            }
        }
        .onChange(of: showContent) { _, newValue in
            if newValue {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }
    
    private func startAnimations() {
        pulseScale = 1.2
        
        // Rotation lente et continue
        withAnimation(
            .linear(duration: 10.0)
            .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
    }
    
    private func stopAnimations() {
        pulseScale = 1.0
        rotationAngle = 0
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}