//
//  TopAppToastView.swift
//  zenloopactivity
//
//  Composant de toast dans l'extension pour afficher l'app la plus utilisée avec VRAIE icône
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct TopAppToastView: View {
    let app: ExtensionAppUsage
    let onHide: () -> Void
    let onRestrict: (RestrictionType) -> Void

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var borderPhase: CGFloat = 0
    @State private var glowIntensity: Double = 0.6
    @State private var showActions = false

    enum RestrictionType {
        case shield  // Overlay
        case hide    // Masquer complètement
    }

    private var appColor: Color {
        let name = app.name.lowercased()
        switch true {
        case name.contains("instagram"): return .pink
        case name.contains("facebook"): return .blue
        case name.contains("tiktok"): return Color(red: 0.0, green: 0.9, blue: 0.8)
        case name.contains("twitter"), name.contains("x"): return .cyan
        case name.contains("youtube"): return .red
        case name.contains("spotify"): return .green
        case name.contains("snapchat"): return .yellow
        case name.contains("whatsapp"): return Color(red: 0.15, green: 0.68, blue: 0.38)
        case name.contains("telegram"): return Color(red: 0.2, green: 0.6, blue: 0.9)
        case name.contains("safari"): return .blue
        case name.contains("chrome"): return Color(red: 0.26, green: 0.52, blue: 0.96)
        case name.contains("netflix"): return .red
        default: return .purple
        }
    }

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                // Contenu principal
                HStack(spacing: 14) {
                    // VRAIE ICÔNE depuis ApplicationToken
                    ZStack {
                        // Glow pulsant
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        appColor.opacity(glowIntensity),
                                        appColor.opacity(glowIntensity * 0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                            .blur(radius: 10)

                        // Container avec vraie icône
                        #if os(iOS)
                        Label(app.token)
                            .labelStyle(.iconOnly)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(appColor.opacity(0.1))
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        #endif
                    }
                    .shadow(color: appColor.opacity(0.6), radius: 15, x: 0, y: 6)

                    // Infos app
                    VStack(alignment: .leading, spacing: 5) {
                        Text("App la Plus Utilisée")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .textCase(.uppercase)
                            .tracking(1)

                        Text(app.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text(formatDuration(app.duration))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [appColor.opacity(0.9), appColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }

                    Spacer()

                    // Bouton expand/collapse
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showActions.toggle()
                        }
                    }) {
                        Image(systemName: showActions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                // Actions (expandable)
                if showActions {
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.white.opacity(0.1))

                        HStack(spacing: 10) {
                            // Bouton Shield (Overlay)
                            ActionButton(
                                title: "Shield",
                                icon: "shield.fill",
                                color: .orange
                            ) {
                                onRestrict(.shield)
                            }

                            // Bouton Hide (Masquer)
                            ActionButton(
                                title: "Hide",
                                icon: "eye.slash.fill",
                                color: .red
                            ) {
                                onRestrict(.hide)
                            }

                            // Bouton Fermer
                            ActionButton(
                                title: "Close",
                                icon: "xmark",
                                color: .gray
                            ) {
                                dismissToast()
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(
                ZStack {
                    // Background glassmorphism
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.95),
                                    Color(red: 0.16, green: 0.14, blue: 0.22).opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.08),
                                            .clear,
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    // Bordure animée
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    appColor.opacity(0.8),
                                    appColor.opacity(0.4),
                                    Color.white.opacity(0.3),
                                    appColor.opacity(0.4),
                                    appColor.opacity(0.8)
                                ]),
                                center: .center,
                                angle: .degrees(borderPhase)
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 0.5)
                }
            )
            .shadow(color: appColor.opacity(0.4), radius: 25, x: 0, y: 12)
            .shadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 8)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            showToast()
        }
    }

    private func showToast() {
        // Animation d'entrée
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75, blendDuration: 0.3)) {
            offset = 55
            opacity = 1
        }

        // Animation de rotation de bordure
        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
            borderPhase = 360
        }

        // Animation de pulsation du glow
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }

        // Auto-dismiss après 8 secondes (plus long pour avoir le temps d'interagir)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if !showActions {
                dismissToast()
            }
        }
    }

    private func dismissToast() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            offset = -100
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onHide()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
}

// MARK: - Action Button Component

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
