//
//  SplashScreenView.swift
//  zenloop
//
//  Launch screen minimaliste et sombre
//

import SwiftUI

struct SplashScreenView: View {
    @State private var contentOpacity: Double = 0
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            // Background noir pur
            Color.black
                .ignoresSafeArea()

            // Contenu centré et statique
            VStack(spacing: 24) {
                // Logo simple et propre
                Image("zenloop")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Titre
                Text("Zenloop")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                // Tagline simple
                Text("Take Back Control")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            // Fade in simple
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1.0
            }

            // Transition après 2 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isActive = false
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
}
