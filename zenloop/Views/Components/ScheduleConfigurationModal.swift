//
//  ScheduleConfigurationModal.swift
//  zenloop
//
//  Created by Claude on 27/08/2025.
//

import SwiftUI
import FamilyControls
#if canImport(UIKit)
import UIKit
#endif

struct ScheduleConfigurationModal: View {
    let session: PopularSession
    @ObservedObject var zenloopManager: ZenloopManager
    let initialAppsSelection: FamilyActivitySelection
    let onAppsSelected: (FamilyActivitySelection) -> Void
    let onAppsClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStartTime = Date()
    @State private var selectedFrequency: ScheduleFrequency = .once
    @State private var selectedDays: Set<Weekday> = []
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showContent = false
    @State private var isAppearing = false
    @State private var hasInitialized = false
    
    init(session: PopularSession, 
         zenloopManager: ZenloopManager, 
         initialAppsSelection: FamilyActivitySelection,
         onAppsSelected: @escaping (FamilyActivitySelection) -> Void,
         onAppsClear: @escaping () -> Void) {
        self.session = session
        self.zenloopManager = zenloopManager
        self.initialAppsSelection = initialAppsSelection
        self.onAppsSelected = onAppsSelected
        self.onAppsClear = onAppsClear
        
        // Initialiser l'état pour affichage immédiat
        self._showContent = State(initialValue: true)
        self._hasInitialized = State(initialValue: true)
        
        print("🚀 [MODAL] Init pour session: \(session.sessionId) - showContent: true")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background moderne avec dégradé
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.12),
                            Color(red: 0.06, green: 0.03, blue: 0.15),
                            Color(red: 0.08, green: 0.02, blue: 0.18),
                            Color(red: 0.04, green: 0.08, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Overlay subtil
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    session.accentColor.color.opacity(0.1),
                                    .clear
                                ],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                }
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header avec session info
                        sessionHeaderSection
                        
                        // Configuration du planning
                        scheduleConfigurationSection
                        
                        // Sélection des apps
                        appSelectionSection
                        
                        // Boutons d'action
                        actionButtonsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(String(localized: "schedule_session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
            .onAppear {
                print("🔄 [MODAL] onAppear pour session: \(session.sessionId)")
                print("🔄 [MODAL] hasInitialized: \(hasInitialized), showContent: \(showContent)")
                
                // Toujours réinitialiser à l'ouverture pour garantir l'affichage
                isAppearing = true
                
                // Initialisation immédiate des données
                selectedStartTime = calculateNextOptimalTime()
                selectedApps = initialAppsSelection
                
                print("🎯 [MODAL] Données initialisées pour '\(session.title)'")
                print("   - Apps sélectionnées: \(selectedApps.applicationTokens.count + selectedApps.categoryTokens.count)")
                
                // Forcer l'affichage immédiat sans délai
                showContent = true
                hasInitialized = true
                
                print("✨ [MODAL] Contenu affiché immédiatement")
            }
            .onDisappear {
                print("👋 [MODAL] onDisappear")
                isAppearing = false
                // NE PAS réinitialiser hasInitialized et showContent ici
                // Cela permet de garder l'état pour les prochaines ouvertures
            }
            .onChange(of: selectedApps) { oldSelection, newSelection in
                // Sauvegarder la sélection pour cette session spécifique
                onAppsSelected(newSelection)
            }
            .onChange(of: session.sessionId) { oldSessionId, newSessionId in
                // Réinitialiser l'état quand on change de session
                print("🔄 [MODAL] Session changée: \(oldSessionId) -> \(newSessionId)")
                hasInitialized = false
                showContent = false
                
                // Réinitialiser les données pour la nouvelle session
                DispatchQueue.main.async {
                    selectedStartTime = calculateNextOptimalTime()
                    selectedApps = initialAppsSelection
                    showContent = true
                    hasInitialized = true
                    print("✅ [MODAL] Nouvelle session initialisée")
                }
            }
        }
    }
    
    // MARK: - Session Header Section
    
    private var sessionHeaderSection: some View {
        VStack(spacing: 16) {
            // Icône de la session
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                session.accentColor.color.opacity(0.3),
                                session.accentColor.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: session.iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(session.accentColor.color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(session.accentColor.color.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: session.accentColor.color.opacity(0.3), radius: 12, x: 0, y: 6)
            
            VStack(spacing: 8) {
                Text(session.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(session.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }
    
    // MARK: - Schedule Configuration Section
    
    private var scheduleConfigurationSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(String(localized: "schedule_configuration"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Sélection de l'heure de début
                startTimeSelectionRow
                
                // Sélection de la fréquence
                frequencySelectionRow
                
                // Sélection des jours (si récurrent)
                if selectedFrequency == .weekly {
                    weekdaySelectionRow
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.accentColor.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }
    
    private var startTimeSelectionRow: some View {
        VStack(spacing: 12) {
            // Date de début
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)
                
                Text(String(localized: "start_date"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                DatePicker("", selection: $selectedStartTime, displayedComponents: [.date])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(session.accentColor.color)
            }
            
            // Heure de début  
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)
                
                Text(String(localized: "start_time"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                DatePicker("", selection: $selectedStartTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(session.accentColor.color)
            }
        }
    }
    
    private var frequencySelectionRow: some View {
        HStack {
            Image(systemName: "repeat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(session.accentColor.color)
                .frame(width: 24)
            
            Text(String(localized: "frequency"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.localizedName)
                        .tag(frequency)
                }
            }
            .pickerStyle(.menu)
            .accentColor(session.accentColor.color)
        }
    }
    
    private var weekdaySelectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)
                
                Text(String(localized: "repeat_on_days"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    WeekdayToggle(
                        day: day,
                        isSelected: selectedDays.contains(day),
                        accentColor: session.accentColor.color
                    ) {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.3), value: selectedFrequency)
    }
    
    // MARK: - App Selection Section
    
    private var appSelectionSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "apps_to_block"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Boutons alignés horizontalement
                HStack(spacing: 12) {
                    Button {
                        showingAppSelection = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: hasSelectedApps ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 14))
                                .foregroundColor(hasSelectedApps ? .green : session.accentColor.color)
                            
                            Text(hasSelectedApps ? String(localized: "modify") : String(localized: "select"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false) // Évite le word break
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((hasSelectedApps ? Color.green : session.accentColor.color).opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Bouton Clear seulement si des apps sont sélectionnées
                    if hasSelectedApps {
                        Button {
                            selectedApps = FamilyActivitySelection()
                            onAppsClear() // Notifier le parent pour effacer
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                
                                Text(String(localized: "clear"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: true, vertical: false) // Évite le word break
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // Affichage des apps sélectionnées
            if hasSelectedApps {
                appSelectionPreview
            } else {
                appSelectionPlaceholder
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.accentColor.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }
    
    private var appSelectionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                
                Text(String(localized: "selected_apps"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(selectedApps.applicationTokens.count + selectedApps.categoryTokens.count) \(String(localized: "items"))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            // Grille des vraies icônes d'apps sélectionnées
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                // Applications individuelles
                ForEach(Array(selectedApps.applicationTokens.prefix(12)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
                
                // Catégories
                ForEach(Array(selectedApps.categoryTokens.prefix(4)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                        .frame(width: 32, height: 32)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.purple.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var appSelectionPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.dashed")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Text(String(localized: "tap_to_select_apps"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                scheduleSession()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(String(localized: "schedule_session"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canSchedule ? 
                            [session.accentColor.color, session.accentColor.color.opacity(0.8)] :
                            [Color.gray.opacity(0.5), Color.gray.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(!canSchedule)
            .shadow(color: session.accentColor.color.opacity(0.3), radius: canSchedule ? 8 : 0, x: 0, y: 4)
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
        .premiumGated()
    }
    
    // MARK: - Computed Properties
    
    private var hasSelectedApps: Bool {
        !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
    }
    
    private var canSchedule: Bool {
        hasSelectedApps
    }
    
    // MARK: - Private Methods
    
    private func scheduleSession() {
        print("🗓️ [SCHEDULE_CONFIG] Tentative de programmation de '\(session.title)'")
        
        // Vérifier l'accès Premium via PremiumGatekeeper
        PremiumGatekeeper.shared.performIfAllowed(.startScheduledSession) {
            print("🗓️ [SCHEDULE_CONFIG] Programmation autorisée pour '\(session.title)'")
            print("   - Heure: \(selectedStartTime)")
            print("   - Fréquence: \(selectedFrequency)")
            print("   - Apps: \(selectedApps.applicationTokens.count)")
            print("   - Catégories: \(selectedApps.categoryTokens.count)")
            
            // Déterminer la difficulté selon la durée
            let difficulty: DifficultyLevel = {
                let hours = session.duration / 3600
                if hours >= 8 {
                    return .hard
                } else if hours >= 4 {
                    return .medium
                } else {
                    return .easy
                }
            }()
            
            // Pour l'instant, programmer une seule session
            // TODO: Implémenter la logique de fréquence répétée
            zenloopManager.scheduleCustomChallenge(
                title: session.title,
                duration: session.duration,
                difficulty: difficulty,
                apps: selectedApps,
                startTime: selectedStartTime
            )
            
            // Feedback haptique
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            #endif
            
            // Fermer le modal
            dismiss()
            
            print("✅ [SCHEDULE_CONFIG] Session programmée avec succès")
        }
    }
    
    private func calculateNextOptimalTime() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        let components = DateComponents(
            year: calendar.component(.year, from: tomorrow),
            month: calendar.component(.month, from: tomorrow),
            day: calendar.component(.day, from: tomorrow),
            hour: 8,
            minute: 0
        )
        
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Supporting Types

enum ScheduleFrequency: String, CaseIterable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    
    var localizedName: String {
        switch self {
        case .once:
            return String(localized: "once")
        case .daily:
            return String(localized: "daily")
        case .weekly:
            return String(localized: "weekly")
        }
    }
}

enum Weekday: String, CaseIterable {
    case monday = "monday"
    case tuesday = "tuesday" 
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    case sunday = "sunday"
    
    var localizedName: String {
        switch self {
        case .monday: return String(localized: "monday")
        case .tuesday: return String(localized: "tuesday")
        case .wednesday: return String(localized: "wednesday")
        case .thursday: return String(localized: "thursday")
        case .friday: return String(localized: "friday")
        case .saturday: return String(localized: "saturday")
        case .sunday: return String(localized: "sunday")
        }
    }
    
    var shortName: String {
        switch self {
        case .monday: return String(localized: "mon")
        case .tuesday: return String(localized: "tue")
        case .wednesday: return String(localized: "wed")
        case .thursday: return String(localized: "thu")
        case .friday: return String(localized: "fri")
        case .saturday: return String(localized: "sat")
        case .sunday: return String(localized: "sun")
        }
    }
}

// MARK: - Weekday Toggle

struct WeekdayToggle: View {
    let day: Weekday
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(day.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accentColor : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? accentColor : .white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview temporairement désactivé pour éviter les erreurs de compilation
/*
#Preview {
    ScheduleConfigurationModal(
        session: PopularSession(
            sessionId: "no_tiktok_8h",
            title: "No TikTok 8h",
            description: "Block TikTok and short videos", 
            duration: 8 * 60 * 60,
            iconName: "video.slash",
            imageName: "tiktok",
            accentColor: .pink,
            targetedApps: ["TikTok"],
            category: .socialMedia
        ),
        zenloopManager: ZenloopManager.shared,
        initialAppsSelection: FamilyActivitySelection(),
        onAppsSelected: { _ in },
        onAppsClear: { }
    )
}
*/