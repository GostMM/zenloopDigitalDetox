//
//  DebugTimerView.swift
//  zenloop
//
//  Debug view pour TimerCard & SessionPlanningRow
//  Accessible via long press sur le MinimalHeader

#if os(iOS)
import SwiftUI
import FamilyControls

struct DebugTimerView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        sessionStateSection
                        timerCardSection
                        sessionPlanningSection
                        appGroupSection
                        shieldSection
                        actionsSection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("🔧 Debug — Timer & Planning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.cyan)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var sessionStateSection: some View {
        debugSection(title: "🎯 Session State", color: .cyan) {
            VStack(spacing: 6) {
                debugRow("currentState", value: "\(zenloopManager.currentState)")
                debugRow("currentProgress", value: String(format: "%.3f", zenloopManager.currentProgress))
                debugRow("currentTimeRemaining", value: zenloopManager.currentTimeRemaining)
                debugRow("pauseTimeRemaining", value: zenloopManager.pauseTimeRemaining)
                debugRow("selectedAppsCount", value: "\(zenloopManager.selectedAppsCount)")
            }
        }
    }

    private var timerCardSection: some View {
        let selection = zenloopManager.getAppsSelection()
        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        let webCount = selection.webDomainTokens.count
        return debugSection(title: "⏱ TimerCard", color: .orange) {
            VStack(spacing: 6) {
                debugRow("applicationTokens", value: "\(appCount)")
                debugRow("categoryTokens", value: "\(catCount)")
                debugRow("webDomainTokens", value: "\(webCount)")
                timerChallengeRows
            }
        }
    }

    @ViewBuilder
    private var timerChallengeRows: some View {
        if let challenge = zenloopManager.currentChallenge {
            VStack(spacing: 6) {
                Divider().background(Color.white.opacity(0.1))
                debugRow("challenge.id", value: challenge.id)
                debugRow("challenge.title", value: challenge.title)
                debugRow("challenge.duration", value: "\(Int(challenge.duration / 60))min")
                debugRow("challenge.blockedAppsCount", value: "\(challenge.blockedAppsCount)")
                debugRow("challenge.appOpenAttempts", value: "\(challenge.appOpenAttempts)")
                debugRow("taskGoals.count", value: "\(challenge.taskGoals.count)")
            }
        } else {
            debugRow("currentChallenge", value: "nil")
        }
    }

    private var sessionPlanningSection: some View {
        let upcoming = zenloopManager.getUpcomingSessions(limit: 10)
        let hasActive = zenloopManager.hasActiveScheduledSessions
        return debugSection(title: "📅 SessionPlanningRow", color: .purple) {
            VStack(spacing: 6) {
                debugRow("upcomingSessions.count", value: "\(upcoming.count)")
                debugRow("hasActiveScheduledSessions", value: "\(hasActive)")
                UpcomingSessionsDebugList(sessions: upcoming)
            }
        }
    }

    private var appGroupSection: some View {
        debugSection(title: "📦 App Group Keys", color: .green) {
            AppGroupDebugRows()
        }
    }

    private var shieldSection: some View {
        let blocks = BlockManager().getActiveBlocks()
        let hasBlocks = GlobalShieldManager.shared.hasActiveBlocks()
        return debugSection(title: "🛡 GlobalShieldManager", color: .red) {
            VStack(spacing: 6) {
                debugRow("hasActiveBlocks", value: "\(hasBlocks)")
                debugRow("activeBlocks.count", value: "\(blocks.count)")
                ActiveBlocksDebugList(blocks: blocks)
            }
        }
    }

    private var actionsSection: some View {
        debugSection(title: "⚡️ Actions", color: .yellow) {
            VStack(spacing: 8) {
                Button { zenloopManager.startStateMonitoring() } label: {
                    actionButton(label: "startStateMonitoring()", color: .cyan)
                }
                Button { zenloopManager.challengeStateManager.checkAndCompleteExpiredSession() } label: {
                    actionButton(label: "checkAndCompleteExpiredSession()", color: .orange)
                }
                Button { zenloopManager.updateScheduledSessionsStatus() } label: {
                    actionButton(label: "updateScheduledSessionsStatus()", color: .purple)
                }
            }
        }
    }

    // MARK: - Reusable UI

    func debugSection<Content: View>(title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .padding(.bottom, 2)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    func debugRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(minWidth: 140, alignment: .leading)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    func actionButton(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1)))
    }
}

