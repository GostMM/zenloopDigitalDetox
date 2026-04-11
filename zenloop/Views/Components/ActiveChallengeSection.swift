//  ActiveChallengeSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//  Redesign v3: Ultra-compact, dark luxury, circular timer, pill controls
//  07/04/2026

import SwiftUI
import FamilyControls

// MARK: - Active Challenge Section

struct ActiveChallengeSection: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var showBreathingView = false
    @State private var shouldStopSession = false
    @State private var ringPulse = false

    var body: some View {
        VStack(spacing: 0) {
            if let challenge = zenloopManager.currentChallenge {

                // ━━ HERO: Ring Timer + Controls ━━
                ringTimerWithControls

                // ━━ INFO STRIP: Progress + Stats ━━
                infoStrip(challenge: challenge)

                // ━━ BLOCKED APPS (if any) ━━
                if challenge.blockedAppsCount > 0 || isScheduledSession(challenge) {
                    blockedAppsRow(challenge: challenge)
                        .padding(.top, 10)
                }

                // ━━ GOALS (compact chips) ━━
                if !challenge.taskGoals.isEmpty {
                    goalsChips(challenge: challenge)
                        .padding(.top, 10)
                }

                // ━━ ATTEMPTS BADGE ━━
                if challenge.appOpenAttempts > 0 {
                    attemptsBadge(challenge: challenge)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 24)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.85).delay(0.15),
            value: showContent
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                ringPulse = true
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, zenloopManager.currentState == .active {
                zenloopManager.startStateMonitoring()
                zenloopManager.challengeStateManager.checkAndCompleteExpiredSession()
            }
        }
        .fullScreenCover(isPresented: $showBreathingView, onDismiss: {
            if shouldStopSession && zenloopManager.currentState != .idle {
                zenloopManager.stopCurrentChallenge()
            }
            shouldStopSession = false
        }) {
            BreathingMeditationView(
                zenloopManager: zenloopManager,
                onStopRequested: { shouldStopSession = true }
            )
        }
    }

    // MARK: - Ring Timer + Inline Controls

    private var ringTimerWithControls: some View {
        VStack(spacing: 14) {

            // ── Circular Ring ──
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 180, height: 180)

                // Progress ring
                Circle()
                    .trim(from: 0, to: zenloopManager.currentProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.3),
                                accentColor,
                                accentColor.opacity(0.8)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: zenloopManager.currentProgress)

                // Glow dot at tip
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: accentColor.opacity(0.8), radius: 8)
                    .offset(y: -90)
                    .rotationEffect(.degrees(360 * zenloopManager.currentProgress))
                    .animation(.easeInOut(duration: 0.8), value: zenloopManager.currentProgress)

                // Inner content
                VStack(spacing: 4) {
                    if zenloopManager.currentState == .paused {
                        // Pause badge
                        Text("PAUSE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundColor(.mint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.mint.opacity(0.15)))

                        // Pause countdown
                        Text(zenloopManager.pauseTimeRemaining)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.mint.opacity(0.9))

                        // Frozen main time
                        Text(zenloopManager.currentTimeRemaining)
                            .font(.system(size: 38, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                    } else {
                        // Percentage small
                        Text("\(Int(zenloopManager.currentProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.6))

                        // Main time
                        Text(zenloopManager.currentTimeRemaining)
                            .font(.system(size: 42, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: accentColor.opacity(ringPulse ? 0.3 : 0.0), radius: 20)
                    }
                }
            }

            // ── Pill Control Bar: [ Pause/Resume | Stop ] ──
            HStack(spacing: 0) {
                // Pause / Resume
                Button(action: {
                    if zenloopManager.currentState == .paused {
                        zenloopManager.resumeChallenge()
                    } else {
                        zenloopManager.requestPause()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: zenloopManager.currentState == .paused
                              ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text(zenloopManager.currentState == .paused ? "Resume" : "Pause")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(pauseResumeColor.opacity(0.2))
                }

                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 24)

                // Stop
                Button(action: { showBreathingView = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Stop")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.08))
                }
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Info Strip (thin bar + stat pills)

    private func infoStrip(challenge: ZenloopChallenge) -> some View {
        VStack(spacing: 8) {
            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * zenloopManager.currentProgress))
                        .animation(.easeInOut(duration: 0.6), value: zenloopManager.currentProgress)
                        .shadow(color: accentColor.opacity(0.4), radius: 6)
                }
            }
            .frame(height: 4)
            .padding(.top, 14)

            // Stats row
            HStack {
                if challenge.blockedAppsCount > 0 || isScheduledSession(challenge) {
                    statLabel(
                        icon: "shield.fill",
                        value: "\(challenge.blockedAppsCount)",
                        label: "blocked",
                        color: .purple
                    )
                }

                Spacer()

                statLabel(
                    icon: "flame.fill",
                    value: "\(Int(zenloopManager.currentProgress * 100))%",
                    label: "done",
                    color: accentColor
                )

                if challenge.appOpenAttempts > 0 {
                    Spacer()
                    statLabel(
                        icon: "hand.raised.fill",
                        value: "\(challenge.appOpenAttempts)",
                        label: challenge.appOpenAttempts > 1 ? "attempts" : "attempt",
                        color: .orange
                    )
                }
            }
        }
    }

    private func statLabel(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color.opacity(0.7))

            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - Blocked Apps Row (compact horizontal scroll)

    private func blockedAppsRow(challenge: ZenloopChallenge) -> some View {
        let selection = zenloopManager.getAppsSelection()
        let totalCount = selection.applicationTokens.count + selection.categoryTokens.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -5) {
                ForEach(Array(selection.applicationTokens.prefix(8)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.8), lineWidth: 1.5)
                        )
                }

                ForEach(Array(selection.categoryTokens.prefix(8)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.8), lineWidth: 1.5)
                        )
                }

                if totalCount > 10 {
                    Text("+\(totalCount - 10)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 32)
    }

    // MARK: - Goals Chips

    private func goalsChips(challenge: ZenloopChallenge) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(challenge.taskGoals, id: \.text) { goal in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                goal.isCompleted
                                    ? Color.green.opacity(0.15)
                                    : Color.white.opacity(0.04)
                            )
                            .frame(width: 20, height: 20)

                        if goal.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.green)
                        }
                    }

                    Text(goal.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(
                            goal.isCompleted
                                ? .white.opacity(0.3)
                                : .white.opacity(0.8)
                        )
                        .strikethrough(goal.isCompleted, color: .white.opacity(0.2))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(goal.isCompleted ? 0.02 : 0.04))
                )
            }
        }
    }

    // MARK: - Attempts Badge

    private func attemptsBadge(challenge: ZenloopChallenge) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange.opacity(0.8))

            Text(challenge.appOpenAttempts > 1
                 ? "\(challenge.appOpenAttempts) blocked attempts"
                 : "1 blocked attempt")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange.opacity(0.7))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule().fill(Color.orange.opacity(0.08))
        )
    }

    // MARK: - Helpers

    private func isScheduledSession(_ challenge: ZenloopChallenge) -> Bool {
        challenge.id.hasPrefix("scheduled_") ||
        challenge.description.contains("programmée déclenchée automatiquement")
    }

    private var accentColor: Color {
        switch zenloopManager.currentState {
        case .active:    return .cyan
        case .paused:    return .mint
        case .completed: return .green
        default:         return .white
        }
    }

    private var pauseResumeColor: Color {
        zenloopManager.currentState == .paused ? .green : .orange
    }
}