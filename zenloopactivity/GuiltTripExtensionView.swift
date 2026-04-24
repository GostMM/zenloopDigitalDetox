//
//  GuiltTripExtensionView.swift
//  zenloopactivity (Extension)
//
//  Vue "Culpabilisation" — redesign centré sur l'impact émotionnel.
//  Uniquement utilisée dans l'onboarding (après le grant Screen Time).
//
//  Séquence :
//  1. Écran noir + compteur vertigineux qui explose à la vraie valeur
//  2. Verdict tranchant ("Addictif / Excessif / À surveiller / Sain")
//  3. Phrase choc personnalisée
//  4. Extrapolation vie entière ("Si tu continues comme ça...")
//  5. Ce que tu aurais pu faire avec ce temps (livres, films, sport, sommeil)
//  6. Top 3 apps voleuses
//

import SwiftUI
import DeviceActivity
import os

private let logger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "GuiltTrip")

// MARK: - Equivalence model

private struct GuiltEquivalence: Identifiable {
    let id = UUID()
    let emoji: String
    let headline: String
    let body: String
}

// MARK: - Phase d'animation

private enum RevealPhase: Int, Comparable {
    case blackout = 0
    case counterSpin = 1
    case counterDone = 2
    case verdictReveal = 3
    case bodyReveal = 4

