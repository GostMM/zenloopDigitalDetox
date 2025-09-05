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
    @State private var timer: Timer?
    
    private let motivationalTips = [
        MotivationalTip(
            icon: "brain.head.profile",
            title: String(localized: "tired_of_endless_scrolling"),
            message: String(localized: "25_min_focus_better_than_2h_lost"),
            color: .blue
        ),
        MotivationalTip(
            icon: "target",
            title: String(localized: "tell_yourself_why"),
            message: String(localized: "before_starting_remember_why_important"),
            color: .green
        ),
        MotivationalTip(
            icon: "moon.stars",
            title: String(localized: "breathe_a_little"),
            message: String(localized: "5_min_break_every_25_brain_thanks"),
            color: .purple
        ),
        MotivationalTip(
            icon: "leaf.fill",
            title: String(localized: "your_cocoon_of_calm"),
            message: String(localized: "tidy_desk_turn_off_notifs_create_serenity"),
            color: .mint
        ),
        MotivationalTip(
            icon: "heart.fill",
            title: String(localized: "go_easy"),
            message: String(localized: "every_small_step_counts_no_need_perfect"),
            color: .pink
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header homogénéisé avec les autres sections
            HStack {
                HStack(spacing: 4) {
                    // Icône pour Motivation
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.pink)
                        .frame(width: 40, height: 40)
                        .background(.pink.opacity(0.15), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "motivation"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(String(localized: "a_little_word_for_you"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Indicateurs compacts
                HStack(spacing: 4) {
                    ForEach(0..<motivationalTips.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentTipIndex ? .pink : .white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentTipIndex)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 20)
            
            // Tip card
            TabView(selection: $currentTipIndex) {
                ForEach(0..<motivationalTips.count, id: \.self) { index in
                    MotivationalTipCard(tip: motivationalTips[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 120)
            .onAppear {
                startAutoRotation()
            }
            .onDisappear {
                stopAutoRotation()
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
    
    private func startAutoRotation() {
        // Arrêter le timer existant s'il y en a un
        stopAutoRotation()
        
        // Créer un nouveau timer avec une cadence plus lente et stable
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                currentTipIndex = (currentTipIndex + 1) % motivationalTips.count
            }
        }
    }
    
    private func stopAutoRotation() {
        timer?.invalidate()
        timer = nil
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
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 20)
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