//
//  ConcentrationType.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

enum ConcentrationType: String, CaseIterable, Identifiable {
    case deep = "deep"
    case creative = "creative"
    case study = "study"
    case meditation = "meditation"
    case work = "work"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .deep: return "Focus Profond"
        case .creative: return "Créativité"
        case .study: return "Étude"
        case .meditation: return "Méditation"
        case .work: return "Travail"
        }
    }
    
    var description: String {
        switch self {
        case .deep: return "Concentration intense pour les tâches complexes"
        case .creative: return "Libère ta créativité et ton imagination"
        case .study: return "Apprentissage et mémorisation optimale"
        case .meditation: return "Calme mental et paix intérieure"
        case .work: return "Productivité maximum pour tes projets"
        }
    }
    
    var icon: String {
        switch self {
        case .deep: return "brain.head.profile"
        case .creative: return "paintbrush.fill"
        case .study: return "book.fill"
        case .meditation: return "leaf.fill"
        case .work: return "laptopcomputer"
        }
    }
    
    var backgroundImage: String {
        switch self {
        case .deep: return "mountains"
        case .creative: return "mountains-b"
        case .study: return "mountains"
        case .meditation: return "mountains-b"
        case .work: return "mountains"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .deep: return .indigo
        case .creative: return .purple
        case .study: return .blue
        case .meditation: return .green
        case .work: return .orange
        }
    }
    
    var accentColor: Color {
        switch self {
        case .deep: return .cyan
        case .creative: return .pink
        case .study: return .teal
        case .meditation: return .mint
        case .work: return .yellow
        }
    }
    
    var suggestedDurations: [Int] {
        switch self {
        case .deep: return [45, 60, 90, 120]
        case .creative: return [30, 45, 60, 90]
        case .study: return [25, 45, 60, 90]
        case .meditation: return [10, 15, 20, 30]
        case .work: return [25, 45, 60, 90]
        }
    }
}