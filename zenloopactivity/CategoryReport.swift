//
//  CategoryReport.swift
//  zenloopactivity (Extension)
//
//  Vue spécialisée pour la répartition par catégories
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Category Report Scene
struct CategoryReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("CategoryBreakdown")
    let content: (CategoryData) -> CategoryView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "CategoryReport")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> CategoryData {
        var categoryDurations: [String: TimeInterval] = [:]
        var categoryAppCounts: [String: Set<ApplicationToken>] = [:]
        var categoryDisplayNames: [String: String] = [:]
        var totalDuration: TimeInterval = 0
        
        logger.info("🔍 [CATEGORY] Processing category breakdown...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                for await categoryActivity in segment.categories {
                    let category = categoryActivity.category
                    let categoryID = stableCategoryID(category)
                    let categoryName = displayName(for: category)
                    let duration = categoryActivity.totalActivityDuration
                    
                    guard duration > 0 else { continue }
                    
                    categoryDisplayNames[categoryID] = categoryName
                    categoryDurations[categoryID, default: 0] += duration
                    
                    // Track unique apps in this category
                    for await appActivity in categoryActivity.applications {
                        if let token = appActivity.application.token,
                           appActivity.totalActivityDuration > 0 {
                            var appSet = categoryAppCounts[categoryID] ?? Set<ApplicationToken>()
                            appSet.insert(token)
                            categoryAppCounts[categoryID] = appSet
                        }
                    }
                }
            }
        }
        
        // Create category items
        let categories = categoryDurations.compactMap { categoryID, duration -> CategoryItem? in
            guard let displayName = categoryDisplayNames[categoryID] else { return nil }
            let appCount = categoryAppCounts[categoryID]?.count ?? 0
            
            return CategoryItem(
                id: categoryID,
                name: displayName,
                duration: duration,
                appCount: appCount,
                percentage: totalDuration > 0 ? (duration / totalDuration) * 100 : 0
            )
        }
        .sorted { $0.duration > $1.duration }
        
        let categoryData = CategoryData(
            categories: categories,
            totalDuration: totalDuration
        )
        
        logger.info("✅ [CATEGORY] Found \(categories.count) categories, total: \(totalDuration)s")
        
        return categoryData
    }
}

// MARK: - Data Models
struct CategoryData {
    let categories: [CategoryItem]
    let totalDuration: TimeInterval
}

struct CategoryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let duration: TimeInterval
    let appCount: Int
    let percentage: Double
    
    var systemImage: String {
        let n = name.lowercased()
        if n.contains("social") { return "person.2.fill" }
        if n.contains("productivity") || n.contains("business") { return "briefcase.fill" }
        if n.contains("finance") { return "creditcard.fill" }
        if n.contains("entertainment") || n.contains("games") { return "gamecontroller.fill" }
        if n.contains("education") { return "book.fill" }
        if n.contains("health") || n.contains("fitness") { return "heart.fill" }
        if n.contains("photo") || n.contains("video") { return "photo.on.rectangle.angled" }
        if n.contains("music") || n.contains("audio") { return "music.note" }
        if n.contains("navigation") || n.contains("travel") { return "location.fill" }
        if n.contains("shopping") { return "bag.fill" }
        if n.contains("news") || n.contains("reading") { return "newspaper.fill" }
        if n.contains("weather") { return "cloud.sun.fill" }
        if n.contains("food") { return "fork.knife" }
        if n.contains("lifestyle") { return "sparkles" }
        return "app.fill"
    }
    
    var color: Color {
        let n = name.lowercased()
        if n.contains("social") { return .blue }
        if n.contains("productivity") || n.contains("business") { return .green }
        if n.contains("finance") { return .orange }
        if n.contains("entertainment") || n.contains("games") { return .purple }
        if n.contains("education") { return .teal }
        if n.contains("health") || n.contains("fitness") { return .pink }
        if n.contains("photo") || n.contains("video") { return .indigo }
        if n.contains("music") || n.contains("audio") { return .red }
        if n.contains("navigation") || n.contains("travel") { return .yellow }
        if n.contains("shopping") { return .mint }
        if n.contains("news") || n.contains("reading") { return .cyan }
        if n.contains("weather") { return .blue }
        if n.contains("food") { return .orange }
        if n.contains("lifestyle") { return .pink }
        return .gray
    }
}

