//
//  BlockControllerView.swift
//  zenloop
//
//  Contrôleur centralisé pour gérer toutes les apps en restriction
//

import SwiftUI
import ManagedSettings
import FamilyControls

struct BlockControllerView: View {
    @State private var restrictedApps: [RestrictedApp] = []
    @State private var refreshTimer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                if restrictedApps.isEmpty {
                    emptyState
                } else {
                    // Liste des apps restreintes
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(restrictedApps) { app in
                                RestrictedAppCard(app: app, onUpdate: loadRestrictedApps)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onAppear {
            loadRestrictedApps()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apps Bloquées")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("\(restrictedApps.count) app\(restrictedApps.count > 1 ? "s" : "") en restriction")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(20)
        .background(Color.black)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Aucune app bloquée")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Toutes vos apps sont accessibles")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadRestrictedApps() {
        var apps: [RestrictedApp] = []

        // 1. Scanner tous les ManagedSettingsStore actifs
        let blockManager = BlockManager()
        var activeBlocks = blockManager.getActiveBlocks()

        // 2. Vérifier et nettoyer les blocks expirés
        for block in activeBlocks where block.isExpired {
            print("🧹 [CLEANUP] Block expiré détecté: \(block.appName)")

            let store = ManagedSettingsStore(named: .init(block.storeName))
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            print("✅ [CLEANUP] App \(block.appName) débloquée")

            blockManager.updateBlockStatus(id: block.id, status: .expired)
        }

        // 3. Nettoyer la persistence
        blockManager.removeExpiredAndStoppedBlocks()

        // 4. Recharger les blocks actifs propres
        activeBlocks = blockManager.getActiveBlocks()

        // 5. Créer la liste des apps restreintes
        for block in activeBlocks {
            let store = ManagedSettingsStore(named: .init(block.storeName))

            // Vérifier si le store a effectivement des apps bloquées
            if let blockedApps = store.shield.applications, !blockedApps.isEmpty {
                let app = RestrictedApp(
                    id: block.id,
                    name: block.appName,
                    storeName: block.storeName,
                    status: block.status,
                    remainingTime: block.formattedRemainingTime,
                    progress: block.progress,
                    startDate: block.startDate,
                    endDate: block.endDate,
                    isPaused: block.status == .paused
                )
                apps.append(app)
            }
        }

        restrictedApps = apps.sorted { $0.endDate < $1.endDate }
        print("📊 [CONTROLLER] Chargé \(apps.count) apps en restriction")
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            loadRestrictedApps()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Restricted App Model

struct RestrictedApp: Identifiable {
    let id: String
    let name: String
    let storeName: String
    let status: ActiveBlock.BlockStatus
    let remainingTime: String
    let progress: Double
    let startDate: TimeInterval
    let endDate: TimeInterval
    let isPaused: Bool
}

// MARK: - Restricted App Card

struct RestrictedAppCard: View {
    let app: RestrictedApp
    let onUpdate: () -> Void
    @State private var showExtendSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                // Icône + Nom
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 48, height: 48)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text(statusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                }

                Spacer()

                // Temps restant
                VStack(alignment: .trailing, spacing: 4) {
                    Text(app.remainingTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("restant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: progressGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * app.progress)
                }
            }
            .frame(height: 8)

            // Controls
            HStack(spacing: 12) {
                // Pause/Resume
                if app.status == .active {
                    ControlActionButton(
                        icon: "pause.fill",
                        label: "Pause",
                        color: .blue
                    ) {
                        pauseApp()
                    }
                } else if app.status == .paused {
                    ControlActionButton(
                        icon: "play.fill",
                        label: "Reprendre",
                        color: .green
                    ) {
                        resumeApp()
                    }
                }

                // Extend
                ControlActionButton(
                    icon: "plus.circle.fill",
                    label: "Ajouter",
                    color: .purple
                ) {
                    showExtendSheet = true
                }

                Spacer()

                // Stop (plus gros bouton)
                Button {
                    stopApp()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Débloquer")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showExtendSheet) {
            ExtendSheet(appName: app.name, blockId: app.id, onExtend: { seconds in
                extendApp(by: seconds)
                showExtendSheet = false
            })
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch app.status {
        case .active: return .orange
        case .paused: return .blue
        case .stopped, .expired: return .gray
        }
    }

    private var statusText: String {
        switch app.status {
        case .active: return "En cours"
        case .paused: return "En pause"
        case .stopped: return "Arrêté"
        case .expired: return "Expiré"
        }
    }

    private var progressGradient: [Color] {
        switch app.status {
        case .active:
            return [.orange, .orange.opacity(0.6)]
        case .paused:
            return [.blue, .blue.opacity(0.6)]
        case .stopped, .expired:
            return [.gray, .gray.opacity(0.6)]
        }
    }

    // MARK: - Actions

    private func pauseApp() {
        print("⏸️ [CONTROLLER] Pause de \(app.name)")

        let store = ManagedSettingsStore(named: .init(app.storeName))

        // Retirer toutes les restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.dateAndTime.requireAutomaticDateAndTime = false

        // Mettre à jour le status
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: app.id, status: .paused)

        onUpdate()
        print("✅ [CONTROLLER] \(app.name) mis en pause")
    }

    private func resumeApp() {
        print("▶️ [CONTROLLER] Reprise de \(app.name)")

        // Note: On ne peut pas facilement réappliquer la restriction ici
        // car on n'a pas accès au token de l'app
        // L'utilisateur doit utiliser l'extension pour Resume

        print("⚠️ [CONTROLLER] Resume depuis l'app non supporté")
        print("💡 [CONTROLLER] Utilisez Full Stats Page pour reprendre le blocage")

        // Juste mettre à jour le status
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: app.id, status: .active)

        onUpdate()
    }

    private func stopApp() {
        print("⏹️ [CONTROLLER] Arrêt de \(app.name)")

        let store = ManagedSettingsStore(named: .init(app.storeName))

        // Retirer toutes les restrictions définitivement
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.dateAndTime.requireAutomaticDateAndTime = false

        // Marquer comme arrêté
        let blockManager = BlockManager()
        blockManager.updateBlockStatus(id: app.id, status: .stopped)

        onUpdate()
        print("✅ [CONTROLLER] \(app.name) débloqué")
    }

    private func extendApp(by seconds: TimeInterval) {
        print("⏱️ [CONTROLLER] Extension de \(app.name) de \(Int(seconds/60)) minutes")

        let blockManager = BlockManager()
        blockManager.extendBlock(id: app.id, bySeconds: seconds)

        onUpdate()
        print("✅ [CONTROLLER] \(app.name) étendu")
    }
}

// MARK: - Control Action Button

struct ControlActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Extend Sheet

struct ExtendSheet: View {
    let appName: String
    let blockId: String
    let onExtend: (TimeInterval) -> Void
    @Environment(\.dismiss) var dismiss

    private let options: [(String, TimeInterval)] = [
        ("5 minutes", 5 * 60),
        ("10 minutes", 10 * 60),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 heure", 60 * 60),
        ("2 heures", 120 * 60)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.purple)

                    Text("Prolonger le blocage")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(appName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 40)

                // Options
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(options, id: \.0) { option in
                            Button {
                                onExtend(option.1)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.purple)

                                    Text(option.0)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Cancel
                Button {
                    dismiss()
                } label: {
                    Text("Annuler")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    BlockControllerView()
}
