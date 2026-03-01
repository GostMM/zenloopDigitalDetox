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
    @State private var showingScheduleModal = false
    @State private var selectedSession: PopularSession?
    @StateObject private var sessionPlanningManager = SessionPlanningManager.shared

    // Dictionnaire pour stocker les sélections d'apps par session
    @State private var sessionAppSelections: [String: FamilyActivitySelection] = [:]

    // States pour la nouvelle carte dynamique
    @State private var selectedDuration: TimeInterval = 30 * 60 // 30 min par défaut
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showingAppPicker = false
    @State private var isInitialLoad = true // Pour éviter d'ouvrir le modal au chargement

    var body: some View {
        VStack(spacing: 0) {
            // Divider subtil
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)

            CompactScheduleCard(
                selectedDuration: $selectedDuration,
                selectedApps: $selectedApps,
                onSelectApps: {
                    showingAppPicker = true
                },
                onSchedule: {
                    // Créer et afficher la modal de scheduling
                    if let session = createDynamicSession() {
                        selectedSession = session
                        showingScheduleModal = true
                    }
                },
                showContent: showContent
            )
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: showContent)
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $selectedApps)
        .onChange(of: selectedApps) { oldValue, newValue in
            // Sauvegarder les apps pour la carte Quick Schedule
            saveQuickScheduleApps(newValue)

            // Ouvrir automatiquement le modal après sélection d'apps (mais pas au chargement initial)
            let hasApps = !newValue.applicationTokens.isEmpty || !newValue.categoryTokens.isEmpty
            if hasApps && !isInitialLoad {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let session = createDynamicSession() {
                        selectedSession = session
                        showingScheduleModal = true
                    }
                }
            }

            // Marquer que le chargement initial est terminé
            if isInitialLoad {
                isInitialLoad = false
            }
        }
        .sheet(isPresented: $showingScheduleModal) {
            Group {
                if let session = selectedSession {
                    ScheduleConfigurationModal(
                        session: session,
                        zenloopManager: zenloopManager,
                        initialAppsSelection: selectedApps,
                        onAppsSelected: { apps in
                            selectedApps = apps
                            saveAppsForSession(session.sessionId, apps: apps)
                        },
                        onAppsClear: {
                            selectedApps = FamilyActivitySelection()
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

                        Text(String(localized: "session_not_found"))
                            .font(.title2)
                            .foregroundColor(.white)

                        Button(String(localized: "close")) {
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
            loadQuickScheduleApps() // Charger les apps de la carte Quick Schedule
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

    // MARK: - Quick Schedule Persistence

    private func saveQuickScheduleApps(_ apps: FamilyActivitySelection) {
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(apps)
                appGroup.set(data, forKey: "quick_schedule_apps")
                appGroup.synchronize()

                let count = apps.applicationTokens.count + apps.categoryTokens.count
                print("💾 [SESSION_ROW] Apps Quick Schedule persistées: \(count) éléments")
            } catch {
                print("❌ [SESSION_ROW] Erreur persistance Quick Schedule: \(error)")
            }
        }
    }

    private func loadQuickScheduleApps() {
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop"),
           let data = appGroup.data(forKey: "quick_schedule_apps") {
            do {
                let decoder = JSONDecoder()
                let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
                selectedApps = selection

                let count = selection.applicationTokens.count + selection.categoryTokens.count
                print("📱 [SESSION_ROW] Apps Quick Schedule chargées: \(count) éléments")
            } catch {
                print("❌ [SESSION_ROW] Erreur chargement Quick Schedule: \(error)")
            }
        }
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

    private func createDynamicSession() -> PopularSession? {
        let hours = Int(selectedDuration) / 3600
        let minutes = (Int(selectedDuration) % 3600) / 60

        let appsCount = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
        let title = appsCount > 0
            ? String(localized: "focus_with_apps", defaultValue: "Focus • \(appsCount) apps")
            : String(localized: "custom_focus_session")

        return PopularSession(
            sessionId: "custom_\(UUID().uuidString)",
            title: title,
            description: String(localized: "personalized_session_description"),
            duration: selectedDuration,
            iconName: "sparkles",
            imageName: "focus",
            accentColor: .purple,
            targetedApps: [],
            category: .mixed
        )
    }

}

// MARK: - Compact Schedule Card

struct CompactScheduleCard: View {
    @Binding var selectedDuration: TimeInterval
    @Binding var selectedApps: FamilyActivitySelection
    let onSelectApps: () -> Void
    let onSchedule: () -> Void
    let showContent: Bool

    // Durées prédéfinies
    private let durations: [(TimeInterval, String)] = [
        (30 * 60, "30m"),
        (60 * 60, "1h"),
        (2 * 60 * 60, "2h"),
        (4 * 60 * 60, "4h")
    ]

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var hasSelectedApps: Bool {
        selectedAppsCount > 0
    }

    private var formattedDuration: String {
        let hours = Int(selectedDuration) / 3600
        let minutes = (Int(selectedDuration) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Section 1: App Selection + Duration (inspiré de CompactTimerView)
            HStack(alignment: .center, spacing: 20) {
                // Apps (left)
                Button(action: onSelectApps) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: hasSelectedApps ? "calendar.badge.checkmark" : "calendar.badge.clock")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "schedule_label"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .tracking(0.5)

                                Text(hasSelectedApps ? String(localized: "apps_count", defaultValue: "\(selectedAppsCount) apps").replacingOccurrences(of: "%d", with: "\(selectedAppsCount)") : String(localized: "choose_apps"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }

                        // Pile d'apps si sélectionnées
                        if hasSelectedApps {
                            StackedAppIcons(selectedApps: selectedApps, maxToShow: 5)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Duration (right) - GRANDE
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "duration_label"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.5)

                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                        Text(formattedDuration)
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
            }

            // Section 2: Durées sélectionnables
            HStack(spacing: 8) {
                ForEach(durations, id: \.0) { duration in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedDuration = duration.0
                        }
                    }) {
                        Text(duration.1)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedDuration == duration.0 ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedDuration == duration.0 ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Section 3: Schedule Button
            Button(action: onSchedule) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .bold))

                    Text(String(localized: "schedule_the_session"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [.purple, .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
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

#Preview {
    SessionPlanningRow(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}