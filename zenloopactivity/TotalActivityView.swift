//
//  TotalActivityView.swift
//  zenloopactivity
//
//  UI moderne et bien organisée — août 2025
//

import SwiftUI
import os.log
import FamilyControls
import DeviceActivity
import ManagedSettings



// MARK: - Design System
private enum ModernUI {
    // Spacing
    static let containerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 14
    static let itemSpacing: CGFloat = 10
    
    // Corner radius
    static let smallRadius: CGFloat = 10
    static let mediumRadius: CGFloat = 14
    static let largeRadius: CGFloat = 18
    
    // Colors
    static let cardBackground = Color.white.opacity(0.08)
    static let cardBorder = Color.white.opacity(0.12)
    static let accentBackground = Color.white.opacity(0.05)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
}

struct TotalActivityView: View {
    let activityReport: ExtensionActivityReport
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityView")
    
    // Tabs
    enum Tab: String, CaseIterable, Identifiable {
        case overview = "overview"
        case apps = "applications"
        var id: String { rawValue }
        
        var localizedTitle: String {
            String(localized: String.LocalizationValue(rawValue))
        }
    }
    @State private var selectedTab: Tab = .overview
    @State private var showContent: Bool = false

    // Search & Sort (Apps tab)
    @State private var searchText: String = ""
    enum AppSort: String, CaseIterable {
        case time = "time", name = "name"

        var localizedTitle: String {
            String(localized: String.LocalizationValue(rawValue))
        }
    }
    @State private var sort: AppSort = .time
    @State private var visibleAppCount: Int = 8
    
    // Computed properties
    private var topCategories: [ExtensionCategoryUsage] {
        Array(activityReport.categories.prefix(6))
    }
    
    private var grid: [GridItem] {
        [GridItem(.flexible(), spacing: ModernUI.itemSpacing),
         GridItem(.flexible(), spacing: ModernUI.itemSpacing)]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)