    static func < (lhs: RevealPhase, rhs: RevealPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Vue principale

struct GuiltTripExtensionView: View {
    let reportData: ExtensionActivityReport

    @State private var phase: RevealPhase = .blackout
    @State private var displayedSeconds: Double = 0
    @State private var counterTimer: Timer?
    @State private var redPulse = false

    private var todaySeconds: Double { reportData.todayScreenSeconds }
    private var averageSeconds: Double { reportData.averageDaily }
    private var todayMinutes: Double { todaySeconds / 60 }
    private var todayHours: Double { todaySeconds / 3600 }

    // Espérance de vie moyenne mondiale : 73 ans. On considère ~55 ans restants
    // comme fenêtre d'extrapolation pour un utilisateur type (un peu moins que la
    // réalité, ce qui rend le chiffre plus conservateur donc plus crédible).
    private let lifetimeYearsRemaining: Double = 55

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            // Phase 1 — Hero centré plein écran pendant que le compteur spin
            if phase < .bodyReveal {
                heroSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            // Phase 2 — Hero remonte en haut, le reste du contenu apparaît
            if phase >= .bodyReveal {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.top, 60)
                            .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Les voleurs juste après le hero — premier impact visuel après le verdict
                        if !reportData.allApps.isEmpty {
                            topAppsSection
                                .padding(.top, 40)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        verdictBanner
                            .padding(.top, 32)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        shockPhraseSection
                            .padding(.top, 28)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        lifetimeSection
                            .padding(.top, 36)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        equivalencesSection
                            .padding(.top, 36)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        Spacer().frame(height: 160)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startRevealSequence()
            logger.critical("🚀 [GUILT] appeared — today=\(todaySeconds)s avg=\(averageSeconds)s apps=\(reportData.allApps.count)")
        }
        .onDisappear { counterTimer?.invalidate() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black

            // Halo rouge qui pulse depuis le haut — plus présent pour phases avancées
            RadialGradient(
                colors: [
                    guiltColor.opacity(phase >= .verdictReveal ? 0.18 : 0.04),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.15),
                startRadius: 0,
                endRadius: 400
            )
            .animation(.easeInOut(duration: 1.0), value: phase)

            // Vignette basse
            LinearGradient(
                colors: [.clear, .black.opacity(0.95)],
                startPoint: .center, endPoint: .bottom
            )
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 18) {
            // Label minuscule
            Text("TEMPS D'ÉCRAN AUJOURD'HUI")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundColor(.white.opacity(phase >= .counterSpin ? 0.35 : 0))
                .animation(.easeIn(duration: 0.4), value: phase)

            // Compteur massif monospaced — vibe "dommage de la journée"
            ZStack {
                // Halo flou derrière le chiffre
                if phase >= .counterDone {
                    Text(formattedTime(displayedSeconds))
                        .font(.system(size: 84, weight: .black, design: .rounded))
                        .foregroundColor(guiltColor.opacity(0.35))
                        .blur(radius: 24)
                        .scaleEffect(redPulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: redPulse)
                }

                Text(formattedTime(displayedSeconds))
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .scaleEffect(phase == .counterDone ? 1.08 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.38), value: phase)
            }
            .opacity(phase >= .counterSpin ? 1 : 0)
            .frame(height: 100)

            // Dot + verdict mini
            if phase >= .verdictReveal {
                HStack(spacing: 8) {
                    Circle()
                        .fill(guiltColor)
                        .frame(width: 7, height: 7)
                        .scaleEffect(redPulse ? 1.3 : 0.9)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: redPulse)
                    Text(verdictLabel.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2.2)
                        .foregroundColor(guiltColor)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Verdict banner

    private var verdictBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: verdictIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(guiltColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verdictHeadline)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(verdictSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(guiltColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(guiltColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Shock phrase

    private var shockPhraseSection: some View {
        Text(shockPhrase)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Lifetime section (the new punchline)

    private var lifetimeSection: some View {
        let totalLifetimeHours = todayHours * 365 * lifetimeYearsRemaining
        let totalLifetimeDays = totalLifetimeHours / 24
        let totalLifetimeYears = totalLifetimeDays / 365

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Si tu continues comme ça…")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formattedLargeNumber(totalLifetimeYears))
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, guiltColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text(totalLifetimeYears >= 1 ? "ANS" : "MOIS")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.55))
                }

                Text("passés sur ton téléphone jusqu'à la fin de ta vie,\nau rythme actuel.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Equivalences

    private var equivalencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Ce que tu aurais pu faire")

            VStack(spacing: 14) {
                ForEach(equivalences) { equiv in
                    HStack(spacing: 14) {
                        Text(equiv.emoji)
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.05)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(equiv.headline)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(equiv.body)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Top Apps (voleurs de temps)

    private var topAppsSection: some View {
        let apps = Array(reportData.allApps.prefix(3))
        let totalTop = apps.reduce(0.0) { $0 + $1.duration }

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(stealColor(index: 0))
                Text("LES VOLEURS DE TON TEMPS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2)
            }

            VStack(spacing: 12) {
                ForEach(0..<apps.count, id: \.self) { index in
                    let app = apps[index]
                    let pct = totalTop > 0 ? app.duration / totalTop : 0

                    HStack(spacing: 16) {
                        // Rang
                        Text("\(index + 1)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(stealColor(index: index).opacity(0.9))
                            .frame(width: 34)

                        #if os(iOS)
                        AppIconBadge(app: app, size: 52)
                        #endif

                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(formattedTime(app.duration))
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [stealColor(index: index), stealColor(index: index).opacity(0.7)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )

                                Text("— \(Int(pct * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [stealColor(index: index), stealColor(index: index).opacity(0.55)],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: geo.size.width * CGFloat(pct),
                                            height: 6
                                        )
                                        .shadow(color: stealColor(index: index).opacity(0.4), radius: 6, x: 0, y: 0)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(stealColor(index: index).opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(stealColor(index: index).opacity(0.18), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Animation Sequence

    private func startRevealSequence() {
        // T+0.5s : démarrage du compteur
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { phase = .counterSpin }
            startCounterAnimation()
        }
    }

    private func startCounterAnimation() {
        let totalDuration: Double = 2.4
        let fps: Double = 60
        let totalFrames = Int(totalDuration * fps)
        var currentFrame = 0
        displayedSeconds = 0

        counterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { timer in
            currentFrame += 1
            let progress = Double(currentFrame) / Double(totalFrames)

            if progress >= 1.0 {
                timer.invalidate()
                displayedSeconds = todaySeconds
                onCounterFinished()
                return
            }
            let eased = easeOutExpo(progress)
            displayedSeconds = todaySeconds * eased
        }
    }

    private func easeOutExpo(_ t: Double) -> Double {
        t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t)
    }

    private func onCounterFinished() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
            phase = .counterDone
        }
        redPulse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.45)) { phase = .verdictReveal }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { phase = .bodyReveal }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.3))
            .tracking(2.5)
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }

    private func formattedLargeNumber(_ years: Double) -> String {
        if years >= 1 {
            return String(format: "%.1f", years)
        } else {
            let months = years * 12
            return String(format: "%.0f", months)
        }
    }

    // MARK: - Guilt tiers

    private var guiltColor: Color {
        if todayHours >= 6 { return Color(red: 1.0, green: 0.18, blue: 0.18) }
        if todayHours >= 4 { return Color(red: 1.0, green: 0.45, blue: 0.15) }
        if todayHours >= 2 { return Color(red: 1.0, green: 0.78, blue: 0.1) }
        return Color(red: 0.35, green: 0.92, blue: 0.55)
    }

    private var verdictIcon: String {
        if todayHours >= 6 { return "flame.fill" }
        if todayHours >= 4 { return "exclamationmark.triangle.fill" }
        if todayHours >= 2 { return "eye.trianglebadge.exclamationmark.fill" }
        return "checkmark.seal.fill"
    }

    private var verdictLabel: String {
        if todayHours >= 6 { return "Addictif" }
        if todayHours >= 4 { return "Excessif" }
        if todayHours >= 2 { return "À surveiller" }
        return "Sain"
    }

    private var verdictHeadline: String {
        if todayHours >= 6 { return "Tu es en zone rouge." }
        if todayHours >= 4 { return "C'est beaucoup trop." }
        if todayHours >= 2 { return "Tu peux encore redresser." }
        return "Bravo, tu maîtrises."
    }

    private var verdictSubtitle: String {
        if todayHours >= 6 {
            return "Ton cerveau ne distingue plus la pause de la compulsion. Ton attention s'effondre."
        }
        if todayHours >= 4 {
            return "Tu perds des heures que tu ne récupéreras jamais. Chaque jour."
        }
        if todayHours >= 2 {
            return "Tu es au-dessus de la moyenne recommandée. Pas grave — encore."
        }
        return "Continue comme ça. Peu de gens y arrivent."
    }

    private var shockPhrase: String {
        if todayHours >= 6 {
            return "Tu as passé plus de temps sur ton téléphone qu'à parler à un être humain aujourd'hui."
        }
        if todayHours >= 4 {
            return "C'est presque un mi-temps.\nChaque jour. Pour scroller."
        }
        if todayHours >= 2 {
            let weeklyHours = Int(todayHours * 7)
            return "\(weeklyHours) heures par semaine.\nC'est un film. Chaque soir."
        }
        return "Tu utilises ton téléphone comme un outil, pas comme une drogue.\nRare."
    }

    private var equivalences: [GuiltEquivalence] {
        let annualHours = todayHours * 365
        let annualDays = annualHours / 24
        var result: [GuiltEquivalence] = []

        if annualDays >= 1 {
            result.append(GuiltEquivalence(
                emoji: "📅",
                headline: "\(Int(annualDays)) jours entiers par an",
                body: "À ce rythme, c'est \(Int(annualDays)) journées complètes rayées de ta vie cette année."
            ))
        }

        let books = Int((todayMinutes * 365) / 320)   // ~320 min pour un livre moyen
        if books > 0 {
            result.append(GuiltEquivalence(
                emoji: "📚",
                headline: "\(books) livres par an",
                body: "Tu aurais pu lire \(books) livres cette année avec ce temps."
            ))
        }

        let workoutMinutes = Int(todayMinutes * 365)
        let workoutHours = workoutMinutes / 60
        if workoutHours > 100 {
            result.append(GuiltEquivalence(
                emoji: "💪",
                headline: "\(workoutHours) heures de sport",
                body: "De quoi transformer complètement ton corps en une année."
            ))
        }

        let sleepHoursPerYear = Int(todayHours * 365)
        if sleepHoursPerYear >= 50 {
            result.append(GuiltEquivalence(
                emoji: "😴",
                headline: "\(sleepHoursPerYear)h de sommeil volé",
                body: "Imagine ta productivité avec \(sleepHoursPerYear)h de sommeil en plus par an."
            ))
        }

        return result
    }

    private func stealColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.28, blue: 0.28),
            Color(red: 1.0, green: 0.55, blue: 0.1),
            Color(red: 1.0, green: 0.82, blue: 0.1)
        ]
        return colors[min(index, colors.count - 1)]
    }
}
