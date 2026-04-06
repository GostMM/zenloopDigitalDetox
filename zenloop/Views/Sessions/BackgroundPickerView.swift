//
//  BackgroundPickerView.swift
//  zenloop
//
//  Sélecteur d'image de fond pour les sessions
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BackgroundPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedBackground: SessionBackground?
    @StateObject private var backgroundManager = BackgroundManager.shared
    @State private var showContent = false

    // Grille adaptative
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Image de Fond")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Personnalisez votre session")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    if backgroundManager.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Chargement des images...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Option "Aucune image"
                            BackgroundThumbnail(
                                background: .none,
                                isSelected: selectedBackground == nil,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedBackground = nil
                                        dismiss()
                                    }
                                }
                            )

                            // Images disponibles depuis Firebase Storage
                            ForEach(backgroundManager.backgrounds) { background in
                                BackgroundThumbnail(
                                    background: background,
                                    isSelected: selectedBackground?.id == background.id,
                                    action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedBackground = background
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            // ✅ Charger les backgrounds depuis Firebase Storage au premier affichage
            if backgroundManager.backgrounds.isEmpty {
                await backgroundManager.loadBackgrounds()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Background Thumbnail

struct BackgroundThumbnail: View {
    let background: SessionBackground
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if background.id == "none" {
                    // Pas d'image
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 32, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Aucune")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        )
                } else {
                    // Image depuis Firebase Storage
                    AsyncImage(url: URL(string: background.downloadUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.gray.opacity(0.2))
                                .overlay(ProgressView().tint(.white))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        case .failure:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.red.opacity(0.2))
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.red)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                // Overlay de sélection
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 3)
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.blue)
                                        .background(Circle().fill(.white).padding(4))
                                        .padding(8)
                                }
                                Spacer()
                            }
                        )
                }
            }
            .frame(height: 120)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    BackgroundPickerView(selectedBackground: .constant(nil))
}
