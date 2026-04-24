//
//  OnboardingView.swift
//  zenloop
//
//  Narrative onboarding flow:
//  1. Welcome       — hook émotionnel ("ton téléphone te vole ton temps")
//  2. ScreenTime    — permission, justifiée par "on va te montrer la vérité"
//  3. GuiltTrip     — vraies données de la journée (déclencheur émotionnel max)
//  4. HowItWorks    — "voilà comment Zenloop répare ça" (sessions + blocages)
//  5. SocialProof   — "rejoins 50k+ users" (stats + témoignages)
//  6. Notifications — permission douce, justifiée par "on te réveille au bon moment"
//  → Paywall (inchangé, conversion à chaud après la narration complète)
//

import SwiftUI
import DeviceActivity

// MARK: - Step Definition

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case screenTime
    case guiltTrip
    case howItWorks
    case socialProof
    case notifications

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    static var totalCount: Int { OnboardingStep.allCases.count }
}

// MARK: - Root View

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var showContent = false
    @State private var showPaywall = false
    @State private var isRequesting = false
    @Binding var isOnboardingComplete: Bool
    @StateObject private var onboardingManager = OnboardingManager.shared

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            // Background noir + lumières douces
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [.white.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            RadialGradient(
                colors: [.white.opacity(0.03), .clear],
                center: .bottom, startRadius: 0, endRadius: 300
            ).ignoresSafeArea()

            // Step content — le GuiltTrip step occupe le plein écran (sans header ni action bar).
            // Les autres steps gardent le layout header + content + action bar.
            if step == .guiltTrip {
                GuiltTripFullScreenStep(onContinue: { handlePrimary() })
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    OnboardingHeader(
                        currentIndex: step.rawValue,
                        totalSteps: OnboardingStep.totalCount,
                        showContent: showContent
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Group {
                        switch step {
                        case .welcome:        WelcomeStep()
                        case .screenTime:     ScreenTimeStep(status: onboardingManager.screenTimeStatus)
                        case .guiltTrip:      EmptyView()
                        case .howItWorks:     HowItWorksStep()
                        case .socialProof:    SocialProofStep()
                        case .notifications:  NotificationsStep(status: onboardingManager.notificationStatus)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                    OnboardingActionBar(
                        step: step,
                        isRequesting: isRequesting,
                        screenTimeStatus: onboardingManager.screenTimeStatus,
                        notificationStatus: onboardingManager.notificationStatus,
                        onPrimary: handlePrimary,
                        onSkip: handleSkip
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }

            // Warm-up invisible du DeviceActivityReport dès que Screen Time est OK.
            // Ça laisse le temps à l'extension `zenloopactivity` de charger avant
            // que l'utilisateur arrive sur l'étape GuiltTrip.
            if onboardingManager.screenTimeStatus == .granted && step.rawValue < OnboardingStep.guiltTrip.rawValue {
                DeviceActivityReportWarmUp()
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(isOnboardingComplete: $isOnboardingComplete)
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8, blendDuration: 0.3)) {
                showContent = true
            }
            onboardingManager.checkPermissionStatuses()
        }
        .onChange(of: step) { _, _ in
            onboardingManager.checkPermissionStatuses()
        }
    }

    // MARK: - Actions

    private func handlePrimary() {
        guard !isRequesting else { return }
        impactMedium.impactOccurred()

        switch step {
        case .welcome, .guiltTrip, .howItWorks, .socialProof:
            advance()

        case .screenTime:
            if onboardingManager.screenTimeStatus == .granted {
                advance()
            } else {
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestScreenTimePermission()
                    await MainActor.run {
                        isRequesting = false
                        if granted {
                            notificationFeedback.notificationOccurred(.success)
                            advance()
                        } else {
                            notificationFeedback.notificationOccurred(.error)
                        }
                    }
                }
            }

        case .notifications:
            if onboardingManager.notificationStatus == .granted {
                finish()
            } else {
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestNotificationPermission()
                    if granted {
                        await SessionNotificationManager.shared.setupDailyWellnessNotifications()
                    }
                    await MainActor.run {
                        isRequesting = false
                        finish()
                    }
                }
            }
        }
    }

    private func handleSkip() {
        impactLight.impactOccurred()
        if step == .notifications {
            finish()
        }
    }

    private func advance() {
        if let next = step.next {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { step = next }
        } else {
            finish()
        }
    }

    private func finish() {
        showPaywall = true
    }
}

