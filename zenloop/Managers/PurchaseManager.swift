//
//  PurchaseManager.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Debug Configuration
struct PurchaseConfig {
    static let isTestEnvironment = false // Changez à false pour production
    static let enableSandboxMode = true
}

// MARK: - PricingPlan Enum

enum PricingPlan: CaseIterable {
    case lifetime
    case yearly
    case monthly
    
    var title: String {
        switch self {
        case .lifetime: return String(localized: "lifetime")
        case .yearly: return String(localized: "yearly")
        case .monthly: return String(localized: "monthly")
        }
    }
    
    var subtitle: String {
        switch self {
        case .lifetime: return String(localized: "one_payment_forever")
        case .yearly: return String(localized: "free_trial_7_days_yearly")
        case .monthly: return String(localized: "free_trial_7_days_monthly")
        }
    }
    
    var price: String {
        switch self {
        case .lifetime: return "99,99€"
        case .yearly: return "47,99€/an" // Fallback seulement
        case .monthly: return "9,99€/mois" // Fallback seulement
        }
    }
    
    var oldPrice: String? {
        switch self {
        case .lifetime: return "119,99€"
        case .yearly: return nil
        case .monthly: return nil
        }
    }
    
    var color: Color {
        switch self {
        case .lifetime: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .yearly: return .cyan
        case .monthly: return .purple
        }
    }
}

// MARK: - PricingPlan Extension
extension PricingPlan {
    var productIdentifier: String {
        switch self {
        case .lifetime: return "com.app.zenloop.premium.lifetime.v2"
        case .yearly: return "com.app.zenloop.premium.yearly.v2"
        case .monthly: return "com.app.zenloop.premium.monthly.v2"
        }
    }
    
    var displayName: String {
        switch self {
        case .lifetime: return "Zenloop Premium Lifetime"
        case .monthly: return "Zenloop Premium Monthly"
        case .yearly: return "Zenloop Premium Yearly"
        }
    }
    
    var fallbackPrice: String {
        switch self {
        case .lifetime: return "99,99€"
        case .monthly: return "9,99€/mois"
        case .yearly: return "47,99€/an"
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus {
    case none           // Pas d'abonnement
    case active         // Abonnement actif
    case expiringSoon   // Expire dans moins de 7 jours
    case expired        // Expiré
    case refunded       // Remboursé
    
    var displayText: String {
        switch self {
        case .none: return String(localized: "no_subscription")
        case .active: return String(localized: "subscription_active")
        case .expiringSoon: return String(localized: "subscription_expiring_soon_short")
        case .expired: return String(localized: "subscription_expired_short")
        case .refunded: return String(localized: "subscription_refunded_short")
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .active: return .green
        case .expiringSoon: return .orange
        case .expired: return .red
        case .refunded: return .red
        }
    }
}

// MARK: - Purchase Errors
enum PurchaseError: LocalizedError {
    case failedVerification
    case system(Error)
    case notInitialized
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "User transaction verification failed"
        case .system(let error):
            return error.localizedDescription
        case .notInitialized:
            return "PurchaseManager not initialized"
        case .productNotFound:
            return "Product not found"
        }
    }
}

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var isInitialized: Bool = false
    @Published var initializationError: String?
    
    // MARK: - Subscription Status Properties
    @Published var expiredProducts: [Product] = []
    @Published var refundedProducts: [Product] = []
    @Published var hasExpiredSubscription: Bool = false
    @Published var hasRefundedSubscription: Bool = false
    
    // MARK: - Private Properties
    private let productIdentifiers: Set<String> = [
        "com.app.zenloop.premium.lifetime.v2",
        "com.app.zenloop.premium.monthly.v2",
        "com.app.zenloop.premium.yearly.v2"
    ]
    
    private var transactionListener: Task<Void, Error>?
    private var initializationTask: Task<Void, Never>?
    
    private init() {
        NSLog("🚀 PurchaseManager init - Starting...")
        print("🚀 PurchaseManager init - Starting...")
        
        // Démarrer l'initialisation mais ne pas bloquer
        initializationTask = Task {
            await initialize()
        }
    }
    
    deinit {
        transactionListener?.cancel()
        initializationTask?.cancel()
    }
    
