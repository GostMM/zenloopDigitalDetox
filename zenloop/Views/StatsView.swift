//
//  StatsView.swift
//  zenloop
//
//  Micro-nav (icônes 28pt) • ultra minimal — août 2025
//

import SwiftUI
import Charts
import DeviceActivity
import FamilyControls
import Foundation

// MARK: - Local aliases pour compatibilité
private typealias SRPCategory = SharedReportCategory
private typealias SRPDayPoint = SharedReportDayPoint

// NOTE: SharedActivityStore is now defined in SharedModels.swift for reuse

// MARK: - Design System Moderne
private enum DS {
    // Spacing parfait
    static let spacing: (xs: CGFloat, s: CGFloat, m: CGFloat, l: CGFloat, xl: CGFloat) = (6, 12, 20, 32, 48)
    static let padding: CGFloat = 16
    static let cardPadding: CGFloat = 20
    
    // Typography hiérarchie
    static let heroSize: CGFloat = 28
    static let titleSize: CGFloat = 20
    static let headlineSize: CGFloat = 16
    static let bodySize: CGFloat = 14
    static let captionSize: CGFloat = 12
    static let labelSize: CGFloat = 10
    
    // Rayons cohérents
    static let radius: (s: CGFloat, m: CGFloat, l: CGFloat, xl: CGFloat) = (8, 12, 16, 24)
    
    // Palette moderne wellness
    struct Color {
        // Textes et éléments principaux
        static let text = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.8)
        static let textTertiary = SwiftUI.Color.white.opacity(0.6)
        
        // Couleurs thématiques modernes
        static let screenTime = SwiftUI.Color(red: 0.3, green: 0.7, blue: 1.0)      // Bleu ciel
        static let focusTime = SwiftUI.Color(red: 0.2, green: 0.8, blue: 0.4)      // Vert nature
        static let savedTime = SwiftUI.Color(red: 1.0, green: 0.7, blue: 0.2)      // Orange doré
        static let productivity = SwiftUI.Color(red: 0.4, green: 0.6, blue: 1.0)   // Bleu productivité
        static let social = SwiftUI.Color(red: 0.9, green: 0.3, blue: 0.8)         // Rose social
        static let entertainment = SwiftUI.Color(red: 0.8, green: 0.4, blue: 1.0)  // Violet divertissement
        static let education = SwiftUI.Color(red: 0.2, green: 0.9, blue: 0.7)      // Turquoise éducation
        
        // Backgrounds et surfaces
        static let cardBg = SwiftUI.Color.white.opacity(0.08)
        static let cardBgActive = SwiftUI.Color.white.opacity(0.12)
        static let sectionBg = SwiftUI.Color.white.opacity(0.04)
        static let divider = SwiftUI.Color.white.opacity(0.12)
        
        // États et accents
        static let accent = SwiftUI.Color(red: 0.2, green: 0.8, blue: 1.0)
        static let success = SwiftUI.Color(red: 0.2, green: 0.9, blue: 0.4)
        static let warning = SwiftUI.Color(red: 1.0, green: 0.8, blue: 0.2)
        static let error = SwiftUI.Color(red: 1.0, green: 0.4, blue: 0.4)
    }
}

// MARK: - StatsView

