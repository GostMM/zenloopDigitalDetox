//
//  CompactTimerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

struct CompactTimerView: View {
    let selectedConcentrationType: ConcentrationType
    let formattedDuration: String
    let hasSelectedApps: Bool
    let selectedAppsCount: Int
    let isIdle: Bool
    let selectedApps: FamilyActivitySelection
    let taskGoalsCount: Int

    let onEditConcentrationType: () -> Void
    let onEditDuration: () -> Void
    let onEditGoals: () -> Void
    let onEditApps: () -> Void
    let onStartSession: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Ligne 1: Type + Duration
            HStack(spacing: 8) {
                // Type de concentration
                Button(action: onEditConcentrationType) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedConcentrationType.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selectedConcentrationType.primaryColor)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("MODE")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.8)

                            Text(selectedConcentrationType.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedConcentrationType.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)

                // Duration
                Button(action: onEditDuration) {
                    VStack(spacing: 3) {
                        Text("TIME")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.8)

                        Text(formattedDuration)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.cyan.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 90)
            }

            // Ligne 2: Goals + Status
            HStack(spacing: 8) {
                // Goals
                Button(action: onEditGoals) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(taskGoalsCount > 0 ? .yellow : .white.opacity(0.3))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("GOALS")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.8)

                            Text(taskGoalsCount > 0 ? "\(taskGoalsCount) goals" : "Add goals")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(taskGoalsCount > 0 ? .white : .white.opacity(0.5))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke((taskGoalsCount > 0 ? Color.yellow : Color.white).opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)

                // Status indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill((hasSelectedApps ? Color.green : Color.orange).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke((hasSelectedApps ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: hasSelectedApps ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(hasSelectedApps ? .green : .orange)
                }
                .frame(width: 54)
            }

            // Ligne 3: Apps
            Button(action: onEditApps) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hasSelectedApps ? .purple : .orange)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("BLOCKED APPS")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.8)

                        Text(hasSelectedApps ? "\(selectedAppsCount) apps" : "Tap to select")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(hasSelectedApps ? .white : .orange)
                    }

                    Spacer()

                    if hasSelectedApps {
                        CompactAppIconsRow(selectedApps: selectedApps, maxToShow: 4)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke((hasSelectedApps ? Color.purple : Color.orange).opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Start button
            if hasSelectedApps && isIdle {
                Button(action: onStartSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))

                        Text(String(localized: "start_session"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [selectedConcentrationType.primaryColor, selectedConcentrationType.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .shadow(color: selectedConcentrationType.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
    }
}

// MARK: - Modern Config Card

struct ModernConfigCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icône en haut
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }

                // Valeur principale
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                // Label en bas
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.08),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Modern Apps Card

struct ModernAppsCard: View {
    let hasSelectedApps: Bool
    let selectedApps: FamilyActivitySelection
    let selectedAppsCount: Int
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icône
                ZStack {
                    Circle()
                        .fill((hasSelectedApps ? Color.purple : Color.orange).opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: hasSelectedApps ? "shield.checkered" : "shield.slash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hasSelectedApps ? .purple : .orange)
                }

                // Contenu
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "apps"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    if hasSelectedApps {
                        HStack(spacing: 6) {
                            Text("\(selectedAppsCount)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Text("selected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    } else {
                        Text("Tap to select")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Preview d'icônes ou placeholder
                if hasSelectedApps {
                    CompactAppIconsRow(selectedApps: selectedApps, maxToShow: 3)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                (hasSelectedApps ? Color.purple : Color.orange).opacity(0.08),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                (hasSelectedApps ? Color.purple : Color.orange).opacity(0.3),
                                (hasSelectedApps ? Color.purple : Color.orange).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .gridCellColumns(2)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Pulsating Chip (badge animé avec label intégré - LEGACY)

struct PulsatingChip: View {
    let label: String
    let icon: String
    let text: String
    let color: Color
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                // Label en haut
                Text(label)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)

                // Chip avec icône et valeur
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(text)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(isPulsing ? 0.25 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(isPulsing ? 0.5 : 0.3), lineWidth: 1)
            )
            .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Compact App Icons Row (affichage horizontal simple)

struct CompactAppIconsRow: View {
    let selectedApps: FamilyActivitySelection
    let maxToShow: Int

    var body: some View {
        HStack(spacing: -6) {
            let apps = Array(selectedApps.applicationTokens.prefix(maxToShow))
            let categories = Array(selectedApps.categoryTokens.prefix(maxToShow - apps.count))
            let allItems = apps.map { AppOrCategory.app($0) } + categories.map { AppOrCategory.category($0) }

            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                Group {
                    switch item {
                    case .app(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 14))
                            .frame(width: 24, height: 24)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                    case .category(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 14))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.purple.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.purple.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .purple.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
                .zIndex(Double(maxToShow - index))
            }
        }
    }
}

// MARK: - Config Button (legacy - kept for compatibility)

struct ConfigButton: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var showBadge: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(color)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(value)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 85)
            .background(
                ZStack {
                    // Gradient de fond subtil
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.15),
                                    color.opacity(0.05),
                                    .white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Bordure avec gradient
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .overlay(alignment: .topTrailing) {
                if showBadge {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .padding(7)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Apps Config Button (avec icônes en pile au coin)

struct AppsConfigButton: View {
    let hasSelectedApps: Bool
    let selectedApps: FamilyActivitySelection
    let selectedAppsCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Contenu principal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill((hasSelectedApps ? Color.cyan : Color.orange).opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: hasSelectedApps ? "shield.checkered" : "shield.slash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(hasSelectedApps ? .cyan : .orange)
                        }

                        Spacer()

                        // Espace pour la pile d'icônes
                        Color.clear
                            .frame(width: 60)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "apps"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)

                        if !hasSelectedApps {
                            Text(String(localized: "tap_to_select"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            // Afficher le nombre d'apps sélectionnées
                            Text("\(selectedAppsCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(minHeight: 85)

                // Pile d'icônes au coin supérieur droit
                if hasSelectedApps {
                    AppIconsStackCorner(selectedApps: selectedApps, totalCount: selectedAppsCount)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
            }
            .background(
                ZStack {
                    let buttonColor = hasSelectedApps ? Color.cyan : Color.orange

                    // Gradient de fond subtil
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    buttonColor.opacity(0.15),
                                    buttonColor.opacity(0.05),
                                    .white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Bordure avec gradient
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [buttonColor.opacity(0.4), buttonColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Icons Stack Corner (pile dans le coin)

struct AppIconsStackCorner: View {
    let selectedApps: FamilyActivitySelection
    let totalCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            let maxToShow = 3
            let apps = Array(selectedApps.applicationTokens.prefix(maxToShow))
            let categories = Array(selectedApps.categoryTokens.prefix(maxToShow - apps.count))
            let allItems = apps.map { AppOrCategory.app($0) } + categories.map { AppOrCategory.category($0) }

            // Créer un effet de pile vers le bas à droite
            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                let offsetX = CGFloat(index) * -8 // Vers la gauche
                let offsetY = CGFloat(index) * 8 // Vers le bas
                let rotation = Double(index) * -3 // Rotation négative pour effet naturel

                Group {
                    switch item {
                    case .app(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)

                    case .category(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.purple.opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.purple.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: .purple.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                .offset(x: offsetX, y: offsetY)
                .rotationEffect(.degrees(rotation))
                .zIndex(Double(maxToShow - index))
            }
        }
        .frame(width: 55, height: 55)
    }
}

// MARK: - App Icons Stack (effet de pile avec ombres) - Gardé pour compatibilité

struct AppIconsStack: View {
    let selectedApps: FamilyActivitySelection
    let totalCount: Int

    var body: some View {
        ZStack(alignment: .leading) {
            let maxToShow = 4
            let apps = Array(selectedApps.applicationTokens.prefix(maxToShow))
            let categories = Array(selectedApps.categoryTokens.prefix(maxToShow - apps.count))
            let allItems = apps.map { AppOrCategory.app($0) } + categories.map { AppOrCategory.category($0) }

            // Créer un effet de pile compact avec ombres
            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                let offset = CGFloat(index) * 14 // Décalage compact de 14pt
                let rotation = Double(index) * 2 // Légère rotation pour effet naturel

                Group {
                    switch item {
                    case .app(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(.clear) // Background transparent
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                    case .category(let token):
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.purple.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.purple.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .purple.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .offset(x: offset, y: CGFloat(index) * -1) // Légère élévation
                .rotationEffect(.degrees(rotation))
                .zIndex(Double(maxToShow - index)) // Les premières au-dessus
            }

            // Badge "+X" compact à la fin
            let totalItems = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
            let displayedItems = allItems.count

            if totalItems > displayedItems {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.cyan.opacity(0.2))
                        .frame(width: 36, height: 32)

                    Text("+\(totalItems - displayedItems)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .offset(x: CGFloat(displayedItems) * 14 + 4)
                .shadow(color: .cyan.opacity(0.2), radius: 4, x: 0, y: 2)
                .zIndex(-1)
            }
        }
        .frame(height: 32)
    }
}

// Helper enum pour gérer apps et catégories ensemble
private enum AppOrCategory {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
}