    // MARK: - Initialization
    func initialize() async {
        guard !isInitialized else {
            NSLog("⚠️ PurchaseManager already initialized")
            return
        }
        
        isLoading = true
        initializationError = nil
        
        NSLog("🔄 Starting PurchaseManager initialization...")
        
        do {
            // 1. Configurer le listener de transactions
            transactionListener = configureTransactionListener()
            NSLog("✅ Transaction listener configured")
            
            // 2. Charger les produits
            try await loadProductsWithRetry()
            NSLog("✅ Products loaded successfully: \(products.count)")
            
            // 3. Mettre à jour les produits achetés (maintenant que products est chargé)
            await updatePurchasedProducts()
            NSLog("✅ Purchased products updated. Premium status: \(isPremium)")
            
            isInitialized = true
            NSLog("🎉 PurchaseManager initialization complete")
            
        } catch {
            NSLog("❌ PurchaseManager initialization failed: \(error)")
            initializationError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Product Loading with Retry
    private func loadProductsWithRetry(maxRetries: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            NSLog("🛒 Loading products (attempt \(attempt)/\(maxRetries))...")
            
            do {
                try await loadProducts()
                return // Succès
            } catch {
                lastError = error
                NSLog("❌ Attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    // Attendre avant de réessayer (backoff exponentiel)
                    let delay = Double(attempt) * 1.0
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // Si tous les essais ont échoué
        throw lastError ?? PurchaseError.system(NSError(domain: "PurchaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load products after \(maxRetries) attempts"]))
    }
    
    // MARK: - Product Loading
    private func loadProducts() async throws {
        NSLog("🛒 Loading products for identifiers: \(productIdentifiers)")
        
        let storeProducts = try await Product.products(for: productIdentifiers)
        
        guard !storeProducts.isEmpty else {
            throw PurchaseError.system(NSError(domain: "PurchaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No products found in App Store"]))
        }
        
        NSLog("✅ Found \(storeProducts.count) products from StoreKit")
        
        for product in storeProducts {
            NSLog("📦 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
        }
        
        // Trier les produits : lifetime > yearly > monthly
        let sortedProducts = storeProducts.sorted { product1, product2 in
            if product1.id.contains("lifetime") && !product2.id.contains("lifetime") { return true }
            if !product1.id.contains("lifetime") && product2.id.contains("lifetime") { return false }
            if product1.id.contains("yearly") && !product2.id.contains("yearly") { return true }
            if !product1.id.contains("yearly") && product2.id.contains("yearly") { return false }
            return product1.price < product2.price
        }
        
        self.products = sortedProducts
        NSLog("🎯 Products loaded and sorted: \(sortedProducts.map { $0.id })")
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws {
        guard isInitialized else {
            throw PurchaseError.notInitialized
        }
        
        print("💳 Starting purchase for product: \(product.id)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            print("✅ Purchase successful, verifying transaction...")
            let transaction = try checkVerified(verificationResult)
            print("✅ Transaction verified: \(transaction.productID)")
            
            // Transaction réussie - sera trackée depuis PaywallView
            
            // Mettre à jour les produits achetés
            await updatePurchasedProducts()
            
            // Finaliser la transaction
            await transaction.finish()
            print("✅ Transaction finished successfully")
            
        case .userCancelled:
            print("❌ User cancelled the purchase")
            throw PurchaseError.system(NSError(domain: "PurchaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "purchase_cancelled_by_user")]))
            
        case .pending:
            print("⏳ Purchase is pending (e.g., parental approval)")
            throw PurchaseError.system(NSError(domain: "PurchaseManager", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "purchase_pending_approval")]))
            
        @unknown default:
            print("❓ Unknown purchase result")
            throw PurchaseError.system(NSError(domain: "PurchaseManager", code: 3, userInfo: [NSLocalizedDescriptionKey: String(localized: "purchase_unknown_result")]))
        }
    }
    
    func purchasePlan(_ plan: PricingPlan) async throws {
        NSLog("🛒 [PURCHASE] Attempting to purchase plan: \(plan.title) (\(plan.productIdentifier))")
        NSLog("🛒 [PURCHASE] Available products: \(products.map { "\($0.id): \($0.type)" })")
        
        guard let product = products.first(where: { $0.id == plan.productIdentifier }) else {
            NSLog("❌ [PURCHASE] Product not found: \(plan.productIdentifier)")
            NSLog("❌ [PURCHASE] Available product IDs: \(products.map(\.id))")
            throw PurchaseError.productNotFound
        }
        
        NSLog("🛒 [PURCHASE] Found product: \(product.id) - Type: \(product.type) - Price: \(product.displayPrice)")
        
        if PurchaseConfig.isTestEnvironment {
            NSLog("🧪 [PURCHASE] Test environment - Product type: \(product.type)")
            if product.type == .autoRenewable {
                NSLog("⚠️ [PURCHASE] Auto-renewable subscription in TestFlight may not work without App Store approval")
            }
        }
        
        try await purchase(product)
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async throws {
        guard isInitialized else {
            throw PurchaseError.notInitialized
        }
        
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - Transaction Listener
    private func configureTransactionListener() -> Task<Void, Error> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    NSLog("🔄 Transaction update received: \(transaction.productID)")
                    await updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    NSLog("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        // S'assurer que les produits sont chargés
        guard !products.isEmpty else {
            NSLog("⚠️ Products not loaded yet, skipping purchased products update")
            return
        }
        
        var newPurchasedProducts: [Product] = []
        var expiredProducts: [Product] = []
        var refundedProducts: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                NSLog("🔍 Checking entitlement: \(transaction.productID)")
                
                // Vérifier le statut de la transaction
                if let revocationDate = transaction.revocationDate {
                    NSLog("🚫 Product refunded: \(transaction.productID) on \(revocationDate)")
                    if let product = products.first(where: { $0.id == transaction.productID }) {
                        refundedProducts.append(product)
                    }
                    continue
                }
                
                // Vérifier l'expiration pour les abonnements
                if let expirationDate = transaction.expirationDate {
                    if expirationDate < Date() {
                        NSLog("⏰ Product expired: \(transaction.productID) on \(expirationDate)")
                        if let product = products.first(where: { $0.id == transaction.productID }) {
                            expiredProducts.append(product)
                        }
                        continue
                    } else {
                        NSLog("⏳ Product expires: \(transaction.productID) on \(expirationDate)")
                    }
                }
                
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    newPurchasedProducts.append(product)
                    NSLog("✅ Found active product: \(product.id)")
                }
            } catch {
                NSLog("❌ Failed to verify transaction: \(error)")
            }
        }
        
        self.purchasedProducts = newPurchasedProducts
        self.expiredProducts = expiredProducts
        self.refundedProducts = refundedProducts
        
        // Déterminer si l'utilisateur est premium
        let wasPremium = self.isPremium
        self.isPremium = !newPurchasedProducts.isEmpty
        
        // Synchroniser avec les UserDefaults partagés pour les widgets
        syncPremiumStatusWithSharedDefaults()
        
        // Mettre à jour les statuts
        self.hasExpiredSubscription = !expiredProducts.isEmpty
        self.hasRefundedSubscription = !refundedProducts.isEmpty
        
        if wasPremium != self.isPremium {
            NSLog("🎯 Premium status changed: \(wasPremium) -> \(self.isPremium)")
        }
        
        NSLog("📊 Current purchased products: \(newPurchasedProducts.map { $0.id })")
        if !expiredProducts.isEmpty {
            NSLog("⏰ Expired products: \(expiredProducts.map { $0.id })")
        }
        if !refundedProducts.isEmpty {
            NSLog("🚫 Refunded products: \(refundedProducts.map { $0.id })")
        }
        NSLog("👑 Premium status: \(self.isPremium)")
    }
    
    // MARK: - Helper Methods
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Helpers
    func lifetimeProduct() -> Product? {
        return products.first { $0.id.contains("lifetime") }
    }
    
    func monthlyProduct() -> Product? {
        return products.first { $0.id.contains("monthly") }
    }
    
    func yearlyProduct() -> Product? {
        return products.first { $0.id.contains("yearly") }
    }
    
    func product(for plan: PricingPlan) -> Product? {
        return products.first { $0.id == plan.productIdentifier }
    }
    
    func isProductPurchased(_ product: Product) -> Bool {
        return purchasedProducts.contains(product)
    }
    
    func isPlanPurchased(_ plan: PricingPlan) -> Bool {
        return purchasedProducts.contains { $0.id == plan.productIdentifier }
    }
    
    // MARK: - Formatted Prices
    func formattedPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func formattedMonthlyPrice(for product: Product) -> String? {
        guard product.id.contains("yearly") else { return nil }
        
        let yearlyPrice = product.price
        let monthlyPrice = yearlyPrice / 12
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        
        return formatter.string(from: NSDecimalNumber(decimal: monthlyPrice))
    }
    
    func priceForPlan(_ plan: PricingPlan) -> String {
        guard let product = products.first(where: { $0.id == plan.productIdentifier }) else {
            NSLog("⚠️ Product not found for plan: \(plan.productIdentifier), using fallback price")
            return plan.fallbackPrice // Utilise le fallback price au bon format
        }
        
        // Utilise le prix dynamique de StoreKit
        return product.displayPrice
    }
    
    private func hasFreeTrial(_ product: Product) -> Bool {
        // Vérifier si le produit a une période d'essai gratuit
        if #available(iOS 15.0, *) {
            return product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        }
        // Pour les abonnements, on assume qu'ils ont un essai gratuit de 7 jours
        return product.id.contains("monthly") || product.id.contains("yearly")
    }
    
    func oldPriceForPlan(_ plan: PricingPlan) -> String? {
        guard plan == .yearly else { return nil }
        
        let monthlyProduct = monthlyProduct()
        guard let monthlyPrice = monthlyProduct?.price else { return nil }
        
        let yearlyEquivalent = monthlyPrice * 12
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = monthlyProduct?.priceFormatStyle.locale ?? Locale.current
        
        return formatter.string(from: NSDecimalNumber(decimal: yearlyEquivalent))
    }
    
    // MARK: - Computed Properties
    var hasActiveSubscription: Bool {
        return isPremium
    }
    
    var activeSubscriptionProduct: Product? {
        return purchasedProducts.first
    }
    
    // MARK: - Edge Cases Methods
    
    /// Obtenir la date d'expiration de l'abonnement actif
    func subscriptionExpirationDate() async -> Date? {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if purchasedProducts.contains(where: { $0.id == transaction.productID }) {
                    return transaction.expirationDate
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    /// Vérifier si l'abonnement expire bientôt (dans les 7 jours)
    func isSubscriptionExpiringSoon() async -> Bool {
        guard let expirationDate = await subscriptionExpirationDate() else { return false }
        let sevenDaysFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60)
        return expirationDate <= sevenDaysFromNow
    }
    
    /// Obtenir le statut détaillé de l'abonnement
    func getSubscriptionStatus() async -> SubscriptionStatus {
        if isPremium {
            if await isSubscriptionExpiringSoon() {
                return .expiringSoon
            }
            return .active
        } else if hasExpiredSubscription {
            return .expired
        } else if hasRefundedSubscription {
            return .refunded
        } else {
            return .none
        }
    }
    
    // MARK: - Manual Refresh
    func refresh() async {
        guard isInitialized else { return }
        
        isLoading = true
        await updatePurchasedProducts()
        isLoading = false
    }
    
    /// Recharger les produits (méthode publique)
    func reloadProducts() async {
        do {
            try await loadProductsWithRetry()
            await updatePurchasedProducts()
        } catch {
            NSLog("❌ Failed to reload products: \(error)")
        }
    }
    
    // MARK: - Widget Synchronization
    
    private func syncPremiumStatusWithSharedDefaults() {
        let shared = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        shared.set(isPremium, forKey: "isPremium")
        shared.synchronize()
        
        NSLog("🔄 Premium status synced with widgets: \(isPremium)")
    }
}

// MARK: - Product Extensions
extension Product {
    var isLifetime: Bool {
        return id.contains("lifetime")
    }
    
    var isMonthly: Bool {
        return id.contains("monthly")
    }
    
    var isYearly: Bool {
        return id.contains("yearly")
    }
    
    var planType: PricingPlan {
        if isLifetime { return .lifetime }
        return isYearly ? .yearly : .monthly
    }
}

// MARK: - Convenience Extensions
extension PurchaseManager {
    
    /// Attendre que l'initialisation soit terminée
    func waitForInitialization() async {
        while !isInitialized && initializationError == nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    /// Forcer une réinitialisation complète
    func forceReinitialize() async {
        isInitialized = false
        initializationError = nil
        products = []
        purchasedProducts = []
        isPremium = false
        
        await initialize()
    }
}