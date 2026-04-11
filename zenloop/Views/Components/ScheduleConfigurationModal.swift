//
//  ScheduleConfigurationModal.swift
//  zenloop
//
//  Redesigned on 07/04/2026: compact unified card layout

import SwiftUI
import FamilyControls
import os
#if canImport(UIKit)
import UIKit
#endif

private let scheduleLogger = Logger(subsystem: "com.app.zenloop", category: "ScheduleModal")

struct ScheduleConfigurationModal: View {
    let session: PopularSession
    @ObservedObject var zenloopManager: ZenloopManager
    let initialAppsSelection: FamilyActivitySelection
    let onAppsSelected: (FamilyActivitySelection) -> Void
    let onAppsClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStartTime = Date()
    @State private var selectedFrequency: ScheduleFrequency = .once
    @State private var selectedDays: Set<Weekday> = []
    @State private var showingAppSelection = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showContent = false

    @State private var showDifficultyModal = false
    @State private var selectedDifficulty: DifficultyLevel? = nil

    @State private var showDurationModal = false
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    @State private var hasCustomDuration = false

    @State private var taskGoals: [(text: String, isCompleted: Bool)] = []
    @State private var showingGoalsModal = false

    @State private var showPastTimeWarning = false

    init(session: PopularSession,
         zenloopManager: ZenloopManager,
         initialAppsSelection: FamilyActivitySelection,
         onAppsSelected: @escaping (FamilyActivitySelection) -> Void,
         onAppsClear: @escaping () -> Void) {
        self.session = session
        self.zenloopManager = zenloopManager
        self.initialAppsSelection = initialAppsSelection
        self.onAppsSelected = onAppsSelected
        self.onAppsClear = onAppsClear
        self._showContent = State(initialValue: true)
    }

    // MARK: - Computed

