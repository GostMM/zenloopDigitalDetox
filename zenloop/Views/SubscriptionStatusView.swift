//
//  SubscriptionStatusView.swift
//  zenloop
//
//  Created by Claude Code on 31/08/2025.
//

import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var subscriptionStatus: SubscriptionStatus = .none
    @State private var expirationDate: Date?
    @State private var showRenewalSheet = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            statusSection
            actionSection
            Spacer()
        }
        .padding(20)
        .background(backgroundGradient)
        .task {
            await refreshSubscriptionStatus()
        }
        .sheet(isPresented: $showRenewalSheet) {
            RenewalPaywallView()
        }
        .refreshable {
            await refreshSubscriptionStatus()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text(String(localized: "premium_status"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(String(localized: "manage_zenloop_subscription"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // Status Card
            VStack(spacing: 12) {
                HStack {
                    statusIcon
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionStatus.displayText)
                            .font(.headline)
                            .foregroundColor(subscriptionStatus.color)
                        
                        if let expirationDate = expirationDate {
                            Text(expirationText(for: expirationDate))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Détails supplémentaires selon le statut
                statusDetails
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch subscriptionStatus {
            case .active:
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
            case .expiringSoon:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .expired:
                Image(systemName: "xmark.shield.fill")
                    .foregroundColor(.red)
            case .refunded:
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundColor(.red)
            case .none:
                Image(systemName: "crown")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }
    
    @ViewBuilder
    private var statusDetails: some View {
        switch subscriptionStatus {
        case .expiringSoon:
            VStack(spacing: 8) {
                Text(String(localized: "subscription_expiring_soon"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Text(String(localized: "renew_to_avoid_interruption"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
        case .expired:
            VStack(spacing: 8) {
                Text(String(localized: "subscription_expired"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Text(String(localized: "renew_to_continue_premium"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
        case .refunded:
            VStack(spacing: 8) {
                Text(String(localized: "subscription_refunded"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Text(String(localized: "subscription_refunded_description"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
        default:
            EmptyView()
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            switch subscriptionStatus {
            case .active:
                refreshButton
                
            case .expiringSoon, .expired, .refunded, .none:
                renewButton
                refreshButton
            }
        }
    }
    
    private var renewButton: some View {
        Button(action: {
            showRenewalSheet = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(renewButtonText)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
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
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshSubscriptionStatus()
            }
        }) {
            HStack(spacing: 8) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(String(localized: "refresh"))
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isRefreshing)
    }
    
    private var renewButtonText: String {
        switch subscriptionStatus {
        case .expiringSoon:
            return String(localized: "renew_now")
        case .expired:
            return String(localized: "reactivate_premium")
        case .refunded:
            return String(localized: "subscribe_again")
        case .none:
            return String(localized: "become_premium")
        default:
            return String(localized: "renew")
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private func expirationText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        
        if date < Date() {
            return "Expiré \(formatter.localizedString(for: date, relativeTo: Date()))"
        } else {
            return "Expire \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
    }
    
    private func refreshSubscriptionStatus() async {
        isRefreshing = true
        
        // Actualiser les données d'achat
        await purchaseManager.refresh()
        
        // Obtenir le statut et la date d'expiration
        subscriptionStatus = await purchaseManager.getSubscriptionStatus()
        expirationDate = await purchaseManager.subscriptionExpirationDate()
        
        isRefreshing = false
    }
}

// MARK: - Renewal Paywall

struct RenewalPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                plansSection
                benefitsSection
                purchaseButton
                
                if let error = purchaseError {
                    errorSection(error)
                }
                
                Spacer()
            }
            .padding(20)
            .background(backgroundGradient)
            .navigationTitle(String(localized: "renew_premium"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "close")) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text(String(localized: "continue_premium_experience"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(String(localized: "choose_plan_continue_premium"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach([PricingPlan.yearly, .monthly], id: \.self) { plan in
                PlanRow(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    purchaseManager: purchaseManager
                ) {
                    selectedPlan = plan
                }
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "included_features"))
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                BenefitRow(icon: "apps.iphone", text: String(localized: "unlimited_app_blocking"))
                BenefitRow(icon: "target", text: String(localized: "personalized_focus_sessions"))
                BenefitRow(icon: "chart.line.uptrend.xyaxis", text: String(localized: "detailed_statistics"))
                BenefitRow(icon: "bell.badge", text: String(localized: "smart_notifications"))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var purchaseButton: some View {
        Button(action: purchaseSelected) {
            HStack(spacing: 12) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(String(localized: "renew_now"))
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundColor(.white)
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
            .shadow(color: .cyan.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .disabled(isPurchasing)
    }
    
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(String(localized: "payment_error"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text(error)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(String(localized: "retry")) {
                purchaseError = nil
                purchaseSelected()
            }
            .font(.caption)
            .foregroundColor(.cyan)
        }
        .padding()
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
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
    
    private func purchaseSelected() {
        guard let product = purchaseManager.product(for: selectedPlan) else {
            purchaseError = String(localized: "product_not_found")
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await purchaseManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PlanRow: View {
    let plan: PricingPlan
    let isSelected: Bool
    let purchaseManager: PurchaseManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(purchaseManager.priceForPlan(plan))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(plan.color)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? plan.color : .white.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? plan.color : .clear, lineWidth: 2)
                    )
            )
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyan)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

#Preview {
    SubscriptionStatusView()
}