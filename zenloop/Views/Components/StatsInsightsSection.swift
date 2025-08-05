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
                
                ProgressStatCard(
                    icon: "iphone",
                    title: "Temps Quotidien",
                    value: appUsageManager.usageStats.dailyTotal > 0 ? 
                        appUsageManager.formatTimeForStats(appUsageManager.usageStats.dailyTotal).value : "4h",
                    unit: appUsageManager.usageStats.dailyTotal > 0 ? 
                        appUsageManager.formatTimeForStats(appUsageManager.usageStats.dailyTotal).unit : "",
                    color: .mint,
                    trend: .down
                )
                
                ProgressStatCard(
                    icon: "calendar",
                    title: "Temps Hebdomadaire", 
                    value: appUsageManager.usageStats.weeklyTotal > 0 ? 
                        appUsageManager.formatTimeForStats(appUsageManager.usageStats.weeklyTotal).value : "28h",
                    unit: appUsageManager.usageStats.weeklyTotal > 0 ? 
                        appUsageManager.formatTimeForStats(appUsageManager.usageStats.weeklyTotal).unit : "",
                    color: .indigo,
                    trend: .down
                )
            }
            .padding(.horizontal, 24)
            .onAppear {
                // Forcer le chargement des données au chargement de la vue
                appUsageManager.loadUsageData()
                debugPrint("📊 [STATS] StatsInsightsSection loaded")
                debugPrint("📊 [STATS] Daily total: \(appUsageManager.usageStats.dailyTotal)")
                debugPrint("📊 [STATS] Top apps count: \(appUsageManager.usageStats.topApps.count)")
                
                // Debug des valeurs formatées
                let dailyFormatted = appUsageManager.formatTimeForStats(appUsageManager.usageStats.dailyTotal)
                debugPrint("📊 [STATS] Daily formatted: value='\(dailyFormatted.value)' unit='\(dailyFormatted.unit)'")
                
                let weeklyFormatted = appUsageManager.formatTimeForStats(appUsageManager.usageStats.weeklyTotal)
                debugPrint("📊 [STATS] Weekly formatted: value='\(weeklyFormatted.value)' unit='\(weeklyFormatted.unit)'")
            }
            
            // Section DeviceActivityReport (vraies données)
            if appUsageManager.isAuthorized {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Données Screen Time")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Données officielles iOS")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                    }
                    
                    // DeviceActivityReport intégré
                    DeviceActivityReport(
                        DeviceActivityReport.Context("TotalActivity"),
                        filter: DeviceActivityFilter(
                            segment: .daily(during: Calendar.current.dateInterval(of: .day, for: .now)!),
                            users: .all,
                            devices: .init([.iPhone])
                        )
                    )
                    .frame(height: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
            }
            
            // Section Top 3 Apps 
            if !appUsageManager.usageStats.topApps.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Top 3 Applications")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Votre temps d'écran quotidien")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        // Indicateur de productivité global
                        HStack(spacing: 4) {
                            Image(systemName: appUsageManager.usageStats.productivityPercentage > 50 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(appUsageManager.usageStats.productivityPercentage > 50 ? .green : .orange)
                            
                            Text("\(appUsageManager.usageStats.productivityPercentage)% productif")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(Array(appUsageManager.usageStats.topApps.enumerated()), id: \.element.id) { index, app in
                            TopAppRowSimple(app: app, rank: index + 1)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
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