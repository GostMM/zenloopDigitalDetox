//
//  FullStatsPageView.swift
//  zenloopactivity
//
//  Page Stats complète style Opal - Design immersif
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
                    // Header avec temps total géant
                    heroHeader

                    // Métriques compactes (Most Used, Focus Score, Pickups)
                    metricsRow

                    // Section Blocked Apps (si il y en a)
                    if !activeBlocks.isEmpty {
                        blockedAppsSection
                            .padding(.top, 20)
                    }

                    // Graphique horaire (barres verticales) avec légende intégrée
                    hourlyChart
                        .padding(.top, 30)
                        .padding(.bottom, 30)

                    // Liste des apps avec jauges
                    appsList
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60) // Espace pour le header
            }
                .transition(.opacity)
            } else {
                // ✅ OPTIMIZED: Skeleton UI au lieu de loading spinner
                SkeletonFullStatsView()
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

    private func prepareContent() {
        // ✅ OPTIMIZED: Calcul immédiat sans délai artificiel
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

            Text("SCREEN TIME TODAY")
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
            // Most Used
            VStack(spacing: 8) {
                Text("MOST USED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)

                HStack(spacing: 6) {
                    // ✅ OPTIMIZED: Utiliser les top 3 pré-calculés
                    if !reportData.topThreeMostUsed.isEmpty {
                        ForEach(Array(reportData.topThreeMostUsed.enumerated()), id: \.offset) { index, app in
                            AppIconBadge(app: app, size: 24)
                        }
                    }
                }
            }

            Spacer()

            // Focus Score (pré-calculé dans l'extension)
            VStack(spacing: 4) {
                // ✅ OPTIMIZED: Utiliser le focus score pré-calculé
                Text("\(reportData.focusScore)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(focusScoreColor(reportData.focusScore))

                Text("FOCUS SCORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1)
            }

            Spacer()

            // Catégories (remplace Pickups car non disponible dans DeviceActivity)
            VStack(spacing: 4) {
                // ✅ OPTIMIZED: Utiliser le count pré-calculé
                Text("\(reportData.categoriesCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("CATEGORIES")
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

                Text("PRODUCTIVE")
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

                Text("DISTRACTING")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
            }

            Spacer()
        }
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        // Échelle fixe: 60 min = hauteur max du graphique
        let chartHeight: CGFloat = 80
        let maxPossibleMinutesPerHour: Double = 60
        let scale = chartHeight / maxPossibleMinutesPerHour

        return VStack(alignment: .leading, spacing: 12) {
            // Légende PRODUCTIVE • DISTRACTING déplacée ici
            legendRow

            // Graphique ultra-compact
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    let barCount = CGFloat(hourlyChartData.count)
                    let totalSpacing = CGFloat(hourlyChartData.count - 1) * 1.5
                    let availableWidth = geometry.size.width - totalSpacing
                    let barWidth = availableWidth / barCount

                    HStack(alignment: .bottom, spacing: 1.5) {
                        ForEach(hourlyChartData, id: \.hour) { data in
                            ZStack(alignment: .bottom) {
                                // Background (vide)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: barWidth, height: chartHeight)

                                // Valeur réelle
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

                // Labels d'heures (seulement quelques-uns)
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

            // Time Offline Section - ultra compact
            timeOfflineSection
        }
        .padding(.vertical, 6)
    }

    private var timeOfflineSection: some View {
        HStack(spacing: 10) {
            // Icône plus petite
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.7, blue: 0.9))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Time Offline")
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

    // Générer des labels intelligents selon le nombre d'heures
    private func getSmartHourLabels() -> [Int] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let hourCount = currentHour + 1

        if hourCount <= 6 {
            // Afficher toutes les heures si moins de 6
            return Array(0...currentHour)
        } else if hourCount <= 12 {
            // Afficher toutes les 2 heures
            return stride(from: 0, through: currentHour, by: 2).map { $0 }
        } else if hourCount <= 18 {
            // Afficher toutes les 3 heures
            return stride(from: 0, through: currentHour, by: 3).map { $0 }
        } else {
            // Afficher toutes les 4 heures
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
        guard totalSeconds > 0 else { return "0% of your day" }
        let percentage = Int((reportData.todayOffScreenSeconds / totalSeconds) * 100)
        return "\(percentage)% of your day"
    }

    // MARK: - Apps List

    // ✅ OPTIMIZED: Lazy loading avec LazyVStack
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

    // ✅ OPTIMIZED: Fonction simplifiée utilisant le score pré-calculé
    private func focusScoreColor(_ score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }

    private var formattedTotalTime: String {
        let totalSeconds = Int(reportData.totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            // Si plus d'1h, afficher heures et minutes
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            // Si moins d'1h, afficher minutes et secondes
            return "\(minutes)m \(seconds)s"
        } else {
            // Si moins d'1 minute, afficher secondes
            return "\(seconds)s"
        }
    }

    private func generateHourlyData() {
        let currentHour = Calendar.current.component(.hour, from: Date())

        logger.critical("🚀🚀🚀 [HOURLY_CHART] === generateHourlyData CALLED ===")
        logger.critical("🚀🚀🚀 [HOURLY_CHART] Processing hourly data with \(reportData.hourlyData.count) entries")
        logger.critical("🚀🚀🚀 [HOURLY_CHART] Current hour: \(currentHour)")
        logger.critical("🚀 [HOURLY_CHART] Total duration: \(reportData.totalDuration)s")
        logger.critical("🚀 [HOURLY_CHART] Apps count: \(reportData.allApps.count)")

        // Debug: Print all available hourly data
        for data in reportData.hourlyData {
            logger.critical("🚀 [HOURLY_CHART] Available data - Hour \(data.hour): \(String(format: "%.1f", data.totalMinutes))min, categories: \(data.categories.count)")
        }

        // Create map from existing hourly data
        var hourDataMap: [Int: ExtensionHourData] = [:]
        for data in reportData.hourlyData {
            hourDataMap[data.hour] = data
        }

        // Build chart data for all hours from 0 to currentHour
        hourlyChartData = (0...currentHour).map { hour in
            if let hourData = hourDataMap[hour] {
                // Use real data
                let isProductive = isHourProductive(hourData: hourData)
                return HourData(
                    hour: hour,
                    totalMinutes: hourData.totalMinutes,
                    isProductive: isProductive
                )
            } else {
                // No activity for this hour
                return HourData(hour: hour, totalMinutes: 0, isProductive: true)
            }
        }

        logger.critical("🚀🚀🚀 [HOURLY_CHART] Generated \(hourlyChartData.count) hour bars")
        for (index, data) in hourlyChartData.enumerated() {
            if data.totalMinutes > 0 {
                logger.critical("🚀 [HOURLY_CHART] Bar \(index): Hour \(data.hour) = \(String(format: "%.1f", data.totalMinutes))min [\(data.isProductive ? "GREEN" : "RED")]")
            } else {
                logger.critical("🚀 [HOURLY_CHART] Bar \(index): Hour \(data.hour) = 0min [EMPTY]")
            }
        }
    }

    private func isHourProductive(hourData: ExtensionHourData) -> Bool {
        // Categories considered distracting
        let distractingKeywords = ["Social", "Entertainment", "Games", "Photo", "Video"]

        let totalMinutes = hourData.totalMinutes
        guard totalMinutes > 0 else { return true }

        var distractingMinutes: Double = 0
        for (categoryName, minutes) in hourData.categories {
            if distractingKeywords.contains(where: { categoryName.contains($0) }) {
                distractingMinutes += minutes
            }
        }

        // If more than 50% is distracting time → red bar
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
                    // Icon
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apps Bloquées")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(activeBlocks.count) app\(activeBlocks.count > 1 ? "s" : "")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    // Expand icon
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

            // Expanded content
            if isBlockCardExpanded {
                VStack(spacing: 8) {
                    ForEach(activeBlocks, id: \.id) { block in
                        BlockedAppRow(block: block) {
                            // Recharger la liste après déblocage
                            loadActiveBlocks()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func loadActiveBlocks() {
        logger.critical("🔍 [FULLSTATS] === LOADING ACTIVE BLOCKS ===")

        let blockManager = BlockManager()
        let blocks = blockManager.getActiveBlocks()

        logger.critical("📊 [FULLSTATS] Found \(blocks.count) active blocks")
        for block in blocks {
            logger.critical("  → Block: \(block.appName)")
            logger.critical("     ID: \(block.id)")
            logger.critical("     Status: \(block.status.rawValue)")
            logger.critical("     Remaining: \(block.formattedRemainingTime)")
            logger.critical("     StoreName: \(block.storeName)")
        }

        activeBlocks = blocks

        if blocks.isEmpty {
            logger.warning("⚠️ [FULLSTATS] No active blocks found!")
            logger.warning("   This could mean:")
            logger.warning("   1. No blocks were created")
            logger.warning("   2. BlockManager failed to save")
            logger.warning("   3. BlockManager failed to read from App Group")
        }
    }

    // MARK: - Block Refresh Timer

    private func startBlockRefreshTimer() {
        // Timer pour vérifier les blocages toutes les 30 secondes
        blockRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            logger.info("⏱️ [FULLSTATS] Refreshing blocks...")

            // Recharger la liste pour afficher les changements
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
                // Fallback: placeholder coloré avec initiale
                placeholderIcon
            } else {
                Label(app.token)
                    .labelStyle(.iconOnly)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
                    .onAppear {
                        // ✅ OPTIMIZED: Timeout plus court pour fallback rapide
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !iconLoadFailed {
                                // Si après 0.5s l'icône n'est toujours pas chargée, utiliser fallback
                                iconLoadFailed = false
                            }
                        }
                    }
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
                    // Icône app avec lock indicator si bloquée
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

                        // Lock badge si bloquée
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
                        // ✅ OPTIMIZED: Chargement immédiat sans stagger delay
                        withAnimation(.easeIn(duration: 0.15)) {
                            iconVisible = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(isBlocked ? 0.6 : 1.0)

                        Text(isBlocked ? "Bloquée" : formatTime(app.duration))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isBlocked ? .red.opacity(0.8) : .white.opacity(0.5))
                    }

                    Spacer()

                    // Bouton de blocage compact ou checkmark si bloquée
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

                // Mini jauge horizontale
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeColor)
                        .frame(width: gaugeWidth, height: 6)
                }

                // Badge catégorie
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
        // Simuler (tu peux utiliser de vraies données de catégorie)
        index == 0 ? "Distracting" : "Productive"
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
    @Environment(\.openURL) var openURL  // ✅ API officielle pour ouvrir des URLs depuis extensions
    @State private var selectedDuration = 15 // minutes
    @State private var isBlocking = false
    @State private var showIcon = false
    var onBlockAdded: (() -> Void)?

    private let durations = [5, 15, 30, 60, 120, 240] // en minutes

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    // Icône et nom de l'app
                    VStack(spacing: 16) {
                        #if os(iOS)
                        if showIcon {
                            Label(app.token)
                                .labelStyle(.iconOnly)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            appPlaceholder
                        }
                        #else
                        appPlaceholder
                        #endif

                        Text(app.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Bloquer temporairement cette app")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Sélection de durée
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DURÉE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(durations, id: \.self) { duration in
                                    DurationButton(
                                        duration: duration,
                                        isSelected: selectedDuration == duration
                                    ) {
                                        selectedDuration = duration
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.horizontal, -20)
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Boutons d'action
                    VStack(spacing: 16) {
                        // Bouton Block
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

                                    Text("Bloquer \(selectedDuration) min")
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
                        .disabled(isBlocking)

                        // Bouton Cancel
                        Button {
                            dismiss()
                        } label: {
                            Text("Annuler")
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
            // ✅ OPTIMIZED: Chargement immédiat de l'icône
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showIcon = true
            }
        }
    }

    private var appPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
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
                .frame(width: 80, height: 80)

            Text(String(app.name.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func blockApp() {
        guard !isBlocking else { return }
        isBlocking = true

        #if os(iOS)
        let duration = TimeInterval(selectedDuration * 60)
        let blockId = UUID().uuidString
        let activityName = DeviceActivityName("block-\(blockId)")

        print("🎯 [BLOCK_SHEET] Starting IMMEDIATE block + auto-unblock")
        print("   → App: \(app.name)")
        print("   → Duration: \(Int(duration/60)) minutes")
        print("   → BlockID: \(blockId)")

        // Encoder le token
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [app.token]

        guard let tokenData = try? JSONEncoder().encode(selection) else {
            print("❌ [BLOCK_SHEET] Failed to encode token")
            self.isBlocking = false
            return
        }

        // 1️⃣ APPLIQUER LE SHIELD IMMÉDIATEMENT dans le store PAR DÉFAUT
        // ✅ CRUCIAL: Utiliser le store par défaut (sans nom) pour la persistance!
        // Le GlobalShieldManager utilise aussi ce store, donc cohérence garantie
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔒 [BLOCK_SHEET] ========== STEP 1: APPLYING SHIELD ==========")
        print("🔒 [BLOCK_SHEET] App: \(app.name)")
        print("🔒 [BLOCK_SHEET] Duration: \(Int(duration/60)) minutes")
        print("🔒 [BLOCK_SHEET] BlockID: \(blockId)")
        print("🔒 [BLOCK_SHEET] ActivityName: \(activityName.rawValue)")

        let store = ManagedSettingsStore() // ✅ Store par défaut = persistance!
        print("🔒 [BLOCK_SHEET] Created DEFAULT ManagedSettingsStore")

        let currentBlocked = store.shield.applications ?? Set()
        print("🔒 [BLOCK_SHEET] Current blocked apps in store: \(currentBlocked.count)")

        var blockedApps = currentBlocked
        let beforeCount = blockedApps.count
        blockedApps.insert(app.token)
        let afterCount = blockedApps.count

        print("🔒 [BLOCK_SHEET] Before insert: \(beforeCount) apps")
        print("🔒 [BLOCK_SHEET] After insert: \(afterCount) apps")
        print("🔒 [BLOCK_SHEET] Actually added: \(afterCount > beforeCount)")

        store.shield.applications = blockedApps
        print("✅ [BLOCK_SHEET] store.shield.applications = blockedApps EXECUTED")

        // Vérifier immédiatement
        let verifyBlocked = store.shield.applications?.count ?? 0
        print("🔒 [BLOCK_SHEET] Verification: store now has \(verifyBlocked) blocked apps")

        if verifyBlocked != afterCount {
            print("⚠️ [BLOCK_SHEET] MISMATCH! Expected \(afterCount) but got \(verifyBlocked)")
        }

        print("✅ [BLOCK_SHEET] Shield applied to DEFAULT store!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 2️⃣ ENVOYER LES DONNÉES À L'APP PRINCIPALE pour la sauvegarde
        print("📝 [BLOCK_SHEET] Report Extension cannot save to App Group (sandbox restriction)")
        print("📤 [BLOCK_SHEET] Opening main app to save block data...")

        // Encoder les données pour l'URL
        let blockData: [String: Any] = [
            "appName": app.name,
            "duration": duration,
            "activityName": activityName.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Encoder le token séparément (base64)
        let tokenBase64 = tokenData.base64EncodedString()

        // Créer l'URL avec les paramètres
        var urlComponents = URLComponents(string: "zenloop://save-block")!
        urlComponents.queryItems = [
            URLQueryItem(name: "appName", value: app.name),
            URLQueryItem(name: "duration", value: String(duration)),
            URLQueryItem(name: "activityName", value: activityName.rawValue),
            URLQueryItem(name: "tokenData", value: tokenBase64)
        ]

        if let url = urlComponents.url {
            print("🔗 [BLOCK_SHEET] Opening main app with block data...")
            openURL(url) { accepted in
                if accepted {
                    print("✅ [BLOCK_SHEET] Main app opened - block will be saved there")
                } else {
                    print("❌ [BLOCK_SHEET] Failed to open main app")
                }
            }
        } else {
            print("❌ [BLOCK_SHEET] Failed to create URL")
        }

        print("💾 [BLOCK_SHEET] Block will be saved by main app (has write permissions)")

        // 3️⃣ PROGRAMMER LE DÉBLOCAGE AUTOMATIQUE avec DeviceActivity
        let center = DeviceActivityCenter()
        let now = Date()
        let calendar = Calendar.current

        // Début = dans 1 seconde (contourner le problème "now")
        let startDate = now.addingTimeInterval(1)
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)

        // Fin = start + duration
        let endDate = now.addingTimeInterval(duration)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        // Note: Le déblocage automatique sera géré par l'app principale via DeviceActivity
        // Nous n'avons pas besoin de sauvegarder le payload ici car l'app le fera
        print("✅ [BLOCK_SHEET] Shield applied, sending data to main app...")

        // Feedback visuel + fermeture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isBlocking = false
            self.onBlockAdded?()
            self.dismiss()
        }
        #endif
    }

}

// MARK: - Duration Button

struct DurationButton: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

    private var displayText: String {
        if duration < 60 {
            return "\(duration)m"
        } else {
            let hours = duration / 60
            return "\(hours)h"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(displayText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .black : .white)

                if isSelected {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
        }
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
                // Lock icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                }

                // App name
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(block.status == .paused ? "En pause" : "Bloquée")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Remaining time
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRemainingTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Skeleton Loading View

/// ✅ OPTIMIZED: Skeleton UI pour feedback visuel instantané
struct SkeletonFullStatsView: View {
    @State private var isAnimating = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero skeleton
                VStack(spacing: 8) {
                    SkeletonBox(width: 200, height: 56)
                    SkeletonBox(width: 150, height: 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

                // Metrics row skeleton
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        SkeletonBox(width: 60, height: 12)
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonBox(width: 24, height: 24, cornerRadius: 6)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        SkeletonBox(width: 40, height: 22)
                        SkeletonBox(width: 80, height: 12)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        SkeletonBox(width: 30, height: 22)
                        SkeletonBox(width: 70, height: 12)
                    }
                }
                .padding(.vertical, 20)

                // Chart skeleton
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SkeletonBox(width: 100, height: 10)
                        Spacer()
                    }

                    HStack(alignment: .bottom, spacing: 1.5) {
                        ForEach(0..<18, id: \.self) { _ in
                            SkeletonBox(width: 15, height: CGFloat.random(in: 20...80), cornerRadius: 2)
                        }
                    }
                    .frame(height: 80)
                }
                .padding(.top, 30)

                // Apps list skeleton
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack(spacing: 12) {
                            SkeletonBox(width: 44, height: 44, cornerRadius: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                SkeletonBox(width: 120, height: 16)
                                SkeletonBox(width: 60, height: 14)
                            }

                            Spacer()

                            SkeletonBox(width: 24, height: 24, cornerRadius: 12)
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
}

struct SkeletonBox: View {
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    @State private var isAnimating = false

    var body: some View {
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
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating.toggle()
                }
            }
    }
}

