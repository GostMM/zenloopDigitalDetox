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
            PaywallView()
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


#Preview {
    SubscriptionStatusView()
}