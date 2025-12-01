//
//  AppSelectionSectionView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct AppSelectionSectionView: View {
    let hasSelectedApps: Bool
    let selectedApps: FamilyActivitySelection
    let onSelectApps: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "apps_to_block"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Button(action: onSelectApps) {
                    HStack(spacing: 8) {
                        Image(systemName: hasSelectedApps ? "plus.circle.fill" : "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(hasSelectedApps ? .cyan : .white.opacity(0.7))

                        Text(hasSelectedApps ? String(localized: "modify") : String(localized: "select"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((hasSelectedApps ? Color.cyan : Color.white).opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Affichage des apps sélectionnées
            if hasSelectedApps {
                SelectedAppsView(selection: selectedApps, maxDisplayCount: 4)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: hasSelectedApps)
            }
        }
    }
}
