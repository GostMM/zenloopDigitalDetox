//
//  StatsInsightsSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import DeviceActivity

struct StatsInsightsSection: View {
    let badgeManager: BadgeManager
    @ObservedObject var zenloopManager: ZenloopManager
    @StateObject private var appUsageManager = AppUsageManager.shared
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 20) { // Espacement plus compact
            // En-tête section plus aéré
            HStack {
                HStack(spacing: 12) {
                    // Icône pour Tes Progrès
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(width: 40, height: 40)
                        .background(.purple.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tes Progrès")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Vue d'ensemble")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
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
            
            // Grid de stats plus compacte
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ProgressStatCard(
                    icon: "flame.fill",
                    title: "Série Actuelle",
                    value: "\(zenloopManager.currentStreakCount)",
                    unit: "jours",
                    color: .orange,
                    trend: .up
                )
                
                ProgressStatCard(
                    icon: "clock.fill",
                    title: "Temps Économisé",
                    value: formatTotalTime(zenloopManager.totalSavedTime).value,
                    unit: formatTotalTime(zenloopManager.totalSavedTime).unit,
                    color: .blue,
                    trend: .up
                )
                
                ProgressStatCard(
                    icon: "trophy.fill",
                    title: "Défis Complétés",
                    value: "\(zenloopManager.completedChallengesTotal)",
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
            .onAppear {
                debugPrint("📊 [STATS] === StatsInsightsSection onAppear ===")
                debugPrint("📊 [STATS] isAuthorized: \(appUsageManager.isAuthorized)")
                debugPrint("📊 [STATS] isLoading: \(appUsageManager.isLoading)")
                debugPrint("📊 [STATS] Avant loadUsageData - Daily: \(appUsageManager.usageStats.dailyTotal)")
                debugPrint("📊 [STATS] Avant loadUsageData - Weekly: \(appUsageManager.usageStats.weeklyTotal)")
                
                // Forcer le chargement des données au chargement de la vue
                appUsageManager.loadUsageData()
                
                // Debug après chargement avec délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    debugPrint("📊 [STATS] === Après loadUsageData (1s délai) ===")
                    debugPrint("📊 [STATS] Daily total: \(appUsageManager.usageStats.dailyTotal)")
                    debugPrint("📊 [STATS] Weekly total: \(appUsageManager.usageStats.weeklyTotal)")
                    debugPrint("📊 [STATS] Top apps count: \(appUsageManager.usageStats.topApps.count)")
                    
                    // Debug des valeurs formatées
                    let dailyFormatted = appUsageManager.formatTimeForStats(appUsageManager.usageStats.dailyTotal)
                    debugPrint("📊 [STATS] Daily formatted: value='\(dailyFormatted.value)' unit='\(dailyFormatted.unit)'")
                    
                    let weeklyFormatted = appUsageManager.formatTimeForStats(appUsageManager.usageStats.weeklyTotal)
                    debugPrint("📊 [STATS] Weekly formatted: value='\(weeklyFormatted.value)' unit='\(weeklyFormatted.unit)'")
                    
                    // Vérifier si ce sont les valeurs par défaut (mock data)
                    if appUsageManager.usageStats.dailyTotal == 14400.0 && appUsageManager.usageStats.weeklyTotal == 100800.0 {
                        debugPrint("⚠️ [STATS] ATTENTION: Ces valeurs correspondent aux données MOCK (4h/28h)")
                        debugPrint("⚠️ [STATS] L'extension DeviceActivity ne fournit pas de vraies données")
                    } else {
                        debugPrint("✅ [STATS] Vraies données DeviceActivity détectées!")
                    }
                }
            }
            
            // Section badges récents (plus aérée)
            if !badgeManager.getUnlockedBadges().isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        HStack(spacing: 12) {
                            // Icône pour Derniers Badges
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yellow)
                                .frame(width: 36, height: 36)
                                .background(.yellow.opacity(0.15), in: Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Derniers Badges")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Tes dernières réussites")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
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
    
    private func formatTotalTime(_ seconds: TimeInterval) -> (value: String, unit: String) {
        let hours = Int(seconds) / 3600
        let value = hours < 100 ? "\(hours)" : "99+"
        return (value: value, unit: "heures")
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
        VStack(spacing: 12) { // Espacement interne plus compact
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16) // Padding plus compact
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

// MARK: - Top App Row

struct TopAppRowSimple: View {
    let app: AppUsageInfo
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rang avec couleur
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 24, height: 24)
                .background(rankColor.opacity(0.2), in: Circle())
            
            // Nom de l'app
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(app.bundleId)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Durée et indicateur productivité
            HStack(spacing: 8) {
                Text(app.formattedTime)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Indicateur productivité
                Image(systemName: app.isProductive ? "checkmark.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(app.isProductive ? .green : .orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
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