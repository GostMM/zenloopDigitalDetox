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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BackgroundPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedBackground: SessionBackground?
    @StateObject private var backgroundManager = BackgroundManager.shared
    @State private var showContent = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 10)
    ]

    var body: some View {
        ZStack {
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        if backgroundManager.isLoading && backgroundManager.backgrounds.isEmpty {
                            // Skeleton grid pendant le chargement initial
                            ForEach(0..<8, id: \.self) { _ in
                                SkeletonThumbnail()
                            }
                        } else {
                            // Option "Aucune image"
                            BackgroundThumbnail(
                                background: .none,
                                isSelected: selectedBackground == nil,
                                action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedBackground = nil
                                        dismiss()
                                    }
                                }
                            )

                            ForEach(backgroundManager.backgrounds) { background in
                                BackgroundThumbnail(
                                    background: background,
                                    isSelected: selectedBackground?.id == background.id,
                                    action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedBackground = background
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
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

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "background_picker_title"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(localized: "background_picker_subtitle"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
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
                    noneTile
                } else {
                    AsyncImage(url: URL(string: background.downloadUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ShimmerTile()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 130)
                                .clipped()
                        case .failure:
                            failureTile
                        @unknown default:
                            ShimmerTile()
                        }
                    }
                }

                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.3, green: 0.6, blue: 1), lineWidth: 2.5)

                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color(red: 0.3, green: 0.6, blue: 1)))
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var noneTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                        .foregroundStyle(Color.white.opacity(0.22))
                )

            VStack(spacing: 6) {
                Image(systemName: "nosign")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(localized: "background_none"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var failureTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))

            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Text(String(localized: "background_load_failed"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Shimmer Tile (per-image skeleton)

struct ShimmerTile: View {
    @State private var animating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: animating ? .leading : .trailing,
                    endPoint: animating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animating.toggle()
                }
            }
    }
}

// MARK: - Skeleton Thumbnail (full-size skeleton for grid loading state)

struct SkeletonThumbnail: View {
    @State private var animating = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: animating ? .leading : .trailing,
                        endPoint: animating ? .trailing : .leading
                    )
                )
                .frame(height: 130)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 18, height: 18)
                .padding(8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animating.toggle()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BackgroundPickerView(selectedBackground: .constant(nil))
}
