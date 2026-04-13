//
//  GuiltTripExtensionView.swift
//  zenloopactivity (Extension)
//
//  Vue "Culpabilisation" rendue via DeviceActivityReport.
//  Accès aux vraies données Screen Time via ExtensionActivityReport.
//
//  Animation: écran noir → compteur vertigineux → reveal progressif sans cards.
//

import SwiftUI
import DeviceActivity
import os

private let logger = Logger(subsystem: "com.app.zenloop.zenloopactivity", category: "GuiltTrip")

private extension Notification.Name {
    static let quickActionEmergencyBreak = Notification.Name("quickActionEmergencyBreak")
}

// MARK: - Equivalence model

private struct GuiltEquivalence: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

// MARK: - Phase d'animation

private enum RevealPhase: Int, Comparable {
    case blackout = 0
    case counterSpin = 1
    case counterDone = 2
    case labelReveal = 3
    case shockPhrase = 4
    case scrollUnlock = 5

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
    @State private var pulseRing = false

    @State private var showComparison = false
    @State private var showEquivalences = false
    @State private var showTopApps = false
    @State private var showCTA = false

    private var todaySeconds: Double { reportData.todayScreenSeconds }
    private var averageSeconds: Double { reportData.averageDaily }
    private var todayMinutes: Double { todaySeconds / 60 }
    private var todayHours: Double { todaySeconds / 3600 }

    private let nationalAverageSeconds: Double = 270 * 60

    var body: some View {
        ZStack {
            background

            if phase < .scrollUnlock {
                heroOverlay
            } else {
                scrollContent
            }
        }
        .onAppear {
            startRevealSequence()
            logger.critical("🚀 [GUILT] View appeared — todayScreen=\(todaySeconds)s avg=\(averageSeconds)s apps=\(reportData.allApps.count)")
        }
        .onDisappear {
            counterTimer?.invalidate()
        }
    }

    // MARK: - Animation Sequence

