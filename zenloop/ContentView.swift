//
//  ContentView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import SwiftUI
import FamilyControls

// MARK: - Navigation Notifications

extension Notification.Name {
    static let navigateToHome = Notification.Name("navigateToHome")
}

struct ContentView: View {
    @StateObject private var zenloopManager = ZenloopManager.shared
    @State private var showOnboarding = true
    @State private var isOnboardingComplete = false
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            if showOnboarding && !isOnboardingComplete {
                OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                mainInterface
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showOnboarding)
        .onAppear {
            zenloopManager.initialize()
            
            // Vérifier si c'est le premier lancement
            if UserDefaults.standard.bool(forKey: "has_completed_onboarding") {
                showOnboarding = false
                isOnboardingComplete = true
            }
        }
        .onChange(of: isOnboardingComplete) { _, isComplete in
            if isComplete {
                UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
                showOnboarding = false
            }
        }
    }
    
    private var mainInterface: some View {
        TabView(selection: $selectedTab) {
            // Accueil - Vue principale avec état adaptatif
            HomeView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Accueil")
                }
                .tag(0)
            
            // Défis - Nouvelle interface défis
            ModernChallengesView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "target" : "target")
                    Text("Défis")
                }
                .tag(1)
            
            // Stats - Vue statistiques
            StatsView()
                .environmentObject(zenloopManager)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    Text("Stats")
                }
                .tag(2)
        }
        .tint(.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            // Navigation automatique vers l'onglet Home
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = 0
            }
        }
    }
}

// MARK: - Vue Accueil
// HomeView est maintenant dans Views/HomeView.swift

// MARK: - Vue Stats

struct StatsView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Stats principales
                        statsOverview
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Historique complet
                        fullActivityHistory
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Statistiques")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var statsOverview: some View {
        VStack(spacing: 16) {
            Text("Vue d'ensemble")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                LegacyStatCard(
                    title: "Défis terminés",
                    value: "\(completedChallengesCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                LegacyStatCard(
                    title: "Temps total",
                    value: totalFocusTime,
                    icon: "clock.fill",
                    color: .blue
                )
                
                LegacyStatCard(
                    title: "Série actuelle",
                    value: "\(currentStreak) jours",
                    icon: "flame.fill",
                    color: .orange
                )
                
                LegacyStatCard(
                    title: "Cette semaine",
                    value: "\(weeklyCount) défis",
                    icon: "calendar",
                    color: .purple
                )
            }
        }
    }
    
    private var fullActivityHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historique complet")
                .font(.title2)
                .fontWeight(.semibold)
            
            if zenloopManager.recentActivity.isEmpty {
                EmptyActivityView()
                    .padding(.vertical, 40)
            } else {
                ForEach(zenloopManager.recentActivity) { activity in
                    LegacyActivityRow(activity: activity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var completedChallengesCount: Int {
        zenloopManager.recentActivity.filter { $0.type == .challengeCompleted }.count
    }
    
    private var totalFocusTime: String {
        let totalSeconds = zenloopManager.recentActivity
            .compactMap { $0.duration }
            .reduce(0, +)
        
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var currentStreak: Int {
        // Calcul simplifié du streak
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()
        
        for activity in zenloopManager.recentActivity.reversed() {
            if activity.type == .challengeCompleted {
                if calendar.isDate(activity.timestamp, inSameDayAs: currentDate) {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            }
        }
        
        return streak
    }
    
    private var weeklyCount: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        return zenloopManager.recentActivity.filter { activity in
            activity.type == .challengeCompleted && activity.timestamp >= weekAgo
        }.count
    }
}

// MARK: - Supporting Views

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Aucune activité")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Lance ton premier défi pour voir ton activité ici")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct LegacyStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LegacyActivityRow: View {
    let activity: ActivityRecord
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activityIcon)
                .font(.system(size: 14))
                .foregroundColor(activityColor)
                .frame(width: 30, height: 30)
                .background(activityColor.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(formatTime(activity.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let duration = activity.duration {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(activityTypeText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(activityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(activityColor.opacity(0.1), in: Capsule())
        }
    }
    
    private var activityIcon: String {
        switch activity.type {
        case .challengeStarted: return "play.circle"
        case .challengeCompleted: return "checkmark.circle"
        case .challengePaused: return "pause.circle"
        case .challengeResumed: return "arrow.clockwise.circle"
        case .challengeStopped: return "stop.circle"
        }
    }
    
    private var activityColor: Color {
        switch activity.type {
        case .challengeStarted: return .blue
        case .challengeCompleted: return .green
        case .challengePaused: return .orange
        case .challengeResumed: return .cyan
        case .challengeStopped: return .red
        }
    }
    
    private var activityTypeText: String {
        switch activity.type {
        case .challengeStarted: return "DÉBUT"
        case .challengeCompleted: return "FINI"
        case .challengePaused: return "PAUSE"
        case .challengeResumed: return "REPRISE"
        case .challengeStopped: return "ARRÊT"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "Aujourd'hui \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "Hier \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "dd/MM HH:mm"
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h\(remainingMinutes > 0 ? "\(remainingMinutes)m" : "")"
        }
    }
}

#Preview {
    ContentView()
}