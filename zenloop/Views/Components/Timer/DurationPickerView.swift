//
//  DurationPickerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct DurationPickerView: View {
    let selectedConcentrationType: ConcentrationType
    let formattedDuration: String
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    let onIncreaseHours: () -> Void
    let onDecreaseHours: () -> Void
    let onIncreaseMinutes: () -> Void
    let onDecreaseMinutes: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "duration"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(formattedDuration)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(selectedConcentrationType.primaryColor)
            }

            // Sélecteurs heures et minutes
            HStack(spacing: 16) {
                // Heures
                VStack(spacing: 8) {
                    Text(String(localized: "hours"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 8) {
                        Button(action: onDecreaseHours) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedConcentrationType.primaryColor)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }

                        Text("\(selectedHours)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 30)

                        Button(action: onIncreaseHours) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedConcentrationType.primaryColor)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }

                // Minutes
                VStack(spacing: 8) {
                    Text(String(localized: "minutes"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 8) {
                        Button(action: onDecreaseMinutes) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedConcentrationType.primaryColor)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }

                        Text("\(selectedMinutes)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 30)

                        Button(action: onDecreaseMinutes) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(selectedConcentrationType.primaryColor)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
            }
        }
    }
}
