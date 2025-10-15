//
//  AffiliateManager.swift
//  zenloop
//
//  Système d'affiliation avec deep linking et tracking Firebase
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

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
        // Ne PAS vérifier le clipboard automatiquement - évite l'alerte de permission
        // On utilisera uniquement server-side recovery + deep links
        tryServerSideRecoveryIfNeeded()
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

    /// Récupération server-side uniquement (si pas de code)
    private func tryServerSideRecoveryIfNeeded() {
        // Si on a déjà un code, ne rien faire
        guard currentAffiliateCode == nil else {
            print("⏭️ [AFFILIATE] Code already exists, skipping recovery")
            return
        }

        // Vérifier si on a déjà fait une tentative de récupération
        let recoveryAttemptedKey = "zenloop.affiliate.recoveryAttempted"
        guard !userDefaults.bool(forKey: recoveryAttemptedKey) else {
            print("⏭️ [AFFILIATE] Recovery already attempted")
            return
        }

        // Essayer la récupération server-side (Firebase)
        print("🔍 [AFFILIATE] Attempting server-side recovery...")
        Task {
            await tryRecoverFromFirebaseClicks()
        }

        // Marquer comme tenté
        userDefaults.set(true, forKey: recoveryAttemptedKey)
        userDefaults.synchronize()
    }

    /// Récupération via Firebase affiliateClicks (si clipboard échoue)
    private func tryRecoverFromFirebaseClicks() async {
        let deviceModel = UIDevice.current.model // "iPhone", "iPad"
        let systemVersion = UIDevice.current.systemVersion // "17.0"

        do {
            // Chercher les clics des dernières 48h correspondant à ce device
            let twoDaysAgo = Date().addingTimeInterval(-48 * 3600)

            let clicksQuery = db.collection("affiliateClicks")
                .whereField("deviceType", isEqualTo: deviceModel)
                .whereField("iOSVersion", isEqualTo: systemVersion)
                .whereField("claimed", isEqualTo: false)
                .whereField("timestamp", isGreaterThan: Timestamp(date: twoDaysAgo))
                .order(by: "timestamp", descending: true)
                .limit(to: 5)

            let snapshot = try await clicksQuery.getDocuments()

            if let mostRecentClick = snapshot.documents.first {
                let data = mostRecentClick.data()

                if let affiliateCode = data["affiliateCode"] as? String {
                    print("🎯 [AFFILIATE] Server-side recovery found code: \(affiliateCode)")

                    // Sauvegarder le code
                    saveAffiliateCode(affiliateCode)

                    // Marquer ce clic comme "claimed"
                    try await mostRecentClick.reference.updateData([
                        "claimed": true,
                        "claimedAt": Timestamp(date: Date())
                    ])

                    print("✅ [AFFILIATE] Code recovered from server!")
                }
            } else {
                print("⚠️ [AFFILIATE] No matching clicks found in last 48h")
            }

        } catch {
            print("❌ [AFFILIATE] Firebase recovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Firebase Integration

    /// Enregistrer l'affiliation dans Firebase lors de l'inscription
    func registerAffiliation(userId: String) async {
        guard let affiliateCode = currentAffiliateCode else {
            print("⚠️ [AFFILIATE] No affiliate code")
            return
        }

        // Utiliser IDFV comme device fingerprint unique
        let deviceFingerprint = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        // Vérifier si ce device a déjà été enregistré pour éviter les doublons
        do {
            let existingQuery = db.collection("affiliates")
                .whereField("deviceFingerprint", isEqualTo: deviceFingerprint)
                .limit(to: 1)

            let existingDocs = try await existingQuery.getDocuments()

            if !existingDocs.isEmpty {
                print("⚠️ [AFFILIATE] Device already registered, skipping duplicate")
                return
            }
        } catch {
            print("⚠️ [AFFILIATE] Error checking existing device: \(error.localizedDescription)")
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
            // Enregistrer dans Firebase avec device fingerprint
            let docRef = db.collection("affiliates").document(userId)
            try await docRef.setData([
                "affiliateCode": affiliateData.affiliateCode,
                "userId": affiliateData.userId,
                "timestamp": Timestamp(date: affiliateData.timestamp),
                "status": affiliateData.status.rawValue,
                "deviceInfo": affiliateData.deviceInfo,
                "deviceFingerprint": deviceFingerprint,
                "source": "app" // Provenance de l'affiliation
            ])

            // Récupérer les infos de l'affilié pour mise à jour
            let affiliateStatsQuery = db.collection("affiliateStats")
                .whereField("affiliateCode", isEqualTo: affiliateCode)
                .limit(to: 1)

            let affiliateSnapshot = try await affiliateStatsQuery.getDocuments()

            if let affiliateDoc = affiliateSnapshot.documents.first {
                // Mettre à jour le document existant avec le bon ID
                try await affiliateDoc.reference.setData([
                    "affiliateCode": affiliateCode,
                    "totalSignups": FieldValue.increment(Int64(1)),
                    "lastSignupDate": Timestamp(date: Date())
                ], merge: true)

                print("✅ [AFFILIATE] Updated existing affiliate stats")
            } else {
                print("⚠️ [AFFILIATE] Affiliate code not found in affiliateStats: \(affiliateCode)")
            }

            // Marquer comme traité
            markAffiliationAsProcessed()
            self.affiliateData = affiliateData

            // Marquer le clic affilié comme récupéré (si existe)
            await markAffiliateClickAsClaimed(affiliateCode: affiliateCode, userId: userId, deviceFingerprint: deviceFingerprint)

            print("✅ [AFFILIATE] Registration saved to Firebase")

        } catch {
            print("❌ [AFFILIATE] Failed to save: \(error.localizedDescription)")
        }
    }

    /// Marquer un clic affilié comme récupéré par un userId
    private func markAffiliateClickAsClaimed(affiliateCode: String, userId: String, deviceFingerprint: String) async {
        do {
            // Chercher les clics non réclamés avec ce code
            let clicksQuery = db.collection("affiliateClicks")
                .whereField("affiliateCode", isEqualTo: affiliateCode)
                .whereField("claimed", isEqualTo: false)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)

            let snapshot = try await clicksQuery.getDocuments()

            if let clickDoc = snapshot.documents.first {
                try await clickDoc.reference.updateData([
                    "claimed": true,
                    "claimedAt": Timestamp(date: Date()),
                    "claimedByUserId": userId,
                    "deviceFingerprint": deviceFingerprint
                ])

                print("✅ [AFFILIATE] Click marked as claimed")
            }
        } catch {
            print("⚠️ [AFFILIATE] Could not mark click as claimed: \(error.localizedDescription)")
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

        // Calculer la commission (30% pour trial converti, 40% pour achat direct)
        let commissionRate = isTrial ? 0.30 : 0.40
        let commission = price * commissionRate

        // Device fingerprint pour éviter les doublons
        let deviceFingerprint = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        do {
            let docRef = db.collection("affiliates").document(userId)

            var affiliateData: [String: Any] = [
                "affiliateCode": affiliateCode,
                "userId": userId,
                "purchaseType": purchaseType.rawValue,
                "purchaseDate": Timestamp(date: Date()),
                "status": status.rawValue,
                "isTrial": isTrial,
                "purchaseAmount": price,
                "timestamp": Timestamp(date: Date()),
                "deviceInfo": getDeviceInfo(),
                "deviceFingerprint": deviceFingerprint
            ]

            if let trialEnd = trialEndDate {
                affiliateData["trialEndDate"] = Timestamp(date: trialEnd)
            }

            // Créer TOUJOURS un document de conversion (trial ou payant)
            let conversionRef = db.collection("affiliateConversions").document()
            try await conversionRef.setData([
                "affiliateCode": affiliateCode,
                "userId": userId,
                "purchaseType": purchaseType.rawValue,
                "purchaseAmount": price,
                "commission": commission,
                "status": status.rawValue,  // "pending" pour trial, "active" pour payant
                "isTrial": isTrial,
                "convertedAt": Timestamp(date: Date()),
                "trialEndDate": trialEndDate != nil ? Timestamp(date: trialEndDate!) : nil
            ])

            // Récupérer le document affiliateStats via query
            let affiliateStatsQuery = db.collection("affiliateStats")
                .whereField("affiliateCode", isEqualTo: affiliateCode)
                .limit(to: 1)

            let affiliateSnapshot = try await affiliateStatsQuery.getDocuments()

            if let affiliateDoc = affiliateSnapshot.documents.first {
                if !isTrial {
                    // Achat payant : incrémenter revenue et conversions
                    affiliateData["revenue"] = commission

                    try await affiliateDoc.reference.setData([
                        "totalRevenue": FieldValue.increment(Double(commission)),
                        "totalConversions": FieldValue.increment(Int64(1)),
                        "lastConversionDate": Timestamp(date: Date())
                    ], merge: true)

                    print("✅ [AFFILIATE] Updated affiliate stats with commission: \(commission)")
                } else {
                    // Trial : incrémenter pending seulement
                    try await affiliateDoc.reference.setData([
                        "totalPending": FieldValue.increment(Int64(1)),
                        "lastPendingDate": Timestamp(date: Date())
                    ], merge: true)

                    print("⏳ [AFFILIATE] Trial tracked as pending (no commission yet)")
                }
            }

            // Vérifier si c'est un nouveau signup avant de créer le document
            let docSnapshot = try await docRef.getDocument()
            let isNewSignup = !docSnapshot.exists

            // Utiliser setData avec merge au lieu de updateData pour créer le doc s'il n'existe pas
            try await docRef.setData(affiliateData, merge: true)

            // Incrémenter totalSignups si c'est la première fois
            if isNewSignup, let affiliateDoc = affiliateSnapshot.documents.first {
                try await affiliateDoc.reference.setData([
                    "totalSignups": FieldValue.increment(Int64(1)),
                    "lastSignupDate": Timestamp(date: Date())
                ], merge: true)
            }

            print("✅ [AFFILIATE] Purchase tracked - Type: \(purchaseType.rawValue), Trial: \(isTrial), Commission: \(commission)")

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

        // Commission de 30% pour les conversions trial
        let commission = price * 0.30

        let conversion = AffiliateConversion(
            affiliateCode: affiliateCode,
            userId: userId,
            fromType: .trial,
            toType: toPurchaseType,
            conversionDate: Date(),
            revenue: commission
        )

        do {
            // Enregistrer la conversion avec tous les détails
            let conversionRef = db.collection("affiliateConversions").document()
            try await conversionRef.setData([
                "affiliateCode": conversion.affiliateCode,
                "userId": conversion.userId,
                "fromType": conversion.fromType.rawValue,
                "toType": conversion.toType.rawValue,
                "purchaseType": toPurchaseType.rawValue,
                "purchaseAmount": price,
                "commission": commission,
                "status": AffiliateStatus.converted.rawValue,
                "convertedAt": Timestamp(date: conversion.conversionDate)
            ])

            // Mettre à jour le statut principal
            let userRef = db.collection("affiliates").document(userId)
            try await userRef.updateData([
                "status": AffiliateStatus.converted.rawValue,
                "conversionDate": Timestamp(date: Date()),
                "revenue": commission,
                "purchaseAmount": price
            ])

            // Récupérer le document affiliateStats via query
            let affiliateStatsQuery = db.collection("affiliateStats")
                .whereField("affiliateCode", isEqualTo: affiliateCode)
                .limit(to: 1)

            let affiliateSnapshot = try await affiliateStatsQuery.getDocuments()

            if let affiliateDoc = affiliateSnapshot.documents.first {
                try await affiliateDoc.reference.setData([
                    "totalRevenue": FieldValue.increment(Double(commission)),
                    "totalConversions": FieldValue.increment(Int64(1)),
                    "totalPending": FieldValue.increment(Int64(-1)),  // Décrémenter pending
                    "lastConversionDate": Timestamp(date: Date())
                ], merge: true)

                print("✅ [AFFILIATE] Updated affiliate stats with commission: \(commission)")
            }

            // Mettre à jour le document de conversion initial (passer de pending à converted)
            let pendingQuery = db.collection("affiliateConversions")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)

            let pendingSnapshot = try await pendingQuery.getDocuments()
            if let pendingDoc = pendingSnapshot.documents.first {
                try await pendingDoc.reference.updateData([
                    "status": AffiliateStatus.converted.rawValue,
                    "commission": commission,
                    "purchaseAmount": price,
                    "purchaseType": toPurchaseType.rawValue
                ])
                print("✅ [AFFILIATE] Updated pending conversion to converted")
            }

            print("✅ [AFFILIATE] Trial conversion tracked - Price: \(price), Commission: \(commission)")

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

            // Récupérer le document affiliateStats via query
            let affiliateStatsQuery = db.collection("affiliateStats")
                .whereField("affiliateCode", isEqualTo: affiliateCode)
                .limit(to: 1)

            let affiliateSnapshot = try await affiliateStatsQuery.getDocuments()

            if let affiliateDoc = affiliateSnapshot.documents.first {
                try await affiliateDoc.reference.setData([
                    "totalExpired": FieldValue.increment(Int64(1)),
                    "totalPending": FieldValue.increment(Int64(-1))  // Décrémenter pending
                ], merge: true)
            }

            // Mettre à jour le document de conversion (passer de pending à expired)
            let pendingQuery = db.collection("affiliateConversions")
                .whereField("userId", isEqualTo: userId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)

            let pendingSnapshot = try await pendingQuery.getDocuments()
            if let pendingDoc = pendingSnapshot.documents.first {
                try await pendingDoc.reference.updateData([
                    "status": AffiliateStatus.expired.rawValue
                ])
                print("✅ [AFFILIATE] Updated pending conversion to expired")
            }

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
