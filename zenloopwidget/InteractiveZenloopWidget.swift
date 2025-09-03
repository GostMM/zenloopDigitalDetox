//
//  InteractiveZenloopWidget.swift
//  zenloopwidget
//
//  Created by Claude on 03/09/2025.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Interactive Widget Configuration

struct InteractiveWidgetProvider: TimelineProvider {
    typealias Entry = ZenloopWidgetEntry
    
    func placeholder(in context: Context) -> ZenloopWidgetEntry {
        ZenloopWidgetEntry(
            date: Date(),
            data: ZenloopWidgetData(
                isSessionActive: false,
                currentSessionTitle: "",
                timeRemaining: "25:00",
                progress: 0.0,
                totalFocusTime: "2h 30m",
                streak: 7,
                isPremium: false
            )
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ZenloopWidgetEntry) -> Void) {
        let data = ZenloopWidgetDataProvider.shared.getCurrentData()
        let entry = ZenloopWidgetEntry(date: Date(), data: data)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ZenloopWidgetEntry>) -> Void) {
        let data = ZenloopWidgetDataProvider.shared.getCurrentData()
        let entry = ZenloopWidgetEntry(date: Date(), data: data)
        
        // Update every minute during active session, every 15 minutes otherwise
        let updateInterval: TimeInterval = data.isSessionActive ? 60 : 900
        let nextUpdate = Date().addingTimeInterval(updateInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Interactive Widget Views

struct InteractiveZenloopWidgetView: View {
    let entry: ZenloopWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallInteractiveWidgetView(data: entry.data)
        case .systemMedium:
            MediumInteractiveWidgetView(data: entry.data)
        case .systemLarge:
            LargeInteractiveWidgetView(data: entry.data)
        default:
            SmallInteractiveWidgetView(data: entry.data)
        }
    }
}

// MARK: - Small Widget (Quick Action)

struct SmallInteractiveWidgetView: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: data.isSessionActive ? [.green.opacity(0.8), .blue.opacity(0.8)] : [.purple.opacity(0.8), .blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Status icon
                Image(systemName: data.isSessionActive ? "timer" : "bolt.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                // Main action button
                if data.isSessionActive {
                    Button(intent: EmergencyBreakIntent()) {
                        VStack(spacing: 4) {
                            Text("PAUSE")
                                .font(.system(size: 12, weight: .bold))
                            Text(data.timeRemaining)
                                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: QuickFocusIntent()) {
                        VStack(spacing: 4) {
                            Text("FOCUS")
                                .font(.system(size: 12, weight: .bold))
                            Text("25min")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                // Progress indicator
                if data.isSessionActive {
                    ProgressView(value: data.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .scaleEffect(y: 2)
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Medium Widget (Multiple Actions)

struct MediumInteractiveWidgetView: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if data.isSessionActive {
                activeSessionMediumView
            } else {
                inactiveMediumView
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
    
    private var activeSessionMediumView: some View {
        VStack(spacing: 12) {
            // Session info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SESSION ACTIVE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(data.currentSessionTitle.isEmpty ? "Focus Session" : data.currentSessionTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Text(data.timeRemaining)
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
                
                Spacer()
                
                // Session progress circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: data.progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: data.progress)
                    
                    Text("\(Int(data.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(width: 50, height: 50)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(intent: EmergencyBreakIntent()) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(intent: StopSessionIntent()) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding()
    }
    
    private var inactiveMediumView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZENLOOP")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("🔥 \(data.streak)")
                        Text("• \(data.totalFocusTime)")
                    }
                    .font(.caption)
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Premium badge
                if data.isPremium {
                    Text("PREMIUM")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
            }
            
            // Quick action buttons
            HStack(spacing: 8) {
                Button(intent: QuickFocus5Intent()) {
                    VStack {
                        Image(systemName: "bolt")
                        Text("5min")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(intent: QuickFocusIntent()) {
                    VStack {
                        Image(systemName: "target")
                        Text("25min")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button(intent: QuickFocus50Intent()) {
                    VStack {
                        Image(systemName: "brain")
                        Text("50min")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Large Widget (Full Control Panel)

struct LargeInteractiveWidgetView: View {
    let data: ZenloopWidgetData
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                // Header with stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("ZENLOOP CONTROL CENTER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("\(data.streak)", systemImage: "flame.fill")
                                .foregroundColor(.orange)
                            
                            Label(data.totalFocusTime, systemImage: "clock.fill")
                                .foregroundColor(.blue)
                            
                            if data.isPremium {
                                Label("PREMIUM", systemImage: "crown.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                
                // Current session or quick actions
                if data.isSessionActive {
                    // Active session view
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("SESSION EN COURS")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                Text(data.currentSessionTitle.isEmpty ? "Focus Session" : data.currentSessionTitle)
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text(data.timeRemaining)
                                    .font(.largeTitle)
                                    .fontWeight(.heavy)
                                    .monospacedDigit()
                                    .foregroundColor(.green)
                                
                                ProgressView(value: data.progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                    .scaleEffect(y: 3)
                            }
                        }
                        
                        // Control buttons
                        HStack(spacing: 12) {
                            Button(intent: EmergencyBreakIntent()) {
                                Label("Pause", systemImage: "pause.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: StopSessionIntent()) {
                                Label("Arrêter", systemImage: "stop.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Quick actions grid
                    VStack(spacing: 12) {
                        Text("DÉMARRAGE RAPIDE")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // First row
                        HStack(spacing: 12) {
                            Button(intent: QuickFocus5Intent()) {
                                VStack {
                                    Image(systemName: "bolt.circle.fill")
                                        .font(.title2)
                                    Text("Flash")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text("5 min")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: QuickFocusIntent()) {
                                VStack {
                                    Image(systemName: "target")
                                        .font(.title2)
                                    Text("Standard")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text("25 min")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: QuickFocus50Intent()) {
                                VStack {
                                    Image(systemName: "brain")
                                        .font(.title2)
                                    Text("Deep")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text("50 min")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Second row
                        HStack(spacing: 12) {
                            Button(intent: StartScheduledSessionIntent()) {
                                HStack {
                                    Image(systemName: "clock")
                                    Text("Session Programmée")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: ViewStatsIntent()) {
                                HStack {
                                    Image(systemName: "chart.bar")
                                    Text("Voir Stats")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Widget Configuration

struct InteractiveZenloopWidget: Widget {
    let kind: String = "InteractiveZenloopWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InteractiveWidgetProvider()) { entry in
            InteractiveZenloopWidgetView(entry: entry)
        }
        .configurationDisplayName("Zenloop Interactive")
        .description("Widget interactif avec contrôles de session en arrière-plan")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled() // iOS 17+
    }
}