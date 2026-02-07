//
//  CategoryAppsListView.swift
//  zenloopactivity
//
//  Liste complète des apps d'une catégorie spécifique avec possibilité de blocage
//

import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import os

private let logger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "CategoryAppsList")

// MARK: - Report Data

struct CategoryAppsReport {
    let categoryName: String
    let categoryType: QuickBlockCategoryType
    let apps: [CategoryAppUsage]
    let totalDuration: TimeInterval
    let appsCount: Int
}

struct CategoryAppUsage: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String?
    let duration: TimeInterval
    let token: ApplicationToken
}

// MARK: - Main View

struct CategoryAppsListView: View {
    let reportData: CategoryAppsReport
    @State private var selectedApps: Set<String> = [] // Bundle IDs des apps à bloquer

    init(reportData: CategoryAppsReport) {
        self.reportData = reportData
        logger.critical("🚀 [CATEGORY_LIST] INIT - category: \(reportData.categoryName), apps: \(reportData.apps.count)")
    }

    var body: some View {
        ZStack {
            // Background gradient plein écran
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.15),
                            Color(red: 0.1, green: 0.1, blue: 0.2),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [reportData.categoryType.color.opacity(0.3), reportData.categoryType.color.opacity(0.2), Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .opacity(0.3)
                .blendMode(.overlay)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header compact sans stats cards
                compactHeaderSection
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                // Apps list avec ScrollView
                ScrollView(.vertical, showsIndicators: false) {
                    appsListSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120) // Espace pour floating button
                }
            }

