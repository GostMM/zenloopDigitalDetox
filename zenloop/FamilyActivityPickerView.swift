//
//  FamilyActivityPickerView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import FamilyControls

struct FamilyActivityPickerView: View {
    @Binding var selection: FamilyActivitySelection
    @Binding var isPresented: Bool
    let onConfirm: (FamilyActivitySelection) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "apps.iphone")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    
                    Text(String(localized: "select_apps_to_block"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Choisissez les applications qui vous distraient")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                FamilyActivityPicker(selection: $selection)
                    .frame(maxHeight: 400)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(String(localized: "confirm_selection")) {
                        onConfirm(selection)
                        isPresented = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    
                    Button("Annuler") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Apps à bloquer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Fermer") {
                    isPresented = false
                }
            )
        }
    }
}

#Preview {
    FamilyActivityPickerView(
        selection: .constant(FamilyActivitySelection()),
        isPresented: .constant(true),
        onConfirm: { _ in }
    )
}