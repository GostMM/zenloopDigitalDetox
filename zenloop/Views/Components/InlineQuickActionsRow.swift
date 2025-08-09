//
//  InlineQuickActionsRow.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 08/08/2025.
//

import SwiftUI

struct InlineQuickActionsRow: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    private let quickActions = [
        QuickAction(
            id: "focus",
            icon: "brain.head.profile",
            title: "Zone de flow",
            subtitle: "1h pour toi",
            color: .indigo,
            duration: 60 * 60
        ),
        QuickAction(
            id: "study",
            icon: "book.fill",
            title: "Apprendre sereinement",
            subtitle: "45min",
            color: .blue,
            duration: 45 * 60
        ),
        QuickAction(
            id: "creative",
            icon: "paintbrush.fill",
            title: "Laisser libre cours",
            subtitle: "90min créatif",
            color: .purple,
            duration: 90 * 60
        ),
        QuickAction(
            id: "meditation",
            icon: "leaf.fill",
            title: "Moment de calme",
            subtitle: "20min zen",
            color: .green,
            duration: 20 * 60
        ),
        QuickAction(
            id: "work",
            icon: "briefcase.fill",
            title: "Productivité douce",
            subtitle: "2h concentré",
            color: .orange,
            duration: 120 * 60
        ),
        QuickAction(
            id: "pomodoro",
            icon: "timer",
            title: "Petit sprint",
            subtitle: "25min intense",
            color: .red,
            duration: 25 * 60
        )
    ]
    
    var body: some View {
        // Scroll horizontal des actions (directement sans card)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickActions) { action in
                    InlineQuickActionButton(
                        action: action,
                        onTap: {
                            startQuickAction(action)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
    
    private func startQuickAction(_ action: QuickAction) {
        print("🚀 [INLINE_ACTIONS] Démarrage: \(action.title) - \(action.subtitle)")
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Démarrer avec les apps déjà sélectionnées
        let difficulty: DifficultyLevel = action.duration <= 1800 ? .easy : action.duration <= 3600 ? .medium : .hard
        
        zenloopManager.startCustomChallenge(
            title: "\(action.title) - \(action.subtitle)",
            duration: TimeInterval(action.duration),
            difficulty: difficulty,
            apps: zenloopManager.getAppsSelection()
        )
    }
}

struct QuickAction: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let duration: Int
}

struct InlineQuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            // Format horizontal inline [ 🧠 Focus 60min]
            HStack(spacing: 8) {
                // Icône
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(action.color)
                
                // Titre
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Durée
                Text(action.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(action.color.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    InlineQuickActionsRow(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}