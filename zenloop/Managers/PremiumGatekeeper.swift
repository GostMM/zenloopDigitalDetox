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
    
    let purchaseManager = PurchaseManager.shared
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
                PaywallView()
                    .onReceive(gatekeeper.purchaseManager.$isPremium) { isPremium in
                        if isPremium {
                            gatekeeper.dismissPaywall()
                        }
                    }
            }
    }
}

extension View {
    func premiumGated() -> some View {
        modifier(PremiumGated())
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