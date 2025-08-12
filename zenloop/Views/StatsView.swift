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
import UIKit // haptique léger

// MARK: - Shared DTO (si tu as déjà SharedModels.swift commun App+Extension, supprime ce bloc)
private struct SharedReportPayload: Codable {
    let intervalStart: TimeInterval
    let intervalEnd: TimeInterval
    let totalSeconds: Double
    let averageDailySeconds: Double
    let updatedAt: TimeInterval
    let topCategories: [SRPCategory]
    let days: [SRPDayPoint]
}
private struct SRPCategory: Codable { let name: String; let seconds: Double; let appCount: Int }
private struct SRPDayPoint:  Codable { let dayStart: TimeInterval; let seconds: Double }

// MARK: - Store (App Group + temps économisé)
final class SharedActivityStore: ObservableObject {
    struct DayPoint: Identifiable { let id = UUID(); let date: Date; let seconds: Double }
    struct CategorySlice: Identifiable { let id = UUID(); let name: String; let seconds: Double; let appCount: Int }
    
    @Published var interval: DateInterval = .init(start: Date(), end: Date())
    @Published var totalSeconds: Double = 0
    @Published var averageDailySeconds: Double = 0
    @Published var days: [DayPoint] = []
    @Published var topCategories: [CategorySlice] = []
    @Published var updatedAt: Date = Date()
    @Published var savedSeconds: Double = 0
    
    private let appGroup = "group.com.app.zenloop"
    private let reportKey = "DAReportLatest"
    private let savedKey  = "zenloop.savedSeconds"
    
    func load() {
        // Utilisation sécurisée de UserDefaults avec gestion d'erreurs et fallback
        do {
            // Essayer d'abord l'App Group, avec fallback vers UserDefaults standard
            let shared = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
            
            if let data = shared.data(forKey: reportKey) {
                let p = try JSONDecoder().decode(SharedReportPayload.self, from: data)
                interval = .init(start: Date(timeIntervalSince1970: p.intervalStart),
                                 end:   Date(timeIntervalSince1970: p.intervalEnd))
                totalSeconds        = p.totalSeconds
                averageDailySeconds = p.averageDailySeconds
                updatedAt           = Date(timeIntervalSince1970: p.updatedAt)
                days = p.days.map { .init(date: Date(timeIntervalSince1970: $0.dayStart), seconds: $0.seconds) }
                topCategories = p.topCategories.map { .init(name: $0.name, seconds: $0.seconds, appCount: $0.appCount) }
            } else {
                resetToDefaults()
            }
        } catch {
            print("⚠️ [STATS] Erreur chargement données partagées: \(error)")
            resetToDefaults()
        }
        
        // Chargement local sécurisé
        savedSeconds = UserDefaults.standard.double(forKey: savedKey)
    }
    
    private func resetToDefaults() {
        interval = .init(start: Calendar.current.startOfDay(for: Date()), end: Date())
        totalSeconds = 0
        averageDailySeconds = 0
        days = []
        topCategories = []
        updatedAt = Date()
    }
    
    func addSaved(seconds: Double) {
        let v = max(0, savedSeconds + seconds)
        savedSeconds = v
        UserDefaults.standard.set(v, forKey: savedKey)
    }
}

// MARK: - Layout constants
private enum UIx { static let hPad: CGFloat = 16; static let sectionGap: CGFloat = 14 }

// MARK: - StatsView