// MARK: - Header

struct OnboardingHeader: View {
    let currentIndex: Int
    let totalSteps: Int
    let showContent: Bool

    var body: some View {
        HStack {
            Text("Zenloop")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? .white : .white.opacity(0.22))
                        .frame(width: index == currentIndex ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -10)
    }
}

// MARK: - Shared Step Scaffold

private struct StepScaffold<Icon: View, Content: View>: View {
    let icon: Icon
    let title: String
    let subtitle: String
    @ViewBuilder var extraContent: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            icon
                .padding(.bottom, 32)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .shadow(color: .white.opacity(0.2), radius: 10)
                    .padding(.horizontal, 24)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 36)
            }

            extraContent()
                .padding(.top, 20)

            Spacer(minLength: 16)
        }
    }
}

private struct HaloIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.2), tint.opacity(0.06), .clear],
                        center: .center, startRadius: 20, endRadius: 90
                    )
                )
                .frame(width: 170, height: 170)

            Image(systemName: systemName)
                .font(.system(size: 58, weight: .regular))
                .foregroundColor(.white)
                .shadow(color: tint.opacity(0.35), radius: 22)
        }
    }
}

// MARK: - Step: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Image hero — image entière, agrandie au-delà de la largeur d'écran
            Image("bg-1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(1.25)

            VStack(spacing: 14) {
                Text(String(localized: "onboard_welcome_title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .shadow(color: .white.opacity(0.2), radius: 10)
                    .padding(.horizontal, 24)

                Text(String(localized: "onboard_welcome_subtitle"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 16)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Step: Screen Time Permission

private struct ScreenTimeStep: View {
    let status: PermissionStatus

    var body: some View {
        StepScaffold(
            icon: HaloIcon(systemName: "chart.bar.fill", tint: .purple),
            title: String(localized: "onboard_screentime_title"),
            subtitle: String(localized: "onboard_screentime_subtitle"),
            extraContent: {
                if status == .granted {
                    StatusPill(icon: "checkmark.circle.fill", label: String(localized: "authorized"), color: .green)
                }
            }
        )
    }
}

// MARK: - Step: GuiltTrip (Full-screen — pas de header, pas d'action bar classique)
//
// Le DeviceActivityReport "GuiltTrip" prend tout l'écran — l'extension zenloopactivity
// dessine sa propre hero + séquence d'animation. Un bouton flottant en bas permet
// de continuer une fois que l'utilisateur a absorbé le choc.

private struct GuiltTripFullScreenStep: View {
    let onContinue: () -> Void
    @State private var showCTA = false

    var body: some View {
        ZStack(alignment: .bottom) {
            #if os(iOS)
            GuiltTripView()
            #else
            Color.black
            #endif

            // CTA flottant qui apparaît après que le choc ait eu le temps de s'installer.
            if showCTA {
                VStack(spacing: 0) {
                    // Fade noir pour garantir la lisibilité du bouton sur fond variable
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.85), .black],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 180)
                    .allowsHitTesting(false)

                    Button(action: onContinue) {
                        Text(String(localized: "onboard_continue_shocked"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .background(Color.black)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            // Le bouton n'apparaît qu'après ~5s : laisse le temps au compteur + verdict
            // + shock phrase de s'installer avant de proposer la sortie.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeOut(duration: 0.5)) { showCTA = true }
            }
        }
    }
}

// MARK: - Step: How It Works

private struct HowItWorksStep: View {
    var body: some View {
        StepScaffold(
            icon: HaloIcon(systemName: "target", tint: .blue),
            title: String(localized: "onboard_howitworks_title"),
            subtitle: String(localized: "onboard_howitworks_subtitle"),
            extraContent: {
                VStack(spacing: 14) {
                    OnboardingFeatureRow(icon: "shield.lefthalf.filled",
                               title: String(localized: "onboard_feature_block_title"),
                               subtitle: String(localized: "onboard_feature_block_subtitle"))
                    OnboardingFeatureRow(icon: "person.3.fill",
                               title: String(localized: "onboard_feature_social_title"),
                               subtitle: String(localized: "onboard_feature_social_subtitle"))
                    OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis",
                               title: String(localized: "onboard_feature_stats_title"),
                               subtitle: String(localized: "onboard_feature_stats_subtitle"))
                }
                .padding(.horizontal, 24)
            }
        )
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
    }
}

// MARK: - Step: Social Proof

private struct SocialProofStep: View {
    var body: some View {
        StepScaffold(
            icon: HaloIcon(systemName: "sparkles", tint: .green),
            title: String(localized: "onboard_social_title"),
            subtitle: String(localized: "onboard_social_subtitle"),
            extraContent: {
                HStack(spacing: 12) {
                    StatCard(value: "50k+", label: String(localized: "onboard_stat_users"))
                    StatCard(value: "2.3h", label: String(localized: "onboard_stat_avg_saved"))
                    StatCard(value: "4.8★", label: String(localized: "onboard_stat_rating"))
                }
                .padding(.horizontal, 24)
            }
        )
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
}

// MARK: - Step: Notifications

private struct NotificationsStep: View {
    let status: PermissionStatus

    var body: some View {
        StepScaffold(
            icon: HaloIcon(systemName: "bell.badge.fill", tint: .orange),
            title: String(localized: "onboard_notifications_title"),
            subtitle: String(localized: "onboard_notifications_subtitle"),
            extraContent: {
                VStack(spacing: 8) {
                    Text(String(localized: "optional_can_skip"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))

                    if status == .granted {
                        StatusPill(icon: "checkmark.circle.fill", label: String(localized: "enabled"), color: .green)
                    }
                }
            }
        )
    }
}

// MARK: - Status Pill

private struct StatusPill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Action Bar

struct OnboardingActionBar: View {
    let step: OnboardingStep
    let isRequesting: Bool
    let screenTimeStatus: PermissionStatus
    let notificationStatus: PermissionStatus
    let onPrimary: () -> Void
    let onSkip: () -> Void

    private var primaryText: String {
        if isRequesting { return String(localized: "processing") }
        switch step {
        case .welcome:        return String(localized: "continue")
        case .screenTime:
            return screenTimeStatus == .granted ?
                String(localized: "continue") :
                String(localized: "authorize_screen_time")
        case .guiltTrip:      return String(localized: "onboard_continue_shocked")
        case .howItWorks:     return String(localized: "continue")
        case .socialProof:    return String(localized: "continue")
        case .notifications:
            return notificationStatus == .granted ?
                String(localized: "finish_setup") :
                String(localized: "enable_notifications")
        }
    }

    private var showSkip: Bool {
        step == .notifications && notificationStatus != .granted
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onPrimary) {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView().tint(.white)
                    } else {
                        Text(primaryText)
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

            if showSkip {
                Button(action: onSkip) {
                    Text(String(localized: "skip_for_now"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(isRequesting)
            }
        }
    }
}

// MARK: - DeviceActivityReport Warm-Up
//
// Mounted invisibly as soon as Screen Time is granted. The extension
// `zenloopactivity` gets loaded + cached so that when the user reaches
// the GuiltTrip step, the report renders instantly instead of blank.

private struct DeviceActivityReportWarmUp: View {
    #if os(iOS)
    private var dailyFilter: DeviceActivityFilter {
        let today = Calendar.current.startOfDay(for: Date())
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: today, end: Date())),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    var body: some View {
        DeviceActivityReport(
            DeviceActivityReport.Context("GuiltTrip"),
            filter: dailyFilter
        )
    }
    #else
    var body: some View { EmptyView() }
    #endif
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
