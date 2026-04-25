//
//  GuiltTripView.swift
//  zenloop
//
//  Affiche la vraie conso Screen Time du jour via DeviceActivityReport
//  (context "GuiltTrip" rendu par l'extension zenloopactivity).
//
//  ⚠️ DeviceActivityReport fait un IPC vers son extension. Au 1er rendu l'extension
//  n'a parfois pas fini son makeConfiguration() → vue vide. Solution: une séquence
//  de remounts programmés (0s / 1s / 2.5s) qui force le ré-échange avec l'extension.
//  Après ça l'extension est chaude → l'utilisateur n'a plus besoin de pull-to-refresh.
//

import SwiftUI
import DeviceActivity

struct GuiltTripView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showContent = false
    @State private var reportKey = UUID()
    @State private var refreshTask: Task<Void, Never>? = nil

    // Filtre journalier : de minuit à maintenant
    #if os(iOS)
    private var dailyFilter: DeviceActivityFilter {
        let today = Calendar.current.startOfDay(for: Date())
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: today, end: Date())),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if os(iOS)
            ZStack {
                if !showContent {
                    GuiltTripSkeleton()
                        .transition(.opacity)
                }

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
            Text(String(localized: "guilt_ios_only"))
                .foregroundColor(.white)
            #endif
        }
        .onAppear { startRefreshSequence() }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .refreshable { await manualRefresh() }
    }

    /// Les remounts se font TOUS derrière le skeleton (showContent=false).
    /// L'utilisateur ne voit que skeleton → rapport final. Zéro flash visible.
    ///
    /// L'extension `zenloopactivity` est généralement déjà chaude grâce au warm-up
    /// invisible de l'onboarding, donc 1 seul remount silencieux suffit en assurance.
    private func startRefreshSequence() {
        refreshTask?.cancel()
        showContent = false
        reportKey = UUID()

        refreshTask = Task { @MainActor in
            // T+0.6s : remount silencieux (skeleton toujours au-dessus)
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            reportKey = UUID()

            // T+1.3s : reveal unique du rapport (qui est maintenant chaud)
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { showContent = true }
        }
    }

    private func manualRefresh() async {
        refreshTask?.cancel()
        await MainActor.run {
            showContent = false
            reportKey = UUID()
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) { showContent = true }
        }
    }
}

// MARK: - Skeleton

struct GuiltTripSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Circle()
                .fill(Color.white.opacity(pulse ? 0.08 : 0.03))
                .frame(width: 56, height: 56)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(pulse ? 0.1 : 0.04))
                .frame(width: 180, height: 60)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(pulse ? 0.06 : 0.02))
                .frame(width: 100, height: 10)

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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GuiltTripView()
    }
}
