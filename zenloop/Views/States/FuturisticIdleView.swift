//
//  FuturisticIdleView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticIdleView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.cyan.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "circle.dashed")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.cyan)
            }
            
            VStack(spacing: 6) {
                Text("Prêt à commencer")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                
                Text("Choisis un défi pour bloquer tes distractions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }
}