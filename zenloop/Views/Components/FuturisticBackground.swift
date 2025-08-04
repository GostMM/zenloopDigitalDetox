//
//  FuturisticBackground.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct FuturisticBackground: View {
    let geometry: GeometryProxy
    let backgroundOffset: CGFloat
    let currentState: ZenloopState
    
    var body: some View {
        ZStack {
            // Image de fond principale - Construit pour ne pas affecter le layout
            Image("mountains")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            
            // Overlay couleur selon l'état
            Rectangle()
                .fill(stateOverlayColor)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(.easeInOut(duration: 1.5), value: currentState)
            
            // Particules flottantes subtiles (seules les particules s'animent)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: CGFloat(15 + index * 8))
                    .offset(
                        x: CGFloat(index * 50 - 100),
                        y: CGFloat(index * 60 - 120) + sin(backgroundOffset * 0.015 + Double(index)) * 25
                    )
                    .blur(radius: 3)
            }
        }
        .clipped() // Assurer que rien ne dépasse
    }
    
    private var stateOverlayColor: Color {
        switch currentState {
        case .idle:
            return Color.blue.opacity(0.3)
        case .active:
            return Color.orange.opacity(0.4)
        case .paused:
            return Color.green.opacity(0.3)
        case .completed:
            return Color.purple.opacity(0.4)
        }
    }
}
