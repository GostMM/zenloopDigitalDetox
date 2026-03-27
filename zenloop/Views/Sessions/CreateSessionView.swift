//
//  CreateSessionView.swift
//  zenloop
//
//  Modal pour créer une nouvelle session de groupe
//  Style: HomeView avec background optimisé
//

import SwiftUI
import FamilyControls

struct CreateSessionView: View {
    @Environment(\.dismiss) var dismiss
    // ✅ FIX: @ObservedObject pour les singletons (pas @StateObject)
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
    @State private var sessionDurationMode = DurationMode.manual
    @State private var selectedHours = 0
    @State private var selectedMinutes = 30

    enum DurationMode {
        case manual
        case timed
    }

    private var selectedAppsCount: Int {
        selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
    }

    private var isValid: Bool {
        !sessionTitle.isEmpty && !sessionDescription.isEmpty
    }

    var body: some View {
        ZStack {
            // Background optimisé
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                // Header
                CreateSessionHeader(onClose: { dismiss() }, showContent: showContent)
                    .padding(.horizontal, 20)

                // Contenu scrollable
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Title Field
                        InputSection(
                            title: "Titre de la Session",
                            placeholder: "Ex: Focus Marathon",
                            text: $sessionTitle,
                            showContent: showContent,
                            delay: 0.1
                        )

                        // Description Field
                        TextEditorSection(
                            title: "Description",
                            placeholder: "Décrivez votre session...",
                            text: $sessionDescription,
                            showContent: showContent,
                            delay: 0.2
                        )

                        // Visibility Toggle
                        VisibilitySection(
                            isPublic: $isPublic,
                            showContent: showContent,
                            delay: 0.3
                        )

                        // Max Participants (optional)
                        InputSection(
                            title: "Nombre Maximum de Participants (optionnel)",
                            placeholder: "Ex: 10",
                            text: $maxParticipants,
                            keyboardType: .numberPad,
                            showContent: showContent,
                            delay: 0.4
                        )

                        // Duration Section
                        DurationSelectionSection(
                            mode: $sessionDurationMode,
                            hours: $selectedHours,
                            minutes: $selectedMinutes,
                            showContent: showContent,
                            delay: 0.45
                        )

                        // App Selection Card
                        SessionAppSelectionCard(
                            selectedCount: selectedAppsCount,
                            showContent: showContent,
                            delay: 0.5,
                            onTap: { showAppPicker = true }
                        )

                        // Error Message
                        if let error = errorMessage {
                            ErrorBanner(message: error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Create Button
                        CreateButton(
                            isValid: isValid,
                            isCreating: isCreating,
                            showContent: showContent,
                            delay: 0.6,
                            action: createSession
                        )

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

    private func createSession() {
        guard !isCreating else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let maxPart = Int(maxParticipants) ?? nil
                let durationMins = sessionDurationMode == .timed ? (selectedHours * 60 + selectedMinutes) : nil

                let session = try await sessionManager.createSession(
                    title: sessionTitle,
                    description: sessionDescription,
                    visibility: isPublic ? .publicSession : .privateSession,
                    maxParticipants: maxPart,
                    suggestedAppsCount: selectedAppsCount,
                    durationMinutes: durationMins
                )

                // Save selected apps locally (never sent to Firebase)
                if selectedAppsCount > 0,
                   let tokenData = try? JSONEncoder().encode(selectedApps) {
                    sessionManager.saveLocalApps(
                        sessionId: session.id!,
                        appTokens: tokenData,
                        count: selectedAppsCount
                    )
                }

                // Start listening to session
                sessionManager.startSessionListener(sessionId: session.id!)

                await MainActor.run {
                    isCreating = false

                    // Haptic feedback
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

// MARK: - Create Session Header

struct CreateSessionHeader: View {
    let onClose: () -> Void
    let showContent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nouvelle Session")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Invitez vos amis à focus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: showContent)
    }
}

// MARK: - Input Section

struct InputSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let showContent: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
    }
}

// MARK: - Text Editor Section

struct TextEditorSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let showContent: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
    }
}

// MARK: - Visibility Section

struct VisibilitySection: View {
    @Binding var isPublic: Bool
    let showContent: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Visibilité")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                VisibilityButton(
                    icon: "globe",
                    title: "Publique",
                    subtitle: "Visible par tous",
                    isSelected: isPublic,
                    action: { isPublic = true }
                )

                VisibilityButton(
                    icon: "lock.fill",
                    title: "Privée",
                    subtitle: "Code requis",
                    isSelected: !isPublic,
                    action: { isPublic = false }
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
    }
}

struct VisibilityButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.5))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.blue : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Session App Selection Card

struct SessionAppSelectionCard: View {
    let selectedCount: Int
    let showContent: Bool
    let delay: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.4, blue: 1.0),
                                    Color(red: 0.4, green: 0.3, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps à Bloquer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(selectedCount > 0 ? "\(selectedCount) app(s) sélectionnée(s)" : "Suggérer des apps (optionnel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.17),
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedCount > 0 ? Color.purple.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: selectedCount > 0 ? 2 : 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
    }
}

// MARK: - Create Button

struct CreateButton: View {
    let isValid: Bool
    let isCreating: Bool
    let showContent: Bool
    let delay: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text("Création...")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Créer la Session")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isValid ? [
                                Color(red: 0.3, green: 0.6, blue: 1.0),
                                Color(red: 0.2, green: 0.5, blue: 0.9)
                            ] : [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .disabled(!isValid || isCreating)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Duration Selection Section

struct DurationSelectionSection: View {
    @Binding var mode: CreateSessionView.DurationMode
    @Binding var hours: Int
    @Binding var minutes: Int
    let showContent: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Durée de la Session")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            // Mode Selection
            HStack(spacing: 12) {
                DurationModeButton(
                    icon: "infinity",
                    title: "Manuel",
                    subtitle: "Gérer manuellement",
                    isSelected: mode == .manual,
                    action: { mode = .manual }
                )

                DurationModeButton(
                    icon: "timer",
                    title: "Durée définie",
                    subtitle: "Fin automatique",
                    isSelected: mode == .timed,
                    action: { mode = .timed }
                )
            }

            // Time Selection (only when timed mode)
            if mode == .timed {
                HStack(spacing: 16) {
                    // Hours Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Heures")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        HStack {
                            Button(action: { if hours > 0 { hours -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Text("\(hours)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 40)

                            Button(action: { if hours < 12 { hours += 1 } }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    )

                    // Minutes Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minutes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        HStack {
                            Button(action: {
                                if minutes >= 15 {
                                    minutes -= 15
                                } else if minutes > 0 {
                                    minutes = 0
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Text("\(minutes)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 40)

                            Button(action: {
                                if minutes < 45 {
                                    minutes += 15
                                } else {
                                    minutes = 0
                                    if hours < 12 { hours += 1 }
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    )
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))

                // Display total duration
                if hours > 0 || minutes > 0 {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue.opacity(0.8))

                        Text("Durée totale: \(formatDuration(hours: hours, minutes: minutes))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(delay), value: showContent)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: mode)
    }

    private func formatDuration(hours: Int, minutes: Int) -> String {
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if minutes > 0 {
            parts.append("\(minutes)min")
        }
        return parts.joined(separator: " ")
    }
}

struct DurationModeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.5))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.blue : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

#Preview {
    CreateSessionView()
        .environmentObject(ZenloopManager.shared)
}