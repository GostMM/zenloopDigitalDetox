//
//  DailyReportModal.swift
//  zenloop
//
//  Rapport quotidien d'utilisation - 3x par jour (matin, midi, soir)
//

import SwiftUI
import FamilyControls
import DeviceActivity
import os.log

// MARK: - Simple Time of Day enum

enum DailyTimeOfDay: String, CaseIterable {
    case morning, afternoon, evening
    
    var greeting: String {
        switch self {
        case .morning: return "Bonjour !"
        case .afternoon: return "Bon après-midi !"
        case .evening: return "Bonsoir !"
        }
    }
    
    var subtitle: String {
        switch self {
        case .morning: return "Comment commencer la journée du bon pied"
        case .afternoon: return "Votre bilan de mi-journée"
        case .evening: return "Récapitulatif de votre journée"
        }
    }
    
    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .afternoon: return "☀️"
        case .evening: return "🌙"
        }
    }
    
    var motivationalMessage: String {
        switch self {
        case .morning: return "Une nouvelle journée commence ! Définissez vos priorités et créez des moments sans écran."
        case .afternoon: return "Vous êtes à mi-parcours. Prenez une pause et reconnectez-vous avec le monde réel."
        case .evening: return "Bravo pour cette journée ! Réfléchissez à vos accomplissements et préparez demain."
        }
    }
    
    var actionTip: String {
        switch self {
        case .morning: return "💡 Conseil: Commencez par 30 minutes sans téléphone"
        case .afternoon: return "💡 Conseil: Faites une promenade de 10 minutes"
        case .evening: return "💡 Conseil: Éteignez les écrans 1h avant de dormir"
        }
    }
}

struct DailyReportModal: View {
    @Binding var isPresented: Bool
    let timeOfDay: DailyTimeOfDay
    
    @State private var showContent = false
    
    // Device Activity contexts - même que RealScreenTimeManager dans StatsView
    private let metricsContext = DeviceActivityReport.Context("Metrics")
    private let topCategoriesCompactContext = DeviceActivityReport.Context("TopCategoriesCompact")
    
    // Filter pour aujourd'hui - utilise la même logique que StatsView
    private var todayFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let interval = DateInterval(start: startOfToday, end: endOfToday)
        
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
    
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
            LinearGradient(
                colors: [Color.black, Color.gray.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Modal content
            VStack(spacing: 0) {
                headerSection
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: UI.sectionSpacing) {
                        // Section temps d'écran avec vraies données
                        realScreenTimeSection
                        
                        // Section top apps avec vraies données
                        realTopAppsSection
                        
                        // Message motivationnel
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
    
    // MARK: - Real Sections avec DeviceActivityReport
    
    private var realScreenTimeSection: some View {
        VStack(alignment: .leading, spacing: UI.itemSpacing) {
            sectionTitle(
                title: "Temps d'écran aujourd'hui",
                icon: "clock.fill",
                color: .cyan
            )
            
            // DeviceActivityReport pour les métriques réelles - même que StatsView
            DeviceActivityReport(metricsContext, filter: todayFilter)
                .frame(height: 100)
                .background(UI.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: UI.cornerRadius)
                        .stroke(UI.cardBorder, lineWidth: 1)
                )
        }
    }
    
    private var realTopAppsSection: some View {
        VStack(alignment: .leading, spacing: UI.itemSpacing) {
            sectionTitle(
                title: "Top 3 catégories aujourd'hui",
                icon: "apps.iphone",
                color: .orange
            )
            
            // DeviceActivityReport pour les catégories réelles - même que StatsView
            DeviceActivityReport(topCategoriesCompactContext, filter: todayFilter)
                .frame(height: 150)
                .background(UI.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: UI.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: UI.cornerRadius)
                        .stroke(UI.cardBorder, lineWidth: 1)
                )
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
            
            // Un seul bouton principal - plus propre
            Button(action: dismiss) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("J'ai vu mon rapport")
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
    
    
    private func openSettings() {
        // Simple action pour ouvrir les paramètres
        // L'utilisateur devra naviguer manuellement vers Screen Time
    }
}


#Preview {
    DailyReportModal(
        isPresented: .constant(true),
        timeOfDay: .morning
    )
    .preferredColorScheme(.dark)
}