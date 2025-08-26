//
//  SchedulePickerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 04/08/2025.
//

import SwiftUI

struct SchedulePickerView: View {
    @Binding var selectedTime: Date
    let onScheduleConfirmed: ((Date, Int) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var selectedPreset: SchedulePreset? = nil
    @State private var isCustomTime = false
    @State private var selectedEndTime: Date = Date()
    @State private var selectedDuration: Int = 25 // minutes par défaut
    @State private var showConfirmation = false
    @State private var confirmationScale: CGFloat = 1.0
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Sélection active EN HAUT (toujours visible)
                        VStack(spacing: 16) {
                            // Header compact avec indicateur de session en attente
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.cyan)
                                    
                                    Text("Programmer votre session")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                // Indicateur de sessions programmées existantes
                                if selectedPreset != nil || isCustomTime {
                                    SchedulePendingIndicator()
                                }
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
                            
                            // Card de sélection active (toujours visible)
                            if let preset = selectedPreset {
                                SelectedScheduleCard(
                                    preset: preset, 
                                    selectedTime: selectedTime, 
                                    selectedDuration: selectedDuration,
                                    onDurationChanged: { newDuration in
                                        selectedDuration = newDuration
                                        updateEndTime()
                                    }
                                )
                                .opacity(showContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            } else if isCustomTime {
                                CustomScheduleCard(
                                    selectedTime: selectedTime, 
                                    selectedDuration: selectedDuration,
                                    onDurationChanged: { newDuration in
                                        selectedDuration = newDuration
                                        updateEndTime()
                                    }
                                )
                                .opacity(showContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            } else {
                                // État initial - encourager à sélectionner
                                HStack(spacing: 12) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.cyan)
                                    
                                    Text("Choisissez votre créneau ci-dessous")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    .ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.cyan.opacity(0.2), lineWidth: 1)
                                )
                                .opacity(showContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            }
                        }
                        
                        // Presets rapides améliorés
                        VStack(spacing: 16) {
                            HStack {
                                Text("Programmer pour")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer()
                                
                                if selectedPreset != nil || isCustomTime {
                                    Button("Changer") {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            selectedPreset = nil
                                            isCustomTime = false
                                        }
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.cyan)
                                }
                            }
                            
                            let presets = SchedulePreset.quickPresets
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(presets, id: \.title) { preset in
                                    SchedulePresetCard(
                                        preset: preset,
                                        isSelected: selectedPreset?.title == preset.title,
                                        action: {
                                            selectPreset(preset)
                                        }
                                    )
                                }
                                
                                // Bouton personnalisé
                                CustomTimeButton(
                                    isSelected: isCustomTime,
                                    action: {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            selectedPreset = nil
                                            isCustomTime = true
                                        }
                                    }
                                )
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.25), value: showContent)
                        
                        // Sélecteur personnalisé (si activé)
                        if isCustomTime {
                            VStack(spacing: 16) {
                                DatePicker(
                                    "Heure personnalisée",
                                    selection: $selectedTime,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .padding(20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.cyan.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                
                // Overlay de confirmation
                if showConfirmation {
                    ConfirmationOverlay()
                        .scaleEffect(confirmationScale)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: confirmationScale)
                        .animation(.easeInOut(duration: 0.3), value: showConfirmation)
                }
            }
            .navigationTitle(String(localized: "programming"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "confirm")) {
                        confirmSchedule()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                    .disabled(selectedPreset == nil && !isCustomTime)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
    
    private func selectPreset(_ preset: SchedulePreset) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedPreset = preset
            isCustomTime = false
            selectedTime = preset.calculateTime()
            selectedDuration = preset.defaultDuration
            updateEndTime()
        }
    }
    
    private func updateEndTime() {
        selectedEndTime = Calendar.current.date(byAdding: .minute, value: selectedDuration, to: selectedTime) ?? selectedTime
    }
    
    private func confirmSchedule() {
        // Triple feedback haptique pour un effet "satisfaisant"
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Feedback de notification de succès
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
        
        // Animation visuelle de confirmation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showConfirmation = true
            confirmationScale = 0.8
        }
        
        // Scale up effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                confirmationScale = 1.2
            }
        }
        
        // Appeler le callback avec les données de programmation
        onScheduleConfirmed?(selectedTime, selectedDuration)
        
        // Fermeture avec délai pour voir l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfirmation = false
            }
            
            // Fermer la vue après l'animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Models and Views

struct SchedulePreset {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let minutesFromNow: Int?
    let specificTime: (hour: Int, minute: Int)?
    let defaultDuration: Int // durée par défaut en minutes
    
    func calculateTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        if let minutes = minutesFromNow {
            return calendar.date(byAdding: .minute, value: minutes, to: now) ?? now
        } else if let specific = specificTime {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = specific.hour
            components.minute = specific.minute
            
            if let scheduledDate = calendar.date(from: components) {
                // Si l'heure est passée aujourd'hui, programmer pour demain
                if scheduledDate < now {
                    return calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? now
                }
                return scheduledDate
            }
        }
        