            // Floating action button
            if !selectedApps.isEmpty {
                floatingActionButton
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            logger.critical("📱 [CATEGORY_LIST] onAppear - loading selected apps")
            loadSelectedApps()
        }
    }

    // MARK: - Compact Header Section

    private var compactHeaderSection: some View {
        HStack(spacing: 16) {
            // Icône compacte
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [reportData.categoryType.color.opacity(0.3), reportData.categoryType.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: reportData.categoryType.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(reportData.categoryType.color)
            }

            // Titre et compteur
            VStack(alignment: .leading, spacing: 4) {
                Text(reportData.categoryType.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("\(reportData.appsCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(reportData.categoryType.color)
                        Text("apps")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    if !selectedApps.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        HStack(spacing: 4) {
                            Text("\(selectedApps.count)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(reportData.categoryType.color)
                            Text("sélectionnées")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }

            Spacer()
        }
    }


    // MARK: - Apps List Section

    private var appsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            if reportData.apps.isEmpty {
                emptyState
            } else {
                ForEach(reportData.apps) { app in
                    CategoryAppRowView(
                        app: app,
                        isSelected: selectedApps.contains(app.bundleIdentifier ?? app.name),
                        color: reportData.categoryType.color,
                        onToggle: {
                            toggleAppSelection(app)
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("Aucune app dans cette catégorie")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Floating Action Button

    private var floatingActionButton: some View {
        VStack {
            Spacer()

            Button(action: {
                logger.critical("🔘 [CATEGORY_LIST] Block button tapped for \(selectedApps.count) apps")
                saveAndBlock()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text("Bloquer \(selectedApps.count) app\(selectedApps.count > 1 ? "s" : "")")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [reportData.categoryType.color, reportData.categoryType.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: reportData.categoryType.color.opacity(0.5), radius: 16, x: 0, y: 8)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helper Methods

    private func toggleAppSelection(_ app: CategoryAppUsage) {
        let identifier = app.bundleIdentifier ?? app.name
        if selectedApps.contains(identifier) {
            selectedApps.remove(identifier)
            logger.critical("➖ [CATEGORY_LIST] Deselected: \(app.name)")
        } else {
            selectedApps.insert(identifier)
            logger.critical("➕ [CATEGORY_LIST] Selected: \(app.name)")
        }
    }

    private func loadSelectedApps() {
        // Charger depuis App Group
        guard let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.critical("❌ [CATEGORY_LIST] App Group unavailable")
            return
        }

        let key = "quick_block_\(reportData.categoryType.rawValue)_apps"
        if let data = appGroup.data(forKey: key),
           let saved = try? JSONDecoder().decode(Set<String>.self, from: data) {
            selectedApps = saved
            logger.critical("✅ [CATEGORY_LIST] Loaded \(saved.count) selected apps")
        }
    }

    private func saveAndBlock() {
        guard let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.critical("❌ [CATEGORY_LIST] App Group unavailable for save")
            return
        }

        do {
            let key = "quick_block_\(reportData.categoryType.rawValue)_apps"
            let data = try JSONEncoder().encode(selectedApps)
            appGroup.set(data, forKey: key)
            appGroup.synchronize()

            logger.critical("💾 [CATEGORY_LIST] Saved \(selectedApps.count) apps to block")

            // Appliquer le blocage via ManagedSettings
            #if os(iOS)
            let store = ManagedSettings.ManagedSettingsStore()

            // Collecter les tokens des apps sélectionnées
            var tokensToBlock: Set<ApplicationToken> = []
            for app in reportData.apps {
                let identifier = app.bundleIdentifier ?? app.name
                if selectedApps.contains(identifier) {
                    tokensToBlock.insert(app.token)
                }
            }

            logger.critical("🛡️ [CATEGORY_LIST] Blocking \(tokensToBlock.count) apps with ManagedSettings")

            // Récupérer les apps déjà bloquées
            var currentBlocked = store.shield.applications ?? Set()
            logger.critical("   → Current blocked apps: \(currentBlocked.count)")

            // Ajouter les nouveaux tokens
            currentBlocked.formUnion(tokensToBlock)
            logger.critical("   → After union: \(currentBlocked.count) total apps")

            // Appliquer le blocage
            store.shield.applications = currentBlocked
            logger.critical("✅ [CATEGORY_LIST] Shield applied to \(currentBlocked.count) apps")

            // Sauvegarder les block IDs pour persistance
            let blockIds = selectedApps.map { "quick_block_\(reportData.categoryType.rawValue)_\($0)" }
            let blockIdsKey = "quick_block_\(reportData.categoryType.rawValue)_ids"
            if let blockIdsData = try? JSONEncoder().encode(blockIds) {
                appGroup.set(blockIdsData, forKey: blockIdsKey)
                logger.critical("💾 [CATEGORY_LIST] Saved \(blockIds.count) block IDs for persistence")
            }
            #endif

        } catch {
            logger.critical("❌ [CATEGORY_LIST] Error saving: \(error.localizedDescription)")
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(minutes > 0 ? " \(minutes)m" : "")"
        }
        return "\(minutes)m"
    }
}

// MARK: - Category App Row View

struct CategoryAppRowView: View {
    let app: CategoryAppUsage
    let isSelected: Bool
    let color: Color
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // App icon plus petit
                Label(app.token)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                // App info avec meilleur spacing
                VStack(alignment: .leading, spacing: 5) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85) // Évite le break word

                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))

                        Text(formatDuration(app.duration))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer(minLength: 12)

                // Checkbox plus petit
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? color : .white.opacity(0.3))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.12) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Category Type Enum

enum QuickBlockCategoryType: String, CaseIterable, Identifiable {
    case social = "social"
    case productivity = "productivity"  // Pour AI
    case gaming = "gaming"
    case adult = "adult"  // Pour porn/adult content

    var id: String { rawValue }

    var title: String {
        switch self {
        case .social: return "No Social Media"
        case .productivity: return "No AI"
        case .gaming: return "No Gaming"
        case .adult: return "No Porn"
        }
    }

    var description: String {
        switch self {
        case .social:
            return "Bloquez Instagram, TikTok, Facebook et autres réseaux sociaux pour rester concentré."
        case .productivity:
            return "Limitez ChatGPT, Claude et autres outils de productivité pour stimuler votre créativité."
        case .gaming:
            return "Contrôlez votre temps de jeu sur mobile."
        case .adult:
            return "Filtrage de contenu adulte via restrictions Web."
        }
    }

    var icon: String {
        switch self {
        case .social: return "bubble.left.and.bubble.right.fill"
        case .productivity: return "brain.head.profile"
        case .gaming: return "gamecontroller.fill"
        case .adult: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .social: return .blue
        case .productivity: return .purple
        case .gaming: return .green
        case .adult: return .red
        }
    }

    // Mapping vers les vraies catégories iOS DeviceActivity
    var deviceActivityCategories: [String] {
        switch self {
        case .social:
            return ["socialNetworking"]
        case .productivity:
            return ["productivity", "business"]
        case .gaming:
            return ["games", "entertainment"]
        case .adult:
            return [] // Géré via Web Content Filter, pas app categories
        }
    }
}

#Preview {
    CategoryAppsListView(reportData: CategoryAppsReport(
        categoryName: "Social Networking",
        categoryType: .social,
        apps: [],
        totalDuration: 7200,
        appsCount: 0
    ))
}
