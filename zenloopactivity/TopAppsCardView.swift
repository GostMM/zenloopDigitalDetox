//
//  TopAppsCardView.swift
//  zenloopactivity
//
//  Card des 3 apps les plus utilisées aujourd'hui avec style TimerCard
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct TopAppsCardView: View {
    let apps: [ExtensionAppUsage]  // Top 3 apps
    let onRestrict: (ExtensionAppUsage, RestrictionType) -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = true  // Expanded par défaut
    @State private var selectedApp: ExtensionAppUsage?

    enum RestrictionType {
        case shield
        case hide
    }

    var body: some View {
        VStack(spacing: 0) {
            // Vue compacte
            compactView

            // Vue détaillée (expandable)
            if isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity)  // Toute la largeur
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 24 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? 24 : 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)  // Marge des bords
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Compact View

    private var compactView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text("Apps les Plus Utilisées")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Aujourd'hui")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        if !apps.isEmpty {
                            Text("• \(apps.count) apps")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.cyan.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Bouton fermer
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)

            if apps.isEmpty {
                emptyStateView
            } else {
                topAppsList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white.opacity(0.3))

            Text("Aucune donnée aujourd'hui")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var topAppsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                topAppRow(app: app, rank: index + 1)

                if index < apps.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func topAppRow(app: ExtensionAppUsage, rank: Int) -> some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(for: rank).opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor(for: rank))
            }

            // App icon (vraie icône)
            #if os(iOS)
            Label(app.token)
                .labelStyle(.iconOnly)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            #endif

            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(formatDuration(app.duration))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Shield button
                Button(action: {
                    onRestrict(app, .shield)
                }) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.orange.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Hide button
                Button(action: {
                    onRestrict(app, .hide)
                }) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.red.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .cyan
        case 3: return .purple
        default: return .gray
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return "< 1min"
        }
    }
}
