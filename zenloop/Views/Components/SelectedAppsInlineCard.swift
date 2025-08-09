//
//  SelectedAppsInlineCard.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 08/08/2025.
//

import SwiftUI
import FamilyControls

struct SelectedAppsInlineCard: View {
    @ObservedObject var zenloopManager: ZenloopManager
    let showContent: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Header avec titre et nombre d'apps
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("Tes distractions ciblées")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(zenloopManager.selectedAppsCount) app\(zenloopManager.selectedAppsCount > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Scroll horizontal des apps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let selection = zenloopManager.getAppsSelection()
                    
                    // Afficher jusqu'à 8 apps pour éviter la performance
                    ForEach(Array(selection.applicationTokens.prefix(8)), id: \.self) { token in
                        VStack(spacing: 6) {
                            // Icône de l'app
                            Label(token)
                                .labelStyle(.iconOnly)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    
                    // Indicateur s'il y a plus d'apps
                    if selection.applicationTokens.count > 8 {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Text("+\(selection.applicationTokens.count - 8)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
}

#Preview {
    SelectedAppsInlineCard(
        zenloopManager: ZenloopManager.shared,
        showContent: true
    )
    .background(Color.black)
}