//
//  RetentionModal.swift
//  zenloop
//
//  Created by Claude on 03/09/2025.
//

import SwiftUI

struct RetentionModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var zenloopManager: ZenloopManager
    @State private var showContinueButton = false
    @State private var animateEmoji = false
    
    var body: some View {
        ZStack {
            // Background with blur effect
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Main modal content
            VStack(spacing: 24) {
                // Animated emoji
                Text(zenloopManager.currentState == .active ? "🛟" : "💚")
                    .font(.system(size: 80))
                    .scaleEffect(animateEmoji ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateEmoji)
                
                // Dynamic title based on session state
                Text(retentionTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Dynamic message based on session state
                VStack(spacing: 16) {
                    Text(retentionMessage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    if zenloopManager.currentState == .active {
                        // Show session progress
                        sessionProgressView
                    } else {
                        // Show app benefits
                        benefitsView
                    }
                }
                .padding(.horizontal, 8)
                
                // Action buttons
                actionButtons
                
            }
            .padding(32)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 20)
            .scaleEffect(showContinueButton ? 1.0 : 0.9)
            .opacity(showContinueButton ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContinueButton = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateEmoji = true
            }
        }
    }
    
    // MARK: - Dynamic Content
    
    private var retentionTitle: String {
        if zenloopManager.currentState == .active {
            return String(localized: "retention_modal_title_active_session", comment: "Retention modal title when session is active")
        } else {
            return String(localized: "retention_modal_title_no_session", comment: "Retention modal title when no session")
        }
    }
    
    private var retentionMessage: String {
        if zenloopManager.currentState == .active {
            return String(localized: "retention_modal_message_active_session", comment: "Retention modal message when session is active")
        } else {
            return String(localized: "retention_modal_message_no_session", comment: "Retention modal message when no session")
        }
    }
    
    // MARK: - Session Progress View
    
    private var sessionProgressView: some View {
        VStack(spacing: 12) {
            if let challenge = zenloopManager.currentChallenge {
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "retention_modal_current_session", comment: "Current session label") + ": \(challenge.title)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(zenloopManager.currentTimeRemaining)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    ProgressView(value: zenloopManager.currentProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.3))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.green.opacity(0.3), lineWidth: 1)
                        }
                }
                
                Text(String(localized: "retention_modal_motivation", comment: "Motivational message"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Benefits View
    
    private var benefitsView: some View {
        VStack(spacing: 12) {
            benefitRow(
                icon: "📊", 
                title: String(localized: "retention_benefit_1_title", comment: "First benefit title"), 
                description: String(localized: "retention_benefit_1_description", comment: "First benefit description")
            )
            benefitRow(
                icon: "🎯", 
                title: String(localized: "retention_benefit_2_title", comment: "Second benefit title"), 
                description: String(localized: "retention_benefit_2_description", comment: "Second benefit description")
            )
            benefitRow(
                icon: "🏆", 
                title: String(localized: "retention_benefit_3_title", comment: "Third benefit title"), 
                description: String(localized: "retention_benefit_3_description", comment: "Third benefit description")
            )
            benefitRow(
                icon: "⚡", 
                title: String(localized: "retention_benefit_4_title", comment: "Fourth benefit title"), 
                description: String(localized: "retention_benefit_4_description", comment: "Fourth benefit description")
            )
        }
    }
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if zenloopManager.currentState == .active {
                // Session active - show stop/continue options
                Button {
                    // Stop session and dismiss
                    zenloopManager.stopCurrentChallenge()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text(String(localized: "retention_button_stop_session", comment: "Stop session button"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.red.opacity(0.2))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.red.opacity(0.5), lineWidth: 1)
                            }
                    }
                }
                
                Button {
                    // Continue session
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text(String(localized: "retention_button_keep_going", comment: "Keep going button"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.green)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.green.opacity(0.7), lineWidth: 1)
                            }
                    }
                }
            } else {
                // No session - show keep app options
                Button {
                    // Start a quick focus session as incentive
                    startMotivationalSession()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "bolt.circle.fill")
                        Text(String(localized: "retention_button_try_quick_focus", comment: "Try quick focus button"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.blue.opacity(0.7), lineWidth: 1)
                            }
                    }
                }
                
                Button {
                    // Just dismiss - they decided to keep it
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                        Text(String(localized: "retention_button_keep_app", comment: "Keep app button"))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.green)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.green.opacity(0.7), lineWidth: 1)
                            }
                    }
                }
            }
            
            // Always show dismiss option
            Button {
                dismiss()
            } label: {
                Text(String(localized: "retention_button_maybe_later", comment: "Maybe later button"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func startMotivationalSession() {
        // Start a short 5-minute motivational session
        let motivationalChallenge = ZenloopChallenge(
            id: "retention-motivation-\(UUID().uuidString)",
            title: "Quick Focus Boost",
            description: "A short 5-minute session to show you how great Zenloop is!",
            duration: 5 * 60, // 5 minutes
            difficulty: .easy,
            startTime: Date(),
            isActive: true
        )
        
        // Start the session
        zenloopManager.startSavedCustomChallenge(motivationalChallenge)
        
        // Send positive feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}