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
            case .manual: "Manuel"
            case .timed: "Durée définie"
            case .scheduled: "Programmée"
            }
        }
        
        var subtitle: String {
            switch self {
            case .manual: "Gérer manuellement"
            case .timed: "Fin automatique"
            case .scheduled: "Début & fin auto"
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
                    VStack(spacing: 20) {
                        SessionTextField(
                            title: "Titre de la Session",
                            placeholder: "Ex: Focus Marathon",
                            text: $sessionTitle
                        )
                        .staggerIn(showContent, delay: 0.1)

                        descriptionField
                            .staggerIn(showContent, delay: 0.2)

                        visibilityPicker
                            .staggerIn(showContent, delay: 0.3)

                        SessionTextField(
                            title: "Max. Participants (optionnel)",
                            placeholder: "Ex: 10",
                            text: $maxParticipants,
                            keyboard: .numberPad
                        )
                        .staggerIn(showContent, delay: 0.4)

                        durationSection
                            .staggerIn(showContent, delay: 0.45)

                        appSelectionCard
                            .staggerIn(showContent, delay: 0.5)

                        backgroundSelectionCard
                            .staggerIn(showContent, delay: 0.55)

                        if let error = errorMessage {
                            ErrorBanner(message: error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        createButton
                            .staggerIn(showContent, delay: 0.6)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nouvelle Session")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Invitez vos amis à focus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
        .staggerIn(showContent, delay: 0)
    }

    var descriptionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Description")
            ZStack(alignment: .topLeading) {
                if sessionDescription.isEmpty {
                    Text("Décrivez votre session...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $sessionDescription)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .cardBackground()
        }
    }

    var visibilityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Visibilité")
            HStack(spacing: 12) {
                SelectableCard(
                    icon: "globe", title: "Publique",
                    subtitle: "Visible par tous",
                    isSelected: isPublic
                ) { isPublic = true }

                SelectableCard(
                    icon: "lock.fill", title: "Privée",
                    subtitle: "Code requis",
                    isSelected: !isPublic
                ) { isPublic = false }
            }
        }
    }

    // MARK: Duration

    var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Durée de la Session")

            // Mode buttons — 2-column top row + full-width scheduled
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach([DurationMode.manual, .timed], id: \.self) { m in
                        SelectableCard(icon: m.icon, title: m.title, subtitle: m.subtitle,
                                       isSelected: durationMode == m, accent: .blue) { durationMode = m }
                    }
                }
                SelectableCard(icon: DurationMode.scheduled.icon, title: DurationMode.scheduled.title,
                               subtitle: DurationMode.scheduled.subtitle,
                               isSelected: durationMode == .scheduled, accent: .blue) { durationMode = .scheduled }
            }

            if durationMode == .timed { timedPicker }
            if durationMode == .scheduled { scheduledPickers }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: durationMode)
    }

    var timedPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StepperCard(label: "Heures", value: $selectedHours, range: 0...12)
                StepperCard(label: "Minutes", value: $selectedMinutes, range: 0...45, step: 15)
            }
            if selectedHours > 0 || selectedMinutes > 0 {
                durationLabel(hours: selectedHours, minutes: selectedMinutes)
            }
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    var scheduledPickers: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScheduleDateRow(icon: "play.circle.fill", color: .green, label: "Heure de Début",
                            date: $scheduledStartDate, minDate: Date()) { newVal in
                if scheduledEndDate <= newVal {
                    scheduledEndDate = newVal.addingTimeInterval(3600)
                }
            }

            ScheduleDateRow(icon: "stop.circle.fill", color: .red, label: "Heure de Fin",
                            date: $scheduledEndDate,
                            minDate: scheduledStartDate.addingTimeInterval(900))

            let dur = scheduledEndDate.timeIntervalSince(scheduledStartDate)
            durationLabel(hours: Int(dur) / 3600, minutes: (Int(dur) % 3600) / 60)
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: App Selection

    var appSelectionCard: some View {
        Button { showAppPicker = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(.linearGradient(colors: [.init(red: 0.5, green: 0.4, blue: 1),
                                                    .init(red: 0.4, green: 0.3, blue: 0.9)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: selectedAppsCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps à Bloquer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) app(s) sélectionnée(s)" : "Suggérer des apps (optionnel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selectedAppsCount > 0 ? Color.purple.opacity(0.5) : .white.opacity(0.1),
                            lineWidth: selectedAppsCount > 0 ? 2 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Background Selection

    var backgroundSelectionCard: some View {
        Button { showBackgroundPicker = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(.linearGradient(colors: [.init(red: 1, green: 0.4, blue: 0.6),
                                                    .init(red: 0.9, green: 0.3, blue: 0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: selectedBackground != nil ? "photo.fill" : "photo.badge.plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Image de fond")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(selectedBackground?.name ?? "Aucune image (optionnel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selectedBackground != nil ? Color.pink.opacity(0.5) : .white.opacity(0.1),
                            lineWidth: selectedBackground != nil ? 2 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerView(selectedBackground: $selectedBackground)
        }
    }

    // MARK: Create & Error

    var createButton: some View {
        Button(action: createSession) {
            HStack(spacing: 12) {
                if isCreating {
                    ProgressView().tint(.white)
                    Text("Création...")
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Créer la Session")
                }
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.linearGradient(
                        colors: isValid
                            ? [Color(red: 0.3, green: 0.6, blue: 1), Color(red: 0.2, green: 0.5, blue: 0.9)]
                            : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .disabled(!isValid || isCreating)
    }

    func durationLabel(hours: Int, minutes: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill").font(.system(size: 14))
            Text("Durée: \(Self.formatDuration(h: hours, m: minutes))")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.blue.opacity(0.8))
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

/// Section label standardisé
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
    }
}

/// Champ texte réutilisable avec style card
struct SessionTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .keyboardType(keyboard)
                .padding(16)
                .cardBackground()
        }
    }
}

/// Carte sélectionnable (visibilité, mode durée)
struct SelectableCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    var accent: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .white.opacity(0.5))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: 16).fill(.cardFill))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accent : .white.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

/// Stepper +/- compact
struct StepperCard: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            HStack {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 24))
                }
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)
                Button {
                    let next = value + step
                    if next > range.upperBound {
                        value = range.lowerBound
                    } else {
                        value = next
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 24))
                }
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.cardFill))
    }
}

/// Ligne de DatePicker pour les sessions programmées
struct ScheduleDateRow: View {
    let icon: String
    let color: Color
    let label: String
    @Binding var date: Date
    var minDate: Date
    var onChange: ((Date) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
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
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.cardFill))
        }
    }
}

// MARK: - View Modifiers & Extensions

private struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.15, green: 0.15, blue: 0.17)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackgroundModifier())
    }
}

/// Animation d'entrée en escalier
private struct StaggerModifier: ViewModifier {
    let show: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 20)
            .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: show)
    }
}

extension View {
    func staggerIn(_ show: Bool, delay: Double) -> some View {
        modifier(StaggerModifier(show: show, delay: delay))
    }
}

/// ShapeStyle helper pour le fill card
extension ShapeStyle where Self == Color {
    static var cardFill: Color {
        Color(red: 0.15, green: 0.15, blue: 0.17)
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