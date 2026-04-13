//
//  FullStatsPageView.swift
//  zenloopactivity
//
//  Page Stats complète style Opal - Design immersif
//
//  ✅ FIX: prepareContent() protégé contre données vides
//  ✅ FIX: SkeletonBox supprimé (défini dans FullStatsView)
//  ✅ FIX: Timer leak corrigé
//

import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation
import UIKit
import os

// MARK: - Shared Models (needed for DeviceActivity payload)

enum RestrictionMode: String, Codable {
    case shield
    case hide
}

struct SelectionPayload: Codable {
    let sessionId: String
    let apps: [ApplicationToken]
    let categories: [ActivityCategoryToken]
    let restrictionMode: RestrictionMode?
}

private let logger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "FullStatsPage")

struct FullStatsPageView: View {
    let reportData: ExtensionActivityReport
    @State private var hourlyChartData: [HourData] = []
    @State private var activeBlocks: [ActiveBlock] = []
    @State private var isContentReady = false
    @State private var blockRefreshTimer: Timer?
    @AppStorage("isBlockCardExpanded", store: UserDefaults(suiteName: "group.com.app.zenloop"))
    private var isBlockCardExpanded = false

    init(reportData: ExtensionActivityReport) {
        self.reportData = reportData
        logger.critical("🚀🚀🚀 [FULLSTATS] FullStatsPageView INIT - reportData has \(reportData.hourlyData.count) hourly entries")
        for data in reportData.hourlyData {
            logger.critical("🚀 [FULLSTATS] INIT Hour \(data.hour): \(String(format: "%.1f", data.totalMinutes))min")
        }
    }

    var body: some View {
        ZStack {
            // Background animé comme HomeView
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.15),
                            Color(red: 0.1, green: 0.1, blue: 0.2),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2), Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .opacity(0.3)
                .blendMode(.overlay)
                .ignoresSafeArea()

