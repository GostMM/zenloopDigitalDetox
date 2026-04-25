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
    @State private var chartAnimatedBars: Set<Int> = []
    @State private var pulsePhase: CGFloat = 0
    @State private var chartSegment: ChartSegment = .all
    @State private var introPhase: IntroPhase = .blackout
    @State private var introDisplayedSeconds: Double = 0
    @State private var introCounterTimer: Timer?
    @State private var introHapticCounter: Int = 0

    enum IntroPhase: Int, Comparable {
        case blackout = 0
        case counting = 1
        case counterDone = 2
        case revealed = 3
        static func < (lhs: IntroPhase, rhs: IntroPhase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum ChartSegment: String, CaseIterable, Identifiable {
        case all, morning, afternoon, evening
        var id: String { rawValue }
        var range: ClosedRange<Int> {
            switch self {
            case .all:       return 0...23
            case .morning:   return 0...11
            case .afternoon: return 12...17
            case .evening:   return 18...23
            }
        }
        var localizedLabel: String {
            switch self {
            case .all:       return String(localized: "chart_segment_all", defaultValue: "All day")
            case .morning:   return String(localized: "chart_morning")
            case .afternoon: return String(localized: "chart_afternoon")
            case .evening:   return String(localized: "chart_evening")
            }
        }
    }
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
            // Fond noir pur pendant l'intro, background coloré après reveal
            if introPhase < .revealed {
                Color.black.ignoresSafeArea()
            } else {
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
                    .transition(.opacity)

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
                    .transition(.opacity)
            }

            // INTRO COUNTER — fond noir, compteur qui grimpe
            if introPhase < .revealed {
                introCounterView
                    .transition(.opacity)
            }

            // CONTENT — reveal après intro
            if introPhase == .revealed && isContentReady {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroHeader

                        metricsRow
                            .padding(.top, 4)

                        if !activeBlocks.isEmpty {
                            blockedAppsSection
                                .padding(.top, 18)
                        }

                        hourlyChart
                            .padding(.top, 22)

                        timeOfflineSection
                            .padding(.top, 14)

                        appsListSectionHeader
                            .padding(.top, 24)
                            .padding(.bottom, 4)

                        appsList
                            .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 110)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            prepareContent()
            startBlockRefreshTimer()
            startIntroSequence()
        }
        .onDisappear {
            stopBlockRefreshTimer()
            introCounterTimer?.invalidate()
        }
    }

    // MARK: - Intro counter (style GuiltTrip)

    private var introCounterView: some View {
        VStack(spacing: 18) {
            Text(String(localized: "screen_time_today").uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundColor(.white.opacity(introPhase >= .counting ? 0.35 : 0))
                .animation(.easeIn(duration: 0.4), value: introPhase)

            ZStack {
                // Halo derrière le chiffre
                if introPhase >= .counterDone {
                    Text(introFormattedTime)
                        .font(.system(size: 84, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                        .blur(radius: 22)
                }

                Text(introFormattedTime)
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .scaleEffect(introPhase == .counterDone ? 1.08 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.38), value: introPhase)
            }
            .opacity(introPhase >= .counting ? 1 : 0)
            .frame(height: 100)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var introFormattedTime: String {
        let total = Int(introDisplayedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }

    private func startIntroSequence() {
        // Soft tap initial dès que l'écran apparaît
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.3)) { introPhase = .counting }
            startIntroCounter()
        }
    }

    private func startIntroCounter() {
        let target = reportData.todayScreenSeconds
        let totalDuration: Double = 2.2
        let fps: Double = 60
        let totalFrames = Int(totalDuration * fps)
        var currentFrame = 0
        introDisplayedSeconds = 0
        introHapticCounter = 0

        let tickGen = UIImpactFeedbackGenerator(style: .light)
        tickGen.prepare()

        introCounterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { timer in
            currentFrame += 1
            let progress = Double(currentFrame) / Double(totalFrames)

            if progress >= 1.0 {
                timer.invalidate()
                introDisplayedSeconds = target
                onIntroCounterFinished()
                return
            }

            let eased = 1.0 - pow(2.0, -10.0 * progress)
            introDisplayedSeconds = target * eased

            // Haptic tick tous les 7 frames (~8.5 ticks/s) pendant la montée rapide,
            // plus espacé sur la fin (easeOutExpo ralentit naturellement).
            introHapticCounter += 1
            if introHapticCounter >= 7 && progress < 0.9 {
                tickGen.impactOccurred(intensity: 0.55)
                introHapticCounter = 0
            }
        }
    }

    private func onIntroCounterFinished() {
        // Impact fort à l'arrivée sur la vraie valeur
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            introPhase = .counterDone
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.55)) {
                introPhase = .revealed
            }
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

    // MARK: - Hero Header (redesigned)

    private var heroHeader: some View {
        VStack(spacing: 6) {
            Text(String(localized: "screen_time_today"))
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1.8)

            Text(formattedTotalTime)
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            avgComparisonPill
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    /// Pill de comparaison avec la moyenne (affichée quand la moyenne existe et diffère du jour)
    @ViewBuilder
    private var avgComparisonPill: some View {
        let avg = reportData.averageDaily
        let today = reportData.todayScreenSeconds

        if avg > 60, abs(today - avg) > 60 {
            let isUnder = today < avg
            let deltaMinutes = Int(abs(today - avg) / 60)
            let color: Color = isUnder
                ? Color(red: 0.35, green: 0.9, blue: 0.55)
                : Color(red: 1.0, green: 0.45, blue: 0.45)

            HStack(spacing: 6) {
                Image(systemName: isUnder ? "arrow.down" : "arrow.up")
                    .font(.system(size: 10, weight: .heavy))
                Text("\(deltaMinutes)m \(isUnder ? String(localized: "less_than_avg") : String(localized: "more_than_avg"))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(color.opacity(0.14))
                    .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
            )
        }
    }

    // MARK: - Metrics Row (3 cards)

    private var metricsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            // Most used
            VStack(spacing: 12) {
                Text(String(localized: "most_used_label"))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)

                HStack(spacing: -8) {
                    if !reportData.topThreeMostUsed.isEmpty {
                        ForEach(Array(reportData.topThreeMostUsed.prefix(3).enumerated()), id: \.offset) { index, app in
                            AppIconBadge(app: app, size: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.35), lineWidth: 1.5)
                                )
                                .zIndex(Double(3 - index))
                        }
                    } else {
                        Text("—")
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .frame(height: 34)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 44)

            // Focus score with ring
            VStack(spacing: 8) {
                Text(String(localized: "focus_score_label"))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)

                FocusScoreRing(score: reportData.focusScore, size: 46)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 44)

            // Categories
            VStack(spacing: 10) {
                Text(String(localized: "categories_label"))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)

                Text("\(reportData.categoriesCount)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hourly Chart (compact — Apple Screen Time style)

    private var hourlyChart: some View {
        let chartHeight: CGFloat = 130
        let currentHour = Calendar.current.component(.hour, from: Date())
        let visibleData = hourlyChartData.filter { chartSegment.range.contains($0.hour) }
        let maxMinutes = max(30.0, (visibleData.map { $0.totalMinutes }.max() ?? 0).rounded(.up))
        let yAxisMax = maxMinutes <= 30 ? 30.0 : (maxMinutes <= 60 ? 60.0 : ((maxMinutes / 30).rounded(.up) * 30))
        let scale = chartHeight / yAxisMax

        return VStack(alignment: .leading, spacing: 10) {
            // Ligne compacte : label + segment dropdown
            HStack(alignment: .center, spacing: 8) {
                Text(String(localized: "today_activity_label"))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)

                Spacer()

                segmentMenu
            }

            // Chart avec Y-axis intégrée (flottante)
            chartCanvas(
                data: visibleData,
                chartHeight: chartHeight,
                yAxisMax: yAxisMax,
                scale: scale,
                currentHour: currentHour
            )

            // Category totals compact — 1 ligne scrollable
            categoryTotalsRow
        }
        .onAppear {
            animateBarsInCascade()
            startPulse()
        }
        .onChange(of: chartSegment) { _, _ in
            animateBarsInCascade()
        }
    }

    private var segmentMenu: some View {
        Menu {
            ForEach(ChartSegment.allCases) { segment in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        chartSegment = segment
                    }
                } label: {
                    if chartSegment == segment {
                        Label(segment.localizedLabel, systemImage: "checkmark")
                    } else {
                        Text(segment.localizedLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(chartSegment.localizedLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.07)))
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func chartCanvas(data: [HourData], chartHeight: CGFloat, yAxisMax: Double, scale: CGFloat, currentHour: Int) -> some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let hourCount = chartSegment.range.count
            let slotWidth = totalW / CGFloat(hourCount)
            let barWidth = max(2.5, slotWidth * 0.5)
            let gridHours = gridHoursForSegment(chartSegment)

            ZStack(alignment: .topLeading) {
                // Horizontal grid lines + Y-axis labels flottants (inline au-dessus des lignes)
                ForEach([yAxisMax, yAxisMax / 2, 0.0], id: \.self) { level in
                    let y = chartHeight - CGFloat(level) * scale
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: totalW, height: 0.5)
                            .offset(y: y)

                        if level > 0 {
                            Text("\(Int(level))m")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .offset(x: -2, y: y - 12)
                        }
                    }
                    .frame(width: totalW, alignment: .topTrailing)
                }

                // Vertical dashed grid lines
                ForEach(gridHours, id: \.self) { hour in
                    let x = xPositionForHour(hour, slotWidth: slotWidth)
                    DashedVerticalLine()
                        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .frame(width: 1, height: chartHeight)
                        .offset(x: x, y: 0)
                }

                // Bars
                ForEach(data, id: \.hour) { hourData in
                    let slotIndex = hourData.hour - chartSegment.range.lowerBound
                    let isCurrent = hourData.hour == currentHour
                    let isAnimated = chartAnimatedBars.contains(hourData.hour)
                    let rawHeight = CGFloat(hourData.totalMinutes) * scale
                    let animatedHeight = isAnimated ? rawHeight : 0
                    let xCenter = (CGFloat(slotIndex) + 0.5) * slotWidth

                    stackedBar(segments: hourData.segments, width: barWidth, height: animatedHeight, isCurrent: isCurrent)
                        .shadow(
                            color: isCurrent
                                ? Color(red: 1.0, green: 0.78, blue: 0.3).opacity(0.4 + 0.2 * pulsePhase)
                                : .clear,
                            radius: isCurrent ? 5 + 2 * pulsePhase : 0
                        )
                        .position(x: xCenter, y: chartHeight - animatedHeight / 2)
                }

                // X-axis hour labels inline sous la ligne 0
                ForEach(gridHours, id: \.self) { hour in
                    Text(String(format: "%02dh", hour))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.38))
                        .fixedSize()
                        .offset(x: xPositionForHour(hour, slotWidth: slotWidth) + 3, y: chartHeight + 3)
                }
            }
            .frame(width: totalW, height: chartHeight + 16)
        }
        .frame(height: chartHeight + 16)
    }

    private func xPositionForHour(_ hour: Int, slotWidth: CGFloat) -> CGFloat {
        CGFloat(hour - chartSegment.range.lowerBound) * slotWidth
    }

    private func gridHoursForSegment(_ segment: ChartSegment) -> [Int] {
        switch segment {
        case .all:       return [0, 6, 12, 18]
        case .morning:   return [0, 4, 8]
        case .afternoon: return [12, 15]
        case .evening:   return [18, 21]
        }
    }

    @ViewBuilder
    private func stackedBar(segments: [HourSegment], width: CGFloat, height: CGFloat, isCurrent: Bool) -> some View {
        let totalMin = Swift.max(0.0001, segments.reduce(0) { $0 + $1.minutes })

        VStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                let segHeight = height * CGFloat(segment.minutes / totalMin)
                Rectangle()
                    .fill(segment.color.opacity(isCurrent ? 1.0 : 0.9))
                    .frame(width: width, height: segHeight)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: height)
    }

    // MARK: - Category totals (style Apple)

    private var categoryTotalsRow: some View {
        let totals = Array(categoryTotals.prefix(5))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(totals, id: \.name) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(entry.color)
                            .frame(width: 6, height: 6)
                        Text(entry.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                        Text(formatCategoryTotal(entry.minutes))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                }
            }
        }
    }

    private var categoryTotals: [(name: String, color: Color, minutes: Double)] {
        var acc: [String: (color: Color, minutes: Double)] = [:]
        for hour in hourlyChartData where chartSegment.range.contains(hour.hour) {
            for seg in hour.segments {
                let prev = acc[seg.name]?.minutes ?? 0
                acc[seg.name] = (color: seg.color, minutes: prev + seg.minutes)
            }
        }
        return acc
            .map { (name: $0.key, color: $0.value.color, minutes: $0.value.minutes) }
            .sorted { $0.minutes > $1.minutes }
    }

    private func formatCategoryTotal(_ minutes: Double) -> String {
        let total = Int(minutes)
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)min" }
        if h > 0 { return "\(h)h" }
        return "\(m)min"
    }

    private func animateBarsInCascade() {
        chartAnimatedBars.removeAll()
        let visible = hourlyChartData.filter { chartSegment.range.contains($0.hour) }
        for (index, data) in visible.enumerated() {
            let delay = Double(index) * 0.02
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    _ = chartAnimatedBars.insert(data.hour)
                }
            }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulsePhase = 1
        }
    }

    // MARK: - Apps list section header

    private var appsListSectionHeader: some View {
        HStack {
            Text(String(localized: "apps_section_title"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Text("\(reportData.allApps.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    private var timeOfflineSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.95))

            Text(String(localized: "time_offline"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Text("·")
                .foregroundColor(.white.opacity(0.25))

            Text(formattedOfflinePercentage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))

            Spacer()

            Text(formattedOfflineTime)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
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
                let segments = hourData.categories
                    .filter { $0.value > 0 }
                    .sorted { $0.value > $1.value }
                    .map { HourSegment(name: Self.shortCategoryName($0.key), minutes: $0.value, color: Self.colorForCategory($0.key)) }
                return HourData(
                    hour: hour,
                    totalMinutes: hourData.totalMinutes,
                    segments: segments
                )
            } else {
                return HourData(hour: hour, totalMinutes: 0, segments: [])
            }
        }

        logger.critical("🚀🚀🚀 [HOURLY_CHART] Generated \(hourlyChartData.count) hour bars")
    }

    static func colorForCategory(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("social") { return Color(red: 0.78, green: 0.42, blue: 0.95) }      // purple
        if lower.contains("entertainment") { return Color(red: 1.00, green: 0.42, blue: 0.55) } // pink
        if lower.contains("game") { return Color(red: 1.00, green: 0.60, blue: 0.25) }         // orange
        if lower.contains("photo") || lower.contains("video") { return Color(red: 0.95, green: 0.35, blue: 0.75) } // magenta
        if lower.contains("productivity") || lower.contains("finance") || lower.contains("business") {
            return Color(red: 0.35, green: 0.85, blue: 0.55)                                   // green
        }
        if lower.contains("creativity") { return Color(red: 0.30, green: 0.80, blue: 0.80) }   // teal
        if lower.contains("education") || lower.contains("reading") || lower.contains("reference") {
            return Color(red: 0.40, green: 0.65, blue: 1.00)                                   // blue
        }
        if lower.contains("information") || lower.contains("news") { return Color(red: 0.35, green: 0.80, blue: 0.95) } // cyan
        if lower.contains("health") || lower.contains("fitness") { return Color(red: 0.55, green: 0.90, blue: 0.45) }   // lime
        if lower.contains("shopping") || lower.contains("food") { return Color(red: 1.00, green: 0.75, blue: 0.35) }    // amber
        if lower.contains("travel") { return Color(red: 0.45, green: 0.75, blue: 1.00) }       // sky
        if lower.contains("music") { return Color(red: 0.75, green: 0.55, blue: 1.00) }        // violet
        return Color(red: 0.60, green: 0.65, blue: 0.75) // neutral grey-blue
    }

    static func shortCategoryName(_ name: String) -> String {
        let trimmed = name.replacingOccurrences(of: " and ", with: " & ")
        if trimmed.count > 18 {
            return String(trimmed.prefix(16)) + "…"
        }
        return trimmed
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
                .padding(.vertical, 12)
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
        let segments: [HourSegment]
    }

    struct HourSegment {
        let name: String
        let minutes: Double
        let color: Color
    }
}

// MARK: - Focus Score Ring

struct FocusScoreRing: View {
    let score: Int
    let size: CGFloat

    private var ringColor: Color {
        if score >= 70 { return Color(red: 0.4, green: 0.9, blue: 0.5) }
        if score >= 40 { return Color(red: 1.0, green: 0.7, blue: 0.2) }
        return Color(red: 1.0, green: 0.35, blue: 0.35)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.75), ringColor, ringColor.opacity(0.75)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: score)

            Text("\(score)")
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        #if os(iOS)
                        if iconVisible {
                            Label(app.token)
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .opacity(isBlocked ? 0.55 : 1.0)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBlocked ? Color.red.opacity(0.45) : Color.clear, lineWidth: 2)
                                )
                                .transition(.opacity)
                        } else {
                            placeholderIcon
                                .opacity(isBlocked ? 0.55 : 1.0)
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
                        HStack(spacing: 8) {
                            Text(app.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .opacity(isBlocked ? 0.6 : 1.0)
                                .lineLimit(1)

                            // Tag catégorie sur TOUTES les rows
                            Text(categoryLabel)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(categoryColor)
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(categoryColor.opacity(0.15)))
                        }

                        Text(isBlocked ? String(localized: "blocked_status") : formatTime(app.duration))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(isBlocked ? .red.opacity(0.8) : .white.opacity(0.55))
                    }

                    Spacer()

                    // Action pill (plus discrète que l'ancien cercle)
                    if isBlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.red)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.red.opacity(0.14)))
                    } else {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                }

                // Barre de progression
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeColor)
                        .frame(width: gaugeWidth, height: 5)
                }
            }
            .padding(.vertical, 12)
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

    struct QuickPreset {
        let label: String
        let totalMinutes: Int
    }

    static let quickPresets: [QuickPreset] = [
        QuickPreset(label: "15m", totalMinutes: 15),
        QuickPreset(label: "30m", totalMinutes: 30),
        QuickPreset(label: "1h", totalMinutes: 60),
        QuickPreset(label: "2h", totalMinutes: 120)
    ]

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

                    VStack(spacing: 16) {
                        // Presets rapides
                        HStack(spacing: 10) {
                            ForEach(Self.quickPresets, id: \.totalMinutes) { preset in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        selectedHours = preset.totalMinutes / 60
                                        selectedMinutes = preset.totalMinutes % 60
                                    }
                                } label: {
                                    Text(preset.label)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(totalMinutes == preset.totalMinutes ? .black : .white.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(totalMinutes == preset.totalMinutes ? Color.white : Color.white.opacity(0.08))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)

                        // Picker custom
                        VStack(spacing: 10) {
                            Text(String(localized: "duration_picker_label"))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1.2)

                            HStack(spacing: 16) {
                                VStack(spacing: 4) {
                                    Text(String(localized: "hours_label"))
                                        .font(.system(size: 11, weight: .semibold))
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
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))

                                    Picker("", selection: $selectedMinutes) {
                                        ForEach([0, 5, 10, 15, 20, 30, 45], id: \.self) { minute in
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
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                    }

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

// MARK: - Dashed vertical line shape

struct DashedVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - FlowLayout (wrap des badges de légende)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth && currentRowWidth > 0 {
                totalHeight += rowHeight + spacing
                currentRowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}