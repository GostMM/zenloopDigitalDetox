//
//  CreateSessionView.swift
//  zenloop
//
//  Modal pour créer une nouvelle session de groupe
//  Version optimisée et compacte
//

import SwiftUI
import FamilyControls

// MARK: - Main View

struct CreateSessionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var sessionManager = SessionManager.shared
    @EnvironmentObject var zenloopManager: ZenloopManager

    @State private var showContent = false
    @State private var sessionTitle = ""
    @State private var sessionDescription = ""
    @State private var isPublic = true
    @State private var maxParticipants = ""
    @State private var showAppPicker = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var durationMode = DurationMode.manual
    @State private var selectedHours = 0
    @State private var selectedMinutes = 30
    @State private var scheduledStartDate = Date().addingTimeInterval(3600)
    @State private var scheduledEndDate = Date().addingTimeInterval(7200)
    @State private var selectedBackground: SessionBackground? = nil
    @State private var showBackgroundPicker = false

    enum DurationMode: CaseIterable {
        case manual, timed, scheduled
        
        var icon: String {
            switch self {
            case .manual: "infinity"
            case .timed: "timer"
            case .scheduled: "calendar.badge.clock"
            }
        }
        
        var title: String {
            switch self {
            case .manual: String(localized: "session_duration_manual")
            case .timed: String(localized: "session_duration_timed")
            case .scheduled: String(localized: "session_duration_scheduled")
            }
        }

        var subtitle: String {
            switch self {
            case .manual: String(localized: "session_duration_manual_sub")
            case .timed: String(localized: "session_duration_timed_sub")
            case .scheduled: String(localized: "session_duration_scheduled_sub")
            }
        }
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var isValid: Bool {
        !sessionTitle.isEmpty && !sessionDescription.isEmpty
    }

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        InlineField(
                            label: String(localized: "session_field_title"),
                            placeholder: String(localized: "session_field_title_placeholder"),
                            text: $sessionTitle
                        )
                        .staggerIn(showContent, delay: 0.08)

                        InlineField(
                            label: String(localized: "session_field_description"),
                            placeholder: String(localized: "session_field_description_placeholder"),
                            text: $sessionDescription,
                            multiline: true
                        )
                        .staggerIn(showContent, delay: 0.14)

                        visibilityPicker
                            .staggerIn(showContent, delay: 0.2)

                        InlineField(
                            label: String(localized: "session_field_max_participants"),
                            placeholder: String(localized: "session_field_optional"),
                            text: $maxParticipants,
                            keyboard: .numberPad
                        )
                        .staggerIn(showContent, delay: 0.26)

                        durationSection
                            .staggerIn(showContent, delay: 0.32)

                        optionalRows
                            .staggerIn(showContent, delay: 0.38)

                        if let error = errorMessage {
                            ErrorBanner(message: error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        createButton
                            .staggerIn(showContent, delay: 0.44)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                showContent = true
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selectedApps)
    }
}

// MARK: - Subviews

private extension CreateSessionView {

    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "session_create_title"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(localized: "session_create_subtitle"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .staggerIn(showContent, delay: 0)
    }

