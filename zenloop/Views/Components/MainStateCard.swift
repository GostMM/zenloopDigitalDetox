//
//  MainStateCard.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI

struct MainStateCard: View {
    let showContent: Bool
    @ObservedObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 0) {
            currentStateContent
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 50)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: showContent)
    }
    
    @ViewBuilder
    private var currentStateContent: some View {
        switch zenloopManager.currentState {
        case .idle:
            FuturisticIdleView()
        case .active:
            FuturisticActiveView(zenloopManager: zenloopManager)
        case .paused:
            FuturisticPausedView(zenloopManager: zenloopManager)
        case .completed:
            FuturisticCompletedView(zenloopManager: zenloopManager)
        }
    }
}