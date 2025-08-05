//
//  TotalActivityView.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI

struct TotalActivityView: View {
    let activityReport: ActivityReport
    
    var body: some View {
        List {
            Text("Temps d'écran moyen quotidien : \(formatTime(activityReport.averageDaily))")
                .font(.headline)
            Text("Temps d'écran moyen hebdomadaire : \(formatTime(activityReport.averageWeekly))")
                .font(.headline)
            Text("Temps total : \(formatTime(activityReport.totalDuration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Section(header: Text("Top 3 apps les plus utilisées")) {
                ForEach(activityReport.top3Apps, id: \.name) { app in
                    HStack {
                        Text(app.name)
                        Spacer()
                        Text(formatTime(app.duration))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0 min"
    }
}

#Preview {
    TotalActivityView(activityReport: ActivityReport(
        totalDuration: 14400, // 4 heures
        averageDaily: 14400,
        averageWeekly: 100800,
        top3Apps: [
            AppUsage(name: "Instagram", duration: 5400),
            AppUsage(name: "Safari", duration: 3600),
            AppUsage(name: "Messages", duration: 2700)
        ]
    ))
}
