//
//  PremiumGatekeeper.swift
//  zenloop
//
//  Created by Claude Code on 31/08/2025.
//

import SwiftUI
import Combine

/// Service qui contrôle l'accès aux fonctionnalités Premium
/// Bloque le lancement de sessions pour les utilisateurs non-Premium
@MainActor
class PremiumGatekeeper: ObservableObject {
    static let shared = PremiumGatekeeper()
    
    @Published var showPaywallForSession = false
    @Published var blockedAction: String? = nil
    
    private let purchaseManager = PurchaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Écouter les changements de statut Premium
        purchaseManager.$isPremium
            .sink { [weak self] isPremium in
                if isPremium {
                    // Si l'utilisateur devient Premium, fermer le paywall
                    self?.showPaywallForSession = false
                    self?.blockedAction = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Control
    
    /// Vérifie si l'utilisateur peut lancer une session
    /// Retourne true si autorisé, false si bloqué (affiche le paywall)
    func canStartSession(actionName: String = String(localized: "start_session")) -> Bool {
        // Vérifier le statut Premium
        if purchaseManager.isPremium {
            return true
        }
        
        // Utilisateur non-Premium : bloquer et afficher le paywall
        blockedAction = actionName
        showPaywallForSession = true
        
        print("🚫 [GATEKEEPER] Action bloquée pour utilisateur non-Premium: \(actionName)")
        return false
    }
    
    /// Exécute une action seulement si l'utilisateur est Premium
    /// Sinon affiche le paywall
    func executeIfPremium(actionName: String, action: @escaping () -> Void) {
        if canStartSession(actionName: actionName) {
            action()
        }
    }
    
    /// Exécute une action async seulement si l'utilisateur est Premium
    func executeIfPremiumAsync(actionName: String, action: @escaping () async -> Void) {
        if canStartSession(actionName: actionName) {
            Task {
                await action()
            }
        }
    }
    
    // MARK: - Challenge Control
    
    /// Vérifie si l'utilisateur peut accéder aux défis personnalisés
    func canCreateChallenge() -> Bool {
        return canStartSession(actionName: String(localized: "create_custom_challenge"))
    }
    
    /// Vérifie si l'utilisateur peut programmer des sessions
    func canScheduleSession() -> Bool {
        return canStartSession(actionName: String(localized: "schedule_session"))
    }
    
    /// Vérifie si l'utilisateur peut utiliser les widgets
    func canUseWidgets() -> Bool {
        return canStartSession(actionName: String(localized: "use_widgets"))
    }
    
    // MARK: - Premium Status Helpers
    
    var isPremium: Bool {
        purchaseManager.isPremium
    }
    
    var subscriptionStatus: SubscriptionStatus {
        // Utiliser Task pour obtenir le statut async dans un contexte sync
        // Pour une utilisation immédiate, on se base sur isPremium
        if purchaseManager.isPremium {
            return .active
        } else if purchaseManager.hasExpiredSubscription {
            return .expired
        } else if purchaseManager.hasRefundedSubscription {
            return .refunded
        } else {
            return .none
        }
    }
    
    // MARK: - User-Friendly Messages
    
    func getBlockedMessage(for action: String) -> String {
        switch subscriptionStatus {
        case .expired:
            return String(localized: "subscription_expired_renew_message").replacingOccurrences(of: "%@", with: action.lowercased())
        case .refunded:
            return String(localized: "subscription_refunded_subscribe_message").replacingOccurrences(of: "%@", with: action.lowercased())
        case .none:
            return String(localized: "discover_premium_message").replacingOccurrences(of: "%@", with: action.lowercased())
        default:
            return String(localized: "premium_required_message").replacingOccurrences(of: "%@", with: action.lowercased())
        }
    }
    
    func getPaywallTitle(for action: String) -> String {
        switch subscriptionStatus {
        case .expired:
            return String(localized: "renew_premium")
        case .refunded:
            return String(localized: "reactivate_premium")
        default:
            return String(localized: "discover_premium")
        }
    }
    
    // MARK: - Reset Method
    
    func dismissPaywall() {
        showPaywallForSession = false
        blockedAction = nil
    }
}

// MARK: - Convenience Extensions

extension PremiumGatekeeper {
    /// Wrapper pour les actions de session courantes
    enum SessionAction {
        case startQuickSession
        case startCustomSession
        case startScheduledSession
        case createChallenge
        case useWidget
        case accessStats
        
        var displayName: String {
            switch self {
            case .startQuickSession:
                return String(localized: "quick_session")
            case .startCustomSession:
                return String(localized: "custom_session")
            case .startScheduledSession:
                return String(localized: "scheduled_session")
            case .createChallenge:
                return String(localized: "custom_challenge")
            case .useWidget:
                return String(localized: "widget")
            case .accessStats:
                return String(localized: "advanced_statistics")
            }
        }
    }
    
    /// Vérifie l'accès pour une action spécifique
    func canPerform(_ action: SessionAction) -> Bool {
        return canStartSession(actionName: action.displayName)
    }
    
    /// Exécute une action de session si autorisée
    func performIfAllowed(_ action: SessionAction, execute: @escaping () -> Void) {
        executeIfPremium(actionName: action.displayName, action: execute)
    }
    
    /// Exécute une action de session async si autorisée
    func performIfAllowedAsync(_ action: SessionAction, execute: @escaping () async -> Void) {
        executeIfPremiumAsync(actionName: action.displayName, action: execute)
    }
}

// MARK: - SwiftUI Integration

/// Modificateur pour intégrer le PremiumGatekeeper dans les vues
struct PremiumGated: ViewModifier {
    @StateObject private var gatekeeper = PremiumGatekeeper.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $gatekeeper.showPaywallForSession) {
                PremiumPaywallView(
                    blockedAction: gatekeeper.blockedAction ?? String(localized: "this_feature"),
                    subscriptionStatus: gatekeeper.subscriptionStatus
                )
            }
    }
}

