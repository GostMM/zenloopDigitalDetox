//
//  DynamicComponents.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import SwiftUI

// MARK: - Dynamic Button avec Haptic Feedback

struct DynamicButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let style: ButtonStyle
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isLoading = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case danger
        case success
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .accentColor
            case .secondary: return Color(.systemGray5)
            case .danger: return .red
            case .success: return .green
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .danger, .success: return .white
            case .secondary: return .primary
            }
        }
        
        var shadowColor: Color {
            switch self {
            case .primary: return .accentColor.opacity(0.3)
            case .secondary: return .black.opacity(0.1)
            case .danger: return .red.opacity(0.3)
            case .success: return .green.opacity(0.3)
            }
        }
    }
    
    init(title: String, subtitle: String? = nil, icon: String, style: ButtonStyle = .primary, 
         hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.style = style
        self.hapticStyle = hapticStyle
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(style.foregroundColor)
                        .rotationEffect(.degrees(isPressed ? 5 : 0))
                        .animation(.easeInOut(duration: 0.1), value: isPressed)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(style.foregroundColor)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(style.foregroundColor.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(style.foregroundColor.opacity(0.7))
                    .offset(x: isPressed ? 3 : 0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(style.backgroundColor)
                    .shadow(
                        color: style.shadowColor,
                        radius: isPressed ? 5 : 10,
                        x: 0,
                        y: isPressed ? 2 : 5
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .disabled(isLoading)
    }
    
    private func performAction() {
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: hapticStyle)
        impactFeedback.impactOccurred()
        
        // Animation de chargement
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
        }
        
        // Exécuter l'action après un délai pour l'effet visuel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            action()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = false
            }
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: color.opacity(0.4),
                            radius: isPressed ? 8 : 15,
                            x: 0,
                            y: isPressed ? 4 : 8
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .rotationEffect(.degrees(rotationAngle))
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .animation(.easeInOut(duration: 0.3), value: rotationAngle)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func performAction() {
        // Feedback haptique fort
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Animation de rotation
        withAnimation(.easeInOut(duration: 0.3)) {
            rotationAngle += 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            action()
        }
    }
}

// MARK: - Quick Action Card avec animations

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: color.opacity(0.2),
                        radius: isPressed ? 5 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )
                
                // Effet shimmer
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 120)
                    .offset(x: shimmerOffset)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: shimmerOffset)
                    .onAppear {
                        shimmerOffset = 200
                    }
                
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundColor(color)
                        .scaleEffect(isPressed ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPressed)
                    
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func performAction() {
        // Feedback haptique léger
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Petit délai pour l'effet visuel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            action()
        }
    }
}

// MARK: - Toggle Switch animé

struct AnimatedToggle: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    let onColor: Color
    let action: ((Bool) -> Void)?
    
    @State private var dragOffset: CGFloat = 0
    
    init(title: String, icon: String, isOn: Binding<Bool>, onColor: Color = .accentColor, action: ((Bool) -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self._isOn = isOn
        self.onColor = onColor
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isOn ? onColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isOn)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? onColor : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 30)
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            }
            .onTapGesture {
                performToggle()
            }
        }
        .padding(.vertical, 8)
    }
    
    private func performToggle() {
        // Feedback haptique pour toggle
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        withAnimation {
            isOn.toggle()
        }
        
        action?(isOn)
    }
}

// MARK: - Progress Ring animé

struct AnimatedProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, color: Color = .accentColor, lineWidth: CGFloat = 8, size: CGFloat = 120) {
        // Vérifier et nettoyer la valeur de progress pour éviter les NaN
        if progress.isNaN || progress.isInfinite {
            self.progress = 0.0
        } else {
            self.progress = min(max(progress, 0.0), 1.0) // Clamp entre 0 et 1
        }
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.7), color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.5), value: animatedProgress)
        }
        .onAppear {
            let safeProgress = progress.isFinite ? min(max(progress, 0.0), 1.0) : 0.0
            animatedProgress = safeProgress
        }
        .onChange(of: progress) { _, newProgress in
            let safeProgress = newProgress.isFinite ? min(max(newProgress, 0.0), 1.0) : 0.0
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = safeProgress
            }
        }
    }
}

