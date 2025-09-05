//
//  zenloopwidget.swift
//  zenloopwidget
//
//  Created by MROIVILI MOUSTOIFA on 28/08/2025.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ZenloopTimelineProvider: TimelineProvider {
    typealias Entry = ZenloopWidgetEntry
    
    func placeholder(in context: Context) -> ZenloopWidgetEntry {
        ZenloopWidgetEntry(
            date: Date(),
            data: ZenloopWidgetData(
                currentState: .idle,
                activeSession: nil,
                sessionsCompleted: 5,
                streak: 3,
                nextScheduledSession: ScheduledSessionData(
                    id: "placeholder-session",
                    title: "No TikTok 8h",
                    startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    duration: 8 * 60 * 60
                ),
                cancelledScheduledSessions: [],
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ZenloopWidgetEntry) -> ()) {
        print("🔄 [WIDGET] getSnapshot called")
        let data = ZenloopWidgetDataProvider.shared.getCurrentData()
        let entry = ZenloopWidgetEntry(date: Date(), data: data)
        print("📊 [WIDGET] Snapshot data: state=\(data.currentState?.rawValue ?? "nil"), title=\(data.currentSessionTitle)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZenloopWidgetEntry>) -> ()) {
        print("🔄 [WIDGET] getTimeline called")
        let currentData = ZenloopWidgetDataProvider.shared.getCurrentData()
        let currentDate = Date()
        
        print("📊 [WIDGET] Timeline data: state=\(currentData.currentState?.rawValue ?? "nil")")
        
        var entries: [ZenloopWidgetEntry] = []
        
        // Entry actuelle
        entries.append(ZenloopWidgetEntry(date: currentDate, data: currentData))
        
        // Mise à jour chaque seconde pour toutes les vues
        let refreshInterval: TimeInterval = 1 // 1 seconde pour toutes les vues
        
        // Créer plusieurs entries pour refresh continu chaque seconde
        let numberOfEntries = 60 // 60 entries = 1 minute de données
        for i in 1...numberOfEntries {
            let entryDate = currentDate.addingTimeInterval(TimeInterval(i) * refreshInterval)
            // Utiliser les données exactement comme reçues de l'app, sans simulation
            entries.append(ZenloopWidgetEntry(date: entryDate, data: currentData))
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Widget Entry

struct ZenloopWidgetEntry: TimelineEntry {
    let date: Date
    let data: ZenloopWidgetData
}

// MARK: - Main Widget

struct zenloopwidget: Widget {
    let kind: String = "zenloopwidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZenloopTimelineProvider()) { entry in
            ZenloopWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.title", bundle: .main))
        .description(String(localized: "widget.description", bundle: .main))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Views

struct ZenloopWidgetView: View {
    var entry: ZenloopTimelineProvider.Entry
    
    var body: some View {
        // Contenu selon la taille
        GeometryReader { geometry in
            if geometry.size.width < 200 { // Small widget
                SmallZenloopWidget(data: entry.data)
            } else { // Medium widget
                MediumZenloopWidget(data: entry.data)
            }
        }
        .widgetBackground(
            ZenloopWidgetBackground(state: entry.data.currentState ?? .idle)
        )
    }
}

// MARK: - Small Widget (systemSmall)

struct SmallZenloopWidget: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // Header compact with logo
            HStack {
                HStack(spacing: 4) {
                    Image("zenloop")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                    Text(String(localized: "zenloop", bundle: .main))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(data.currentState?.emoji ?? "🎯")
                    .font(.system(size: 14))
            }
            
            Spacer()
            
            // Contenu principal selon l'état
            Group {
                switch data.currentState {
                case .active:
                    activeSessionContent
                case .idle:
                    idleContent
                case .paused:
                    pausedContent
                case .completed:
                    completedContent
                case nil:
                    idleContent
                }
            }
            
            Spacer()
            
            // Footer compact avec streak
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                
                Text("\(data.streak)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(data.sessionsCompleted)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
    }
    
    @ViewBuilder
    private var activeSessionContent: some View {
        VStack(spacing: 4) {
            // Time remaining (primary focus)
            Text(data.timeRemaining)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            // Session title (compact)
            Text(data.currentSessionTitle.isEmpty ? String(localized: "focus_session_placeholder", bundle: .main) : data.currentSessionTitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
            
            // Progress bar
            ProgressView(value: data.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2)
                .padding(.vertical, 2)
            
            // Action button (compact)
            Button(intent: PauseSessionIntent()) {
                HStack(spacing: 2) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                    Text(String(localized: "pause", bundle: .main))
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 6) {
            // Status message
            Text(String(localized: "ready_to_focus", bundle: .main))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            // Next session info (if available)
            if let nextSession = data.nextScheduledSession {
                Text("\(String(localized: "next", bundle: .main)) \(nextSession.formattedStartTime)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.cyan)
            }
            
            // Quick start buttons (prominent and stacked)
            VStack(spacing: 4) {
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 25
                    return intent
                }()) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text(String(localized: "start_25min", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 60
                    return intent
                }()) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(String(localized: "start_1_hour", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var pausedContent: some View {
        VStack(spacing: 4) {
            // Paused status
            Text(String(localized: "session_paused", bundle: .main))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            // Time remaining
            Text(data.timeRemaining)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            // Action buttons (prominent and stacked)
            VStack(spacing: 3) {
                Button(intent: ResumeSessionIntent()) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text(String(localized: "resume", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                Button(intent: StopSessionIntent()) {
                    HStack {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                        Text(String(localized: "stop", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var completedContent: some View {
        VStack(spacing: 4) {
            // Celebration
            Text("🎉")
                .font(.system(size: 24))
            
            Text(String(localized: "well_done", bundle: .main))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Text(data.currentSessionTitle.isEmpty ? String(localized: "session_completed_placeholder", bundle: .main) : "\(data.currentSessionTitle) completed!")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.green)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // New session button (prominent)
            Button(intent: StartNewSessionIntent()) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                    Text(String(localized: "start_new_session", bundle: .main))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.8))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Medium Widget (systemMedium)

struct MediumZenloopWidget: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        VStack(spacing: 0) {
            // Header compact mais complet
            HStack {
                HStack(spacing: 4) {
                    Image("zenloop")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                    Text(String(localized: "zenloop", bundle: .main))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Stats compactes dans le header
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("\(data.streak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    
                    HStack(spacing: 3) {
                        Text("\(data.sessionsCompleted ?? 0)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
                
                Text(data.currentState?.emoji ?? "🎯")
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Contenu principal optimisé
            Group {
                switch data.currentState {
                case .active:
                    mediumActiveContent
                case .idle:
                    mediumIdleContent
                case .paused:
                    mediumPausedContent
                case .completed:
                    mediumCompletedContent
                case nil:
                    mediumIdleContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Medium Widget Content Views
    
    @ViewBuilder
    private var mediumActiveContent: some View {
        HStack(spacing: 16) {
            // Section gauche - Timer et progress
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "focus_session", bundle: .main))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if !data.currentSessionTitle.isEmpty {
                        Text(data.currentSessionTitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Text(data.timeRemaining)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Progress bar épaisse
                ProgressView(value: data.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    .scaleEffect(y: 4)
                    .padding(.vertical, 4)
            }
            
            Spacer()
            
            // Section droite - Action + info
            VStack(spacing: 6) {
                // Progress percentage
                Text("\(Int((data.progress) * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                
                // Action button (compact)
                Button(intent: PauseSessionIntent()) {
                    HStack(spacing: 3) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12))
                        Text(String(localized: "pause", bundle: .main))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var mediumIdleContent: some View {
        VStack(spacing: 10) {
            // Section du haut - Message et prochaine session
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "ready_to_focus", bundle: .main))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(String(localized: "choose_session_duration", bundle: .main))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Next session info if available
                if let nextSession = data.nextScheduledSession {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(localized: "scheduled", bundle: .main))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(nextSession.formattedStartTime)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                        Text(nextSession.title)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            
            // Section du bas - Boutons d'action (compacts)
            HStack(spacing: 8) {
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 25
                    return intent
                }()) {
                    VStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                        Text(String(localized: "25min", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 60
                    return intent
                }()) {
                    VStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text(String(localized: "1_hour", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 120
                    return intent
                }()) {
                    VStack(spacing: 2) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 14))
                        Text(String(localized: "start_2_hours", bundle: .main))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var mediumPausedContent: some View {
        HStack(spacing: 16) {
            // Section gauche - Timer
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "session_paused", bundle: .main))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(String(localized: "take_break_resume", bundle: .main))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(data.timeRemaining)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            // Section droite - Actions (compactes)
            HStack(spacing: 6) {
                Button(intent: ResumeSessionIntent()) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text(String(localized: "resume", bundle: .main))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(intent: StopSessionIntent()) {
                    HStack(spacing: 3) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11))
                        Text(String(localized: "stop", bundle: .main))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var mediumCompletedContent: some View {
        HStack(spacing: 16) {
            // Section gauche - Célébration
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "well_done", bundle: .main))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(localized: "session_completed_successfully", bundle: .main))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                if !data.currentSessionTitle.isEmpty {
                    Text("✓ \(data.currentSessionTitle)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Section droite - Action (compacte)
            VStack(spacing: 8) {
                Button(intent: StartNewSessionIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text(String(localized: "new_session", bundle: .main))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var activeSessionDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.currentSessionTitle.isEmpty ? String(localized: "focus_session_placeholder", bundle: .main) : data.currentSessionTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            Text(data.timeRemaining)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Progress bar plus large
            ProgressView(value: data.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 3)
        }
    }
    
    @ViewBuilder
    private var idleDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "ready_to_focus_tap", bundle: .main))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(String(localized: "tap_to_start_session", bundle: .main))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var pausedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "session_paused", bundle: .main))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(data.timeRemaining)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.cyan)
        }
    }
    
    @ViewBuilder
    private var completedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "session_completed", bundle: .main))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
            
            Text(data.currentSessionTitle.isEmpty ? String(localized: "great_job", bundle: .main) : data.currentSessionTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Background

struct ZenloopWidgetBackground: View {
    let state: WidgetState
    @State private var animateGlow = false
    
    var body: some View {
        ZStack {
            // Background principal (basé sur OptimizedBackground)
            LinearGradient(
                colors: [
                    Color(red: state.primaryColor.red, green: state.primaryColor.green, blue: state.primaryColor.blue),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Overlay secondaire animé
            LinearGradient(
                colors: [
                    Color(red: state.secondaryColor.red, green: state.secondaryColor.green, blue: state.secondaryColor.blue)
                        .opacity(state.secondaryColor.opacity),
                    Color.clear
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .opacity(animateGlow ? 0.4 : 0.2)
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGlow)
            .blendMode(.overlay)
        }
        .onAppear {
            animateGlow = true
        }
    }
}

#Preview("Small Widget", as: .systemSmall) {
    zenloopwidget()
} timeline: {
    ZenloopWidgetEntry(
        date: .now,
        data: ZenloopWidgetData(
            currentState: .active,
            activeSession: ActiveSessionData(
                id: "preview-active",
                title: "Deep Focus Session",
                timeRemaining: "02:35",
                progress: 0.7,
                origin: .manual,
                startTime: Date(),
                originalDuration: 1500
            ),
            sessionsCompleted: 5,
            streak: 3,
            nextScheduledSession: nil,
            cancelledScheduledSessions: [],
            lastUpdated: .now
        )
    )
}

#Preview("Medium Widget", as: .systemMedium) {
    zenloopwidget()
} timeline: {
    ZenloopWidgetEntry(
        date: .now,
        data: ZenloopWidgetData(
            currentState: .idle,
            activeSession: nil,
            sessionsCompleted: 8,
            streak: 5,
            nextScheduledSession: ScheduledSessionData(
                id: "preview-scheduled",
                title: "No TikTok 8h",
                startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                duration: 8 * 60 * 60
            ),
            cancelledScheduledSessions: [],
            lastUpdated: .now
        )
    )
}

// MARK: - iOS 17 Compatibility Extension

extension View {
    @ViewBuilder
    func widgetBackground<V: View>(_ backgroundView: V) -> some View {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
            self.containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            self.background(backgroundView)
        }
    }
}