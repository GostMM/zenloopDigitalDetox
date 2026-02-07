//
//  GoalsSectionView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct GoalsSectionView: View {
    @Binding var taskGoals: [(text: String, isCompleted: Bool)]
    @Binding var showingAddGoal: Bool
    let goalSuggestions: [(String, String)]
    let onAddGoal: (String) -> Void
    let onRemoveGoal: (Int) -> Void
    let onToggleGoalCompletion: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.5) : .yellow)

                Text(String(localized: "goals"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                if !taskGoals.isEmpty {
                    Text("\(taskGoals.count)/5")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.yellow.opacity(0.15))
                        )
                }

                Spacer()

                if taskGoals.count < 5 {
                    Menu {
                        ForEach(goalSuggestions, id: \.0) { suggestion in
                            Button {
                                onAddGoal(String(localized: String.LocalizationValue(suggestion.0)))
                            } label: {
                                Label(String(localized: String.LocalizationValue(suggestion.0)), systemImage: suggestion.1)
                            }
                        }

                        Divider()

                        Button {
                            showingAddGoal = true
                        } label: {
                            Label(String(localized: "custom_goal"), systemImage: "pencil")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(String(localized: "add"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.6) : .yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    }
                }
            }

            // Liste des objectifs en grille 2x2 + 1 si impair
            if !taskGoals.isEmpty {
                VStack(spacing: 6) {
                    // Afficher les goals 2 par 2
                    let pairCount = taskGoals.count / 2
                    let hasOddGoal = taskGoals.count % 2 != 0

                    // Grille 2x2 pour les paires
                    ForEach(0..<pairCount, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            // Goal gauche
                            GoalCard(
                                goal: taskGoals[rowIndex * 2],
                                onToggle: { onToggleGoalCompletion(rowIndex * 2) },
                                onRemove: { onRemoveGoal(rowIndex * 2) }
                            )

                            // Goal droit
                            GoalCard(
                                goal: taskGoals[rowIndex * 2 + 1],
                                onToggle: { onToggleGoalCompletion(rowIndex * 2 + 1) },
                                onRemove: { onRemoveGoal(rowIndex * 2 + 1) }
                            )
                        }
                    }

                    // Goal impair seul si nécessaire
                    if hasOddGoal {
                        GoalCard(
                            goal: taskGoals[taskGoals.count - 1],
                            onToggle: { onToggleGoalCompletion(taskGoals.count - 1) },
                            onRemove: { onRemoveGoal(taskGoals.count - 1) }
                        )
                    }
                }
            } else {
                Text(String(localized: "add_goal_optional"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(taskGoals.isEmpty ? .white.opacity(0.03) : .yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(taskGoals.isEmpty ? .white.opacity(0.08) : .yellow.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Goal Card Component

struct GoalCard: View {
    let goal: (text: String, isCompleted: Bool)
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox interactive
            Button(action: onToggle) {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(goal.isCompleted ? .green : .yellow.opacity(0.6))
            }

            Text(goal.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(goal.isCompleted ? .white.opacity(0.5) : .white.opacity(0.9))
                .strikethrough(goal.isCompleted, color: .white.opacity(0.5))
                .lineLimit(1)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(goal.isCompleted ? .green.opacity(0.08) : .yellow.opacity(0.05))
        )
    }
}
