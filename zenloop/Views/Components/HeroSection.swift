//
//  HeroSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//  Refactored to match TimerCard minimal style
//

import SwiftUI
import FamilyControls
import ManagedSettings

struct HeroSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool

    var body: some View {
        // Actions contextuelles uniquement, style minimaliste
        ContextualActionsSection(
            currentState: currentState,
            zenloopManager: zenloopManager
        )
        .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(Animation.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - Contextual Actions Section (Refactorisée)

struct ContextualActionsSection: View {
    let currentState: ZenloopState
    @ObservedObject var zenloopManager: ZenloopManager

    var body: some View {
        switch currentState {
        case .idle:
            EmptyView() // Pas d'actions en idle (TimerCard gère tout)

        case .active:
            ActiveSessionActions(zenloopManager: zenloopManager)

        case .paused:
            PausedSessionActions(zenloopManager: zenloopManager)

        case .completed:
            CompletedSessionActions(zenloopManager: zenloopManager)
        }
    }
}

// MARK: - Active Session Actions

struct ActiveSessionActions: View {
    @ObservedObject var zenloopManager: ZenloopManager

    var body: some View {
        HStack(spacing: 12) {
            // Pause Button
            Button(action: { zenloopManager.requestPause() }) {
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.mint)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PAUSE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)

                        Text("Take a break")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // Stop Button
            Button(action: { zenloopManager.stopCurrentChallenge() }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("STOP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)

                        Text("End session")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Paused Session Actions

struct PausedSessionActions: View {
    @ObservedObject var zenloopManager: ZenloopManager

    var body: some View {
        HStack(spacing: 12) {
            // Resume Button
            Button(action: { zenloopManager.resumeChallenge() }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("RESUME")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)

                        Text("Continue session")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // Stop Button
            Button(action: { zenloopManager.stopCurrentChallenge() }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("STOP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)

                        Text("End session")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Completed Session Actions

struct CompletedSessionActions: View {
    @ObservedObject var zenloopManager: ZenloopManager

    var body: some View {
        VStack(spacing: 12) {
            // Célébration message avec icône
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION COMPLETED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)

                    Text("Great work!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()
            }

            // Start New Session Button
            Button(action: { zenloopManager.resetToIdle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("Start new session")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 14)
    }
}

// Note: ScaleButtonStyle is already defined in CompactButton.swift
