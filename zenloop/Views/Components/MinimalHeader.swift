//
//  MinimalHeader.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct MinimalHeader: View {
    let showContent: Bool
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var subscriptionStatus: SubscriptionStatus = .none
    @State private var showSubscriptionStatus = false
    @State private var activeBlocksCount: Int = 0
    @State private var showActiveBlocks = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentGreeting)
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
            }

            Spacer(minLength: 4)

            if activeBlocksCount > 0 {
                Button {
                    showActiveBlocks = true
                } label: {
                    ZStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                                    )
                            )

                        Text("\(activeBlocksCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.red))
                            .offset(x: 10, y: -10)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)
            }

            if purchaseManager.isPremium {
                ProBadge()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -10)
            } else {
                SubscriptionStatusIndicator(
                    status: subscriptionStatus,
                    showContent: showContent
                ) {
                    showSubscriptionStatus = true
                }
            }

            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(currentState == .active ? 1.3 : 1.0)
                .animation(
                    currentState == .active ?
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .easeOut(duration: 0.3),
                    value: currentState
                )
                .opacity(showContent ? 1 : 0)
        }
        .frame(height: 44)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
        .sheet(isPresented: $showSubscriptionStatus) {
            SubscriptionStatusView()
        }
        .sheet(isPresented: $showActiveBlocks) {
            BlockControllerView()
        }
        .task {
            await updateSubscriptionStatus()
            updateActiveBlocksCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateActiveBlocksCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActiveBlocksDidChange"))) { _ in
            updateActiveBlocksCount()
        }
    }

    private var currentGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "greeting_morning")
        case 12..<17: return String(localized: "greeting_afternoon")
        case 17..<21: return String(localized: "greeting_evening")
        default: return String(localized: "greeting_night")
        }
    }

    private var statusText: String {
        switch currentState {
        case .idle: return String(localized: "status_ready_new_challenge")
        case .active: return String(localized: "status_focus_in_progress")
        case .paused: return String(localized: "status_active_pause")
        case .completed: return String(localized: "status_mission_accomplished")
        }
    }

    private var stateColor: Color {
        switch currentState {
        case .idle: return .cyan
        case .active: return .orange
        case .paused: return .mint
        case .completed: return .purple
        }
    }

    private func updateSubscriptionStatus() async {
        subscriptionStatus = await purchaseManager.getSubscriptionStatus()
    }

    private func updateActiveBlocksCount() {
        let blockManager = BlockManager()
        activeBlocksCount = blockManager.getActiveBlocks().count
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

struct SubscriptionStatusIndicator: View {
    let status: SubscriptionStatus
    let showContent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                statusIcon
                    .font(.system(size: 10, weight: .bold))

                if shouldShowText {
                    Text(statusText)
                        .font(.system(size: 8, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(status.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(status.color.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -10)
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .expiringSoon:
                Image(systemName: "exclamationmark.triangle.fill")
            case .expired:
                Image(systemName: "xmark.circle.fill")
            case .refunded:
                Image(systemName: "arrow.uturn.backward.circle.fill")
            default:
                Image(systemName: "crown")
            }
        }
    }

    private var statusText: String {
        switch status {
        case .expiringSoon: return String(localized: "expires_short")
        case .expired: return String(localized: "expired_short")
        case .refunded: return String(localized: "refunded_short")
        case .none: return String(localized: "premium_short")
        default: return ""
        }
    }

    private var shouldShowText: Bool {
        switch status {
        case .expiringSoon, .expired, .refunded, .none:
            return true
        default:
            return false
        }
    }
}
