//
//  SessionBackground.swift
//  zenloop
//
//  Modèle pour les images de fond des sessions depuis Firebase Storage
//

import Foundation
import FirebaseStorage
import os.log

private let logger = Logger(subsystem: "com.app.zenloop", category: "SessionBackground")

struct SessionBackground: Identifiable, Hashable {
    let id: String
    let name: String
    let storagePath: String // ✅ Chemin dans Firebase Storage
    var downloadUrl: String? // ✅ URL de téléchargement (chargée dynamiquement)

    // ✅ Background par défaut (aucune image)
    static let none = SessionBackground(
        id: "none",
        name: "None",
        storagePath: ""
    )
}

// MARK: - Background Manager

@MainActor
class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()

    @Published var backgrounds: [SessionBackground] = []
    @Published var isLoading = false

    private init() {}

    // ✅ Charger dynamiquement tous les fichiers du folder backgrounds/ depuis Firebase Storage
    func loadBackgrounds() async {
        isLoading = true
        logger.info("🔍 Chargement des backgrounds depuis Firebase Storage...")

        do {
            let storage = Storage.storage()
            let backgroundsRef = storage.reference().child("backgrounds")

            // ✅ Lister tous les fichiers dans le folder backgrounds/
            let result = try await backgroundsRef.listAll()

            logger.info("✅ Trouvé \(result.items.count) images dans backgrounds/")

            var loadedBackgrounds: [SessionBackground] = []

            // ✅ Pour chaque fichier, récupérer son URL de téléchargement
            for item in result.items {
                do {
                    let downloadUrl = try await item.downloadURL()
                    let fileName = item.name
                    let fileNameWithoutExt = fileName.replacingOccurrences(of: #"\.[^.]+$"#, with: "", options: .regularExpression)

                    // Créer un nom lisible à partir du nom de fichier
                    let displayName = fileNameWithoutExt
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized

                    let background = SessionBackground(
                        id: fileNameWithoutExt,
                        name: displayName,
                        storagePath: "backgrounds/\(fileName)",
                        downloadUrl: downloadUrl.absoluteString
                    )

                    loadedBackgrounds.append(background)
                    logger.debug("✅ Chargé: \(fileName) → \(displayName)")
                } catch {
                    logger.error("❌ Erreur lors du chargement de \(item.name): \(error.localizedDescription)")
                }
            }

            // Trier par nom
            self.backgrounds = loadedBackgrounds.sorted { $0.name < $1.name }
            logger.info("✅ \(self.backgrounds.count) backgrounds chargés avec succès")

        } catch {
            logger.error("❌ Erreur lors de la liste des backgrounds: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // ✅ Récupérer l'URL d'un background par son storagePath
    func getUrlForPath(_ storagePath: String) -> String? {
        return backgrounds.first(where: { $0.storagePath == storagePath })?.downloadUrl
    }
}
