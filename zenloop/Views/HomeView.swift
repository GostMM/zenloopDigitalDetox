//
//  HomeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import UIKit
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    private var badgeManager: BadgeManager { BadgeManager.shared }
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var globalShieldManager = GlobalShieldManager.shared
    @State private var showContent = false
    @State private var syncTimer: Timer?

    // MARK: - Computed Properties

    private var isIdle: Bool {
        zenloopManager.currentState == .idle
    }

    private var hasNoActiveSession: Bool {
        sessionManager.currentSession == nil
    }

    private var hasPersistentBlocks: Bool {
        globalShieldManager.hasActiveBlocks()
    }

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: zenloopManager.currentState)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                MinimalHeader(
                    showContent: showContent,
                    currentState: zenloopManager.currentState,
                    zenloopManager: zenloopManager
                )
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if isIdle {
                            TimerCard(zenloopManager: zenloopManager, showContent: showContent)
                                .padding(.top, 20)

                            if hasNoActiveSession && hasPersistentBlocks {
                                PersistentBlocksAlert(onClearBlocks: {
                                    globalShieldManager.clearAllBlocks()
                                })
                                .padding(.horizontal, 20)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                            }

                            UpcomingSessionsCard(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                            SessionPlanningRow(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                            QuickBlockModesSection(showContent: showContent)
                        }

                        if !isIdle {
                            activeSections
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            QuickBlockModesSection(showContent: showContent)
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                showContent = true
            }
            badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
            Task {
                await synchronizeBackgroundSessions()
            }
            startPeriodicSync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                TopAppsDisplayManager.shared.checkIfShouldShow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await synchronizeBackgroundSessions()
            }
        }
        .onDisappear {
            stopPeriodicSync()
        }
        .onChange(of: zenloopManager.currentState) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
            }
            if newValue == .active || newValue == .completed {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }

    // MARK: - View Sections

    @ViewBuilder
    private var activeSections: some View {
        ActiveChallengeSection(
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        .padding(.top, 30)
    }

    // MARK: - Background Session Synchronization

    @MainActor
    private func synchronizeBackgroundSessions() async {
        zenloopManager.updateScheduledSessionsStatus()
        await checkAndRestoreActiveSession()
        zenloopManager.cleanupExpiredSessions()
        checkExtensionEvents()
    }

    @MainActor
    private func checkAndRestoreActiveSession() async {
        if zenloopManager.currentState == .idle,
           let challenge = zenloopManager.currentChallenge,
           challenge.isActive && !isExpired(challenge) {
            zenloopManager.currentState = .active
            zenloopManager.currentTimeRemaining = challenge.timeRemaining
            zenloopManager.currentProgress = challenge.safeProgress
        }
    }

    // MARK: - Extension Events Processing

    private func checkExtensionEvents() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        if let events = suite.array(forKey: "device_activity_events") as? [[String: Any]], !events.isEmpty {
            for event in events {
                if let eventType = event["event"] as? String,
                   let activity = event["activity"] as? String {
                    processExtensionEvent(type: eventType, activity: activity)
                }
            }
            suite.removeObject(forKey: "device_activity_events")
            suite.synchronize()
        }
    }

    private func processExtensionEvent(type: String, activity: String) {
        switch type {
        case "intervalDidStart", "intervalDidEnd":
            Task { @MainActor in
                await synchronizeBackgroundSessions()
            }
        default:
            break
        }
    }

    // MARK: - Helper Methods

    private func isExpired(_ challenge: ZenloopChallenge) -> Bool {
        guard let startTime = challenge.startTime else { return false }
        return Date() > startTime.addingTimeInterval(challenge.duration)
    }

    // MARK: - Periodic Sync Management

    private func startPeriodicSync() {
        stopPeriodicSync()
        var tickCount = 0
        syncTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            Task { @MainActor in
                guard UIApplication.shared.applicationState == .active else { return }
                tickCount += 1
                checkExtensionEvents()
                if tickCount % 4 == 0 { // toutes les ~32s
                    await synchronizeBackgroundSessions()
                }
            }
        }
    }

    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
}

// MARK: - Persistent Blocks Alert Card

struct PersistentBlocksAlert: View {
    let onClearBlocks: () -> Void
    @State private var isClearing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "restrictions_persistantes"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(localized: "aucune_session_active"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }

            Button {
                isClearing = true
                onClearBlocks()
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isClearing = false
                }
            } label: {
                HStack {
                    if isClearing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(String(localized: "lever_toutes_restrictions"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(isClearing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(ZenloopManager.shared)
}
