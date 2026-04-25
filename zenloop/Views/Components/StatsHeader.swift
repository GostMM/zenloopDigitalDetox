//
//  StatsHeader.swift
//  zenloop
//
//  Header dédié à la page Stats — titre + date + sélecteur de période.
//

import SwiftUI

enum StatsPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .today: return String(localized: "period_today")
        case .week:  return String(localized: "period_week")
        case .month: return String(localized: "period_month")
        }
    }
}

struct StatsHeader: View {
    @Binding var selectedPeriod: StatsPeriod
    let showContent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "stats_title"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text(formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -10)

            Spacer()

            PeriodSelector(selected: $selectedPeriod)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)
        }
        .frame(height: 48)
        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15), value: showContent)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: Date()).capitalized
    }
}

// MARK: - Period Selector (dropdown menu)

struct PeriodSelector: View {
    @Binding var selected: StatsPeriod

    var body: some View {
        Menu {
            ForEach(StatsPeriod.allCases) { period in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selected = period
                    }
                } label: {
                    if selected == period {
                        Label(period.localizedLabel, systemImage: "checkmark")
                    } else {
                        Text(period.localizedLabel)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.localizedLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }
}
