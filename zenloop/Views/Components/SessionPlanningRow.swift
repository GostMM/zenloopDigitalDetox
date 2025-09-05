//
//  SessionPlanningRow.swift
//  zenloop
//
//  Created by Claude on 27/08/2025.
//

import SwiftUI
import FamilyControls
import UIKit

struct SessionPlanningRow: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @State private var showingConfiguration = false
    @State private var showingScheduleModal = false
    @State private var selectedSession: PopularSession?
    @StateObject private var sessionPlanningManager = SessionPlanningManager.shared
    
    // Dictionnaire pour stocker les sélections d'apps par session
    @State private var sessionAppSelections: [String: FamilyActivitySelection] = [:]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header avec icône et titre
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.purple)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.purple.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(String(localized: "session_planning"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Badge compact pour sessions programmées
                        if zenloopManager.hasActiveScheduledSessions {
                            let count = getScheduledSessionsCount()
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(.cyan, in: Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(String(localized: "schedule_focus_sessions"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Indicateur de prochaine session avec icône
                        if let nextSession = zenloopManager.nextScheduledSession {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.cyan)
                                
                                Text(formatTime(nextSession.startTime))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Bouton config
                Button(action: {
                    showingConfiguration = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 12)
            
            // Sessions programmables populaires
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sessionPlanningManager.popularSessions) { session in
                        PopularSessionCard(
                            session: session,
                            hasAppsConfigured: hasAppsForSession(session.sessionId),
                            onSchedule: {
                                print("🎯 [SESSION_ROW] Ouverture modal pour session: \(session.sessionId)")
                                selectedSession = session
                                showingScheduleModal = true
                                print("✅ [SESSION_ROW] Modal state: selectedSession=\(selectedSession?.sessionId ?? "nil"), showingModal=\(showingScheduleModal)")
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, 12)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: showContent)
        .sheet(isPresented: $showingConfiguration) {
            NavigationView {
                SessionPlanningModal(zenloopManager: zenloopManager)
            }
        }
        .sheet(isPresented: $showingScheduleModal) {
            Group {
                if let session = selectedSession {
                    ScheduleConfigurationModal(
                        session: session, 
                        zenloopManager: zenloopManager,
                        initialAppsSelection: getAppsForSession(session.sessionId),
                        onAppsSelected: { apps in
                            saveAppsForSession(session.sessionId, apps: apps)
                        },
                        onAppsClear: {
                            clearAppsForSession(session.sessionId)
                        }
                    )
                    .onAppear {
                        print("📱 [SESSION_ROW] Sheet présentée pour session: \(session.sessionId)")
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Session non trouvée")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Button("Fermer") {
                            showingScheduleModal = false
                        }
                        .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .onAppear {
                        print("❌ [SESSION_ROW] Sheet présentée mais selectedSession est nil!")
                    }
                }
            }
        }
        .onAppear {
            sessionPlanningManager.refreshSessions()
            loadPersistedSelections()
        }
        .onChange(of: showingScheduleModal) { oldValue, newValue in
            print("🔄 [SESSION_ROW] showingScheduleModal changé: \(oldValue) -> \(newValue)")
            if !newValue {
                // Réinitialiser selectedSession quand le modal se ferme
                print("🔄 [SESSION_ROW] Modal fermé, réinitialisation selectedSession")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedSession = nil
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasAppsForSession(_ sessionId: String) -> Bool {
        if let selection = sessionAppSelections[sessionId] {
            return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        }
        return false
    }
    
    private func getAppsForSession(_ sessionId: String) -> FamilyActivitySelection {
        return sessionAppSelections[sessionId] ?? FamilyActivitySelection()
    }
    
    private func saveAppsForSession(_ sessionId: String, apps: FamilyActivitySelection) {
        // Sauvegarder en mémoire
        sessionAppSelections[sessionId] = apps
        
        // Persister dans App Group avec JSONEncoder (même méthode qu'AppRestrictionCoordinator)
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(apps)
                appGroup.set(data, forKey: "session_\(sessionId)_apps")
                appGroup.set(true, forKey: "session_\(sessionId)_configured")
                appGroup.synchronize()
                
                let count = apps.applicationTokens.count + apps.categoryTokens.count
                print("💾 [SESSION_ROW] Apps persistées pour session '\(sessionId)': \(count) éléments")
            } catch {
                print("❌ [SESSION_ROW] Erreur persistance pour '\(sessionId)': \(error)")
                // Marquer au moins comme configuré même si la sérialisation échoue
                appGroup.set(true, forKey: "session_\(sessionId)_configured")
                appGroup.synchronize()
            }
        }
    }
    
    private func loadPersistedSelections() {
        // Charger les configurations persistées avec JSONDecoder
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            for session in sessionPlanningManager.popularSessions {
                if let data = appGroup.data(forKey: "session_\(session.sessionId)_apps") {
                    do {
                        let decoder = JSONDecoder()
                        let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
                        sessionAppSelections[session.sessionId] = selection
                        
                        let count = selection.applicationTokens.count + selection.categoryTokens.count
                        print("📱 [SESSION_ROW] Apps chargées pour session '\(session.sessionId)': \(count) éléments")
                    } catch {
                        print("❌ [SESSION_ROW] Erreur chargement pour '\(session.sessionId)': \(error)")
                        // Garder une sélection vide si décodage échoue
                        sessionAppSelections[session.sessionId] = FamilyActivitySelection()
                    }
                } else if appGroup.bool(forKey: "session_\(session.sessionId)_configured") {
                    // Session marquée comme configurée mais pas de données - créer sélection vide
                    sessionAppSelections[session.sessionId] = FamilyActivitySelection()
                }
            }
        }
    }
    
    private func clearAppsForSession(_ sessionId: String) {
        // Effacer de la mémoire
        sessionAppSelections[sessionId] = nil
        
        // Effacer de la persistance
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            appGroup.removeObject(forKey: "session_\(sessionId)_apps")
            appGroup.removeObject(forKey: "session_\(sessionId)_configured")
            appGroup.synchronize()
        }
        
        print("🗑️ [SESSION_ROW] Apps effacées pour session: \(sessionId)")
    }
    
    private func getScheduledSessionsCount() -> Int {
        // Utiliser la méthode existante de ZenloopManager via BlockScheduler  
        return zenloopManager.hasActiveScheduledSessions ? 1 : 0
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
}

// MARK: - Popular Session Card

struct PopularSessionCard: View {
    let session: PopularSession
    let hasAppsConfigured: Bool
    let onSchedule: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSchedule) {
            VStack(spacing: 12) {
                // Image de background avec overlay
                ZStack {
                    // Image de background qui couvre toute la carte
                    Image(session.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 140) // Même taille que la carte complète
                        .clipped()
                        .overlay(
                            // Overlay dégradé pour lisibilité du texte
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.1),
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.7),
                                    session.accentColor.color.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Contenu au-dessus
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Badges : durée + configuration
                            HStack(spacing: 6) {
                                // Badge de durée
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(session.formattedDuration)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(session.accentColor.color.opacity(0.8), lineWidth: 1)
                                        )
                                )
                                
                                // Badge de configuration
                                if hasAppsConfigured {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text(String(localized: "configured"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.green.opacity(0.8))
                                    )
                                }
                            }
                            
                            // Titre de la session avec meilleur contraste
                            Text(session.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                            
                            // Apps ciblées avec meilleur contraste
                            Text(session.targetedAppsText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                }
            }
            .frame(width: 160, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [session.accentColor.color.opacity(0.6), session.accentColor.color.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 2 : 1
                    )
            )
            .shadow(
                color: session.accentColor.color.opacity(0.3),
                radius: isPressed ? 12 : 8,
                x: 0,
                y: isPressed ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.1 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Session Planning Modal

struct SessionPlanningModal: View {
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionPlanningManager = SessionPlanningManager.shared
    @State private var showContent = false
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var selectedSession: PopularSession?
    
    var body: some View {
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
                                .purple.opacity(0.1),
                                .cyan.opacity(0.05),
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
                LazyVStack(spacing: 20) {
                    // Header avec icône
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .purple.opacity(0.3),
                                            .cyan.opacity(0.2),
                                            .blue.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.purple)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.5), .cyan.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 8) {
                            Text(String(localized: "schedule_sessions"))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(String(localized: "plan_focus_sessions_description"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
                    
                    // Sessions populaires
                    popularSessionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle(String(localized: "session_planning"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "close")) {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { oldSelection, newSelection in
            // Quand l'utilisateur a sélectionné des apps, programmer la session
            if let session = selectedSession, 
               (!newSelection.applicationTokens.isEmpty || !newSelection.categoryTokens.isEmpty) {
                scheduleSessionWithApps(session: session, apps: newSelection)
                selectedSession = nil // Reset après programmation
                dismiss() // Fermer le modal après programmation
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
        }
    }
    
    private var popularSessionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "popular_sessions"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(sessionPlanningManager.popularSessions) { session in
                    DetailedSessionCard(
                        session: session,
                        onSchedule: {
                            selectedSession = session
                            selectedApps = FamilyActivitySelection() // Reset la sélection
                            showingAppSelection = true
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.purple.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
    
    // MARK: - Private Methods
    
    private func scheduleSessionWithApps(session: PopularSession, apps: FamilyActivitySelection) {
        print("🗓️ [SESSION_MODAL] Programmation de '\(session.title)' avec \(apps.applicationTokens.count) apps et \(apps.categoryTokens.count) catégories")
        
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
        
        // Calculer l'heure de début (demain matin à 8h par exemple)
        let startTime = calculateNextOptimalTime()
        
        // Programmer via ZenloopManager
        zenloopManager.scheduleCustomChallenge(
            title: session.title,
            duration: session.duration,
            difficulty: difficulty,
            apps: apps,
            startTime: startTime
        )
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("✅ [SESSION_MODAL] Session '\(session.title)' programmée pour \(startTime)")
    }
    
    private func calculateNextOptimalTime() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        let components = DateComponents(
            year: calendar.component(.year, from: tomorrow),
            month: calendar.component(.month, from: tomorrow),
            day: calendar.component(.day, from: tomorrow),
            hour: 8, // 8h du matin
            minute: 0
        )
        
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Detailed Session Card

struct DetailedSessionCard: View {
    let session: PopularSession
    let onSchedule: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSchedule) {
            VStack(spacing: 12) {
                // Header avec icône
                HStack(spacing: 8) {
                    Image(systemName: session.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(session.accentColor.color)
                        .frame(width: 40, height: 40)
                        .background(session.accentColor.color.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(session.formattedDuration)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(session.accentColor.color)
                    }
                    
                    Spacer()
                }
                
                // Description
                Text(session.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Apps ciblées
                Text(session.targetedAppsText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Bouton d'action
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(session.accentColor.color)
                    
                    Text(String(localized: "schedule"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(session.accentColor.color)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(session.accentColor.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(session.accentColor.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    SessionPlanningRow(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}