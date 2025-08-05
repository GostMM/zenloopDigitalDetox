//
//  TotalActivityView.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI
import os.log
import FamilyControls

struct TotalActivityView: View {
    let activityReport: ActivityReport
    private let logger = Logger(subsystem: "com.app.zenloop.activity", category: "TotalActivityView")
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête compact avec métriques
            HStack(spacing: 0) {
                // Temps quotidien
                VStack(spacing: 2) {
                    Text(formatTime(activityReport.averageDaily))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Aujourd'hui")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                // Temps hebdomadaire 
                VStack(spacing: 2) {
                    Text(formatTime(activityReport.averageWeekly))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Semaine")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Séparateur
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Liste compacte des applications
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(activityReport.top3Apps.enumerated()), id: \.element.name) { index, app in
                        HStack(spacing: 12) {
                            // Rang médaille compact
                            ZStack {
                                Circle()
                                    .fill(rankColor(for: index + 1))
                                    .frame(width: 24, height: 24)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Icône app
                            Label(app.token)
                                .labelStyle(.iconOnly)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Info app (texte fixé)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Utilisation")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 8)
                            
                            // Durée et pourcentage alignés
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(formatTime(app.duration))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text("\(Int((app.duration / activityReport.totalDuration) * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        // Séparateur entre apps
                        if index < activityReport.top3Apps.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            logger.info("🎯 [VIEW] ActivityReport received:")
            logger.info("🎯 [VIEW] Total duration: \(activityReport.totalDuration)s")
            logger.info("🎯 [VIEW] Apps count: \(activityReport.top3Apps.count)")
            for (index, app) in activityReport.top3Apps.enumerated() {
                logger.info("🎯 [VIEW] App \(index + 1): \(app.name) - \(app.duration)s")
            }
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0 min"
    }
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .orange      // Or pour la 1ère place
        case 2: return .gray        // Argent pour la 2ème place  
        case 3: return .brown       // Bronze pour la 3ème place
        default: return .blue
        }
    }
}

#Preview {
    TotalActivityView(activityReport: ActivityReport(
        totalDuration: 14400, // 4 heures
        averageDaily: 14400,
        averageWeekly: 100800,
        top3Apps: [
            // Note: ApplicationToken nécessite un vrai token, preview simplifiée
        ]
    ))
}
