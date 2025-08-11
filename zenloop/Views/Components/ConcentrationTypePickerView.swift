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
                        
                        // Grid des types de concentration
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 16) {
                            ForEach(ConcentrationType.allCases) { type in
                                ConcentrationTypeCard(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    withAnimation(.spring()) {
                                        selectedType = type
                                    }
                                    
                                    // Fermer après sélection
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background image depuis les assets
                Image(getBackgroundImageForType())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
                
                // Overlay gradient
                LinearGradient(
                    colors: [
                        .clear,
                        type.primaryColor.opacity(0.6),
                        type.primaryColor.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                VStack(spacing: 8) {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(type.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(type.description)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Indicateur de sélection
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(type.accentColor)
                                .background(.white, in: Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? type.accentColor : .white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(color: isSelected ? type.accentColor.opacity(0.3) : .black.opacity(0.2), radius: isSelected ? 8 : 4)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func getBackgroundImageForType() -> String {
        switch type {
        case .deep:
            return "focus"
        case .creative:
            return "creativite"  
        case .study:
            return "study"
        case .meditation:
            return "meditation"
        case .work:
            return "focus"
        }
    }
}

#Preview {
    ConcentrationTypePickerView(selectedType: .constant(.deep))
}