    private func startRevealSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = .counterSpin
            startCounterAnimation()
        }
    }

    private func startCounterAnimation() {
        let totalDuration: Double = 2.2
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            phase = .counterDone
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .labelReveal
                pulseRing = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.5)) {
                phase = .shockPhrase
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                phase = .scrollUnlock
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    showComparison = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    showEquivalences = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    showTopApps = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    showCTA = true
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if phase >= .scrollUnlock {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.03, blue: 0.10),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            if phase >= .counterDone {
                RadialGradient(
                    colors: [guiltColor.opacity(0.12), Color.clear],
                    center: phase >= .scrollUnlock ? .init(x: 0.5, y: 0.12) : .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: phase)
            }
        }
    }

    // MARK: - Hero Overlay (centré, fond noir)

    private var heroOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                if phase >= .labelReveal {
                    Circle()
                        .stroke(guiltColor.opacity(0.15), lineWidth: 1)
                        .frame(width: pulseRing ? 80 : 60, height: pulseRing ? 80 : 60)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseRing)
                }

                Image(systemName: guiltIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(guiltColor)
                    .opacity(phase >= .labelReveal ? 1 : 0)
                    .scaleEffect(phase >= .labelReveal ? 1 : 0.5)
            }
            .frame(height: 80)

            ZStack {
                if phase == .counterSpin {
                    Text(formattedTime(displayedSeconds))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(guiltColor.opacity(0.25))
                        .blur(radius: 20)
                }

                Text(formattedTime(displayedSeconds))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .scaleEffect(phase == .counterDone ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.4), value: phase)
            }
            .opacity(phase >= .counterSpin ? 1 : 0)

            Text(guiltLabel.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(guiltColor.opacity(0.7))
                .tracking(3)
                .opacity(phase >= .labelReveal ? 1 : 0)

            Text("Temps d'écran aujourd'hui")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
                .opacity(phase >= .labelReveal ? 1 : 0)

            Text(shockPhrase)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(phase >= .shockPhrase ? 1 : 0)
                .offset(y: phase >= .shockPhrase ? 0 : 12)

            Spacer()
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                heroCompact
                    .padding(.top, 50)

                Spacer().frame(height: 44)
                comparisonSection
                    .opacity(showComparison ? 1 : 0)
                    .offset(y: showComparison ? 0 : 30)

                Spacer().frame(height: 40)
                equivalencesSection
                    .opacity(showEquivalences ? 1 : 0)
                    .offset(y: showEquivalences ? 0 : 30)

                Spacer().frame(height: 40)
                topAppsSection
                    .opacity(showTopApps ? 1 : 0)
                    .offset(y: showTopApps ? 0 : 30)

                Spacer().frame(height: 40)
                ctaSection
                    .opacity(showCTA ? 1 : 0)
                    .offset(y: showCTA ? 0 : 30)

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Hero Compact

    private var heroCompact: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(guiltColor.opacity(0.15), lineWidth: 1)
                    .frame(width: pulseRing ? 72 : 56, height: pulseRing ? 72 : 56)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseRing)

                Image(systemName: guiltIcon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(guiltColor)
            }

            Text(formattedTime(todaySeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(guiltLabel.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(guiltColor.opacity(0.7))
                .tracking(3)

            Text("Temps d'écran aujourd'hui")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))

            Text(shockPhrase)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("Comparaison")

            if averageSeconds > 0 {
                comparisonRow(
                    label: "Ta moyenne (7j)",
                    value: formattedTime(averageSeconds),
                    delta: todaySeconds - averageSeconds,
                    icon: "person.fill"
                )
                separator
            }

            comparisonRow(
                label: "Moyenne mondiale",
                value: formattedTime(nationalAverageSeconds),
                delta: todaySeconds - nationalAverageSeconds,
                icon: "globe"
            )
        }
    }

    private func comparisonRow(label: String, value: String, delta: Double, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            let isOver = delta > 0
            let deltaMinutes = Int(abs(delta) / 60)
            HStack(spacing: 4) {
                Image(systemName: isOver ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text("\(deltaMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(isOver ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color(red: 0.3, green: 0.9, blue: 0.5))
        }
    }

    // MARK: - Equivalences

    private var equivalencesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Ce que ça représente")

            ForEach(Array(equivalences.enumerated()), id: \.element.id) { index, equiv in
                HStack(spacing: 16) {
                    Text(equiv.icon)
                        .font(.system(size: 28))
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(equiv.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(equiv.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)

                if index < equivalences.count - 1 {
                    separator
                }
            }
        }
    }

    // MARK: - Top Apps

    private var topAppsSection: some View {
        let apps = reportData.allApps.prefix(5)
        guard !apps.isEmpty else { return AnyView(EmptyView()) }

        let totalTop = apps.reduce(0.0) { $0 + $1.duration }

        return AnyView(
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("Apps les plus chronophages")

                ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Icône réelle de l'app
                            #if os(iOS)
                            AppIconBadge(app: app, size: 36)
                            #endif

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)

                                Text(formattedTime(app.duration))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(appBarColor(index: index).opacity(0.8))
                            }

                            Spacer()

                            // Barre relative (longueur = % du total)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(appBarColor(index: index).opacity(0.7))
                                        .frame(
                                            width: totalTop > 0 ? geo.size.width * CGFloat(app.duration / totalTop) : 0,
                                            height: 4
                                        )
                                }
                            }
                            .frame(width: 70, height: 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        )
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            Text("Reprends le contrôle")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text("Lance une session focus et bloque les apps qui te volent ton temps.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Button {
                NotificationCenter.default.post(name: .quickActionEmergencyBreak, object: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Lancer une session focus")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [guiltColor, guiltColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.25))
            .tracking(2)
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "< 1m"
    }

    private var guiltColor: Color {
        if todayHours >= 6 { return Color(red: 1.0, green: 0.2, blue: 0.2) }
        if todayHours >= 4 { return Color(red: 1.0, green: 0.55, blue: 0.1) }
        if todayHours >= 2 { return Color(red: 1.0, green: 0.85, blue: 0.1) }
        return Color(red: 0.3, green: 0.9, blue: 0.5)
    }

    private var guiltIcon: String {
        if todayHours >= 6 { return "flame.fill" }
        if todayHours >= 4 { return "exclamationmark.triangle.fill" }
        if todayHours >= 2 { return "eye.fill" }
        return "checkmark.circle.fill"
    }

    private var guiltLabel: String {
        if todayHours >= 6 { return "Addictif" }
        if todayHours >= 4 { return "Excessif" }
        if todayHours >= 2 { return "À surveiller" }
        return "Raisonnable"
    }

    private var shockPhrase: String {
        if todayHours >= 6 {
            return "Tu as passé plus de temps sur ton téléphone qu'à dormir."
        } else if todayHours >= 4 {
            return "\(Int(todayHours))h de scroll = \(Int(todayHours * 15)) épisodes d'une série que tu n'as jamais regardée."
        } else if todayHours >= 2 {
            return "À ce rythme, tu passeras plus de 30 jours par an sur ton téléphone."
        } else {
            return "Bonne journée ! Continue comme ça."
        }
    }

    private var equivalences: [GuiltEquivalence] {
        let annualHours = todayHours * 365
        let annualDays = annualHours / 24
        var result: [GuiltEquivalence] = []

        if annualDays >= 1 {
            result.append(GuiltEquivalence(
                icon: "📅",
                title: String(format: "%.0f jours perdus / an", annualDays),
                subtitle: "À ce rythme, tu passeras \(Int(annualDays)) jours entiers sur ton téléphone cette année.",
                color: .red
            ))
        }

        let booksPerYear = Int(todayMinutes * 365 / (80000 / 250))
        if booksPerYear > 0 {
            result.append(GuiltEquivalence(
                icon: "📚",
                title: "\(booksPerYear) livres par an",
                subtitle: "Avec ce temps, tu aurais pu lire \(booksPerYear) livres cette année.",
                color: Color(red: 0.4, green: 0.6, blue: 1.0)
            ))
        }

        let moviesPerYear = Int(annualHours / 1.75)
        if moviesPerYear > 0 {
            result.append(GuiltEquivalence(
                icon: "🎬",
                title: "\(moviesPerYear) films par an",
                subtitle: "De quoi regarder tout le top 100 IMDb \(max(1, moviesPerYear / 100)) fois.",
                color: Color(red: 0.9, green: 0.5, blue: 0.2)
            ))
        }

        let caloriesIfWalked = Int(todayMinutes * 3)
        if caloriesIfWalked > 50 {
            result.append(GuiltEquivalence(
                icon: "🏃",
                title: "\(caloriesIfWalked) calories non brûlées",
                subtitle: "Si tu avais marché pendant ce temps, tu aurais brûlé \(caloriesIfWalked) kcal.",
                color: Color(red: 0.3, green: 0.85, blue: 0.5)
            ))
        }

        return result
    }

    private func appBarColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.3, blue: 0.3),
            Color(red: 1.0, green: 0.55, blue: 0.1),
            Color(red: 1.0, green: 0.85, blue: 0.1),
            Color(red: 0.4, green: 0.6, blue: 1.0),
            Color(red: 0.6, green: 0.4, blue: 1.0),
        ]
        return colors[min(index, colors.count - 1)]
    }
}