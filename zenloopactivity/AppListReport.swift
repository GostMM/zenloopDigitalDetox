//
//  AppListReport.swift
//  zenloopactivity (Extension)
//
//  Vue spécialisée pour l'affichage des applications
//

import SwiftUI
import DeviceActivity
import ManagedSettings
import FamilyControls
import os.log

// MARK: - App List Report Scene
struct AppListReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("AppList")
    let content: (AppListData) -> AppListView
    
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "AppListReport")
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> AppListData {
        var apps: [AppUsageItem] = []
        var totalDuration: TimeInterval = 0
        
        logger.info("🔍 [APP-LIST] Processing app usage data...")
        
        for await datum in data {
            for await segment in datum.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let duration = appActivity.totalActivityDuration
                        guard duration > 0 else { continue }
                        
                        let name = appActivity.application.localizedDisplayName 
                            ?? appActivity.application.bundleIdentifier 
                            ?? "Unknown App"
                            
                        if let token = appActivity.application.token {
                            // Check if app already exists and merge durations
                            if let existingIndex = apps.firstIndex(where: { $0.token == token }) {
                                apps[existingIndex].duration += duration
                            } else {
                                apps.append(AppUsageItem(
                                    name: name,
                                    duration: duration,
                                    token: token,
                                    bundleId: appActivity.application.bundleIdentifier ?? ""
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // Sort by usage time (descending)
        apps.sort { $0.duration > $1.duration }
        
        logger.info("✅ [APP-LIST] Found \(apps.count) apps, total: \(totalDuration)s")
        
        return AppListData(apps: apps, totalDuration: totalDuration)
    }
}

// MARK: - Data Models
struct AppListData {
    let apps: [AppUsageItem]
    let totalDuration: TimeInterval
}

struct AppUsageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var duration: TimeInterval
    let token: ApplicationToken
    let bundleId: String
    
    var percentage: Double {
        // Will be calculated relative to total when displayed
        return 0.0
    }
}

// MARK: - App List View
struct AppListView: View {
    let appListData: AppListData
    
    @State private var searchText: String = ""
    @State private var showCount: Int = 10
    
    private var filteredApps: [AppUsageItem] {
        let apps = appListData.apps
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apps
        }
        let query = searchText.lowercased()
        return apps.filter { $0.name.lowercased().contains(query) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerSection
            
            if filteredApps.isEmpty {
                emptyState
            } else {
                appsList
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Stats summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(appListData.apps.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "applications"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(appListData.totalDuration))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(localized: "total_time"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14))
                
                TextField(String(localized: "search_apps"), text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.05))
    }
    
    // MARK: - Apps List
    private var appsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredApps.prefix(showCount).enumerated()), id: \.element.id) { index, app in
                    AppRowView(
                        app: app,
                        rank: index + 1,
                        totalDuration: appListData.totalDuration
                    )
                    
                    if index < min(filteredApps.count, showCount) - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
                
                if showCount < filteredApps.count {
                    loadMoreButton
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCount += 10
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(String(localized: "show_more_apps"))
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.top, 16)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.4))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? String(localized: "no_apps_found") : String(localized: "no_search_results"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(searchText.isEmpty ? String(localized: "no_activity_recorded") : String(localized: "try_different_search"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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

// MARK: - App Row View
private struct AppRowView: View {
    let app: AppUsageItem
    let rank: Int
    let totalDuration: TimeInterval
    
    private var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(round((app.duration / totalDuration) * 100))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 20, alignment: .leading)
            
            // App icon avec validation du token
            if isValidToken(app.token) {
                Label(app.token)
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue.opacity(0.8))
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // App details
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formatTime(app.duration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("\(percentage)%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Usage bar
            VStack(alignment: .trailing, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        
                        Rectangle()
                            .fill(usageColor)
                            .frame(width: max(2, geometry.size.width * CGFloat(min(1, totalDuration > 0 ? app.duration / totalDuration : 0))), height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    }
                }
                .frame(width: 60, height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .yellow
        case 3: return .mint
        case 4...10: return .blue
        default: return .white.opacity(0.6)
        }
    }
    
    private var usageColor: Color {
        switch percentage {
        case 30...: return .red
        case 15..<30: return .orange
        case 5..<15: return .yellow
        default: return .green
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

// MARK: - Helper Functions
private func isValidToken(_ token: ApplicationToken) -> Bool {
    // Toujours afficher les vraies icônes d'applications
    return true
}

// MARK: - Extension for Context
extension DeviceActivityReport.Context {
    static let appList = Self("AppList")
}