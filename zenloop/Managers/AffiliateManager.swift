//
//  AffiliateManager.swift
//  zenloop
//
//  Système d'affiliation avec deep linking et tracking Firebase
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Statut de l'affiliation
enum AffiliateStatus: String, Codable {
    case pending = "pending"           // En attente (trial actif)
    case converted = "converted"       // Converti (trial → paid)
    case active = "active"             // Utilisateur premium actif
    case expired = "expired"           // Trial expiré sans conversion
    case refunded = "refunded"         // Remboursé
}

/// Type d'achat
enum PurchaseType: String, Codable {
    case trial = "trial"               // Période d'essai gratuite
    case monthly = "monthly"           // Abonnement mensuel
    case yearly = "yearly"             // Abonnement annuel
    case lifetime = "lifetime"         // Achat à vie
}

/// Modèle d'affiliation
struct AffiliateData: Codable {
    let affiliateCode: String          // Code de l'affilié (ex: "JOHN123")
    let userId: String                 // ID de l'utilisateur qui s'inscrit
    let timestamp: Date                // Date d'inscription
    var purchaseType: PurchaseType?    // Type d'achat (nil si pas encore acheté)
    var purchaseDate: Date?            // Date d'achat
    var status: AffiliateStatus        // Statut actuel
    var trialEndDate: Date?            // Date de fin du trial
    var revenue: Double?               // Revenu généré (pour l'affilié)
    var deviceInfo: [String: String]   // Info device pour tracking
}

/// Conversion d'affiliation (quand un trial devient paid)
struct AffiliateConversion: Codable {
    let affiliateCode: String
    let userId: String
    let fromType: PurchaseType         // trial
    let toType: PurchaseType           // monthly/yearly/lifetime
    let conversionDate: Date
    let revenue: Double
}

@MainActor
class AffiliateManager: ObservableObject {
    static let shared = AffiliateManager()

    @Published var currentAffiliateCode: String?
    @Published var affiliateData: AffiliateData?

    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard

    // Keys pour UserDefaults
    private let affiliateCodeKey = "zenloop.affiliate.code"
    private let affiliateDataKey = "zenloop.affiliate.data"
    private let affiliateProcessedKey = "zenloop.affiliate.processed"

    private init() {
        loadSavedAffiliateCode()
    }

    // MARK: - Deep Linking

    /// Traiter un deep link avec code affilié
    /// URL format: zenloop://affiliate?code=JOHN123
    func processDeepLink(url: URL) {
        print("🔗 [AFFILIATE] Processing deep link: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "affiliate" || components.path.contains("affiliate") else {
            print("❌ [AFFILIATE] Not an affiliate link")
            return
        }

        // Extraire le code affilié
        let queryItems = components.queryItems ?? []
        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            print("❌ [AFFILIATE] No affiliate code found in URL")
            return
        }

