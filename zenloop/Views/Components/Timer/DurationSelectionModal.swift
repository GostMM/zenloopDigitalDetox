//
//  DurationSelectionModal.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct DurationSelectionModal: View {
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let availableMinutes = [5, 10, 15, 20, 25, 30, 45, 55]

    private var formattedDuration: String {
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
            // Drag Indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Header
            VStack(spacing: 4) {
                Text(String(localized: "duration"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(formattedDuration)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)

            // Quick Durations
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "quick_durations"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    QuickDurationButton(minutes: 15, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                    QuickDurationButton(minutes: 25, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                    QuickDurationButton(minutes: 45, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                    QuickDurationButton(minutes: 60, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                    QuickDurationButton(minutes: 90, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                    QuickDurationButton(minutes: 120, selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, impactFeedback: impactFeedback)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)

            // Custom Duration
            VStack(spacing: 16) {
                Text(String(localized: "custom_duration"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 24) {
                    // Heures
                    VStack(spacing: 12) {
                        Text(String(localized: "hours"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 12) {
                            Button {
                                decreaseHours()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedHours > 0 ? .cyan : .white.opacity(0.3))
                            }
                            .disabled(selectedHours == 0)

                            Text("\(selectedHours)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 40)

                            Button {
                                increaseHours()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedHours < 24 ? .cyan : .white.opacity(0.3))
                            }
                            .disabled(selectedHours >= 24)
                        }
                    }

                    // Minutes
                    VStack(spacing: 12) {
                        Text(String(localized: "minutes"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 12) {
                            Button {
                                decreaseMinutes()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cyan)
                            }

                            Text("\(selectedMinutes)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 40)

                            Button {
                                increaseMinutes()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // Boutons
            VStack(spacing: 8) {
                Button {
                    impactFeedback.impactOccurred()
                    onConfirm()
                    dismiss()
                } label: {
                    Text(String(localized: "confirm"))
                        .font(.system(size: 16, weight: .semibold))
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

    // MARK: - Control Methods

    private func increaseHours() {
        impactFeedback.impactOccurred()
        if selectedHours < 24 {
            selectedHours += 1
        }
    }

    private func decreaseHours() {
        impactFeedback.impactOccurred()
        if selectedHours > 0 {
            selectedHours -= 1
        }
    }

    private func increaseMinutes() {
        impactFeedback.impactOccurred()
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex < availableMinutes.count - 1 {
            selectedMinutes = availableMinutes[currentIndex + 1]
        } else if selectedMinutes == availableMinutes.last {
            selectedMinutes = 0
            if selectedHours < 24 {
                selectedHours += 1
            }
        }
    }

    private func decreaseMinutes() {
        impactFeedback.impactOccurred()
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            selectedMinutes = availableMinutes[currentIndex - 1]
        } else if selectedMinutes == 0 && selectedHours > 0 {
            selectedMinutes = availableMinutes.last ?? 55
            selectedHours -= 1
        }
    }
}

struct QuickDurationButton: View {
    let minutes: Int
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    let impactFeedback: UIImpactFeedbackGenerator

    private var label: String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h\(mins)"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)min"
        }
    }

    private var isSelected: Bool {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        return totalMinutes == minutes
    }

    var body: some View {
        Button {
            impactFeedback.impactOccurred()
            selectedHours = minutes / 60
            selectedMinutes = minutes % 60
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [.cyan.opacity(0.3), .blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [.white.opacity(0.1), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
