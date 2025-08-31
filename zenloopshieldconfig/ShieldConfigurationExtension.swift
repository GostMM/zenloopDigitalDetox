import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Palette
    private var gradientStart: UIColor { UIColor(red: 0.40, green: 0.20, blue: 1.00, alpha: 1.0) }
    private var gradientEnd:   UIColor { UIColor(red: 0.60, green: 0.10, blue: 0.90, alpha: 1.0) }

    // MARK: - App Group (⚠️ à adapter à ton identifiant)
    private let appGroupId = "group.com.app.zenloop" // ex: "group.com.yourcompany.zenloop"

    // MARK: - Logo / Cache
    private lazy var baseLogo: UIImage? = (UIImage(named: "zenloopLogo") ?? createZenloopLogo())
    private lazy var premiumIconCache = NSCache<NSString, UIImage>() // key = "size@bundleId"

    // MARK: - Labels (API: text + color) avec validation
    private func label(_ text: String, _ color: UIColor) -> ShieldConfiguration.Label {
        // Validation et nettoyage du texte
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        debugLog("📝 Creating label: '\(cleanedText)' with color: \(color)")
        return ShieldConfiguration.Label(text: cleanedText, color: color)
    }

    // MARK: - Accent premium (stable par bundleId)
    private func premiumAccent(for bundleId: String) -> UIColor {
        let t = CGFloat((stableHash(bundleId) % 100)) / 100.0
        return blend(gradientStart, gradientEnd, t: t)
    }

    private func stableHash(_ s: String) -> Int {
        var hash = 5381
        for u in s.utf8 { hash = ((hash << 5) &+ hash) &+ Int(u) }
        return abs(hash)
    }

    private func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1v: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2v: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1v, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2v, alpha: &a2)
        return UIColor(
            red:   r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue:  b1v + (b2v - b1v) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }

    // MARK: - Fond
    private func backgroundColor() -> UIColor { .clear } // blur => effet verre

    // MARK: - Compteur tentatives
    private var attemptKey: String { "zenloop.shield.attempts" }
    private func incrementAttempts(for id: String) -> Int {
        let key = "\(attemptKey).\(id)"
        let cur = UserDefaults.standard.integer(forKey: key)
        let new = cur + 1
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    // MARK: - Messages contextuels dynamiques
    // Supprimé - remplacé par le système de motivation plus complet

    // MARK: - Récupération icône app (via App Group, fallback logo)
    /// Option 1: via UserDefaults(suiteName:) clé "appicon.<bundleId>" contenant Data PNG/JPEG
    /// Option 2: via fichier dans le conteneur partagé: /AppIcons/<bundleId>.png
    private func sharedAppIcon(for bundleId: String) -> UIImage? {
        // UserDefaults (binary Data)
        if let ud = UserDefaults(suiteName: appGroupId),
           let data = ud.data(forKey: "appicon.\(bundleId)"),
           let img = UIImage(data: data, scale: UIScreen.main.scale) {
            return img
        }
        // Fichier dans le conteneur
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("AppIcons", isDirectory: true) {
            let urlPNG = dir.appendingPathComponent("\(bundleId).png")
            let urlJPG = dir.appendingPathComponent("\(bundleId).jpg")
            if let data = try? Data(contentsOf: urlPNG), let img = UIImage(data: data, scale: UIScreen.main.scale) {
                return img
            }
            if let data = try? Data(contentsOf: urlJPG), let img = UIImage(data: data, scale: UIScreen.main.scale) {
                return img
            }
        }
        return nil
    }

    // MARK: - Dessin utilitaire (aspect fill + clip cercle)
    private func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let circlePath = UIBezierPath(ovalIn: rect)
        circlePath.addClip() // clip circulaire

        let imgSize = image.size
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let drawSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
        let drawOrigin = CGPoint(x: rect.midX - drawSize.width/2, y: rect.midY - drawSize.height/2)
        let drawRect = CGRect(origin: drawOrigin, size: drawSize)

        image.draw(in: drawRect)
        cg.resetClip()
    }

    // MARK: - Icône premium (ronde, cover, anneau dégradé, reflet, badge verrou)
    private func premiumIcon(size: CGFloat, bundleId: String, appIcon: UIImage?) -> UIImage? {
        let key = "\(Int(size))@\(bundleId)" as NSString
        if let cached = premiumIconCache.object(forKey: key) { return cached }

        let baseImage = appIcon ?? baseLogo
        guard let base = baseImage else { return nil }

        let sz = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: sz)

        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: sz)
            let circle = UIBezierPath(ovalIn: rect)

            // Ombre externe douce
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 10),
                         blur: 20,
                         color: UIColor.black.withAlphaComponent(0.28).cgColor)
            UIColor.clear.setFill()
            circle.fill()
            cg.restoreGState()

            // Fond verre (dégradé radial subtil)
            circle.addClip()
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [UIColor.white.withAlphaComponent(0.10).cgColor,
                                              UIColor.black.withAlphaComponent(0.10).cgColor] as CFArray,
                                     locations: [0.0, 1.0]) {
                cg.drawRadialGradient(
                    grad,
                    startCenter: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endCenter: CGPoint(x: rect.midX, y: rect.midY),
                    endRadius: max(rect.width, rect.height) / 2,
                    options: []
                )
            }

            // Image centrale → cover cercle (aspect fill) avec léger inset
            let inset: CGFloat = rect.width * 0.08
            drawAspectFill(base, in: rect.insetBy(dx: inset, dy: inset))

            // Anneau dégradé fin
            let ringWidth: CGFloat = 2.0
            let ringRect = rect.insetBy(dx: ringWidth/2, dy: ringWidth/2)
            let ringPath = UIBezierPath(ovalIn: ringRect).cgPath
            cg.saveGState()
            cg.addPath(ringPath)
            cg.setLineWidth(ringWidth)
            cg.replacePathWithStrokedPath()
            cg.clip()
            if let ringGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [gradientStart.cgColor, gradientEnd.cgColor] as CFArray,
                                         locations: [0.0, 1.0]) {
                cg.drawLinearGradient(
                    ringGrad,
                    start: CGPoint(x: rect.minX, y: rect.minY),
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
            }
            cg.restoreGState()

            // Reflet glossy léger
            let gloss = UIBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.58))
            UIColor.white.withAlphaComponent(0.18).setFill()
            gloss.fill()

            // Badge verrou (discret) en bas à droite
            if let lock = UIImage(systemName: "lock.fill") {
                let badgeSide = rect.width * 0.26
                let badgeRect = CGRect(
                    x: rect.maxX - badgeSide - rect.width * 0.07,
                    y: rect.maxY - badgeSide - rect.width * 0.07,
                    width: badgeSide, height: badgeSide
                )

                let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeSide * 0.28)
                UIColor.black.withAlphaComponent(0.30).setFill()
                badgePath.fill()

                let cfg = UIImage.SymbolConfiguration(pointSize: badgeSide * 0.60, weight: .semibold)
                let tinted = lock.applyingSymbolConfiguration(cfg)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                tinted?.draw(in: badgeRect.insetBy(dx: badgeSide * 0.20, dy: badgeSide * 0.20))
            }
        }

        premiumIconCache.setObject(img, forKey: key)
        return img
    }

    // MARK: - Fallback logo (si aucun asset)
    private func createZenloopLogo() -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let circle = UIBezierPath(ovalIn: rect.insetBy(dx: 32, dy: 32))
            blend(gradientStart, gradientEnd, t: 0.5).setFill()
            circle.fill()

            let infinity = "∞" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 280, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = infinity.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (rect.width - textSize.width)/2,
                y: (rect.height - textSize.height)/2,
                width: textSize.width,
                height: textSize.height
            )
            infinity.draw(in: textRect, withAttributes: attrs)
        }
    }

    // MARK: - Shield Premium avec Design Motivationnel
    private func makeShield(
        tint: UIColor,
        title: String,
        appName: String,
        bundleId: String,
        appIcon: UIImage?,
        context: ShieldContext
    ) -> ShieldConfiguration {

        let attempts = incrementAttempts(for: bundleId)
        
        // Titre motivationnel grand et impactant
        let motivationalTitle = createMotivationalTitle(for: context)
        
        // Message motivationnel détaillé et bien structuré
        let fullMessage = createFullMotivationalMessage(
            appName: appName, 
            attempts: attempts, 
            context: context
        )
        
        // Icône premium plus grande
        let icon: UIImage? = {
            if let premiumIcon = premiumIcon(size: 140, bundleId: bundleId, appIcon: appIcon) {
                return premiumIcon
            } else if let systemIcon = UIImage(systemName: "brain.head.profile") {
                let config = UIImage.SymbolConfiguration(pointSize: 70, weight: .bold)
                return systemIcon.withConfiguration(config).withTintColor(tint, renderingMode: .alwaysOriginal)
            }
            return nil
        }()
        
        debugLog("🛡️ Shield Premium:")
        debugLog("   Title: \(motivationalTitle)")
        debugLog("   Message length: \(fullMessage.count)")
        debugLog("   App: \(appName)")
        debugLog("   Attempts: \(attempts)")
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.black.withAlphaComponent(0.8),
            icon: icon,
            title: ShieldConfiguration.Label(
                text: motivationalTitle, 
                color: UIColor.white
            ),
            subtitle: ShieldConfiguration.Label(
                text: fullMessage, 
                color: UIColor.white.withAlphaComponent(0.95)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "FOCUS", 
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: tint
            // Pas de bouton secondaire - interface épurée
        )
    }
    
    // Titre motivationnel impactant
    private func createMotivationalTitle(for context: ShieldContext) -> String {
        switch context {
        case .focusSession:
            return "VOTRE FORCE"
        case .challengeActive:
            return "DÉFI EN COURS"
        case .digitalDetox:
            return "DIGITAL DETOX"
        case .flowZone:
            return "ZONE DE FLOW"
        }
    }
    
    // Message motivationnel complet et structuré
    private func createFullMotivationalMessage(appName: String, attempts: Int, context: ShieldContext) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeMotivation = getTimeBasedMotivation(hour: hour)
        let contextMotivation = getContextMotivation(for: context)
        let progressMessage = getProgressMessage(attempts: attempts)
        
        return """
\(timeMotivation)

\(contextMotivation)

Application bloquée : \(appName)
\(progressMessage)

Chaque moment de résistance renforce votre discipline mentale. Vous développez une capacité précieuse de concentration profonde.

Continuez - votre futur vous remerciera.
"""
    }
    
    private func getTimeBasedMotivation(hour: Int) -> String {
        switch hour {
        case 6..<12:
            return "🌅 EXCELLENT DÉBUT DE JOURNÉE\nVotre cerveau est au maximum de ses capacités."
        case 12..<14:
            return "☀️ MOMENTUM DE MI-JOURNÉE\nGardez cette énergie productive."
        case 14..<18:
            return "⚡ APRÈS-MIDI DE PERFORMANCE\nC'est maintenant que vous faites la différence."
        case 18..<22:
            return "🌙 SOIRÉE DE MAÎTRISE\nFinissez la journée en force."
        default:
            return "🌟 SESSION NOCTURNE DÉDIÉE\nVotre engagement tard le soir montre votre détermination."
        }
    }
    
    private func getContextMotivation(for context: ShieldContext) -> String {
        switch context {
        case .focusSession:
            return "Votre session de focus profond transforme votre cerveau. Chaque minute compte."
        case .challengeActive:
            return "Ce défi vous pousse vers une version améliorée de vous-même."
        case .digitalDetox:
            return "Vous reprenez le contrôle de votre attention. C'est un superpouvoir moderne."
        case .flowZone:
            return "Dans cette zone de flow, vous atteignez votre plein potentiel."
        }
    }
    
    private func getProgressMessage(attempts: Int) -> String {
        switch attempts {
        case 1:
            return "Première tentative - normal d'avoir envie d'ouvrir l'app."
        case 2...3:
            return "Tentative #\(attempts) - votre cerveau teste votre résolution."
        case 4...6:
            return "Tentative #\(attempts) - vous résistez mieux que la moyenne."
        default:
            return "Tentative #\(attempts) - votre discipline devient exceptionnelle."
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
    
    // Supprimé - remplacé par createSimpleSubtitle
    
    // Supprimé - plus besoin des labels secondaires
    // Interface épurée avec un seul bouton clair

    // MARK: - Configs
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? application.bundleIdentifier ?? "App"
        let bundleId = application.bundleIdentifier ?? "unknown"
        let tint = premiumAccent(for: bundleId)
        let appIcon = sharedAppIcon(for: bundleId)

        return makeShield(
            tint: tint,
            title: "Session Focus Active",
            appName: appName,
            bundleId: bundleId,
            appIcon: appIcon,
            context: .focusSession
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? application.bundleIdentifier ?? "App"
        let bundleId = application.bundleIdentifier ?? "unknown"
        let tint = premiumAccent(for: bundleId)
        let appIcon = sharedAppIcon(for: bundleId)

        return makeShield(
            tint: tint,
            title: "Défi en Cours",
            appName: appName,
            bundleId: bundleId,
            appIcon: appIcon,
            context: .challengeActive
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domain = webDomain.domain ?? "Site web"
        let id = "web.\(webDomain.domain ?? "unknown")"
        let tint = premiumAccent(for: id)

        return makeShield(
            tint: tint,
            title: "Digital Detox",
            appName: domain,
            bundleId: id,
            appIcon: nil,
            context: .digitalDetox
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        let domain = webDomain.domain ?? "Site web"
        let id = "web.\(webDomain.domain ?? "unknown")"
        let tint = premiumAccent(for: id)

        return makeShield(
            tint: tint,
            title: "Zone de Flow",
            appName: domain,
            bundleId: id,
            appIcon: nil,
            context: .flowZone
        )
    }
}

// MARK: - Shield Context Types

private enum ShieldContext {
    case focusSession
    case challengeActive
    case digitalDetox
    case flowZone
}