        // Sauvegarder le code
        saveAffiliateCode(code)
        print("✅ [AFFILIATE] Code saved: \(code)")
    }

    /// Sauvegarder le code affilié
    func saveAffiliateCode(_ code: String) {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        currentAffiliateCode = cleanCode
        userDefaults.set(cleanCode, forKey: affiliateCodeKey)
        userDefaults.synchronize()

        print("💾 [AFFILIATE] Code saved to UserDefaults: \(cleanCode)")
    }

    /// Charger le code affilié sauvegardé
    private func loadSavedAffiliateCode() {
        if let code = userDefaults.string(forKey: affiliateCodeKey) {
            currentAffiliateCode = code
            print("📱 [AFFILIATE] Loaded saved code: \(code)")
        }
    }

    // MARK: - Firebase Integration

    /// Enregistrer l'affiliation dans Firebase lors de l'inscription
    func registerAffiliation(userId: String) async {
        guard let affiliateCode = currentAffiliateCode,
              !hasProcessedAffiliation() else {
            print("⚠️ [AFFILIATE] No code or already processed")
            return
        }

        let affiliateData = AffiliateData(
            affiliateCode: affiliateCode,
            userId: userId,
            timestamp: Date(),
            purchaseType: nil,
            purchaseDate: nil,
            status: .pending,
            trialEndDate: nil,
            revenue: nil,
            deviceInfo: getDeviceInfo()
        )

        do {
            // Enregistrer dans Firebase
            let docRef = db.collection("affiliates").document(userId)
            try await docRef.setData([
                "affiliateCode": affiliateData.affiliateCode,
                "userId": affiliateData.userId,
                "timestamp": Timestamp(date: affiliateData.timestamp),
                "status": affiliateData.status.rawValue,
                "deviceInfo": affiliateData.deviceInfo
            ])

            // Incrémenter le compteur de l'affilié
            let affiliateRef = db.collection("affiliateStats").document(affiliateCode)
            try await affiliateRef.setData([
                "code": affiliateCode,
                "totalSignups": FieldValue.increment(Int64(1)),
                "lastSignupDate": Timestamp(date: Date())
            ], merge: true)

            // Marquer comme traité
            markAffiliationAsProcessed()
            self.affiliateData = affiliateData

            print("✅ [AFFILIATE] Registration saved to Firebase")

        } catch {
            print("❌ [AFFILIATE] Failed to save: \(error.localizedDescription)")
        }
    }

    /// Tracker un achat avec statut trial/paid
    func trackPurchase(
        userId: String,
        purchaseType: PurchaseType,
        isTrial: Bool,
        price: Double,
        trialEndDate: Date? = nil
    ) async {
        guard let affiliateCode = currentAffiliateCode else {
            print("⚠️ [AFFILIATE] No affiliate code to track purchase")
            return
        }

        let status: AffiliateStatus = isTrial ? .pending : .active

        do {
            let docRef = db.collection("affiliates").document(userId)

            var updateData: [String: Any] = [
                "purchaseType": purchaseType.rawValue,
                "purchaseDate": Timestamp(date: Date()),
                "status": status.rawValue,
                "isTrial": isTrial
            ]

            if let trialEnd = trialEndDate {
                updateData["trialEndDate"] = Timestamp(date: trialEnd)
            }

            // Si ce n'est pas un trial, enregistrer le revenu
            if !isTrial {
                updateData["revenue"] = price

                // Mettre à jour les stats de l'affilié
                let affiliateRef = db.collection("affiliateStats").document(affiliateCode)
                try await affiliateRef.setData([
                    "totalRevenue": FieldValue.increment(Int64(price)),
                    "totalConversions": FieldValue.increment(Int64(1)),
                    "lastConversionDate": Timestamp(date: Date())
                ], merge: true)
            }

            try await docRef.updateData(updateData)

            print("✅ [AFFILIATE] Purchase tracked - Type: \(purchaseType.rawValue), Trial: \(isTrial)")

        } catch {
            print("❌ [AFFILIATE] Failed to track purchase: \(error.localizedDescription)")
        }
    }

    /// Tracker la conversion d'un trial vers paid
    func trackTrialConversion(
        userId: String,
        fromTrial: Bool,
        toPurchaseType: PurchaseType,
        price: Double
    ) async {
        guard let affiliateCode = currentAffiliateCode else { return }

        let conversion = AffiliateConversion(
            affiliateCode: affiliateCode,
            userId: userId,
            fromType: .trial,
            toType: toPurchaseType,
            conversionDate: Date(),
            revenue: price
        )

        do {
            // Enregistrer la conversion
            let conversionRef = db.collection("affiliateConversions").document()
            try await conversionRef.setData([
                "affiliateCode": conversion.affiliateCode,
                "userId": conversion.userId,
                "fromType": conversion.fromType.rawValue,
                "toType": conversion.toType.rawValue,
                "conversionDate": Timestamp(date: conversion.conversionDate),
                "revenue": conversion.revenue
            ])

            // Mettre à jour le statut principal
            let userRef = db.collection("affiliates").document(userId)
            try await userRef.updateData([
                "status": AffiliateStatus.converted.rawValue,
                "conversionDate": Timestamp(date: Date()),
                "revenue": price
            ])

            // Stats de l'affilié
            let statsRef = db.collection("affiliateStats").document(affiliateCode)
            try await statsRef.setData([
                "totalRevenue": FieldValue.increment(Int64(price)),
                "totalConversions": FieldValue.increment(Int64(1)),
                "lastConversionDate": Timestamp(date: Date())
            ], merge: true)

            print("✅ [AFFILIATE] Trial conversion tracked - Revenue: \(price)")

        } catch {
            print("❌ [AFFILIATE] Failed to track conversion: \(error.localizedDescription)")
        }
    }

    /// Tracker l'expiration d'un trial sans conversion
    func trackTrialExpired(userId: String) async {
        guard let affiliateCode = currentAffiliateCode else { return }

        do {
            let docRef = db.collection("affiliates").document(userId)
            try await docRef.updateData([
                "status": AffiliateStatus.expired.rawValue,
                "expirationDate": Timestamp(date: Date())
            ])

            // Stats de l'affilié (trial expiré)
            let statsRef = db.collection("affiliateStats").document(affiliateCode)
            try await statsRef.setData([
                "totalExpired": FieldValue.increment(Int64(1))
            ], merge: true)

            print("⏰ [AFFILIATE] Trial expired tracked")

        } catch {
            print("❌ [AFFILIATE] Failed to track expiration: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func hasProcessedAffiliation() -> Bool {
        return userDefaults.bool(forKey: affiliateProcessedKey)
    }

    private func markAffiliationAsProcessed() {
        userDefaults.set(true, forKey: affiliateProcessedKey)
        userDefaults.synchronize()
    }

    /// Clear affiliate data (pour testing)
    func clearAffiliateData() {
        currentAffiliateCode = nil
        affiliateData = nil
        userDefaults.removeObject(forKey: affiliateCodeKey)
        userDefaults.removeObject(forKey: affiliateProcessedKey)
        userDefaults.synchronize()
        print("🗑️ [AFFILIATE] Data cleared")
    }

    private func getDeviceInfo() -> [String: String] {
        return [
            "model": UIDevice.current.model,
            "system": UIDevice.current.systemName,
            "version": UIDevice.current.systemVersion,
            "locale": Locale.current.identifier
        ]
    }

    // MARK: - Testing Helpers

    /// Simuler un deep link (pour testing)
    func simulateAffiliateLink(code: String) {
        let urlString = "zenloop://affiliate?code=\(code)"
        if let url = URL(string: urlString) {
            processDeepLink(url: url)
        }
    }

    /// Debug info
    func printDebugInfo() {
        print("""

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📊 AFFILIATE DEBUG INFO
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Code: \(currentAffiliateCode ?? "None")
        Processed: \(hasProcessedAffiliation())
        Data: \(affiliateData?.affiliateCode ?? "None")
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }
}
