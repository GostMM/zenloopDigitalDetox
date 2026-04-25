//  ActiveChallengeSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//  Redesign v4: Refined dark luxury, organized sections, goal priorities & progress
//  11/04/2026

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

    // MARK: Computed

    private var challenge: ZenloopChallenge? { zenloopManager.currentChallenge }

    private var completedGoals: Int {
        challenge?.taskGoals.filter(\.isCompleted).count ?? 0
    }

    private var totalGoals: Int {
        challenge?.taskGoals.count ?? 0
    }

    private var goalProgress: Double {
        guard totalGoals > 0 else { return 0 }
        return Double(completedGoals) / Double(totalGoals)
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

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            if challenge != nil {
                // ━━ HEADER LABEL ━━
                sectionLabel(String(localized: "active_challenge_focus_session"))
                    .padding(.bottom, 16)

                // ━━ HERO: Ring Timer + Controls ━━
                ringTimerWithControls

                // ━━ PROGRESS BAR (thin) ━━
                thinProgressBar
                    .padding(.top, 18)

                // ━━ STATS ROW ━━
                statsRow
                    .padding(.top, 10)

                // ━━ BLOCKED APPS ━━
                if let c = challenge, c.blockedAppsCount > 0 || isScheduledSession(c) {
                    blockedAppsSection(challenge: c)
                        .padding(.top, 18)
                }

                // ━━ GOALS ━━
                if let c = challenge, !c.taskGoals.isEmpty {
                    goalsSection(challenge: c)
                        .padding(.top, 18)
                }

                // ━━ ATTEMPTS ALERT ━━
                if let c = challenge, c.appOpenAttempts > 0 {
                    attemptsAlert(challenge: c)
                        .padding(.top, 14)
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

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(3)
            .foregroundColor(.white.opacity(0.2))
    }

    // MARK: - Section Header (title + trailing badge)

    private func sectionHeader(title: String, trailing: String? = nil, trailingColor: Color = .cyan) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.25))

            Spacer()

            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(trailingColor.opacity(0.6))
            }
        }
    }

    // MARK: - Ring Timer + Inline Controls

    private var ringTimerWithControls: some View {
        VStack(spacing: 16) {

            // ── Circular Ring ──
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 5)
                    .frame(width: 190, height: 190)

                // Progress ring
                Circle()
                    .trim(from: 0, to: zenloopManager.currentProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.2),
                                accentColor,
                                accentColor.opacity(0.6)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: zenloopManager.currentProgress)

                // Glow dot at tip
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: accentColor.opacity(0.6), radius: 10)
                    .offset(y: -95)
                    .rotationEffect(.degrees(360 * zenloopManager.currentProgress))
                    .opacity(ringPulse ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.8), value: zenloopManager.currentProgress)

                // Inner content
                VStack(spacing: 2) {
                    if zenloopManager.currentState == .paused {
                        pausedContent
                    } else {
                        activeContent
                    }
                }
            }

            // ── Pill Control Bar ──
            pillControlBar
                .frame(maxWidth: 280)
        }
    }

    private var activeContent: some View {
        VStack(spacing: 2) {
            Text("\(Int(zenloopManager.currentProgress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor.opacity(0.6))

            Text(zenloopManager.currentTimeRemaining)
                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: accentColor.opacity(ringPulse ? 0.3 : 0.0), radius: 20)

            Text(String(localized: "active_challenge_remaining"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.2))
        }
    }

    private var pausedContent: some View {
        VStack(spacing: 2) {
            Text(String(localized: "active_challenge_pause_label"))
                .font(.system(size: 9, weight: .heavy))
                .tracking(2)
                .foregroundColor(.mint)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.mint.opacity(0.15)))

            Text(zenloopManager.pauseTimeRemaining)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.mint.opacity(0.9))

            Text(zenloopManager.currentTimeRemaining)
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
    }

    private var pillControlBar: some View {
        HStack(spacing: 0) {
            // Pause / Resume
            Button {
                if zenloopManager.currentState == .paused {
                    zenloopManager.resumeChallenge()
                } else {
                    zenloopManager.requestPause()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: zenloopManager.currentState == .paused
                          ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .bold))

                    Text(zenloopManager.currentState == .paused
                         ? String(localized: "resume")
                         : String(localized: "pause"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(pauseResumeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(pauseResumeColor.opacity(0.1))
            }

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 24)

            // Stop
            Button { showBreathingView = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(localized: "stop"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(Color.red.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.06))
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Thin Progress Bar

    private var thinProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.04))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geo.size.width * zenloopManager.currentProgress))
                    .shadow(color: accentColor.opacity(0.3), radius: 6)
                    .animation(.easeInOut(duration: 0.6), value: zenloopManager.currentProgress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack {
            if let c = challenge, c.blockedAppsCount > 0 || isScheduledSession(c) {
                statItem(
                    icon: "shield.fill",
                    value: "\(c.blockedAppsCount)",
                    label: String(localized: "active_challenge_blocked"),
                    color: .purple
                )
            }

            Spacer()

            statItem(
                icon: "flame.fill",
                value: "\(Int(zenloopManager.currentProgress * 100))%",
                label: String(localized: "active_challenge_done"),
                color: accentColor
            )

            if let c = challenge, c.appOpenAttempts > 0 {
                Spacer()
                statItem(
                    icon: "hand.raised.fill",
                    value: "\(c.appOpenAttempts)",
                    label: c.appOpenAttempts > 1
                        ? String(localized: "active_challenge_attempts")
                        : String(localized: "active_challenge_attempt"),
                    color: .orange
                )
            }
        }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color.opacity(0.65))

            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
        }
    }

    // MARK: - Blocked Apps Section

    private func blockedAppsSection(challenge: ZenloopChallenge) -> some View {
        let selection = zenloopManager.getAppsSelection()
        let selectionCount = selection.applicationTokens.count + selection.categoryTokens.count
        let effectiveTotal = selectionCount > 0 ? selectionCount : challenge.blockedAppsCount
        let maxIcons = 8

        return VStack(spacing: 8) {
            sectionHeader(
                title: String(localized: "active_challenge_blocked_apps"),
                trailing: "\(effectiveTotal) apps",
                trailingColor: accentColor
            )

            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -6) {
                        ForEach(Array(selection.applicationTokens.prefix(maxIcons)), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 30, height: 30)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                                )
                        }

                        ForEach(
                            Array(selection.categoryTokens.prefix(max(0, maxIcons - selection.applicationTokens.count))),
                            id: \.self
                        ) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 30, height: 30)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                                )
                        }

                        if selectionCount > maxIcons {
                            Text("+\(selectionCount - maxIcons)")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.white.opacity(0.04)))
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 34)
        }
    }

    // MARK: - Goals Section (Redesigned)

    private func goalsSection(challenge: ZenloopChallenge) -> some View {
        VStack(spacing: 8) {
            // Header with counter
            sectionHeader(
                title: String(localized: "active_challenge_session_goals"),
                trailing: "\(completedGoals) / \(totalGoals)",
                trailingColor: completedGoals == totalGoals && totalGoals > 0 ? .green : .cyan
            )

            // Goal items
            VStack(spacing: 6) {
                ForEach(challenge.taskGoals) { goal in
                    goalRow(goal: goal)
                }
            }

            // Goal progress bar
            goalProgressBar
        }
    }

    private func goalRow(goal: TaskGoal) -> some View {
        Button {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
            zenloopManager.toggleTaskGoal(id: goal.id)
        } label: {
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(
                            goal.isCompleted
                                ? Color.green.opacity(0.1)
                                : Color.white.opacity(0.03)
                        )
                        .frame(width: 20, height: 20)

                    if goal.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.green)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }

                // Goal text
                Text(goal.text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(
                        goal.isCompleted
                            ? .white.opacity(0.25)
                            : .white.opacity(0.75)
                    )
                    .strikethrough(goal.isCompleted, color: .white.opacity(0.1))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Status tag
                goalTag(for: goal)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(goal.isCompleted ? 0.015 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        goal.isCompleted
                            ? Color.green.opacity(0.12)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: goal.isCompleted)
    }

    @ViewBuilder
    private func goalTag(for goal: TaskGoal) -> some View {
        if goal.isCompleted {
            tagPill(text: String(localized: "active_challenge_tag_done"), bgColor: .green, textColor: .green)
        } else {
            tagPill(text: String(localized: "active_challenge_tag_todo"), bgColor: .white, textColor: .white)
        }
    }

    private func tagPill(text: String, bgColor: Color, textColor: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(textColor.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(bgColor.opacity(0.08))
            )
    }

    private var goalProgressBar: some View {
        HStack(spacing: 8) {
            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.04))

                    Capsule()
                        .fill(Color.green)
                        .frame(width: max(0, geo.size.width * goalProgress))
                        .animation(.easeInOut(duration: 0.4), value: goalProgress)
                }
            }
            .frame(height: 3)

            // Percentage
            Text("\(Int(goalProgress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.015))
        )
    }

    // MARK: - Attempts Alert Banner

    private func attemptsAlert(challenge: ZenloopChallenge) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange.opacity(0.8))

            Text(challenge.appOpenAttempts > 1
                 ? String(format: String(localized: "active_challenge_blocked_attempts"), challenge.appOpenAttempts)
                 : String(localized: "active_challenge_blocked_attempt_single"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange.opacity(0.7))

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            Capsule().fill(Color.orange.opacity(0.06))
        )
    }

    // MARK: - Helpers

    private func isScheduledSession(_ challenge: ZenloopChallenge) -> Bool {
        challenge.id.hasPrefix("scheduled_") ||
        challenge.description.contains("programmée déclenchée automatiquement")
    }
}