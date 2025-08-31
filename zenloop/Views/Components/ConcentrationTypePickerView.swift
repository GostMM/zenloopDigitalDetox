//
//  ConcentrationTypePickerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct ConcentrationTypePickerView: View {
    @Binding var selectedType: ConcentrationType
    @Environment(\.dismiss) private var dismiss
    
    // Grid simple et robuste - 2 colonnes fixes avec espacement calculé
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background avec gradient sombre
                LinearGradient(
                    colors: [.black, .gray.opacity(0.8), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 20)
                        
                        // Titre
                        VStack(spacing: 8) {
                            Text(String(localized: "concentration_type"))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(String(localized: "choose_ideal_ambiance"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Grid simple des types de concentration
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(ConcentrationType.allCases) { type in
                                ConcentrationTypeCard(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    // Retour haptique immédiat
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring()) {
                                        selectedType = type
                                    }
                                    
                                    // Fermer après sélection avec un léger délai pour apprécier l'animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(
                // Bouton fermer
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
            )
        }
    }
}

struct ConcentrationTypeCard: View {
    let type: ConcentrationType
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Section supérieure avec icône
                VStack(spacing: 12) {
                    // Icône principale
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        type.primaryColor.opacity(0.3),
                                        type.primaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: type.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(type.primaryColor)
                    }
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? type.accentColor : type.primaryColor.opacity(0.3), 
                                lineWidth: isSelected ? 3 : 2
                            )
                    )
                    
                    // Titre
                    Text(type.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                // Section inférieure avec description
                VStack(spacing: 8) {
                    Text(type.shortDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Indicateur de sélection
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(type.accentColor)
                            
                            Text(String(localized: "selected"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(type.accentColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? type.accentColor : .white.opacity(0.15), 
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : (isSelected ? 1.02 : 1.0))
            .shadow(
                color: isSelected ? type.accentColor.opacity(0.4) : .black.opacity(0.1), 
                radius: isSelected ? 12 : 6, 
                x: 0, 
                y: isSelected ? 6 : 3
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
            
            // Retour haptique léger au press
            if pressing {
                let lightImpact = UIImpactFeedbackGenerator(style: .light)
                lightImpact.impactOccurred()
            }
        }, perform: {})
    }
}

#Preview {
    ConcentrationTypePickerView(selectedType: .constant(.deep))
}