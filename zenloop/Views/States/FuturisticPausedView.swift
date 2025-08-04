//
//  FuturisticPausedView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticPausedView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.mint.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "pause.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.mint)
            }
            
            VStack(spacing: 8) {
                Text("Pause active")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                
                Text("Temps restant: \(zenloopManager.pauseTimeRemaining)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.mint)
                
                CompactButton(
                    title: "Reprendre",
                    icon: "play.fill",
                    color: .mint
                ) {
                    zenloopManager.resumeChallenge()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}