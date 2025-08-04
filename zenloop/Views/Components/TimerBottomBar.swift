//
//  TimerBottomBar.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct TimerBottomBar: View {
    @ObservedObject var zenloopManager: ZenloopManager
    @State private var selectedMinutes: Int = 25
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var hasSelectedApps = false
    @State private var selectedConcentrationType: ConcentrationType = .deep
    @State private var showingConcentrationPicker = false
    
    private let availableMinutes = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    private let recentDurations = [25, 45, 60] // Durées populaires
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Ligne 1: Type de concentration
                HStack(spacing: 12) {
                    // Sélecteur de type de concentration
                    Button {
                        showingConcentrationPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedConcentrationType.icon)
                                .font(.system(size: 12))
                                .foregroundColor(selectedConcentrationType.primaryColor)
                            
                            Text(selectedConcentrationType.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedConcentrationType.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Durées suggérées pour ce type
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(selectedConcentrationType.suggestedDurations, id: \.self) { minutes in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMinutes = minutes
                                    }
                                } label: {
                                    Text("\(minutes)m")
                                        .font(.system(size: 10, weight: selectedMinutes == minutes ? .bold : .medium))
                                        .foregroundColor(selectedMinutes == minutes ? .black : .white.opacity(0.7))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(selectedMinutes == minutes ? selectedConcentrationType.accentColor : .clear)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: 140)
                }
                
                // Ligne 2: Apps et Start
                HStack(spacing: 12) {
                    // Sélection d'apps
                    Button {
                        showingAppSelection = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hasSelectedApps ? "checkmark.shield.fill" : "shield")
                                .font(.system(size: 12))
                                .foregroundColor(hasSelectedApps ? .green : .white.opacity(0.6))
                            
                            Text(hasSelectedApps ? "\(selectedApps.applications.count) apps" : "Choisir apps")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(hasSelectedApps ? .green.opacity(0.3) : .white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Bouton de démarrage avec couleur du type
                    Button(action: startCustomChallenge) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .medium))
                            
                            Text("Commencer")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedConcentrationType.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: selectedConcentrationType.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(zenloopManager.currentState != .idle || !hasSelectedApps)
                    .opacity(zenloopManager.currentState == .idle && hasSelectedApps ? 1.0 : 0.6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 0.5),
                alignment: .top
            )
        }
        .sheet(isPresented: $showingConcentrationPicker) {
            ConcentrationTypePickerView(selectedType: $selectedConcentrationType)
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            hasSelectedApps = !newSelection.applications.isEmpty || !newSelection.categories.isEmpty
        }
        .onChange(of: selectedConcentrationType) { _, newType in
            // Ajuster le temps sélectionné aux durées suggérées
            if !newType.suggestedDurations.contains(selectedMinutes) {
                selectedMinutes = newType.suggestedDurations.first ?? 25
            }
        }
    }
    
    // MARK: - Actions
    
    private func decreaseTime() {
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            withAnimation(.spring()) {
                selectedMinutes = availableMinutes[currentIndex - 1]
            }
        }
    }
    
    private func increaseTime() {
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex < availableMinutes.count - 1 {
            withAnimation(.spring()) {
                selectedMinutes = availableMinutes[currentIndex + 1]
            }
        }
    }
    
    private func startCustomChallenge() {
        // Vérifier qu'au moins une app est sélectionnée
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            print("⚠️ [TIMER_BOTTOM_BAR] Aucune app sélectionnée")
            return
        }
        
        // Sauvegarder dans les récents
        saveRecentDuration(selectedMinutes)
        
        // Démarrer le défi personnalisé avec le type de concentration
        zenloopManager.startCustomChallenge(
            title: selectedConcentrationType.title,
            duration: TimeInterval(selectedMinutes * 60),
            difficulty: getDifficultyFromType(selectedConcentrationType),
            apps: selectedApps
        )
    }
    
    private func getDifficultyFromType(_ type: ConcentrationType) -> DifficultyLevel {
        switch type {
        case .meditation: return .easy
        case .creative, .study, .work: return .medium
        case .deep: return .hard
        }
    }
    
    private func saveRecentDuration(_ minutes: Int) {
        var recents = UserDefaults.standard.array(forKey: "recent_durations") as? [Int] ?? []
        
        // Supprimer si déjà présent
        recents.removeAll { $0 == minutes }
        
        // Ajouter au début
        recents.insert(minutes, at: 0)
        
        // Garder seulement les 5 derniers
        if recents.count > 5 {
            recents = Array(recents.prefix(5))
        }
        
        UserDefaults.standard.set(recents, forKey: "recent_durations")
    }
}



#Preview {
    TimerBottomBar(zenloopManager: ZenloopManager.shared)
        .background(Color.black)
}