        return now
    }
    
    static let quickPresets: [SchedulePreset] = [
        SchedulePreset(
            title: "Dans 5 min",
            subtitle: "Démarrage rapide",
            icon: "bolt.fill",
            color: .orange,
            minutesFromNow: 5,
            specificTime: nil,
            defaultDuration: 15 // session courte
        ),
        SchedulePreset(
            title: "Dans 15 min",
            subtitle: "Court délai",
            icon: "timer",
            color: .cyan,
            minutesFromNow: 15,
            specificTime: nil,
            defaultDuration: 25 // pomodoro classique
        ),
        SchedulePreset(
            title: "Dans 1h",
            subtitle: "Plus tard",
            icon: "clock.arrow.circlepath",
            color: .purple,
            minutesFromNow: 60,
            specificTime: nil,
            defaultDuration: 45 // session moyenne
        ),
        SchedulePreset(
            title: "Ce soir 20h",
            subtitle: "Routine du soir",
            icon: "moon.stars.fill",
            color: .indigo,
            minutesFromNow: nil,
            specificTime: (20, 0),
            defaultDuration: 60 // session du soir
        ),
        SchedulePreset(
            title: "Demain 9h",
            subtitle: "Matinée productive",
            icon: "sun.max.fill",
            color: .yellow,
            minutesFromNow: nil,
            specificTime: (9, 0),
            defaultDuration: 90 // session longue matinale
        ),
        SchedulePreset(
            title: "Pause déj 12h",
            subtitle: "Concentration midi",
            icon: "fork.knife",
            color: .green,
            minutesFromNow: nil,
            specificTime: (12, 0),
            defaultDuration: 30 // pause déjeuner
        )
    ]
}

struct SchedulePresetCard: View {
    let preset: SchedulePreset
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icône avec fond coloré
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(preset.color.opacity(isSelected ? 0.3 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(preset.color)
                }
                
                VStack(spacing: 2) {
                    Text(preset.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(preset.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? preset.color.opacity(0.4) : .white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct CustomTimeButton: View {
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icône personnalisée
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text("Personnalisé")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Votre heure")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.3) : .white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct SelectedScheduleCard: View {
    let preset: SchedulePreset
    let selectedTime: Date
    let selectedDuration: Int
    let onDurationChanged: (Int) -> Void
    
    private var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: selectedDuration, to: selectedTime) ?? selectedTime
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // En-tête avec les heures de début et fin
            HStack(spacing: 12) {
                // Icône de statut
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(preset.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: preset.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(preset.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        // Début
                        HStack(spacing: 4) {
                            Text("De")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatTime(selectedTime))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(preset.color)
                        }
                        
                        // Flèche
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        // Fin
                        HStack(spacing: 4) {
                            Text("à")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatTime(endTime))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Sélecteur de durée
            DurationSelector(
                selectedDuration: selectedDuration,
                color: preset.color,
                onChange: onDurationChanged
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(preset.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CustomScheduleCard: View {
    let selectedTime: Date
    let selectedDuration: Int
    let onDurationChanged: (Int) -> Void
    
    private var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: selectedDuration, to: selectedTime) ?? selectedTime
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // En-tête avec les heures de début et fin
            HStack(spacing: 12) {
                // Icône de statut
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heure personnalisée")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        // Début
                        HStack(spacing: 4) {
                            Text("De")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatTime(selectedTime))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        
                        // Flèche
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        // Fin
                        HStack(spacing: 4) {
                            Text("à")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(formatTime(endTime))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Sélecteur de durée
            DurationSelector(
                selectedDuration: selectedDuration,
                color: .white,
                onChange: onDurationChanged
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 2)
                )
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Duration Selector

struct DurationSelector: View {
    let selectedDuration: Int
    let color: Color
    let onChange: (Int) -> Void
    
    private let availableDurations = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600, 720, 1440]
    
    var body: some View {
        VStack(spacing: 12) {
            // Header avec durée actuelle
            HStack {
                Text("Durée")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatDuration(selectedDuration))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Sélecteur de durée avec boutons rapides
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableDurations, id: \.self) { duration in
                        DurationButton(
                            duration: duration,
                            isSelected: duration == selectedDuration,
                            color: color,
                            action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                onChange(duration)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes / 60)h \(minutes % 60)min"
        }
    }
}

struct DurationButton: View {
    let duration: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(formatDuration(duration))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? color : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? color.opacity(0.5) : .white.opacity(0.1), lineWidth: 1)
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)min"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes / 60)h\(minutes % 60)"
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

// MARK: - Schedule Pending Indicator

struct SchedulePendingIndicator: View {
    @State private var isPulsing = false
    @State private var isGlowing = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Dot animé
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .shadow(color: .orange, radius: isGlowing ? 4 : 2)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isGlowing
                )
            
            Text("EN ATTENTE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.orange)
                .opacity(isPulsing ? 0.8 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.orange.opacity(0.4), lineWidth: 1)
                )
        )
        .onAppear {
            isPulsing = true
            isGlowing = true
        }
    }
}

// MARK: - Confirmation Overlay

struct ConfirmationOverlay: View {
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Card de confirmation
            VStack(spacing: 20) {
                // Icône de succès avec animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .green.opacity(0.4), radius: 20, x: 0, y: 8)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: UUID())
                
                VStack(spacing: 8) {
                    Text("Session programmée !")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Vous recevrez une notification\nau moment de commencer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .opacity(1.0)
                .animation(.easeIn(duration: 0.3).delay(0.2), value: UUID())
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
}

#Preview {
    SchedulePickerView(
        selectedTime: .constant(Date()),
        onScheduleConfirmed: { startTime, duration in
            print("Preview: Session programmée pour \(startTime) pendant \(duration) minutes")
        }
    )
}