struct StatsView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @StateObject private var screenTimeManager = RealScreenTimeManager()
    @StateObject private var store = SharedActivityStore()
    
    @State private var selectedPeriod: TimePeriod = .today
    @State private var reportInstanceID = UUID()
    @State private var hasInitiallyLoaded = false
    
    // Navigation dynamique
    @State private var activeSection: StatsSection = .apps
    @State private var showSections = false
    
    
    enum StatsSection: String, CaseIterable, Identifiable {
        case apps = "apps"
        case categories = "categories"
        case patterns = "patterns"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .apps: return String(localized: "applications")
            case .categories: return String(localized: "categories")
            case .patterns: return String(localized: "trends")
            }
        }
        
        var icon: String {
            switch self {
            case .apps: return "square.grid.3x3.fill"
            case .categories: return "folder.fill"
            case .patterns: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var color: Color {
            switch self {
            case .apps: return DS.Color.screenTime
            case .categories: return DS.Color.social
            case .patterns: return DS.Color.productivity
            }
        }
    }
    
    enum TimePeriod: String, CaseIterable, Identifiable {
        case today = "today", week = "7_days", month = "30_days"
        var id: String { rawValue }
        func dateInterval(now: Date = Date(), cal: Calendar = .current) -> DateInterval {
            switch self {
            case .today:
                return cal.dateInterval(of: .day, for: now)
                ?? .init(start: cal.startOfDay(for: now), end: now)
            case .week:
                let s = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)) ?? now
                return .init(start: s, end: now)
            case .month:
                let s = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: now)) ?? now
                return .init(start: s, end: now)
            }
        }
    }
    
    // Derived
    private var periodSeconds: Double { max(0, store.interval.end.timeIntervalSince(store.interval.start)) }
    private var offScreenSeconds: Double { max(0, periodSeconds - store.totalSeconds) }
    private var savedPct: Int { store.totalSeconds > 0 ? Int(round(100 * store.savedSeconds / store.totalSeconds)) : 0 }
    
    var body: some View {
        ZStack {
            OptimizedBackground(currentState: zenloopManager.currentState).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header moderne avec métriques importantes
                modernHeader
                
                // Navigation par onglets
                sectionTabs
                
                // Contenu de la section active
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: DS.spacing.m) {
                        if screenTimeManager.isAuthorized {
                            sectionContent
                                .padding(.top, DS.spacing.s)
                        } else {
                            unauthorizedView
                                .padding(.top, DS.spacing.xl)
                        }
                    }
                    .padding(.horizontal, DS.padding)
                    .padding(.bottom, DS.spacing.xl)
                }
            }
            
            // Extension invisible pour générer les données d'aujourd'hui
            DeviceActivityReport(screenTimeManager.reportContext, filter: screenTimeManager.currentFilter)
                .frame(width: 0, height: 0)
                .opacity(0)
                .id("totalactivity-\(reportInstanceID)")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { 
                showSections = true 
            }
            screenTimeManager.checkAuthorization()
            screenTimeManager.selectedPeriod = selectedPeriod
            
            if !hasInitiallyLoaded {
                hasInitiallyLoaded = true
                loadInitialData()
            } else {
                // Ne recharge que si nécessaire (pas trop récent)
                store.load()
            }
        }
        .onChange(of: selectedPeriod) { _, new in
            screenTimeManager.selectedPeriod = new
            refreshReport()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Moderne avec métrique swipeable
    private var modernHeader: some View {
        VStack(spacing: DS.spacing.m) {
            // Titre et contrôles
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "statistics"))
                        .font(.system(size: DS.heroSize, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Color.text)
                    
                    Text(formatPeriodRange())
                        .font(.system(size: DS.captionSize, weight: .medium))
                        .foregroundColor(DS.Color.textSecondary)
                }
                
                Spacer()
                
                // Sélecteur de période moderne
                periodSelector
                
                // Bouton refresh
                Button(action: refreshWithHaptic) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DS.bodySize, weight: .semibold))
                        .foregroundColor(DS.Color.text)
                        .frame(width: 36, height: 36)
                        .background(DS.Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius.s))
                }
            }
            
            // Métrique principale compacte avec vraies données
            DeviceActivityReport(screenTimeManager.metricsContext, filter: screenTimeManager.currentFilter)
                .id("metrics-\(reportInstanceID)")
                .frame(height: 110)
        }
        .padding(.horizontal, DS.padding)
        .padding(.top, DS.spacing.s)
        .opacity(showSections ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: showSections)
    }
    
    // MARK: - Sélecteur de période moderne
    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(periodLabel(period))
                        .font(.system(size: DS.labelSize, weight: .semibold))
                        .foregroundColor(selectedPeriod == period ? .black : DS.Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: DS.radius.s)
                                .fill(selectedPeriod == period ? DS.Color.text : Color.clear)
                        )
                }
                .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
            }
        }
        .padding(4)
        .background(DS.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius.s))
    }
    
    // MARK: - Onglets de navigation (plus bas, sans fond)
    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.spacing.s) {
                ForEach(StatsSection.allCases) { section in
                    SectionTab(
                        section: section,
                        isActive: activeSection == section,
                        action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activeSection = section
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DS.padding)
        }
        .padding(.top, DS.spacing.l) // Plus d'espace en haut
        .padding(.bottom, DS.spacing.s)
    }
    
    // MARK: - Contenu des sections
    @ViewBuilder
    private var sectionContent: some View {
        switch activeSection {
        case .apps:
            appsSection
        case .categories:
            categoriesSection
        case .patterns:
            patternsSection
        }
    }
    
    
    private var appsSection: some View {
        VStack(spacing: DS.spacing.m) {
            ModernCard(title: String(localized: "most_used_apps"), icon: "square.grid.3x3.fill", color: DS.Color.screenTime) {
                DeviceActivityReport(screenTimeManager.topAppsContext, filter: screenTimeManager.currentFilter)
                    .id("topapps-\(reportInstanceID)")
                    .frame(minHeight: 160)
            }
            
            ModernCard(title: String(localized: "apps_summary"), icon: "app.badge.fill", color: DS.Color.focusTime) {
                DeviceActivityReport(screenTimeManager.appSummaryContext, filter: screenTimeManager.currentFilter)
                    .id("appsummary-\(reportInstanceID)")
                    .frame(minHeight: 120)
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(spacing: DS.spacing.m) {
            ModernCard(title: String(localized: "categories_distribution"), icon: "chart.pie.fill", color: DS.Color.social) {
                DeviceActivityReport(screenTimeManager.categoryDistributionContext, filter: screenTimeManager.currentFilter)
                    .id("categories-\(reportInstanceID)")
                    .frame(minHeight: 180)
            }
            
            ModernCard(title: String(localized: "top_categories"), icon: "folder.badge.plus", color: DS.Color.entertainment) {
                DeviceActivityReport(screenTimeManager.topCategoriesCompactContext, filter: screenTimeManager.currentFilter)
                    .id("topcategories-\(reportInstanceID)")
                    .frame(minHeight: 100)
            }
        }
    }
    
    private var patternsSection: some View {
        VStack(spacing: DS.spacing.m) {
            ModernCard(title: String(localized: "daily_usage"), icon: "chart.bar.fill", color: DS.Color.productivity) {
                DeviceActivityReport(screenTimeManager.dailyUsageContext, filter: screenTimeManager.currentFilter)
                    .id("dailyusage-\(reportInstanceID)")
                    .frame(minHeight: 160)
            }
            
            ModernCard(title: String(localized: "weekday_vs_weekend"), icon: "calendar.badge.clock", color: DS.Color.accent) {
                DeviceActivityReport(screenTimeManager.timeComparisonContext, filter: screenTimeManager.currentFilter)
                    .id("timecomparison-\(reportInstanceID)")
                    .frame(minHeight: 140)
            }
        }
    }
    
    // MARK: - Vue non autorisée moderne
    private var unauthorizedView: some View {
        VStack(spacing: DS.spacing.l) {
            // Icône et titre
            VStack(spacing: DS.spacing.m) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(DS.Color.accent)
                
                VStack(spacing: DS.spacing.s) {
                    Text(String(localized: "unlock_statistics"))
                        .font(.system(size: DS.titleSize, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Color.text)
                    
                    Text(String(localized: "authorize_screen_time_access_description"))
                        .font(.system(size: DS.bodySize, weight: .medium))
                        .foregroundColor(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Bouton d'autorisation moderne
            Button {
                Task { await screenTimeManager.requestAuthorization() }
            } label: {
                HStack(spacing: DS.spacing.s) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: DS.bodySize, weight: .semibold))
                    
                    Text(String(localized: "authorize_access"))
                        .font(.system(size: DS.bodySize, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, DS.spacing.l)
                .padding(.vertical, DS.spacing.m)
                .background(DS.Color.text)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius.m))
                .shadow(color: DS.Color.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(DS.cardPadding)
        .background(
            LinearGradient(
                colors: [DS.Color.accent.opacity(0.1), DS.Color.cardBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius.l)
                .stroke(DS.Color.accent.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    private func periodLabel(_ period: TimePeriod) -> String {
        switch period {
        case .today: return String(localized: "today_short")
        case .week: return "7j"
        case .month: return "30j"
        }
    }
    private func refreshReport() { reportInstanceID = UUID() }
    
    private func refreshWithHaptic() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Un seul appel coordonné au lieu de multiples
        refreshReport()
        
        // Intelligent retry seulement si nécessaire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if store.totalSeconds == 0 && store.days.isEmpty {
                store.load(force: true) // Force si pas de données
                refreshReport()
            }
        }
    }
    
    private func toggleSection(_ sectionId: String) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            // Cette fonction n'est plus utilisée avec la nouvelle navigation
        }
    }
    
    private func calculateScreenTimeTrend() -> TrendDirection {
        guard store.days.count >= 2 else { return .neutral }
        let recent = store.days.suffix(3).reduce(0) { $0 + $1.seconds }
        let previous = store.days.dropLast(3).suffix(3).reduce(0) { $0 + $1.seconds }
        
        if recent > previous * 1.1 { return .negative }
        if recent < previous * 0.9 { return .positive }
        return .neutral
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: max(0, duration)) ?? "0m"
    }
    
    private func formatPeriodRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: store.interval.start)
        let end = formatter.string(from: store.interval.end)
        return start == end ? start : "\(start) - \(end)"
    }
    
    // Cette section n'est plus nécessaire - les métriques sont dans le header
    
    private func loadInitialData() {
        print("🚀 [STATS] Loading initial data...")
        
        // Chargement initial avec force
        store.load(force: true)
        
        // Rafraîchir le rapport pour déclencher les extensions
        refreshReport()
        
        // Si pas de données après chargement initial, retry avec report refresh
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s pour laisser temps aux extensions
            
            await MainActor.run {
                if store.totalSeconds == 0 && store.days.isEmpty {
                    print("🔄 [STATS] No data found - refreshing report and retrying")
                    refreshReport()
                    
                    // Attendre un peu puis recharger
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            store.load(force: true)
                        }
                    }
                }
            }
        }
    }
    private func lastUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
            .replacingOccurrences(of: String(localized: "ago_prefix"), with: String(localized: "updated_prefix"))
    }
    
    private func dateRange(_ i: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let s = formatter.string(from: i.start)
        let e = formatter.string(from: i.end)
        return s == e ? s : "\(s) – \(e)"
    }
}

