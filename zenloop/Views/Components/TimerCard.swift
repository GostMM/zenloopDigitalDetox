//
//  TimerCard.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct TimerCard: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @State private var selectedMinutes: Int = 25
    @State private var selectedHours: Int = 0
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var hasSelectedApps = false
    @State private var showingDurationModal = false
    @State private var showingGoalsModal = false
    @State private var taskGoals: [(text: String, isCompleted: Bool)] = []
    @State private var showingDifficultySelector = false
    @State private var selectedDifficulty: DifficultyLevel? = nil
    @StateObject private var gatekeeper = PremiumGatekeeper.shared

    private let availableMinutes = [5, 10, 15, 20, 25, 30, 45, 55]

    // MARK: - Computed Properties

    private var formattedDuration: String {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        if selectedHours > 0 {
            if selectedMinutes > 0 {
                return "\(selectedHours)h \(selectedMinutes)min"
            } else {
                return "\(selectedHours)h"
            }
        } else {
            return "\(selectedMinutes)min"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CompactTimerView(
                selectedDifficulty: selectedDifficulty,
                formattedDuration: formattedDuration,
                hasSelectedApps: hasSelectedApps,
                selectedAppsCount: zenloopManager.selectedAppsCount,
                isIdle: zenloopManager.currentState == .idle,
                selectedApps: selectedApps,
                taskGoalsCount: taskGoals.count,
                onEditDifficulty: {
                    showingDifficultySelector = true
                },
                onEditDuration: {
                    showingDurationModal = true
                },
                onEditGoals: {
                    showingGoalsModal = true
                },
                onEditApps: {
                    showingAppSelection = true
                },
                onStartSession: startSession
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.25), value: showContent)
        .sheet(isPresented: $showingDurationModal) {
            DurationSelectionModal(
                selectedHours: $selectedHours,
                selectedMinutes: $selectedMinutes,
                onConfirm: {
                    // Duration updated via binding
                }
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingGoalsModal) {
            GoalsManagementModal(taskGoals: $taskGoals)
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingDifficultySelector) {
            DifficultySelectionModal(
                selectedDifficulty: $selectedDifficulty,
                autoDifficulty: calculateAutoDifficulty()
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: selectedDifficulty) { oldValue, newValue in
            // Quand une difficulté est sélectionnée dans le modal, juste fermer
            if showingDifficultySelector && newValue != nil {
                showingDifficultySelector = false
            }
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { oldSelection, newSelection in
            let oldHasSelectedApps = hasSelectedApps
            hasSelectedApps = !newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty

            print("🔍 [TIMER_CARD] Selection changed:")
            print("  - Old: Apps=\(oldSelection.applicationTokens.count), Categories=\(oldSelection.categoryTokens.count)")
            print("  - New: Apps=\(newSelection.applicationTokens.count), Categories=\(newSelection.categoryTokens.count)")
            print("  - HasSelectedApps: \(oldHasSelectedApps) -> \(hasSelectedApps)")

            zenloopManager.updateAppsSelectionWithDetails(newSelection)
        }
        .onAppear {
            if !availableMinutes.contains(selectedMinutes) {
                selectedMinutes = 25
            }

            selectedApps = zenloopManager.getAppsSelection()
            hasSelectedApps = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty

            print("🔍 [TIMER_CARD] OnAppear - Apps: \(selectedApps.applicationTokens.count), Categories: \(selectedApps.categoryTokens.count), HasSelectedApps: \(hasSelectedApps), ManagerCount: \(zenloopManager.selectedAppsCount)")

            if !hasSelectedApps && zenloopManager.selectedAppsCount > 0 {
                print("⚠️ [TIMER_CARD] Incohérence détectée - reset de la sélection du manager")
                zenloopManager.updateAppsSelection(FamilyActivitySelection())
            }
        }
        .premiumGated()
    }

    // MARK: - Session Management

    private func startSession() {
        gatekeeper.performIfAllowed(.startCustomSession) {
            confirmStartSession()
        }
    }

    private func confirmStartSession() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        let totalMinutes = selectedHours * 60 + selectedMinutes
        let difficulty: DifficultyLevel = selectedDifficulty ?? (totalMinutes <= 20 ? .easy : totalMinutes <= 60 ? .medium : .hard)
        let title = "Session \(difficulty.rawValue) - \(formattedDuration)"
        let duration = TimeInterval(totalMinutes * 60)

        print("🚀 [TIMER_CARD] Démarrage session: \(title), difficulté: \(difficulty.rawValue)")

        if hasSelectedApps {
            let goalsString = taskGoals.isEmpty ? nil : taskGoals.map { goal in
                goal.isCompleted ? "✅ \(goal.text)" : "⭕️ \(goal.text)"
            }.joined(separator: "\n")

            zenloopManager.startCustomChallenge(
                title: title,
                duration: duration,
                difficulty: difficulty,
                apps: selectedApps,
                taskGoal: goalsString
            )
        } else {
            zenloopManager.startQuickChallenge(duration: duration, difficulty: difficulty)
        }

        selectedDifficulty = nil
    }

    private func calculateAutoDifficulty() -> DifficultyLevel {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        return totalMinutes <= 20 ? .easy : totalMinutes <= 60 ? .medium : .hard
    }
}

#Preview {
    TimerCard(zenloopManager: ZenloopManager.shared, showContent: true)
        .background(Color.black)
}
