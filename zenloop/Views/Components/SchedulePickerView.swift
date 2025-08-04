//
//  SchedulePickerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 04/08/2025.
//

import SwiftUI

struct SchedulePickerView: View {
    @Binding var selectedTime: Date
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background cohérent avec le reste de l'app
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                        Color(red: 0.08, green: 0.02, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Description
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.cyan)
                        
                        VStack(spacing: 8) {
                            Text("Programmer le démarrage")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Choisissez quand commencer votre session")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
                    
                    // Date Picker personnalisé
                    VStack(spacing: 20) {
                        DatePicker(
                            "Heure de démarrage",
                            selection: $selectedTime,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.cyan.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Raccourcis rapides
                        VStack(spacing: 12) {
                            Text("Raccourcis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                QuickTimeButton(title: "Dans 5 min", minutes: 5, selectedTime: $selectedTime)
                                QuickTimeButton(title: "Dans 15 min", minutes: 15, selectedTime: $selectedTime)
                                QuickTimeButton(title: "Dans 30 min", minutes: 30, selectedTime: $selectedTime)
                                QuickTimeButton(title: "Dans 1 heure", minutes: 60, selectedTime: $selectedTime)
                            }
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Programmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirmer") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Quick Time Button

struct QuickTimeButton: View {
    let title: String
    let minutes: Int
    @Binding var selectedTime: Date
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            selectedTime = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .brightness(isPressed ? -0.1 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    SchedulePickerView(selectedTime: .constant(Date()))
}