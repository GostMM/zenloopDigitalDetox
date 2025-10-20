//
//  TopAppToastReport.swift
//  zenloopactivity
//
//  DeviceActivityReport scene pour afficher le toast de l'app la plus utilisée
//

import SwiftUI
import DeviceActivity
import FamilyControls

extension DeviceActivityReport.Context {
    static let topAppToast = Self("TopAppToast")
}

// MARK: - Report Scene

struct TopAppToastReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .topAppToast
    let content: (TopAppData) -> TopAppToastReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TopAppData {
        var appUsages: [String: ExtensionAppUsage] = [:]
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Collecter toutes les apps d'AUJOURD'HUI uniquement
        for await datum in data {
            for await segment in datum.activitySegments {
                // Filtrer uniquement les segments d'aujourd'hui
                guard segment.dateInterval.start >= todayStart else { continue }

                for await catActivity in segment.categories {
                    for await app in catActivity.applications {
                        let dur = app.totalActivityDuration
                        guard dur > 0 else { continue }

                        let name = app.application.localizedDisplayName
                            ?? app.application.bundleIdentifier
                            ?? "Application"

                        #if os(iOS)
                        if let token = app.application.token {
                            if let existing = appUsages[name] {
                                // Update duration for existing app
                                appUsages[name] = ExtensionAppUsage(
                                    name: name,
                                    duration: existing.duration + dur,
                                    token: token
                                )
                            } else {
                                appUsages[name] = ExtensionAppUsage(
                                    name: name,
                                    duration: dur,
                                    token: token
                                )
                            }
                        }
                        #endif
                    }
                }
            }
        }

        // Trier et prendre les 3 premières
        let topApps = appUsages.values
            .sorted { $0.duration > $1.duration }
            .prefix(3)

        print("📊 [TOP_APPS_REPORT] Found \(appUsages.count) apps today, showing top \(Array(topApps).count)")
        return TopAppData(topApps: Array(topApps))
    }
}

// MARK: - Data Model

struct TopAppData {
    let topApps: [ExtensionAppUsage]
}

// MARK: - Report View

struct TopAppToastReportView: View {
    let data: TopAppData
    @State private var isVisible = true

    var body: some View {
        // TOUJOURS afficher quelque chose pour debug
        VStack {
            if isVisible {
                if !data.topApps.isEmpty {
                    TopAppsCardView(
                        apps: data.topApps,
                        onRestrict: { app, type in
                            sendRestrictionRequest(app: app, type: type)
                        },
                        onDismiss: {
                            dismissCard()
                        }
                    )
                } else {
                    // Placeholder si pas de données
                    HStack(spacing: 16) {
                        // Icon gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan.opacity(0.3), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)

                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Apps les Plus Utilisées")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Text("Aucune donnée aujourd'hui")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Button(action: { dismissCard() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)  // Toute la largeur
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)  // Marge des bords
                }
            }
        }
        .onAppear {
            print("🎯 [TOP_APP_TOAST_REPORT_VIEW] Appeared - topApps count: \(data.topApps.count)")
        }
    }

    private func dismissCard() {
        // Masquer localement
        isVisible = false

        // Envoyer signal à l'app principale pour fermer la card
        guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else { return }
        shared.set(true, forKey: "TopAppsCard_DismissRequested")
        shared.synchronize()

        print("✅ [TOP_APPS_REPORT] Dismiss request sent to main app")

        // Poster notification
        NotificationCenter.default.post(
            name: NSNotification.Name("TopAppsCardDismissRequested"),
            object: nil
        )
    }

    private func sendRestrictionRequest(app: ExtensionAppUsage, type: TopAppsCardView.RestrictionType) {
        // Sauvegarder dans App Group pour que l'app principale puisse lire
        guard let shared = UserDefaults(suiteName: "group.com.app.zenloop") else { return }

        let restrictionData: [String: Any] = [
            "appName": app.name,
            "duration": app.duration,
            "restrictionType": type == .shield ? "shield" : "hide",
            "timestamp": Date().timeIntervalSince1970
        ]

        shared.set(restrictionData, forKey: "PendingRestrictionRequest")
        shared.synchronize()

        print("✅ [TOP_APPS_REPORT] Restriction request saved: \(app.name) - \(type)")

        // Poster notification locale (l'app principale doit écouter)
        NotificationCenter.default.post(
            name: NSNotification.Name("TopAppRestrictionRequested"),
            object: nil,
            userInfo: restrictionData
        )
    }
}
