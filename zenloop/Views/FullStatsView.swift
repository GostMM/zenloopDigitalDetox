//
//  FullStatsView.swift
//  zenloop
//
//  Vue Stats complète style Opal - Entièrement DeviceActivityReport
//

import SwiftUI
import DeviceActivity
import FamilyControls

struct FullStatsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var reportKey = UUID() // Force reload du DeviceActivityReport

    // Lazy loading des managers
    private var purchaseManager: PurchaseManager { PurchaseManager.shared }

    // Filter pour toute la journée (de minuit à maintenant)
    private var dailyFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: today, end: now)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
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

            // TOUTE la page est un DeviceActivityReport
            #if os(iOS)
            ZStack {
                // ✅ OPTIMIZED: Afficher un skeleton pendant le chargement initial
                if !showContent {
                    InstantStatsPreview()
                        .transition(.opacity)
                }

                // Le vrai DeviceActivityReport
                DeviceActivityReport(
                    DeviceActivityReport.Context("FullStatsPage"),
                    filter: dailyFilter
                )
                .id(reportKey) // Permet de forcer le reload
                .ignoresSafeArea(edges: .bottom)
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showContent)
            }
            #else
            Text("Full stats view available on iOS only")
                .foregroundColor(.white)
            #endif

            // MinimalHeader overlay en haut
            VStack {
                MinimalHeader(
                    showContent: showContent,
                    currentState: zenloopManager.currentState,
                    isPremium: purchaseManager.isPremium,
                    zenloopManager: zenloopManager
                )
                .padding(.horizontal, 20)
                .padding(.top, getSafeAreaTop())
                .background(
                    // Gradient fade pour meilleure lisibilité
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .task {
            // ✅ OPTIMIZED: Délai intelligent pour laisser le report se charger
            // Le skeleton reste visible pendant ce temps
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s

            withAnimation {
                showContent = true
            }
        }
        .refreshable {
            // Pull to refresh pour recharger les données
            reportKey = UUID()
            showContent = false

            try? await Task.sleep(nanoseconds: 800_000_000)

            withAnimation {
                showContent = true
            }
        }
    }

    // MARK: - Safe Area Helper

    private func getSafeAreaTop() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.top
    }
}

// MARK: - Instant Stats Preview (Cached Data)

/// ✅ OPTIMIZED: Affichage instantané des dernières données pendant que le report se charge
struct InstantStatsPreview: View {
    @State private var cachedData: InstantStatsData?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero section avec données cachées
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

                // Metrics row avec données cachées
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("MOST USED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)

                        if let topApps = cachedData?.topApps, !topApps.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(topApps.prefix(3), id: \.self) { appName in
                                    AppNameBadge(name: appName)
                                }
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("\(cachedData?.focusScore ?? 0)%")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(focusScoreColor(cachedData?.focusScore ?? 0))

                        Text("FOCUS SCORE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("\(cachedData?.categoriesCount ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        Text("CATEGORIES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1)
                    }
                }
                .padding(.vertical, 20)

                // Chart skeleton avec pulse
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SkeletonBox(width: 100, height: 10)
                        Spacer()
                    }

                    if let hourlyData = cachedData?.hourlyData {
                        SimpleHourlyChart(data: hourlyData)
                    } else {
                        HStack(alignment: .bottom, spacing: 1.5) {
                            ForEach(0..<18, id: \.self) { _ in
                                SkeletonBox(width: 15, height: CGFloat.random(in: 20...80), cornerRadius: 2)
                            }
                        }
                        .frame(height: 80)
                    }
                }
                .padding(.top, 30)

                Spacer(minLength: 200)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .onAppear {
            loadCachedData()
        }
    }

    private var formattedTotalTime: String {
        guard let duration = cachedData?.totalDuration else { return "0h 0m" }

        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }

    private func focusScoreColor(_ score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }

    private func loadCachedData() {
        guard let shared = UserDefaults(suiteName: "group.com.app.zenloop"),
              let data = shared.data(forKey: "DAReportLatest") else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(SharedReportPayload.self, from: data)

            // Calculer focus score
            let focusScore = calculateFocusScore(from: payload.topCategories)

            cachedData = InstantStatsData(
                totalDuration: payload.todayScreenSeconds,
                focusScore: focusScore,
                topApps: payload.topApps.prefix(3).map { $0.name },
                categoriesCount: payload.topCategories.count,
                hourlyData: payload.hourlyData.compactMap { hourPoint in
                    guard !hourPoint.categories.isEmpty else { return nil }
                    let totalMinutes = hourPoint.categories.reduce(0) { $0 + $1.seconds / 60.0 }
                    return SimpleHourPoint(hour: hourPoint.hour, totalMinutes: totalMinutes)
                }
            )

        } catch {
            print("❌ Failed to load cached data: \(error)")
        }
    }

    private func calculateFocusScore(from categories: [SharedReportCategory]) -> Int {
        guard !categories.isEmpty else { return 0 }

        let distractingKeywords = ["Social", "Entertainment", "Games", "Photo", "Video"]
        var productiveTime: Double = 0
        var distractingTime: Double = 0

        for category in categories {
            let isDistracting = distractingKeywords.contains(where: { category.name.contains($0) })
            if isDistracting {
                distractingTime += category.seconds
            } else {
                productiveTime += category.seconds
            }
        }

        let totalTime = productiveTime + distractingTime
        guard totalTime > 0 else { return 0 }
        return Int((productiveTime / totalTime) * 100)
    }
}

struct InstantStatsData {
    let totalDuration: TimeInterval
    let focusScore: Int
    let topApps: [String]
    let categoriesCount: Int
    let hourlyData: [SimpleHourPoint]
}

struct SimpleHourPoint {
    let hour: Int
    let totalMinutes: Double
}

struct AppNameBadge: View {
    let name: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
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
                .frame(width: 24, height: 24)

            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct SimpleHourlyChart: View {
    let data: [SimpleHourPoint]

    var body: some View {
        let chartHeight: CGFloat = 80
        let maxMinutes: Double = 60

        GeometryReader { geometry in
            let barCount = CGFloat(data.count)
            let totalSpacing = CGFloat(data.count - 1) * 1.5
            let availableWidth = geometry.size.width - totalSpacing
            let barWidth = barCount > 0 ? availableWidth / barCount : 0

            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(data, id: \.hour) { point in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.3))
                        .frame(
                            width: barWidth,
                            height: max(2, CGFloat(point.totalMinutes / maxMinutes) * chartHeight)
                        )
                }
            }
        }
        .frame(height: chartHeight)
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

#Preview {
    FullStatsView()
}
