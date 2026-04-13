//
//  GuiltTripView.swift
//  zenloop
//
//  Tab "Culpabilisation" — utilise DeviceActivityReport (context "GuiltTrip")
//  pour accéder aux vraies données Screen Time via l'extension zenloopactivity.
//
//  Background noir pur pour matcher la phase blackout de GuiltTripExtensionView.
//

import SwiftUI
import DeviceActivity

struct GuiltTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var reportKey = UUID()

    // Filtre journalier : de minuit à maintenant
    #if os(iOS)
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
    #endif

    var body: some View {
        ZStack {
            // Fond noir pur — identique à la phase blackout de l'extension
            Color.black
                .ignoresSafeArea()

            #if os(iOS)
            ZStack {
                // Skeleton pendant le chargement
                if !showContent {
                    GuiltTripSkeleton()
                        .transition(.opacity)
                }

                // Le vrai DeviceActivityReport avec context "GuiltTrip"
                DeviceActivityReport(
                    DeviceActivityReport.Context("GuiltTrip"),
                    filter: dailyFilter
                )
                .id(reportKey)
                .ignoresSafeArea(edges: .bottom)
                .opacity(showContent ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showContent)
            }
            #else
            Text("Disponible sur iOS uniquement")
                .foregroundColor(.white)
            #endif
        }
        .task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation { showContent = true }
        }
        .refreshable {
            reportKey = UUID()
            showContent = false
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation { showContent = true }
        }
    }
}

// MARK: - Skeleton (fond noir, sans cards, style minimal)

struct GuiltTripSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icône placeholder
            Circle()
                .fill(Color.white.opacity(pulse ? 0.08 : 0.03))
                .frame(width: 56, height: 56)

            // Compteur placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(pulse ? 0.1 : 0.04))
                .frame(width: 180, height: 60)

            // Label placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(pulse ? 0.06 : 0.02))
                .frame(width: 100, height: 10)

            // Sous-titre placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(pulse ? 0.05 : 0.02))
                .frame(width: 160, height: 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GuiltTripView()
            .environmentObject(ZenloopManager.shared)
    }
}