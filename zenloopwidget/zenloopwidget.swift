//
//  zenloopwidget.swift
//  zenloopwidget
//
//  Widget iOS pour Zenloop - Temps d'écran et actions rapides
//

import WidgetKit
import SwiftUI
import Intents

// MARK: - Widget Provider

struct ZenloopWidgetProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> ZenloopWidgetEntry {
        ZenloopWidgetEntry(
            date: Date(),
            screenTime: "2h 45min",
            todayUsage: "3h 12min",
            weeklyAverage: "4h 30min",
            topApp: "Instagram",
            currentStreak: 5,
            isSessionActive: false,
            sessionTimeRemaining: nil
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ZenloopWidgetEntry {
        return placeholder(in: context)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ZenloopWidgetEntry> {
        let entry = await loadWidgetData()
        
        // Mettre à jour toutes les 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        return timeline
    }
    
    private func loadWidgetData() async -> ZenloopWidgetEntry {
        // Charger les données depuis App Groups
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        
        // Données d'activité depuis l'extension Device Activity
        var screenTime = "0min"
        var todayUsage = "0min"
        var weeklyAverage = "0min"
        var topApp = "Aucune app"
        
        if let reportData = userDefaults.data(forKey: "device_activity_report") {
            do {
                let payload = try JSONDecoder().decode(SharedReportPayload.self, from: reportData)
                
                // Calculer le temps d'écran d'aujourd'hui
                let today = Calendar.current.startOfDay(for: Date())
                let todaySeconds = payload.days.first { 
                    Calendar.current.isDate(Date(timeIntervalSince1970: $0.dayStart), inSameDayAs: today) 
                }?.seconds ?? 0
                
                screenTime = formatDuration(todaySeconds)
                todayUsage = formatDuration(todaySeconds)
                weeklyAverage = formatDuration(payload.averageDailySeconds)
                
                if let firstCategory = payload.topCategories.first {
                    topApp = firstCategory.name
                }
                
            } catch {
                print("❌ [WIDGET] Erreur décodage données: \(error)")
            }
        }
        
        // Données de session active
        let isSessionActive = userDefaults.bool(forKey: "current_session_active")
        var sessionTimeRemaining: TimeInterval? = nil
        
        if isSessionActive {
            let sessionEndTime = userDefaults.double(forKey: "current_session_end_time")
            if sessionEndTime > 0 {
                sessionTimeRemaining = max(0, sessionEndTime - Date().timeIntervalSince1970)
            }
        }
        
        // Streak actuel
        let currentStreak = userDefaults.integer(forKey: "current_daily_streak")
        
        return ZenloopWidgetEntry(
            date: Date(),
            screenTime: screenTime,
            todayUsage: todayUsage,
            weeklyAverage: weeklyAverage,
            topApp: topApp,
            currentStreak: max(0, currentStreak),
            isSessionActive: isSessionActive,
            sessionTimeRemaining: sessionTimeRemaining
        )
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Widget Entry

struct ZenloopWidgetEntry: TimelineEntry {
    let date: Date
    let screenTime: String
    let todayUsage: String
    let weeklyAverage: String
    let topApp: String
    let currentStreak: Int
    let isSessionActive: Bool
    let sessionTimeRemaining: TimeInterval?
}

// MARK: - Widget Views

struct ZenloopWidgetEntryView: View {
    var entry: ZenloopWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)

struct SmallWidgetView: View {
    let entry: ZenloopWidgetEntry
    
    var body: some View {
        ZStack {
            // Dégradé de fond
            LinearGradient(
                colors: entry.isSessionActive ? 
                    [Color.green.opacity(0.8), Color.cyan.opacity(0.6)] :
                    [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Header avec logo
                HStack {
                    Text("Zenloop")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if entry.isSessionActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Contenu principal
                if entry.isSessionActive, let remaining = entry.sessionTimeRemaining {
                    // Session active
                    VStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(formatSessionTime(remaining))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("restant")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    // Temps d'écran aujourd'hui
                    VStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(entry.todayUsage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("aujourd'hui")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            .padding(12)
        }
        .widgetURL(URL(string: "zenloop://open"))
    }
    
    private func formatSessionTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)min"
        }
    }
}

// MARK: - Medium Widget (4x2)

struct MediumWidgetView: View {
    let entry: ZenloopWidgetEntry
    
    var body: some View {
        ZStack {
            // Dégradé de fond
            LinearGradient(
                colors: entry.isSessionActive ? 
                    [Color.green.opacity(0.8), Color.cyan.opacity(0.6)] :
                    [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 16) {
                // Côté gauche - Données principales
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        Text("Zenloop")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if entry.isSessionActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text("ACTIF")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Métrique principale
                    if entry.isSessionActive, let remaining = entry.sessionTimeRemaining {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SESSION FOCUS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .textCase(.uppercase)
                            
                            Text(formatSessionTime(remaining))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("temps restant")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AUJOURD'HUI")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .textCase(.uppercase)
                            
                            Text(entry.todayUsage)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("temps d'écran")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                
                // Côté droit - Statistiques secondaires
                VStack(alignment: .trailing, spacing: 12) {
                    // Streak
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        Text("jours")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Moyenne hebdomadaire
                    if !entry.isSessionActive {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.weeklyAverage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("moy. semaine")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Action rapide
                    Button(intent: StartFocusSessionIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: entry.isSessionActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 8))
                            Text(entry.isSessionActive ? "PAUSE" : "FOCUS")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .widgetURL(URL(string: "zenloop://open"))
    }
    
    private func formatSessionTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)min"
        }
    }
}

// MARK: - Large Widget (4x4)

struct LargeWidgetView: View {
    let entry: ZenloopWidgetEntry
    
    var body: some View {
        ZStack {
            // Dégradé de fond
            LinearGradient(
                colors: entry.isSessionActive ? 
                    [Color.green.opacity(0.8), Color.cyan.opacity(0.6)] :
                    [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Zenloop")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Digital Wellness")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if entry.isSessionActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("SESSION ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Contenu principal
                if entry.isSessionActive, let remaining = entry.sessionTimeRemaining {
                    // Vue session active
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading) {
                                Text("SESSION FOCUS")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(formatSessionTime(remaining))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                        }
                        
                        // Barre de progression approximative
                        ProgressView(value: 0.6) // Exemple, à calculer selon la session
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .background(.white.opacity(0.3))
                    }
                } else {
                    // Vue données d'utilisation
                    HStack(spacing: 20) {
                        // Temps d'écran aujourd'hui
                        VStack(spacing: 8) {
                            Image(systemName: "iphone")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text(entry.todayUsage)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Aujourd'hui")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .background(.white.opacity(0.3))
                        
                        // Moyenne hebdomadaire
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text(entry.weeklyAverage)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Moyenne")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .background(.white.opacity(0.3))
                        
                        // Streak
                        VStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Jours")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Actions rapides
                HStack(spacing: 12) {
                    Button(intent: StartFocusSessionIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.isSessionActive ? "pause.fill" : "target")
                                .font(.system(size: 12))
                            Text(entry.isSessionActive ? "Pause" : "Focus Session")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: OpenAppIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 12))
                            Text("Ouvrir App")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .widgetURL(URL(string: "zenloop://home"))
    }
    
    private func formatSessionTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)min"
        }
    }
}

// MARK: - App Intents

struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Démarrer Session Focus"
    static var description: IntentDescription = IntentDescription("Lance une session de focus rapide")
    
    func perform() async throws -> some IntentResult {
        // Communiquer avec l'app principale via UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        userDefaults.set(true, forKey: "widget_start_focus_request")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "widget_request_timestamp")
        
        return .result()
    }
}

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir Zenloop"
    static var description: IntentDescription = IntentDescription("Ouvre l'application Zenloop")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Configuration Intent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description: IntentDescription = IntentDescription("Configure le widget Zenloop")
}

// MARK: - Main Widget

struct ZenloopWidget: Widget {
    let kind: String = "zenloopwidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: ZenloopWidgetProvider()
        ) { entry in
            ZenloopWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zenloop")
        .description("Suivez votre temps d'écran et lancez des sessions focus.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}