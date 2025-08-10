//
//  SmartNotificationManager.swift
//  zenloop
//
//  Created by Claude on 06/08/2025.
//

/*
import Foundation
import UserNotifications
import Combine
import UIKit

// MARK: - Intelligent Contextual Notification System

class SmartNotificationManager: ObservableObject {
    static let shared = SmartNotificationManager()
    
    private let participationIntelligence = ParticipationIntelligence.shared
    private let analytics = CommunityAnalytics.shared
    private let db = Firestore.firestore()
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var sentNotificationsCount: Int = 0
    @Published var engagementRate: Double = 0.0
    
    // Anti-spam et optimisation
    private var notificationHistory: [String: [NotificationRecord]] = [:]
    private var userPreferences: [String: NotificationPreferences] = [:]
    private let maxDailyNotifications = 5
    private let cooldownPeriod: TimeInterval = 2 * 3600 // 2 heures
    
    private init() {
        setupNotificationSystem()
        startNotificationOptimization()
    }
    
    // MARK: - System Setup
    
    private func setupNotificationSystem() {
        requestNotificationPermissions()
        loadUserPreferences()
        
        // Observer les changements de permissions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        print("📱 [NOTIFICATIONS] Smart Notification System initialized")
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = granted ? .authorized : .denied
            }
            
            if granted {
                print("✅ [NOTIFICATIONS] Permission granted")
            } else if let error = error {
                print("❌ [NOTIFICATIONS] Permission error: \(error)")
            }
        }
        
        // Récupérer le statut actuel
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Mettre à jour le statut des permissions quand l'app revient au premier plan
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    // MARK: - Intelligent Notification Scheduling
    
    private func startNotificationOptimization() {
        // Optimisation périodique des notifications
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Chaque heure
            Task {
                await self.optimizeNotificationSchedule()
                await self.analyzeNotificationPerformance()
            }
        }
    }
    
    private func optimizeNotificationSchedule() async {
        let currentUserId = CommunityManager.shared.currentUserId
        let userStats = await analytics.getCurrentUserStats()
        
        // Analyser les meilleurs moments pour notifier cet utilisateur
        await updateOptimalNotificationTimes(userId: currentUserId, stats: userStats)
        
        // Optimiser les patterns de notification pour cet utilisateur
        print("📊 [NOTIFICATIONS] Optimized notification patterns for user: \(currentUserId)")
    }
    
    // MARK: - Challenge Recommendations
    
    func sendChallengeRecommendation(userId: String, challenge: GeneratedChallenge) async {
        // Vérifier les conditions anti-spam
        guard await canSendNotification(to: userId, type: .challengeRecommendation) else {
            return
        }
        
        // Personnaliser le message selon le profil utilisateur
        let personalizedContent = await generatePersonalizedContent(
            for: userId,
            challenge: challenge,
            type: .challengeRecommendation
        )
        
        // Calculer le timing optimal
        let optimalDeliveryTime = await calculateOptimalDeliveryTime(userId: userId, priority: .medium)
        
        await scheduleNotification(
            userId: userId,
            content: personalizedContent,
            deliveryTime: optimalDeliveryTime,
            type: .challengeRecommendation,
            metadata: ["challengeId": challenge.id]
        )
    }
    
    // MARK: - Motivation & Engagement Notifications
    
    func sendMotivationNotification(userId: String, context: MotivationContext) async {
        guard await canSendNotification(to: userId, type: .motivation) else {
            return
        }
        
        let content = generateMotivationContent(context: context, userId: userId)
        let deliveryTime = await calculateOptimalDeliveryTime(userId: userId, priority: .low)
        
        await scheduleNotification(
            userId: userId,
            content: content,
            deliveryTime: deliveryTime,
            type: .motivation,
            metadata: ["context": context.rawValue]
        )
    }
    
    func sendProgressUpdateNotification(userId: String, progress: Double, challengeId: String) async {
        // Notifications d'encouragement basées sur la progression
        let content: NotificationContent
        
        switch progress {
        case 0.25:
            content = NotificationContent(
                title: "🎯 Premier quart accompli !",
                body: "Tu es sur la bonne voie ! Continue comme ça, chaque minute compte.",
                sound: .soft
            )
        case 0.5:
            content = NotificationContent(
                title: "🔥 À mi-parcours !",
                body: "Bravo ! Tu as déjà fait la moitié. Le plus dur est derrière toi !",
                sound: .achievement
            )
        case 0.75:
            content = NotificationContent(
                title: "💪 Plus que 25% !",
                body: "Incroyable progression ! La ligne d'arrivée se rapproche.",
                sound: .encouraging
            )
        default:
            return // Pas de notification pour les autres jalons
        }
        
        await scheduleImmediateNotification(
            userId: userId,
            content: content,
            type: .progressUpdate,
            metadata: ["challengeId": challengeId, "progress": "\(progress)"]
        )
    }
    
    // MARK: - Social & Community Notifications
    
    func sendSocialNotification(userId: String, type: SocialNotificationType, data: [String: Any]) async {
        guard await canSendNotification(to: userId, type: .social) else {
            return
        }
        
        let content = generateSocialContent(type: type, data: data)
        let priority: NotificationPriority = type == .messageReceived ? .high : .medium
        let deliveryTime = await calculateOptimalDeliveryTime(userId: userId, priority: priority)
        
        await scheduleNotification(
            userId: userId,
            content: content,
            deliveryTime: deliveryTime,
            type: .social,
            metadata: data
        )
    }
    
    func sendCommunityMilestoneNotification(milestone: CommunityMilestone) async {
        // Notification pour toute la communauté
        let activeUsers = await getActiveUsers()
        
        let content = NotificationContent(
            title: milestone.title,
            body: milestone.description,
            sound: .celebration
        )
        
        for userId in activeUsers {
            if await canSendNotification(to: userId, type: .communityUpdate) {
                await scheduleImmediateNotification(
                    userId: userId,
                    content: content,
                    type: .communityUpdate,
                    metadata: ["milestone": milestone.type.rawValue]
                )
            }
        }
    }
    
    // MARK: - Contextual Triggers
    
    func sendAppBlockedNotification(userId: String, appName: String, challengeContext: String?) async {
        let personalizedMessage = await generateAppBlockedMessage(
            userId: userId,
            appName: appName,
            challengeContext: challengeContext
        )
        
        let content = NotificationContent(
            title: "🛡️ App bloquée avec succès !",
            body: personalizedMessage,
            sound: .achievement
        )
        
        await scheduleImmediateNotification(
            userId: userId,
            content: content,
            type: .appBlocked,
            metadata: ["appName": appName]
        )
    }
    
    func sendStreakNotification(userId: String, streakCount: Int, category: CommunityCategory) async {
        let streakMessages = generateStreakMessages(streakCount: streakCount, category: category)
        
        let content = NotificationContent(
            title: streakMessages.title,
            body: streakMessages.body,
            sound: streakCount % 7 == 0 ? .celebration : .achievement
        )
        
        await scheduleImmediateNotification(
            userId: userId,
            content: content,
            type: .streak,
            metadata: ["streakCount": "\(streakCount)", "category": category.rawValue]
        )
    }
    
    // MARK: - Smart Timing Optimization
    
    private func calculateOptimalDeliveryTime(userId: String, priority: NotificationPriority) async -> Date {
        let now = Date()
        
        // Pour les notifications haute priorité, envoyer immédiatement (avec quelques minutes de délai)
        if priority == .high {
            return Calendar.current.date(byAdding: .minute, value: Int.random(in: 1...5), to: now) ?? now
        }
        
        // Récupérer les préférences utilisateur
        let preferences = userPreferences[userId] ?? NotificationPreferences.default()
        
        // Éviter les heures de silence
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= preferences.silentHours.start || hour <= preferences.silentHours.end {
            // Reporter au lendemain matin
            var nextDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            nextDay = Calendar.current.date(bySettingHour: preferences.preferredHours.start, minute: 0, second: 0, of: nextDay) ?? nextDay
            return nextDay
        }
        
        // Utiliser l'intelligence pour prédire le meilleur moment
        let optimalTime = await predictOptimalTime(userId: userId, currentTime: now)
        
        return optimalTime
    }
    
    private func predictOptimalTime(userId: String, currentTime: Date) async -> Date {
        // Analyser l'historique d'engagement pour prédire le meilleur moment
        let userHistory = notificationHistory[userId] ?? []
        
        // Trouver les heures avec le meilleur taux d'engagement
        var hourlyEngagement: [Int: Double] = [:]
        
        for record in userHistory {
            let hour = Calendar.current.component(.hour, from: record.sentAt)
            let engagement = record.wasOpened ? 1.0 : 0.0
            
            hourlyEngagement[hour, default: 0.0] = (hourlyEngagement[hour, default: 0.0] + engagement) / 2.0
        }
        
        // Trouver la meilleure heure dans les 4 prochaines heures
        let currentHour = Calendar.current.component(.hour, from: currentTime)
        var bestHour = currentHour
        var bestScore = 0.0
        
        for hour in currentHour...(currentHour + 4) {
            let normalizedHour = hour % 24
            let score = hourlyEngagement[normalizedHour] ?? 0.3 // Score par défaut
            
            if score > bestScore {
                bestScore = score
                bestHour = normalizedHour
            }
        }
        
        // Si la meilleure heure est maintenant ou dans le passé, ajouter un petit délai
        let optimalHour = max(bestHour, currentHour)
        let delayMinutes = optimalHour == currentHour ? Int.random(in: 10...30) : 0
        
        var targetTime = Calendar.current.date(bySettingHour: optimalHour, minute: delayMinutes, second: 0, of: currentTime) ?? currentTime
        
        // Si c'est dans le passé, reporter à demain
        if targetTime <= currentTime {
            targetTime = Calendar.current.date(byAdding: .day, value: 1, to: targetTime) ?? targetTime
        }
        
        return targetTime
    }
    
    // MARK: - Content Generation
    
    private func generatePersonalizedContent(
        for userId: String,
        challenge: GeneratedChallenge,
        type: NotificationType
    ) async -> NotificationContent {
        
        // Récupérer le profil utilisateur pour personnaliser
        let userStats = await analytics.getCurrentUserStats()
        
        let personalizedTitle: String
        let personalizedBody: String
        
        // Personnalisation basée sur l'historique
        if userStats.completedChallenges == 0 {
            personalizedTitle = "🌟 Ton premier défi t'attend !"
            personalizedBody = "\(challenge.title) - Parfait pour commencer ton aventure digital wellness."
        } else {
            let successRate = userStats.completedChallenges > 0 ? Double(userStats.completedChallenges) / Double(userStats.totalPoints / 10) : 0.0
            if successRate > 0.8 {
                personalizedTitle = "🔥 Champion, un nouveau défi !"
                personalizedBody = "\(challenge.title) - Ton excellent historique de \(userStats.completedChallenges) défis mérite ce challenge !"
            } else if successRate < 0.3 {
                personalizedTitle = "💪 Un défi pour rebondir !"
                personalizedBody = "\(challenge.title) - Conçu pour t'aider à retrouver ton rythme."
            } else {
                personalizedTitle = "🎯 Nouveau défi disponible !"
                personalizedBody = "\(challenge.title) - \(challenge.maxParticipants) places disponibles."
            }
        }
        
        return NotificationContent(
            title: personalizedTitle,
            body: personalizedBody,
            sound: .gentle
        )
    }
    
    private func generateMotivationContent(context: MotivationContext, userId: String) -> NotificationContent {
        let motivationMessages: [(String, String)] = [
            ("💪 Moment de force !", "Tu as la capacité de transformer cette envie en victoire. Respire et reconnecte-toi à tes objectifs."),
            ("🌟 Tu es plus fort que ça !", "Chaque résistance est une preuve de ta détermination. Continue, tu progresses !"),
            ("🎯 Focus sur ton pourquoi", "Rappelle-toi pourquoi tu as commencé. Cette motivation est toujours là, en toi."),
            ("🏆 Champions face aux défis", "Les vrais champions se révèlent dans les moments difficiles. C'est ton moment !"),
            ("🌱 Croissance en cours", "Chaque défi surmonté te rend plus fort. Tu es en train d'évoluer !")
        ]
        
        let randomMessage = motivationMessages.randomElement() ?? motivationMessages.first!
        
        return NotificationContent(
            title: randomMessage.0,
            body: randomMessage.1,
            sound: .inspiring
        )
    }
    
    private func generateSocialContent(type: SocialNotificationType, data: [String: Any]) -> NotificationContent {
        switch type {
        case .messageReceived:
            let sender = data["sender"] as? String ?? "Un participant"
            return NotificationContent(
                title: "💬 Nouveau message",
                body: "\(sender) t'a écrit dans un défi communautaire !",
                sound: .message
            )
            
        case .challengeJoined:
            let challengeTitle = data["challengeTitle"] as? String ?? "un défi"
            let participantName = data["participantName"] as? String ?? "Quelqu'un"
            return NotificationContent(
                title: "🎉 Nouveau participant !",
                body: "\(participantName) a rejoint \(challengeTitle). Plus on est, plus c'est motivant !",
                sound: .social
            )
            
        case .goalAchieved:
            let achieverName = data["achieverName"] as? String ?? "Un participant"
            return NotificationContent(
                title: "🏆 Objectif atteint !",
                body: "Bravo à \(achieverName) qui vient de terminer son défi ! À ton tour ?",
                sound: .celebration
            )
            
        case .encouragementReceived:
            let encourager = data["encourager"] as? String ?? "Quelqu'un"
            return NotificationContent(
                title: "❤️ Encouragement reçu !",
                body: "\(encourager) t'encourage dans ton défi. La communauté est avec toi !",
                sound: .heart
            )
        }
    }
    
    private func generateAppBlockedMessage(userId: String, appName: String, challengeContext: String?) async -> String {
        let encouragingMessages = [
            "Excellent réflexe ! Tu viens de choisir ton bien-être plutôt que la distraction.",
            "Bravo ! Tu prouves que tu contrôles ta technologie, pas l'inverse.",
            "Bien joué ! Chaque blocage te rapproche de tes objectifs.",
            "Super ! Tu viens de gagner du temps précieux pour ce qui compte vraiment.",
            "Félicitations ! Tu montres l'exemple à toute la communauté."
        ]
        
        return encouragingMessages.randomElement() ?? encouragingMessages.first!
    }
    
    private func generateStreakMessages(streakCount: Int, category: CommunityCategory) -> (title: String, body: String) {
        switch streakCount {
        case 3:
            return ("🔥 3 jours de suite !", "Tu commences à prendre le rythme ! Continue comme ça.")
            
        case 7:
            return ("🌟 Une semaine complète !", "Incroyable ! Tu as tenu une semaine entière. Tu es en train de changer tes habitudes.")
            
        case 14:
            return ("💎 Deux semaines consécutives !", "Exceptionnel ! Tes nouvelles habitudes se solidifient.")
            
        case 30:
            return ("👑 Un mois de maîtrise !", "LÉGENDAIRE ! Un mois complet de discipline. Tu es devenu un exemple pour tous.")
            
        case let count where count % 10 == 0:
            return ("🏆 \(count) jours de suite !", "Ta constance est remarquable ! Continue cette série extraordinaire.")
            
        default:
            return ("⚡ Série de \(streakCount) jours !", "Chaque jour compte. Ta détermination paie !")
        }
    }
    
    // MARK: - Anti-Spam & Optimization
    
    private func canSendNotification(to userId: String, type: NotificationType) async -> Bool {
        // Vérifier les permissions
        guard notificationPermissionStatus == .authorized else {
            return false
        }
        
        // Vérifier les préférences utilisateur
        let preferences = userPreferences[userId] ?? NotificationPreferences.default()
        guard preferences.enabledTypes.contains(type) else {
            return false
        }
        
        // Vérifier le limite quotidien
        let today = Calendar.current.startOfDay(for: Date())
        let todayNotifications = (notificationHistory[userId] ?? [])
            .filter { Calendar.current.startOfDay(for: $0.sentAt) == today }
        
        if todayNotifications.count >= maxDailyNotifications {
            return false
        }
        
        // Vérifier le cooldown
        if let lastNotification = notificationHistory[userId]?.last,
           Date().timeIntervalSince(lastNotification.sentAt) < cooldownPeriod {
            return false
        }
        
        // Vérifier l'heure de silence
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour >= preferences.silentHours.start && currentHour <= preferences.silentHours.end {
            return false
        }
        
        return true
    }
    
    private func scheduleNotification(
        userId: String,
        content: NotificationContent,
        deliveryTime: Date,
        type: NotificationType,
        metadata: [String: Any]
    ) async {
        
        let identifier = UUID().uuidString
        
        // Créer la notification
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.sound = content.sound.unSound
        notificationContent.userInfo = metadata
        
        // Programmer la livraison
        let timeInterval = deliveryTime.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeInterval, 1), repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            // Enregistrer dans l'historique
            let record = NotificationRecord(
                id: identifier,
                userId: userId,
                type: type,
                content: content,
                scheduledFor: deliveryTime,
                sentAt: Date(),
                wasOpened: false,
                metadata: metadata
            )
            
            notificationHistory[userId, default: []].append(record)
            
            // Maintenir l'historique (garder seulement les 100 dernières)
            if notificationHistory[userId]!.count > 100 {
                notificationHistory[userId]!.removeFirst()
            }
            
            sentNotificationsCount += 1
            
            print("📤 [NOTIFICATIONS] Scheduled \(type) notification for \(userId) at \(deliveryTime)")
            
        } catch {
            print("❌ [NOTIFICATIONS] Failed to schedule notification: \(error)")
        }
    }
    
    private func scheduleImmediateNotification(
        userId: String,
        content: NotificationContent,
        type: NotificationType,
        metadata: [String: Any]
    ) async {
        let deliveryTime = Calendar.current.date(byAdding: .second, value: 2, to: Date()) ?? Date()
        await scheduleNotification(
            userId: userId,
            content: content,
            deliveryTime: deliveryTime,
            type: type,
            metadata: metadata
        )
    }
    
    // MARK: - Performance Analytics
    
    private func analyzeNotificationPerformance() async {
        var totalNotifications = 0
        var openedNotifications = 0
        
        for (_, records) in notificationHistory {
            totalNotifications += records.count
            openedNotifications += records.filter { $0.wasOpened }.count
        }
        
        let rate = totalNotifications > 0 ? Double(openedNotifications) / Double(totalNotifications) : 0.0
        
        await MainActor.run {
            self.engagementRate = rate
        }
        
        print("📊 [NOTIFICATIONS] Engagement rate: \(Int(rate * 100))% (\(openedNotifications)/\(totalNotifications))")
    }
    
    func recordNotificationOpened(identifier: String) {
        // Marquer une notification comme ouverte pour améliorer l'algorithme
        for (userId, records) in notificationHistory {
            if let index = records.firstIndex(where: { $0.id == identifier }) {
                notificationHistory[userId]![index].wasOpened = true
                break
            }
        }
        
        Task {
            await analyzeNotificationPerformance()
        }
    }
    
    // MARK: - User Preferences Management
    
    private func loadUserPreferences() {
        // En production, charger depuis UserDefaults ou Firebase
        // Pour l'instant, utiliser des préférences par défaut
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences, for userId: String) {
        userPreferences[userId] = preferences
        
        // Sauvegarder les préférences
        UserDefaults.standard.set(try? JSONEncoder().encode(preferences), forKey: "notification_preferences_\(userId)")
    }
    
    // MARK: - Utility Functions
    
    private func getActiveUsers() async -> [String] {
        // Récupérer les utilisateurs actifs pour les notifications communautaires
        do {
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            let snapshot = try await db.collection("challenge_participants")
                .whereField("createdAt", isGreaterThan: Timestamp(date: threeDaysAgo))
                .getDocuments()
            
            return Array(Set(snapshot.documents.compactMap { $0.data()["userId"] as? String }))
        } catch {
            return []
        }
    }
    
    private func updateOptimalNotificationTimes(userId: String, stats: CommunityUserStats) async {
        // Analyser les patterns et mettre à jour les préférences automatiquement
        // En production, utiliser l'ML pour optimiser les heures de notification
    }
}

// MARK: - Supporting Data Structures

struct NotificationContent {
    let title: String
    let body: String
    let sound: NotificationSound
}

enum NotificationSound {
    case silent, soft, gentle, message, social, achievement, celebration, inspiring, encouraging, heart
    
    var unSound: UNNotificationSound {
        switch self {
        case .silent:
            return UNNotificationSound(named: UNNotificationSoundName(""))
        case .soft, .gentle:
            return UNNotificationSound.default
        case .message, .social:
            return UNNotificationSound.default
        case .achievement, .celebration:
            return UNNotificationSound.default
        case .inspiring, .encouraging, .heart:
            return UNNotificationSound.default
        }
    }
}

enum NotificationType: String, CaseIterable, Codable {
    case challengeRecommendation = "challenge_recommendation"
    case motivation = "motivation"
    case progressUpdate = "progress_update"
    case social = "social"
    case communityUpdate = "community_update"
    case appBlocked = "app_blocked"
    case streak = "streak"
    case reminder = "reminder"
}

enum NotificationPriority {
    case low, medium, high, critical
}

enum MotivationContext: String, CaseIterable {
    case appAttempt = "app_attempt"
    case lowProgress = "low_progress"
    case milestone = "milestone"
    case encouragement = "encouragement"
}

enum SocialNotificationType {
    case messageReceived
    case challengeJoined
    case goalAchieved
    case encouragementReceived
}

struct CommunityMilestone {
    let type: MilestoneType
    let title: String
    let description: String
    let achievedAt: Date
}

enum MilestoneType: String {
    case userCount = "user_count"
    case challengeCount = "challenge_count"
    case successRate = "success_rate"
    case engagement = "engagement"
}

struct NotificationRecord {
    let id: String
    let userId: String
    let type: NotificationType
    let content: NotificationContent
    let scheduledFor: Date
    let sentAt: Date
    var wasOpened: Bool
    let metadata: [String: Any]
}

struct NotificationPreferences: Codable {
    let enabledTypes: Set<NotificationType>
    let preferredHours: TimeRange
    let silentHours: TimeRange
    let maxDailyNotifications: Int
    
    static func `default`() -> NotificationPreferences {
        return NotificationPreferences(
            enabledTypes: Set(NotificationType.allCases),
            preferredHours: TimeRange(start: 9, end: 18),
            silentHours: TimeRange(start: 22, end: 8),
            maxDailyNotifications: 5
        )
    }
}

struct TimeRange: Codable {
    let start: Int // Heure (0-23)
    let end: Int   // Heure (0-23)
}

*/