    private var hasSelectedApps: Bool {
        !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var canSchedule: Bool {
        hasSelectedApps && selectedStartTime.timeIntervalSinceNow > 120
    }

    private var currentDuration: TimeInterval {
        hasCustomDuration ? TimeInterval(selectedHours * 3600 + selectedMinutes * 60) : session.duration
    }

    private var formattedDuration: String {
        let h = Int(currentDuration) / 3600
        let m = (Int(currentDuration) % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h\(m)" : "\(h)h" }
        return "\(m)min"
    }

    private var difficultyLevel: DifficultyLevel {
        selectedDifficulty ?? autoSuggestedDifficulty
    }

    private var autoSuggestedDifficulty: DifficultyLevel {
        let hours = currentDuration / 3600
        if hours >= 8 { return .hard }
        else if hours >= 4 { return .medium }
        return .easy
    }

    private let accentPurple = Color.purple

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.03, green: 0.03, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Header compact
                        headerRow

                        // Card unique : apps + durée + options
                        mainCard

                        // Card : horaire
                        scheduleCard

                        // Bouton
                        scheduleButton

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(String(localized: "schedule_session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "cancel")) { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
            .sheet(isPresented: $showDifficultyModal) {
                DifficultySelectionModal(selectedDifficulty: $selectedDifficulty, autoDifficulty: autoSuggestedDifficulty)
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingGoalsModal) {
                GoalsManagementModal(taskGoals: $taskGoals)
                    .presentationDetents([.height(550)])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showDurationModal) {
                DurationSelectionModal(selectedHours: $selectedHours, selectedMinutes: $selectedMinutes, onConfirm: {
                    hasCustomDuration = true
                    showDurationModal = false
                })
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedDifficulty) { _, newValue in
                if showDifficultyModal && newValue != nil { showDifficultyModal = false }
            }
            .onChange(of: selectedApps) { _, newSelection in onAppsSelected(newSelection) }
            .onAppear {
                selectedStartTime = calculateNextOptimalTime()
                selectedApps = initialAppsSelection
                selectedHours = Int(session.duration / 3600)
                selectedMinutes = Int((session.duration.truncatingRemainder(dividingBy: 3600)) / 60)
                showContent = true
            }
            .alert(String(localized: "invalid_time_title", defaultValue: "Heure invalide"), isPresented: $showPastTimeWarning) {
                Button("OK") {}
            } message: {
                Text(String(localized: "invalid_time_message", defaultValue: "L'heure de début doit être au moins 2 minutes dans le futur."))
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(session.accentColor.color.opacity(0.2))
                    .frame(width: 52, height: 52)

                Image(systemName: session.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(session.accentColor.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(session.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - Main Card (apps + duration + difficulty + goals)

    private var mainCard: some View {
        VStack(spacing: 0) {
            // Row 1 : Apps | Duration
            HStack(alignment: .top, spacing: 0) {
                // Apps (tap to select)
                Button { showingAppSelection = true } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text(hasSelectedApps ? "\(selectedAppsCount) apps" : String(localized: "tap_to_select"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(hasSelectedApps ? .white : .orange)
                        } icon: {
                            Image(systemName: hasSelectedApps ? "shield.checkered" : "square.stack.3d.up.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(hasSelectedApps ? accentPurple : .orange)
                        }

                        if hasSelectedApps {
                            StackedAppIcons(selectedApps: selectedApps, maxToShow: 5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .buttonStyle(PlainButtonStyle())

                // Séparateur vertical
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 10)

                // Duration (tap to change)
                Button { showDurationModal = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(accentPurple.opacity(0.7))

                        Text(formattedDuration)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Séparateur horizontal
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 14)

            // Row 2 : Difficulty | Goals
            HStack(spacing: 0) {
                Button { showDifficultyModal = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: difficultyLevel.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(difficultyLevel.color)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "restriction_label"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(0.5)

                            Text(difficultyLevel.localizedName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                Button { showingGoalsModal = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: taskGoals.isEmpty ? "circle.dashed" : "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.3) : .yellow)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "goals_label"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(0.5)

                            Text(taskGoals.isEmpty
                                 ? String(localized: "optional_label")
                                 : String(localized: "goals_added_count", defaultValue: "\(taskGoals.count) added")
                                    .replacingOccurrences(of: "%d", with: "\(taskGoals.count)"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(taskGoals.isEmpty ? .white.opacity(0.5) : .white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(spacing: 14) {
            // Date + Time
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentPurple)
                    .frame(width: 20)

                DatePicker("", selection: $selectedStartTime, in: Date()..., displayedComponents: [.date])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(accentPurple)

                Spacer()

                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentPurple)

                DatePicker("", selection: $selectedStartTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(accentPurple)
            }

            // Warning si trop proche
            if selectedStartTime.timeIntervalSinceNow < 120 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)

                    Text(String(localized: "time_too_close_warning", defaultValue: "Minimum 2 minutes dans le futur"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)

                    Spacer()
                }
                .transition(.opacity)
            }

            // Séparateur
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            // Fréquence
            HStack {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentPurple)
                    .frame(width: 20)

                Text(String(localized: "frequency"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Picker("", selection: $selectedFrequency) {
                    ForEach(ScheduleFrequency.allCases, id: \.self) { freq in
                        Text(freq.localizedName).tag(freq)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(accentPurple)
            }

            // Jours de la semaine (si weekly)
            if selectedFrequency == .weekly {
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) { selectedDays.remove(day) }
                            else { selectedDays.insert(day) }
                        } label: {
                            Text(day.shortName.prefix(2))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(selectedDays.contains(day) ? .white : .white.opacity(0.4))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(selectedDays.contains(day) ? accentPurple : .white.opacity(0.06))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: selectedFrequency)
    }

    // MARK: - Schedule Button

    private var scheduleButton: some View {
        Button { scheduleSession() } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))

                Text(String(localized: "schedule_session"))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canSchedule
                          ? LinearGradient(colors: [accentPurple, accentPurple.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(!canSchedule)
        .shadow(color: canSchedule ? accentPurple.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
        .premiumGated()
    }

    // MARK: - Actions

    private func scheduleSession() {
        scheduleLogger.critical("🟢 [MODAL] STEP 0 — Schedule button tapped | title: \(session.title, privacy: .public) | duration: \(Int(currentDuration/60), privacy: .public)min | start: \(selectedStartTime, privacy: .public) | apps: \(selectedApps.applicationTokens.count, privacy: .public) | categories: \(selectedApps.categoryTokens.count, privacy: .public) | difficulty: \(difficultyLevel.rawValue, privacy: .public) | frequency: \(selectedFrequency.rawValue, privacy: .public)")

        guard selectedStartTime.timeIntervalSinceNow > 120 else {
            scheduleLogger.error("❌ [MODAL] STEP 0 — GUARD FAILED: startTime too close (\(Int(selectedStartTime.timeIntervalSinceNow), privacy: .public)s). Showing alert.")
            showPastTimeWarning = true
            return
        }

        let difficulty = selectedDifficulty ?? autoSuggestedDifficulty
        scheduleLogger.critical("➡️ [MODAL] STEP 0 — guards passed, calling PremiumGatekeeper.performIfAllowed(.startScheduledSession)")

        PremiumGatekeeper.shared.performIfAllowed(.startScheduledSession) {
            scheduleLogger.critical("➡️ [MODAL] STEP 0 → STEP 1 — PremiumGatekeeper allowed, frequency: \(selectedFrequency.rawValue, privacy: .public)")
            switch selectedFrequency {
            case .once:
                scheduleLogger.critical("📅 [MODAL] STEP 0 — calling zenloopManager.scheduleCustomChallenge (once)")
                zenloopManager.scheduleCustomChallenge(
                    title: session.title, duration: currentDuration,
                    difficulty: difficulty, apps: selectedApps, startTime: selectedStartTime
                )

            case .daily:
                let calendar = Calendar.current
                for dayOffset in 0..<7 {
                    guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedStartTime),
                          futureDate.timeIntervalSinceNow > 120 else { continue }
                    zenloopManager.scheduleCustomChallenge(
                        title: "\(session.title) (J\(dayOffset + 1))", duration: currentDuration,
                        difficulty: difficulty, apps: selectedApps, startTime: futureDate
                    )
                }

            case .weekly:
                guard !selectedDays.isEmpty else {
                    zenloopManager.scheduleCustomChallenge(
                        title: session.title, duration: currentDuration,
                        difficulty: difficulty, apps: selectedApps, startTime: selectedStartTime
                    )
                    break
                }
                let calendar = Calendar.current
                let baseHour = calendar.component(.hour, from: selectedStartTime)
                let baseMinute = calendar.component(.minute, from: selectedStartTime)
                for weekOffset in 0..<4 {
                    for day in selectedDays {
                        guard let targetDate = nextDate(for: day, weekOffset: weekOffset, hour: baseHour, minute: baseMinute),
                              targetDate.timeIntervalSinceNow > 120 else { continue }
                        zenloopManager.scheduleCustomChallenge(
                            title: "\(session.title) (\(day.shortName))", duration: currentDuration,
                            difficulty: difficulty, apps: selectedApps, startTime: targetDate
                        )
                    }
                }
            }

            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
            dismiss()
        }
    }

    private func nextDate(for weekday: Weekday, weekOffset: Int, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let targetWeekday: Int = {
            switch weekday {
            case .sunday: return 1; case .monday: return 2; case .tuesday: return 3
            case .wednesday: return 4; case .thursday: return 5; case .friday: return 6
            case .saturday: return 7
            }
        }()
        var components = DateComponents()
        components.weekday = targetWeekday; components.hour = hour; components.minute = minute; components.second = 0
        guard let next = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else { return nil }
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: next)
    }

    private func calculateNextOptimalTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let targetDate = hour < 23 ? now : (calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let targetHour = hour < 23 ? hour + 1 : 8
        return calendar.date(from: DateComponents(
            year: calendar.component(.year, from: targetDate),
            month: calendar.component(.month, from: targetDate),
            day: calendar.component(.day, from: targetDate),
            hour: targetHour, minute: 0
        )) ?? now
    }
}

// MARK: - Supporting Types

enum ScheduleFrequency: String, CaseIterable {
    case once, daily, weekly
    var localizedName: String {
        switch self {
        case .once: return String(localized: "once")
        case .daily: return String(localized: "daily")
        case .weekly: return String(localized: "weekly")
        }
    }
}

enum Weekday: String, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    var localizedName: String {
        switch self {
        case .monday: return String(localized: "monday"); case .tuesday: return String(localized: "tuesday")
        case .wednesday: return String(localized: "wednesday"); case .thursday: return String(localized: "thursday")
        case .friday: return String(localized: "friday"); case .saturday: return String(localized: "saturday")
        case .sunday: return String(localized: "sunday")
        }
    }
    var shortName: String {
        switch self {
        case .monday: return String(localized: "mon"); case .tuesday: return String(localized: "tue")
        case .wednesday: return String(localized: "wed"); case .thursday: return String(localized: "thu")
        case .friday: return String(localized: "fri"); case .saturday: return String(localized: "sat")
        case .sunday: return String(localized: "sun")
        }
    }
}

struct WeekdayToggle: View {
    let day: Weekday; let isSelected: Bool; let accentColor: Color; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(day.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accentColor : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? accentColor : .white.opacity(0.2), lineWidth: 1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}