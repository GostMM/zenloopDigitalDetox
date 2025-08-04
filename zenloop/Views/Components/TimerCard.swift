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
    @State private var selectedConcentrationType: ConcentrationType = .deep
    @State private var showingConcentrationPicker = false
    @State private var isScheduled = false
    @State private var scheduledStartTime = Date()
    @State private var showingSchedulePicker = false
    
    private let availableMinutes = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    private let availableHours = Array(0...24)
    private let quickDurations = [15, 25, 45, 60, 90, 120, 180, 300, 480, 720, 1440] // jusqu'à 24h
    
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
    
    private var formatScheduledTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: scheduledStartTime)
        
        let calendar = Calendar.current
        if calendar.isDate(scheduledStartTime, inSameDayAs: Date()) {
            return "Aujourd'hui à \(timeString)"
        } else if calendar.isDate(scheduledStartTime, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            return "Demain à \(timeString)"
        } else {
            formatter.dateFormat = "dd/MM à HH:mm"
            return formatter.string(from: scheduledStartTime)
        }
    }
    
    private var buttonIsEnabled: Bool {
        // Toujours permettre si c'est programmé (l'utilisateur sélectionnera les apps plus tard)
        if isScheduled {
            return zenloopManager.currentState == .idle
        }
        // Pour les sessions immédiates, exiger des apps sélectionnées
        return hasSelectedApps && zenloopManager.currentState == .idle
    }
    
    private var buttonText: String {
        if isScheduled {
            return "Programmer la Session"
        }
        
        if !hasSelectedApps {
            return "Sélectionner des apps d'abord"
        }
        
        return "Commencer Maintenant"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête de la carte
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nouvelle Session")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Configure ton temps de concentration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Type de concentration
                HStack {
                    Text("Type")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button {
                        showingConcentrationPicker = true
                    } label: {
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
                
                // Sélecteur de durée avec heures/minutes
                VStack(spacing: 12) {
                    HStack {
                        Text("Durée")
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
                            Text("Heures")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 8) {
                                Button {
                                    decreaseHours()
                                } label: {
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
                                
                                Button {
                                    increaseHours()
                                } label: {
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
                            Text("Minutes")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 8) {
                                Button {
                                    decreaseMinutes()
                                } label: {
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
                                
                                Button {
                                    increaseMinutes()
                                } label: {
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
                
                // Applications à bloquer
                VStack(spacing: 12) {
                    HStack {
                        Text("Apps à bloquer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Button {
                            showingAppSelection = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: hasSelectedApps ? "plus.circle.fill" : "plus.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(hasSelectedApps ? .cyan : .white.opacity(0.7))
                                
                                Text(hasSelectedApps ? "Modifier" : "Sélectionner")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke((hasSelectedApps ? Color.cyan : Color.white).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Affichage des apps sélectionnées
                    if hasSelectedApps {
                        SelectedAppsView(selection: selectedApps, maxDisplayCount: 6)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.3), value: hasSelectedApps)
                    }
                }
                
                // Programmation (optionnel)
                VStack(spacing: 12) {
                    HStack {
                        Text("Programmation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Toggle("", isOn: $isScheduled)
                            .scaleEffect(0.8)
                            .tint(selectedConcentrationType.primaryColor)
                    }
                    
                    if isScheduled {
                        Button {
                            showingSchedulePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedConcentrationType.primaryColor)
                                
                                Text(formatScheduledTime)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedConcentrationType.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: isScheduled)
                    }
                }
                
                // Bouton de démarrage/programmation
                Button {
                    if buttonIsEnabled {
                        startSession()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isScheduled ? "clock.arrow.circlepath" : "play.fill")
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
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.25), value: showContent)
        .sheet(isPresented: $showingConcentrationPicker) {
            ConcentrationTypePickerView(selectedType: $selectedConcentrationType)
        }
        .sheet(isPresented: $showingSchedulePicker) {
            SchedulePickerView(selectedTime: $scheduledStartTime)
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            hasSelectedApps = !newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty
            zenloopManager.updateAppsSelectionWithDetails(newSelection)
        }
        .onAppear {
            // Charger la sélection existante
            selectedApps = zenloopManager.getAppsSelection()
            // Vérifier si la sélection est réellement valide (pas juste le count)
            hasSelectedApps = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
            
            // Mettre à jour le gestionnaire si la sélection est vide mais le count > 0
            if hasSelectedApps == false && zenloopManager.selectedAppsCount > 0 {
                zenloopManager.updateAppsSelection(FamilyActivitySelection())
            }
        }
    }
    
    private func increaseTime() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex < availableMinutes.count - 1 {
            selectedMinutes = availableMinutes[currentIndex + 1]
        }
    }
    
    private func decreaseTime() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            selectedMinutes = availableMinutes[currentIndex - 1]
        }
    }
    
    // MARK: - Control Methods
    
    private func increaseHours() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedHours < 24 {
            selectedHours += 1
        }
    }
    
    private func decreaseHours() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedHours > 0 {
            selectedHours -= 1
        }
    }
    
    private func increaseMinutes() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex < availableMinutes.count - 1 {
            selectedMinutes = availableMinutes[currentIndex + 1]
        }
    }
    
    private func decreaseMinutes() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            selectedMinutes = availableMinutes[currentIndex - 1]
        }
    }
    
    private func startSession() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        let totalMinutes = selectedHours * 60 + selectedMinutes
        
        if isScheduled {
            print("📅 [TIMER_CARD] Programmation session: \(selectedConcentrationType.title), \(formattedDuration) à \(formatScheduledTime)")
            // TODO: Implémenter la programmation différée
            // Pour l'instant, on démarre immédiatement
        }
        
        print("🚀 [TIMER_CARD] Démarrage session: \(selectedConcentrationType.title), \(formattedDuration)")
        
        let title = "\(selectedConcentrationType.title) - \(formattedDuration)"
        let duration = TimeInterval(totalMinutes * 60)
        let difficulty: DifficultyLevel = totalMinutes <= 20 ? .easy : totalMinutes <= 60 ? .medium : .hard
        
        if hasSelectedApps {
            zenloopManager.startCustomChallenge(
                title: title,
                duration: duration,
                difficulty: difficulty,
                apps: selectedApps
            )
        } else {
            zenloopManager.startQuickChallenge(duration: duration)
        }
    }
}

#Preview {
    TimerCard(zenloopManager: ZenloopManager.shared, showContent: true)
        .background(Color.black)
}