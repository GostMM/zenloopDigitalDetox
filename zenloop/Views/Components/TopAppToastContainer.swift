//
//  TopAppToastContainer.swift
//  zenloop
//
//  Container pour afficher le toast DeviceActivityReport avec vraies données
//

import SwiftUI
import DeviceActivity
import FamilyControls

// MARK: - Context Extension

extension DeviceActivityReport.Context {
    static let topAppToast = Self("TopAppToast")
}

struct TopAppToastContainer: View {
    @StateObject private var authCenter = ScreenTimeAuthManager.shared
    @Binding var isShowing: Bool

    private let filter: DeviceActivityFilter = {
        let calendar = Calendar.current
        // Période : AUJOURD'HUI uniquement (de 00h00 à maintenant)
        let todayStart = calendar.startOfDay(for: Date())
        let now = Date()

        let interval = DateInterval(start: todayStart, end: now)
        print("📅 [TOAST_CONTAINER] Filtre créé: \(todayStart) -> \(now)")

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }()

    var body: some View {
        DeviceActivityReport(.topAppToast, filter: filter)
            .frame(maxWidth: .infinity)  // Toute la largeur
            .padding(.top, 0)  // Safe area
            .onAppear {
                print("🎯 [TOAST_CONTAINER] DeviceActivityReport affiché (TOP)")
                print("🎯 [TOAST_CONTAINER] isShowing: \(isShowing)")
                print("🎯 [TOAST_CONTAINER] Autorisé: \(authCenter.isAuthorized)")
            }
            .onDisappear {
                print("🎯 [TOAST_CONTAINER] DeviceActivityReport masqué")
            }
    }
}

// MARK: - Screen Time Auth Manager

@MainActor
class ScreenTimeAuthManager: ObservableObject {
    static let shared = ScreenTimeAuthManager()

    @Published var isAuthorized = false

    private let authCenter = AuthorizationCenter.shared

    private init() {
        checkAuthorization()
    }

    func checkAuthorization() {
        switch authCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
            print("✅ [AUTH] Screen Time autorisé")
        case .denied, .notDetermined:
            isAuthorized = false
            print("⚠️ [AUTH] Screen Time NON autorisé")
        @unknown default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = true
            print("✅ [AUTH] Autorisation accordée")
        } catch {
            isAuthorized = false
            print("❌ [AUTH] Autorisation refusée: \(error)")
        }
    }
}
