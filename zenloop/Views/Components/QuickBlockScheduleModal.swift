//
//  QuickBlockScheduleModal.swift
//  zenloop
//
//  Modal de configuration pour scheduler un Quick Block Mode
//  Basé sur ScheduleConfigurationModal mais adapté pour les catégories
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct QuickBlockScheduleModal: View {
    let categoryType: QuickBlockCategoryType
    let selectedApps: FamilyActivitySelection
    @ObservedObject var zenloopManager: ZenloopManager
    let onSessionStarted: (Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDuration: TimeInterval = 30 * 60 // 30 min par défaut
    @State private var selectedStartTime = Date()
    @State private var selectedDifficulty: DifficultyLevel = .medium
    @State private var showContent = false

    // Durées disponibles (en minutes)
    private let availableDurations: [TimeInterval] = [
        15 * 60,  // 15 min
        30 * 60,  // 30 min
        60 * 60,  // 1h
        90 * 60,  // 1h30
        2 * 60 * 60,  // 2h
        3 * 60 * 60,  // 3h
        4 * 60 * 60,  // 4h
        6 * 60 * 60,  // 6h
        8 * 60 * 60   // 8h
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background moderne
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.12),
                        Color(red: 0.06, green: 0.03, blue: 0.15),
                        Color(red: 0.08, green: 0.02, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header avec info catégorie
                        headerSection

                        // Sélection de durée
                        durationSelectionSection

                        // Sélection de difficulté
                        difficultySelectionSection

                        // Heure de début
                        startTimeSection

                        // Boutons d'action
                        actionButtonsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            .navigationTitle("Planifier le blocage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                selectedStartTime = Date()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContent = true
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icône et titre
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: categoryType.systemIcon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(categoryType.displayName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("\(selectedApps.applicationTokens.count + selectedApps.categoryTokens.count) apps sélectionnées")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Duration Selection
    private var durationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durée du blocage")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            // Grid de durées
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(availableDurations, id: \.self) { duration in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDuration = duration
                        }
                    }) {
                        Text(formatDuration(duration))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedDuration == duration ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDuration == duration ? Color.blue : Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Difficulty Selection
    private var difficultySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Niveau de restriction")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(DifficultyLevel.allCases) { difficulty in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDifficulty = difficulty
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: difficulty.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(selectedDifficulty == difficulty ? .white : .white.opacity(0.5))

                            Text(difficulty.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selectedDifficulty == difficulty ? .white : .white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDifficulty == difficulty ? difficulty.color.opacity(0.3) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedDifficulty == difficulty ? difficulty.color : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                }
            }

            // Description du niveau
            Text(difficultyDescription)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Start Time Section
    private var startTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heure de début")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            DatePicker(
                "",
                selection: $selectedStartTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(.dark)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Bouton "Planifier"
            Button(action: scheduleSession) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Planifier le blocage")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            // Bouton "Démarrer maintenant"
            Button(action: startNow) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Démarrer maintenant")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Computed Properties
    private var difficultyDescription: String {
        switch selectedDifficulty {
        case .easy:
            return "Shield overlay - Les apps sont visibles mais bloquées"
        case .medium:
            return "Shield avec notification - Blocage renforcé"
        case .hard:
            return "Masquage complet - Les apps disparaissent de l'écran"
        }
    }

    // MARK: - Actions
    private func scheduleSession() {
        print("🗓️ [QUICK_BLOCK] Scheduling session for \(categoryType.displayName)")
        print("   → Start time: \(selectedStartTime)")
        print("   → Duration: \(formatDuration(selectedDuration))")
        print("   → Difficulty: \(selectedDifficulty.rawValue)")

        // Scheduler via ZenloopManager
        zenloopManager.scheduleCustomChallenge(
            title: categoryType.displayName,
            duration: selectedDuration,
            difficulty: selectedDifficulty,
            apps: selectedApps,
            startTime: selectedStartTime
        )

        // Notifier le ViewModel
        onSessionStarted(selectedStartTime, selectedDuration)
        dismiss()
    }

    private func startNow() {
        print("▶️ [QUICK_BLOCK] Starting session NOW for \(categoryType.displayName)")

        // Démarrer via ZenloopManager
        zenloopManager.startCustomChallenge(
            title: categoryType.displayName,
            duration: selectedDuration,
            difficulty: selectedDifficulty,
            apps: selectedApps,
            taskGoal: nil
        )

        // Notifier le ViewModel
        onSessionStarted(Date(), selectedDuration)
        dismiss()
    }

    // MARK: - Helpers
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)min"
        }
    }
}
