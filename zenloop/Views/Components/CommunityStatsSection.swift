//
//  CommunityStatsSection.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import SwiftUI

struct CommunityStatsMainSection: View {
    @ObservedObject var communityManager: CommunityManager
    let showContent: Bool
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var leaderboard: [LeaderboardEntry] = []
    
    enum StatsPeriod: String, CaseIterable {
        case week = "Semaine"
        case month = "Mois"
        case allTime = "Total"
        
        var icon: String {
            switch self {
            case .week: return "calendar.badge.clock"
            case .month: return "calendar"
            case .allTime: return "infinity"
            }
        }
        
        var color: Color {
            switch self {
            case .week: return .green
            case .month: return .blue
            case .allTime: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header avec sélecteur de période
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Classement Communauté")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Vois où tu te situes parmi les champions du focus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                
                // Sélecteur de période
                StatsPeriodSelector(
                    selectedPeriod: $selectedPeriod,
                    onChange: { period in
                        loadLeaderboard(for: period)
                    }
                )
            }
            
            // Statistiques personnelles
            if let userStats = communityManager.userStats {
                PersonalStatsCard(
                    userStats: userStats,
                    period: selectedPeriod
                )
            }
            
            // Classement
            LeaderboardView(
                entries: leaderboard,
                currentUserId: communityManager.currentUserId,
                period: selectedPeriod
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
        .onAppear {
            loadLeaderboard(for: selectedPeriod)
        }
    }
    
    private func loadLeaderboard(for period: StatsPeriod) {
        // Simuler le chargement du classement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.leaderboard = generateMockLeaderboard(for: period)
        }
    }
    
