//
//  TopAppToast.swift
//  zenloop
//
//  Toast élégant affichant l'app la plus utilisée avec effet de lumière
//

import SwiftUI

struct TopAppToast: View {
    let appName: String
    let duration: TimeInterval
    let appColor: Color
    let appIcon: String
    @Binding var isShowing: Bool

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var borderPhase: CGFloat = 0
    @State private var glowIntensity: Double = 0.6

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                // Icône de l'app avec glow dynamique
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

                    // Container de l'icône
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    appColor.opacity(0.4),
                                    appColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    // Icône
                    Image(systemName: appIcon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(color: appColor.opacity(0.6), radius: 15, x: 0, y: 6)

                // Contenu textuel
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "most_used_app"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(appName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text(formatDuration(duration))
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

                // Bouton de fermeture
                Button(action: { dismissToast() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
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

        // Auto-dismiss après 5 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            dismissToast()
        }
    }

    private func dismissToast() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            offset = -100
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isShowing = false
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

// MARK: - Preview

struct TopAppToast_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.08, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TopAppToast(
                appName: "Instagram",
                duration: 5400,
                appColor: .pink,
                appIcon: "photo.on.rectangle.angled",
                isShowing: .constant(true)
            )
        }
    }
}
