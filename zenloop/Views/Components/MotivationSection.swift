//
//  MotivationSection.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct MotivationSection: View {
    let showContent: Bool
    @ObservedObject var zenloopManager: ZenloopManager
    @State private var currentTipIndex = 0
    
    private let motivationalTips = [
        MotivationalTip(
            icon: "brain.head.profile",
            title: "Focus Profond",
            message: "25 minutes de concentration valent mieux que 2 heures de distraction",
            color: .blue
        ),
        MotivationalTip(
            icon: "target",
            title: "Objectif Claire",
            message: "Définis un objectif précis avant chaque session de focus",
            color: .green
        ),
        MotivationalTip(
            icon: "moon.stars",
            title: "Pause Régulière",
            message: "Prends des pauses de 5 minutes toutes les 25 minutes",
            color: .purple
        ),
        MotivationalTip(
            icon: "leaf.fill",
            title: "Environnement",
            message: "Un espace calme et organisé améliore ta concentration",
            color: .mint
        ),
        MotivationalTip(
            icon: "heart.fill",
            title: "Persévérance",
            message: "Chaque session te rapproche de tes objectifs",
            color: .pink
        )
    ]
    
    var body: some View {
        VStack(spacing: 32) { // Plus d'espacement entre sections
            // Tips carousel plus aéré
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conseils du Jour")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Pour améliorer ta concentration")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Indicateurs plus visibles
                    HStack(spacing: 6) {
                        ForEach(0..<motivationalTips.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentTipIndex ? .white : .white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentTipIndex)
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Tip card
                TabView(selection: $currentTipIndex) {
                    ForEach(0..<motivationalTips.count, id: \.self) { index in
                        MotivationalTipCard(tip: motivationalTips[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 140) // Hauteur légèrement augmentée
                .onAppear {
                    startAutoRotation()
                }
            }
            
            // Quick start inline buttons
            VStack(spacing: 16) {
                HStack {
                    Text("Démarrage Rapide")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // Boutons en grille 2x2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    InlineQuickButton(
                        title: "15min",
                        icon: "bolt.fill",
                        color: .yellow,
                        action: { startQuickSession(minutes: 15) }
                    )
                    
                    InlineQuickButton(
                        title: "25min",
                        icon: "timer",
                        color: .blue,
                        action: { startQuickSession(minutes: 25) }
                    )
                    
                    InlineQuickButton(
                        title: "60min",
                        icon: "brain.head.profile",
                        color: .purple,
                        action: { startQuickSession(minutes: 60) }
                    )
                    
                    InlineQuickButton(
                        title: "90min",
                        icon: "infinity",
                        color: .indigo,
                        action: { startQuickSession(minutes: 90) }
                    )
                }
                .padding(.horizontal, 24)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentTipIndex = (currentTipIndex + 1) % motivationalTips.count
            }
        }
    }
    
    private func startQuickSession(minutes: Int) {
        print("🚀 [MOTIVATION] Démarrage session rapide: \(minutes) minutes")
        let duration = TimeInterval(minutes * 60)
        zenloopManager.startQuickChallenge(duration: duration)
    }
}

struct MotivationalTip {
    let icon: String
    let title: String
    let message: String
    let color: Color
}

struct MotivationalTipCard: View {
    let tip: MotivationalTip
    
    var body: some View {
        HStack(spacing: 20) { // Plus d'espacement
            // Icône plus proéminente
            Image(systemName: tip.icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(tip.color)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [tip.color.opacity(0.3), tip.color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(tip.color.opacity(0.4), lineWidth: 1)
                )
            
            // Contenu plus aéré
            VStack(alignment: .leading, spacing: 8) {
                Text(tip.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(tip.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(24) // Plus de padding
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Inline Quick Button

struct InlineQuickButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Feedback haptique
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? 0.1 : 0.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct QuickStartCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) { // Plus d'espacement vertical
                // Icône plus grande et plus attractive
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
                
                // Texte plus lisible
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 110, height: 100) // Dimensions plus généreuses
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    MotivationSection(showContent: true, zenloopManager: ZenloopManager.shared)
        .background(Color.black)
}