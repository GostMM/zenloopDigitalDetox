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
    @State private var isExpanded = false // Nouvel état pour l'expansion
    @State private var taskGoals: [(text: String, isCompleted: Bool)] = [] // Liste des objectifs avec état (max 5)
    @State private var showingAddGoal = false
    @State private var showingDifficultySelector = false // Modal pour choisir la difficulté
    @State private var selectedDifficulty: DifficultyLevel? = nil // nil = auto (basé sur durée)
    @StateObject private var gatekeeper = PremiumGatekeeper.shared

    // Suggestions d'objectifs prédéfinis
    private let goalSuggestions = [
        ("read_20_pages", "book.fill"),
        ("finish_report", "doc.text.fill"),
        ("meditate_10_min", "figure.mind.and.body"),
        ("complete_workout", "dumbbell.fill"),
        ("write_1000_words", "pencil.and.outline"),
        ("study_chapter", "graduationcap.fill")
    ]
    
    private let availableMinutes = [5, 10, 15, 20, 25, 30, 45, 55]
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
    
    
    private var buttonIsEnabled: Bool {
        // Pour les sessions immédiates, exiger des apps sélectionnées
        return hasSelectedApps && zenloopManager.currentState == .idle
    }
    
    private var buttonText: String {
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
        .sheet(isPresented: $showingDifficultySelector) {
            DifficultySelectionModal(
                selectedDifficulty: $selectedDifficulty,
                autoDifficulty: calculateAutoDifficulty(),
                onConfirm: {
                    showingDifficultySelector = false
                    confirmStartSession()
                }
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.hidden)
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
            // Vérifier et corriger les minutes si nécessaire
            if !availableMinutes.contains(selectedMinutes) {
                selectedMinutes = 25 // Valeur par défaut sûre
            }
            
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
        .premiumGated()
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
                        
                        // Status badges
                        VStack(alignment: .leading, spacing: 4) {
                            // Badge de sélection d'apps
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
                
                // Section Objectifs - Version compacte avec liste
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "target")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.5) : .yellow)

                        Text(String(localized: "goals"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))

                        if !taskGoals.isEmpty {
                            Text("\(taskGoals.count)/5")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.yellow.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.yellow.opacity(0.15))
                                )
                        }

                        Spacer()

                        if taskGoals.count < 5 {
                            Menu {
                                ForEach(goalSuggestions, id: \.0) { suggestion in
                                    Button {
                                        addGoal(String(localized: String.LocalizationValue(suggestion.0)))
                                    } label: {
                                        Label(String(localized: String.LocalizationValue(suggestion.0)), systemImage: suggestion.1)
                                    }
                                }

                                Divider()

                                Button {
                                    showingAddGoal = true
                                } label: {
                                    Label(String(localized: "custom_goal"), systemImage: "pencil")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(String(localized: "add"))
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.6) : .yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }

                    // Liste des objectifs
                    if !taskGoals.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(Array(taskGoals.enumerated()), id: \.offset) { index, goal in
                                HStack(spacing: 8) {
                                    // Checkbox interactive
                                    Button {
                                        toggleGoalCompletion(at: index)
                                    } label: {
                                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(goal.isCompleted ? .green : .yellow.opacity(0.6))
                                    }

                                    Text(goal.text)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(goal.isCompleted ? .white.opacity(0.5) : .white.opacity(0.9))
                                        .strikethrough(goal.isCompleted, color: .white.opacity(0.5))
                                        .lineLimit(1)

                                    Spacer()

                                    Button {
                                        removeGoal(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(goal.isCompleted ? .green.opacity(0.08) : .yellow.opacity(0.05))
                                )
                            }
                        }
                    } else {
                        Text(String(localized: "add_goal_optional"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(taskGoals.isEmpty ? .white.opacity(0.03) : .yellow.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(taskGoals.isEmpty ? .white.opacity(0.08) : .yellow.opacity(0.25), lineWidth: 1)
                        )
                )
                .sheet(isPresented: $showingAddGoal) {
                    AddGoalSheet(onAdd: { newGoal in
                        addGoal(newGoal)
                        showingAddGoal = false
                    }, onCancel: {
                        showingAddGoal = false
                    })
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
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
                
                // Bouton de démarrage
                Button {
                    if buttonIsEnabled {
                        startSession()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
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
        } else if selectedMinutes == availableMinutes.last {
            // Si on est au max des minutes (55), passer à 1h 00min
            selectedMinutes = 0
            selectedHours += 1
        }
    }
    
    private func decreaseMinutes() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let currentIndex = availableMinutes.firstIndex(of: selectedMinutes),
           currentIndex > 0 {
            selectedMinutes = availableMinutes[currentIndex - 1]
        } else if selectedMinutes == 0 && selectedHours > 0 {
            // Si on est à 0 minutes et qu'on a des heures, passer à l'heure précédente avec 55min
            selectedMinutes = availableMinutes.last ?? 55
            selectedHours -= 1
        }
    }
    
    // MARK: - Goal Management

    private func addGoal(_ goal: String) {
        guard taskGoals.count < 5 else { return }
        guard !goal.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
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
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            taskGoals[index].isCompleted.toggle()
        }
    }

    private func startSession() {
        // Vérifier si l'utilisateur peut lancer une session
        gatekeeper.performIfAllowed(.startCustomSession) {
            // Ouvrir le sélecteur de difficulté au lieu de démarrer directement
            showingDifficultySelector = true
        }
    }

    private func confirmStartSession() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        let totalMinutes = selectedHours * 60 + selectedMinutes

        let title = "\(selectedConcentrationType.title) - \(formattedDuration)"
        let duration = TimeInterval(totalMinutes * 60)

        // Utiliser la difficulté sélectionnée ou auto
        let difficulty: DifficultyLevel = selectedDifficulty ?? (totalMinutes <= 20 ? .easy : totalMinutes <= 60 ? .medium : .hard)

        print("🚀 [TIMER_CARD] Démarrage session: \(title), difficulté: \(difficulty.rawValue)")

        // Démarrer la session
        if hasSelectedApps {
            // Combiner tous les objectifs avec leurs statuts sur des lignes séparées
            let goalsString = taskGoals.isEmpty ? nil : taskGoals.map { goal in
                goal.isCompleted ? "✅ \(goal.text)" : "⭕️ \(goal.text)"
            }.joined(separator: "\n")

            zenloopManager.startCustomChallenge(
                title: title,
                duration: duration,
                difficulty: difficulty,
                apps: selectedApps,
                taskGoal: goalsString
            )
        } else {
            zenloopManager.startQuickChallenge(duration: duration, difficulty: difficulty)
        }

        // Réinitialiser la sélection
        selectedDifficulty = nil
    }
    
    private func calculateAutoDifficulty() -> DifficultyLevel {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        return totalMinutes <= 20 ? .easy : totalMinutes <= 60 ? .medium : .hard
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Difficulty Selection Modal

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
                            Text(difficulty.rawValue)
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

// MARK: - Add Goal Sheet

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

#Preview {
    TimerCard(zenloopManager: ZenloopManager.shared, showContent: true)
        .background(Color.black)
}