//
//  QuickBlockScheduleModal.swift
//  zenloop
//
//  Modal compacte pour planifier un Quick Block Mode
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

    @State private var selectedDuration: TimeInterval = 30 * 60
    @State private var selectedStartTime = Date()
    @State private var selectedDifficulty: DifficultyLevel = .medium
    @State private var showContent = false

    private let durations: [TimeInterval] = [
        15, 30, 60, 90, 120, 180, 240, 360, 480
    ].map { $0 * 60 }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                scrollContent
            }
            .navigationTitle("Planifier le blocage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") { dismiss() }
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

    // MARK: - Background

    private var backgroundGradient: some View {
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
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerSection
                cardStack
                actionButtons
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    // MARK: - Header (compact)

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 52, height: 52)

                Image(systemName: categoryType.systemIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryType.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                let count = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
                Text("\(count) apps sélectionnées")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Card Stack (durée + difficulté + heure dans une seule carte)

    private var cardStack: some View {
        VStack(spacing: 0) {
            // ── Durée ──
            sectionHeader("Durée", icon: "clock")
            durationGrid
                .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.1))

            // ── Difficulté ──
            sectionHeader("Restriction", icon: "shield.lefthalf.filled")
                .padding(.top, 16)
            difficultyRow
            Text(difficultyDescription)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.1))

            // ── Heure de début ──
            HStack {
                sectionHeader("Début", icon: "calendar")
                Spacer()
                DatePicker("", selection: $selectedStartTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .scaleEffect(0.9, anchor: .trailing)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }

    // MARK: - Duration Grid (compact 3 colonnes)

    private var durationGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(durations, id: \.self) { duration in
                let isSelected = selectedDuration == duration
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selectedDuration = duration
                    }
                } label: {
                    Text(formatDuration(duration))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.blue : Color.white.opacity(0.08))
                        )
                }
            }
        }
    }

    // MARK: - Difficulty Row (compact)

    private var difficultyRow: some View {
        HStack(spacing: 8) {
            ForEach(DifficultyLevel.allCases) { difficulty in
                let isSelected = selectedDifficulty == difficulty
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selectedDifficulty = difficulty
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: difficulty.icon)
                            .font(.system(size: 16, weight: .bold))
                        Text(difficulty.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? difficulty.color.opacity(0.25) : Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? difficulty.color.opacity(0.6) : .clear, lineWidth: 1.5)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: scheduleSession) {
                Label("Planifier le blocage", systemImage: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.25), radius: 6, y: 3)
            }

            Button(action: startNow) {
                Label("Démarrer maintenant", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
    }

    // MARK: - Computed

    private var difficultyDescription: String {
        switch selectedDifficulty {
        case .easy:   return "Shield overlay – apps visibles mais bloquées"
        case .medium: return "Shield + notification – blocage renforcé"
        case .hard:   return "Masquage complet – apps invisibles"
        }
    }

    // MARK: - Actions

    private func scheduleSession() {
        zenloopManager.scheduleCustomChallenge(
            title: categoryType.displayName,
            duration: selectedDuration,
            difficulty: selectedDifficulty,
            apps: selectedApps,
            startTime: selectedStartTime
        )
        onSessionStarted(selectedStartTime, selectedDuration)
        dismiss()
    }

    private func startNow() {
        zenloopManager.startCustomChallenge(
            title: categoryType.displayName,
            duration: selectedDuration,
            difficulty: selectedDifficulty,
            apps: selectedApps,
            taskGoal: nil
        )
        onSessionStarted(Date(), selectedDuration)
        dismiss()
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h\(m)" }
        if h > 0 { return "\(h)h" }
        return "\(m)min"
    }
}