// MARK: - State Views

struct IdleStateView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "bolt.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Prêt pour un défi ?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Lance un défi pour bloquer tes distractions et rester concentré")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    QuickActionTile(
                        title: "Pomodoro",
                        subtitle: "25 min",
                        icon: "timer",
                        color: .red,
                        isEnabled: true
                    ) {
                        zenloopManager.startQuickChallenge(duration: 25 * 60)
                    }
                    
                    QuickActionTile(
                        title: "Focus",
                        subtitle: "50 min",
                        icon: "brain.head.profile",
                        color: .blue,
                        isEnabled: true
                    ) {
                        zenloopManager.startQuickChallenge(duration: 50 * 60)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ActiveChallengeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 24) {
            if let challenge = zenloopManager.currentChallenge {
                VStack(spacing: 20) {
                    // Progress Circle
                    ZStack {
                        Circle()
                            .stroke(Color.orange.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: challenge.safeProgress)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: challenge.safeProgress)
                        
                        VStack(spacing: 4) {
                            Text("\(challenge.progressPercentage)%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("Complété")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Text(challenge.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(challenge.timeRemaining)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        if challenge.blockedAppsCount > 0 {
                            VStack(spacing: 8) {
                                // Afficher les icônes des apps bloquées
                                SelectedAppsView(selection: zenloopManager.getAppsSelection(), maxDisplayCount: 5)
                                
                                // Garder BlockedAppsView en fallback si nécessaire
                                // BlockedAppsView(appNames: challenge.blockedAppsNames)
                                
                                // Afficher les tentatives d'ouverture
                                if challenge.appOpenAttempts > 0 {
                                    HStack {
                                        Image(systemName: "exclamationmark.shield")
                                            .foregroundColor(.orange)
                                        Text("\(challenge.appOpenAttempts) tentative(s) d'ouverture")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Button("Pause") {
                            print("🔘 [UI] BOUTON PAUSE PRESSÉ!")
                            zenloopManager.requestPause()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Arrêter") {
                            zenloopManager.stopCurrentChallenge()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

struct PausedChallengeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                VStack(spacing: 8) {
                    Text("Défi en pause")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Profite de ta pause de 5 minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let challenge = zenloopManager.currentChallenge {
                VStack(spacing: 16) {
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Text("Temps de pause restant:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(zenloopManager.pauseTimeRemaining)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                    
                    Button("Reprendre maintenant") {
                        print("🔘 [UI] BOUTON REPRENDRE PRESSÉ!")
                        zenloopManager.resumeChallenge()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct CompletedChallengeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: true)
                
                VStack(spacing: 8) {
                    Text("Félicitations ! 🎉")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Tu as terminé ton défi avec succès")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let challenge = zenloopManager.currentChallenge {
                VStack(spacing: 12) {
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("Durée")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(challenge.duration))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack {
                            Text("Apps bloquées")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(challenge.blockedAppsCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            Button("Nouveau défi") {
                zenloopManager.resetToIdle()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Blocked Apps View

struct BlockedAppsView: View {
    let appNames: [String]
    
    var body: some View {
        if !appNames.isEmpty {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(appNames.indices, id: \.self) { index in
                    let appName = appNames[index]
                    AppIconView(appName: appName)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

struct AppIconView: View {
    let appName: String
    @State private var appIcon: UIImage?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(appColor)
                    .frame(width: 40, height: 40)
                
                if let icon = appIcon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(appInitials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            Text(appName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            loadAppIcon()
        }
    }
    
    private var appInitials: String {
        let words = appName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(appName.prefix(2)).uppercased()
        }
    }
    
    private var appColor: Color {
        // Couleurs basées sur le hash du nom pour cohérence
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .indigo, .teal]
        let index = abs(appName.hashValue) % colors.count
        return colors[index]
    }
    
    private func loadAppIcon() {
        // Pour l'instant, ne pas charger les icônes pour éviter de bloquer l'UI
        // Cette fonctionnalité sera activée après optimisation
    }
}