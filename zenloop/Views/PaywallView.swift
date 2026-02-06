//
// PaywallView.swift
// zenloop
//
// Created by MROIVILI MOUSTOIFA on 03/08/2025.
//
import SwiftUI
import StoreKit
import UIKit
import AVKit
import AVFoundation

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
    @State private var selectedPlan: PricingPlan = .lifetime  // Sélection par défaut sur achat unique
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    // Haptic Feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
   
    var body: some View {
        ZStack {
            // Background vidéo en plein écran
            VideoBackgroundView()

            // Dégradé dark en bas pour lisibilité
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.3),
                        .black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 350)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Interface principale minimaliste
            VStack(spacing: 0) {
                // Header avec titre à gauche
                HStack {
                    Text("Zenloop Premium")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 10)

                    Spacer()

                    Button(action: {
                        impactLight.impactOccurred()
                        Task {
                            await FirebaseManager.shared.trackPaywallAction(action: .dismissed)
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                    Spacer()

                    // Plans en row horizontal compact
                    HStack(spacing: 12) {
                        // LIFETIME - Achat unique
                        CompactPlanCard(
                            plan: .lifetime,
                            isSelected: selectedPlan == .lifetime,
                            purchaseManager: purchaseManager,
                            onSelect: {
                                impactMedium.impactOccurred()
                                selectedPlan = .lifetime
                            }
                        )

                        // MONTHLY - Abonnement
                        CompactPlanCard(
                            plan: .monthly,
                            isSelected: selectedPlan == .monthly,
                            purchaseManager: purchaseManager,
                            onSelect: {
                                impactMedium.impactOccurred()
                                selectedPlan = .monthly
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(showContent ? 1 : 0)

                    // CTA minimaliste
                    VStack(spacing: 14) {
                        Button(action: {
                            impactHeavy.impactOccurred()
                            purchasePlan()
                        }) {
                            HStack(spacing: 10) {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(String(localized: "unlock_your_potential_cta"))
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
                        .disabled(isPurchasing)

                        // Footer compact
                        VStack(spacing: 12) {
                            Button(String(localized: "restore_purchases")) {
                                impactLight.impactOccurred()
                                Task {
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 8) {
                                Link(String(localized: "privacy_policy"), destination: URL(string: "https://www.zenloop.me/privacy-policy")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))

                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))

                                Link(String(localized: "terms_of_use"), destination: URL(string: "https://www.zenloop.me/eula")!)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .fullScreenCover(isPresented: $showPermissionsSetup) {
            PermissionsSetupView(isOnboardingComplete: $isOnboardingComplete)
        }
        .onAppear {
            impactMedium.impactOccurred()

            // Animation d'apparition simple
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }

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

// MARK: - Video Background
struct VideoBackgroundView: View {
    @StateObject private var playerViewModel = VideoPlayerViewModel()

    var body: some View {
        // Vidéo en plein écran SANS AUCUNE SUPERPOSITION
        if let player = playerViewModel.player {
            PaywallVideoPlayerView(player: player)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    print("🎬 [VIDEO] VideoBackgroundView appeared")
                    // Force play au cas où
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if player.rate == 0 {
                            player.play()
                            print("▶️ [VIDEO] Force play from view")
                        }
                    }
                }
        } else {
            // Fond noir en attendant
            Color.black
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                )
                .onAppear {
                    playerViewModel.setupPlayer()
                }
        }
    }
}

// MARK: - Paywall Video Player UIViewRepresentable
struct PaywallVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        print("🎬 [VIDEO UI] Creating UIView for video player")
        let view = UIView(frame: .zero)
        view.backgroundColor = .black // Fond noir pour test

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.insertSublayer(playerLayer, at: 0)

        context.coordinator.playerLayer = playerLayer

        // Forcer le player à jouer
        DispatchQueue.main.async {
            player.play()
            print("✅ [VIDEO UI] UIView created, forcing play. Rate: \(player.rate)")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.playerLayer?.frame = uiView.bounds
            print("🔄 [VIDEO UI] Updated frame: \(uiView.bounds), rate: \(player.rate)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Video Player ViewModel
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var statusObserver: NSKeyValueObservation?
    private var timeObserver: Any?

    func setupPlayer() {
        print("🎬 [VIDEO] Starting video setup...")
        
        // IMPORTANT: Configurer l'audio session pour vidéo muette
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ [VIDEO] Audio session configured")
        } catch {
            print("⚠️ [VIDEO] Audio session error: \(error)")
        }

        // Essayer d'abord avec le nom exact de votre asset
        var videoURL: URL?
        
        // Option 1: NSDataAsset (si la vidéo est dans Assets.xcassets)
        if let asset = NSDataAsset(name: "Zenloop") {
            print("✅ [VIDEO] Found NSDataAsset 'Zenloop', size: \(asset.data.count) bytes")

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("zenloop_paywall.mp4")

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try asset.data.write(to: tempURL)
                videoURL = tempURL
                print("✅ [VIDEO] Video written to temp: \(tempURL)")
            } catch {
                print("❌ [VIDEO] Failed to write video: \(error)")
            }
        }

        // Option 2: Bundle resource (si la vidéo est dans le dossier du projet)
        if videoURL == nil {
            // Essayez différentes variantes du nom
            let possibleNames = [
                ("Zenloop", "mp4"),
                ("Zenloop 2.1", "mp4"),
                ("Zenloopvideo", "mp4")
            ]

            for (name, ext) in possibleNames {
                if let bundleURL = Bundle.main.url(forResource: name, withExtension: ext) {
                    videoURL = bundleURL
                    print("✅ [VIDEO] Found video in bundle: \(name).\(ext)")
                    break
                }
            }
        }
        
        guard let url = videoURL else {
            print("❌ [VIDEO] No video found. Check asset name in Assets.xcassets or bundle")
            return
        }
        
        setupPlayerWithURL(url)
    }

    private func setupPlayerWithURL(_ url: URL) {
        print("🎬 [VIDEO] Setting up player with URL: \(url)")
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Configuration essentielle
        queuePlayer.isMuted = true
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        queuePlayer.actionAtItemEnd = .none
        
        // Observer le statut
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    print("✅ [VIDEO] Status: Ready to play")
                    print("📐 [VIDEO] Video size: \(item.presentationSize)")
                    print("⏱️ [VIDEO] Duration: \(item.duration.seconds)s")
                    print("🎬 [VIDEO] Has video tracks: \(item.asset.tracks.count)")
                    queuePlayer.play()
                    print("▶️ [VIDEO] Play() called - rate: \(queuePlayer.rate)")
                case .failed:
                    if let error = item.error {
                        print("❌ [VIDEO] Failed: \(error.localizedDescription)")
                    }
                case .unknown:
                    print("⏳ [VIDEO] Status: Unknown")
                @unknown default:
                    break
                }
            }
        }
        
        // Observer pour vérifier que la vidéo joue réellement
        timeObserver = queuePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { time in
            let currentTime = CMTimeGetSeconds(time)
            if currentTime > 0 {
                print("▶️ [VIDEO] Playing at \(String(format: "%.1f", currentTime))s")
            }
        }
        
        // Setup du looper APRÈS avoir configuré les observers
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        self.player = queuePlayer
        print("✅ [VIDEO] Player setup complete")
        
        // Force play après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if queuePlayer.rate == 0 {
                queuePlayer.play()
                print("🔄 [VIDEO] Force play after delay")
            }
        }
    }

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        statusObserver?.invalidate()
        statusObserver = nil
        player?.pause()
        player = nil
        playerLooper = nil
        timeObserver = nil
        print("🧹 [VIDEO] Cleanup complete")
    }
}

