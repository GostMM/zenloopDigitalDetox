//
//  ActiveBlocksView.swift
//  zenloop
//
//  Vue de gestion des blocages actifs avec contrôles complets
//

import SwiftUI
import ManagedSettings
import FamilyControls

struct ActiveBlocksView: View {
    @State private var activeBlocks: [ActiveBlock] = []
    @State private var refreshTimer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if activeBlocks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(activeBlocks, id: \.id) { block in
                            ActiveBlockCard(block: block) {
                                loadBlocks()
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Blocages actifs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBlocks()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            Text("Aucun blocage actif")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Bloquez des apps depuis\nFull Stats ou Home")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Data Loading

    private func loadBlocks() {
        let blockManager = BlockManager()
        activeBlocks = blockManager.getActiveBlocks()
            .sorted { $0.remainingDuration > $1.remainingDuration }
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            loadBlocks()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Active Block Card

struct ActiveBlockCard: View {
    let block: ActiveBlock
    let onUpdate: () -> Void

    @State private var showExtendSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header avec nom app et temps restant
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.appName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                }

                Spacer()

                Text(block.formattedRemainingTime)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Barre de progression
            ProgressBar(progress: block.progress)

            // Contrôles
            HStack(spacing: 12) {
                if block.status == .active {
                    // Pause
                    ControlButton(
                        icon: "pause.fill",
                        label: "Pause",
                        color: .orange
                    ) {
                        pauseBlock()
                    }
                } else if block.status == .paused {
                    // Resume
                    ControlButton(
                        icon: "play.fill",
                        label: "Reprendre",
                        color: .green
                    ) {
                        resumeBlock()
                    }
                }

                // Extend
                ControlButton(
                    icon: "plus.circle.fill",
                    label: "Ajouter",
                    color: .blue
                ) {
                    showExtendSheet = true
                }

                Spacer()

                // Stop
                ControlButton(
                    icon: "stop.fill",
                    label: "Arrêter",
                    color: .red
                ) {
                    stopBlock()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
        )
        .sheet(isPresented: $showExtendSheet) {
            ExtendBlockSheet(block: block) {
                onUpdate()
            }
        }
    }

    // MARK: - Status

    private var statusText: String {
        switch block.status {
        case .active:
            return "En cours"
        case .paused:
            return "En pause"
        case .stopped:
            return "Arrêté"
        case .expired:
            return "Expiré"
        }
    }

    private var statusColor: Color {
        switch block.status {
        case .active:
            return .green
        case .paused:
            return .orange
        case .stopped, .expired:
            return .gray
        }
    }

    // MARK: - Actions

    private func pauseBlock() {
        print("🔵 [PAUSE] Fonction pauseBlock appelée pour \(block.appName)")

        let store = ManagedSettingsStore(named: .init(block.storeName))

        // Méthode officielle Apple pour retirer toutes les restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.dateAndTime.requireAutomaticDateAndTime = false

        print("⏸️ [PAUSE] Restriction retirée pour \(block.appName)")

        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: block.id, status: .paused)
        onUpdate()
    }

    private func resumeBlock() {
        print("⚠️ [RESUME] Resume depuis l'app principale non supporté")
        print("💡 [RESUME] Utilisez les contrôles dans Full Stats Page (tab Screen Time)")

        // Juste mettre à jour le status, pas la restriction
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: block.id, status: .active)
        onUpdate()
    }

    private func stopBlock() {
        print("🔴 [STOP] Fonction stopBlock appelée pour \(block.appName)")

        let store = ManagedSettingsStore(named: .init(block.storeName))

        // Méthode officielle Apple pour retirer toutes les restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.dateAndTime.requireAutomaticDateAndTime = false

        print("⏹️ [STOP] Restriction retirée définitivement pour \(block.appName)")

        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: block.id, status: .stopped)
        onUpdate()
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))

                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
            )
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: progressColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
        .frame(height: 8)
    }

    private var progressColors: [Color] {
        if progress < 0.3 {
            return [.green, .green.opacity(0.8)]
        } else if progress < 0.7 {
            return [.orange, .orange.opacity(0.8)]
        } else {
            return [.red, .red.opacity(0.8)]
        }
    }
}

// MARK: - Extend Block Sheet

struct ExtendBlockSheet: View {
    let block: ActiveBlock
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMinutes = 15

    private let durations = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    Text("Ajouter du temps")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(block.appName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    // Sélection de durée
                    VStack(spacing: 16) {
                        ForEach(durations, id: \.self) { minutes in
                            Button {
                                selectedMinutes = minutes
                            } label: {
                                HStack {
                                    Text("+\(minutes) minutes")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedMinutes == minutes ? .black : .white)

                                    Spacer()

                                    if selectedMinutes == minutes {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMinutes == minutes ? Color.white : Color.white.opacity(0.1))
                                )
                            }
                        }
                    }

                    Spacer()

                    // Boutons
                    VStack(spacing: 12) {
                        Button {
                            extendBlock()
                        } label: {
                            Text("Ajouter \(selectedMinutes)min")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Annuler")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
    }

    private func extendBlock() {
        let blockManager = BlockManager()
        blockManager.extendBlock(id: block.id, bySeconds: TimeInterval(selectedMinutes * 60))
        onUpdate()
        dismiss()
    }
}
