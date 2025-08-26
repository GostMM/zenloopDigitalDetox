//
//  CategoryWidgets.swift
//  zenloopactivity (Extension)
//
//  Widgets modulaires pour l'analyse par catégories
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log
import Foundation

// MARK: - Category Distribution Widget
struct CategoryDistributionWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("CategoryDistribution")
    let content: (CategoryDistributionData) -> CategoryDistributionView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "CategoryDistributionWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> CategoryDistributionData {
        var categoryDurations: [String: TimeInterval] = [:]
        var categoryDisplayNames: [String: String] = [:]
        var totalDuration: TimeInterval = 0
        
        logger.info("🔍 [CATEGORY-DIST] Processing category distribution...")
        
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
                }
            }
        }
        
        let categories = categoryDurations.compactMap { categoryID, duration -> CategoryDistributionItem? in
            guard let displayName = categoryDisplayNames[categoryID] else { return nil }
            let percentage = totalDuration > 0 ? (duration / totalDuration) * 100 : 0
            
            return CategoryDistributionItem(
                name: displayName,
                duration: duration,
                percentage: percentage
            )
        }
        .sorted { $0.duration > $1.duration }
        .prefix(4) // Top 4 seulement
        
        logger.info("✅ [CATEGORY-DIST] Found \(categories.count) categories")
        
        return CategoryDistributionData(
            categories: Array(categories),
            totalDuration: totalDuration
        )
    }
}

struct CategoryDistributionData {
    let categories: [CategoryDistributionItem]
    let totalDuration: TimeInterval
}

struct CategoryDistributionItem: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let percentage: Double
    
    var color: Color {
        let n = name.lowercased()
        if n.contains("social") { return .blue }
        if n.contains("productivity") || n.contains("business") { return .green }
        if n.contains("entertainment") || n.contains("games") { return .purple }
        if n.contains("education") { return .teal }
        if n.contains("health") || n.contains("fitness") { return .pink }
        if n.contains("photo") || n.contains("video") { return .indigo }
        return .orange
    }
    
    var icon: String {
        let n = name.lowercased()
        if n.contains("social") { return "person.2" }
        if n.contains("productivity") || n.contains("business") { return "briefcase" }
        if n.contains("entertainment") || n.contains("games") { return "gamecontroller" }
        if n.contains("education") { return "book" }
        if n.contains("health") || n.contains("fitness") { return "heart" }
        if n.contains("photo") || n.contains("video") { return "photo" }
        return "app"
    }
}

struct CategoryDistributionView: View {
    let categoryDistributionData: CategoryDistributionData
    
    var body: some View {
        VStack(spacing: 10) {
            // Titre
            HStack {
                Text("Distribution par catégorie")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            
            // Barre de distribution visuelle
            distributionBar
            
            // Liste des catégories
            VStack(spacing: 6) {
                ForEach(categoryDistributionData.categories) { category in
                    CategoryRow(category: category)
                }
            }
        }
        .padding(12)
    }
    
    private var distributionBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(categoryDistributionData.categories) { category in
                    let width = geometry.size.width * (category.percentage / 100)
                    category.color.opacity(0.8)
                        .frame(width: max(2, width), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                }
                
                // Autres (non représentés)
                let representedPercentage = categoryDistributionData.categories.reduce(0) { $0 + $1.percentage }
                let othersPercentage = max(0, 100 - representedPercentage)
                
                if othersPercentage > 1 {
                    let width = geometry.size.width * (othersPercentage / 100)
                    Color.gray.opacity(0.4)
                        .frame(width: max(2, width), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                }
            }
        }
        .frame(height: 6)
    }
}

private struct CategoryRow: View {
    let category: CategoryDistributionItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Icône
            Image(systemName: category.icon)
                .foregroundColor(category.color)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16)
            
            // Nom
            Text(category.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
            
            // Pourcentage et durée
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(category.color)
                
                Text(formatTime(category.duration))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - Top Categories Compact Widget
struct TopCategoriesCompactWidget: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TopCategoriesCompact")
    let content: (TopCategoriesCompactData) -> TopCategoriesCompactView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TopCategoriesCompactWidget")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TopCategoriesCompactData {
        var categoryDurations: [String: TimeInterval] = [:]
        var categoryDisplayNames: [String: String] = [:]
        
        logger.info("🔍 [TOP-CATEGORIES] Processing top categories...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                for await categoryActivity in segment.categories {
                    let category = categoryActivity.category
                    let categoryID = stableCategoryID(category)
                    let categoryName = displayName(for: category)
                    let duration = categoryActivity.totalActivityDuration
                    
                    guard duration > 0 else { continue }
                    
                    categoryDisplayNames[categoryID] = categoryName
                    categoryDurations[categoryID, default: 0] += duration
                }
            }
        }
        
        let topCategories = categoryDurations.compactMap { categoryID, duration -> TopCategoryItem? in
            guard let displayName = categoryDisplayNames[categoryID] else { return nil }
            
            return TopCategoryItem(
                name: displayName,
                duration: duration
            )
        }
        .sorted { $0.duration > $1.duration }
        .prefix(3) // Top 3 seulement pour la version compacte
        
        logger.info("✅ [TOP-CATEGORIES] Found \(topCategories.count) top categories")
        
        return TopCategoriesCompactData(categories: Array(topCategories))
    }
}

struct TopCategoriesCompactData {
    let categories: [TopCategoryItem]
}

struct TopCategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    
    var color: Color {
        let n = name.lowercased()
        if n.contains("social") { return .blue }
        if n.contains("productivity") || n.contains("business") { return .green }
        if n.contains("entertainment") || n.contains("games") { return .purple }
        return .orange
    }
    
    var icon: String {
        let n = name.lowercased()
        if n.contains("social") { return "person.2.fill" }
        if n.contains("productivity") || n.contains("business") { return "briefcase.fill" }
        if n.contains("entertainment") || n.contains("games") { return "gamecontroller.fill" }
        return "app.fill"
    }
}

struct TopCategoriesCompactView: View {
    let topCategoriesCompactData: TopCategoriesCompactData
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(topCategoriesCompactData.categories.enumerated()), id: \.element.id) { index, category in
                CategoryChip(
                    category: category,
                    rank: index + 1
                )
                
                if index < topCategoriesCompactData.categories.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(12)
    }
}

private struct CategoryChip: View {
    let category: TopCategoryItem
    let rank: Int
    
    var body: some View {
        VStack(spacing: 6) {
            // Icône avec badge de rang
            ZStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Badge de rang
                Text("\(rank)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 14, height: 14)
                    .background(rankColor)
                    .clipShape(Circle())
                    .offset(x: 10, y: -10)
            }
            
            // Nom de catégorie
            Text(shortName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            // Durée
            Text(formatTime(category.duration))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(category.color)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .gray
        }
    }
    
    private var shortName: String {
        let words = category.name.split(separator: " ")
        return words.isEmpty ? category.name : String(words[0])
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
    case "Socialnetworking": return "Social"
    case "Photovideo": return "Photo & Video"
    case "Healthfitness": return "Santé"
    case "Entertainment": return "Divertissement"
    case "Productivity": return "Productivité"
    default: return result
    }
}

// MARK: - Context Extensions
extension DeviceActivityReport.Context {
    static let categoryDistribution = Self("CategoryDistribution")
    static let topCategoriesCompact = Self("TopCategoriesCompact")
}