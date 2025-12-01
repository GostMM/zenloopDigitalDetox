//
//  ExpandedTimerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct ExpandedTimerView: View {
    let selectedConcentrationType: ConcentrationType
    let formattedDuration: String
    let hasSelectedApps: Bool
    let selectedApps: FamilyActivitySelection
    let buttonIsEnabled: Bool
    let buttonText: String

    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Binding var taskGoals: [(text: String, isCompleted: Bool)]
    @Binding var showingAddGoal: Bool
    @Binding var showingConcentrationPicker: Bool

    let goalSuggestions: [(String, String)]

    let onShowConcentrationPicker: () -> Void
    let onShowAppSelection: () -> Void
    let onStartSession: () -> Void
    let onIncreaseHours: () -> Void
    let onDecreaseHours: () -> Void
    let onIncreaseMinutes: () -> Void
    let onDecreaseMinutes: () -> Void
    let onAddGoal: (String) -> Void
    let onRemoveGoal: (Int) -> Void
    let onToggleGoalCompletion: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .background(.white.opacity(0.1))
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                // Type de concentration
                HStack {
                    Text(String(localized: "type"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Button(action: onShowConcentrationPicker) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedConcentrationType.icon)
                                .font(.system(size: 14))
                                .foregroundColor(selectedConcentrationType.primaryColor)

                            Text(selectedConcentrationType.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedConcentrationType.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                // Sélecteur de durée
                DurationPickerView(
                    selectedConcentrationType: selectedConcentrationType,
                    formattedDuration: formattedDuration,
                    selectedHours: $selectedHours,
                    selectedMinutes: $selectedMinutes,
                    onIncreaseHours: onIncreaseHours,
                    onDecreaseHours: onDecreaseHours,
                    onIncreaseMinutes: onIncreaseMinutes,
                    onDecreaseMinutes: onDecreaseMinutes
                )

                // Section Objectifs
                GoalsSectionView(
                    taskGoals: $taskGoals,
                    showingAddGoal: $showingAddGoal,
                    goalSuggestions: goalSuggestions,
                    onAddGoal: onAddGoal,
                    onRemoveGoal: onRemoveGoal,
                    onToggleGoalCompletion: onToggleGoalCompletion
                )
                .sheet(isPresented: $showingAddGoal) {
                    AddGoalSheet(onAdd: { newGoal in
                        onAddGoal(newGoal)
                        showingAddGoal = false
                    }, onCancel: {
                        showingAddGoal = false
                    })
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
                }

                // Applications à bloquer
                AppSelectionSectionView(
                    hasSelectedApps: hasSelectedApps,
                    selectedApps: selectedApps,
                    onSelectApps: onShowAppSelection
                )

                // Bouton de démarrage
                Button(action: {
                    if buttonIsEnabled {
                        onStartSession()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text(buttonText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: buttonIsEnabled ?
                                [selectedConcentrationType.primaryColor, selectedConcentrationType.accentColor] :
                                [Color.gray.opacity(0.5), Color.gray.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(!buttonIsEnabled)
                .shadow(color: selectedConcentrationType.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
