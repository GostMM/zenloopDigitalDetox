//
//  SessionPlanningRow.swift
//  zenloop
//
//  Created by Claude on 27/08/2025.
//  Fixed on 07/04/2026: layout shift when apps selected

import SwiftUI
import FamilyControls
import UIKit

struct SessionPlanningRow: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @State private var showingScheduleModal = false
    @State private var selectedSession: PopularSession?

    @State private var selectedDuration: TimeInterval = 30 * 60
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showingAppPicker = false
    @State private var isInitialLoad = true

    @State private var currentDynamicSessionId: String = "quick_schedule"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.0), .white.opacity(0.1), .white.opacity(0.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)

            CompactScheduleCard(
                selectedDuration: $selectedDuration,
                selectedApps: $selectedApps,
                onSelectApps: { showingAppPicker = true },
                onSchedule: {
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
            saveQuickScheduleApps(newValue)
            let hasApps = !newValue.applicationTokens.isEmpty || !newValue.categoryTokens.isEmpty
            if hasApps && !isInitialLoad {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let session = createDynamicSession() {
                        selectedSession = session
                        showingScheduleModal = true
                    }
                }
            }
            if isInitialLoad { isInitialLoad = false }
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
                            saveQuickScheduleApps(apps)
                        },
                        onAppsClear: {
                            selectedApps = FamilyActivitySelection()
                            clearQuickScheduleApps()
                        }
                    )
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(String(localized: "session_not_found"))
                            .font(.title2).foregroundColor(.white)
                        Button(String(localized: "close")) { showingScheduleModal = false }
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                }
            }
        }
        .onAppear { loadQuickScheduleApps() }
        .onChange(of: showingScheduleModal) { oldValue, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selectedSession = nil }
            }
        }
    }

    // MARK: - Quick Schedule Persistence

    private func saveQuickScheduleApps(_ apps: FamilyActivitySelection) {
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            if let data = try? JSONEncoder().encode(apps) {
                appGroup.set(data, forKey: "quick_schedule_apps")
                appGroup.synchronize()
            }
        }
    }

    private func loadQuickScheduleApps() {
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop"),
           let data = appGroup.data(forKey: "quick_schedule_apps"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = selection
        }
    }

    private func clearQuickScheduleApps() {
        if let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") {
            appGroup.removeObject(forKey: "quick_schedule_apps")
            appGroup.synchronize()
        }
    }

    private func createDynamicSession() -> PopularSession? {
        let appsCount = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
        let title = appsCount > 0
            ? String(localized: "focus_with_apps", defaultValue: "Focus • \(appsCount) apps")
            : String(localized: "custom_focus_session")

        return PopularSession(
            sessionId: currentDynamicSessionId,
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

    private let durations: [(TimeInterval, String)] = [
        (30 * 60, "30m"), (60 * 60, "1h"), (2 * 60 * 60, "2h"), (4 * 60 * 60, "4h")
    ]

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var hasSelectedApps: Bool { selectedAppsCount > 0 }

    private var formattedDuration: String {
        let hours = Int(selectedDuration) / 3600
        let minutes = (Int(selectedDuration) % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(spacing: 16) {
            // FIX: Top row — apps à gauche, duration à droite (position fixe)
            // alignment: .top empêche le shift vertical quand les icônes apparaissent
            HStack(alignment: .top, spacing: 12) {
                // Bloc gauche : apps — prend tout l'espace restant
                Button(action: onSelectApps) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: hasSelectedApps ? "calendar.badge.checkmark" : "calendar.badge.clock")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "schedule_label"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .tracking(0.5)

                                Text(hasSelectedApps
                                     ? String(localized: "apps_count", defaultValue: "\(selectedAppsCount) apps")
                                        .replacingOccurrences(of: "%d", with: "\(selectedAppsCount)")
                                     : String(localized: "choose_apps"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }

                        // Les icônes apparaissent EN DESSOUS, pas à côté
                        // Le bloc duration ne bouge pas car il est fixedSize + aligné .top
                        if hasSelectedApps {
                            StackedAppIcons(selectedApps: selectedApps, maxToShow: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())

                // Bloc droit : duration — largeur intrinsèque, ne se compresse pas
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
                .fixedSize()  // Ne pas compresser ni étirer — position stable
            }

            // Sélecteur de durée
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

            // Bouton Schedule
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
                    LinearGradient(colors: [.purple, .purple.opacity(0.8)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}