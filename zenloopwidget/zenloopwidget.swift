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
        print("📊 [WIDGET] Snapshot data: state=\(data.currentState.rawValue), title=\(data.sessionTitle ?? "nil")")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZenloopWidgetEntry>) -> ()) {
        print("🔄 [WIDGET] getTimeline called")
        let currentData = ZenloopWidgetDataProvider.shared.getCurrentData()
        let currentDate = Date()
        
        print("📊 [WIDGET] Timeline data: state=\(currentData.currentState.rawValue)")
        
        var entries: [ZenloopWidgetEntry] = []
        
        // Entry actuelle
        entries.append(ZenloopWidgetEntry(date: currentDate, data: currentData))
        
        // Mise à jour selon l'état de la session
        let refreshInterval: TimeInterval
        switch currentData.currentState {
        case .active:
            refreshInterval = 60 // 1 minute pour les sessions actives
        case .paused:
            refreshInterval = 300 // 5 minutes pour les sessions en pause
        case .completed:
            refreshInterval = 300 // 5 minutes après completion
        case .idle:
            refreshInterval = 1800 // 30 minutes en idle
        }
        
        // Créer plusieurs entries pour un refresh régulier
        let numberOfEntries = currentData.currentState == .active ? 10 : 5
        for i in 1...numberOfEntries {
            let entryDate = currentDate.addingTimeInterval(TimeInterval(i) * refreshInterval)
            
            // Pour les sessions actives, simuler la progression du timer
            var updatedData = currentData
            if currentData.currentState == .active {
                let newTimeRemaining = max(0, (currentData.timeRemaining?.timeIntervalFromString() ?? 0) - TimeInterval(i * 60))
                // Créer une session active mise à jour
                let updatedActiveSession = ActiveSessionData(
                    id: currentData.activeSession?.id ?? UUID().uuidString,
                    title: currentData.activeSession?.title ?? "Focus Session",
                    timeRemaining: newTimeRemaining > 0 ? newTimeRemaining.formattedTime() : "00:00",
                    progress: currentData.progress + (0.1 * Double(i)),
                    origin: currentData.activeSession?.origin ?? .quickStart,
                    startTime: currentData.activeSession?.startTime ?? Date(),
                    originalDuration: currentData.activeSession?.originalDuration ?? 1500
                )
                
                updatedData = ZenloopWidgetData(
                    currentState: newTimeRemaining > 0 ? .active : .completed,
                    activeSession: newTimeRemaining > 0 ? updatedActiveSession : nil,
                    sessionsCompleted: currentData.sessionsCompleted,
                    streak: currentData.streak,
                    nextScheduledSession: currentData.nextScheduledSession,
                    cancelledScheduledSessions: currentData.cancelledScheduledSessions,
                    lastUpdated: entryDate
                )
            }
            
            entries.append(ZenloopWidgetEntry(date: entryDate, data: updatedData))
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
        .configurationDisplayName("Zenloop Focus")
        .description("Track your focus sessions and digital wellness progress")
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
            ZenloopWidgetBackground(state: entry.data.currentState)
        )
    }
}

// MARK: - Small Widget (systemSmall)

struct SmallZenloopWidget: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        VStack(spacing: 8) {
            // Header compact
            HStack {
                Text("Zenloop")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(data.currentState.emoji)
                    .font(.system(size: 16))
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
            Text(data.sessionTitle ?? "Focus Session")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(data.timeRemaining ?? "00:00")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            // Progress bar
            ProgressView(value: data.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2)
            
            // Action button
            Button(intent: PauseSessionIntent()) {
                Text("Pause")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 4) {
            Text("Ready")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            if let nextSession = data.nextScheduledSession {
                Text("Next: \(nextSession.formattedStartTime)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.cyan)
            }
            
            // Quick start suggestions
            HStack(spacing: 4) {
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 25
                    return intent
                }()) {
                    Text("25m")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                
                Button(intent: {
                    var intent = StartQuickSessionIntent()
                    intent.duration = 60
                    return intent
                }()) {
                    Text("1h")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var pausedContent: some View {
        VStack(spacing: 4) {
            Text("Paused")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            
            Text(data.timeRemaining ?? "00:00")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
            
            // Resume/Stop buttons
            HStack(spacing: 4) {
                Button(intent: ResumeSessionIntent()) {
                    Text("Resume")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                
                Button(intent: StopSessionIntent()) {
                    Text("Stop")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var completedContent: some View {
        VStack(spacing: 4) {
            Text("Well Done!")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            
            Text(data.sessionTitle ?? "Session")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.green)
                .lineLimit(1)
            
            // Start new session button
            Button(intent: StartNewSessionIntent()) {
                Text("New Session")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Medium Widget (systemMedium)

struct MediumZenloopWidget: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        HStack(spacing: 12) {
            // Section gauche - Info principale
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Text("Zenloop")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(data.currentState.emoji)
                        .font(.system(size: 16))
                    
                    Spacer()
                }
                
                // État principal
                Text(data.currentState.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Contenu spécifique à l'état
                Group {
                    switch data.currentState {
                    case .active:
                        activeSessionDetails
                    case .idle:
                        idleDetails
                    case .paused:
                        pausedDetails
                    case .completed:
                        completedDetails
                    }
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Section droite - Stats et prochaine session
            VStack(alignment: .trailing, spacing: 8) {
                // Stats compactes
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(data.streak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("\(data.sessionsCompleted)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Prochaine session (si applicable)
                if let nextSession = data.nextScheduledSession, data.currentState == .idle {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(nextSession.formattedStartTime)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.cyan)
                        
                        Text(nextSession.title)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
    }
    
    @ViewBuilder
    private var activeSessionDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.sessionTitle ?? "Focus Session")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            Text(data.timeRemaining ?? "00:00")
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
            Text("Ready to focus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Tap to start session")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var pausedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Session paused")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(data.timeRemaining ?? "00:00")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.cyan)
        }
    }
    
    @ViewBuilder
    private var completedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Session completed!")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
            
            Text(data.sessionTitle ?? "Great job!")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Background

struct ZenloopWidgetBackground: View {
    let state: ZenloopWidgetData.WidgetState
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