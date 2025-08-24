import SwiftUI

struct SplashScreen: View {
    // États d'animation minimalistes
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Fond simple
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo de l'app (icône)
                logoView
                
                // Titre simple
                titleSection
                
                Spacer()
            }
        }
        .onAppear {
            startSimpleAnimation()
        }
    }
    
    // MARK: - Logo (App Icon)
    private var logoView: some View {
        VStack(spacing: 0) {
            // Utiliser l'icône de l'app
            Image("zenloop")
                .resizable()
                .frame(width: 120, height: 120)
                .cornerRadius(26) // Coins arrondis comme les icônes iOS
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .shadow(color: .white.opacity(0.1), radius: 10)
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 8) {
            // Titre principal simple
            Text("Zenloop")
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .opacity(titleOpacity)
        }
    }
    
    // MARK: - Simple Animation
    private func startSimpleAnimation() {
        // Animation simple du logo
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1
            logoScale = 1.0
        }
        
        // Titre après le logo
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            titleOpacity = 1
        }
        
        // Transition vers l'app principale (plus courte)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NotificationCenter.default.post(name: Notification.Name("SplashCompleted"), object: nil)
        }
    }
}

// MARK: - Preview
#Preview {
    SplashScreen()
}
