//
//  UnblockAppSheet.swift
//  zenloopactivity
//
//  Sheet pour débloquer une app depuis l'extension
//

import SwiftUI
import FamilyControls
import ManagedSettings
import os

private let unblockLogger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "UnblockSheet")

struct UnblockAppSheet: View {
    let block: ActiveBlock
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var isUnblocking = false
    var onUnblocked: (() -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    // Icône et nom de l'app
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.red)
                        }

                        Text(block.appName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        VStack(spacing: 8) {
                            Text("Cette app est bloquée")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Text("Temps restant: \(block.formattedRemainingTime)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red.opacity(0.9))
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 40)

                    Spacer()

                    // Boutons d'action
                    VStack(spacing: 16) {
                        // Bouton Unblock
                        Button {
                            unblockApp()
                        } label: {
                            HStack(spacing: 12) {
                                if isUnblocking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 18, weight: .bold))

                                    Text("Débloquer maintenant")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.8),
                                        Color.red.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isUnblocking)

                        // Bouton Cancel
                        Button {
                            dismiss()
                        } label: {
                            Text("Garder bloqué")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func unblockApp() {
        guard !isUnblocking else {
            unblockLogger.critical("⚠️ [UNBLOCK] Already unblocking, ignoring duplicate call")
            return
        }
        isUnblocking = true

        #if os(iOS)
        unblockLogger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        unblockLogger.critical("🔓 [UNBLOCK] ========== STARTING UNBLOCK ==========")
        unblockLogger.critical("🔓 [UNBLOCK] App Name: \(block.appName)")
        unblockLogger.critical("🔓 [UNBLOCK] BlockID: \(block.id)")
        unblockLogger.critical("🔓 [UNBLOCK] StoreName: \(block.storeName)")
        unblockLogger.critical("🔓 [UNBLOCK] Status: \(block.status.rawValue)")
        unblockLogger.critical("🔓 [UNBLOCK] Remaining: \(block.formattedRemainingTime)")

        // 1. Vérifier le tokenData
        unblockLogger.critical("🔍 [UNBLOCK] Step 1: Checking tokenData...")
        unblockLogger.critical("   → TokenData size: \(block.appTokenData.count) bytes")

        if block.appTokenData.isEmpty {
            unblockLogger.error("❌ [UNBLOCK] ERROR: TokenData is EMPTY!")
            unblockLogger.critical("   → Cannot unblock without token data")
            isUnblocking = false
            return
        }

        // 1. Encoder le tokenData en base64 pour le passer via URL
        unblockLogger.critical("🔍 [UNBLOCK] Step 2: Encoding token to base64...")
        let tokenBase64 = block.appTokenData.base64EncodedString()
        unblockLogger.critical("   → Base64 length: \(tokenBase64.count) characters")
        unblockLogger.critical("   → Base64 preview: \(tokenBase64.prefix(50))...")

        // 2. Créer l'URL scheme pour débloquer via l'app principale
        unblockLogger.critical("🔍 [UNBLOCK] Step 3: Creating URL components...")
        var urlComponents = URLComponents(string: "zenloop://unblock")!
        urlComponents.queryItems = [
            URLQueryItem(name: "blockId", value: block.id),
            URLQueryItem(name: "appName", value: block.appName),
            URLQueryItem(name: "tokenData", value: tokenBase64)
        ]

        unblockLogger.critical("   → Query items count: \(urlComponents.queryItems?.count ?? 0)")
        unblockLogger.critical("   → blockId: \(block.id)")
        unblockLogger.critical("   → appName: \(block.appName)")
        unblockLogger.critical("   → tokenData: \(tokenBase64.count) chars")

        guard let url = urlComponents.url else {
            unblockLogger.error("❌ [UNBLOCK] ERROR: Failed to create URL!")
            unblockLogger.error("   → URLComponents string: \(urlComponents.string ?? "nil")")
            isUnblocking = false
            return
        }

        unblockLogger.critical("🔍 [UNBLOCK] Step 4: URL created successfully!")
        unblockLogger.critical("   → Full URL: \(url.absoluteString)")
        unblockLogger.critical("   → Scheme: \(url.scheme ?? "nil")")
        unblockLogger.critical("   → Host: \(url.host ?? "nil")")
        unblockLogger.critical("   → Query: \(url.query?.prefix(100) ?? "nil")...")

        // 3. Ouvrir l'app principale pour traiter le déblocage
        unblockLogger.critical("🔍 [UNBLOCK] Step 5: Opening main app with openURL...")
        unblockLogger.critical("   → Calling openURL now...")

        openURL(url) { accepted in
            unblockLogger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if accepted {
                unblockLogger.critical("✅✅✅ [UNBLOCK] MAIN APP ACCEPTED UNBLOCK REQUEST!")
                unblockLogger.critical("   → App should process unblock now")
            } else {
                unblockLogger.error("❌❌❌ [UNBLOCK] MAIN APP REJECTED UNBLOCK REQUEST!")
                unblockLogger.error("   → URL might be invalid or app not responding")
            }
            unblockLogger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        // 4. Essayer aussi le déblocage direct local (fallback)
        unblockLogger.critical("🔍 [UNBLOCK] Step 6: Attempting local shield removal as fallback...")
        let store = ManagedSettingsStore(named: .init(block.storeName))

        unblockLogger.critical("   → Store name: \(block.storeName)")
        unblockLogger.critical("   → Clearing store.shield.applications...")
        store.shield.applications = nil

        unblockLogger.critical("   → Clearing store.shield.applicationCategories...")
        store.shield.applicationCategories = nil

        unblockLogger.critical("   → Calling clearAllSettings()...")
        store.clearAllSettings()

        unblockLogger.critical("✅ [UNBLOCK] Local shield removal attempted")

        // 5. Marquer comme stoppé dans le storage local (pour la cohérence)
        unblockLogger.critical("🔍 [UNBLOCK] Step 7: Updating block status in BlockManager...")
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: block.id, status: .stopped)
        unblockLogger.critical("✅ [UNBLOCK] Block status updated to .stopped")

        // 6. Supprimer le block complètement
        unblockLogger.critical("🔍 [UNBLOCK] Step 8: Removing block from BlockManager...")
        blockManager.removeBlock(id: block.id)
        unblockLogger.critical("✅ [UNBLOCK] Block removed from storage")

        unblockLogger.critical("🔓 [UNBLOCK] ========== UNBLOCK COMPLETE ==========")
        unblockLogger.critical("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif

        // Feedback visuel + fermeture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isUnblocking = false
            self.onUnblocked?()
            self.dismiss()
        }
    }
}