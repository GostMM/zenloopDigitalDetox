//
//  FuturisticActiveView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticActiveView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 16) {
            if let challenge = zenloopManager.currentChallenge {
                // Progress ring compact
                ZStack {
                    Circle()
                        .stroke(.orange.opacity(0.2), lineWidth: 6)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: challenge.safeProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1), value: challenge.safeProgress)
                    
                    VStack(spacing: 2) {
                        Text("\(challenge.progressPercentage)%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Complété")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                VStack(spacing: 8) {
                    Text(challenge.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(challenge.timeRemaining)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    if challenge.blockedAppsCount > 0 {
                        // Afficher les icônes des apps bloquées
                        SelectedAppsView(selection: zenloopManager.getAppsSelection(), maxDisplayCount: 4)
                    }
                }
                
                // Actions compactes
                HStack(spacing: 10) {
                    CompactButton(
                        title: "Pause",
                        icon: "pause.fill",
                        color: .mint
                    ) {
                        zenloopManager.requestPause()
                    }
                    
                    CompactButton(
                        title: "Arrêter",
                        icon: "stop.fill",
                        color: .red
                    ) {
                        zenloopManager.stopCurrentChallenge()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}