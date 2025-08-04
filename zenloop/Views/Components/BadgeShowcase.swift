//
//  BadgeShowcase.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct BadgeShowcase: View {
    @ObservedObject var badgeManager: BadgeManager
    @State private var showAllBadges = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tes Badges")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(badgeManager.getUnlockedBadges().count)/\(badgeManager.getAllBadges().count) débloqués")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button("Voir tout") {
                    showAllBadges = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cyan)
            }
            
            // Badges récents/importants
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredBadges, id: \.id) { badge in
                        BadgeCard(badge: badge, size: .medium)
                    }
                    
                    if featuredBadges.count < 3 {
                        ForEach(nextBadgesToUnlock.prefix(3 - featuredBadges.count), id: \.id) { badge in
                            BadgeCard(badge: badge, size: .medium, isLocked: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .sheet(isPresented: $showAllBadges) {
            BadgeCollectionView(badgeManager: badgeManager)
        }
    }
    
    private var featuredBadges: [Badge] {
        let unlocked = badgeManager.getUnlockedBadges()
        
        // Prioriser les badges rares/épiques/légendaires
        let sortedUnlocked = unlocked.sorted { badge1, badge2 in
            if badge1.rarity != badge2.rarity {
                return badge1.rarity.rawValue > badge2.rarity.rawValue
            }
            return (badge1.unlockedAt ?? Date.distantPast) > (badge2.unlockedAt ?? Date.distantPast)
        }
        
        return Array(sortedUnlocked.prefix(3))
    }
    
    private var nextBadgesToUnlock: [Badge] {
        let unlockedIds = badgeManager.unlockedBadges
        return badgeManager.getAllBadges().filter { !unlockedIds.contains($0.id) }
    }
}

struct BadgeCard: View {
    let badge: Badge
    let size: BadgeSize
    let isLocked: Bool
    
    init(badge: Badge, size: BadgeSize = .medium, isLocked: Bool = false) {
        self.badge = badge
        self.size = size
        self.isLocked = isLocked
    }
    
    enum BadgeSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 80
            case .large: return 100
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 40
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Badge icon
            ZStack {
                Circle()
                    .fill(isLocked ? 
                        LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing) : 
                        badge.color.gradient)
                    .frame(width: size.dimension, height: size.dimension)
                    .overlay(
                        Circle()
                            .stroke(
                                isLocked ? Color.gray.opacity(0.5) : Color.white.opacity(0.3),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isLocked ? Color.clear : badge.color.color.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size.iconSize * 0.6, weight: .medium))
                        .foregroundColor(Color.gray)
                } else {
                    Image(systemName: badge.icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                        .foregroundColor(Color.white)
                }
                
                // Animation pour les badges légendaires
                if !isLocked && badge.rarity == .legendary {
                    Circle()
                        .stroke(badge.color.color, lineWidth: 2)
                        .frame(width: size.dimension + 10, height: size.dimension + 10)
                        .opacity(0.6)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
                }
            }
            
            // Badge info
            VStack(spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isLocked ? Color.gray : Color.white)
                    .lineLimit(1)
                
                if size != .small {
                    Text(badge.rarity.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isLocked ? Color.gray.opacity(0.7) : badge.color.color)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: size.dimension + 20)
    }
}

struct BadgeCollectionView: View {
    @ObservedObject var badgeManager: BadgeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: BadgeFilter = .all
    
    enum BadgeFilter: String, CaseIterable {
        case all = "Tous"
        case unlocked = "Débloqués" 
        case locked = "Verrouillés"
        case rare = "Rares+"
        
        func shouldShow(badge: Badge, isUnlocked: Bool) -> Bool {
            switch self {
            case .all: return true
            case .unlocked: return isUnlocked
            case .locked: return !isUnlocked
            case .rare: return badge.rarity == .rare || badge.rarity == .epic || badge.rarity == .legendary
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filtres
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BadgeFilter.allCases, id: \.rawValue) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                
                // Collection de badges
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                        ForEach(filteredBadges, id: \.id) { badge in
                            let isUnlocked = badgeManager.unlockedBadges.contains(badge.id)
                            
                            VStack(spacing: 12) {
                                BadgeCard(badge: badge, size: .large, isLocked: !isUnlocked)
                                
                                VStack(spacing: 4) {
                                    Text(badge.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    if !isUnlocked {
                                        Text(badge.requirement.description)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.orange)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isUnlocked ? badge.color.color.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Collection de Badges")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Fermer") { dismiss() })
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var filteredBadges: [Badge] {
        badgeManager.getAllBadges().filter { badge in
            let isUnlocked = badgeManager.unlockedBadges.contains(badge.id)
            return selectedFilter.shouldShow(badge: badge, isUnlocked: isUnlocked)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? .blue : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(.blue, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    BadgeShowcase(badgeManager: BadgeManager.shared)
        .background(Color.black)
}