extension View {
    func premiumGated() -> some View {
        modifier(PremiumGated())
    }
}

// MARK: - Premium Paywall View (Style Hypnotique)

struct PremiumPaywallView: View {
    let blockedAction: String
    let subscriptionStatus: SubscriptionStatus
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var gatekeeper = PremiumGatekeeper.shared
    
    // État des animations
    @State private var showContent = false
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var isPurchasing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var glowIntensity: Double = 0.3
    @State private var purchaseError: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background hypnotique
                PremiumHypnoticBackground()
                    .ignoresSafeArea(.all, edges: .all)
                
                // Interface principale
                VStack(spacing: 0) {
                    // Header compact avec fermeture
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zenloop Premium")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(gatekeeper.getPaywallTitle(for: blockedAction))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button(action: { 
                            gatekeeper.dismissPaywall()
                            dismiss() 
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Centre hypnotique avec action bloquée
                    VStack(spacing: 20) {
                        // Animation centrale
                        ZStack {
                            // Anneaux animés
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .red.opacity(0.8 - Double(index) * 0.2),
                                                .orange.opacity(0.6 - Double(index) * 0.15),
                                                .yellow.opacity(0.4 - Double(index) * 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2 - CGFloat(index) * 0.3
                                    )
                                    .frame(width: 80 + CGFloat(index * 15), height: 80 + CGFloat(index * 15))
                                    .rotationEffect(.degrees(rotationAngle + Double(index * 60)))
                                    .scaleEffect(pulseScale + Double(index) * 0.05)
                            }
                            
                            // Icône de blocage au centre
                            Image(systemName: "lock.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.red)
                                .scaleEffect(pulseScale)
                                .shadow(color: .red, radius: 10)
                        }
                        
                        // Message de blocage
                        VStack(spacing: 8) {
                            Text(String(localized: "blocked_feature"))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .red, radius: 5)
                            
                            Text("« \(blockedAction) »")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Text(gatekeeper.getBlockedMessage(for: blockedAction))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Section des plans dans le style PaywallView
                    VStack(spacing: 12) {
                        // Plans côte à côte
                        HStack(spacing: 12) {
                            // Plan annuel
                            HypnoticPlanCard(
                                plan: .yearly,
                                isSelected: selectedPlan == .yearly,
                                purchaseManager: purchaseManager,
                                onSelect: { selectedPlan = .yearly }
                            )
                            
                            // Plan mensuel
                            HypnoticPlanCard(
                                plan: .monthly,
                                isSelected: selectedPlan == .monthly,
                                purchaseManager: purchaseManager,
                                onSelect: { selectedPlan = .monthly }
                            )
                        }
                        
                        // CTA hypnotique
                        Button(action: { purchasePlan() }) {
                            HStack(spacing: 12) {
                                if isPurchasing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Text(isPurchasing ? String(localized: "processing") : String(localized: "unlock_premium_now"))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                ZStack {
                                    // Background principal
                                    LinearGradient(
                                        colors: [.cyan, .purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    
                                    // Overlay animé
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .offset(x: showContent ? 200 : -200)
                                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: showContent)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .shadow(color: .cyan.opacity(0.5), radius: 15, x: 0, y: 5)
                            .scaleEffect(isPurchasing ? 0.95 : 1.0)
                        }
                        .disabled(isPurchasing)
                        
                        // Garantie
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text(String(localized: "money_back_guarantee"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .opacity(showContent ? 1 : 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animation d'apparition
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }
        
        // Rotation continue
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulsation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
        
        // Variation du glow
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    private func purchasePlan() {
        guard let product = purchaseManager.product(for: selectedPlan) else { 
            return 
        }
        
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await purchaseManager.purchase(product)
                // Le gatekeeper se fermera automatiquement quand isPremium devient true
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
    }
    
    private var statusIcon: String {
        switch subscriptionStatus {
        case .expired:
            return "clock.badge.exclamationmark"
        case .refunded:
            return "arrow.uturn.backward.circle"
        default:
            return "crown.fill"
        }
    }
    
    private var statusColor: Color {
        switch subscriptionStatus {
        case .expired:
            return .orange
        case .refunded:
            return .red
        default:
            return .yellow
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Background Hypnotique Premium

struct PremiumHypnoticBackground: View {
    @State private var phase: Double = 0
    @State private var waveOffset: Double = 0
    
    var body: some View {
        ZStack {
            // Base sombre
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.01, blue: 0.05),
                    Color(red: 0.05, green: 0.01, blue: 0.08),
                    Color(red: 0.08, green: 0.02, blue: 0.12),
                    Color(red: 0.01, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Particules flottantes hypnotiques
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .cyan.opacity(0.4),
                                .purple.opacity(0.3),
                                .pink.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: CGFloat.random(in: 20...60))
                    .position(
                        x: CGFloat.random(in: 0...400) + CGFloat(sin(phase + Double(index)) * 20),
                        y: CGFloat.random(in: 0...800) + CGFloat(cos(phase + Double(index) * 0.7) * 30)
                    )
                    .opacity(0.6 + sin(phase + Double(index) * 0.5) * 0.3)
                    .scaleEffect(0.8 + sin(phase + Double(index) * 0.3) * 0.2)
            }
        }
        .onAppear {
            // Animation des particules
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Plan Card Hypnotique

struct HypnoticPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Badge spécial
                Group {
                    if plan == .yearly {
                        Text(String(localized: "popular"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    } else {
                        Text(String(localized: "flexible"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                }
                
                VStack(spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(realPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(plan.color)
                    
                    Text(plan.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Indicateur de sélection
                Circle()
                    .fill(isSelected ? plan.color : .clear)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(plan.color, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? plan.color : .white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(plan.color.opacity(0.1))
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? plan.color.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var realPrice: String {
        return purchaseManager.priceForPlan(plan)
    }
}

// MARK: - Plan Card Component (Legacy)

struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isRecommended: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if isRecommended {
                            Text(String(localized: "popular"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(price)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    if title == String(localized: "yearly") {
                        Text(String(localized: "per_year"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text(String(localized: "per_month"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRecommended ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Test")
        .premiumGated()
}