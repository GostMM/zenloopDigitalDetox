//
//  PaywallView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {
    @Binding var isOnboardingComplete: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showContent = false
    @State private var selectedPlan: PricingPlan = .lifetime
    @State private var isPurchasing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var messageIndex = 0
    @State private var glowIntensity: Double = 0.3
    @State private var purchaseError: String?
    
    // Haptic Feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private let hypnoticMessages = [
        String(localized: "hypnotic_unlock_potential"),
        String(localized: "hypnotic_stop_scrolling"),
        String(localized: "hypnotic_focus_master"), 
        String(localized: "hypnotic_time_is_gold"),
        String(localized: "hypnotic_transform_productivity"),
        String(localized: "hypnotic_unlock_superpower"),
        String(localized: "hypnotic_take_control_now"),
        String(localized: "hypnotic_premium_version")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background hypnotique
                HypnoticBackground()
                    .ignoresSafeArea(.all, edges: .all)
                
                // Interface principale sans scroll
                VStack(spacing: 0) {
                    // Header compact
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zenloop")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text("PREMIUM")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { 
                            impactLight.impactOccurred()
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
                    
                    // Centre hypnotique
                    VStack(spacing: 24) {
                        // Cercle central hypnotique
                        ZStack {
                            // Anneaux animés
                            ForEach(0..<5, id: \.self) { index in
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .cyan.opacity(0.8 - Double(index) * 0.15),
                                                .purple.opacity(0.6 - Double(index) * 0.1),
                                                .pink.opacity(0.4 - Double(index) * 0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2 - CGFloat(index) * 0.3
                                    )
                                    .frame(width: 100 + CGFloat(index * 20), height: 100 + CGFloat(index * 20))
                                    .rotationEffect(.degrees(rotationAngle + Double(index * 45)))
                                    .scaleEffect(pulseScale + Double(index) * 0.05)
                                    .opacity(glowIntensity + Double(index) * 0.1)
                            }
                            
                            // Centre lumineux
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.9), .cyan.opacity(0.7), .purple.opacity(0.5)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 50
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: .cyan, radius: 20)
                                .shadow(color: .purple, radius: 30)
                                .scaleEffect(pulseScale)
                            
                            // Icône couronne
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(pulseScale)
                                .shadow(color: .white, radius: 10)
                        }
                        
                        // Message hypnotique animé
                        Text(hypnoticMessages[messageIndex])
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .cyan, radius: 8)
                            .scaleEffect(showContent ? 1.0 : 0.8)
                            .opacity(showContent ? 1 : 0)
                        
                        // Sous-message
                        Text(String(localized: "paywall_ultimate_experience"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1 : 0)
                    }
                    
                    Spacer()
                    
                    // Section des plans compacte - 3 offres en vertical
                    VStack(spacing: 12) {
                        // Plan Lifetime (priorité haute)
                        PremiumPlanCard(
                            plan: .lifetime,
                            isSelected: selectedPlan == .lifetime,
                            isCompact: false,
                            purchaseManager: purchaseManager,
                            onSelect: { 
                                impactMedium.impactOccurred()
                                selectedPlan = .lifetime 
                            }
                        )
                        
                        // Plans récurrents côte à côte
                        HStack(spacing: 12) {
                            // Plan annuel
                            PremiumPlanCard(
                                plan: .yearly,
                                isSelected: selectedPlan == .yearly,
                                isCompact: true,
                                purchaseManager: purchaseManager,
                                onSelect: { 
                                    impactMedium.impactOccurred()
                                    selectedPlan = .yearly 
                                }
                            )
                            
                            // Plan mensuel
                            PremiumPlanCard(
                                plan: .monthly,
                                isSelected: selectedPlan == .monthly,
                                isCompact: true,
                                purchaseManager: purchaseManager,
                                onSelect: { 
                                    impactMedium.impactOccurred()
                                    selectedPlan = .monthly 
                                }
                            )
                        }
                        
                        // CTA hypnotique
                        Button(action: { 
                            impactHeavy.impactOccurred()
                            purchasePlan() 
                        }) {
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
                                
                                Text(isPurchasing ? "Activation..." : "DÉVERROUILLE TON POTENTIEL")
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
                            .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                            .scaleEffect(isPurchasing ? 0.95 : 1.0)
                        }
                        .disabled(isPurchasing)
                        
                        // Garantie et restore
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text("Garantie 7 jours satisfait ou remboursé")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Button("Restaurer les achats") {
                                impactLight.impactOccurred()
                                Task {
                                    do {
                                        try await purchaseManager.restorePurchases()
                                        if purchaseManager.isPremium {
                                            notificationFeedback.notificationOccurred(.success)
                                            isOnboardingComplete = true
                                            dismiss()
                                        }
                                    } catch {
                                        print("❌ Failed to restore purchases: \(error)")
                                        notificationFeedback.notificationOccurred(.error)
                                    }
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan)
                        }
                        .opacity(showContent ? 1 : 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // Feedback haptique d'entrée
            impactMedium.impactOccurred()
            startAnimations()
            
            // Force reload products si nécessaire
            Task {
                if purchaseManager.products.isEmpty {
                    print("🔄 Products empty, reloading...")
                    await purchaseManager.reloadProducts()
                }
                print("📊 Available products: \(purchaseManager.products.count)")
                for product in purchaseManager.products {
                    print("📦 \(product.id): \(product.displayPrice)")
                }
            }
        }
    }
    
    private func startAnimations() {
        // Animation d'apparition
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }
        
        // Rotation continue
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulsation hypnotique
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Variation du glow
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        
        // Messages rotatifs avec feedback haptique
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            impactLight.impactOccurred()
            withAnimation(.easeInOut(duration: 0.5)) {
                messageIndex = (messageIndex + 1) % hypnoticMessages.count
            }
        }
    }
    
    private func purchasePlan() {
        guard let product = getSelectedProduct() else { 
            notificationFeedback.notificationOccurred(.error)
            return 
        }
        
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await purchaseManager.purchase(product)
                
                // Succès de l'achat - feedback de succès
                await MainActor.run {
                    notificationFeedback.notificationOccurred(.success)
                    isPurchasing = false
                    isOnboardingComplete = true
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    notificationFeedback.notificationOccurred(.error)
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
    }
    
    private func getSelectedProduct() -> Product? {
        let product = purchaseManager.products.first { product in
            product.planType == selectedPlan
        }
        print("🛒 Getting selected product for plan: \(selectedPlan)")
        print("🛒 Available products: \(purchaseManager.products.count)")
        print("🛒 Found product: \(product?.id ?? "nil")")
        return product
    }
}

