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
    func canStartSession(actionName: String = "Démarrer une session") -> Bool {
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
        return canStartSession(actionName: "Créer un défi personnalisé")
    }
    
    /// Vérifie si l'utilisateur peut programmer des sessions
    func canScheduleSession() -> Bool {
        return canStartSession(actionName: "Programmer une session")
    }
    
    /// Vérifie si l'utilisateur peut utiliser les widgets
    func canUseWidgets() -> Bool {
        return canStartSession(actionName: "Utiliser les widgets")
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
            return "Votre abonnement a expiré. Renouvelez pour continuer à utiliser \(action.lowercased())."
        case .refunded:
            return "Votre abonnement a été remboursé. Souscrivez à nouveau pour accéder à \(action.lowercased())."
        case .none:
            return "Découvrez Zenloop Premium pour accéder à \(action.lowercased()) et bien plus encore !"
        default:
            return "Zenloop Premium requis pour \(action.lowercased())."
        }
    }
    
    func getPaywallTitle(for action: String) -> String {
        switch subscriptionStatus {
        case .expired:
            return "Renouveler Premium"
        case .refunded:
            return "Réactiver Premium"
        default:
            return "Découvrir Premium"
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
                return "Session rapide"
            case .startCustomSession:
                return "Session personnalisée"
            case .startScheduledSession:
                return "Session programmée"
            case .createChallenge:
                return "Défi personnalisé"
            case .useWidget:
                return "Widget"
            case .accessStats:
                return "Statistiques avancées"
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
                    blockedAction: gatekeeper.blockedAction ?? "cette fonctionnalité",
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

// MARK: - Premium Paywall View

struct PremiumPaywallView: View {
    let blockedAction: String
    let subscriptionStatus: SubscriptionStatus
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var gatekeeper = PremiumGatekeeper.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                blockedActionSection
                benefitsSection
                plansSection
                
                Spacer()
            }
            .padding(20)
            .background(backgroundGradient)
            .navigationTitle(gatekeeper.getPaywallTitle(for: blockedAction))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") {
                        gatekeeper.dismissPaywall()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 40))
                .foregroundColor(statusColor)
            
            Text(gatekeeper.getBlockedMessage(for: blockedAction))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
    
    private var blockedActionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                
                Text("Fonctionnalité bloquée")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text("« \(blockedAction) » nécessite Zenloop Premium")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                
                Text("Avec Premium, débloquez :")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(icon: "infinity", text: "Sessions illimitées")
                BenefitRow(icon: "apps.iphone", text: "Blocage d'apps avancé")
                BenefitRow(icon: "target", text: "Défis personnalisés")
                BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Statistiques détaillées")
                BenefitRow(icon: "clock.badge", text: "Sessions programmées")
                BenefitRow(icon: "widget.large", text: "Widgets de contrôle")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var plansSection: some View {
        RenewalPaywallView()
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

#Preview {
    Text("Test")
        .premiumGated()
}