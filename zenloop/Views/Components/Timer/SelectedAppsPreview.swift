//
//  SelectedAppsPreview.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct SelectedAppsPreview: View {
    let selectedApps: FamilyActivitySelection

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))

                Text(String(localized: "apps_blocked"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Mini aperçu des apps et catégories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Afficher les applications individuelles d'abord
                    let maxAppsToShow = 3
                    let apps = Array(selectedApps.applicationTokens.prefix(maxAppsToShow))
                    ForEach(apps, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                    }

                    // Afficher les catégories sélectionnées
                    let maxCategoriesToShow = 2
                    let categories = Array(selectedApps.categoryTokens.prefix(maxCategoriesToShow))
                    ForEach(categories, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(.purple.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }

                    // Compteur si plus d'éléments
                    let totalItems = selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
                    let displayedItems = min(apps.count + categories.count, maxAppsToShow + maxCategoriesToShow)

                    if totalItems > displayedItems {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .frame(width: 24, height: 24)

                            Text("+\(totalItems - displayedItems)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 4)
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
