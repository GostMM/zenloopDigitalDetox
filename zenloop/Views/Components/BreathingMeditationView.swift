//
//  BreathingMeditationView.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import AVKit
import AVFoundation

struct BreathingMeditationView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingOpacity: Double = 0.6
    @State private var currentPhase: BreathingPhase = .inhale
    @State private var videoPlayer: AVPlayer?
    @State private var selectedVideoName: String = ""
    @State private var isVideoEnded = false
    @State private var showDecisionSheet = false
    @State private var breathingTimer: Timer?
    @State private var hapticTimer: Timer?
    @State private var videoDuration: Double = 0
    @State private var currentBreathingCycle = 0
    @State private var tempVideoURL: URL?
    @State private var videoLoopCount = 0
    private let maxVideoLoops = 2
    
    // Vidéos disponibles
    private let availableVideos = [
        "0_Deer_Sunrise_1080x1920",
        "0_Mountain_Lake_2160x3840", 
        "0_Zebra_Wildlife_2160x3840"
    ]
    
    enum BreathingPhase {
        case inhale, hold, exhale, pause
        
        var duration: Double {
            switch self {
            case .inhale: return 4.0
            case .hold: return 4.0
            case .exhale: return 6.0
            case .pause: return 2.0
            }
        }
        
        var instruction: String {
            switch self {
            case .inhale: return "Inspirez"
            case .hold: return "Retenez"
            case .exhale: return "Expirez"
            case .pause: return "Pause"
            }
        }
        
        var scale: CGFloat {
            switch self {
            case .inhale: return 1.4
            case .hold: return 1.35
            case .exhale: return 0.7
            case .pause: return 0.75
            }
        }
        
        var opacity: Double {
            switch self {
            case .inhale: return 0.95
            case .hold: return 0.9
            case .exhale: return 0.3
            case .pause: return 0.35
            }
        }
        
        var animationCurve: Animation {
            switch self {
            case .inhale: return .easeOut(duration: duration)
            case .hold: return .linear(duration: duration)
            case .exhale: return .easeIn(duration: duration)
            case .pause: return .easeInOut(duration: duration)
            }
        }
        
        // Durée totale d'un cycle complet
        static var totalCycleDuration: Double {
            return BreathingPhase.inhale.duration + 
                   BreathingPhase.hold.duration + 
                   BreathingPhase.exhale.duration + 
                   BreathingPhase.pause.duration
        }
    }
    
    var body: some View {
        ZStack {
            // Vidéo de fond
            if let player = videoPlayer {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
                    .onDisappear {
                        player.pause()
                    }
            }
            
            // Overlay sombre pour le contraste
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.4),
                            .black.opacity(0.2),
                            .black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header minimaliste
                HStack {
                    Button(action: {
                        stopBreathingSession()
                        showDecisionSheet = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    Text("Respiration")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Espace pour équilibrer
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Zone de respiration centrale avec animation douce
                ZStack {
                    // Cercles concentriques
                    concentricCircles
                    
                    // Cercle central avec pulsation douce
                    centralBreathingCircle
                    
                    // Particules flottantes
                    floatingParticles
                    
                    // Instruction au centre avec style amélioré
                    breathingInstructions
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showContent)
                
                Spacer()
                
                // Instructions en bas
                VStack(spacing: 12) {
                    Text("Suivez le rythme du cercle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Respirez profondément et détendez-vous")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showContent)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            setupBreathingSession()
        }
        .onDisappear {
            cleanupSession()
        }
        .sheet(isPresented: $showDecisionSheet) {
            BreathingDecisionSheet(
                onContinue: {
                    // Reprendre la session (sortir de pause et fermer l'écran de respiration)
                    zenloopManager.resumeChallenge()
                    zenloopManager.showBreathingMeditation = false
                    showDecisionSheet = false
                    dismiss()
                },
                onStop: {
                    // Arrêter définitivement la session
                    zenloopManager.stopCurrentChallenge()
                    showDecisionSheet = false
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Setup & Cleanup
    
    private func setupBreathingSession() {
        // Sélectionner une vidéo aléatoire
        selectedVideoName = availableVideos.randomElement() ?? availableVideos[0]
        setupVideoPlayer()
        
        // Afficher le contenu avec animation
        withAnimation(.easeOut(duration: 1.0)) {
            showContent = true
        }
        
        print("🫁 [BREATHING] Session démarrée avec vidéo: \(selectedVideoName)")
    }
    
    private func setupVideoPlayer() {
        // Pour les vidéos dans Assets.xcassets datasets, nous devons utiliser NSDataAsset
        guard let dataAsset = NSDataAsset(name: selectedVideoName) else {
            print("❌ [BREATHING] DataAsset introuvable: \(selectedVideoName)")
            print("📁 [BREATHING] Tentative avec Bundle.main...")
            
            // Fallback : essayer directement dans le bundle
            if let videoURL = Bundle.main.url(forResource: selectedVideoName, withExtension: "mp4") {
                setupPlayerWithURL(videoURL)
                return
            }
            
            print("❌ [BREATHING] Vidéo non trouvée, utilisation d'une durée par défaut")
            // Utiliser une durée par défaut et démarrer la respiration sans vidéo
            videoDuration = 30.0 // 30 secondes par défaut
            startBreathingForDuration(videoDuration)
            return
        }
        
        print("✅ [BREATHING] DataAsset trouvé: \(selectedVideoName), taille: \(dataAsset.data.count) bytes")
        
        // Créer un fichier temporaire à partir du NSDataAsset
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempVideoURL = tempDirectory.appendingPathComponent("\(selectedVideoName).mp4")
        
        do {
            // Écrire les données de la vidéo dans un fichier temporaire
            try dataAsset.data.write(to: tempVideoURL)
            print("✅ [BREATHING] Vidéo écrite dans: \(tempVideoURL.path)")
            
            // Stocker l'URL pour nettoyage ultérieur
            self.tempVideoURL = tempVideoURL
            
            setupPlayerWithURL(tempVideoURL)
        } catch {
            print("❌ [BREATHING] Erreur écriture fichier temporaire: \(error)")
            // Fallback avec durée par défaut
            videoDuration = 30.0
            startBreathingForDuration(videoDuration)
        }
    }
    
    private func setupPlayerWithURL(_ url: URL) {
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.actionAtItemEnd = .none
        
        // Observer la fin de la vidéo pour la boucle
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer?.currentItem,
            queue: .main
        ) { _ in
            self.handleVideoLoop()
        }
        
        // Configurer l'audio pour ne pas interrompre les autres apps
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [BREATHING] Erreur configuration audio: \(error)")
        }
        
        // Démarrer la lecture et obtenir la durée après un court délai
        videoPlayer?.play()
        print("🎥 [BREATHING] Lecture vidéo démarrée: \(url.lastPathComponent)")
        
        // Obtenir la durée de la vidéo après un délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let duration = videoPlayer?.currentItem?.duration {
                let seconds = CMTimeGetSeconds(duration)
                if seconds.isFinite && seconds > 0 {
                    videoDuration = seconds
                    print("🎥 [BREATHING] Durée vidéo: \(seconds)s")
                    startBreathingForDuration(seconds)
                } else {
                    // Durée par défaut si impossible à obtenir
                    videoDuration = 30.0
                    startBreathingForDuration(videoDuration)
                }
            }
        }
    }
    
    private func startBreathingForDuration(_ duration: Double) {
        // La vidéo va jouer 2 fois, donc doubler la durée pour la respiration
        let totalDuration = duration * Double(maxVideoLoops)
        print("🫁 [BREATHING] Démarrage respiration pour \(totalDuration)s (\(duration)s × \(maxVideoLoops) boucles)")
        
        // Calculer combien de cycles de respiration pour la durée totale
        let cycleDuration = BreathingPhase.totalCycleDuration
        let numberOfCycles = Int(totalDuration / cycleDuration)
        
        print("🫁 [BREATHING] \(numberOfCycles) cycles de respiration (\(cycleDuration)s chacun)")
        
        startBreathingCycles(numberOfCycles)
    }
    
    private func handleVideoLoop() {
        videoLoopCount += 1
        print("🔄 [BREATHING] Boucle vidéo \(videoLoopCount)/\(maxVideoLoops)")
        
        if videoLoopCount < maxVideoLoops {
            // Relancer la vidéo depuis le début
            videoPlayer?.seek(to: .zero)
            videoPlayer?.play()
            print("🎥 [BREATHING] Relancement vidéo pour boucle \(videoLoopCount + 1)")
        } else {
            // Toutes les boucles terminées
            print("🎥 [BREATHING] Toutes les boucles vidéo terminées")
            handleVideoEnd()
        }
    }
    
    private func startBreathingCycles(_ totalCycles: Int) {
        currentBreathingCycle = 0
        startNextBreathingPhase()
        
        // Haptique synchrone avec chaque phase
        scheduleHapticForCurrentPhase()
    }
    
    private func startNextBreathingPhase() {
        guard currentBreathingCycle < getTotalCyclesNeeded() else {
            print("🫁 [BREATHING] Tous les cycles terminés")
            return
        }
        
        // Animation pour la phase actuelle avec courbe spécifique
        withAnimation(currentPhase.animationCurve) {
            breathingScale = currentPhase.scale
            breathingOpacity = currentPhase.opacity
        }
        
        // Programmer la phase suivante
        DispatchQueue.main.asyncAfter(deadline: .now() + currentPhase.duration) {
            self.switchToNextPhase()
            self.startNextBreathingPhase()
        }
    }
    
    private func getTotalCyclesNeeded() -> Int {
        let cycleDuration = BreathingPhase.totalCycleDuration
        return Int(videoDuration / cycleDuration) + 1
    }
    
    private func scheduleHapticForCurrentPhase() {
        triggerHapticFeedback()
        
        // Programmer le prochain haptique pour cette phase
        DispatchQueue.main.asyncAfter(deadline: .now() + currentPhase.duration) {
            if self.currentBreathingCycle < self.getTotalCyclesNeeded() {
                self.scheduleHapticForCurrentPhase()
            }
        }
    }
    
    
    private func switchToNextPhase() {
        switch currentPhase {
        case .inhale: 
            currentPhase = .hold
        case .hold: 
            currentPhase = .exhale  
        case .exhale: 
            currentPhase = .pause
        case .pause: 
            currentPhase = .inhale
            currentBreathingCycle += 1
            print("🫁 [BREATHING] Cycle \(currentBreathingCycle) terminé")
        }
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handleVideoEnd() {
        print("🎥 [BREATHING] Vidéo terminée")
        isVideoEnded = true
        showDecisionSheet = true
        stopBreathingSession()
    }
    
    private func stopBreathingSession() {
        breathingTimer?.invalidate()
        hapticTimer?.invalidate()
        videoPlayer?.pause()
        print("🫁 [BREATHING] Session arrêtée")
    }
    
    private func cleanupSession() {
        stopBreathingSession()
        NotificationCenter.default.removeObserver(self)
        
        // Nettoyer le fichier temporaire
        if let tempURL = tempVideoURL {
            do {
                try FileManager.default.removeItem(at: tempURL)
                print("🗑️ [BREATHING] Fichier temporaire supprimé: \(tempURL.path)")
            } catch {
                print("⚠️ [BREATHING] Impossible de supprimer fichier temporaire: \(error)")
            }
            tempVideoURL = nil
        }
        
        // Restaurer l'audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ [BREATHING] Erreur nettoyage audio: \(error)")
        }
    }
    
    private func getBreathingCount() -> String {
        // Compteur de cycles pour l'utilisateur
        switch currentPhase {
        case .inhale: return "1...2...3...4"
        case .hold: return "Maintenez..."
        case .exhale: return "1...2...3...4...5...6"
        case .pause: return "Relâchez..."
        }
    }
    
    // MARK: - Breathing Animation Components
    
    private var concentricCircles: some View {
        ForEach(0..<4, id: \.self) { index in
            let circleColor = getCircleColor(for: index)
            let circleScale = breathingScale * (1.0 - CGFloat(index) * 0.1)
            let circleOpacity = breathingOpacity * (1.0 - CGFloat(index) * 0.15)
            let circleSize = CGFloat(120 + index * 40)
            let blurRadius = CGFloat(1 + index)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            circleColor.opacity(0.1),
                            circleColor.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: CGFloat(80 + index * 20)
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(circleScale)
                .opacity(circleOpacity)
                .blur(radius: blurRadius)
        }
    }
    
    private var centralBreathingCircle: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [
                        .cyan.opacity(0.3),
                        .blue.opacity(0.4),
                        .purple.opacity(0.2),
                        .cyan.opacity(0.3)
                    ],
                    center: .center
                )
            )
            .frame(width: 80, height: 80)
            .scaleEffect(breathingScale * 0.6)
            .opacity(breathingOpacity + 0.3)
            .blur(radius: 1)
    }
    
    private var floatingParticles: some View {
        ForEach(0..<8, id: \.self) { particleIndex in
            FloatingParticle(
                index: particleIndex,
                color: getParticleColor(for: particleIndex),
                breathingScale: breathingScale,
                breathingOpacity: breathingOpacity
            )
        }
    }
    
    private var breathingInstructions: some View {
        VStack(spacing: 8) {
            Text(currentPhase.instruction)
                .font(.system(size: 26, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            Text(getBreathingCount())
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .opacity(breathingOpacity)
        }
    }
    
    // MARK: - Animation Colors Helpers
    
    private func getCircleColor(for index: Int) -> Color {
        let colors: [Color] = [.cyan, .blue, .purple, .indigo]
        return colors[index % colors.count]
    }
    
    private func getParticleColor(for index: Int) -> Color {
        let baseColors: [Color] = [
            .cyan.opacity(0.6),
            .blue.opacity(0.5),
            .purple.opacity(0.4),
            .indigo.opacity(0.3),
            .teal.opacity(0.5),
            .mint.opacity(0.4),
            .white.opacity(0.3),
            .cyan.opacity(0.4)
        ]
        return baseColors[index % baseColors.count]
    }
}

// MARK: - Floating Particle Component

struct FloatingParticle: View {
    let index: Int
    let color: Color
    let breathingScale: CGFloat
    let breathingOpacity: Double
    
    var body: some View {
        let angle = Double(index) * .pi / 4
        let baseRadius: Double = 60
        let dynamicRadius = baseRadius + breathingScale * 20
        let offsetX = cos(angle) * dynamicRadius
        let offsetY = sin(angle) * dynamicRadius
        
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(x: offsetX, y: offsetY)
            .opacity(breathingOpacity * 0.8)
            .scaleEffect(breathingScale * 0.5)
            .blur(radius: 0.5)
    }
}

// MARK: - Video Player View

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let playerView = PlayerUIView()
        playerView.player = player
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Rien à faire, le player est déjà configuré
    }
}

class PlayerUIView: UIView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    private var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = bounds
    }
}

// MARK: - Decision Sheet

struct BreathingDecisionSheet: View {
    let onContinue: () -> Void
    let onStop: () -> Void
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.12),
                    Color(red: 0.06, green: 0.03, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icône de méditation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.3), .blue.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.cyan)
                }
                .scaleEffect(showContent ? 1 : 0.8)
                .opacity(showContent ? 1 : 0)
                
                VStack(spacing: 16) {
                    Text("Moment de respiration terminé")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Que souhaitez-vous faire maintenant ?")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                VStack(spacing: 16) {
                    // Bouton Continuer
                    Button(action: onContinue) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Continuer la session")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Bouton Arrêter
                    Button(action: onStop) {
                        HStack(spacing: 12) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Arrêter et retourner à l'accueil")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
        }
    }
}

#Preview {
    BreathingMeditationView(zenloopManager: ZenloopManager.shared)
}