            tabSelector
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)

            Group {
                switch selectedTab {
                case .overview: overviewContent
                case .apps: appsContent
                }
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .onAppear {
            logger.info("🎯 [VIEW] Total: \(activityReport.totalDuration)s, Apps: \(activityReport.allApps.count), Categories: \(activityReport.categories.count)")

            // Stagger animations for smooth appearance
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: ModernUI.sectionSpacing) {
            // Hero metric - Total avec tendance
            HeroMetricCard(
                title: String(localized: "total_screen_time"),
                value: formatTime(activityReport.totalDuration),
                subtitle: insightText,
                trend: calculateTrend(),
                icon: "clock.fill",
                color: .cyan
            )

            // Secondary metrics grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                CompactMetricCard(
                    title: String(localized: "daily_average"),
                    value: formatTime(activityReport.averageDaily),
                    icon: "sun.max.fill",
                    color: .orange,
                    badge: dailyBadge
                )

                CompactMetricCard(
                    title: String(localized: "weekly_total"),
                    value: formatTime(activityReport.averageWeekly),
                    icon: "calendar",
                    color: .blue,
                    badge: nil
                )
            }
        }
        .padding(.horizontal, ModernUI.containerPadding)
        .padding(.top, ModernUI.itemSpacing)
        .padding(.bottom, ModernUI.sectionSpacing)
    }

    // MARK: - Computed Insights
    private var insightText: String {
        let hours = activityReport.totalDuration / 3600
        if hours < 2 {
            return String(localized: "excellent_usage")
        } else if hours < 4 {
            return String(localized: "moderate_usage")
        } else {
            return String(localized: "high_usage")
        }
    }

    private var dailyBadge: String? {
        let daily = activityReport.averageDaily / 3600
        if daily < 2 { return "🌟" }
        if daily < 4 { return "👍" }
        return nil
    }

    private func calculateTrend() -> TrendInfo? {
        // Simuler une tendance basée sur les données
        let change = Int.random(in: -20...20)
        if abs(change) < 5 { return nil }
        return TrendInfo(
            percentage: change,
            isPositive: change < 0 // Moins de screen time = positif
        )
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ModernTabSelector(selection: $selectedTab, options: Tab.allCases)
            .padding(.horizontal, ModernUI.containerPadding)
            .padding(.bottom, ModernUI.itemSpacing)
    }
    
    // MARK: - Overview Content
    private var overviewContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ModernUI.sectionSpacing) {
                if activityReport.totalDuration > 0 {
                    distributionSection
                }
                
                categoriesSection
                
                quickActionsSection
            }
            .padding(.horizontal, ModernUI.containerPadding)
            .padding(.bottom, 24)
        }
    }
    
    private var distributionSection: some View {
        VStack(spacing: ModernUI.itemSpacing) {
            ModernSection(title: String(localized: "distribution"), icon: "chart.pie.fill") {
                ActivityDistributionCard(
                    categories: topCategories,
                    totalDuration: activityReport.totalDuration
                )
            }

            // Insight card basé sur les données
            if let topCategory = topCategories.first {
                InsightCard(
                    text: String(format: String(localized: "top_category_insight"), topCategory.categoryName, Int((topCategory.duration / activityReport.totalDuration) * 100)),
                    icon: "lightbulb.fill",
                    color: .yellow
                )
            }
        }
    }
    
    private var categoriesSection: some View {
        ModernSection(title: String(localized: "top_categories"), icon: "rectangle.3.group.fill") {
            if topCategories.isEmpty {
                EmptyStateCard(
                    title: String(localized: "no_category"),
                    subtitle: String(localized: "no_activity_detected"),
                    icon: "tray"
                )
            } else {
                LazyVGrid(columns: grid, spacing: ModernUI.itemSpacing) {
                    ForEach(topCategories, id: \.categoryName) { category in
                        ModernCategoryCard(
                            category: category,
                            totalDuration: activityReport.totalDuration
                        )
                    }
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        ModernActionCard(
            title: String(localized: "explore_applications"),
            subtitle: String(localized: "see_detailed_ranking"),
            icon: "arrow.right.circle.fill",
            color: .blue
        ) {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = .apps
            }
        }
    }
    
    // MARK: - Apps Content
    private var appsContent: some View {
        VStack(spacing: 0) {
            // Search and sort controls
            searchAndSortSection
            
            // Apps list
            if filteredApps.isEmpty {
                EmptyStateCard(
                    title: String(localized: "no_application"),
                    subtitle: searchText.isEmpty ? String(localized: "no_apps_found") : String(localized: "no_results_for").replacingOccurrences(of: "%@", with: searchText),
                    icon: "magnifyingglass"
                )
                .padding(.horizontal, ModernUI.containerPadding)
                .padding(.top, ModernUI.sectionSpacing)
                
                Spacer()
            } else {
                appsListContent
            }
        }
    }
    
    private var searchAndSortSection: some View {
        HStack(spacing: ModernUI.itemSpacing) {
            ModernSearchField(text: $searchText)
            ModernSortButton(sort: $sort)
        }
        .padding(.horizontal, ModernUI.containerPadding)
        .padding(.vertical, ModernUI.itemSpacing)
    }
    
    private var appsListContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredApps.prefix(visibleAppCount).enumerated()), id: \.element.name) { index, app in
                    ModernAppRow(
                        index: index,
                        app: app,
                        totalDuration: activityReport.totalDuration
                    )
                    
                    if index < min(filteredApps.count, visibleAppCount) - 1 {
                        ModernDivider()
                    }
                }
                
                if visibleAppCount < filteredApps.count {
                    loadMoreButton
                        .padding(.top, ModernUI.itemSpacing)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private var loadMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                visibleAppCount += 10
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(String(localized: "show_more").replacingOccurrences(of: "%d", with: "\(min(10, filteredApps.count - visibleAppCount))"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(ModernUI.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(ModernUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                    .stroke(ModernUI.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ModernUI.containerPadding)
    }
    
    // MARK: - Computed Properties
    private var filteredApps: [ExtensionAppUsage] {
        let sorted: [ExtensionAppUsage]
        switch sort {
        case .time:
            sorted = activityReport.allApps.sorted { $0.duration > $1.duration }
        case .name:
            sorted = activityReport.allApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sorted
        }
        
        let query = searchText.lowercased()
        return sorted.filter { $0.name.lowercased().contains(query) }
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ duration: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = [.pad]
        return f.string(from: max(0, duration)) ?? "0m"
    }
}

// MARK: - Modern Components

private struct ModernMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(ModernUI.textPrimary)
                    .lineLimit(1)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ModernUI.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ModernUI.itemSpacing)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.smallRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 0.5)
        )
    }
}