// MARK: - Category View
struct CategoryView: View {
    let categoryData: CategoryData
    
    @State private var viewMode: ViewMode = .list
    @State private var sortMode: SortMode = .duration
    @State private var selectedCategory: CategoryItem?
    
    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "list"
        case chart = "chart"
        case grid = "grid"
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            String(localized: String.LocalizationValue(rawValue))
        }
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .chart: return "chart.pie.fill"
            case .grid: return "grid"
            }
        }
    }
    
    enum SortMode: String, CaseIterable {
        case duration = "duration"
        case name = "name"
        case appCount = "app_count"
        
        var localizedTitle: String {
            String(localized: String.LocalizationValue(rawValue))
        }
    }
    
    private var sortedCategories: [CategoryItem] {
        switch sortMode {
        case .duration:
            return categoryData.categories.sorted { $0.duration > $1.duration }
        case .name:
            return categoryData.categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .appCount:
            return categoryData.categories.sorted { $0.appCount > $1.appCount }
        }
    }
    
    private var topCategories: [CategoryItem] {
        Array(sortedCategories.prefix(5))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with summary
            headerSection
            
            // Controls (view mode + sort)
            controlsSection
            
            // Content based on view mode
            Group {
                switch viewMode {
                case .list: listContent
                case .chart: chartContent
                case .grid: gridContent
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewMode)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Summary stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(categoryData.categories.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "categories"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(categoryData.totalDuration))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(localized: "total_usage"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Top category highlight
            if let topCategory = categoryData.categories.first {
                topCategoryHighlight(topCategory)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.white.opacity(0.05))
    }
    
    private func topCategoryHighlight(_ category: CategoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "top_category"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(category.duration))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(category.color)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        HStack(spacing: 12) {
            // View mode selector
            HStack(spacing: 4) {
                ForEach(ViewMode.allCases) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(viewMode == mode ? .black : .white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewMode == mode ? .white : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            
            Spacer()
            
            // Sort selector
            Menu {
                Picker(selection: $sortMode, label: Text(String(localized: "sort_by"))) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(localized: "sort"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - List Content
    private var listContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sortedCategories) { category in
                    CategoryListRow(
                        category: category,
                        totalDuration: categoryData.totalDuration
                    )
                    .onTapGesture {
                        selectedCategory = category
                    }
                    
                    if category.id != sortedCategories.last?.id {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Chart Content
    private var chartContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Pie chart representation
                pieChartSection
                
                // Legend
                legendSection
                
                // Detailed breakdown
                detailedBreakdown
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private var pieChartSection: some View {
        VStack(spacing: 16) {
            Text(String(localized: "usage_distribution"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // Simple visual representation
            HStack(spacing: 2) {
                ForEach(topCategories) { category in
                    let width = categoryData.totalDuration > 0 ? max(8, 300 * category.duration / categoryData.totalDuration) : 0
                    category.color.opacity(0.8)
                        .frame(width: width, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                
                // Others (if needed)
                let othersTotal = categoryData.categories.dropFirst(5).reduce(0) { $0 + $1.duration }
                if othersTotal > 0 {
                    let width = categoryData.totalDuration > 0 ? max(8, 300 * othersTotal / categoryData.totalDuration) : 0
                    Color.gray.opacity(0.6)
                        .frame(width: width, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 12)
        }
    }
    
    private var legendSection: some View {
        VStack(spacing: 8) {
            ForEach(topCategories) { category in
                HStack(spacing: 10) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    
                    Text(category.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(category.percentage))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("(\(formatTime(category.duration)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
            
            // Others summary
            let othersCategories = Array(categoryData.categories.dropFirst(5))
            if !othersCategories.isEmpty {
                let othersTotal = othersCategories.reduce(0) { $0 + $1.duration }
                let othersPercentage = categoryData.totalDuration > 0 ? (othersTotal / categoryData.totalDuration) * 100 : 0
                
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    
                    Text(String(localized: "others") + " (\(othersCategories.count))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(Int(othersPercentage))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("(\(formatTime(othersTotal)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var detailedBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "detailed_breakdown"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVStack(spacing: 8) {
                ForEach(sortedCategories.prefix(10)) { category in
                    CategoryDetailRow(category: category, totalDuration: categoryData.totalDuration)
                }
            }
        }
    }
    
    // MARK: - Grid Content
    private var gridContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(sortedCategories) { category in
                    CategoryGridCard(category: category, totalDuration: categoryData.totalDuration)
                        .onTapGesture {
                            selectedCategory = category
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: max(0, duration)) ?? "0m"
    }
}

// MARK: - Supporting Views
private struct CategoryListRow: View {
    let category: CategoryItem
    let totalDuration: TimeInterval
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: category.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(category.color)
                .frame(width: 40, height: 40)
                .background(category.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Category details
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formatTime(category.duration))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(category.appCount) \(category.appCount == 1 ? String(localized: "app_singular") : String(localized: "apps_plural"))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Percentage and usage bar
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        
                        Rectangle()
                            .fill(category.color.opacity(0.8))
                            .frame(width: max(2, geometry.size.width * min(1, category.percentage / 100)), height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    }
                }
                .frame(width: 60, height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct CategoryDetailRow: View {
    let category: CategoryItem
    let totalDuration: TimeInterval
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    Rectangle()
                        .fill(category.color.opacity(0.8))
                        .frame(width: max(3, geometry.size.width * min(1, category.percentage / 100)), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
            
            // Details
            VStack(alignment: .trailing, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formatTime(category.duration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 100)
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct CategoryGridCard: View {
    let category: CategoryItem
    let totalDuration: TimeInterval
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon and percentage
            HStack {
                Image(systemName: category.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(category.color)
                    .frame(width: 36, height: 36)
                    .background(category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Category name
            Text(category.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Duration and app count
            HStack {
                Text(formatTime(category.duration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(category.appCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(category.color)
            }
            
            // Usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    
                    Rectangle()
                        .fill(category.color.opacity(0.8))
                        .frame(width: max(2, geometry.size.width * min(1, category.percentage / 100)), height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - Helper Functions
private func stableCategoryID(_ category: ActivityCategory) -> String {
    String(reflecting: category)
}

private func displayName(for category: ActivityCategory) -> String {
    if #available(iOS 17.0, *) {
        if let native = category.localizedDisplayName,
           !native.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return native
        }
    }
    let qualified = String(reflecting: category)
    let rawCase = qualified.split(separator: ".").last.map(String.init) ?? qualified
    return humanizeEnumCase(rawCase)
}

private func humanizeEnumCase(_ s: String) -> String {
    let base = s.replacingOccurrences(of: "_", with: " ")
    let spaced = base.replacingOccurrences(of: "([a-z])([A-Z])",
                                           with: "$1 $2",
                                           options: .regularExpression)
    let words = spaced.split(separator: " ").map { $0.lowercased().capitalized }
    let result = words.joined(separator: " ")
    switch result {
    case "Socialnetworking": return "Social Networking"
    case "Photovideo": return "Photo & Video"
    case "Healthfitness": return "Health & Fitness"
    default: return result
    }
}

// MARK: - Extension for Context
extension DeviceActivityReport.Context {
    static let categoryBreakdown = Self("CategoryBreakdown")
}