            if isContentReady {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroHeader
                        metricsRow

                        if !activeBlocks.isEmpty {
                            blockedAppsSection
                                .padding(.top, 20)
                        }

                        hourlyChart
                            .padding(.top, 30)
                            .padding(.bottom, 30)

                        appsList
                            .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
                .transition(.opacity)
            } else {
                // ✅ FIX: Skeleton défini localement pour l'extension (pas de dépendance croisée)
                ExtensionSkeletonView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            prepareContent()
            startBlockRefreshTimer()
        }
        .onDisappear {
            stopBlockRefreshTimer()
        }
    }

    // ✅ FIX: Protégé contre les données vides au premier render
    private func prepareContent() {
        // Vérifier que les données sont réellement disponibles
        guard reportData.totalDuration > 0 || !reportData.allApps.isEmpty || !reportData.hourlyData.isEmpty else {
            logger.warning("⚠️ [FULLSTATS] reportData appears empty, showing content anyway to avoid stuck skeleton")
            // Afficher quand même pour ne pas rester bloqué sur le skeleton
            generateHourlyData()
            loadActiveBlocks()
            withAnimation(.easeInOut(duration: 0.2)) {
                isContentReady = true
            }
            return
        }

        generateHourlyData()
        loadActiveBlocks()

        withAnimation(.easeInOut(duration: 0.2)) {
            isContentReady = true
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 8) {
            Text(formattedTotalTime)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(String(localized: "screen_time_today"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(String(localized: "most_used_label"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)

                HStack(spacing: 6) {
                    if !reportData.topThreeMostUsed.isEmpty {
                        ForEach(Array(reportData.topThreeMostUsed.enumerated()), id: \.offset) { index, app in
                            AppIconBadge(app: app, size: 24)
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(reportData.focusScore)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(focusScoreColor(reportData.focusScore))

                Text(String(localized: "focus_score_label"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(reportData.categoriesCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(String(localized: "categories_label"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Legend Row

    private var legendRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.4, green: 0.6, blue: 0.3))
                    .frame(width: 8, height: 8)

                Text(String(localized: "productive_label"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
            }

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 3, height: 3)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.3, blue: 0.3))
                    .frame(width: 8, height: 8)

                Text(String(localized: "distracting_label"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
            }

            Spacer()
        }
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        let chartHeight: CGFloat = 80
        let maxPossibleMinutesPerHour: Double = 60
        let scale = chartHeight / maxPossibleMinutesPerHour

        return VStack(alignment: .leading, spacing: 12) {
            legendRow

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    let barCount = CGFloat(hourlyChartData.count)
                    let totalSpacing = CGFloat(max(0, hourlyChartData.count - 1)) * 1.5
                    let availableWidth = geometry.size.width - totalSpacing
                    let barWidth = barCount > 0 ? availableWidth / barCount : 0

                    HStack(alignment: .bottom, spacing: 1.5) {
                        ForEach(hourlyChartData, id: \.hour) { data in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: barWidth, height: chartHeight)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor(for: data))
                                    .frame(
                                        width: barWidth,
                                        height: max(2, CGFloat(data.totalMinutes) * scale)
                                    )
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: data.totalMinutes)
                            }
                        }
                    }
                }
                .frame(height: chartHeight)

                HStack(spacing: 0) {
                    let labels = getSmartHourLabels()
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, hour in
                        Text("\(hour < 10 ? "0" : "")\(hour)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : (index == labels.count - 1 ? .trailing : .center))
                    }
                }
            }

            timeOfflineSection
        }
        .padding(.vertical, 6)
    }

    private var timeOfflineSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.7, blue: 0.9))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "time_offline"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(formattedOfflinePercentage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Text(formattedOfflineTime)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func getSmartHourLabels() -> [Int] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let hourCount = currentHour + 1

        if hourCount <= 6 {
            return Array(0...currentHour)
        } else if hourCount <= 12 {
            return stride(from: 0, through: currentHour, by: 2).map { $0 }
        } else if hourCount <= 18 {
            return stride(from: 0, through: currentHour, by: 3).map { $0 }
        } else {
            return stride(from: 0, through: currentHour, by: 4).map { $0 }
        }
    }

    private var formattedOfflineTime: String {
        let offlineSeconds = reportData.todayOffScreenSeconds
        let hours = Int(offlineSeconds) / 3600
        let minutes = (Int(offlineSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var formattedOfflinePercentage: String {
        let totalSeconds = reportData.todayScreenSeconds + reportData.todayOffScreenSeconds
        guard totalSeconds > 0 else { return "0% \(String(localized: "of_your_day"))" }
        let percentage = Int((reportData.todayOffScreenSeconds / totalSeconds) * 100)
        return "\(percentage)% \(String(localized: "of_your_day"))"
    }

    // MARK: - Apps List

    private var appsList: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            ForEach(Array(reportData.allApps.prefix(10).enumerated()), id: \.offset) { index, app in
                FullStatsAppRow(
                    app: app,
                    index: index,
                    maxDuration: reportData.allApps.first?.duration ?? 1,
                    isBlocked: activeBlocks.contains(where: { $0.appName == app.name }),
                    onBlockAdded: {
                        loadActiveBlocks()
                    }
                )

                if index < min(9, reportData.allApps.count - 1) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 60)
                }
            }
        }
    }

    // MARK: - Helpers

    private func focusScoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        else if score >= 40 { return .orange }
        else { return .red }
    }

    private var formattedTotalTime: String {
        let totalSeconds = Int(reportData.totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private func generateHourlyData() {
        let currentHour = Calendar.current.component(.hour, from: Date())

        logger.critical("🚀🚀🚀 [HOURLY_CHART] === generateHourlyData CALLED ===")
        logger.critical("🚀🚀🚀 [HOURLY_CHART] Processing hourly data with \(reportData.hourlyData.count) entries, currentHour=\(currentHour)")

        var hourDataMap: [Int: ExtensionHourData] = [:]
        for data in reportData.hourlyData {
            hourDataMap[data.hour] = data
        }

        hourlyChartData = (0...currentHour).map { hour in
            if let hourData = hourDataMap[hour] {
                let isProductive = isHourProductive(hourData: hourData)
                return HourData(
                    hour: hour,
                    totalMinutes: hourData.totalMinutes,
                    isProductive: isProductive
                )
            } else {
                return HourData(hour: hour, totalMinutes: 0, isProductive: true)
            }
        }

        logger.critical("🚀🚀🚀 [HOURLY_CHART] Generated \(hourlyChartData.count) hour bars")
    }

    private func isHourProductive(hourData: ExtensionHourData) -> Bool {
        let distractingKeywords = ["Social", "Entertainment", "Games", "Photo", "Video"]
        let totalMinutes = hourData.totalMinutes
        guard totalMinutes > 0 else { return true }

        var distractingMinutes: Double = 0
        for (categoryName, minutes) in hourData.categories {
            if distractingKeywords.contains(where: { categoryName.contains($0) }) {
                distractingMinutes += minutes
            }
        }

        return (distractingMinutes / totalMinutes) < 0.5
    }

    private func barColor(for data: HourData) -> Color {
        data.isProductive
            ? Color(red: 0.4, green: 0.6, blue: 0.3)
            : Color(red: 1.0, green: 0.3, blue: 0.3)
    }

    // MARK: - Blocked Apps Section

    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isBlockCardExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    blockedAppsStack

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "apps_blocked_title"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text(activeBlocks.count > 1
                            ? String(localized: "apps_plural_blocked", defaultValue: "\(activeBlocks.count) apps").replacingOccurrences(of: "%d", with: "\(activeBlocks.count)")
                            : String(localized: "app_singular_blocked", defaultValue: "\(activeBlocks.count) app").replacingOccurrences(of: "%d", with: "\(activeBlocks.count)")
                        )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: isBlockCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isBlockCardExpanded ? 180 : 0))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)

            if isBlockCardExpanded {
                VStack(spacing: 8) {
                    ForEach(activeBlocks, id: \.id) { block in
                        BlockedAppRow(block: block) {
                            loadActiveBlocks()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var blockedAppsStack: some View {
        ZStack {
            ForEach(Array(activeBlocks.prefix(3).enumerated()), id: \.element.id) { index, block in
                if let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
                   let token = selection.applicationTokens.first {

                    ZStack(alignment: .bottomTrailing) {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 2)
                            )

                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                    .offset(x: CGFloat(index * 12))
                    .zIndex(Double(3 - index))
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.4, blue: 0.6),
                                            Color(red: 0.2, green: 0.3, blue: 0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Text(String(block.appName.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }

                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                    .offset(x: CGFloat(index * 12))
                    .zIndex(Double(3 - index))
                }
            }
        }
        .frame(width: CGFloat(40 + (min(activeBlocks.count, 3) - 1) * 12), height: 40)
    }

    private func loadActiveBlocks() {
        logger.critical("🔍 [FULLSTATS] === LOADING ACTIVE BLOCKS ===")

        let blockManager = BlockManager()
        let blocks = blockManager.getActiveBlocks()

        logger.critical("📊 [FULLSTATS] Found \(blocks.count) active blocks")
        activeBlocks = blocks
    }

    // MARK: - Block Refresh Timer

    private func startBlockRefreshTimer() {
        // ✅ FIX: Invalider l'ancien timer avant d'en créer un nouveau
        blockRefreshTimer?.invalidate()

        blockRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            logger.info("⏱️ [FULLSTATS] Refreshing blocks...")
            loadActiveBlocks()
        }
    }

    private func stopBlockRefreshTimer() {
        blockRefreshTimer?.invalidate()
        blockRefreshTimer = nil
    }

    struct HourData {
        let hour: Int
        let totalMinutes: Double
        let isProductive: Bool
    }
}

// MARK: - App Icon Badge

struct AppIconBadge: View {
    let app: ExtensionAppUsage
    let size: CGFloat
    @State private var iconLoadFailed = false

    var body: some View {
        #if os(iOS)
        ZStack {
            if iconLoadFailed {
                placeholderIcon
            } else {
                Label(app.token)
                    .labelStyle(.iconOnly)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
            }
        }
        #else
        placeholderIcon
        #endif
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.4, blue: 0.6),
                            Color(red: 0.2, green: 0.3, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Full Stats App Row

struct FullStatsAppRow: View {
    let app: ExtensionAppUsage
    let index: Int
    let maxDuration: TimeInterval
    let isBlocked: Bool
    @State private var showBlockSheet = false
    @State private var iconVisible = false
    var onBlockAdded: (() -> Void)?

    var body: some View {
        Button {
            if !isBlocked {
                showBlockSheet = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        #if os(iOS)
                        if iconVisible {
                            Label(app.token)
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .opacity(isBlocked ? 0.6 : 1.0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBlocked ? Color.red.opacity(0.4) : Color.clear, lineWidth: 2)
                                )
                                .transition(.opacity)
                        } else {
                            placeholderIcon
                                .opacity(isBlocked ? 0.6 : 1.0)
                        }
                        #else
                        placeholderIcon
                        #endif

                        if isBlocked {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 2, y: 2)
                        }
                    }
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.15)) {
                            iconVisible = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(isBlocked ? 0.6 : 1.0)

                        Text(isBlocked ? String(localized: "blocked_status") : formatTime(app.duration))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isBlocked ? .red.opacity(0.8) : .white.opacity(0.5))
                    }

                    Spacer()

                    if isBlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green.opacity(0.6))
                    } else {
                        Image(systemName: "hand.raised.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeColor)
                        .frame(width: gaugeWidth, height: 6)
                }

                if index < 3 {
                    HStack(spacing: 4) {
                        Text(categoryLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(categoryColor)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(categoryColor)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBlockSheet) {
            BlockAppSheet(app: app, onBlockAdded: onBlockAdded)
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.35, blue: 0.55),
                            Color(red: 0.15, green: 0.25, blue: 0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var gaugeWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 40
        return screenWidth * CGFloat(app.duration / maxDuration)
    }

    private var gaugeColor: LinearGradient {
        let percentage = app.duration / maxDuration
        if percentage > 0.7 {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.3, blue: 0.3), Color(red: 1.0, green: 0.4, blue: 0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.7, blue: 0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var categoryLabel: String {
        index == 0 ? String(localized: "distracting_category") : String(localized: "productive_category")
    }

    private var categoryColor: Color {
        index == 0 ? Color(red: 1.0, green: 0.3, blue: 0.3) : Color(red: 0.4, green: 0.6, blue: 0.3)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Block App Sheet

struct BlockAppSheet: View {
    let app: ExtensionAppUsage
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var selectedHours = 0
    @State private var selectedMinutes = 15
    @State private var isBlocking = false
    @State private var showIcon = false
    var onBlockAdded: (() -> Void)?

    private var totalMinutes: Int {
        selectedHours * 60 + selectedMinutes
    }

    private var blockButtonText: String {
        let total = totalMinutes
        if total == 0 {
            return String(localized: "select_duration")
        } else if selectedHours > 0 && selectedMinutes > 0 {
            return String(localized: "block_hours_minutes", defaultValue: "Block \(selectedHours)h \(selectedMinutes)m")
                .replacingOccurrences(of: "%dh", with: "\(selectedHours)h")
                .replacingOccurrences(of: "%dm", with: "\(selectedMinutes)m")
        } else if selectedHours > 0 {
            return String(localized: "block_hours", defaultValue: "Block \(selectedHours)h")
                .replacingOccurrences(of: "%dh", with: "\(selectedHours)h")
        } else {
            return String(localized: "block_minutes", defaultValue: "Block \(selectedMinutes)m")
                .replacingOccurrences(of: "%dm", with: "\(selectedMinutes)m")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        #if os(iOS)
                        if showIcon {
                            Label(app.token)
                                .labelStyle(.iconOnly)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                                .shadow(color: Color.white.opacity(0.15), radius: 20, x: 0, y: 10)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            appPlaceholder
                        }
                        #else
                        appPlaceholder
                        #endif

                        Text(app.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "block_temporarily"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 12) {
                        Text(String(localized: "duration_picker_label"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)

                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text(String(localized: "hours_label"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))

                                Picker("", selection: $selectedHours) {
                                    ForEach(0..<13) { hour in
                                        Text("\(hour)").tag(hour)
                                            .foregroundColor(.white)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70, height: 100)
                                .compositingGroup()
                                .clipped()
                            }

                            Text(":")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.top, 20)

                            VStack(spacing: 4) {
                                Text(String(localized: "minutes_label"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))

                                Picker("", selection: $selectedMinutes) {
                                    ForEach([0, 1, 2, 5, 10, 15, 16, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                            .foregroundColor(.white)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 70, height: 100)
                                .compositingGroup()
                                .clipped()
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    VStack(spacing: 16) {
                        Button {
                            blockApp()
                        } label: {
                            HStack(spacing: 12) {
                                if isBlocking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 18, weight: .bold))

                                    Text(blockButtonText)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.3, blue: 0.3),
                                        Color(red: 1.0, green: 0.4, blue: 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isBlocking || totalMinutes == 0)

                        Button {
                            dismiss()
                        } label: {
                            Text(String(localized: "cancel_button"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showIcon = true
            }
        }
    }

    private var appPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.4, blue: 0.6),
                            Color(red: 0.2, green: 0.3, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func blockApp() {
        guard !isBlocking else { return }
        isBlocking = true

        #if os(iOS)
        let blockLogger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "BlockSheet")

        let duration = TimeInterval(totalMinutes * 60)
        let blockId = UUID().uuidString
        let activityName = DeviceActivityName("block-\(blockId)")

        blockLogger.critical("🎯 [BLOCK_SHEET] Starting block: \(app.name) for \(Int(duration/60))min")

        var selection = FamilyActivitySelection()
        selection.applicationTokens = [app.token]

        guard let tokenData = try? JSONEncoder().encode(selection) else {
            blockLogger.error("❌ [BLOCK_SHEET] Failed to encode token")
            self.isBlocking = false
            return
        }

        // 1️⃣ Appliquer le shield immédiatement
        let store = ManagedSettingsStore()
        var blockedApps = store.shield.applications ?? Set()
        blockedApps.insert(app.token)
        store.shield.applications = blockedApps
        blockLogger.critical("✅ [BLOCK_SHEET] Shield applied, total blocked: \(blockedApps.count)")

        // 2️⃣ Ouvrir l'app principale pour sauvegarder
        let tokenBase64 = tokenData.base64EncodedString()

        var urlComponents = URLComponents(string: "zenloop://save-block")!
        urlComponents.queryItems = [
            URLQueryItem(name: "appName", value: app.name),
            URLQueryItem(name: "duration", value: String(duration)),
            URLQueryItem(name: "activityName", value: activityName.rawValue),
            URLQueryItem(name: "tokenData", value: tokenBase64)
        ]

        if let url = urlComponents.url {
            openURL(url) { accepted in
                if accepted {
                    blockLogger.critical("✅ [BLOCK_SHEET] Main app opened")
                } else {
                    blockLogger.error("❌ [BLOCK_SHEET] Failed to open main app")
                }
            }
        }

        // 3️⃣ Sauvegarder le payload
        if let suite = UserDefaults(suiteName: "group.com.app.zenloop") {
            let payload = SelectionPayload(
                sessionId: blockId,
                apps: [app.token],
                categories: [],
                restrictionMode: .shield
            )

            if let payloadData = try? JSONEncoder().encode(payload) {
                suite.set(payloadData, forKey: "payload_\(activityName.rawValue)")
                suite.synchronize()
                blockLogger.critical("💾 [BLOCK_SHEET] Payload saved")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isBlocking = false
            self.onBlockAdded?()
            self.dismiss()
        }
        #endif
    }
}

// MARK: - Blocked App Row

struct BlockedAppRow: View {
    let block: ActiveBlock
    @State private var remainingTime: String = ""
    @State private var timer: Timer?
    @State private var showUnblockSheet = false
    var onUnblocked: (() -> Void)?

    var body: some View {
        Button {
            showUnblockSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    if let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: block.appTokenData),
                       let token = selection.applicationTokens.first {

                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.4, blue: 0.6),
                                            Color(red: 0.2, green: 0.3, blue: 0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)

                            Text(String(block.appName.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 22, height: 22)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(block.status == .paused ? String(localized: "paused_status") : String(localized: "blocked_status"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text(remainingTime)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red.opacity(0.9))
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showUnblockSheet) {
            UnblockAppSheet(block: block, onUnblocked: onUnblocked)
        }
        .onAppear {
            updateRemainingTime()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func updateRemainingTime() {
        remainingTime = block.formattedRemainingTime
    }

    private func startTimer() {
        // ✅ FIX: Invalider l'ancien timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRemainingTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Extension Skeleton (local à l'extension, pas de dépendance croisée)

struct ExtensionSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 8) {
                    skeletonRect(width: 200, height: 56)
                    skeletonRect(width: 150, height: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        skeletonRect(width: 60, height: 12)
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                skeletonRect(width: 24, height: 24, cornerRadius: 6)
                            }
                        }
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        skeletonRect(width: 40, height: 22)
                        skeletonRect(width: 80, height: 12)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        skeletonRect(width: 30, height: 22)
                        skeletonRect(width: 70, height: 12)
                    }
                }
                .padding(.vertical, 20)

                VStack(alignment: .leading, spacing: 12) {
                    skeletonRect(width: 100, height: 10)

                    HStack(alignment: .bottom, spacing: 1.5) {
                        ForEach(0..<18, id: \.self) { _ in
                            skeletonRect(width: 15, height: CGFloat.random(in: 20...80), cornerRadius: 2)
                        }
                    }
                    .frame(height: 80)
                }
                .padding(.top, 30)

                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack(spacing: 12) {
                            skeletonRect(width: 44, height: 44, cornerRadius: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                skeletonRect(width: 120, height: 16)
                                skeletonRect(width: 60, height: 14)
                            }
                            Spacer()
                            skeletonRect(width: 24, height: 24, cornerRadius: 12)
                        }
                        .padding(.vertical, 16)

                        if index < 4 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
    }

    private func skeletonRect(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                if !isAnimating {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }
}