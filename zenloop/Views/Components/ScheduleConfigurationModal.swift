//
//  ScheduleConfigurationModal.swift
//  zenloop
//
//  Refactorisé avec CompactTimerView pour cohérence
//  Fixed on 06/04/2026: frequency now used, past time validation, duration sync

import SwiftUI
import FamilyControls
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var isAppearing = false
    @State private var hasInitialized = false

    // Difficulty selection
    @State private var showDifficultyModal = false
    @State private var selectedDifficulty: DifficultyLevel? = nil

    // Duration selection
    @State private var showDurationModal = false
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    @State private var hasCustomDuration = false

    // Task goals
    @State private var taskGoals: [(text: String, isCompleted: Bool)] = []
    @State private var showingGoalsModal = false

    // FIX Bug 8: Validation feedback
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
        self._hasInitialized = State(initialValue: true)
    }

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.12),
                    Color(red: 0.06, green: 0.03, blue: 0.15),
                    Color(red: 0.08, green: 0.02, blue: 0.18),
                    Color(red: 0.04, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            session.accentColor.color.opacity(0.1),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
        }
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationView {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack {
            backgroundGradient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    sessionHeaderSection
                    compactTimerSection
                    scheduleConfigurationSection
                    actionButtonsSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle(String(localized: "schedule_session"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "cancel")) {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .sheet(isPresented: $showDifficultyModal) {
            DifficultySelectionModal(
                selectedDifficulty: $selectedDifficulty,
                autoDifficulty: autoSuggestedDifficulty
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingGoalsModal) {
            GoalsManagementModal(taskGoals: $taskGoals)
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showDurationModal) {
            DurationSelectionModal(
                selectedHours: $selectedHours,
                selectedMinutes: $selectedMinutes,
                onConfirm: {
                    hasCustomDuration = true
                    showDurationModal = false
                }
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedDifficulty) { oldValue, newValue in
            if showDifficultyModal && newValue != nil {
                showDifficultyModal = false
            }
        }
        .onChange(of: selectedApps) { oldSelection, newSelection in
            onAppsSelected(newSelection)
        }
        .onChange(of: session.sessionId) { oldSessionId, newSessionId in
            hasInitialized = false
            showContent = false

            DispatchQueue.main.async {
                selectedStartTime = calculateNextOptimalTime()
                selectedApps = initialAppsSelection
                showContent = true
                hasInitialized = true
            }
        }
        .onAppear {
            isAppearing = true
            selectedStartTime = calculateNextOptimalTime()
            selectedApps = initialAppsSelection

            selectedHours = Int(session.duration / 3600)
            selectedMinutes = Int((session.duration.truncatingRemainder(dividingBy: 3600)) / 60)

            showContent = true
            hasInitialized = true
        }
        .onDisappear {
            isAppearing = false
        }
        // FIX Bug 8: Alert for past time
        .alert(String(localized: "invalid_time_title", defaultValue: "Heure invalide"), isPresented: $showPastTimeWarning) {
            Button("OK") {}
        } message: {
            Text(String(localized: "invalid_time_message", defaultValue: "L'heure de début doit être au moins 2 minutes dans le futur. Veuillez choisir une heure ultérieure."))
        }
    }

    // MARK: - Session Header Section

    private var sessionHeaderSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                session.accentColor.color.opacity(0.3),
                                session.accentColor.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: session.iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(session.accentColor.color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(session.accentColor.color.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: session.accentColor.color.opacity(0.3), radius: 12, x: 0, y: 6)

            VStack(spacing: 8) {
                Text(session.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(session.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }

    // MARK: - Compact Timer Section

    private var compactTimerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                Button {
                    showingAppSelection = true
                } label: {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: hasSelectedApps ? "shield.checkered" : "square.stack.3d.up.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(hasSelectedApps ? .purple : .orange)
                                .symbolEffect(.bounce, value: hasSelectedApps)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "apps_to_block_label"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(0.5)

                                Text(hasSelectedApps ? String(localized: "apps_selected_count", defaultValue: "\(selectedAppsCount) selected").replacingOccurrences(of: "%d", with: "\(selectedAppsCount)") : String(localized: "tap_to_select"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(hasSelectedApps ? .white : .orange)
                            }

                            Spacer()
                        }

                        if hasSelectedApps {
                            HStack(spacing: 0) {
                                StackedAppIcons(selectedApps: selectedApps, maxToShow: 5)
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    showDurationModal = true
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.cyan.opacity(0.6))

                            Text(formattedDuration)
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            HStack(spacing: 12) {
                Button {
                    showDifficultyModal = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: difficultyIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(difficultyColor)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "restriction_label"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.5)

                            Text(difficultyTitle)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    showingGoalsModal = true
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(localized: "goals_label"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.5)

                            Text(taskGoals.count > 0 ? String(localized: "goals_added_count", defaultValue: "\(taskGoals.count) added").replacingOccurrences(of: "%d", with: "\(taskGoals.count)") : String(localized: "optional_label"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(taskGoals.count > 0 ? .white : .white.opacity(0.5))
                        }

                        Image(systemName: taskGoals.count > 0 ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(taskGoals.count > 0 ? .yellow : .white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.accentColor.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }

    // MARK: - Schedule Configuration Section

    private var scheduleConfigurationSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(String(localized: "schedule_configuration"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 16) {
                startTimeSelectionRow
                frequencySelectionRow

                if selectedFrequency == .weekly {
                    weekdaySelectionRow
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(session.accentColor.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
    }

    private var startTimeSelectionRow: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)

                Text(String(localized: "start_date"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                // FIX Bug 8: Minimum date = maintenant
                DatePicker("", selection: $selectedStartTime, in: Date()..., displayedComponents: [.date])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(session.accentColor.color)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)

                Text(String(localized: "start_time"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                DatePicker("", selection: $selectedStartTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(session.accentColor.color)
            }

            // FIX Bug 8: Indicateur visuel si l'heure est dans le passé
            if selectedStartTime.timeIntervalSinceNow < 120 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text(String(localized: "time_too_close_warning", defaultValue: "L'heure doit être au moins 2 minutes dans le futur"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)

                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    private var frequencySelectionRow: some View {
        HStack {
            Image(systemName: "repeat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(session.accentColor.color)
                .frame(width: 24)

            Text(String(localized: "frequency"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.localizedName)
                        .tag(frequency)
                }
            }
            .pickerStyle(.menu)
            .accentColor(session.accentColor.color)
        }
    }

    private var weekdaySelectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.accentColor.color)
                    .frame(width: 24)

                Text(String(localized: "repeat_on_days"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    WeekdayToggle(
                        day: day,
                        isSelected: selectedDays.contains(day),
                        accentColor: session.accentColor.color
                    ) {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.3), value: selectedFrequency)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                scheduleSession()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(String(localized: "schedule_session"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canSchedule ?
                            [session.accentColor.color, session.accentColor.color.opacity(0.8)] :
                            [Color.gray.opacity(0.5), Color.gray.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(!canSchedule)
            .shadow(color: session.accentColor.color.opacity(0.3), radius: canSchedule ? 8 : 0, x: 0, y: 4)
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: showContent)
        .premiumGated()
    }

    // MARK: - Computed Properties

    private var hasSelectedApps: Bool {
        !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    // FIX Bug 8: canSchedule vérifie aussi l'heure
    private var canSchedule: Bool {
        hasSelectedApps && selectedStartTime.timeIntervalSinceNow > 120
    }

    private var autoSuggestedDifficulty: DifficultyLevel {
        let hours = currentDuration / 3600
        if hours >= 8 {
            return .hard
        } else if hours >= 4 {
            return .medium
        } else {
            return .easy
        }
    }

    private var difficultyTitle: String {
        selectedDifficulty?.rawValue ?? "Auto"
    }

    private var difficultyIcon: String {
        selectedDifficulty?.icon ?? "sparkles"
    }

    private var difficultyColor: Color {
        selectedDifficulty?.color ?? .cyan
    }

    private var formattedDuration: String {
        let hours: Int
        let minutes: Int

        if hasCustomDuration {
            hours = selectedHours
            minutes = selectedMinutes
        } else {
            let duration = session.duration
            hours = Int(duration / 3600)
            minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        }

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)min"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)min"
        }
    }

    private var currentDuration: TimeInterval {
        if hasCustomDuration {
            return TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
        } else {
            return session.duration
        }
    }

    // MARK: - Private Methods

    private func scheduleSession() {
        // FIX Bug 8: Validation finale avant programmation
        guard selectedStartTime.timeIntervalSinceNow > 120 else {
            showPastTimeWarning = true
            return
        }

        let difficulty = selectedDifficulty ?? autoSuggestedDifficulty

        PremiumGatekeeper.shared.performIfAllowed(.startScheduledSession) {
            // FIX Bug 7: Gérer la fréquence sélectionnée
            switch selectedFrequency {
            case .once:
                // Programmation unique
                zenloopManager.scheduleCustomChallenge(
                    title: session.title,
                    duration: currentDuration,
                    difficulty: difficulty,
                    apps: selectedApps,
                    startTime: selectedStartTime
                )

            case .daily:
                // FIX Bug 7: Programmer pour les 7 prochains jours
                let calendar = Calendar.current
                for dayOffset in 0..<7 {
                    guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedStartTime) else { continue }
                    // Ne pas programmer si dans le passé
                    guard futureDate.timeIntervalSinceNow > 120 else { continue }

                    zenloopManager.scheduleCustomChallenge(
                        title: "\(session.title) (J\(dayOffset + 1))",
                        duration: currentDuration,
                        difficulty: difficulty,
                        apps: selectedApps,
                        startTime: futureDate
                    )
                }

            case .weekly:
                // FIX Bug 7: Programmer pour chaque jour sélectionné (4 prochaines semaines)
                guard !selectedDays.isEmpty else {
                    // Fallback: programmation unique si aucun jour sélectionné
                    zenloopManager.scheduleCustomChallenge(
                        title: session.title,
                        duration: currentDuration,
                        difficulty: difficulty,
                        apps: selectedApps,
                        startTime: selectedStartTime
                    )
                    break
                }

                let calendar = Calendar.current
                let baseHour = calendar.component(.hour, from: selectedStartTime)
                let baseMinute = calendar.component(.minute, from: selectedStartTime)

                // Programmer pour les 4 prochaines semaines
                for weekOffset in 0..<4 {
                    for day in selectedDays {
                        guard let targetDate = nextDate(for: day, weekOffset: weekOffset, hour: baseHour, minute: baseMinute) else { continue }
                        guard targetDate.timeIntervalSinceNow > 120 else { continue }

                        zenloopManager.scheduleCustomChallenge(
                            title: "\(session.title) (\(day.shortName))",
                            duration: currentDuration,
                            difficulty: difficulty,
                            apps: selectedApps,
                            startTime: targetDate
                        )
                    }
                }
            }

            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            #endif

            dismiss()
        }
    }

    // FIX Bug 7: Helper pour calculer la prochaine date d'un jour de la semaine
    private func nextDate(for weekday: Weekday, weekOffset: Int, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let today = Date()

        // Convertir Weekday en numéro de jour Calendar (1=dimanche, 2=lundi, etc.)
        let targetWeekday: Int
        switch weekday {
        case .sunday: targetWeekday = 1
        case .monday: targetWeekday = 2
        case .tuesday: targetWeekday = 3
        case .wednesday: targetWeekday = 4
        case .thursday: targetWeekday = 5
        case .friday: targetWeekday = 6
        case .saturday: targetWeekday = 7
        }

        // Trouver le prochain jour correspondant
        var components = DateComponents()
        components.weekday = targetWeekday
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let nextOccurrence = calendar.nextDate(after: today, matching: components, matchingPolicy: .nextTime) else {
            return nil
        }

        // Ajouter l'offset de semaines
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: nextOccurrence)
    }

    private func calculateNextOptimalTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        let targetDate: Date
        let targetHour: Int

        if currentHour < 23 {
            targetDate = now
            targetHour = currentHour + 1
        } else {
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            targetHour = 8
        }

        let components = DateComponents(
            year: calendar.component(.year, from: targetDate),
            month: calendar.component(.month, from: targetDate),
            day: calendar.component(.day, from: targetDate),
            hour: targetHour,
            minute: 0
        )

        return calendar.date(from: components) ?? now
    }
}

// MARK: - Supporting Types

enum ScheduleFrequency: String, CaseIterable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"

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
        case .monday: return String(localized: "monday")
        case .tuesday: return String(localized: "tuesday")
        case .wednesday: return String(localized: "wednesday")
        case .thursday: return String(localized: "thursday")
        case .friday: return String(localized: "friday")
        case .saturday: return String(localized: "saturday")
        case .sunday: return String(localized: "sunday")
        }
    }

    var shortName: String {
        switch self {
        case .monday: return String(localized: "mon")
        case .tuesday: return String(localized: "tue")
        case .wednesday: return String(localized: "wed")
        case .thursday: return String(localized: "thu")
        case .friday: return String(localized: "fri")
        case .saturday: return String(localized: "sat")
        case .sunday: return String(localized: "sun")
        }
    }
}

struct WeekdayToggle: View {
    let day: Weekday
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(day.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accentColor : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? accentColor : .white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}