//
//  CommunityDiscussionsSection.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import SwiftUI

struct CommunityDiscussionsMainSection: View {
    @ObservedObject var communityManager: CommunityManager
    let showContent: Bool
    @State private var selectedDiscussion: CommunityChallenge?
    @State private var showingFullChat = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header de section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discussions Actives")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Échange avec la communauté sur les défis en cours")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Badge des discussions actives
                if !communityManager.activeChallenges.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text("\(communityManager.activeChallenges.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.2), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.blue.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            
            // Liste des discussions
            if communityManager.activeChallenges.isEmpty {
                EmptyCommunityDiscussionsView()
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(communityManager.activeChallenges) { challenge in
                        DiscussionPreviewCard(
                            challenge: challenge,
                            onTap: {
                                print("🗣️ [DISCUSSION] Opening chat for challenge: \(challenge.title)")
                                selectedDiscussion = challenge
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingFullChat = true
                                }
                            }
                        )
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
        .sheet(isPresented: $showingFullChat) {
            if let challenge = selectedDiscussion {
                NavigationView {
                    CommunityDiscussionView(
                        challenge: challenge,
                        communityManager: communityManager
                    )
                    .navigationTitle("Discussion")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Fermer") {
                                showingFullChat = false
                            }
                            .foregroundColor(.white)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 6) {
                                Image(systemName: challenge.category.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(challenge.category.color)
                                
                                Text(challenge.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(challenge.category.color)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Discussion Preview Card

struct DiscussionPreviewCard: View {
    let challenge: CommunityChallenge
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var recentMessages: [PreviewMessage] = []
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header de la discussion
                HStack {
                    // Badge du défi
                    HStack(spacing: 6) {
                        Image(systemName: challenge.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(challenge.category.color)
                        
                        Text(challenge.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(challenge.category.color)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(challenge.category.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(challenge.category.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                    
                    // Indicateur d'activité
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                        
                        Text("\(challenge.participantCount) actifs")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                
                // Aperçu des messages récents
                if !recentMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Messages récents:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                        }
                        
                        ForEach(recentMessages.prefix(3), id: \.id) { message in
                            DiscussionMessagePreview(message: message)
                        }
                    }
                }
                
                // Call to action
                HStack {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("Rejoindre la discussion")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
            .shadow(color: challenge.category.color.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            loadRecentMessages()
        }
    }
    
    private func loadRecentMessages() {
        // Simuler des messages récents
        recentMessages = [
            PreviewMessage(
                id: "msg1",
                username: "ZenWolf42",
                content: "6h sans IA, ça fait du bien au cerveau ! 💪",
                timestamp: Date().addingTimeInterval(-300)
            ),
            PreviewMessage(
                id: "msg2", 
                username: "CalmRiver15",
                content: "Pareil ! Je me sens plus créatif",
                timestamp: Date().addingTimeInterval(-180)
            ),
            PreviewMessage(
                id: "msg3",
                username: "PeacefulEagle33",
                content: "Des conseils pour tenir toute la journée ?",
                timestamp: Date().addingTimeInterval(-60)
            )
        ]
    }
}

// MARK: - Discussion Message Preview

struct DiscussionMessagePreview: View {
    let message: PreviewMessage
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor.opacity(0.8), avatarColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                
                Text(String(message.username.prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Contenu du message
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(message.username)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(message.relativeTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                
                Text(message.content)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]
        let hash = abs(message.username.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Preview Message Model

struct PreviewMessage: Identifiable {
    let id: String
    let username: String
    let content: String
    let timestamp: Date
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Empty State

struct EmptyCommunityDiscussionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Aucune discussion active")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Les discussions apparaîtront ici quand des défis communautaires seront lancés. Participe à un défi pour échanger avec les autres !")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    CommunityDiscussionsMainSection(
        communityManager: CommunityManager.shared,
        showContent: true
    )
    .background(Color.black)
}

*/