//
// PaywallView.swift
// zenloop
//
// Created by MROIVILI MOUSTOIFA on 03/08/2025.
//
import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {
    @Binding var isOnboardingComplete: Bool?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showPermissionsSetup = false
    
    // Initializer for onboarding context
    init(isOnboardingComplete: Binding<Bool>) {
        let optionalBinding = Binding<Bool?>(
            get: { isOnboardingComplete.wrappedValue },
            set: { newValue in
                if let value = newValue {
                    isOnboardingComplete.wrappedValue = value
                }
            }
        )
        self._isOnboardingComplete = optionalBinding
    }
    
    // Initializer for session/premium gate context
    init() {
        self._isOnboardingComplete = .constant(nil)
    }
    @State private var showContent = false
    @State private var selectedPlan: PricingPlan = .lifetime  // Sélection par défaut sur le meilleur plan
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
               
                // Interface principale avec scroll
                VStack(spacing: 0) {
                    // Header compact fixe
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
                            // Firebase: Tracker la fermeture du paywall
                            Task {
                                await FirebaseManager.shared.trackPaywallAction(action: .dismissed)
                            }
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

                    // Contenu scrollable
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Centre hypnotique (plus compact)
                            VStack(spacing: 20) {
                                // Cercle central hypnotique (réduit)
                                ZStack {
                                    // Anneaux animés
                                    ForEach(0..<4, id: \.self) { index in
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
                                            .frame(width: 80 + CGFloat(index * 15), height: 80 + CGFloat(index * 15))
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
                                                endRadius: 40
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .shadow(color: .cyan, radius: 15)
                                        .shadow(color: .purple, radius: 20)
                                        .scaleEffect(pulseScale)

                                    // Icône couronne
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .scaleEffect(pulseScale)
                                        .shadow(color: .white, radius: 8)
                                }
                                .padding(.top, 20)

                                // Message hypnotique animé
                                Text(hypnoticMessages[messageIndex])
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .cyan, radius: 8)
                                    .scaleEffect(showContent ? 1.0 : 0.8)
                                    .opacity(showContent ? 1 : 0)
                                    .padding(.horizontal, 20)

                                // Sous-message
                                Text(String(localized: "paywall_ultimate_experience"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .opacity(showContent ? 1 : 0)
                                    .padding(.horizontal, 20)
                            }

                            // Bénéfices Premium (compact et impactant)
                            VStack(spacing: 10) {
                                PremiumFeatureRow(icon: "infinity", text: String(localized: "unlimited_focus_sessions"), color: .cyan)
                                PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: String(localized: "advanced_analytics"), color: .purple)
                                PremiumFeatureRow(icon: "bell.badge.fill", text: String(localized: "smart_reminders"), color: .orange)
                                PremiumFeatureRow(icon: "lock.shield.fill", text: String(localized: "priority_support"), color: .green)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)

                            // Tous les plans visibles simultanément
                            VStack(spacing: 12) {
                                // Lifetime - Le plus attrayant (BEST OFFER)
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

                                // Yearly - Populaire
                                PremiumPlanCard(
                                    plan: .yearly,
                                    isSelected: selectedPlan == .yearly,
                                    isCompact: false,
                                    purchaseManager: purchaseManager,
                                    onSelect: {
                                        impactMedium.impactOccurred()
                                        selectedPlan = .yearly
                                    }
                                )

                                // Monthly - Option flexible
                                PremiumPlanCard(
                                    plan: .monthly,
                                    isSelected: selectedPlan == .monthly,
                                    isCompact: false,
                                    purchaseManager: purchaseManager,
                                    onSelect: {
                                        impactMedium.impactOccurred()
                                        selectedPlan = .monthly
                                    }
                                )
                            }
                            .padding(.horizontal, 16)

                            // Espace avant le bouton
                            Spacer(minLength: 20)
                        }
                    }

                    // CTA et footer fixes en bas
                    VStack(spacing: 12) {
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

                                Text(isPurchasing ? String(localized: "activating") : String(localized: "unlock_your_potential_cta"))
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

                                Text(String(localized: "money_back_guarantee_7_days"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Button(String(localized: "restore_purchases")) {
                                impactLight.impactOccurred()
                                Task {
                                    // Firebase: Tracker la restauration
                                    await FirebaseManager.shared.trackPaywallAction(action: .restorePurchases)

                                    do {
                                        try await purchaseManager.restorePurchases()
                                        if purchaseManager.isPremium {
                                            notificationFeedback.notificationOccurred(.success)
                                            isOnboardingComplete? = true
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .fullScreenCover(isPresented: $showPermissionsSetup) {
            PermissionsSetupView(isOnboardingComplete: $isOnboardingComplete)
        }
        .onAppear {
            // Feedback haptique d'entrée
            impactMedium.impactOccurred()
            startAnimations()
           
            // Firebase: Tracker l'affichage du paywall
            Task {
                print("📱 [PAYWALL] PaywallView appeared - tracking viewed action")
                await FirebaseManager.shared.trackPaywallAction(action: .viewed)
                print("📱 [PAYWALL] Tracking call completed")
            }
           
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
            // Firebase: Tracker la tentative d'achat
            await FirebaseManager.shared.trackPaywallAction(
                action: .purchaseAttempted,
                productId: product.id,
                price: product.displayPrice
            )
           
            do {
                try await purchaseManager.purchase(product)
               
                // Firebase: Tracker l'achat réussi
                await FirebaseManager.shared.trackPaywallAction(
                    action: .purchaseCompleted,
                    productId: product.id,
                    price: product.displayPrice
                )
               
                await FirebaseManager.shared.trackSubscriptionPurchase(
                    productId: product.id,
                    price: product.displayPrice.replacingOccurrences(of: "€", with: "")
                )
               
                await FirebaseManager.shared.trackSubscriptionEvent(
                    event: .subscribed,
                    productId: product.id
                )
               
                // Succès de l'achat - afficher les permissions
                await MainActor.run {
                    notificationFeedback.notificationOccurred(.success)
                    isPurchasing = false
                    showPermissionsSetup = true
                }
               
            } catch {
                // Firebase: Tracker l'échec ou annulation de l'achat
                let errorDescription = error.localizedDescription.lowercased()
                let action: PaywallAction = errorDescription.contains("annulé") || errorDescription.contains("cancelled")
                    ? .purchaseCanceled
                    : .purchaseFailed
               
                await FirebaseManager.shared.trackPaywallAction(
                    action: action,
                    productId: product.id,
                    price: product.displayPrice
                )
               
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
            ForEach(0..<30, id: \.self) { index in  // Augmenté pour plus de magnificence
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
                    .frame(width: CGFloat.random(in: 10...60))  // Tailles variées pour plus de dynamisme
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width) + CGFloat(sin(phase + Double(index)) * 40),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height) + CGFloat(cos(phase + Double(index) * 0.7) * 50)
                    )
                    .opacity(0.5 + sin(phase + Double(index) * 0.5) * 0.3)
                    .scaleEffect(0.7 + sin(phase + Double(index) * 0.3) * 0.3)
                    .blur(radius: 2)  // Ajout de blur pour un effet plus doux et hypnotique
            }
           
            // Vagues hypnotiques
            ForEach(0..<4, id: \.self) { index in  // Une vague supplémentaire
                WaveShape(offset: waveOffset + Double(index) * 0.25, amplitude: 25 + Double(index) * 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(0.3 - Double(index) * 0.08),
                                .purple.opacity(0.2 - Double(index) * 0.04),
                                .pink.opacity(0.1 - Double(index) * 0.02),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5 - Double(index) * 0.5
                    )
                    .offset(y: CGFloat(index * 80))
                    .blur(radius: 1)  // Blur léger pour adoucir
            }
        }
        .onAppear {
            // Animation des particules
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {  // Durée allongée pour plus de fluidité
                phase = .pi * 2
            }
           
            // Animation des vagues
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {  // Durée ajustée
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
        let wavelength = rect.width / 2.5  // Ajusté pour des vagues plus douces
       
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

// MARK: - Plan Card Redesigned
struct PremiumPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let isCompact: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void

    private var fontSizeTitle: CGFloat { isCompact ? 14 : 20 }
    private var fontSizePrice: CGFloat { isCompact ? 18 : 32 }
    private var fontSizeSubtitle: CGFloat { isCompact ? 9 : 11 }
    private var fontSizeBadge: CGFloat { isCompact ? 8 : 11 }
    private var fontSizeOldPrice: CGFloat { isCompact ? 10 : 14 }
    private var paddingVertical: CGFloat { isCompact ? 12 : 18 }
    private var paddingHorizontal: CGFloat { isCompact ? 8 : 20 }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Indicateur de sélection à gauche
                ZStack {
                    Circle()
                        .fill(isSelected ? plan.color : .clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(plan.color, lineWidth: 2)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Contenu principal
                VStack(alignment: .leading, spacing: 8) {
                    // Badge en haut
                    HStack {
                        if plan == .lifetime {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9))
                                Text(String(localized: "best_offer"))
                                    .font(.system(size: fontSizeBadge, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 1.0, green: 0.84, blue: 0.0), in: Capsule())
                        } else if plan == .yearly {
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 8))
                                    Text(String(localized: "free_trial_7_days"))
                                        .font(.system(size: fontSizeBadge, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green, in: Capsule())

                                Text(String(localized: "popular"))
                                    .font(.system(size: fontSizeBadge, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.orange, in: Capsule())
                            }
                        } else if plan == .monthly {
                            HStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 8))
                                Text(String(localized: "free_trial_7_days"))
                                    .font(.system(size: fontSizeBadge, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green, in: Capsule())
                        }

                        Spacer()
                    }

                    // Titre et prix
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.system(size: fontSizeTitle, weight: .bold))
                                .foregroundColor(.white)

                            Text(plan.subtitle)
                                .font(.system(size: fontSizeSubtitle, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let oldPrice = realOldPrice {
                                Text(oldPrice)
                                    .font(.system(size: fontSizeOldPrice, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .strikethrough()
                            }

                            Text(realPrice)
                                .font(.system(size: fontSizePrice, weight: .black))
                                .foregroundColor(plan.color)
                                .shadow(color: plan.color.opacity(0.5), radius: 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, paddingVertical)
            .padding(.horizontal, paddingHorizontal)
            .background(
                ZStack {
                    // Background avec effet de profondeur
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)

                    // Bordure lumineuse si sélectionné
                    if isSelected {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        plan.color.opacity(0.15),
                                        plan.color.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Bordure
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isSelected ?
                                LinearGradient(
                                    colors: [plan.color, plan.color.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 3 : 1.5
                        )
                }
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .shadow(
                color: isSelected ? plan.color.opacity(0.4) : .black.opacity(0.2),
                radius: isSelected ? 15 : 5,
                x: 0,
                y: isSelected ? 8 : 2
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var realPrice: String {
        return purchaseManager.priceForPlan(plan)
    }

    private var realOldPrice: String? {
        return purchaseManager.oldPriceForPlan(plan)
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(color)
        }
    }
}

// MARK: - Permissions Setup View (After Purchase)
struct PermissionsSetupView: View {
    @Binding var isOnboardingComplete: Bool?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var currentStep = 0
    @State private var showContent = false
    @State private var isRequesting = false

    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "final_setup"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "two_quick_steps"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    // Progress
                    Text("\(currentStep + 1)/2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Current step content
                if currentStep == 0 {
                    screenTimePermissionStep
                } else {
                    notificationPermissionStep
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Primary action button
                    Button(action: handleAction) {
                    HStack(spacing: 12) {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonText)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)

                            Image(systemName: currentStep == 1 ? "checkmark" : "arrow.right")
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
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .cyan.opacity(0.3), radius: 12)
                    }
                    .disabled(isRequesting)
                    .opacity(isRequesting ? 0.6 : 1.0)

                    // Skip button for notifications step
                    if currentStep == 1 && onboardingManager.notificationStatus != .granted {
                        Button(action: {
                            print("⏭️ [PERMISSIONS] Skipping notifications")
                            finishSetup()
                        }) {
                            Text(String(localized: "skip_for_now"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(isRequesting)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showContent = true
            }
            onboardingManager.checkPermissionStatuses()
        }
    }

    @ViewBuilder
    private var screenTimePermissionStep: some View {
        VStack(spacing: 30) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.3), .cyan.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.cyan)
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1 : 0)

            VStack(spacing: 16) {
                Text(String(localized: "screen_time_access"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(String(localized: "screen_time_explanation"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                // Status
                if onboardingManager.screenTimeStatus == .granted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "authorized"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 10)
                }
            }
            .opacity(showContent ? 1 : 0)
        }
    }

    @ViewBuilder
    private var notificationPermissionStep: some View {
        VStack(spacing: 30) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.orange)
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1 : 0)

            VStack(spacing: 16) {
                Text(String(localized: "smart_notifications"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(String(localized: "notification_explanation"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Text(String(localized: "optional_can_skip"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)

                // Status
                if onboardingManager.notificationStatus == .granted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "enabled"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 10)
                }
            }
            .opacity(showContent ? 1 : 0)
        }
    }

    private var buttonText: String {
        if currentStep == 0 {
            return onboardingManager.screenTimeStatus == .granted ?
                String(localized: "continue") :
                String(localized: "authorize_screen_time")
        } else {
            return onboardingManager.notificationStatus == .granted ?
                String(localized: "finish_setup") :
                String(localized: "enable_notifications")
        }
    }

    private func handleAction() {
        impactMedium.impactOccurred()

        print("🔵 [PERMISSIONS] handleAction called - currentStep: \(currentStep)")

        if currentStep == 0 {
            // Screen Time
            print("🔵 [PERMISSIONS] Screen Time step - current status: \(onboardingManager.screenTimeStatus)")

            if onboardingManager.screenTimeStatus == .granted {
                print("✅ [PERMISSIONS] Screen Time already granted, moving to step 1")
                withAnimation {
                    currentStep = 1
                }
            } else {
                print("🔵 [PERMISSIONS] Requesting Screen Time permission...")
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestScreenTimePermission()
                    print("🔵 [PERMISSIONS] Screen Time request result: \(granted)")

                    await MainActor.run {
                        isRequesting = false
                        if granted {
                            print("✅ [PERMISSIONS] Screen Time granted, moving to step 1")
                            notificationFeedback.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    currentStep = 1
                                }
                            }
                        } else {
                            print("❌ [PERMISSIONS] Screen Time denied or error")
                            notificationFeedback.notificationOccurred(.error)
                        }
                    }
                }
            }
        } else {
            // Notifications
            print("🔵 [PERMISSIONS] Notifications step - current status: \(onboardingManager.notificationStatus)")

            if onboardingManager.notificationStatus != .granted {
                print("🔵 [PERMISSIONS] Requesting Notification permission...")
                isRequesting = true
                Task {
                    let granted = await onboardingManager.requestNotificationPermission()
                    print("🔵 [PERMISSIONS] Notification request result: \(granted)")

                    await MainActor.run {
                        isRequesting = false
                        finishSetup()
                    }
                }
            } else {
                print("✅ [PERMISSIONS] Notifications already granted, finishing setup")
                finishSetup()
            }
        }
    }

    private func finishSetup() {
        notificationFeedback.notificationOccurred(.success)
        isOnboardingComplete? = true
        dismiss()
    }
}

// MARK: - Data Models (moved to PurchaseManager)
#Preview {
    PaywallView()
}