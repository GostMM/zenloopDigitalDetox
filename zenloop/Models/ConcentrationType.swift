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
        case .deep: return String(localized: "concentration_deep_focus")
        case .creative: return String(localized: "concentration_creativity")
        case .study: return String(localized: "concentration_study")
        case .meditation: return String(localized: "concentration_meditation")
        case .work: return String(localized: "concentration_work")
        }
    }
    
    var description: String {
        switch self {
        case .deep: return String(localized: "concentration_deep_focus_desc")
        case .creative: return String(localized: "concentration_creativity_desc")
        case .study: return String(localized: "concentration_study_desc")
        case .meditation: return String(localized: "concentration_meditation_desc")
        case .work: return String(localized: "concentration_work_desc")
        }
    }
    
    var shortDescription: String {
        switch self {
        case .deep: return String(localized: "deep_focus_short")
        case .creative: return String(localized: "creativity_short")
        case .study: return String(localized: "study_short")
        case .meditation: return String(localized: "meditation_short")
        case .work: return String(localized: "work_short")
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