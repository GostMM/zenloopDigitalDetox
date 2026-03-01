//
//  QuickBlockCategoryView.swift
//  zenloopactivity
//
//  Vue pour afficher les apps d'une catégorie spécifique (Social, AI, Porn, Gaming)
//

import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import os

private let logger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "QuickBlockCategory")

struct QuickBlockCategoryView: View {
    let category: BlockCategory
    @State private var selectedApps = FamilyActivitySelection()
    @Environment(\.openURL) var openURL

    init(category: BlockCategory) {
        self.category = category
        logger.critical("🚀🚀🚀 [QUICK_BLOCK] QuickBlockCategoryView INIT - category: \(category.rawValue)")
    }

    var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    var body: some View {
        let _ = logger.critical("🎨 [QUICK_BLOCK] Body rendering for category: \(category.rawValue)")
        ZStack {
            // Background gradient
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
                        colors: [category.color.opacity(0.3), category.color.opacity(0.2), Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .opacity(0.3)
                .blendMode(.overlay)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header avec icône et titre
                    headerSection

                    // Apps sélectionnées
                    if selectedAppsCount > 0 {
                        selectedAppsSection
                    } else {
                        emptyStateSection
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }

            // Bouton flottant pour ouvrir l'app principale
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Button(action: {
                        logger.critical("🔘 [QUICK_BLOCK] Button tapped, opening main app")
                        // Ouvrir l'app principale avec un URL scheme
                        if let url = URL(string: "zenloop://quick-block/\(category.rawValue)") {
                            logger.critical("📱 [QUICK_BLOCK] Opening URL: \(url.absoluteString)")
                            openURL(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedAppsCount > 0 ? "pencil.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 20, weight: .bold))

                            Text(selectedAppsCount > 0
                                ? String(localized: "edit_apps", defaultValue: "Edit (\(selectedAppsCount))").replacingOccurrences(of: "%d", with: "\(selectedAppsCount)")
                                : String(localized: "select_apps_button"))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [category.color, category.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: category.color.opacity(0.4), radius: 12, x: 0, y: 6)
                    }

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            logger.critical("📱 [QUICK_BLOCK] onAppear called for category: \(category.rawValue)")
            loadPersistedSelection()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Icône avec gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color.opacity(0.3), category.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: category.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(category.color)
            }

            // Titre
            Text(category.title)
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)

            // Description
            Text(category.description)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
        }
    }

    // MARK: - Selected Apps Section

    private var selectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre de la section
            HStack(spacing: 8) {
                Text(String(localized: "selected_apps_title"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(selectedAppsCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.2))
                    .cornerRadius(8)
            }

            // Grille d'apps
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(Array(selectedApps.applicationTokens), id: \.self) { token in
                    VStack(spacing: 8) {
                        // Icône de l'app
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 42))
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(category.color.opacity(0.3), lineWidth: 1)
                            )

                        // Nom de l'app
                        Label(token)
                            .labelStyle(.titleOnly)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 32)
                    }
                }

                // Catégories
                ForEach(Array(selectedApps.categoryTokens), id: \.self) { token in
                    VStack(spacing: 8) {
                        // Icône de catégorie
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 42))
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(category.color.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(category.color.opacity(0.3), lineWidth: 1)
                            )

                        // Nom de la catégorie
                        Label(token)
                            .labelStyle(.titleOnly)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 32)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text(String(localized: "no_apps_selected"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text(String(localized: "tap_to_select_apps"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Persistence

    private func loadPersistedSelection() {
        logger.critical("💾 [QUICK_BLOCK] loadPersistedSelection called for category: \(category.rawValue)")

        guard let appGroup = UserDefaults(suiteName: "group.com.app.zenloop") else {
            logger.critical("❌ [QUICK_BLOCK] App Group unavailable")
            return
        }

        logger.critical("✅ [QUICK_BLOCK] App Group OK")

        let key = "quick_block_\(category.rawValue)"
        logger.critical("💾 [QUICK_BLOCK] Looking for key: \(key)")

        if let data = appGroup.data(forKey: key) {
            logger.critical("✅ [QUICK_BLOCK] Data found, size: \(data.count) bytes")
            do {
                let decoder = JSONDecoder()
                let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
                selectedApps = selection
                logger.critical("✅ [QUICK_BLOCK] Loaded \(category.title): \(selection.applicationTokens.count) apps")
            } catch {
                logger.critical("❌ [QUICK_BLOCK] Error loading \(category.title): \(error.localizedDescription)")
            }
        } else {
            logger.critical("⚠️ [QUICK_BLOCK] No data found for key: \(key)")
        }
    }

}

// MARK: - Block Category Model

enum BlockCategory: String, CaseIterable, Identifiable {
    case noSocial = "social"
    case noAI = "ai"
    case noPorn = "porn"
    case noGaming = "gaming"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noSocial: return String(localized: "no_social_title")
        case .noAI: return String(localized: "no_ai_title")
        case .noPorn: return String(localized: "no_porn_title")
        case .noGaming: return String(localized: "no_gaming_title")
        }
    }

    var description: String {
        switch self {
        case .noSocial:
            return String(localized: "no_social_description")
        case .noAI:
            return String(localized: "no_ai_description")
        case .noPorn:
            return String(localized: "no_porn_description")
        case .noGaming:
            return String(localized: "no_gaming_description")
        }
    }

    var icon: String {
        switch self {
        case .noSocial: return "bubble.left.and.bubble.right.fill"
        case .noAI: return "brain.head.profile"
        case .noPorn: return "hand.raised.fill"
        case .noGaming: return "gamecontroller.fill"
        }
    }

    var color: Color {
        switch self {
        case .noSocial: return .blue
        case .noAI: return .purple
        case .noPorn: return .red
        case .noGaming: return .green
        }
    }
}

#Preview {
    QuickBlockCategoryView(category: .noSocial)
}
