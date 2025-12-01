//
//  DifficultySelectionModal.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct DifficultySelectionModal: View {
    @Binding var selectedDifficulty: DifficultyLevel?
    let autoDifficulty: DifficultyLevel
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    // Réutiliser le même feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header
            VStack(spacing: 4) {
                Text(String(localized: "difficulty_modal_title"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(String(localized: "difficulty_modal_subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.bottom, 18)

            // Options
            VStack(spacing: 8) {
                ForEach(DifficultyLevel.allCases) { difficulty in
                    DifficultyOptionCard(
                        difficulty: difficulty,
                        isSelected: (selectedDifficulty ?? autoDifficulty) == difficulty,
                        isAuto: selectedDifficulty == nil && difficulty == autoDifficulty,
                        onTap: {
                            impactFeedback.impactOccurred()
                            selectedDifficulty = difficulty
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Boutons
            VStack(spacing: 8) {
                Button {
                    impactFeedback.impactOccurred()
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(String(localized: "start_session"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "cancel"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(height: 40)
                }
            }
            .padding(.horizontal, 16)
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
}

struct DifficultyOptionCard: View {
    let difficulty: DifficultyLevel
    let isSelected: Bool
    let isAuto: Bool
    let onTap: () -> Void

    private var modeInfo: (title: String, description: String, icon: String) {
        switch difficulty {
        case .easy:
            return (
                String(localized: "difficulty_easy_mode"),
                String(localized: "difficulty_easy_desc"),
                "shield.lefthalf.filled"
            )
        case .medium:
            return (
                String(localized: "difficulty_medium_mode"),
                String(localized: "difficulty_medium_desc"),
                "shield.fill"
            )
        case .hard:
            return (
                String(localized: "difficulty_hard_mode"),
                String(localized: "difficulty_hard_desc"),
                "eye.slash.fill"
            )
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Icon avec gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        difficulty.color.opacity(0.2),
                                        difficulty.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: difficulty.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(difficulty.color)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(difficulty.localizedName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            if isAuto {
                                HStack(spacing: 2) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 7, weight: .bold))
                                    Text(String(localized: "suggested"))
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(difficulty.color.opacity(0.25))
                                .cornerRadius(5)
                            }

                            Spacer()

                            // Checkmark
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(difficulty.color)
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }

                        // Mode type avec icône
                        HStack(spacing: 5) {
                            Image(systemName: modeInfo.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(difficulty.color.opacity(0.8))

                            Text(modeInfo.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(difficulty.color.opacity(0.9))
                        }

                        // Description
                        Text(modeInfo.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    difficulty.color.opacity(0.15),
                                    difficulty.color.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? difficulty.color.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? difficulty.color.opacity(0.2) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