    private func generateMockLeaderboard(for period: StatsPeriod) -> [LeaderboardEntry] {
        let usernames = [
            "ZenMaster99", "FocusNinja77", "CalmWarrior", "MindfulSage", "DeepThought42",
            "ZenWolf88", "SereneEagle", "QuietStorm", "PeacefulDragon", "WiseOtter",
            "ClearMind", "SteadyRiver", "BrightLotus", "FreshWind", "StillMountain"
        ]
        
        let badges = ["👑", "🥇", "🥈", "🥉", "🏅", "🌟", "💎", "⭐", "🔥", "💪", "🧠", "🎯", "✨", "🚀", "🏆"]
        
        let basePoints = period == .week ? 50 : period == .month ? 200 : 1000
        
        return usernames.enumerated().map { index, username in
            let points = basePoints + Int.random(in: -30...150) - (index * 10)
            let completedChallenges = Int.random(in: 1...(period == .week ? 5 : period == .month ? 15 : 50))
            let badge = badges.randomElement() ?? "🏅"
            
            return LeaderboardEntry(
                id: "user_\(index)",
                username: username,
                rank: index + 1,
                points: max(points, 10),
                completedChallenges: completedChallenges,
                badge: badge,
                isCurrentUser: username == communityManager.currentUsername
            )
        }
        .sorted { $0.points > $1.points }
        .enumerated()
        .map { index, entry in
            LeaderboardEntry(
                id: entry.id,
                username: entry.username,
                rank: index + 1,
                points: entry.points,
                completedChallenges: entry.completedChallenges,
                badge: entry.badge,
                isCurrentUser: entry.isCurrentUser
            )
        }
    }
}

// MARK: - Stats Period Selector

struct StatsPeriodSelector: View {
    @Binding var selectedPeriod: CommunityStatsMainSection.StatsPeriod
    let onChange: (CommunityStatsMainSection.StatsPeriod) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(CommunityStatsMainSection.StatsPeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedPeriod = period
                        onChange(period)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: period.icon)
                            .font(.system(size: 12, weight: selectedPeriod == period ? .bold : .medium))
                        
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: selectedPeriod == period ? .semibold : .medium))
                    }
                    .foregroundColor(selectedPeriod == period ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        selectedPeriod == period ?
                            AnyView(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(period.color.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(period.color.opacity(0.4), lineWidth: 1)
                                    )
                            ) :
                            AnyView(Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Personal Stats Card

struct PersonalStatsCard: View {
    let userStats: CommunityUserStats
    let period: CommunityStatsMainSection.StatsPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tes performances")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(period.rawValue.lowercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(period.color)
                }
                
                Spacer()
                
                // Badge personnel
                HStack(spacing: 6) {
                    if !userStats.badges.isEmpty {
                        Text(userStats.badges.last ?? "🏅")
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("#\(userStats.rank)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("classement")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Statistiques
            HStack(spacing: 20) {
                PersonalStatItem(
                    icon: "star.fill",
                    value: "\(userStats.totalPoints)",
                    label: "Points",
                    color: .yellow
                )
                
                PersonalStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(userStats.completedChallenges)",
                    label: "Défis",
                    color: .green
                )
                
                PersonalStatItem(
                    icon: "trophy.fill",
                    value: "\(userStats.badges.count)",
                    label: "Badges",
                    color: .orange
                )
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [period.color.opacity(0.2), period.color.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(period.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: period.color.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Personal Stat Item

struct PersonalStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Leaderboard View

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String
    let period: CommunityStatsMainSection.StatsPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Classement")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(entries.count) participants")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Top 3 podium
            if entries.count >= 3 {
                PodiumView(
                    entries: Array(entries.prefix(3)),
                    period: period
                )
            }
            
            // Liste des autres positions
            VStack(spacing: 8) {
                ForEach(entries.dropFirst(3).prefix(7), id: \.id) { entry in
                    LeaderboardRowView(
                        entry: entry,
                        period: period
                    )
                }
                
                // Indication s'il y a plus d'utilisateurs
                if entries.count > 10 {
                    Text("... et \(entries.count - 10) autres participants")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Podium View

struct PodiumView: View {
    let entries: [LeaderboardEntry]
    let period: CommunityStatsMainSection.StatsPeriod
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2ème place
            if entries.count > 1 {
                PodiumPositionView(
                    entry: entries[1],
                    height: 60,
                    color: PodiumColor.silver,
                    period: period
                )
            }
            
            // 1ère place
            if !entries.isEmpty {
                PodiumPositionView(
                    entry: entries[0],
                    height: 80,
                    color: PodiumColor.gold,
                    period: period
                )
            }
            
            // 3ème place
            if entries.count > 2 {
                PodiumPositionView(
                    entry: entries[2],
                    height: 50,
                    color: PodiumColor.bronze,
                    period: period
                )
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Podium Position View

struct PodiumPositionView: View {
    let entry: LeaderboardEntry
    let height: CGFloat
    let color: PodiumColor
    let period: CommunityStatsMainSection.StatsPeriod
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar + badge
            ZStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.swiftUIColor.opacity(0.8), color.swiftUIColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(String(entry.username.prefix(2)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2)
                )
                
                // Badge de position
                Text(entry.badge)
                    .font(.system(size: 16))
                    .offset(x: 18, y: -18)
            }
            
            // Nom et points
            VStack(spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(entry.points) pts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color.swiftUIColor)
            }
            
            // Piédestal
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color.swiftUIColor.opacity(0.6), color.swiftUIColor.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: height)
                .overlay(
                    Rectangle()
                        .stroke(.white.opacity(0.2), lineWidth: 1),
                    alignment: .top
                )
        }
    }
}

// MARK: - Leaderboard Row View

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let period: CommunityStatsMainSection.StatsPeriod
    
    var body: some View {
        HStack(spacing: 12) {
            // Rang
            Text("#\(entry.rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(entry.isCurrentUser ? period.color : .white.opacity(0.7))
                .frame(width: 32, alignment: .leading)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor.opacity(0.8), avatarColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Text(String(entry.username.prefix(2)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(entry.isCurrentUser ? period.color : .clear, lineWidth: 2)
            )
            
            // Nom d'utilisateur
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.system(size: 14, weight: entry.isCurrentUser ? .bold : .semibold))
                        .foregroundColor(entry.isCurrentUser ? period.color : .white)
                    
                    if entry.isCurrentUser {
                        Text("(Toi)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(period.color.opacity(0.8))
                    }
                }
                
                Text("\(entry.completedChallenges) défis")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Badge et points
            HStack(spacing: 8) {
                Text(entry.badge)
                    .font(.system(size: 16))
                
                Text("\(entry.points)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(entry.isCurrentUser ? period.color : .white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            entry.isCurrentUser ?
                AnyView(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(period.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(period.color.opacity(0.3), lineWidth: 1)
                        )
                ) :
                AnyView(Color.clear)
        )
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]
        let hash = abs(entry.username.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Leaderboard Entry Model

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let rank: Int
    let points: Int
    let completedChallenges: Int
    let badge: String
    let isCurrentUser: Bool
}

// MARK: - Podium Colors

enum PodiumColor {
    case gold, silver, bronze
    
    var swiftUIColor: Color {
        switch self {
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }
}

#Preview {
    CommunityStatsMainSection(
        communityManager: CommunityManager.shared,
        showContent: true
    )
    .background(Color.black)
}