    var visibilityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(String(localized: "session_visibility"))
            SegmentedToggle(
                options: [
                    .init(id: "public", icon: "globe", title: String(localized: "session_visibility_public")),
                    .init(id: "private", icon: "lock.fill", title: String(localized: "session_visibility_private"))
                ],
                selectedId: isPublic ? "public" : "private"
            ) { id in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPublic = (id == "public")
                }
            }
        }
    }

    // MARK: Duration

    var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(String(localized: "session_duration"))

            SegmentedToggle(
                options: DurationMode.allCases.map {
                    .init(id: $0.title, icon: $0.icon, title: $0.title)
                },
                selectedId: durationMode.title
            ) { id in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if let m = DurationMode.allCases.first(where: { $0.title == id }) {
                        durationMode = m
                    }
                }
            }

            if durationMode == .timed { timedPicker }
            if durationMode == .scheduled { scheduledPickers }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: durationMode)
    }

    var timedPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                InlineStepper(label: String(localized: "session_hours"), value: $selectedHours, range: 0...12)
                InlineStepper(label: String(localized: "session_minutes"), value: $selectedMinutes, range: 0...45, step: 15)
            }
            if selectedHours > 0 || selectedMinutes > 0 {
                durationLabel(hours: selectedHours, minutes: selectedMinutes)
            }
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    var scheduledPickers: some View {
        VStack(alignment: .leading, spacing: 10) {
            InlineDateRow(label: String(localized: "session_start"), date: $scheduledStartDate, minDate: Date()) { newVal in
                if scheduledEndDate <= newVal {
                    scheduledEndDate = newVal.addingTimeInterval(3600)
                }
            }
            InlineDateRow(label: String(localized: "session_end"), date: $scheduledEndDate,
                          minDate: scheduledStartDate.addingTimeInterval(900))

            let dur = scheduledEndDate.timeIntervalSince(scheduledStartDate)
            durationLabel(hours: Int(dur) / 3600, minutes: (Int(dur) % 3600) / 60)
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    // MARK: Optional Rows (apps + background)

    var optionalRows: some View {
        VStack(spacing: 10) {
            OptionRow(
                icon: "app.badge",
                title: String(localized: "session_apps_to_block"),
                value: selectedAppsCount > 0
                    ? String(format: String(localized: "session_apps_count"), selectedAppsCount)
                    : String(localized: "session_field_optional"),
                isActive: selectedAppsCount > 0
            ) { showAppPicker = true }

            OptionRow(
                icon: "photo",
                title: String(localized: "session_background_image"),
                value: selectedBackground?.name ?? String(localized: "session_field_optional"),
                isActive: selectedBackground != nil
            ) { showBackgroundPicker = true }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerView(selectedBackground: $selectedBackground)
        }
    }

    // MARK: Create & Error

    var createButton: some View {
        Button(action: createSession) {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView().tint(.white)
                    Text(String(localized: "session_creating"))
                } else {
                    Text(String(localized: "session_create_button"))
                }
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(isValid ? .white : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isValid
                          ? Color(red: 0.3, green: 0.6, blue: 1)
                          : Color.white.opacity(0.08))
            )
        }
        .disabled(!isValid || isCreating)
    }

    func durationLabel(hours: Int, minutes: Int) -> some View {
        Text(Self.formatDuration(h: hours, m: minutes))
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .monospacedDigit()
    }

    static func formatDuration(h: Int, m: Int) -> String {
        [h > 0 ? "\(h)h" : nil, m > 0 ? "\(m)min" : nil]
            .compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Create Session Logic

private extension CreateSessionView {

    func createSession() {
        guard !isCreating else { return }
        isCreating = true
        errorMessage = nil

        Task {
            do {
                let maxPart = Int(maxParticipants)

                let (durationMins, schedStart, schedEnd): (Int?, Date?, Date?) = {
                    switch durationMode {
                    case .manual:
                        return (nil, nil, nil)
                    case .timed:
                        return (selectedHours * 60 + selectedMinutes, nil, nil)
                    case .scheduled:
                        let mins = Int(scheduledEndDate.timeIntervalSince(scheduledStartDate) / 60)
                        return (mins, scheduledStartDate, scheduledEndDate)
                    }
                }()

                let session = try await sessionManager.createSession(
                    title: sessionTitle,
                    description: sessionDescription,
                    visibility: isPublic ? .publicSession : .privateSession,
                    maxParticipants: maxPart,
                    suggestedAppsCount: selectedAppsCount,
                    durationMinutes: durationMins,
                    scheduledStartTime: schedStart,
                    scheduledEndTime: schedEnd,
                    backgroundImageUrl: selectedBackground?.storagePath
                )

                guard let sessionId = session.id else { return }

                // Sauvegarder les tokens d'apps localement
                if selectedAppsCount > 0,
                   let tokenData = try? JSONEncoder().encode(selectedApps) {
                    sessionManager.saveLocalApps(sessionId: sessionId, appTokens: tokenData, count: selectedAppsCount)
                }

                // Programmer le DeviceActivity si nécessaire
                if durationMode == .scheduled {
                    try await ScheduledSessionCoordinator.shared.scheduleSession(
                        sessionId: sessionId,
                        startTime: scheduledStartDate,
                        endTime: scheduledEndDate,
                        apps: selectedApps
                    )
                }

                sessionManager.startSessionListener(sessionId: sessionId)

                await MainActor.run {
                    isCreating = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Reusable Components

/// Label de champ minimal (caps + tracking)
private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.4))
    }
}

/// Champ inline — label discret + input minimal sans card épaisse
struct InlineField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label)

            Group {
                if multiline {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 70, maxHeight: 110)
                            .padding(.leading, -4)
                    }
                } else {
                    TextField("", text: $text, prompt: Text(placeholder)
                        .foregroundColor(.white.opacity(0.3)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .keyboardType(keyboard)
                }
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(text.isEmpty ? Color.white.opacity(0.1) : Color.white.opacity(0.25))
                    .frame(height: 1)
            }
        }
    }
}

/// Segmented pill picker (visibilité, durée mode)
struct SegmentedToggle: View {
    struct Option: Identifiable {
        let id: String
        let icon: String
        let title: String
    }
    let options: [Option]
    let selectedId: String
    let onSelect: (String) -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { opt in
                let isSelected = selectedId == opt.id
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(opt.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(opt.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.white)
                                    .matchedGeometryEffect(id: "segbg", in: ns)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}

/// Stepper inline compact (une ligne)
struct InlineStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 28)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let next = value + step
                value = next > range.upperBound ? range.lowerBound : next
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

/// DatePicker inline compact (une ligne)
struct InlineDateRow: View {
    let label: String
    @Binding var date: Date
    var minDate: Date
    var onChange: ((Date) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 50, alignment: .leading)

            Spacer()

            DatePicker("", selection: Binding(
                get: { date },
                set: { newVal in
                    date = newVal
                    onChange?(newVal)
                }
            ), in: minDate..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}

/// Ligne d'option (Apps, Background)
struct OptionRow: View {
    let icon: String
    let title: String
    let value: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? Color(red: 0.3, green: 0.6, blue: 1) : .white.opacity(0.55))
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? Color(red: 0.3, green: 0.6, blue: 1) : .white.opacity(0.4))
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Modifiers & Extensions

/// Animation d'entrée en escalier
private struct StaggerModifier: ViewModifier {
    let show: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 14)
            .animation(.spring(response: 0.9, dampingFraction: 0.82).delay(delay), value: show)
    }
}

extension View {
    func staggerIn(_ show: Bool, delay: Double) -> some View {
        modifier(StaggerModifier(show: show, delay: delay))
    }
}

// MARK: - Error Banner (shared with JoinSessionView)

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    CreateSessionView()
        .environmentObject(ZenloopManager.shared)
}