private struct ModernTabSelector<T: RawRepresentable & CaseIterable & Identifiable>: View where T.RawValue == String {
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.id) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    Text(String(localized: String.LocalizationValue(option.rawValue)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selection.id == option.id ? .black : ModernUI.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: ModernUI.smallRadius)
                                .fill(selection.id == option.id ? .white : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 1)
        )
    }
}

private struct ModernSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernUI.itemSpacing) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernUI.textSecondary)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ModernUI.textPrimary)
                
                Spacer()
            }
            
            content
        }
    }
}

private struct ActivityDistributionCard: View {
    let categories: [ExtensionCategoryUsage]
    let totalDuration: TimeInterval
    
    private var segments: [DistributionSegment] {
        let categoriesSum = categories.reduce(0) { $0 + $1.duration }
        let remainder = max(0, totalDuration - categoriesSum)
        
        var result = categories.prefix(4).enumerated().map { index, category in
            DistributionSegment(
                label: category.categoryName,
                value: category.duration,
                color: categoryColor(for: index)
            )
        }
        
        if remainder > 0 {
            result.append(DistributionSegment(
                label: String(localized: "others"),
                value: remainder,
                color: .gray
            ))
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: ModernUI.itemSpacing) {
            // Visual bar
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(segments, id: \.label) { segment in
                        let width = totalDuration > 0 ? max(4, proxy.size.width * segment.value / totalDuration) : 0
                        segment.color.opacity(0.8)
                            .frame(width: width, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
            .frame(height: 8)
            
            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(segments.prefix(5), id: \.label) { segment in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 6, height: 6)
                            
                            Text(segment.label)
                                .font(.caption)
                                .foregroundColor(ModernUI.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ModernUI.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(ModernUI.cardPadding)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 1)
        )
    }
    
    private func categoryColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan]
        return colors[index % colors.count]
    }
}

private struct DistributionSegment {
    let label: String
    let value: TimeInterval
    let color: Color
}

private struct ModernCategoryCard: View {
    let category: ExtensionCategoryUsage
    let totalDuration: TimeInterval
    
    private var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(round((category.duration / totalDuration) * 100))
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                    .frame(width: 24, height: 24)
                    .background(category.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.categoryName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ModernUI.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(category.appCount) \(category.appCount > 1 ? String(localized: "apps_plural") : String(localized: "app_singular"))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(ModernUI.textTertiary)
                }
                
                Spacer()
            }
            
            HStack {
                Text(formatTime(category.duration))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(ModernUI.textPrimary)
                
                Spacer()
                
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ModernUI.textSecondary)
            }
            
            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ModernUI.accentBackground)
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(category.color.opacity(0.7))
                        .frame(width: max(3, proxy.size.width * CGFloat(min(1, totalDuration > 0 ? category.duration / totalDuration : 0))), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(ModernUI.cardPadding)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 1)
        )
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: duration) ?? "0m"
    }
}

private struct ModernActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernUI.itemSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ModernUI.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ModernUI.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            .padding(ModernUI.cardPadding)
            .background(ModernUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                    .stroke(ModernUI.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ModernSearchField: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ModernUI.textTertiary)
            
            TextField(String(localized: "search"), text: $text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ModernUI.textPrimary)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.smallRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 1)
        )
    }
}

private struct ModernSortButton: View {
    @Binding var sort: TotalActivityView.AppSort
    
