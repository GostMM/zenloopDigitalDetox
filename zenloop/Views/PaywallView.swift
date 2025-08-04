//
//  PaywallView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct PaywallView: View {
    @Binding var isOnboardingComplete: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var isPurchasing = false
    
    var body: some View {
        ZStack {
            // Background premium
            PremiumBackground()
                .ignoresSafeArea(.all, edges: .all)
            
            VStack(spacing: 0) {
                // Header avec close button
                PaywallHeader(onClose: { dismiss() }, showContent: showContent)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Hero section premium
                        PremiumHeroSection(showContent: showContent)
                        
                        // Features premium
                        PremiumFeaturesSection(showContent: showContent)
                        
                        // Pricing plans
                        PricingSection(
                            selectedPlan: $selectedPlan,
                            showContent: showContent
                        )
                        
                        // CTA et garantie
                        PaywallCTASection(
                            selectedPlan: selectedPlan,
                            isPurchasing: isPurchasing,
                            onPurchase: { purchasePlan() },
                            showContent: showContent
                        )
                        
                        // Trust indicators
                        TrustSection(showContent: showContent)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                showContent = true
            }
        }
    }
    
    private func purchasePlan() {
        isPurchasing = true
        
        // Simulate purchase process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isPurchasing = false
            isOnboardingComplete = true
            dismiss()
        }
    }
}

// MARK: - Premium Background

struct PremiumBackground: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.08, green: 0.02, blue: 0.12),
                    Color(red: 0.02, green: 0.08, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated premium elements
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.1), .purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat.random(in: 50...150))
                    .position(
                        x: CGFloat.random(in: 0...400),
                        y: CGFloat.random(in: 0...800) + animationOffset
                    )
                    .animation(
                        .linear(duration: Double.random(in: 10...20))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...5)),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -200
            withAnimation {
                animationOffset = 200
            }
        }
    }
}

// MARK: - Paywall Header

struct PaywallHeader: View {
    let onClose: () -> Void
    let showContent: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Zenloop")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    
                    Text("Premium")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Premium Hero Section

struct PremiumHeroSection: View {
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Premium icon avec animations
            ZStack {
                // Glow effects
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.3 - Double(index) * 0.1), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(showContent ? 1.0 + Double(index) * 0.2 : 0.5)
                        .animation(
                            .easeInOut(duration: 2.0 + Double(index) * 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: showContent
                        )
                }
                
                // Main premium icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .cyan.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 8)
                }
            }
            .scaleEffect(showContent ? 1.0 : 0.3)
            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showContent)
            
            // Premium messaging
            VStack(spacing: 16) {
                Text("Débloque ton Potentiel")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Accède à toutes les fonctionnalités premium et transforme définitivement tes habitudes numériques")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }
}

// MARK: - Premium Features Section

struct PremiumFeaturesSection: View {
    let showContent: Bool
    
    private let features: [PremiumFeature] = [
        PremiumFeature(
            icon: "infinity",
            title: "Sessions Illimitées",
            description: "Autant de sessions de focus que tu veux",
            color: .cyan
        ),
        PremiumFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Analytics Avancés",
            description: "Statistiques détaillées et insights personnalisés",
            color: .blue
        ),
        PremiumFeature(
            icon: "trophy.fill",
            title: "Tous les Badges",
            description: "Débloquer tous les achievements premium",
            color: .purple
        ),
        PremiumFeature(
            icon: "icloud.fill",
            title: "Sync Multi-Appareils",
            description: "Synchronisation sur tous tes appareils",
            color: .green
        ),
        PremiumFeature(
            icon: "paintbrush.fill",
            title: "Thèmes Premium",
            description: "Personnalise l'app avec des thèmes exclusifs",
            color: .pink
        ),
        PremiumFeature(
            icon: "headphones",
            title: "Support Prioritaire",
            description: "Assistance premium 24/7",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Fonctionnalités Premium")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    PremiumFeatureCard(feature: feature)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7 + Double(index) * 0.1), value: showContent)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PremiumFeatureCard: View {
    let feature: PremiumFeature
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(feature.color)
            }
            
            VStack(spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(feature.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(feature.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Pricing Section

struct PricingSection: View {
    @Binding var selectedPlan: PricingPlan
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choisis ton Plan")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
            
            VStack(spacing: 12) {
                PricingCard(
                    plan: .yearly,
                    isSelected: selectedPlan == .yearly,
                    onSelect: { selectedPlan = .yearly }
                )
                .opacity(showContent ? 1 : 0)
                .offset(x: showContent ? 0 : -50)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.9), value: showContent)
                
                PricingCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    onSelect: { selectedPlan = .monthly }
                )
                .opacity(showContent ? 1 : 0)
                .offset(x: showContent ? 0 : 50)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0), value: showContent)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PricingCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        if plan == .yearly {
                            Text("POPULAIRE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                        }
                    }
                    
                    Text(plan.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(plan.color)
                    
                    if let oldPrice = plan.oldPrice {
                        Text(oldPrice)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .strikethrough()
                    }
                }
                
                Circle()
                    .fill(isSelected ? plan.color : .clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(plan.color, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? plan.color : .white.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

// MARK: - CTA Section

struct PaywallCTASection: View {
    let selectedPlan: PricingPlan
    let isPurchasing: Bool
    let onPurchase: () -> Void
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onPurchase) {
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
                    
                    Text(isPurchasing ? "Processing..." : "Démarrer Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [selectedPlan.color, selectedPlan.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: selectedPlan.color.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .disabled(isPurchasing)
            
            // Garantie
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text("Garantie satisfait ou remboursé 7 jours")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.1), value: showContent)
    }
}

// MARK: - Trust Section

struct TrustSection: View {
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                TrustIndicator(icon: "star.fill", text: "4.9★", subtitle: "App Store")
                TrustIndicator(icon: "person.2.fill", text: "10K+", subtitle: "Utilisateurs")
                TrustIndicator(icon: "shield.fill", text: "Sécurisé", subtitle: "Données")
            }
            
            Text("Rejoins des milliers d'utilisateurs qui ont déjà transformé leur relation avec la technologie")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.2), value: showContent)
    }
}

struct TrustIndicator: View {
    let icon: String
    let text: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
            
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Data Models

struct PremiumFeature {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

enum PricingPlan: CaseIterable {
    case yearly
    case monthly
    
    var title: String {
        switch self {
        case .yearly: return "Annuel"
        case .monthly: return "Mensuel"
        }
    }
    
    var subtitle: String {
        switch self {
        case .yearly: return "Économise 60%"
        case .monthly: return "Flexibilité maximale"
        }
    }
    
    var price: String {
        switch self {
        case .yearly: return "3,99€/mois"
        case .monthly: return "9,99€/mois"
        }
    }
    
    var oldPrice: String? {
        switch self {
        case .yearly: return "9,99€/mois"
        case .monthly: return nil
        }
    }
    
    var color: Color {
        switch self {
        case .yearly: return .cyan
        case .monthly: return .purple
        }
    }
}

#Preview {
    PaywallView(isOnboardingComplete: .constant(false))
}