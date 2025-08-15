import SwiftUI

struct SplashScreen: View {
    // États d'animation
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -180
    @State private var glowOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var particlesOpacity: Double = 0
    @State private var infinityPathProgress: CGFloat = 0
    @State private var barOpacity: Double = 0
    @State private var barScale: CGFloat = 1.5
    
    // Animation des particules flottantes
    @State private var particleAnimation = false
    
    var body: some View {
        ZStack {
            // Fond avec gradient subtil
            backgroundGradient
            
            // Particules d'arrière-plan animées (léger)
            ParticlesView(animate: $particleAnimation, opacity: particlesOpacity)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo avec animations
                logoView
                    .padding(.bottom, 50)
                
                // Titre et sous-titre
                titleSection
                
                Spacer()
                
                // Indicateur de chargement subtil
                loadingIndicator
                    .padding(.bottom, 80)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            // Base gradient - fond noir/très sombre comme le logo
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Gradient radial très subtil pour effet de profondeur
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.15, blue: 0.3).opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .scaleEffect(1.5)
            .opacity(glowOpacity)
            .animation(.easeInOut(duration: 2), value: glowOpacity)
        }
    }
    
    // MARK: - Logo
    private var logoView: some View {
        ZStack {
            // Glow effect derrière le logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .opacity(glowOpacity * 0.7)
                .scaleEffect(1 + (glowOpacity * 0.3))
            
            // Logo principal - Symbole infini avec barre
            ZStack {
                // Symbole infini animé
                InfinityOnlyShape()
                    .trim(from: 0, to: infinityPathProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.95, green: 0.95, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 160, height: 80)
                    .shadow(color: Color.white.opacity(0.3), radius: 8)
                
                // Barre diagonale animée séparément
                DiagonalBar()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.95, green: 0.95, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 80)
                    .opacity(barOpacity)
                    .scaleEffect(barScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: barScale)
            }
            .scaleEffect(logoScale)
            .rotationEffect(.degrees(logoRotation))
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: logoScale)
            .animation(.easeOut(duration: 1.2), value: logoRotation)
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 12) {
            // Titre principal
            Text("Zenloop")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            Color(red: 0.9, green: 0.9, blue: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: titleOffset)
            
            // Sous-titre
            Text(String(localized: "break_infinite_loop"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .opacity(subtitleOpacity)
        }
    }
    
    // MARK: - Loading Indicator
    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(particleAnimation ? 1.2 : 0.8)
                    .opacity(subtitleOpacity)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: particleAnimation
                    )
            }
        }
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        // Phase 1: Logo apparition et rotation
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1
            logoScale = 1
            logoRotation = 0
        }
        
        // Phase 2: Tracé de l'infini
        withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
            infinityPathProgress = 1
        }
        
        // Phase 3: Apparition de la barre diagonale
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(1.2)) {
            barOpacity = 1
            barScale = 1
        }
        
        // Phase 4: Glow effect
        withAnimation(.easeInOut(duration: 1).delay(1.4)) {
            glowOpacity = 1
        }
        
        // Phase 5: Titre
        withAnimation(.easeOut(duration: 0.6).delay(1.6)) {
            titleOpacity = 1
            titleOffset = 0
        }
        
        // Phase 6: Sous-titre et particules
        withAnimation(.easeOut(duration: 0.6).delay(2.0)) {
            subtitleOpacity = 1
            particlesOpacity = 1
        }
        
        // Démarrer l'animation des particules
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            particleAnimation = true
        }
        
        // Transition vers l'app principale
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            NotificationCenter.default.post(name: Notification.Name("SplashCompleted"), object: nil)
        }
    }
}

// MARK: - Infinity Only Shape (sans la barre)
struct InfinityOnlyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Paramètres pour un infini classique (figure en huit couchée)
        let controlOffset = width * 0.22  // Distance des points de contrôle
        let loopWidth = width * 0.42      // Largeur des boucles
        let loopHeight = height * 0.35    // Hauteur des boucles
        
        // Point de départ (centre)
        path.move(to: CGPoint(x: centerX, y: centerY))
        
        // Partie supérieure de la boucle gauche
        path.addCurve(
            to: CGPoint(x: centerX - loopWidth, y: centerY),
            control1: CGPoint(x: centerX - controlOffset, y: centerY - loopHeight),
            control2: CGPoint(x: centerX - loopWidth, y: centerY - loopHeight)
        )
        
        // Partie inférieure de la boucle gauche (retour au centre)
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY),
            control1: CGPoint(x: centerX - loopWidth, y: centerY + loopHeight),
            control2: CGPoint(x: centerX - controlOffset, y: centerY + loopHeight)
        )
        
        // Partie inférieure de la boucle droite
        path.addCurve(
            to: CGPoint(x: centerX + loopWidth, y: centerY),
            control1: CGPoint(x: centerX + controlOffset, y: centerY + loopHeight),
            control2: CGPoint(x: centerX + loopWidth, y: centerY + loopHeight)
        )
        
        // Partie supérieure de la boucle droite (retour au centre)
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY),
            control1: CGPoint(x: centerX + loopWidth, y: centerY - loopHeight),
            control2: CGPoint(x: centerX + controlOffset, y: centerY - loopHeight)
        )
        
        return path
    }
}