// MARK: - Compact Plan Card (Horizontal)
struct CompactPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Titre compact
                Text(plan == .lifetime ? "Achat unique" : "Mensuel")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                // Prix principal
                Text(realPrice)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)

                // Sous-titre
                Text(plan == .lifetime ? "Accès à vie" : "/mois")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? .white.opacity(0.25) : .white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? .white : .white.opacity(0.3), lineWidth: isSelected ? 2.5 : 1.5)
                    )
            )
            .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 12)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var realPrice: String {
        return purchaseManager.priceForPlan(plan)
    }
}

// MARK: - Minimal Plan Card (Vertical - Legacy)
struct MinimalPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan == .lifetime ? "Achat unique" : "Abonnement")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(plan == .lifetime ? "Accès à vie" : "Annulable à tout moment")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(realPrice)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    if plan == .monthly {
                        Text("/\(String(localized: "per_month"))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? .white.opacity(0.25) : .white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? .white.opacity(0.6) : .white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var realPrice: String {
        return purchaseManager.priceForPlan(plan)
    }
}

// MARK: - Plan Card Redesigned (Legacy - kept for reference)
struct PremiumPlanCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let isCompact: Bool
    let purchaseManager: PurchaseManager
    let onSelect: () -> Void

    private var fontSizeTitle: CGFloat { isCompact ? 14 : 20 }
    private var fontSizePrice: CGFloat { isCompact ? 16 : 24 }
    private var fontSizeSubtitle: CGFloat { isCompact ? 9 : 11 }
    private var fontSizeBadge: CGFloat { isCompact ? 8 : 11 }
    private var fontSizeOldPrice: CGFloat { isCompact ? 10 : 12 }
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
                    // Badge en haut - ORDRE OPTIMISÉ
                    HStack {
                        if plan == .yearly {
                            // YEARLY = MEILLEUR CHOIX (badges proéminents)
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                    Text(String(localized: "popular"))
                                        .font(.system(size: fontSizeBadge, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .shadow(color: .orange.opacity(0.5), radius: 4, x: 0, y: 2)

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
                            }
                        } else if plan == .monthly {
                            // MONTHLY = Option flexible
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
                        } else if plan == .lifetime {
                            // LIFETIME = Premium pour convaincus
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
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(oldPrice)
                                        .font(.system(size: fontSizeOldPrice, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .strikethrough()
                                    if plan == .monthly || plan == .yearly {
                                        Text("/\(plan == .monthly ? String(localized: "per_month") : String(localized: "per_year"))")
                                            .font(.system(size: 8, weight: .regular))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(realPrice)
                                    .font(.system(size: fontSizePrice, weight: .black))
                                    .foregroundColor(plan.color)
                                    .shadow(color: plan.color.opacity(0.5), radius: 8)

                                if plan == .monthly || plan == .yearly {
                                    Text("/\(plan == .monthly ? String(localized: "per_month") : String(localized: "per_year"))")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(plan.color.opacity(0.7))
                                }
                            }
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
            // Background noir avec jeu de lumière comme l'onboarding
            Color.black
                .ignoresSafeArea()

            // Lumière douce en haut
            RadialGradient(
                colors: [
                    .white.opacity(0.05),
                    .clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Lumière douce en bas
            RadialGradient(
                colors: [
                    .white.opacity(0.03),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header minimaliste
                HStack {
                    Text(String(localized: "final_setup"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? .white : .white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Current step content
                if currentStep == 0 {
                    screenTimePermissionStep
                } else {
                    notificationPermissionStep
                }

                Spacer()

                // Action buttons style paywall
                VStack(spacing: 14) {
                    // Primary action button
                    Button(action: handleAction) {
                        HStack(spacing: 10) {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(buttonText)
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
                    .disabled(isRequesting)

                    // Skip button for notifications step
                    if currentStep == 1 && onboardingManager.notificationStatus != .granted {
                        Button(action: {
                            print("⏭️ [PERMISSIONS] Skipping notifications")
                            finishSetup()
                        }) {
                            Text(String(localized: "skip_for_now"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(isRequesting)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
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
        VStack(spacing: 32) {
            // Icône avec halo
            ZStack {
                // Halo doux
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.1),
                                .white.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.3), radius: 20)
            }

            // Texte
            VStack(spacing: 16) {
                Text(String(localized: "screen_time_access"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.2), radius: 10)

                Text(String(localized: "screen_time_explanation"))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)

                // Status
                if onboardingManager.screenTimeStatus == .granted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "authorized"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.green.opacity(0.15), in: Capsule())
                    .padding(.top, 10)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var notificationPermissionStep: some View {
        VStack(spacing: 32) {
            // Icône avec halo
            ZStack {
                // Halo doux
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.1),
                                .white.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.3), radius: 20)
            }

            // Texte
            VStack(spacing: 16) {
                Text(String(localized: "smart_notifications"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.2), radius: 10)

                Text(String(localized: "notification_explanation"))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)

                Text(String(localized: "optional_can_skip"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))

                // Status
                if onboardingManager.notificationStatus == .granted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "enabled"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.green.opacity(0.15), in: Capsule())
                    .padding(.top, 10)
                }
            }
        }
        .padding(.horizontal, 24)
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