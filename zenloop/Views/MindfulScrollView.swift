//
//  MindfulScrollView.swift
//  zenloop
//
//  Alternative saine au scroll addictif - Comme une cigarette électronique pour les scrollers
//

import SwiftUI

struct MindfulScrollView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @State private var showContent = false
    @State private var scrollTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var scrollCount = 0
    @State private var displayedCards: [MindfulContent] = []
    @State private var contentPool: [MindfulContent] = []

    private let cardsPerLoad = 10
    private let maxCards = 50 // Limite pour optimiser la mémoire

    var body: some View {
        ZStack {
            // Background apaisant
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header avec compteur de temps
                mindfulHeader

                // Zone de scroll infini
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 40) {
                            // Message d'introduction
                            introCard
                                .id("intro")

                            // Contenu infini avec recyclage
                            ForEach(displayedCards.indices, id: \.self) { index in
                                mindfulCard(content: displayedCards[index], index: index)
                                    .id("card-\(index)")
                                    .onAppear {
                                        // Charger plus de contenu quand on approche de la fin
                                        if index == displayedCards.count - 3 {
                                            loadMoreContent()
                                        }
                                    }
                            }

                            // Indicateur de continuation
                            continuationIndicator

                            Spacer(minLength: 200)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                .coordinateSpace(name: "scroll")
            }

            // Overlay de conscientisation si scroll trop longtemps
            if scrollTime > 60 {
                awarenessOverlay
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
            initializeContent()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Infinite Scroll Logic

    private func initializeContent() {
        // Initialiser le pool de contenu varié
        contentPool = generateContentPool()
        // Charger le premier batch
        loadMoreContent()
    }

    private func loadMoreContent() {
        guard displayedCards.count < maxCards else {
            // Si on atteint la limite, recycler les anciennes cartes
            recycleOldCards()
            return
        }

        // Ajouter de nouvelles cartes variées
        let newCards = getRandomCards(count: cardsPerLoad)
        displayedCards.append(contentsOf: newCards)
        scrollCount += cardsPerLoad

        print("📜 [MINDFUL] Loaded \(newCards.count) new cards. Total: \(displayedCards.count)")
    }

    private func recycleOldCards() {
        // Garder seulement les 30 dernières cartes et en ajouter 10 nouvelles
        if displayedCards.count > 30 {
            displayedCards.removeFirst(20)
        }
        let newCards = getRandomCards(count: 10)
        displayedCards.append(contentsOf: newCards)

        print("♻️ [MINDFUL] Recycled cards. Total: \(displayedCards.count)")
    }

    private func getRandomCards(count: Int) -> [MindfulContent] {
        var cards: [MindfulContent] = []
        for _ in 0..<count {
            if let randomCard = contentPool.randomElement() {
                cards.append(randomCard)
            }
        }
        return cards
    }

    private func generateContentPool() -> [MindfulContent] {
        // Créer un pool de 50+ contenus variés
        var pool: [MindfulContent] = []

        // Quotes (15)
        pool.append(contentsOf: generateQuotes())

        // Progress messages (10)
        pool.append(contentsOf: generateProgressMessages())

        // Insights (10)
        pool.append(contentsOf: generateInsights())

        // Affirmations (10)
        pool.append(contentsOf: generateAffirmations())

        // Reminders (5)
        pool.append(contentsOf: generateReminders())

        return pool
    }

    // MARK: - Header

    private var mindfulHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "mindful_scroll"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(localized: "scroll_consciously"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Temps de scroll
                ScrollTimeIndicator(time: scrollTime)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Barre de respiration
            BreathingBar(isAnimating: showContent)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Cards

    private var introCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "infinity")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.cyan)

            Text(String(localized: "mindful_scroll_intro"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(String(localized: "mindful_scroll_description"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .cyan.opacity(0.1), radius: 20)
    }

    private func mindfulCard(content: MindfulContent, index: Int) -> some View {
        VStack(spacing: 20) {
            // Icône
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [content.color.opacity(0.3), content.color.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: content.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(content.color)
            }

            // Type de contenu
            Text(content.category)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(content.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(content.color.opacity(0.2), in: Capsule())

            // Texte principal
            Text(content.text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            // Sous-texte optionnel
            if let subtext = content.subtext {
                Text(subtext)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            // Animation de particules
            ParticleEffect(color: content.color)
                .frame(height: 60)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [content.color.opacity(0.4), content.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: content.color.opacity(0.15), radius: 25)
    }

    private var continuationIndicator: some View {
        VStack(spacing: 16) {
            // Animation de points
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 10, height: 10)
                        .opacity(showContent ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: showContent
                        )
                }
            }

            Text("Scrolle pour découvrir plus...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            // Message de scroll count
            if scrollCount > 20 {
                Text("Tu as scrollé \(scrollCount) cartes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.7))
            }
        }
        .padding(.vertical, 40)
    }

    private var finalCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text(String(localized: "youve_scrolled_enough"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(String(localized: "time_to_take_action"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: {
                // Retour à l'accueil ou démarrer une session
                NotificationCenter.default.post(name: .navigateToHome, object: nil)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                    Text(String(localized: "start_focus_session"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Awareness Overlay

    private var awarenessOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Fermer en tapant sur le fond
                    dismissAwarenessOverlay()
                }

            VStack(spacing: 20) {
                // Header avec bouton close
                HStack {
                    Spacer()
                    Button(action: {
                        dismissAwarenessOverlay()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Image(systemName: "clock.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text(String(localized: "awareness_check"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(String(localized: "youve_been_scrolling_for"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text(formatTime(scrollTime))
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.orange)

                Text(String(localized: "time_to_do_something_meaningful"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Deux boutons d'action
                VStack(spacing: 12) {
                    // Bouton principal : Passer à l'action
                    Button(action: {
                        stopTimer()
                        NotificationCenter.default.post(name: .navigateToHome, object: nil)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(String(localized: "take_action"))
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }

                    // Bouton secondaire : Continuer à scroller
                    Button(action: {
                        dismissAwarenessOverlay()
                    }) {
                        Text(String(localized: "continue_scrolling"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .padding(20)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: scrollTime)
    }

    private func dismissAwarenessOverlay() {
        // Reset le timer pour ne pas réafficher immédiatement
        stopTimer() // Important: stopper l'ancien timer d'abord
        scrollTime = 0
        startTimer() // Puis redémarrer un nouveau
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            scrollTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Supporting Views

struct ScrollTimeIndicator: View {
    let time: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))

            Text(formatTime(time))
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
        }
        .foregroundColor(time > 60 ? .orange : .cyan)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct BreathingBar: View {
    let isAnimating: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(.white.opacity(0.1))

                // Animated bar
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * phase)
            }
        }
        .frame(height: 4)
        .onAppear {
            if isAnimating {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    phase = 1.0
                }
            }
        }
    }
}

struct ParticleEffect: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        HStack(spacing: 15) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(y: animate ? -20 : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Data Models

struct MindfulContent {
    let icon: String
    let color: Color
    let category: String
    let text: String
    let subtext: String?
}

extension MindfulScrollView {
    // MARK: - Content Generators

    func generateQuotes() -> [MindfulContent] {
        [
            MindfulContent(icon: "leaf.fill", color: .green, category: "Quote", text: "Le moment présent est tout ce que tu as.", subtext: nil),
            MindfulContent(icon: "leaf.fill", color: .green, category: "Quote", text: "La simplicité est la sophistication ultime.", subtext: nil),
            MindfulContent(icon: "cloud.fill", color: .blue, category: "Quote", text: "Chaque respiration est une opportunité de recommencer.", subtext: nil),
            MindfulContent(icon: "star.fill", color: .yellow, category: "Quote", text: "Tu es exactement là où tu dois être.", subtext: nil),
            MindfulContent(icon: "heart.fill", color: .pink, category: "Quote", text: "L'attention est le cadeau le plus précieux.", subtext: nil),
            MindfulContent(icon: "flame.fill", color: .orange, category: "Quote", text: "Ton énergie va où va ton attention.", subtext: nil),
            MindfulContent(icon: "wind", color: .cyan, category: "Quote", text: "Laisse aller ce qui ne te sert plus.", subtext: nil),
            MindfulContent(icon: "sun.max.fill", color: .orange, category: "Quote", text: "Chaque jour est une page blanche.", subtext: nil),
            MindfulContent(icon: "moon.stars.fill", color: .indigo, category: "Quote", text: "Le silence est la réponse à de nombreuses questions.", subtext: nil),
            MindfulContent(icon: "sparkles", color: .purple, category: "Quote", text: "Tu es plus fort que tu ne le penses.", subtext: nil),
            MindfulContent(icon: "leaf.fill", color: .green, category: "Quote", text: "La paix commence par un sourire.", subtext: nil),
            MindfulContent(icon: "water.waves", color: .blue, category: "Quote", text: "Coule comme l'eau, ne résiste pas au changement.", subtext: nil),
            MindfulContent(icon: "mountain.2.fill", color: .gray, category: "Quote", text: "Les obstacles sont des opportunités déguisées.", subtext: nil),
            MindfulContent(icon: "tree.fill", color: .green, category: "Quote", text: "Grandis lentement, mais avec des racines profondes.", subtext: nil),
            MindfulContent(icon: "eye.fill", color: .purple, category: "Quote", text: "Ce que tu cherches te cherche aussi.", subtext: nil)
        ]
    }

    func generateProgressMessages() -> [MindfulContent] {
        let hours = [5, 8, 12, 15, 20, 25, 30]
        let days = [3, 5, 7, 10, 14, 21, 30]

        var messages: [MindfulContent] = []

        messages.append(MindfulContent(icon: "chart.line.uptrend.xyaxis", color: .cyan, category: "Progrès", text: "Tu as récupéré \(hours.randomElement()!)h cette semaine", subtext: "Continue, tu es sur la bonne voie !"))
        messages.append(MindfulContent(icon: "flame.fill", color: .orange, category: "Streak", text: "\(days.randomElement()!) jours de concentration", subtext: "Ta discipline paye !"))
        messages.append(MindfulContent(icon: "star.fill", color: .yellow, category: "Progrès", text: "Tu as bloqué \(Int.random(in: 50...200)) tentatives de distraction", subtext: "Impressionnant !"))
        messages.append(MindfulContent(icon: "trophy.fill", color: .yellow, category: "Progrès", text: "\(Int.random(in: 10...50)) sessions terminées", subtext: "Tu builds une habitude solide !"))
        messages.append(MindfulContent(icon: "chart.bar.fill", color: .purple, category: "Stats", text: "+\(Int.random(in: 20...80))% de productivité", subtext: "Par rapport au mois dernier"))
        messages.append(MindfulContent(icon: "clock.fill", color: .green, category: "Temps", text: "\(Int.random(in: 2...8))h de deep work aujourd'hui", subtext: "C'est ton meilleur score !"))
        messages.append(MindfulContent(icon: "checkmark.seal.fill", color: .blue, category: "Achievement", text: "Niveau Focus : Expert", subtext: "Tu es dans le top 10% !"))
        messages.append(MindfulContent(icon: "target", color: .cyan, category: "Objectif", text: "Plus que \(Int.random(in: 1...5)) jours", subtext: "Pour atteindre ton objectif hebdo"))
        messages.append(MindfulContent(icon: "medal.fill", color: .yellow, category: "Badge", text: "Nouveau badge débloqué !", subtext: "Maître de la concentration"))
        messages.append(MindfulContent(icon: "arrow.up.right.circle.fill", color: .green, category: "Croissance", text: "+\(Int.random(in: 15...45))% cette semaine", subtext: "Ta meilleure semaine !"))

        return messages
    }

    func generateInsights() -> [MindfulContent] {
        [
            MindfulContent(icon: "brain.head.profile", color: .purple, category: "Insight", text: "Chaque résistance à la distraction renforce ton muscle de focus.", subtext: nil),
            MindfulContent(icon: "lightbulb.fill", color: .yellow, category: "Insight", text: "Les premiers 5 minutes sont les plus difficiles. Après, c'est du flow.", subtext: nil),
            MindfulContent(icon: "eye.fill", color: .cyan, category: "Insight", text: "Ton téléphone est un outil, pas un maître.", subtext: nil),
            MindfulContent(icon: "bolt.fill", color: .orange, category: "Insight", text: "90 minutes de focus profond = 8h de travail distrait.", subtext: nil),
            MindfulContent(icon: "figure.mind.and.body", color: .purple, category: "Insight", text: "Le multitasking est un mythe. Le monotasking est un superpouvoir.", subtext: nil),
            MindfulContent(icon: "hourglass", color: .blue, category: "Insight", text: "Ton attention est limitée. Choisis bien où tu la mets.", subtext: nil),
            MindfulContent(icon: "shield.fill", color: .green, category: "Insight", text: "Bloquer des apps = créer un espace pour ce qui compte.", subtext: nil),
            MindfulContent(icon: "lock.fill", color: .red, category: "Insight", text: "Les notifications sont des voleurs de présence.", subtext: nil),
            MindfulContent(icon: "timer", color: .orange, category: "Insight", text: "25 min de focus > 2h de pseudo-travail.", subtext: nil),
            MindfulContent(icon: "sparkles", color: .purple, category: "Insight", text: "La clarté vient du silence, pas du bruit.", subtext: nil)
        ]
    }

    func generateAffirmations() -> [MindfulContent] {
        [
            MindfulContent(icon: "heart.fill", color: .pink, category: "Affirmation", text: "Je contrôle mon attention et mon temps.", subtext: nil),
            MindfulContent(icon: "hand.raised.fill", color: .orange, category: "Affirmation", text: "Je choisis la présence plutôt que la distraction.", subtext: nil),
            MindfulContent(icon: "figure.walk", color: .green, category: "Affirmation", text: "Chaque petit pas compte.", subtext: nil),
            MindfulContent(icon: "star.fill", color: .yellow, category: "Affirmation", text: "Je suis capable de focus profond.", subtext: nil),
            MindfulContent(icon: "bolt.heart.fill", color: .pink, category: "Affirmation", text: "Mon énergie est précieuse et je la protège.", subtext: nil),
            MindfulContent(icon: "shield.lefthalf.filled", color: .blue, category: "Affirmation", text: "Je crée des limites saines avec la technologie.", subtext: nil),
            MindfulContent(icon: "checkmark.circle.fill", color: .green, category: "Affirmation", text: "Je progresse chaque jour, même lentement.", subtext: nil),
            MindfulContent(icon: "crown.fill", color: .yellow, category: "Affirmation", text: "Je suis le maître de mes habitudes.", subtext: nil),
            MindfulContent(icon: "sparkle", color: .purple, category: "Affirmation", text: "Ma concentration est mon superpouvoir.", subtext: nil),
            MindfulContent(icon: "leaf.fill", color: .green, category: "Affirmation", text: "Je mérite des moments de paix.", subtext: nil)
        ]
    }

    func generateReminders() -> [MindfulContent] {
        [
            MindfulContent(icon: "lungs.fill", color: .cyan, category: "Rappel", text: "Remarque comment tu te sens là, maintenant.", subtext: "Prends une grande inspiration."),
            MindfulContent(icon: "heart.text.square.fill", color: .pink, category: "Rappel", text: "Quand as-tu regardé un proche dans les yeux pour la dernière fois ?", subtext: nil),
            MindfulContent(icon: "sun.horizon.fill", color: .orange, category: "Rappel", text: "As-tu vu le ciel aujourd'hui ?", subtext: nil),
            MindfulContent(icon: "drop.fill", color: .blue, category: "Rappel", text: "Hydrate-toi, ton cerveau en a besoin.", subtext: nil),
            MindfulContent(icon: "figure.stand", color: .green, category: "Rappel", text: "Lève-toi et étire-toi, même 30 secondes.", subtext: nil)
        ]
    }
}

// Navigation is handled via existing notification in ContentView.swift

#Preview {
    MindfulScrollView()
        .environmentObject(ZenloopManager.shared)
}
