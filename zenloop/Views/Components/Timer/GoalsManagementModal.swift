//
//  GoalsManagementModal.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct GoalsManagementModal: View {
    @Binding var taskGoals: [(text: String, isCompleted: Bool)]
    @Environment(\.dismiss) var dismiss

    @State private var showingAddGoal = false
    @State private var newGoalText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    private let goalSuggestions = [
        ("read_20_pages", "book.fill"),
        ("finish_report", "doc.text.fill"),
        ("meditate_10_min", "figure.mind.and.body"),
        ("complete_workout", "dumbbell.fill"),
        ("write_1000_words", "pencil.and.outline"),
        ("study_chapter", "graduationcap.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow)

                    Text(String(localized: "goals"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    if !taskGoals.isEmpty {
                        Text("\(taskGoals.count)/5")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(.yellow.opacity(0.15))
                            )
                    }

                    Spacer()
                }

                Text(String(localized: "goals_subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)

            // Goals List
            ScrollView {
                VStack(spacing: 12) {
                    if taskGoals.isEmpty {
                        // Empty State
                        VStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.top, 20)

                            Text(String(localized: "no_goals_yet"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Text(String(localized: "add_goals_hint"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        // Goals List
                        ForEach(Array(taskGoals.enumerated()), id: \.offset) { index, goal in
                            GoalRow(
                                goal: goal,
                                onToggle: {
                                    toggleGoalCompletion(at: index)
                                },
                                onDelete: {
                                    removeGoal(at: index)
                                }
                            )
                        }
                    }

                    // Quick Suggestions
                    if taskGoals.count < 5 && !showingAddGoal {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "suggestions"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.top, 8)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(goalSuggestions, id: \.0) { suggestion in
                                    SuggestionButton(
                                        title: String(localized: String.LocalizationValue(suggestion.0)),
                                        icon: suggestion.1,
                                        onTap: {
                                            addGoal(String(localized: String.LocalizationValue(suggestion.0)))
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 300)

            // Add Custom Goal Field
            if showingAddGoal {
                VStack(spacing: 12) {
                    Divider()
                        .background(.white.opacity(0.1))

                    HStack(spacing: 12) {
                        TextField(String(localized: "goal_placeholder"), text: $newGoalText)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                if !newGoalText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    addGoal(newGoalText)
                                    newGoalText = ""
                                    showingAddGoal = false
                                }
                            }

                        Button {
                            if !newGoalText.trimmingCharacters(in: .whitespaces).isEmpty {
                                addGoal(newGoalText)
                                newGoalText = ""
                                showingAddGoal = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(newGoalText.isEmpty ? .white.opacity(0.3) : .yellow)
                        }
                        .disabled(newGoalText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTextFieldFocused = true
                    }
                }
            }

            // Buttons
            VStack(spacing: 8) {
                if taskGoals.count < 5 {
                    Button {
                        impactFeedback.impactOccurred()
                        withAnimation {
                            showingAddGoal.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showingAddGoal ? "xmark" : "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(showingAddGoal ? String(localized: "cancel") : String(localized: "add_custom_goal"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: showingAddGoal ? [.red.opacity(0.6), .red.opacity(0.4)] : [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "done"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Goal Management

    private func addGoal(_ goal: String) {
        guard taskGoals.count < 5 else { return }
        guard !goal.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        impactFeedback.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            taskGoals.append((text: goal, isCompleted: false))
        }
    }

    private func removeGoal(at index: Int) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            taskGoals.remove(at: index)
        }
    }

    private func toggleGoalCompletion(at index: Int) {
        impactFeedback.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            taskGoals[index].isCompleted.toggle()
        }
    }
}

// MARK: - Goal Row

struct GoalRow: View {
    let goal: (text: String, isCompleted: Bool)
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(goal.isCompleted ? .green : .yellow)
            }

            // Text
            Text(goal.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(goal.isCompleted ? .white.opacity(0.5) : .white)
                .strikethrough(goal.isCompleted, color: .white.opacity(0.5))
                .lineLimit(2)

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(goal.isCompleted ? .green.opacity(0.1) : .yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goal.isCompleted ? .green.opacity(0.3) : .yellow.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let title: String
    let icon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.8))

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.yellow.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
