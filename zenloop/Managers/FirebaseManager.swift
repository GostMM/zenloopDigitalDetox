//
//  FirebaseManager.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import Foundation
import Firebase
import FirebaseFirestore
import UIKit

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private let deviceId: String
    
    private init() {
        // Générer un ID device unique et persistant
        if let savedDeviceId = UserDefaults.standard.string(forKey: "zenloop_device_id") {
            self.deviceId = savedDeviceId
        } else {
            self.deviceId = UUID().uuidString
            UserDefaults.standard.set(self.deviceId, forKey: "zenloop_device_id")
        }
    }
    
    // MARK: - Device Registration
    
    func registerDeviceOnFirstLaunch() async {
        let hasRegistered = UserDefaults.standard.bool(forKey: "zenloop_device_registered")
        
        if !hasRegistered {
            await registerDevice()
            UserDefaults.standard.set(true, forKey: "zenloop_device_registered")
            print("✅ [FIREBASE] Device registered on first launch")
        } else {
            print("ℹ️ [FIREBASE] Device already registered")
        }
    }
    
    private func registerDevice() async {
        let deviceData: [String: Any] = [
            "deviceId": deviceId,
            "firstLaunch": Timestamp(date: Date()),
            "lastSeen": Timestamp(date: Date()),
            "deviceModel": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        ]
        
        do {
            try await db.collection("devices").document(deviceId).setData(deviceData)
            print("✅ [FIREBASE] Device data saved: \(deviceId)")
        } catch {
            print("❌ [FIREBASE] Error saving device data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Paywall Tracking
    
    func trackPaywallAction(action: PaywallAction, productId: String? = nil, price: String? = nil) async {
        print("🔥 [FIREBASE] Attempting to track paywall action: \(action.rawValue)")
        print("🔥 [FIREBASE] DeviceId: \(deviceId)")
        
        // Test simple d'abord : essayer d'écrire dans la collection devices (qui fonctionne)
        do {
            let testData: [String: Any] = [
                "test": "paywall_tracking_test",
                "timestamp": Timestamp(date: Date()),
                "deviceId": deviceId
            ]
            
            let testRef = try await db.collection("devices").document(deviceId).collection("test_events").addDocument(data: testData)
            print("✅ [FIREBASE] Test write to devices collection successful: \(testRef.documentID)")
        } catch {
            print("❌ [FIREBASE] Test write to devices collection failed: \(error)")
        }
        
        let actionData: [String: Any] = [
            "deviceId": deviceId,
            "action": action.rawValue,
            "timestamp": Timestamp(date: Date()),
            "productId": productId ?? "",
            "price": price ?? "",
            "context": "paywall"
        ]
        
        print("🔥 [FIREBASE] Action data: \(actionData)")
        
        do {
            let docRef = try await db.collection("paywall_events").addDocument(data: actionData)
            print("✅ [FIREBASE] Paywall action tracked successfully: \(action.rawValue)")
            print("✅ [FIREBASE] Document ID: \(docRef.documentID)")
            
            // Vérifier que le document existe vraiment
            let snapshot = try await docRef.getDocument()
            if snapshot.exists {
                print("✅ [FIREBASE] Document verified in Firestore")
                print("✅ [FIREBASE] Document data: \(snapshot.data() ?? [:])")
            } else {
                print("⚠️ [FIREBASE] Document not found after creation")
            }
            
        } catch {
            print("❌ [FIREBASE] Error tracking paywall action: \(error)")
            print("❌ [FIREBASE] Error details: \(error.localizedDescription)")
            
            // Essayer d'écrire dans une sous-collection de devices à la place
            do {
                let fallbackRef = try await db.collection("devices").document(deviceId).collection("paywall_events").addDocument(data: actionData)
                print("✅ [FIREBASE] Fallback write successful: \(fallbackRef.documentID)")
            } catch {
                print("❌ [FIREBASE] Fallback write also failed: \(error)")
            }
        }
    }
    
    // MARK: - Subscription Tracking
    
    func trackSubscriptionPurchase(productId: String, price: String, currency: String = "EUR") async {
        let subscriptionData: [String: Any] = [
            "deviceId": deviceId,
            "productId": productId,
            "price": price,
            "currency": currency,
            "purchaseDate": Timestamp(date: Date()),
            "status": "purchased"
        ]
        
        do {
            try await db.collection("subscriptions").addDocument(data: subscriptionData)
            print("✅ [FIREBASE] Subscription purchase tracked: \(productId) - \(price)\(currency)")
        } catch {
            print("❌ [FIREBASE] Error tracking subscription: \(error.localizedDescription)")
        }
    }
    
    func trackSubscriptionEvent(event: SubscriptionEvent, productId: String) async {
        let eventData: [String: Any] = [
            "deviceId": deviceId,
            "event": event.rawValue,
            "productId": productId,
            "timestamp": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("subscription_events").addDocument(data: eventData)
            print("✅ [FIREBASE] Subscription event tracked: \(event.rawValue)")
        } catch {
            print("❌ [FIREBASE] Error tracking subscription event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Device Activity
    
    func updateLastSeen() async {
        do {
            try await db.collection("devices").document(deviceId).updateData([
                "lastSeen": Timestamp(date: Date())
            ])
        } catch {
            print("❌ [FIREBASE] Error updating last seen: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Enums

enum PaywallAction: String, CaseIterable {
    case viewed = "viewed"
    case dismissed = "dismissed"
    case purchaseAttempted = "purchase_attempted"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case purchaseCanceled = "purchase_canceled"
    case restorePurchases = "restore_purchases"
}

enum SubscriptionEvent: String, CaseIterable {
    case subscribed = "subscribed"
    case renewed = "renewed"
    case expired = "expired"
    case canceled = "canceled"
    case upgraded = "upgraded"
    case downgraded = "downgraded"
    case refunded = "refunded"
}