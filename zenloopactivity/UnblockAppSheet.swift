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
        guard !isUnblocking else { return }
        isUnblocking = true

        #if os(iOS)
        unblockLogger.critical("🔓 [UNBLOCK] Unblocking app: \(block.appName)")

        // 1. Marquer comme stoppé dans le storage local
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: block.id, status: .stopped)

        // 2. IMPORTANT: Envoyer une commande à l'app principale pour nettoyer le ManagedSettingsStore
        let command = BlockCommand.stopBlock(id: block.id)
        blockManager.sendCommand(command)

        unblockLogger.critical("📤 [UNBLOCK] Command sent to main app for unblocking")

        // 3. Nettoyer les blocks stoppés localement
        blockManager.removeExpiredAndStoppedBlocks()

        unblockLogger.critical("✅ [UNBLOCK] Block removed from storage: \(block.appName)")
        #endif

        // Feedback visuel + fermeture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isUnblocking = false
            self.onUnblocked?()
            self.dismiss()
        }
    }
}