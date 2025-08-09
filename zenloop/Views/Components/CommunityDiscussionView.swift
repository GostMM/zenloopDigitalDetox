//
//  CommunityDiscussionView.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import SwiftUI

struct CommunityDiscussionView: View {
    let challenge: CommunityChallenge
    @ObservedObject var communityManager: CommunityManager
    @State private var messages: [CommunityMessage] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var replyingTo: CommunityMessage?
    @State private var showingEmojiPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header du chat
            ChatHeader(
                challenge: challenge,
                participantCount: challenge.participantCount
            )
            
            // Liste des messages
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty && !isLoading {
                        // État vide temporaire
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Aucun message pour le moment")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Soyez le premier à écrire !")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 12) {
                            // Messages groupés par utilisateur
                            ForEach(groupedMessages, id: \.first?.id) { messageGroup in
                                MessageGroupView(
                                    messages: messageGroup,
                                    currentUserId: communityManager.currentUserId,
                                    onLike: { messageId in
                                        likeMessage(messageId)
                                    },
                                    onReply: { message in
                                        replyingTo = message
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll vers le bas lors de nouveaux messages
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input de message
            MessageInputView(
                messageText: $newMessageText,
                replyingTo: $replyingTo,
                onSend: { text in
                    sendMessage(text)
                },
                onEmojiTap: {
                    showingEmojiPicker = true
                }
            )
        }
        .background(Color.black.opacity(0.95))
        .onAppear {
            // Démarrer l'écoute temps réel des messages Firebase
            communityManager.startListeningToMessages(for: challenge.id)
            // Écouter les notifications de nouveaux messages
            setupMessageNotifications()
            
            // Firebase va charger les messages automatiquement
        }
        .onDisappear {
            // Arrêter l'écoute quand on quitte la vue
            communityManager.stopListeningToMessages(for: challenge.id)
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(onEmojiSelected: { emoji in
                newMessageText += emoji
                showingEmojiPicker = false
            })
        }
    }
    
    private var groupedMessages: [[CommunityMessage]] {
        var groups: [[CommunityMessage]] = []
        var currentGroup: [CommunityMessage] = []
        var lastUserId: String = ""
        var lastTime: Date = Date.distantPast
        
        for message in messages {
            let timeDifference = message.timestamp.timeIntervalSince(lastTime)
            let shouldGroup = message.userId == lastUserId && timeDifference < 300 // 5 minutes
            
            if shouldGroup && !currentGroup.isEmpty {
                currentGroup.append(message)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [message]
            }
            
            lastUserId = message.userId
            lastTime = message.timestamp
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func setupMessageNotifications() {
        // Écouter les notifications de nouveaux messages venant de Firebase
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CommunityMessagesUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            print("📢 [VIEW] Received notification for messages update")
            
            guard let userInfo = notification.userInfo,
                  let challengeId = userInfo["challengeId"] as? String,
                  let newMessages = userInfo["messages"] as? [CommunityMessage],
                  challengeId == challenge.id else { 
                print("❌ [VIEW] Notification data invalid or wrong challenge")
                return 
            }
            
            print("✅ [VIEW] Updating UI with \(newMessages.count) messages")
            
            // Mettre à jour les messages avec animation
            withAnimation(.easeInOut(duration: 0.3)) {
                messages = newMessages
            }
        }
        
        // Commencer avec une liste vide - Firebase va la remplir
        messages = []
    }
    
    private func generateMockMessages() -> [CommunityMessage] {
        let mockUsernames = ["ZenWolf42", "CalmRiver15", "WiseDragon88", "PeacefulEagle33", "BrightLotus67"]
        let mockMessages = [
            "Salut tout le monde ! Qui est prêt pour ce défi ? 💪",
            "J'ai configuré mon blocage pour toutes les apps d'IA, c'est parti !",
            "Première fois que je fais ça, des conseils ?",
            "@ZenWolf42 Commence par bloquer les plus addictives en premier",
            "Déjà 2h sans ChatGPT, je sens la différence !",
            "Quelqu'un d'autre trouve ça difficile ? 😅",
            "Normal au début, ça devient plus facile après",
            "L'objectif c'est de reprendre le contrôle, pas de se punir",
            "Excellente mentalité ! 👏",
            "6h de faites, je me sens plus créatif bizarrement",
            "Pareil ! Mon cerveau cherche d'autres solutions",
            "C'est exactement le but du défi 🎯"
        ]
        
        var messages: [CommunityMessage] = []
        let startTime = Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
        
        for (index, content) in mockMessages.enumerated() {
            let username = mockUsernames.randomElement() ?? "Anonymous"
            let userId = "user_\(username)"
            let timestamp = Calendar.current.date(byAdding: .minute, value: index * 15, to: startTime) ?? Date()
            
            let message = CommunityMessage(
                id: "msg_\(index)",
                userId: userId,
                username: username,
                content: content,
                timestamp: timestamp,
                challengeId: challenge.id,
                likes: Int.random(in: 0...8),
                replies: []
            )
            messages.append(message)
        }
        
        return messages
    }
    
    private func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Envoyer directement à Firebase - la synchronisation temps réel mettra à jour l'UI
        communityManager.sendMessage(text.trimmingCharacters(in: .whitespacesAndNewlines), to: challenge.id)
        
        // Reset de l'interface
        newMessageText = ""
        replyingTo = nil
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func likeMessage(_ messageId: String) {
        // Envoyer directement à Firebase - la synchronisation temps réel mettra à jour l'UI
        communityManager.likeMessage(messageId)
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
}

// MARK: - Chat Header

struct ChatHeader: View {
    let challenge: CommunityChallenge
    let participantCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discussion")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Text("\(participantCount) participants actifs")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Badge du défi
                HStack(spacing: 6) {
                    Image(systemName: challenge.category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(challenge.category.color)
                    
                    Text(challenge.title)
                        .font(.system(size: 12, weight: .semibold))
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(.white.opacity(0.1))
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Message Group View

struct MessageGroupView: View {
    let messages: [CommunityMessage]
    let currentUserId: String
    let onLike: (String) -> Void
    let onReply: (CommunityMessage) -> Void
    
    private var isOwnMessage: Bool {
        messages.first?.userId == currentUserId
    }
    
    private var username: String {
        messages.first?.username ?? "Anonymous"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isOwnMessage {
                // Avatar de l'utilisateur
                UserAvatarView(username: username)
            }
            
            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 6) {
                // Nom d'utilisateur et timestamp
                if !isOwnMessage {
                    HStack(spacing: 8) {
                        Text(username)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(messages.first?.relativeTime ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Messages du groupe
                ForEach(messages, id: \.id) { message in
                    MessageBubbleView(
                        message: message,
                        isOwnMessage: isOwnMessage,
                        onLike: onLike,
                        onReply: onReply
                    )
                }
            }
            
            if isOwnMessage {
                UserAvatarView(username: username)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOwnMessage ? .trailing : .leading)
    }
}

// MARK: - User Avatar View

struct UserAvatarView: View {
    let username: String
    
    private var initials: String {
        String(username.prefix(2)).uppercased()
    }
    
    private var avatarColor: Color {
        // Générer une couleur basée sur le nom d'utilisateur
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo, .mint]
        let hash = abs(username.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatarColor.opacity(0.8), avatarColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            Text(initials)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: CommunityMessage
    let isOwnMessage: Bool
    let onLike: (String) -> Void
    let onReply: (CommunityMessage) -> Void
    @State private var showingActions = false
    
    var body: some View {
        HStack(spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 8) {
                // Bulle de message
                MessageContentView(
                    message: message,
                    isOwnMessage: isOwnMessage
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingActions.toggle()
                    }
                }
                
                // Actions (likes, réponse)
                if showingActions {
                    MessageActionsView(
                        message: message,
                        isOwnMessage: isOwnMessage,
                        onLike: onLike,
                        onReply: onReply
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            
            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingActions)
    }
}

// MARK: - Message Content View

struct MessageContentView: View {
    let message: CommunityMessage
    let isOwnMessage: Bool
    
    var body: some View {
        VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
            // Contenu du message
            Text(message.content)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isOwnMessage ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isOwnMessage ?
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                    in: RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isOwnMessage ? .clear : .white.opacity(0.1),
                            lineWidth: 1
                        )
                )
            
            // Timestamp pour messages propres
            if isOwnMessage {
                Text(message.relativeTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Message Actions View

struct MessageActionsView: View {
    let message: CommunityMessage
    let isOwnMessage: Bool
    let onLike: (String) -> Void
    let onReply: (CommunityMessage) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if !isOwnMessage {
                // Bouton Like
                Button(action: {
                    onLike(message.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: message.likes > 0 ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        
                        if message.likes > 0 {
                            Text("\(message.likes)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1), in: Capsule())
                }
                
                // Bouton Répondre
                Button(action: {
                    onReply(message)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Répondre")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            
            // Afficher les likes sur ses propres messages
            if isOwnMessage && message.likes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                    
                    Text("\(message.likes)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.1), in: Capsule())
            }
        }
    }
}

#Preview {
    CommunityDiscussionView(
        challenge: CommunityChallenge(
            id: "test",
            title: "Journée sans IA",
            description: "Test description",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            participantCount: 42,
            maxParticipants: 100,
            suggestedApps: ["ChatGPT", "Claude"],
            category: .productivity,
            difficulty: .medium,
            reward: CommunityReward(points: 100, badge: "🤖", title: "Anti-IA Pioneer")
        ),
        communityManager: CommunityManager.shared
    )
}