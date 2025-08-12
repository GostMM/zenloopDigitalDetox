//  BreathingMeditationView.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//  Updated with center-reveal animation + rich haptics on 10/08/2025.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreHaptics

// MARK: - Haptics Manager

final class HapticsManager: ObservableObject {
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let successNotif = UINotificationFeedbackGenerator()
    
    func prepare() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            // Fallback UIKit if CoreHaptics fails
            supportsHaptics = false
        }
    }
    
    func playPhase(_ phase: BreathingMeditationView.BreathingPhase) {
        if supportsHaptics {
            do {
                // Pattern: transient bump at start + gentle continuous curve for inhale/exhale
                let events: [CHHapticEvent]
                switch phase {
                case .inhale:
                    events = [
                        CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)],
                                      relativeTime: 0),
                        CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)],
                                      relativeTime: 0.02,
                                      duration: 0.35)
                    ]
                case .hold:
                    events = [
                        CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)],
                                      relativeTime: 0)
                    ]
                case .exhale:
                    events = [
                        CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)],
                                      relativeTime: 0),
                        CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)],
                                      relativeTime: 0.02,
                                      duration: 0.28)
                    ]
                case .pause:
                    events = [
                        CHHapticEvent(eventType: .hapticTransient,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.18),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)],
                                      relativeTime: 0)
                    ]
                }
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine?.makePlayer(with: pattern)
                try engine?.start()
                try player?.start(atTime: 0)
            } catch {
                // Fallback
                lightImpact.impactOccurred()
            }
        } else {
            // UIKit fallback mapping
            switch phase {
            case .inhale: mediumImpact.impactOccurred()
            case .hold: lightImpact.impactOccurred(intensity: 0.6)
            case .exhale: lightImpact.impactOccurred()
            case .pause: lightImpact.impactOccurred(intensity: 0.4)
            }
        }
    }
    
    func selection() {
        lightImpact.impactOccurred(intensity: 0.7)
    }
    
    func success() {
        successNotif.notificationOccurred(.success)
    }
}

// MARK: - Main View

struct BreathingMeditationView: View {
    @ObservedObject var zenloopManager: ZenloopManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var haptics = HapticsManager()
    
    @State private var showContent = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingOpacity: Double = 0.6
    @State private var currentPhase: BreathingPhase = .inhale
    
    @State private var videoPlayer: AVPlayer?
    @State private var selectedVideoName: String = ""
    @State private var isVideoEnded = false
    @State private var showDecisionSheet = false
    
    @State private var videoDuration: Double = 0
    @State private var currentBreathingCycle = 0
    @State private var tempVideoURL: URL?
    @State private var videoLoopCount = 0
    private let maxVideoLoops = 2
    
    // Cleanup control
    @State private var isSessionActive = false
    
    // Center reveal mask
    @State private var reveal = false
    
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
            case .inhale: return String(localized: "inhale")
            case .hold: return String(localized: "hold")
            case .exhale: return String(localized: "exhale")
            case .pause: return String(localized: "pause")
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
        
