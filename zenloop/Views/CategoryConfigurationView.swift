//
//  CategoryConfigurationView.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import FamilyControls

struct CategoryConfigurationView: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showContent = false
    @State private var showingAppSelection = false
    @State private var selectedCategory: AppCategory? = nil
    @State private var selectedApps = FamilyActivitySelection()
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.08, green: 0.02, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Progress indicator
                    progressSection
                    
                    // Categories list
                    categoriesSection
                    
                    // Completion message
                    if categoryManager.configuredCategories.count == categoryManager.categories.count {
                        completionSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("🎯 Configurez vos Catégories")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Sélectionnez une seule fois vos apps par catégorie pour des défis rapides")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progression")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(categoryManager.configuredCategories.count)/\(categoryManager.categories.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.cyan)
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.cyan.opacity(0.3), lineWidth: 1)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: showContent)
    }
    
    private var progressPercentage: Double {
        guard !categoryManager.categories.isEmpty else { return 0 }
        return Double(categoryManager.configuredCategories.count) / Double(categoryManager.categories.count)
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(categoryManager.categories.enumerated()), id: \.element.id) { index, category in
                CategoryConfigurationCard(
                    category: category,
                    onConfigure: {
                        selectedCategory = category
                        selectedApps = category.selectedApps.toFamilyActivitySelection()
                        showingAppSelection = true
                    }
                )
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.1), value: showContent)
            }
        }
    }
    
    // MARK: - Completion Section
    
    private var completionSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text("🎉 Configuration Terminée !")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Vous pouvez maintenant utiliser les défis rapides par catégorie")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(showContent ? 1.0 : 0.8)
        .opacity(showContent ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
    }
}

// MARK: - Category Configuration Card

struct CategoryConfigurationCard: View {
    let category: AppCategory
    let onConfigure: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onConfigure) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(category.color.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(category.color.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(category.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if category.isConfigured {
                            statusBadge
                        }
                    }
                    
                    Text(category.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    if category.isConfigured {
                        Text("\(category.selectedAppsCount) app\(category.selectedAppsCount > 1 ? "s" : "") sélectionnée\(category.selectedAppsCount > 1 ? "s" : "")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(category.color.color)
                    }
                }
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        category.isConfigured ? 
                        category.color.color.opacity(0.5) : 
                        .white.opacity(0.1),
                        lineWidth: category.isConfigured ? 2 : 1
                    )
            )
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
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
            
            Text("Configuré")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.green.opacity(0.2), in: Capsule())
    }
}

#Preview {
    NavigationView {
        CategoryConfigurationView()
    }
}