//
//  FirebaseStorageImage.swift
//  zenloop
//
//  Composant pour charger des images depuis Firebase Storage
//

import SwiftUI
import FirebaseStorage

/// Vue qui charge une image depuis Firebase Storage de manière asynchrone
struct FirebaseStorageImage: View {
    let storagePath: String
    @State private var imageUrl: String?
    @State private var isLoading = true
    @State private var hasError = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white.opacity(0.5))
            } else if hasError {
                Image(systemName: "photo.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.3))
            } else if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                    case .failure:
                        Image(systemName: "photo.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.3))
                    default:
                        ProgressView()
                            .tint(.white.opacity(0.5))
                    }
                }
            }
        }
        .task {
            await loadImageUrl()
        }
    }

    private func loadImageUrl() async {
        guard !storagePath.isEmpty else {
            isLoading = false
            hasError = true
            return
        }

        do {
            let storage = Storage.storage()
            let reference = storage.reference(withPath: storagePath)
            let url = try await reference.downloadURL()

            await MainActor.run {
                self.imageUrl = url.absoluteString
                self.isLoading = false
            }
        } catch {
            print("❌ Erreur chargement image Firebase Storage: \(error.localizedDescription)")
            await MainActor.run {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
}
