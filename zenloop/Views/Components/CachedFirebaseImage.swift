//
//  CachedFirebaseImage.swift
//  zenloop
//
//  Système élégant de chargement d'images Firebase Storage
//  avec cache mémoire + disque, shimmer placeholder, et transitions fluides.
//

import SwiftUI
import FirebaseStorage
import Combine

// MARK: - Image Cache (Singleton)

final class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.zenloop.imagecache", qos: .utility)

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("firebase_images", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Limite mémoire raisonnable (~50 images)
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for key: String) -> UIImage? {
        let cacheKey = key.cacheKey

        // 1. Mémoire (instantané)
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        // 2. Disque
        let filePath = cacheDirectory.appendingPathComponent(cacheKey)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: data.count)
            return image
        }

        return nil
    }

    func store(_ image: UIImage, for key: String) {
        let cacheKey = key.cacheKey

        // Mémoire
        if let data = image.jpegData(compressionQuality: 0.85) {
            memoryCache.setObject(image, forKey: cacheKey as NSString, cost: data.count)

            // Disque (async)
            let filePath = cacheDirectory.appendingPathComponent(cacheKey)
            ioQueue.async {
                try? data.write(to: filePath, options: .atomic)
            }
        }
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        ioQueue.async { [weak self] in
            guard let dir = self?.cacheDirectory else { return }
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

private extension String {
    /// Clé sûre pour le filesystem (hash du path Firebase)
    var cacheKey: String {
        let hash = self.utf8.reduce(into: UInt64(5381)) { result, byte in
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(byte)
        }
        return String(hash, radix: 36)
    }
}


// MARK: - Image Loader (ObservableObject par path)

final class FirebaseImageLoader: ObservableObject {
    enum Phase: Equatable {
        case empty
        case loading
        case loaded(UIImage)
        case failed

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty), (.loading, .loading), (.failed, .failed): return true
            case (.loaded(let a), .loaded(let b)): return a === b
            default: return false
            }
        }
    }

    @Published private(set) var phase: Phase = .empty

    private var storagePath: String?
    private var downloadTask: StorageDownloadTask?

    func load(path: String) {
        // Déjà chargé pour ce path
        if storagePath == path, case .loaded = phase { return }

        cancel()
        storagePath = path

        // Cache hit → pas de réseau
        if let cached = ImageCacheManager.shared.image(for: path) {
            phase = .loaded(cached)
            return
        }

        phase = .loading

        let ref = Storage.storage().reference(withPath: path)

        // Max 5 MB
        downloadTask = ref.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self, self.storagePath == path else { return }

                if let data, let image = UIImage(data: data) {
                    ImageCacheManager.shared.store(image, for: path)
                    withAnimation(.easeOut(duration: 0.35)) {
                        self.phase = .loaded(image)
                    }
                } else {
                    self.phase = .failed
                }
            }
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
    }
}


// MARK: - CachedFirebaseImage (View publique)

/// Remplace `FirebaseStorageImage` partout dans l'app.
///
/// Usage :
/// ```
/// CachedFirebaseImage(storagePath: session.backgroundImageUrl)
///     .frame(width: 220, height: 200)
///     .clipShape(RoundedRectangle(cornerRadius: 20))
/// ```
struct CachedFirebaseImage: View {
    let storagePath: String?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 0

    @StateObject private var loader = FirebaseImageLoader()

    var body: some View {
        Group {
            switch loader.phase {
            case .empty, .loading:
                ShimmerPlaceholder()

            case .loaded(let uiImage):
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))

            case .failed:
                FailedImagePlaceholder()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            if let path = storagePath, !path.isEmpty {
                loader.load(path: path)
            }
        }
        .onChange(of: storagePath) { _, newPath in
            if let path = newPath, !path.isEmpty {
                loader.load(path: path)
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
}


// MARK: - Shimmer Placeholder

struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base
                Color.white.opacity(0.04)

                // Shimmer sweep
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.06),
                        .white.opacity(0.10),
                        .white.opacity(0.06),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: phase * (geo.size.width * 0.8))
                .blendMode(.screen)

                // Icône centrale discrète
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.08))
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1.0
            }
        }
    }
}


// MARK: - Failed Placeholder

struct FailedImagePlaceholder: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.03)

            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.12))

                Text("Erreur")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.10))
            }
        }
    }
}


// MARK: - Overlay Modifier (pour les cartes avec texte par-dessus)

struct ReadabilityOverlayModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.7),
                            .black.opacity(0.2),
                            .black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}

extension View {
    /// Ajoute un gradient sombre pour garantir la lisibilité du texte.
    func withReadabilityOverlay(cornerRadius: CGFloat = 0) -> some View {
        self.modifier(ReadabilityOverlayModifier(cornerRadius: cornerRadius))
    }
}
