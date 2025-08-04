//
//  FuturisticCompletedView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticCompletedView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.purple)
                    .scaleEffect(1.1)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: true)
            }
            
            VStack(spacing: 8) {
                Text("Félicitations ! 🎉")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                
                Text("Mission accomplie avec succès")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                
                CompactButton(
                    title: "Nouveau défi",
                    icon: "plus.circle.fill",
                    color: .purple
                ) {
                    zenloopManager.resetToIdle()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}