        static var totalCycleDuration: Double {
            inhale.duration + hold.duration + exhale.duration + pause.duration
        }
    }
    
    var body: some View {
        ZStack {
            // Background video with center-reveal mask
            GeometryReader { proxy in
                let size = proxy.size
                if let player = videoPlayer {
                    VideoPlayerView(player: player)
                        .ignoresSafeArea()
                        .mask(
                            // Circular mask that scales from center to reveal the video
                            Circle()
                                .frame(width: 10, height: 10)
                                .scaleEffect(reveal ? revealTargetScale(for: size) : 0.001, anchor: .center)
                                .position(x: size.width / 2, y: size.height / 2)
                                .animation(.spring(response: 0.9, dampingFraction: 0.85).speed(0.9), value: reveal)
                        )
                        .onDisappear { player.pause() }
                        .onAppear {
                            // Ensure the mask opens shortly after view appears to feel “cinematic”
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                reveal = true
                            }
                        }
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            
            // Subtle vignette for contrast
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0.2), .black.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        haptics.selection()
                        isSessionActive = false
                        stopBreathingSession()
                        showDecisionSheet = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                    
                    Text(String(localized: "breathing"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Breathing core
                ZStack {
                    concentricCircles
                    centralBreathingCircle
                    breathingHalo
                    floatingParticles
                    breathingInstructions
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.82), value: showContent)
                
                Spacer()
                
                // Bottom tips
                VStack(spacing: 12) {
                    Text(String(localized: "follow_circle_rhythm"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(String(localized: "breathe_deeply_relax"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.25), value: showContent)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isSessionActive = true
            haptics.prepare()
            setupBreathingSession()
        }
        .onDisappear {
            isSessionActive = false
            cleanupSession()
        }
        .sheet(isPresented: $showDecisionSheet) {
            BreathingDecisionSheet(
                onContinue: {
                    haptics.selection()
                    zenloopManager.resumeChallenge()
                    zenloopManager.showBreathingMeditation = false
                    showDecisionSheet = false
                    dismiss()
                },
                onStop: {
                    haptics.success()
                    zenloopManager.stopCurrentChallenge()
                    showDecisionSheet = false
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Setup & Cleanup
    
    private func setupBreathingSession() {
        selectedVideoName = availableVideos.randomElement() ?? availableVideos[0]
        setupVideoPlayer()
        
        withAnimation(.easeOut(duration: 0.9)) {
            showContent = true
        }
        
        print("🫁 [BREATHING] Session démarrée avec vidéo: \(selectedVideoName)")
    }
    
    private func setupVideoPlayer() {
        // Try NSDataAsset first (Assets Catalog)
        if let dataAsset = NSDataAsset(name: selectedVideoName) {
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempVideoURL = tempDirectory.appendingPathComponent("\(selectedVideoName).mp4")
            do {
                try dataAsset.data.write(to: tempVideoURL)
                self.tempVideoURL = tempVideoURL
                setupPlayerWithURL(tempVideoURL)
                return
            } catch {
                print("❌ [BREATHING] Erreur écriture fichier temp: \(error)")
            }
        }
        // Fallback: bundle resource
        if let url = Bundle.main.url(forResource: selectedVideoName, withExtension: "mp4") {
            setupPlayerWithURL(url)
            return
        }
        
        // Final fallback: no video, just run breathing for default duration
        videoDuration = 30.0
        startBreathingForDuration(videoDuration)
    }
    
    private func setupPlayerWithURL(_ url: URL) {
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.actionAtItemEnd = .none
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer?.currentItem,
            queue: .main
        ) { _ in
            self.handleVideoLoop()
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [BREATHING] Erreur configuration audio: \(error)")
        }
        
        videoPlayer?.play()
        print("🎥 [BREATHING] Lecture vidéo: \(url.lastPathComponent)")
        
        // Determine duration shortly after playback starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let duration = videoPlayer?.currentItem?.duration {
                let seconds = CMTimeGetSeconds(duration)
                self.videoDuration = (seconds.isFinite && seconds > 0) ? seconds : 30.0
            } else {
                self.videoDuration = 30.0
            }
            startBreathingForDuration(self.videoDuration)
        }
    }
    
    private func startBreathingForDuration(_ duration: Double) {
        let totalDuration = duration * Double(maxVideoLoops)
        let cycleDuration = BreathingPhase.totalCycleDuration
        let cycles = max(1, Int(totalDuration / cycleDuration))
        
        currentBreathingCycle = 0
        currentPhase = .inhale
        // Kick first phase haptic immediately to “lock” user into rhythm
        haptics.playPhase(.inhale)
        animatePhase(.inhale)
        scheduleNextPhase()
        
        print("🫁 [BREATHING] Durée totale ~\(Int(totalDuration))s, cycles ≈ \(cycles)")
    }
    
    private func scheduleNextPhase() {
        DispatchQueue.main.asyncAfter(deadline: .now() + currentPhase.duration) {
            // ✅ Vérifier si la session est toujours active avant de continuer
            guard self.isSessionActive else {
                print("🫁 [BREATHING] Session fermée - arrêt des animations")
                return
            }
            
            self.switchToNextPhase()
            self.animatePhase(self.currentPhase)
            self.haptics.playPhase(self.currentPhase)
            if self.shouldContinueBreathing() {
                self.scheduleNextPhase()
            }
        }
    }
    
    private func animatePhase(_ phase: BreathingPhase) {
        withAnimation(phase.animationCurve) {
            breathingScale = phase.scale
            breathingOpacity = phase.opacity
        }
    }
    
    private func switchToNextPhase() {
        switch currentPhase {
        case .inhale: currentPhase = .hold
        case .hold: currentPhase = .exhale
        case .exhale: currentPhase = .pause
        case .pause:
            currentPhase = .inhale
            currentBreathingCycle += 1
            print("🫁 [BREATHING] Cycle \(currentBreathingCycle) terminé")
        }
    }
    
    private func shouldContinueBreathing() -> Bool {
        // Continue seulement si session active et vidéo pas terminée
        return isSessionActive && !isVideoEnded
    }
    
    private func handleVideoLoop() {
        videoLoopCount += 1
        print("🔄 [BREATHING] Boucle vidéo \(videoLoopCount)/\(maxVideoLoops)")
        if videoLoopCount < maxVideoLoops {
            videoPlayer?.seek(to: .zero)
            videoPlayer?.play()
        } else {
            handleVideoEnd()
        }
    }
    
    private func handleVideoEnd() {
        print("🎥 [BREATHING] Vidéo terminée")
        isVideoEnded = true
        haptics.success()
        showDecisionSheet = true
        stopBreathingSession()
    }
    
    private func stopBreathingSession() {
        isSessionActive = false
        videoPlayer?.pause()
        print("🫁 [BREATHING] Session arrêtée")
    }
    
    private func cleanupSession() {
        print("🧹 [BREATHING] Cleanup complet - arrêt de toutes les animations")
        
        // ✅ Arrêter immédiatement toutes les animations en cours
        isSessionActive = false
        isVideoEnded = true
        
        // ✅ Cleanup video et notifications
        NotificationCenter.default.removeObserver(self)
        videoPlayer?.pause()
        videoPlayer = nil
        
        // ✅ Cleanup fichiers temporaires
        if let tempURL = tempVideoURL {
            try? FileManager.default.removeItem(at: tempURL)
            tempVideoURL = nil
        }
        
        // ✅ Cleanup session audio
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ [BREATHING] Erreur cleanup audio: \(error)")
        }
        
        // ✅ Reset des états d'animation
        breathingScale = 1.0
        breathingOpacity = 0.6
        currentBreathingCycle = 0
        videoLoopCount = 0
        
        print("✅ [BREATHING] Cleanup terminé")
    }
    
    // MARK: - Helpers
    
    private func revealTargetScale(for size: CGSize) -> CGFloat {
        // Base circle is 10pt; we need diameter >= diagonal to fully reveal
        let diagonal = sqrt(size.width * size.width + size.height * size.height)
        let target = (diagonal / 10.0) * 1.15 // margin
        return max(target, 1.0)
    }
    
    private func getBreathingCount() -> String {
        switch currentPhase {
        case .inhale: return String(localized: "count_inhale")
        case .hold: return String(localized: "count_hold")
        case .exhale: return String(localized: "count_exhale")
        case .pause: return String(localized: "count_pause")
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
                        colors: [circleColor.opacity(0.1),
                                 circleColor.opacity(0.05),
                                 .clear],
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
    
    // Subtle glowing ring that breathes
    private var breathingHalo: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [.cyan.opacity(0.6), .blue.opacity(0.55), .purple.opacity(0.45), .cyan.opacity(0.6)],
                    center: .center
                ),
                lineWidth: 2.0
            )
            .frame(width: 150, height: 150)
            .scaleEffect(breathingScale * 0.9)
            .opacity(breathingOpacity * 0.8)
            .blur(radius: 1.2)
            .shadow(color: .cyan.opacity(0.35), radius: 8, x: 0, y: 0)
    }
    
    private var centralBreathingCircle: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [
                        .cyan.opacity(0.35),
                        .blue.opacity(0.45),
                        .purple.opacity(0.25),
                        .cyan.opacity(0.35)
                    ],
                    center: .center
                )
            )
            .frame(width: 84, height: 84)
            .scaleEffect(breathingScale * 0.62)
            .opacity(min(1.0, breathingOpacity + 0.3))
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
                .foregroundColor(.white.opacity(0.85))
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
            .white.opacity(0.35),
            .cyan.opacity(0.45)
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
        let baseRadius: Double = 62
        let dynamicRadius = baseRadius + Double(breathingScale) * 18
        let offsetX = cos(angle) * dynamicRadius
        let offsetY = sin(angle) * dynamicRadius
        
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(x: offsetX, y: offsetY)
            .opacity(breathingOpacity * 0.85)
            .scaleEffect(breathingScale * 0.5)
            .blur(radius: 0.6)
    }
}

// MARK: - Video Player View

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

final class PlayerUIView: UIView {
    var player: AVPlayer? { didSet { playerLayer.player = player } }
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
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
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.02, blue: 0.12),
                         Color(red: 0.06, green: 0.03, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.3), .blue.opacity(0.1)],
                                center: .center, startRadius: 0, endRadius: 50
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
                    Text(String(localized: "breathing_moment_completed"))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(String(localized: "what_would_you_like_to_do"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                VStack(spacing: 16) {
                    Button(action: onContinue) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(String(localized: "continue_session"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button(action: onStop) {
                        HStack(spacing: 12) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(String(localized: "stop_return_home"))
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
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.2)) {
                showContent = true
            }
        }
    }
}

#Preview {
    BreathingMeditationView(zenloopManager: ZenloopManager.shared)
}