struct StatsView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @StateObject private var screenTimeManager = RealScreenTimeManager()
    @StateObject private var store = SharedActivityStore()
    
    @Namespace private var navAnim
    @State private var show = false
    @State private var selected: Screen = .apple
    @State private var selectedPeriod: TimePeriod = .today
    @State private var reportInstanceID = UUID()
    @State private var hasInitiallyLoaded = false
    
    enum Screen: String, CaseIterable, Identifiable {
        case apple = "apple", overview = "overview", analytics = "analytics"
        var id: String { rawValue }
        var icon: String {
            switch self { case .apple: "chart.bar.xaxis"; case .overview: "rectangle.grid.2x2"; case .analytics: "waveform.path.ecg" }
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
            
            VStack(spacing: 8) {
                header
                controlRow
                contentPages
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { show = true }
            screenTimeManager.checkAuthorization()
            screenTimeManager.selectedPeriod = selectedPeriod
            
            // Chargement initial avec retry automatique
            if !hasInitiallyLoaded {
                hasInitiallyLoaded = true
                loadInitialData()
            } else {
                // Si déjà chargé, juste un refresh léger
                store.load()
            }
        }
        .onChange(of: selectedPeriod) { _, new in
            screenTimeManager.selectedPeriod = new
            refreshReport()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header (compact)
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "statistics"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(show ? 1 : 0)
                Text("\(dateRange(store.interval)) • \(lastUpdated(store.updatedAt))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                    .opacity(show ? 1 : 0)
            }
            Spacer()
            Button {
                refreshReport()
                store.load()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // Retry intelligent si pas de données après 0.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if store.totalSeconds == 0 && store.days.isEmpty {
                        print("🔄 [STATS] Refresh auto-retry")
                        store.load()
                        refreshReport()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel(String(localized: "refresh"))
        }
        .padding([.leading, .trailing], 20)
        .padding(.top, 10)
        .animation(.easeOut(duration: 0.6), value: show)
    }
    
    // MARK: - Controls row (période + micro-nav icônes)
    private var controlRow: some View {
        HStack(spacing: 10) {
            Picker("", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases) { p in Text(LocalizedStringKey(p.rawValue)).tag(p) }
            }
            .pickerStyle(.segmented)
            
            Spacer(minLength: 8)
            
            MicroNav(selected: $selected, namespace: navAnim)
            
            if !screenTimeManager.isAuthorized {
                Button {
                    Task { await screenTimeManager.requestAuthorization() }
                } label: {
                    Image(systemName: "lock.open")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(String(localized: "authorize_screen_time"))
                }
            }
        }
        .padding([.leading, .trailing], 20)
    }
    
    // MARK: - Content (TabView pages + swipe)
    private var contentPages: some View {
        TabView(selection: $selected) {
            // Apple
            AppleScreen(
                isAuthorized: screenTimeManager.isAuthorized,
                context: screenTimeManager.reportContext,
                filter: screenTimeManager.currentFilter,
                reportInstanceID: reportInstanceID
            )
            .tag(Screen.apple)
            
            // Aperçu
            OverviewScreen(
                totalSeconds: store.totalSeconds,
                offScreenSeconds: offScreenSeconds,
                savedSeconds: store.savedSeconds,
                savedPct: savedPct
            )
            .tag(Screen.overview)
            
            // Analyses
            AnalyticsScreen(days: store.days, slices: store.topCategories)
                .tag(Screen.analytics)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.18), value: selected)
    }
    
    // MARK: - Helpers
    private func refreshReport() { reportInstanceID = UUID() }
    
    private func loadInitialData() {
        // Chargement immédiat
        store.load()
        
        // Si pas de données, retry avec délai progressif
        Task {
            var retryCount = 0
            while retryCount < 3 && store.totalSeconds == 0 && store.days.isEmpty {
                retryCount += 1
                let delay = Double(retryCount) * 0.5 // 0.5s, 1s, 1.5s
                
                print("📊 [STATS] Retry \(retryCount)/3 dans \(delay)s")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                await MainActor.run {
                    store.load()
                    refreshReport()
                }
            }
            
            if store.totalSeconds > 0 || !store.days.isEmpty {
                print("✅ [STATS] Données chargées après \(retryCount) tentatives")
            } else {
                print("⚠️ [STATS] Aucune donnée disponible après 3 tentatives")
            }
        }
    }
    private func lastUpdated(_ date: Date) -> String {
        RelativeDateTimeFormatter.cached.localizedString(for: date, relativeTo: Date())
            .replacingOccurrences(of: "il y a ", with: String(localized: "updated_maj"))
    }
    private func dateRange(_ i: DateInterval) -> String {
        let s = DateFormatter.dayMonth.string(from: i.start)
        let e = DateFormatter.dayMonth.string(from: i.end)
        return s == e ? s : "\(s) – \(e)"
    }
}

// MARK: - Micro Nav (icônes seules, 28pt)

private struct MicroNav: View {
    @Binding var selected: StatsView.Screen
    var namespace: Namespace.ID
    
    private let items: [StatsView.Screen] = [.apple, .overview, .analytics]
    private let size: CGFloat = 28
    private let paddingH: CGFloat = 6
    private let paddingV: CGFloat = 4
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { s in
                navButton(for: s)
            }
        }
        .padding(.horizontal, paddingH)
        .padding(.vertical, paddingV)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
    }
    
    @ViewBuilder
    private func navButton(for s: StatsView.Screen) -> some View {
        Button {
            selected = s
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                if selected == s {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.16))
                        .matchedGeometryEffect(id: "micro-pill", in: namespace)
                        .frame(height: size)
                        .transition(.opacity)
                }
                Image(systemName: s.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(selected == s ? 1 : 0.85))
                    .frame(width: size, height: size)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(LocalizedStringKey(s.rawValue))
    }
}

// MARK: - Screens

// 1) Apple — pas de card, scroll natif du rapport
private struct AppleScreen: View {
    let isAuthorized: Bool
    let context: DeviceActivityReport.Context
    let filter: DeviceActivityFilter
    let reportInstanceID: UUID
    
