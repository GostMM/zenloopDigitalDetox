//
//  QuickBlockCategory.swift
//  zenloop
//
//  Modèle pour les modes de blocage rapide avec apps sélectionnées
//

import Foundation
import FamilyControls

enum QuickBlockCategoryType: String, CaseIterable, Codable, Identifiable {
    case social = "social"
    case productivity = "productivity"
    case gaming = "gaming"
    case adult = "adult"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .social:  return String(localized: "no_social_title")
        case .productivity: return String(localized: "no_ai_title")
        case .gaming: return String(localized: "no_gaming_title")
        case .adult: return String(localized: "no_porn_title")
        }
    }

    var imageName: String {
        switch self {
        case .social: return "social"
        case .productivity: return "imafe-ia-2"
        case .gaming: return "game"
        case .adult: return "pornde"
        }
    }

    var systemIcon: String {
        switch self {
        case .social: return "message.fill"
        case .productivity: return "brain.head.profile"
        case .gaming: return "gamecontroller.fill"
        case .adult: return "hand.raised.fill"
        }
    }
}

struct QuickBlockCategory: Identifiable, Codable {
    let id: String
    let type: QuickBlockCategoryType
    var selection: FamilyActivitySelection
    var isActive: Bool
    var scheduledStartTime: Date?
    var scheduledDuration: TimeInterval?

    init(type: QuickBlockCategoryType) {
        self.id = UUID().uuidString
        self.type = type
        self.selection = FamilyActivitySelection()
        self.isActive = false
        self.scheduledStartTime = nil
        self.scheduledDuration = nil
    }

    var hasAppsSelected: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    var appsCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
}