// MARK: - Supporting Types
enum TrendDirection {
    case positive, negative, neutral
    
    var color: Color {
        switch self {
        case .positive: return DS.Color.success
        case .negative: return DS.Color.error
        case .neutral: return DS.Color.textTertiary
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "arrow.up.right"
        case .negative: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
}

enum DataSection: String, CaseIterable {
    case apps = "apps"
    case screenTime = "screen_time"
    case categories = "categories"
    
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    var icon: String {
        switch self {
        case .apps: return "apps.iphone"
        case .screenTime: return "clock.badge"
        case .categories: return "chart.pie"
        }
    }
    var context: String {
        switch self {
        case .apps: return "AppList"
        case .screenTime: return "ScreenTimeMetrics"
        case .categories: return "CategoryBreakdown"
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Animation Extensions
extension Animation {
    static func easeOutCubic(duration: Double) -> Animation {
        .timingCurve(0.33, 1, 0.68, 1, duration: duration)
    }
}

// MARK: - Nouveaux Composants Modernes

// MARK: - Cartes de métriques modernisées  
private struct ModernMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DS.spacing.s) {
            // Icône avec couleur thématique
            Image(systemName: icon)
                .font(.system(size: DS.bodySize, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DS.radius.s))
            
            // Valeur et titre sans ligne break
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: DS.headlineSize, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.system(size: DS.captionSize, weight: .medium))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.spacing.m)
        .background(
            LinearGradient(
                colors: [color.opacity(0.08), DS.Color.cardBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius.m)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Onglet de section
private struct SectionTab: View {
    let section: StatsView.StatsSection
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacing.s) {
                Image(systemName: section.icon)
                    .font(.system(size: DS.captionSize, weight: .semibold))
                    .foregroundColor(isActive ? .black : section.color)
                
                Text(section.title)
                    .font(.system(size: DS.bodySize, weight: .semibold))
                    .foregroundColor(isActive ? .black : DS.Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, DS.spacing.m)
            .padding(.vertical, DS.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: DS.radius.s)
                    .fill(isActive ? section.color : DS.Color.cardBg)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Carte moderne principale
private struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing.m) {
            // Header avec icône et titre
            HStack(spacing: DS.spacing.s) {
                Image(systemName: icon)
                    .font(.system(size: DS.bodySize, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: DS.headlineSize, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Spacer()
            }
            
            // Contenu
            content
        }
        .padding(DS.cardPadding)
        .background(DS.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius.l)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Insight rapide
private struct QuickInsight: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DS.spacing.s) {
            Image(systemName: icon)
                .font(.system(size: DS.captionSize, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: DS.bodySize, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Color.text)
                    .lineLimit(1)
                
                Text(title)
                    .font(.system(size: DS.labelSize, weight: .medium))
                    .foregroundColor(DS.Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.spacing.m)
        .background(DS.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius.s))
    }
}

// MARK: - Composant WeeklyPattern amélioré pour éviter les breaks
private struct WeeklyPattern: View {
    let days: [SharedActivityStore.DayPoint]
    
    var body: some View {
        if days.isEmpty {
            VStack(spacing: DS.spacing.s) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(DS.Color.textTertiary)
                
                Text(String(localized: "no_data_available"))
                    .font(.system(size: DS.captionSize, weight: .medium))
                    .foregroundColor(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            VStack(alignment: .leading, spacing: DS.spacing.s) {
                Text(String(localized: "last_7_days"))
                    .font(.system(size: DS.captionSize, weight: .semibold))
                    .foregroundColor(DS.Color.textSecondary)
                
                HStack(spacing: 6) {
                    ForEach(days.suffix(7), id: \.id) { day in
                        ModernDayColumn(
                            dayPoint: day,
                            maxValue: days.map(\.seconds).max() ?? 1
                        )
                    }
                }
                .frame(height: 60)
            }
        }
    }
}

private struct ModernDayColumn: View {
    let dayPoint: SharedActivityStore.DayPoint
    let maxValue: Double
    
    var body: some View {
        VStack(spacing: 4) {
            // Barre moderne
            RoundedRectangle(cornerRadius: 3)
                .fill(barColor)
                .frame(width: 16, height: max(6, 40 * heightRatio))
                .animation(.easeInOut(duration: 0.4), value: heightRatio)
            
            // Label du jour
            Text(dayLabel)
                .font(.system(size: DS.labelSize, weight: .medium))
                .foregroundColor(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var heightRatio: CGFloat {
        maxValue > 0 ? CGFloat(dayPoint.seconds / maxValue) : 0
    }
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: dayPoint.date).prefix(1))
    }
    
    private var barColor: Color {
        let hours = dayPoint.seconds / 3600
        switch hours {
        case 4...: return DS.Color.error
        case 2..<4: return DS.Color.warning
        case 1..<2: return DS.Color.accent
        default: return DS.Color.success
        }
    }
}


// MARK: - Screen Time Manager (optimisé)
final class RealScreenTimeManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var selectedPeriod: StatsView.TimePeriod = .today
    
    private let authorizationCenter = AuthorizationCenter.shared
    
    // All contexts used in StatsView - mapped 1:1 with zenloopactivity extension
    let reportContext = DeviceActivityReport.Context("TotalActivity")
    let metricsContext = DeviceActivityReport.Context("Metrics")
    let topAppsContext = DeviceActivityReport.Context("TopApps")
    let appSummaryContext = DeviceActivityReport.Context("AppSummary")
    let categoryDistributionContext = DeviceActivityReport.Context("CategoryDistribution")
    let topCategoriesCompactContext = DeviceActivityReport.Context("TopCategoriesCompact")
    let dailyUsageContext = DeviceActivityReport.Context("DailyUsage")
    let timeComparisonContext = DeviceActivityReport.Context("TimeComparison")
    
    var currentFilter: DeviceActivityFilter {
        let interval = selectedPeriod.dateInterval(now: Date(), cal: .current)
        return DeviceActivityFilter(segment: .daily(during: interval),
                                    users: .all,
                                    devices: .init([.iPhone, .iPad]))
    }
    
    func checkAuthorization() {
        switch authorizationCenter.authorizationStatus {
        case .approved: isAuthorized = true
        case .denied, .notDetermined: isAuthorized = false
        @unknown default: isAuthorized = false
        }
    }
    
    func requestAuthorization() async {
        do {
            try await authorizationCenter.requestAuthorization(for: .individual)
            await MainActor.run { self.isAuthorized = true }
        } catch {
            await MainActor.run { self.isAuthorized = false }
        }
    }
}



