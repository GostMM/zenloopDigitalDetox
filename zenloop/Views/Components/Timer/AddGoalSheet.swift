//
//  AddGoalSheet.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct AddGoalSheet: View {
    @State private var goalText = ""
    let onAdd: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(String(localized: "add_goal"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)

            // TextField
            TextField(String(localized: "goal_placeholder"), text: $goalText)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    if !goalText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAdd(goalText)
                    }
                }

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(String(localized: "cancel"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }

                Button {
                    if !goalText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAdd(goalText)
                    }
                } label: {
                    Text(String(localized: "add"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: goalText.isEmpty ? [.gray.opacity(0.5)] : [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(goalText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
        .onAppear {
            // Focus automatique sur le TextField
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}
