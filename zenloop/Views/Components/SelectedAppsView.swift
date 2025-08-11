//
//  SelectedAppsView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 04/08/2025.
//

import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

struct SelectedAppsView: View {
    let selection: FamilyActivitySelection
    let maxDisplayCount: Int
    
    init(selection: FamilyActivitySelection, maxDisplayCount: Int = 6) {
        self.selection = selection
        self.maxDisplayCount = maxDisplayCount
    }
    
    private var selectedAppsArray: Array<ApplicationToken>.SubSequence {
        Array(selection.applicationTokens).prefix(maxDisplayCount)
    }
    
    private var hasMoreApps: Bool {
        selection.applicationTokens.count > maxDisplayCount
    }
    
    private var totalCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
    
    var body: some View {
        if !selectedAppsArray.isEmpty || !selection.categoryTokens.isEmpty {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text(String(localized: "selected_apps"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(totalCount) app\(totalCount > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Applications individuelles
                if !selectedAppsArray.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(Array(selectedAppsArray), id: \.self) { token in
                            AppIconCard(token: token)
                        }
                        
                        // Indicateur "et X autres" si nécessaire
                        if hasMoreApps {
                            MoreAppsCard(count: selection.applicationTokens.count - maxDisplayCount)
                        }
                    }
                }
                
                // Catégories sélectionnées
                if !selection.categoryTokens.isEmpty {
                    CategoriesSection(categoryTokens: selection.categoryTokens)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        } else {
            EmptySelectionView()
        }
    }
}

// MARK: - App Icon Card

struct AppIconCard: View {
    let token: ApplicationToken
    
    var body: some View {
        // Seulement l'icône, pas de nom
        Label(token)
            .labelStyle(.iconOnly)
            .font(.system(size: 28))
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - More Apps Card

struct MoreAppsCard: View {
    let count: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            
            Text("+\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Categories Section

struct CategoriesSection: View {
    let categoryTokens: Set<ActivityCategoryToken>
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Catégories")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(Array(categoryTokens), id: \.self) { token in
                    CategoryCard(token: token)
                }
            }
        }
    }
}

struct CategoryCard: View {
    let token: ActivityCategoryToken
    
    var body: some View {
        // Seulement l'icône pour les catégories aussi
        Label(token)
            .labelStyle(.iconOnly)
            .font(.system(size: 28))
            .frame(width: 44, height: 44)
            .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Empty Selection View

struct EmptySelectionView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.slash")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
            
            Text(String(localized: "no_app_selected"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Types

// AppDetails n'est plus nécessaire car on utilise Label(token) directement

#Preview {
    VStack(spacing: 20) {
        SelectedAppsView(selection: FamilyActivitySelection())
        
        // Preview avec données factices si possible
        SelectedAppsView(selection: FamilyActivitySelection(), maxDisplayCount: 4)
    }
    .padding()
    .background(Color.black)
}