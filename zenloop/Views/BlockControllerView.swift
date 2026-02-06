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
                        LazyVStack(spacing: 12) {
                            ForEach(Array(restrictedApps.enumerated()), id: \.element.id) { index, app in
                                RestrictedAppCard(app: app, onUpdate: loadRestrictedApps)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)
                                    ))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * 0.05), value: restrictedApps.count)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
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

        // ✅ IMPORTANT: Utiliser le DEFAULT store (sans nom) comme FullStatsPageView
        let defaultStore = ManagedSettingsStore()

        // 1. Scanner tous les blocks actifs depuis BlockManager
        let blockManager = BlockManager()
        var activeBlocks = blockManager.getActiveBlocks()

        print("🔍 [CONTROLLER] Found \(activeBlocks.count) active blocks in BlockManager")
        print("📦 [CONTROLLER] Default store has \(defaultStore.shield.applications?.count ?? 0) blocked apps")

        // 2. Vérifier et nettoyer les blocks expirés
        for block in activeBlocks where block.isExpired {
            print("🧹 [CLEANUP] Block expiré détecté: \(block.appName)")

            // Récupérer le token pour le retirer du shield
            if let token = block.getApplicationToken() {
                var currentBlocked = defaultStore.shield.applications ?? Set()
                currentBlocked.remove(token)
                defaultStore.shield.applications = currentBlocked
                print("✅ [CLEANUP] App \(block.appName) retirée du shield")
            }

            blockManager.updateBlockStatus(id: block.id, status: .expired)
        }

        // 3. Nettoyer la persistence
        blockManager.removeExpiredAndStoppedBlocks()

        // 4. Recharger les blocks actifs propres
        activeBlocks = blockManager.getActiveBlocks()

        // 5. Créer la liste des apps restreintes
        // ✅ On fait confiance au BlockManager - pas besoin de vérifier le store
        for block in activeBlocks {
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
    @State private var showIcon = false

    var body: some View {
        HStack(spacing: 14) {
            // ✅ Icône réelle de l'app avec lock badge
            ZStack(alignment: .bottomTrailing) {
                #if os(iOS)
                if showIcon, let token = getAppToken() {
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(statusColor.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: statusColor.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    placeholderIcon
                }
                #else
                placeholderIcon
                #endif

                // Badge cadenas animé
                ZStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 22, height: 22)

                    Image(systemName: app.status == .paused ? "pause.fill" : "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showIcon = true
                }
            }

            // Infos compactes
            VStack(alignment: .leading, spacing: 6) {
                // Nom + status
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                }

                // Progress bar ultra-fine
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.12))

                        RoundedRectangle(cornerRadius: 2)
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
                .frame(height: 4)

                // Temps restant
                Text(app.remainingTime)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer(minLength: 8)

            // Boutons compacts verticaux
            VStack(spacing: 6) {
                // Pause/Resume
                if app.status == .active {
                    compactButton(icon: "pause.fill", color: .blue) {
                        pauseApp()
                    }
                } else if app.status == .paused {
                    compactButton(icon: "play.fill", color: .green) {
                        resumeApp()
                    }
                }

                // Stop
                compactButton(icon: "xmark", color: .red) {
                    stopApp()
                }

                // Extend
                compactButton(icon: "plus", color: .purple) {
                    showExtendSheet = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    statusColor.opacity(0.3),
                                    statusColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: statusColor.opacity(0.15), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showExtendSheet) {
            ExtendSheet(appName: app.name, blockId: app.id, onExtend: { seconds in
                extendApp(by: seconds)
                showExtendSheet = false
            })
        }
    }

    // ✅ Récupérer le token de l'app pour afficher l'icône réelle
    private func getAppToken() -> ApplicationToken? {
        let blockManager = BlockManager()
        guard let block = blockManager.getBlock(id: app.id) else { return nil }
        return block.getApplicationToken()
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            statusColor.opacity(0.3),
                            statusColor.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(statusColor.opacity(0.4), lineWidth: 2)
        )
    }

    private func compactButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .overlay(
                            Circle()
                                .strokeBorder(color.opacity(0.3), lineWidth: 1)
                        )
                )
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

        // ✅ Utiliser le DEFAULT store
        let defaultStore = ManagedSettingsStore()
        let blockManager = BlockManager()

        // Récupérer le block pour avoir le token
        if let block = blockManager.getBlock(id: app.id),
           let token = block.getApplicationToken() {

            // Retirer cette app du shield
            var currentBlocked = defaultStore.shield.applications ?? Set()
            let beforeCount = currentBlocked.count
            currentBlocked.remove(token)
            let afterCount = currentBlocked.count

            defaultStore.shield.applications = currentBlocked
            print("📦 [CONTROLLER] Removed token from shield: \(beforeCount) → \(afterCount)")
        }

        // Mettre à jour le status
        blockManager.updateBlockStatus(id: app.id, status: .paused)

        onUpdate()
        print("✅ [CONTROLLER] \(app.name) mis en pause")
    }

    private func resumeApp() {
        print("▶️ [CONTROLLER] Reprise de \(app.name)")

        // ✅ Maintenant on peut réappliquer le shield avec le token stocké
        let defaultStore = ManagedSettingsStore()
        let blockManager = BlockManager()

        // Récupérer le block pour avoir le token
        if let block = blockManager.getBlock(id: app.id),
           let token = block.getApplicationToken() {

            // Ajouter cette app au shield
            var currentBlocked = defaultStore.shield.applications ?? Set()
            let beforeCount = currentBlocked.count
            currentBlocked.insert(token)
            let afterCount = currentBlocked.count

            defaultStore.shield.applications = currentBlocked
            print("📦 [CONTROLLER] Added token to shield: \(beforeCount) → \(afterCount)")
        }

        // Mettre à jour le status
        blockManager.updateBlockStatus(id: app.id, status: .active)

        onUpdate()
        print("✅ [CONTROLLER] \(app.name) repris")
    }

    private func stopApp() {
        print("⏹️ [CONTROLLER] Arrêt de \(app.name)")

        // ✅ Utiliser le DEFAULT store
        let defaultStore = ManagedSettingsStore()
        let blockManager = BlockManager()

        // Récupérer le block pour avoir le token
        if let block = blockManager.getBlock(id: app.id),
           let token = block.getApplicationToken() {

            // Retirer cette app du shield définitivement
            var currentBlocked = defaultStore.shield.applications ?? Set()
            let beforeCount = currentBlocked.count
            currentBlocked.remove(token)
            let afterCount = currentBlocked.count

            defaultStore.shield.applications = currentBlocked
            print("📦 [CONTROLLER] Removed token from shield: \(beforeCount) → \(afterCount)")
        }

        // Marquer comme arrêté
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
