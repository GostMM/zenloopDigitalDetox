//
//  MessageInputView.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    @Binding var replyingTo: CommunityMessage?
    let onSend: (String) -> Void
    let onEmojiTap: () -> Void
    
    @State private var isExpanded = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicateur de réponse
            if let replyingTo = replyingTo {
                ReplyIndicatorView(
                    message: replyingTo,
                    onCancel: {
                        self.replyingTo = nil
                    }
                )
            }
            
            // Zone d'input
            HStack(alignment: .bottom, spacing: 12) {
                // Bouton emoji
                Button(action: onEmojiTap) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1), in: Circle())
                }
                
                // Champ de texte
                HStack(spacing: 8) {
                    TextField("Écris ton message...", text: $messageText, axis: .vertical)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...6)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .onSubmit {
                            if canSend {
                                sendMessage()
                            }
                        }
                }
                
                // Bouton d'envoi
                Button(action: sendMessage) {
                    Image(systemName: canSend ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(canSend ? .blue : .white.opacity(0.4))
                        .scaleEffect(canSend ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.white.opacity(0.1)),
                alignment: .top
            )
        }
    }
    
    private func sendMessage() {
        guard canSend else { return }
        
        let message = messageText
        onSend(message)
        
        // Reset
        messageText = ""
        replyingTo = nil
        isTextFieldFocused = false
    }
}

// MARK: - Reply Indicator View

struct ReplyIndicatorView: View {
    let message: CommunityMessage
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Ligne de réponse
            VStack {
                Rectangle()
                    .fill(.blue)
                    .frame(width: 3)
                    .cornerRadius(1.5)
            }
            .frame(height: 40)
            
            // Contenu de la réponse
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Répondre à")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text(message.username)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Text(message.content)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.blue.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Emoji Picker View

struct EmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let emojiCategories: [EmojiCategory] = [
        EmojiCategory(
            title: "Smileys",
            icon: "😊",
            emojis: ["😊", "😂", "🤣", "😍", "🥰", "😘", "😋", "😎", "🤔", "😅", "😇", "🙂", "😉", "😌", "😏", "😴", "🤤", "😪", "🥱", "😵", "🤯", "🥳", "😎"]
        ),
        EmojiCategory(
            title: "Gestes",
            icon: "👍",
            emojis: ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐", "🖖", "👋", "🤗", "🙏", "✍️", "💅", "🤳", "💪"]
        ),
        EmojiCategory(
            title: "Cœurs",
            icon: "❤️",
            emojis: ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟"]
        ),
        EmojiCategory(
            title: "Activités",
            icon: "⚽",
            emojis: ["⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🎱", "🪀", "🏓", "🏸", "🥅", "🏒", "🏑", "🥍", "🏏", "🪃", "🥊", "🥋", "⛳", "🏹", "🎣", "🤿", "🎿"]
        ),
        EmojiCategory(
            title: "Objets",
            icon: "📱",
            emojis: ["📱", "💻", "🖥", "🖨", "⌚", "📷", "📹", "🎥", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙", "🎚", "🎛", "🧭", "⏱", "⏰", "🕰", "⏳", "⌛", "📡"]
        ),
        EmojiCategory(
            title: "Nature",
            icon: "🌳",
            emojis: ["🌲", "🌳", "🌴", "🌵", "🌶", "🍄", "🌾", "💐", "🌷", "🌹", "🥀", "🌺", "🌸", "🌼", "🌻", "🌞", "🌝", "🌛", "🌜", "🌚", "🌕", "🌖", "🌗", "🌘"]
        )
    ]
    
    @State private var selectedCategory = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sélecteur de catégories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<emojiCategories.count, id: \.self) { index in
                            Button(action: {
                                selectedCategory = index
                            }) {
                                Text(emojiCategories[index].icon)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedCategory == index ?
                                            Color.blue.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedCategory == index ? .blue : .clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                
                Divider()
                    .background(.white.opacity(0.1))
                
                // Grille d'emojis
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(emojiCategories[selectedCategory].emojis, id: \.self) { emoji in
                            Button(action: {
                                onEmojiSelected(emoji)
                            }) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(Color.clear)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .navigationTitle("Émojis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Emoji Category Model

struct EmojiCategory {
    let title: String
    let icon: String
    let emojis: [String]
}

// ScaleButtonStyle est défini dans CompactButton.swift

#Preview {
    VStack {
        Spacer()
        MessageInputView(
            messageText: .constant(""),
            replyingTo: .constant(nil),
            onSend: { _ in },
            onEmojiTap: { }
        )
    }
    .background(Color.black)
}