// MARK: - Diagonal Bar Shape
struct DiagonalBar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Barre diagonale comme dans le logo original
        let barWidth: CGFloat = 20  // Même épaisseur que l'infini
        let barLength = width * 0.55
        
        // Angle de la barre (environ -45 degrés comme dans l'image)
        let angle = -45.0 * (Double.pi / 180.0)
        
        // Points de la barre (rectangle tourné)
        let halfLength = barLength / 2
        let halfWidth = barWidth / 2
        
        // Calculer les coins du rectangle
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        
        // Coin supérieur gauche
        let x1 = centerX - halfLength * cosAngle + halfWidth * sinAngle
        let y1 = centerY - halfLength * sinAngle - halfWidth * cosAngle
        
        // Coin supérieur droit
        let x2 = centerX + halfLength * cosAngle + halfWidth * sinAngle
        let y2 = centerY + halfLength * sinAngle - halfWidth * cosAngle
        
        // Coin inférieur droit
        let x3 = centerX + halfLength * cosAngle - halfWidth * sinAngle
        let y3 = centerY + halfLength * sinAngle + halfWidth * cosAngle
        
        // Coin inférieur gauche
        let x4 = centerX - halfLength * cosAngle - halfWidth * sinAngle
        let y4 = centerY - halfLength * sinAngle + halfWidth * cosAngle
        
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        path.addLine(to: CGPoint(x: x3, y: y3))
        path.addLine(to: CGPoint(x: x4, y: y4))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Crossed Infinity Shape (Logo complet pour référence)
struct CrossedInfinityShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Dessiner le symbole infini
        let loopWidth = width * 0.35
        let loopHeight = height * 0.4
        
        // Boucle gauche
        path.move(to: CGPoint(x: centerX, y: centerY))
        path.addCurve(
            to: CGPoint(x: centerX - loopWidth, y: centerY),
            control1: CGPoint(x: centerX, y: centerY - loopHeight),
            control2: CGPoint(x: centerX - loopWidth, y: centerY - loopHeight)
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY),
            control1: CGPoint(x: centerX - loopWidth, y: centerY + loopHeight),
            control2: CGPoint(x: centerX, y: centerY + loopHeight)
        )
        
        // Boucle droite
        path.addCurve(
            to: CGPoint(x: centerX + loopWidth, y: centerY),
            control1: CGPoint(x: centerX, y: centerY - loopHeight),
            control2: CGPoint(x: centerX + loopWidth, y: centerY - loopHeight)
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: centerY),
            control1: CGPoint(x: centerX + loopWidth, y: centerY + loopHeight),
            control2: CGPoint(x: centerX, y: centerY + loopHeight)
        )
        
        // Ajouter la barre diagonale
        let barLength = width * 0.5
        let barAngle = -45.0 * (Double.pi / 180.0)
        
        let startX = centerX + cos(barAngle) * barLength
        let startY = centerY + sin(barAngle) * barLength
        let endX = centerX - cos(barAngle) * barLength
        let endY = centerY - sin(barAngle) * barLength
        
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        
        return path
    }
}

// MARK: - Particles View
struct ParticlesView: View {
    @Binding var animate: Bool
    let opacity: Double
    
    var body: some View {
        ZStack {
            ForEach(0..<15) { index in
                ParticleView(
                    animate: $animate,
                    delay: Double(index) * 0.2,
                    size: CGFloat.random(in: 2...6),
                    initialX: CGFloat.random(in: -200...200),
                    initialY: CGFloat.random(in: -400...400)
                )
                .opacity(opacity * 0.3)
            }
        }
    }
}

struct ParticleView: View {
    @Binding var animate: Bool
    let delay: Double
    let size: CGFloat
    let initialX: CGFloat
    let initialY: CGFloat
    
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.8, green: 0.6, blue: 1.0),
                        Color(red: 0.6, green: 0.8, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .offset(x: initialX, y: initialY + offsetY)
            .blur(radius: 1)
            .onChange(of: animate) { _, newValue in
                if newValue {
                    withAnimation(
                        Animation.linear(duration: Double.random(in: 8...15))
                            .repeatForever(autoreverses: false)
                            .delay(delay)
                    ) {
                        offsetY = -800
                    }
                }
            }
    }
}

// MARK: - Preview
#Preview {
    SplashScreen()
}
