//
//  CommunityView.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import SwiftUI
import FamilyControls

struct CommunityView: View {
    @StateObject private var communityManager = CommunityManager.shared
    @State private var showContent = false
    @State private var selectedTab: CommunityTab = .challenges
    
    enum CommunityTab: CaseIterable {
        case challenges, discussions
        
        var title: String {
            switch self {
            case .challenges: return "Défis"
            case .discussions: return "Discussions" 
            }
        }
        
        var icon: String {
            switch self {
            case .challenges: return "target"
            case .discussions: return "bubble.left.and.bubble.right.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .challenges: return .orange
            case .discussions: return .blue
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background moderne avec dégradé communautaire
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.12),
                        Color(red: 0.06, green: 0.03, blue: 0.15),
                        Color(red: 0.08, green: 0.02, blue: 0.18),
                        Color(red: 0.04, green: 0.08, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Overlay avec effet communautaire
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .orange.opacity(0.1),
                                .blue.opacity(0.05),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header avec profil utilisateur
                CommunityHeader(
                    username: communityManager.currentUsername,
                    showContent: showContent
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Navigation par onglets
                CommunityTabBar(
                    selectedTab: $selectedTab,
                    showContent: showContent
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Contenu selon l'onglet sélectionné
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case .challenges:
                            CommunityChallengesSection(
                                communityManager: communityManager,
                                showContent: showContent
                            )
                        case .discussions:
                            CommunityDiscussionsMainSection(
                                communityManager: communityManager,
                                showContent: showContent
                            )
                        }
                        
                        // Espace de respiration en bas
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                showContent = true
            }
            communityManager.loadCommunityData()
            
            // Générer automatiquement les premiers défis si aucun n'existe
            Task {
                await communityManager.generateInitialChallengesIfNeeded()
            }
        }
    }
}

// MARK: - Community Header

struct CommunityHeader: View {
    let username: String
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Communauté")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Ensemble vers plus de sérénité")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Profil utilisateur
                UserProfileBadge(username: username)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
}

// MARK: - User Profile Badge

struct UserProfileBadge: View {
    let username: String
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar généré
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(String(username.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Membre")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Community Tab Bar

struct CommunityTabBar: View {
    @Binding var selectedTab: CommunityView.CommunityTab
    let showContent: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CommunityView.CommunityTab.allCases, id: \.self) { tab in
                CommunityTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
}

// MARK: - Community Tab Button

struct CommunityTabButton: View {
    let tab: CommunityView.CommunityTab
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? tab.color : .white.opacity(0.7))
                
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                isSelected ? 
                    AnyView(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tab.color.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(tab.color.opacity(0.4), lineWidth: 1)
                            )
                    ) :
                    AnyView(Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Placeholder Sections (supprimées car remplacées par les vraies sections)

#Preview {
    CommunityView()
}

*/