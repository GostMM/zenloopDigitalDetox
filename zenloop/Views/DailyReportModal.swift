//
//  DailyReportModal.swift
//  zenloop
//
//  Rapport quotidien d'utilisation - 3x par jour (matin, midi, soir)
//

import SwiftUI
import FamilyControls

struct DailyReportModal: View {
    @Binding var isPresented: Bool
    let reportData: DailyActivityData?
    let timeOfDay: DailyReportManager.TimeOfDay
    
    @State private var showContent = false
    
    // MARK: - Design System
    enum UI {
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 20
        static let smallRadius: CGFloat = 12
        
        static let cardBackground = Color.white.opacity(0.08)
        static let cardBorder = Color.white.opacity(0.12)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.8)
        static let textTertiary = Color.white.opacity(0.6)
    }
    
    var body: some View {
        ZStack {
            // Background avec flou
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()
            
            // Modal content
            VStack(spacing: 0) {
                headerSection
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: UI.sectionSpacing) {
                        if let data = reportData {
                            screenTimeSection(data: data)
                            topAppsSection(data: data)
                        } else {
                            noDataSection
                        }
                        
                        motivationalMessageSection
                    }
                    .padding(.horizontal, UI.cardPadding)
                    .padding(.top, UI.sectionSpacing)
                    .padding(.bottom, 40)
                }
                
                bottomActionSection
            }
        }
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: UI.itemSpacing) {
            // Time period indicator
            HStack {
                timeOfDayIcon
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeOfDay.greeting)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(UI.textPrimary)
                    
                    Text(timeOfDay.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UI.textSecondary)
                }
                
                Spacer()
                
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(UI.textTertiary)
                }
            }
            .padding(.horizontal, UI.cardPadding)
            .padding(.top, 20)
            
            // Divider
            Rectangle()
                .fill(UI.cardBorder.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, UI.cardPadding)
        }
    }
    
    private var timeOfDayIcon: some View {
        Group {
            switch timeOfDay {
            case .morning:
                Text("🌅")
            case .afternoon:
                Text("☀️")
            case .evening:
                Text("🌙")
            }
        }
    }
    
    // MARK: - Screen Time Section
    
    private func screenTimeSection(data: DailyActivityData) -> some View {
        VStack(alignment: .leading, spacing: UI.itemSpacing) {
            sectionTitle(
                title: String(localized: "your_screen_time_today"),
                icon: "clock.fill",
                color: .cyan
            )
            
            // Temps total avec comparaison
            HStack(spacing: UI.itemSpacing) {
                // Temps principal
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.formattedTotalTime)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(UI.textPrimary)
                    
                    Text(String(localized: "total"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UI.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Spacer()
                
                // Moyenne quotidienne
                VStack(alignment: .trailing, spacing: 8) {
                    Text(data.formattedDailyAverage)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(UI.textSecondary)
                    
                    Text(String(localized: "daily_average"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UI.textTertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(UI.cardPadding)
            .background(UI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UI.cornerRadius)
                    .stroke(UI.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Top Apps Section
    
    private func topAppsSection(data: DailyActivityData) -> some View {
        VStack(alignment: .leading, spacing: UI.itemSpacing) {
            sectionTitle(
                title: String(localized: "top_3_apps_today"),
                icon: "apps.iphone",
                color: .orange
            )
            
            if data.topCategories.isEmpty {
                // État vide avec style
                VStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(UI.textTertiary)
                    
                    Text(String(localized: "no_usage_data"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(UI.textSecondary)
                    
                    Text(String(localized: "start_using_apps_to_see_data"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UI.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(UI.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: UI.cornerRadius)
                        .stroke(UI.cardBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(data.topCategories.prefix(3).enumerated()), id: \.offset) { index, category in
                        TopAppCard(
                            rank: index + 1,
                            category: category,
                            totalDuration: data.totalSeconds
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - No Data Section
    
    private var noDataSection: some View {
        VStack(spacing: UI.sectionSpacing) {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(UI.textTertiary)
                
                VStack(spacing: 8) {
                    Text(String(localized: "no_screen_time_data"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(UI.textSecondary)
                    
                    Text(String(localized: "enable_screen_time_for_detailed_insights"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(UI.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(UI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UI.cornerRadius)
                    .stroke(UI.cardBorder, lineWidth: 1)
            )
            
            // Action button
            Button(action: openSettings) {
                HStack(spacing: 12) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(String(localized: "open_settings"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: UI.smallRadius))
                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Motivational Message Section
    
    private var motivationalMessageSection: some View {
        VStack(alignment: .leading, spacing: UI.itemSpacing) {
            sectionTitle(
                title: String(localized: "daily_motivation"),
                icon: "heart.fill",
                color: .pink
            )
            
            HStack(spacing: UI.itemSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(timeOfDay.motivationalMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(UI.textSecondary)
                        .lineSpacing(4)
                    
                    Text(timeOfDay.actionTip)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UI.textTertiary)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                Text(timeOfDay.emoji)
                    .font(.system(size: 32))
            }
            .padding(UI.cardPadding)
            .background(UI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UI.cornerRadius)
                    .stroke(UI.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Bottom Action Section
    
    private var bottomActionSection: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(UI.cardBorder.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, UI.cardPadding)
            
            HStack(spacing: 16) {
                // Bouton "Plus tard"
                Button(action: dismiss) {
                    Text(String(localized: "maybe_later"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(UI.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(UI.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: UI.smallRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: UI.smallRadius)
                                .stroke(UI.cardBorder, lineWidth: 1)
                        )
                }
                
                // Bouton principal
                Button(action: startFocusSession) {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(String(localized: "start_focus_session"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: UI.smallRadius))
                    .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, UI.cardPadding)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionTitle(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(UI.textPrimary)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func dismiss() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func startFocusSession() {
        // Fermer le modal et lancer une session
        dismiss()
        // TODO: Déclencher une session focus
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Supporting Components

private struct TopAppCard: View {
    let rank: Int
    let category: ActivityCategoryData
    let totalDuration: Double
    
    private var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(round((category.seconds / totalDuration) * 100))
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .cyan
        case 3: return .mint
        default: return .gray
        }
    }
    
    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "📱"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rang avec emoji
            VStack(spacing: 4) {
                Text(rankEmoji)
                    .font(.system(size: 20))
                
                Text("#\(rank)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(rankColor)
            }
            .frame(width: 40)
            
            // Info catégorie
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DailyReportModal.UI.textPrimary)
                    .lineLimit(1)
                
                Text("\(category.appCount) \(category.appCount > 1 ? String(localized: "apps_plural") : String(localized: "app_singular"))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DailyReportModal.UI.textTertiary)
            }
            
            Spacer()
            
            // Temps et pourcentage
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(category.seconds))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DailyReportModal.UI.textPrimary)
                
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(rankColor)
            }
        }
        .padding(16)
        .background(DailyReportModal.UI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DailyReportModal.UI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DailyReportModal.UI.smallRadius)
                .stroke(DailyReportModal.UI.cardBorder, lineWidth: 1)
        )
    }
    
    private func formatTime(_ duration: Double) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

#Preview {
    DailyReportModal(
        isPresented: .constant(true),
        reportData: DailyActivityData(
            totalSeconds: 28800, // 8 heures
            averageDailySeconds: 25200, // 7 heures
            topCategories: [
                ActivityCategoryData(name: "Social Media", seconds: 10800, appCount: 3),
                ActivityCategoryData(name: "Productivity", seconds: 7200, appCount: 2),
                ActivityCategoryData(name: "Entertainment", seconds: 5400, appCount: 4)
            ],
            days: [],
            updatedAt: Date().timeIntervalSince1970
        ),
        timeOfDay: .morning
    )
    .preferredColorScheme(.dark)
}