//
//  CategoryChallengesRow.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import FamilyControls

struct CategoryChallengesRow: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    @State private var showingConfiguration = false
    
    var body: some View {
        // Interface aérée avec layout multi-lignes
        Button(action: {
            showingConfiguration = true
        }) {
            VStack(spacing: 16) {
                // Première ligne : Titre et Status
                HStack(spacing: 12) {
                    // Icône avec indicateur de statut
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .cyan.opacity(0.3),
                                        .cyan.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: categoryManager.configuredCategories.isEmpty ? "target" : "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(categoryManager.configuredCategories.isEmpty ? .cyan : .green)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.cyan.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Titre et status
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Défis Catégories")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Status badge
                        HStack(spacing: 4) {
                            if categoryManager.configuredCategories.isEmpty {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cyan)
                                
                                Text("Tap pour configurer")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.cyan)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text("Prêt à utiliser")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Bouton d'action
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Config")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Deuxième ligne : Statistiques et aperçu
                if !categoryManager.configuredCategories.isEmpty {
                    HStack(spacing: 20) {
                        // Nombre de catégories
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Catégories")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("\(categoryManager.configuredCategories.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Nombre de défis
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Défis")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("\(categoryManager.availableChallenges.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Apps totales
                        HStack(spacing: 6) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apps")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("\(categoryManager.totalConfiguredApps)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Troisième ligne : Aperçu des catégories (si configurées)
                if !categoryManager.configuredCategories.isEmpty {
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.grid.2x2")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Catégories configurées:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Mini aperçu des catégories
                        HStack(spacing: 6) {
                            ForEach(categoryManager.configuredCategories.prefix(4), id: \.id) { category in
                                ZStack {
                                    Circle()
                                        .fill(category.color.color.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: category.icon)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(category.color.color)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(category.color.color.opacity(0.5), lineWidth: 1)
                                )
                            }
                            
                            if categoryManager.configuredCategories.count > 4 {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("+\(categoryManager.configuredCategories.count - 4)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.cyan.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.cyan.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.cyan.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: showContent)
        .sheet(isPresented: $showingConfiguration) {
            NavigationView {
                CategoryChallengesModal(zenloopManager: zenloopManager)
                    .onDisappear {
                        // Forcer le rechargement des données après configuration
                        categoryManager.refreshData()
                    }
            }
        }
        .onAppear {
            print("🔍 [CATEGORY_CHALLENGES] Categories: \(categoryManager.categories.count), Configured: \(categoryManager.configuredCategories.count)")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Configurez vos catégories pour débloquer les défis rapides")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingConfiguration = true
            }) {
                Text("Configurer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Challenges Scroll View
    
    private var challengesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categoryManager.configuredCategories) { category in
                    CategoryChallengeGroup(
                        category: category,
                        challenges: categoryManager.getChallengesForCategory(category.id),
                        onChallengeStart: { challenge in
                            categoryManager.startCategoryChallenge(challenge, zenloopManager: zenloopManager)
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Category Challenges Modal

struct CategoryChallengesModal: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAppSelection = false
    @State private var selectedCategory: AppCategory? = nil
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background moderne avec dégradé IA
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
                
                // Overlay subtil avec image IA
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .purple.opacity(0.1),
                                .cyan.opacity(0.05),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .blue.opacity(0.08),
                                .clear
                            ],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 400
                        )
                    )
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    // Header avec image IA
                    VStack(spacing: 16) {
                        // Image IA moderne
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .purple.opacity(0.3),
                                            .cyan.opacity(0.2),
                                            .blue.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image("image-ia-3")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .clear,
                                                    .purple.opacity(0.3)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.5), .cyan.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 8) {
                            Text("Défis par Catégorie")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            if categoryManager.configuredCategories.isEmpty {
                                Text("Configurez vos catégories pour débloquer les défis rapides")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Choisissez un défi ou configurez de nouvelles catégories")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
                    
                    // Défis disponibles (si configurés)
                    if !categoryManager.configuredCategories.isEmpty {
                        availableChallengesSection
                    }
                    
                    // Configuration des catégories
                    categoriesConfigurationSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationTitle("Défis Catégories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fermer") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .familyActivityPicker(isPresented: $showingAppSelection, selection: $selectedApps)
        .onChange(of: selectedApps) { _, newSelection in
            if let category = selectedCategory {
                categoryManager.updateCategorySelection(category.id, selection: newSelection)
                selectedCategory = nil
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Available Challenges Section (Organized by Category)
    
    private var availableChallengesSection: some View {
        VStack(spacing: 20) {
            // Header général
            HStack {
                Text("Défis Disponibles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(categoryManager.availableChallenges.count) défis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Défis organisés par catégorie
            LazyVStack(spacing: 16) {
                ForEach(categoryManager.configuredCategories, id: \.id) { category in
                    CategoryChallengeSection(
                        category: category,
                        challenges: categoryManager.getChallengesForCategory(category.id),
                        onChallengeStart: { challenge in
                            categoryManager.startCategoryChallenge(challenge, zenloopManager: zenloopManager)
                            dismiss()
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
    
    // MARK: - Categories Configuration Section
    
    private var categoriesConfigurationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Configuration")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(categoryManager.configuredCategories.count)/\(categoryManager.categories.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            LazyVStack(spacing: 12) {
                ForEach(categoryManager.categories, id: \.id) { category in
                    CompactCategoryConfigCard(
                        category: category,
                        onConfigure: {
                            selectedCategory = category
                            selectedApps = category.selectedApps.toFamilyActivitySelection()
                            showingAppSelection = true
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.cyan.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

// MARK: - Category Challenge Section

struct CategoryChallengeSection: View {
    let category: AppCategory
    let challenges: [CategoryChallenge]
    let onChallengeStart: (CategoryChallenge) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header de la catégorie
            HStack(spacing: 12) {
                // Image IA pour la catégorie
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.color.opacity(0.3),
                                    category.color.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(getImageForCategory())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(category.color.color.opacity(0.1))
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(category.color.color.opacity(0.4), lineWidth: 1.5)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(challenges.count) défis • \(category.selectedAppsCount) apps")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(category.color.color)
                }
                
                Spacer()
                
                // Badge de catégorie
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(category.color.color)
                    
                    Text(categoryShortName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(category.color.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(category.color.color.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(category.color.color.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Défis de cette catégorie en grille
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(challenges.sorted(by: { $0.duration < $1.duration }), id: \.id) { challenge in
                    CompactCategoryDefyButton(
                        challenge: challenge,
                        category: category,
                        onTap: { onChallengeStart(challenge) }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    category.color.color.opacity(0.4),
                                    category.color.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: category.color.color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private var categoryShortName: String {
        switch category.id {
        case "ai_productivity": return "IA"
        case "social_media": return "Social"
        case "games_entertainment": return "Games"
        default: return String(category.name.prefix(5))
        }
    }
    
    private func getImageForCategory() -> String {
        switch category.id {
        case "ai_productivity": return "image-ia-1"
        case "social_media": return "imafe-ia-2"
        case "games_entertainment": return "image-ia-3"
        default: return "image-ia-1"
        }
    }
}

// MARK: - Compact Category Defy Button

struct CompactCategoryDefyButton: View {
    let challenge: CategoryChallenge
    let category: AppCategory
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Indicateur de difficulté
                HStack(spacing: 2) {
                    ForEach(0..<getDifficultyLevel(), id: \.self) { _ in
                        Circle()
                            .fill(category.color.color)
                            .frame(width: 3, height: 3)
                    }
                    ForEach(0..<(3-getDifficultyLevel()), id: \.self) { _ in
                        Circle()
                            .fill(category.color.color.opacity(0.3))
                            .frame(width: 3, height: 3)
                    }
                }
                
                // Titre compact
                Text(challenge.title.replacingOccurrences(of: "0 ", with: ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                
                // Durée
                Text(challenge.formattedDuration)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(category.color.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(category.color.color.opacity(0.15))
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.color.color.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(category.color.color.opacity(0.3), lineWidth: 1)
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
    
    private func getDifficultyLevel() -> Int {
        switch challenge.difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Compact Challenge Button

struct CompactChallengeButton: View {
    let challenge: CategoryChallenge
    let category: AppCategory
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header avec icône de catégorie moderne
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        category.color.color.opacity(0.3),
                                        category.color.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(category.color.color)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(category.color.color.opacity(0.4), lineWidth: 1)
                    )
                    
                    // Indicateur de difficulté
                    HStack(spacing: 2) {
                        ForEach(0..<getDifficultyLevel(), id: \.self) { _ in
                            Circle()
                                .fill(category.color.color)
                                .frame(width: 4, height: 4)
                        }
                        ForEach(0..<(3-getDifficultyLevel()), id: \.self) { _ in
                            Circle()
                                .fill(category.color.color.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                
                // Titre du défi
                Text(challenge.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Durée avec style moderne
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(category.color.color)
                    
                    Text(challenge.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(category.color.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(category.color.color.opacity(0.15))
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        category.color.color.opacity(0.5),
                                        category.color.color.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: category.color.color.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func getDifficultyLevel() -> Int {
        switch challenge.difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Compact Category Config Card

struct CompactCategoryConfigCard: View {
    let category: AppCategory
    let onConfigure: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onConfigure) {
            HStack(spacing: 16) {
                // Image IA pour la catégorie
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.color.opacity(0.3),
                                    category.color.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    // Utiliser différentes images selon la catégorie
                    Image(getImageForCategory())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(category.color.color.opacity(0.2))
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    category.color.color.opacity(0.6),
                                    category.color.color.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: category.color.color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Contenu amélioré
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(category.description)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        VStack(spacing: 4) {
                            if category.isConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(category.color.color)
                            }
                            
                            Text(category.isConfigured ? "OK" : "Config")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(category.isConfigured ? .green : category.color.color)
                        }
                    }
                    
                    // Statistiques
                    HStack(spacing: 12) {
                        if category.isConfigured {
                            HStack(spacing: 4) {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(category.color.color)
                                
                                Text("\(category.selectedAppsCount) apps")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(category.color.color)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(category.color.color.opacity(0.15))
                            )
                        } else {
                            Text("Tap pour configurer")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: category.isConfigured ? 
                                [category.color.color.opacity(0.5), category.color.color.opacity(0.2)] :
                                [.white.opacity(0.2), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: category.isConfigured ? category.color.color.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.05 : 0.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func getImageForCategory() -> String {
        switch category.id {
        case "ai_productivity": return "image-ia-1"
        case "social_media": return "imafe-ia-2" // Note: il y a une faute dans le nom du dossier
        case "games_entertainment": return "image-ia-3"
        default: return "image-ia-1"
        }
    }
}

// MARK: - Category Challenge Group

struct CategoryChallengeGroup: View {
    let category: AppCategory
    let challenges: [CategoryChallenge]
    let onChallengeStart: (CategoryChallenge) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(category.color.color)
                
                Text(categoryName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Challenge buttons
            VStack(spacing: 6) {
                ForEach(challenges.sorted(by: { $0.duration < $1.duration })) { challenge in
                    CategoryChallengeButton(
                        challenge: challenge,
                        category: category,
                        onTap: { onChallengeStart(challenge) }
                    )
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var categoryName: String {
        // Prendre le premier mot pour économiser l'espace
        return String(category.name.split(separator: " ").first ?? "")
    }
}

// MARK: - Category Challenge Button

struct CategoryChallengeButton: View {
    let challenge: CategoryChallenge
    let category: AppCategory
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Badge
                Text(challenge.badge)
                    .font(.system(size: 10))
                
                // Title
                Text("0 \(categoryShortName)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                
                // Duration
                Text(challenge.formattedDuration)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(category.color.color.opacity(0.4), lineWidth: 1)
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
    
    private var categoryShortName: String {
        switch category.id {
        case "ai_productivity": return "IA"
        case "social_media": return "Social"
        case "games_entertainment": return "Games"
        default: return String(category.name.prefix(5))
        }
    }
}

// MARK: - Standalone Category Challenges (Alternative Layout)

struct CategoryChallengesInline: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availableChallenges) { challenge in
                    if let category = categoryManager.getCategoryById(challenge.categoryId) {
                        InlineCategoryChallengeButton(
                            challenge: challenge,
                            category: category,
                            onTap: {
                                categoryManager.startCategoryChallenge(challenge, zenloopManager: zenloopManager)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: showContent)
    }
    
    private var availableChallenges: [CategoryChallenge] {
        return categoryManager.availableChallenges
            .filter { challenge in
                categoryManager.getCategoryById(challenge.categoryId)?.isReadyForChallenges == true
            }
            .sorted { $0.duration < $1.duration }
    }
}

// MARK: - Inline Category Challenge Button

struct InlineCategoryChallengeButton: View {
    let challenge: CategoryChallenge
    let category: AppCategory
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Category icon
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(category.color.color)
                
                // Challenge title
                Text(challenge.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Badge
                Text(challenge.badge)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(category.color.color.opacity(0.4), lineWidth: 1)
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
    CategoryChallengesRow(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}