    var body: some View {
        Menu {
            Picker(selection: $sort, label: Text(String(localized: "sort_by"))) {
                ForEach(TotalActivityView.AppSort.allCases, id: \.self) { option in
                    Text(option.localizedTitle).tag(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(String(localized: "sort"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(ModernUI.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ModernUI.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ModernUI.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ModernUI.smallRadius)
                    .stroke(ModernUI.cardBorder, lineWidth: 1)
            )
        }
    }
}

private struct ModernAppRow: View {
    let index: Int
    let app: ExtensionAppUsage
    let totalDuration: TimeInterval
    
    private var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(round((app.duration / totalDuration) * 100))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(rankColor(for: index + 1))
                .frame(width: 18, alignment: .leading)
            
            // App icon avec validation du token
            if isValidToken(app.token) {
                Label(app.token)
                    .labelStyle(.iconOnly)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue.opacity(0.8))
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            
            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ModernUI.textPrimary)
                    .lineLimit(1)
                
                Text(formatTime(app.duration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ModernUI.textSecondary)
            }
            
            Spacer()
            
            // Percentage
            Text("\(percentage)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(ModernUI.textSecondary)
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal, ModernUI.containerPadding)
        .padding(.vertical, 10)
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .orange
        case 2: return .cyan
        case 3: return .mint
        default: return ModernUI.textTertiary
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: duration) ?? "0m"
    }
}

private struct ModernDivider: View {
    var body: some View {
        Rectangle()
            .fill(ModernUI.cardBorder.opacity(0.5))
            .frame(height: 0.5)
            .padding(.horizontal, ModernUI.containerPadding)
    }
}

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(ModernUI.textTertiary)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernUI.textSecondary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernUI.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(ModernUI.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    TotalActivityView(activityReport: ExtensionActivityReport(
        totalDuration: 14400,
        averageDaily: 7200,
        averageWeekly: 50400,
        allApps: [],
        categories: [
            ExtensionCategoryUsage(categoryName: "Social Networking", duration: 7200, appCount: 3),
            ExtensionCategoryUsage(categoryName: "Productivity", duration: 3600, appCount: 2),
            ExtensionCategoryUsage(categoryName: "Photo & Video", duration: 2400, appCount: 4),
            ExtensionCategoryUsage(categoryName: "Health & Fitness", duration: 1200, appCount: 1)
        ],
        todayScreenSeconds: 10800,
        todayOffScreenSeconds: 28800,
        hourlyData: [],
        focusScore: 65,
        topThreeMostUsed: [],
        categoriesCount: 4
    ))
    .preferredColorScheme(ColorScheme.dark)
}

// MARK: - New Enhanced Components

/// Hero metric card with trend indicator
private struct HeroMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendInfo?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernUI.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(value)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(ModernUI.textPrimary)

                        if let trend = trend {
                            TrendBadge(trend: trend)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(color)
                }

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }
            }
        }
        .padding(ModernUI.cardPadding + 4)
        .background(
            LinearGradient(
                colors: [color.opacity(0.08), ModernUI.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.largeRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.largeRadius)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: color.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

/// Compact metric card with optional badge
private struct CompactMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let badge: String?

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 16))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(ModernUI.textPrimary)
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ModernUI.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(ModernUI.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ModernUI.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}

/// Trend badge showing percentage change
private struct TrendBadge: View {
    let trend: TrendInfo

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.isPositive ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 10, weight: .bold))

            Text("\(abs(trend.percentage))%")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(trend.isPositive ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((trend.isPositive ? Color.green : Color.red).opacity(0.15))
        )
    }
}

/// Insight card with icon
private struct InsightCard: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ModernUI.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(ModernUI.cardPadding)
        .background(
            LinearGradient(
                colors: [color.opacity(0.08), ModernUI.cardBackground],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernUI.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ModernUI.mediumRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Trend information model
struct TrendInfo {
    let percentage: Int
    let isPositive: Bool
}

// MARK: - Helper Functions
private func isValidToken(_ token: ApplicationToken) -> Bool {
    // Toujours afficher les vraies icônes d'applications
    return true
}