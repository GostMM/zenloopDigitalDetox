//
//  StatsInsightsSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct StatsInsightsSection: View {
    let badgeManager: BadgeManager
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 28) { // Espacement plus généreux
            // En-tête section plus aéré
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tes Progrès")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Vue d'ensemble de tes performances")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button("Voir tout") {
                    // Action pour voir détails
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 24) // Padding plus généreux
            
            // Grid de stats avec plus d'espacement
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                ProgressStatCard(
                    icon: "flame.fill",
                    title: "Série Actuelle",
                    value: "\(zenloopManager.currentStreak)",
                    unit: "jours",
                    color: .orange,
                    trend: .up
                )
                
                ProgressStatCard(
                    icon: "clock.fill",
                    title: "Temps Total",
                    value: formatTotalTime(zenloopManager.totalFocusTime),
                    unit: "heures",
                    color: .blue,
                    trend: .stable
                )
                
                ProgressStatCard(
                    icon: "trophy.fill",
                    title: "Défis Complétés",
                    value: "\(zenloopManager.completedChallengesCount)",
                    unit: "sessions",
                    color: .yellow,
                    trend: .up
                )
                
                ProgressStatCard(
                    icon: "star.fill",
                    title: "Badges Gagnés",
                    value: "\(badgeManager.getUnlockedBadges().count)",
                    unit: "badges",
                    color: .purple,
                    trend: .up
                )
            }
            .padding(.horizontal, 24)
            
            // Section badges récents (plus aérée)
            if !badgeManager.getUnlockedBadges().isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Derniers Badges")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Tes dernières réussites")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button("Collection") {
                            // Action pour voir collection complète
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) { // Plus d'espacement entre badges
                            ForEach(Array(badgeManager.getUnlockedBadges().suffix(5)), id: \.id) { badge in
                                CompactBadgeCard(badge: badge)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, -24)
                }
                .padding(.horizontal, 24)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
    
    private func formatTotalTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        return hours < 100 ? "\(hours)" : "99+"
    }
}

struct ProgressStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    let trend: ProgressStatCard.TrendDirection
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) { // Plus d'espacement interne
            // Header plus aéré
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15), in: Circle())
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(trend.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(trend.color.opacity(0.15), in: Capsule())
            }
            
            // Contenu principal
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20) // Plus de padding
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20)) // Coins plus arrondis
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CompactBadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.color.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: badge.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(badge.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 50)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatsInsightsSection(
        badgeManager: BadgeManager.shared,
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}