    var body: some View {
        VStack(spacing: 8) {
            if isAuthorized {
                DeviceActivityReport(context, filter: filter)
                    .id(reportInstanceID)                // refresh uniquement quand période change
                    .frame(minHeight: 340)
                    .padding([.leading, .trailing], 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 28))
                    Text(String(localized: "authorize_screen_time_detail"))
                        .font(.footnote).foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding([.leading, .trailing], 20)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding([.leading, .trailing], 20)
            }
        }
    }
}

// 2) Aperçu — métriques + insight
private struct OverviewScreen: View {
    let totalSeconds: Double
    let offScreenSeconds: Double
    let savedSeconds: Double
    let savedPct: Int
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: UIx.sectionGap) {
                SectionBlock(title: String(localized: "overview")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        MetricTile(title: String(localized: "screen"), value: DateComponentsFormatter.cached.string(from: totalSeconds) ?? "0 min", icon: "iphone")
                        MetricTile(title: String(localized: "off_screen"), value: DateComponentsFormatter.cached.string(from: offScreenSeconds) ?? "0 min", icon: "moon")
                        MetricTile(title: String(localized: "saved"), value: DateComponentsFormatter.cached.string(from: savedSeconds) ?? "0 min", icon: "shield.lefthalf.filled")
                    }
                    if savedSeconds > 0 {
                        InsightTile(text: String(localized: "you_saved_time_percent", defaultValue: "You saved \(DateComponentsFormatter.cached.string(from: savedSeconds) ?? "0 min") (\(savedPct)%) during this period.", table: nil, bundle: .main, comment: "").replacingOccurrences(of: "%@", with: DateComponentsFormatter.cached.string(from: savedSeconds) ?? "0 min").replacingOccurrences(of: "%d", with: "\(savedPct)"),
                                    icon: "lightbulb")
                    }
                }
                .padding([.leading, .trailing], UIx.hPad)
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
    }
}

// 3) Analyses — tendance + top catégories
private struct AnalyticsScreen: View {
    let days: [SharedActivityStore.DayPoint]
    let slices: [SharedActivityStore.CategorySlice]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: UIx.sectionGap) {
                SectionBlock(title: String(localized: "analytics")) {
                    VStack(spacing: 10) {
                        MiniChartCard(title: String(localized: "trend")) { Sparkline(days: days) }
                        MiniChartCard(title: String(localized: "top_categories")) { TopCategoriesMini(slices: slices) }
                    }
                }
                .padding([.leading, .trailing], UIx.hPad)
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - UI Components

private struct SectionBlock<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            content
        }
    }
}

private struct MetricTile: View {
    let title: String, value: String, icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white).lineLimit(1)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsightTile: View {
    let text: String, icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.yellow)
            Text(text).font(.footnote).foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MiniChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
            content.frame(minHeight: 130)
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Mini charts

private struct Sparkline: View {
    let days: [SharedActivityStore.DayPoint]
    var body: some View {
        if days.isEmpty {
            ChartEmpty()
        } else {
            Chart(days) { p in
                LineMark(x: .value("Jour", p.date, unit: .day), y: .value("s", p.seconds))
                AreaMark(x: .value("Jour", p.date, unit: .day), y: .value("s", p.seconds))
                    .opacity(0.15)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { val in
                    AxisValueLabel {
                        if let v = val.as(Double.self) { Text(Self.short(v)) }
                    }
                }
            }
        }
    }
    private static func short(_ s: Double) -> String { s >= 3600 ? "\(Int(s/3600))h" : "\(Int(round(s/60)))m" }
}

private struct TopCategoriesMini: View {
    let slices: [SharedActivityStore.CategorySlice]
    var body: some View {
        if slices.isEmpty { ChartEmpty() }
        else {
            Chart(slices) { s in BarMark(x: .value("s", s.seconds), y: .value("Cat", s.name)) }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(v >= 3600 ? "\(Int(v/3600))h" : "\(Int(round(v/60)))m") }
                        }
                    }
                }
        }
    }
}

private struct ChartEmpty: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundColor(.white.opacity(0.6))
            Text(String(localized: "not_enough_data")).font(.caption).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Screen Time Manager (sans filtre d’appareils)

final class RealScreenTimeManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var selectedPeriod: StatsView.TimePeriod = .today
    
    private let authorizationCenter = AuthorizationCenter.shared
    let reportContext = DeviceActivityReport.Context("TotalActivity")
    
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

// MARK: - Formatters (cachés pour perf)

private extension DateComponentsFormatter {
    static let cached: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .short
        f.zeroFormattingBehavior = [.pad]
        return f
    }()
}

private extension RelativeDateTimeFormatter {
    static let cached: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = .current
        f.unitsStyle = .abbreviated
        return f
    }()
}

private extension DateFormatter {
    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
}

