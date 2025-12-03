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
        DeviceActivityReport(DeviceActivityReport.Context("StatsActivity"), filter: dailyFilter)
            .frame(height: 500)
            .padding(.horizontal, 20)
            .padding(.top, -12)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
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
