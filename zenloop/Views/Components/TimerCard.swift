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
    @State private var isExpanded = false // Nouvel état pour l'expansion
    
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
            return String(localized: "today_at", defaultValue: "Today at \(timeString)", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: timeString)
        } else if calendar.isDate(scheduledStartTime, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            return String(localized: "tomorrow_at", defaultValue: "Tomorrow at \(timeString)", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: timeString)
        } else {
            // Use locale-specific date formatting for other dates
            formatter.dateStyle = .short
            formatter.timeStyle = .short
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
            return String(localized: "schedule_your_moment")
        }
        
        if !hasSelectedApps {
            return String(localized: "first_choose_distractions")
        }
        
        return String(localized: "lets_go")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Vue compacte (toujours visible)
            compactView
            
            // Vue détaillée (expandable)
            if isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 24 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.25), value: showContent)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
        .sheet(isPresented: $showingConcentrationPicker) {
            ConcentrationTypePickerView(selectedType: $selectedConcentrationType)
        }
        .sheet(isPresented: $showingSchedulePicker) {
            SchedulePickerView(selectedTime: $scheduledStartTime)
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { oldSelection, newSelection in
            // Une sélection est valide si elle contient des apps individuelles OU des catégories
            // Les catégories contiennent implicitement plusieurs applications
            let oldHasSelectedApps = hasSelectedApps
            hasSelectedApps = !newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty
            
            print("🔍 [TIMER_CARD] Selection changed:")
            print("  - Old: Apps=\(oldSelection.applicationTokens.count), Categories=\(oldSelection.categoryTokens.count)")
            print("  - New: Apps=\(newSelection.applicationTokens.count), Categories=\(newSelection.categoryTokens.count)")
            print("  - HasSelectedApps: \(oldHasSelectedApps) -> \(hasSelectedApps)")
            
            zenloopManager.updateAppsSelectionWithDetails(newSelection)
        }
        .onAppear {
            // Charger la sélection existante
            selectedApps = zenloopManager.getAppsSelection()
            // Vérifier si la sélection est réellement valide
            // Une sélection est valide si elle contient des apps individuelles OU des catégories
            hasSelectedApps = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
            
            print("🔍 [TIMER_CARD] OnAppear - Apps: \(selectedApps.applicationTokens.count), Categories: \(selectedApps.categoryTokens.count), HasSelectedApps: \(hasSelectedApps), ManagerCount: \(zenloopManager.selectedAppsCount)")
            
            // Mettre à jour le gestionnaire si la sélection est incohérente
            if !hasSelectedApps && zenloopManager.selectedAppsCount > 0 {
                print("⚠️ [TIMER_CARD] Incohérence détectée - reset de la sélection du manager")
                zenloopManager.updateAppsSelection(FamilyActivitySelection())
            }
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            VStack(spacing: 16) {
                // Première ligne : Titre et Status
                HStack(spacing: 12) {
                    // Icône de type de concentration plus moderne
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        selectedConcentrationType.primaryColor.opacity(0.3),
                                        selectedConcentrationType.primaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: selectedConcentrationType.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(selectedConcentrationType.primaryColor)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedConcentrationType.primaryColor.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Titre et status
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "take_your_time"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Status badge
                        HStack(spacing: 4) {
                            if hasSelectedApps {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text(String(localized: "everything_ready"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                
                                Text(String(localized: "select_apps"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Bouton expand/collapse
                    VStack(spacing: 2) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(isExpanded ? String(localized: "less") : String(localized: "more"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Deuxième ligne : Détails de la session
                HStack(spacing: 20) {
                    // Type de concentration
                    HStack(spacing: 6) {
                        Image(systemName: selectedConcentrationType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(selectedConcentrationType.primaryColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                          
                            
                            Text(selectedConcentrationType.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Durée
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        VStack(alignment: .leading, spacing: 2) {
                          
                            
                            Text(formattedDuration)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Apps sélectionnées
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                        
                        VStack(alignment: .leading, spacing: 2) {
                          
                            
                            Text(hasSelectedApps ? "\(zenloopManager.selectedAppsCount)" : "0")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(hasSelectedApps ? .cyan : .white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                }
                
                // Troisième ligne : Bouton d'action (si apps sélectionnées)
                if hasSelectedApps && zenloopManager.currentState == .idle {
                    HStack {
                        Button(action: startSession) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(String(localized: "start_session"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [selectedConcentrationType.primaryColor, selectedConcentrationType.accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .onTapGesture {
                            // Empêcher la propagation vers le bouton parent
                        }
                    }
                }
                
                // Apps sélectionnées preview (si présentes et mode compact)
                if hasSelectedApps && !isExpanded {
                    selectedAppsPreview
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Apps Preview
    
    private var selectedAppsPreview: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
                
                Text(String(localized: "apps_blocked"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Mini aperçu des apps et catégories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Afficher les applications individuelles d'abord
                    let maxAppsToShow = 3
                    let apps = Array(selectedApps.applicationTokens.prefix(maxAppsToShow))
                    ForEach(apps, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    // Afficher les catégories sélectionnées
                    let maxCategoriesToShow = 2
                    let categories = Array(selectedApps.categoryTokens.prefix(maxCategoriesToShow))
                    ForEach(categories, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.purple.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    // Compteur si plus d'éléments
                    let totalItems = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
                    let displayedItems = min(apps.count + categories.count, maxAppsToShow + maxCategoriesToShow)
                    
                    if totalItems > displayedItems {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .frame(width: 24, height: 24)
                            
                            Text("+\(totalItems - displayedItems)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.cyan.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(spacing: 16) {
            Divider()
                .background(.white.opacity(0.1))
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                // Type de concentration
                HStack {
                    Text(String(localized: "type"))
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
                            Text(String(localized: "minutes"))
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
                        Text(String(localized: "apps_to_block"))
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
                                
                                Text(hasSelectedApps ? String(localized: "modify") : String(localized: "select"))
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
                        SelectedAppsView(selection: selectedApps, maxDisplayCount: 4)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.3), value: hasSelectedApps)
                    }
                }
                
                // Programmation (optionnel)
                VStack(spacing: 12) {
                    HStack {
                        Text(String(localized: "scheduling"))
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
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
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