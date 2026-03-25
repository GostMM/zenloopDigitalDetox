//
//  JoinSessionView.swift
//  zenloop
//
//  Modal pour rejoindre une session avec un code d'invitation
//  Style: HomeView avec background optimisé
//

import SwiftUI

struct JoinSessionView: View {
    @Environment(\.dismiss) var dismiss
    // ✅ FIX: @ObservedObject pour les singletons (pas @StateObject)
    @ObservedObject private var sessionManager = SessionManager.shared
    @Binding var inviteCode: String

    @State private var showContent = false
    @State private var codeDigits: [String] = ["", "", "", "", "", ""]
    @State private var isSearching = false
    @State private var foundSession: Session?
    @State private var errorMessage: String?
    @FocusState private var focusedField: Int?

    var body: some View {
        ZStack {
            // Background optimisé
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 0) {
                // Header
                JoinSessionHeader(onClose: { dismiss() }, showContent: showContent)
                    .padding(.horizontal, 20)

                // Contenu
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // Title
                        VStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.8))

                            Text("Entrez le Code d'Invitation")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("6 caractères")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 40)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1), value: showContent)

                        // Code Input
                        CodeInputView(
                            digits: $codeDigits,
                            focusedField: _focusedField,
                            showContent: showContent
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2), value: showContent)

                        // Error Message
                        if let error = errorMessage {
                            ErrorBanner(message: error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Found Session Card
                        if let session = foundSession {
                            SessionFoundCard(
                                session: session,
                                showContent: showContent,
                                onJoin: {
                                    joinSession(session)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Search Button
                        if foundSession == nil {
                            SearchButton(
                                isSearching: isSearching,
                                isEnabled: isCodeComplete,
                                showContent: showContent,
                                action: searchSession
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                showContent = true
            }

            // Focus first field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = 0
            }
        }
        .onChange(of: codeDigits) { _ in
            // Auto-search when code is complete
            if isCodeComplete && foundSession == nil {
                searchSession()
            }
        }
    }

    private var isCodeComplete: Bool {
        codeDigits.allSatisfy { !$0.isEmpty }
    }

    private var fullCode: String {
        codeDigits.joined()
    }

    private func searchSession() {
        guard !isSearching, isCodeComplete else { return }

        isSearching = true
        errorMessage = nil
        foundSession = nil

        Task {
            do {
                let session = try await sessionManager.joinSession(inviteCode: fullCode)

                await MainActor.run {
                    isSearching = false
                    foundSession = session

                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription

                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func joinSession(_ session: Session) {
        // Start listening to session
        sessionManager.startSessionListener(sessionId: session.id!)

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        dismiss()
    }
}

// MARK: - Join Session Header

struct JoinSessionHeader: View {
    let onClose: () -> Void
    let showContent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rejoindre")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Entrez le code d'invitation")
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

// MARK: - Code Input View

struct CodeInputView: View {
    @Binding var digits: [String]
    @FocusState var focusedField: Int?
    let showContent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                CodeDigitField(
                    text: $digits[index],
                    isFocused: focusedField == index,
                    onSubmit: {
                        if index < 5 {
                            focusedField = index + 1
                        } else {
                            focusedField = nil
                        }
                    },
                    onBackspace: {
                        if digits[index].isEmpty && index > 0 {
                            focusedField = index - 1
                            digits[index - 1] = ""
                        }
                    }
                )
                .focused($focusedField, equals: index)
            }
        }
    }
}

struct CodeDigitField: View {
    @Binding var text: String
    let isFocused: Bool
    let onSubmit: () -> Void
    let onBackspace: () -> Void

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .keyboardType(.asciiCapable)
            .autocapitalization(.allCharacters)
            .disableAutocorrection(true)
            .frame(width: 50, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color.blue : Color.white.opacity(0.1),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .onChange(of: text) { newValue in
                // Only allow one character
                if newValue.count > 1 {
                    text = String(newValue.prefix(1))
                }

                // Auto-advance to next field
                if !newValue.isEmpty {
                    onSubmit()
                }

                // Convert to uppercase
                text = text.uppercased()
            }
            .onKeyPress(.delete) {
                onBackspace()
                return .handled
            }
    }
}

// MARK: - Session Found Card

struct SessionFoundCard: View {
    let session: Session
    let showContent: Bool
    let onJoin: () -> Void

    private var statusText: String {
        switch session.status {
        case .lobby: return "En attente"
        case .active: return "En cours (late join)"
        case .paused: return "En pause"
        case .completed: return "Terminée"
        case .dissolved: return "Dissoute"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .lobby: return .orange
        case .active: return .green
        case .paused: return .orange.opacity(0.7)
        case .completed: return .blue
        case .dissolved: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.3),
                                Color.green.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }

            // Session Info
            VStack(spacing: 12) {
                Text(session.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(session.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                // Session Details
                HStack(spacing: 16) {
                    Label(statusText, systemImage: "circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)

                    Label("\(session.memberIds.count) membres", systemImage: "person.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Leader info
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)

                    Text("par \(session.leaderUsername)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Join Button
            Button(action: onJoin) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("Rejoindre la Session")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color.green.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
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
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.5),
                            Color.green.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1.0 : 0.9)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showContent)
    }
}

// MARK: - Search Button

struct SearchButton: View {
    let isSearching: Bool
    let isEnabled: Bool
    let showContent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text("Recherche...")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("Chercher la Session")
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
                            colors: isEnabled ? [
                                Color(red: 0.4, green: 0.5, blue: 1.0),
                                Color(red: 0.3, green: 0.4, blue: 0.9)
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
        .disabled(!isEnabled || isSearching)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
}

#Preview {
    JoinSessionView(inviteCode: .constant(""))
}