// MARK: - Background Hypnotique

struct HypnoticBackground: View {
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
            ForEach(0..<20, id: \.self) { index in
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
                    .frame(width: CGFloat.random(in: 20...80))
                    .position(
                        x: CGFloat.random(in: 0...400) + CGFloat(sin(phase + Double(index)) * 30),
                        y: CGFloat.random(in: 0...800) + CGFloat(cos(phase + Double(index) * 0.7) * 40)
                    )
                    .opacity(0.6 + sin(phase + Double(index) * 0.5) * 0.4)
                    .scaleEffect(0.8 + sin(phase + Double(index) * 0.3) * 0.2)
            }
            
            // Vagues hypnotiques
            ForEach(0..<3, id: \.self) { index in
                WaveShape(offset: waveOffset + Double(index) * 0.3, amplitude: 30 + Double(index) * 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(0.3 - Double(index) * 0.1),
                                .purple.opacity(0.2 - Double(index) * 0.05),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .offset(y: CGFloat(index * 100))
            }
        }
        .onAppear {
            // Animation des particules
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
            
            // Animation des vagues
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                waveOffset = .pi * 2
            }
        }
    }
}

struct WaveShape: Shape {
    var offset: Double
    var amplitude: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midHeight = rect.height / 2
        let wavelength = rect.width / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relativeX = x / wavelength
            let sine = sin(relativeX + offset)
            let y = midHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// MARK: - Plan Card Compact

struct PremiumPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let isCompact: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Badge spécial selon le plan
                Group {
                    if plan == .lifetime {
                        Text("MEILLEURE OFFRE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.0, green: 0.84, blue: 0.0), in: Capsule())
                    } else if plan == .yearly {
                        HStack(spacing: 4) {
                            Text("7 JOURS GRATUITS")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                            
                            Text("POPULAIRE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                        }
                    } else if plan == .monthly {
                        Text("7 JOURS GRATUITS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    } else {
                        Spacer().frame(height: 16) // Espace pour alignement
                    }
                }
                
                VStack(spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(realPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(plan.color)
                    
                    if let oldPrice = realOldPrice {
                        Text(oldPrice)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .strikethrough()
                    }
                    
                    Text(plan.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Indicateur de sélection
                Circle()
                    .fill(isSelected ? plan.color : .clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(plan.color, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? plan.color : .white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(plan.color.opacity(0.1))
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? plan.color.opacity(0.3) : .clear,
                radius: isSelected ? 10 : 0
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var realPrice: String {
        return purchaseManager.priceForPlan(plan)
    }
    
    private var realOldPrice: String? {
        return purchaseManager.oldPriceForPlan(plan)
    }
}

// MARK: - Data Models (moved to PurchaseManager)

#Preview {
    PaywallView(isOnboardingComplete: .constant(false))
}