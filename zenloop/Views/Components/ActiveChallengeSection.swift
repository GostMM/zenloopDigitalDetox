//  ActiveChallengeSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//  Refactored: Timer en grand, Blocked Apps au-dessus, Jauge épaisse
//

import SwiftUI
import FamilyControls

struct ActiveChallengeSection: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var showBreathingView = false
    @State private var shouldStopSession = false

    var body: some View {
        VStack(spacing: 20) {
            if let challenge = zenloopManager.currentChallenge {
                // Timer en très grand (en haut, centré)
                timerSection

                // Blocked Apps (au-dessus de la jauge)
                if challenge.blockedAppsCount > 0 {
                    blockedAppsSection(challenge: challenge)
                }

                // Progress bar (plus épaisse et énergique)
                progressBarSection

                // Goals section (afficher si goals existent)
                if !challenge.taskGoals.isEmpty {
                    goalsSection(challenge: challenge)
                }

                // App Open Attempts (si > 0)
                if challenge.appOpenAttempts > 0 {
                    appAttemptsWarning(challenge: challenge)
                }
            }
        }
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(Animation.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
        .onAppear {
            if zenloopManager.currentState == .active {
                zenloopManager.startStateMonitoring()
            }
        }
        .onChange(of: zenloopManager.currentState) { newState in
            if newState == .active {
                zenloopManager.startStateMonitoring()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, zenloopManager.currentState == .active {
                zenloopManager.startStateMonitoring()
            }
        }
        .fullScreenCover(isPresented: $showBreathingView, onDismiss: {
            // Stop uniquement si l'utilisateur a choisi "Stop"
            if shouldStopSession && zenloopManager.currentState != .idle {
                zenloopManager.stopCurrentChallenge()
            }
            shouldStopSession = false
        }) {
            BreathingMeditationView(
                zenloopManager: zenloopManager,
                onStopRequested: {
                    shouldStopSession = true
                }
            )
        }
    }

    // MARK: - Timer Section (très grand, centré)

    private var timerSection: some View {
        VStack(spacing: 6) {
            Text("TIME REMAINING")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            Text(zenloopManager.currentTimeRemaining)
                .font(.system(size: 52, weight: .heavy))
                .foregroundColor(stateColor)
                .monospacedDigit()
        }
        .padding(.vertical, 14)
    }

    // MARK: - Blocked Apps Section

    private func blockedAppsSection(challenge: ZenloopChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label + Boutons d'action (Pause/Stop à droite)
            HStack(spacing: 12) {
                // Blocked Apps Label (gauche)
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("BLOCKED APPS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)

                        Text("\(challenge.blockedAppsCount) apps")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Boutons Pause/Resume/Stop (droite, vertical)
                VStack(spacing: 6) {
                    // Pause/Resume Button (change selon l'état)
                    if zenloopManager.currentState == .paused {
                        // Resume Button
                        Button(action: { zenloopManager.resumeChallenge() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Resume")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 90)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    } else {
                        // Pause Button
                        Button(action: { zenloopManager.requestPause() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Pause")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 90)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.yellow.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }

                    // Stop Button → Affiche BreathingMeditationView
                    Button(action: { showBreathingView = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Stop")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 90)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }

            // Apps et catégories en pile horizontale
            HStack(spacing: -8) {
                let selection = zenloopManager.getAppsSelection()
                let totalCount = selection.applicationTokens.count + selection.categoryTokens.count

                // Afficher les apps
                ForEach(Array(selection.applicationTokens.prefix(6)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                }

                // Afficher les catégories
                ForEach(Array(selection.categoryTokens.prefix(6)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                }

                // Afficher +X si plus de 8 items au total
                if totalCount > 8 {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

                        Text("+\(totalCount - 8)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Progress Bar Section (épaisse et énergique)

    private var progressBarSection: some View {
        VStack(spacing: 10) {
            // Progress percentage
            HStack {
                Text("PROGRESS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(0.5)

                Spacer()

                Text("\(Int(zenloopManager.currentProgress * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            // Barre de progression ÉPAISSE
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.15))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(stateGradient)
                        .frame(width: geometry.size.width * zenloopManager.currentProgress, height: 16)
                        .animation(.easeInOut(duration: 0.5), value: zenloopManager.currentProgress)
                        .shadow(color: stateColor.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 16)
        }
        .padding(.vertical, 12)
    }

    // MARK: - App Attempts Warning

    private func appAttemptsWarning(challenge: ZenloopChallenge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("BLOCKED ATTEMPTS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(0.5)

                Text(challenge.appOpenAttempts > 1
                    ? "\(challenge.appOpenAttempts) attempts blocked"
                    : "1 attempt blocked")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

        // MARK: - Goals Section

    private func goalsSection(challenge: ZenloopChallenge) -> some View {
        VStack(spacing: 6) {
            let goals = challenge.taskGoals
            let pairCount = goals.count / 2
            let hasOddGoal = goals.count % 2 != 0

            // Grille 2x2 pour les paires
            ForEach(0..<pairCount, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    // Goal gauche
                    goalCard(goal: goals[rowIndex * 2])

                    // Goal droit
                    goalCard(goal: goals[rowIndex * 2 + 1])
                }
            }

            // Goal impair seul si nécessaire
            if hasOddGoal {
                goalCard(goal: goals[goals.count - 1])
            }
        }
    }

    private func goalCard(goal: TaskGoal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(goal.isCompleted ? .green : .yellow.opacity(0.6))

            Text(goal.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(goal.isCompleted ? .white.opacity(0.5) : .white.opacity(0.9))
                .strikethrough(goal.isCompleted, color: .white.opacity(0.5))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(goal.isCompleted ? .green.opacity(0.08) : .yellow.opacity(0.05))
        )
    }

// MARK: - Helpers

    private var stateColor: Color {
        switch zenloopManager.currentState {
        case .active: return .cyan
        case .paused: return .mint
        case .completed: return .green
        default: return .white
        }
    }

    private var stateGradient: LinearGradient {
        LinearGradient(
            colors: [stateColor, stateColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
