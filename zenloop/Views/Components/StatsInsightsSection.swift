//
//  StatsInsightsSection.swift
//  zenloop
//
//  Section pour afficher les statistiques d'utilisation via DeviceActivity
//

import SwiftUI
import DeviceActivity
import FamilyControls

struct StatsInsightsSection: View {
    let badgeManager: BadgeManager
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool

    @State private var refreshID = UUID()
    @State private var showFullStats = false

    // Filter pour DeviceActivityReport (aujourd'hui)
    private var dailyFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: today, end: tomorrow)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    var body: some View {
        #if os(iOS)
        Button {
            showFullStats = true
        } label: {
            // DeviceActivityReport avec hauteur réduite 280px - contenu simplifié (header + top 3 apps)
            DeviceActivityReport(DeviceActivityReport.Context("StatsActivity"), filter: dailyFilter)
                .frame(height: 300)
                .allowsHitTesting(false) // Désactive toute interaction - gestures passent au ScrollView parent
                .padding(.horizontal, 20)
                .padding(.top, -12)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
                .id(refreshID) // Force le rechargement quand l'ID change
        }
        .buttonStyle(.plain)
        .onAppear {
            // Forcer le refresh après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshID = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh quand l'app revient au premier plan
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshID = UUID()
            }
        }
        .fullScreenCover(isPresented: $showFullStats) {
            FullStatsView()
                .environmentObject(zenloopManager)
        }
        #else
        EmptyView()
        #endif
    }
}

#Preview {
    StatsInsightsSection(
        badgeManager: BadgeManager.shared,
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}