// MARK: - Sub-views

struct UpcomingSessionsDebugList: View {
    let sessions: [ZenloopChallenge]

    var body: some View {
        VStack(spacing: 4) {
            if sessions.isEmpty {
                HStack {
                    Text("sessions")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text("(aucune)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                ForEach(sessions.indices, id: \.self) { idx in
                    UpcomingSessionDebugRow(idx: idx, session: sessions[idx])
                }
            }
        }
    }
}

struct UpcomingSessionDebugRow: View {
    let idx: Int
    let session: ZenloopChallenge

    private var startTimeFormatted: String {
        guard let start = session.startTime else { return "nil" }
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .short
        return f.string(from: start)
    }

    private var relativeStart: String {
        guard let start = session.startTime else { return "–" }
        let interval = start.timeIntervalSince(Date())
        if interval < 0 { return "passé" }
        else if interval < 60 { return "dans \(Int(interval))s" }
        else if interval < 3600 { return "dans \(Int(interval / 60))min" }
        else { return "dans \(String(format: "%.1f", interval / 3600))h" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().background(Color.white.opacity(0.1))
            row("[\(idx)] id", value: session.id)
            row("[\(idx)] title", value: session.title)
            row("[\(idx)] duration", value: "\(Int(session.duration / 60))min")
            row("[\(idx)] startTime", value: startTimeFormatted)
            row("[\(idx)] in", value: relativeStart)
            row("[\(idx)] blockedApps", value: "\(session.blockedAppsCount)")
        }
    }

    private func row(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(minWidth: 140, alignment: .leading)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct AppGroupDebugRows: View {
    private let suite = UserDefaults(suiteName: "group.com.app.zenloop")

    private var namedKeys: [(String, String)] {
        let keys = ["active_blocks_v2", "quick_schedule_apps", "deviceActivityReport"]
        return keys.map { key -> (String, String) in
            if let data = suite?.data(forKey: key) {
                return (key, "\(data.count) bytes")
            } else if let str = suite?.string(forKey: key) {
                return (key, str)
            } else {
                return (key, "–")
            }
        }
    }

    private var dynamicKeys: [String] {
        (suite?.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("pending_") || $0.hasPrefix("blockId_") || $0.hasPrefix("payload_") }
            .sorted()) ?? []
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(namedKeys, id: \.0) { pair in
                row(pair.0, value: pair.1)
            }
            row("pending/blockId/payload", value: "\(dynamicKeys.count) trouvées")
            ForEach(dynamicKeys, id: \.self) { key in
                row("  \(key)", value: "✓")
            }
        }
    }

    private func row(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(minWidth: 140, alignment: .leading)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct ActiveBlocksDebugList: View {
    let blocks: [ActiveBlock]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(blocks, id: \.id) { block in
                ActiveBlockDebugRow(block: block, idx: blocks.firstIndex(where: { $0.id == block.id }) ?? 0)
            }
        }
    }

    private func row(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(minWidth: 140, alignment: .leading)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
struct ActiveBlockDebugRow: View {
    let block: ActiveBlock
    let idx: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().background(Color.white.opacity(0.1))
            row("[\(idx)] id", value: block.id)
            row("[\(idx)] appName", value: block.appName)
            row("[\(idx)] isExpired", value: "\(block.isExpired)")
            row("[\(idx)] remaining", value: block.formattedRemainingTime)
        }
    }

    private func row(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(minWidth: 140, alignment: .leading)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
#endif
