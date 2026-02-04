//
//  HomeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 03/08/2025.
//

import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    // Lazy loading des managers pour éviter l'initialisation lourde
    private var badgeManager: BadgeManager { BadgeManager.shared }
    private var categoryManager: CategoryManager { CategoryManager.shared }
    private var purchaseManager: PurchaseManager { PurchaseManager.shared }
    @StateObject private var dailyReportManager = DailyReportManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var topAppsDisplayManager = TopAppsDisplayManager.shared
    @State private var showContent = false
    @State private var syncTimer: Timer?


    // MARK: - Computed Properties
    
    private var isIdle: Bool {
        zenloopManager.currentState == .idle
    }
    
    private var isActive: Bool {
        zenloopManager.currentState != .idle
    }
    
    
    var body: some View {
        ZStack {
            // Background optimisé - moins gourmand en ressources
            OptimizedBackground(currentState: zenloopManager.currentState)
                .ignoresSafeArea(.all, edges: .all)

            // Interface principale
            VStack(spacing: 0) {
                // Header minimaliste
                MinimalHeader(
                    showContent: showContent,
                    currentState: zenloopManager.currentState,
                    isPremium: purchaseManager.isPremium,
                    zenloopManager: zenloopManager
                )
                .padding(.horizontal, 20)
               
                
                // Contenu principal avec espacement amélioré
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10 ) {
                        // Timer Card en priorité absolue (toujours au top si idle)
                        if isIdle {
                            TimerCard(zenloopManager: zenloopManager, showContent: showContent)
                                .padding(.top, 20)

                            // Upcoming Scheduled Sessions
                            UpcomingSessionsCard(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )

                            // Session Planning directement après TimerCard
                            SessionPlanningRow(
                                zenloopManager: zenloopManager,
                                showContent: showContent
                            )
                        }

                        // Section principale selon l'état
                        primarySection
                        
                        // Sections conditionnelles selon l'état avec transitions fluides
                        Group {
                            if isIdle {
                                idleSections
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            } else {
                                activeSections
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isIdle)
                        
                        // Sections communes
                        commonSections

                        // Espace de respiration en bas pour la card des top apps
                        Spacer(minLength: topAppsDisplayManager.shouldShowCard ? 300 : 80)
                    }
                    .padding(.horizontal, 0)
                }
                .frame(maxHeight: .infinity)
            }

            // Plus de bottom bar - maintenant intégrée en carte

            // Card des top 3 apps (bottom sheet draggable) - DÉSACTIVÉ
            // if topAppsDisplayManager.shouldShowCard {
            //     Color.clear
            //         .sheet(isPresented: .constant(true)) {
            //             TopAppsBottomSheet(onDismiss: {
            //                 topAppsDisplayManager.dismissCard()
            //             })
            //             .presentationDetents([.height(500), .large])
            //             .presentationDragIndicator(.visible)
            //             .presentationBackgroundInteraction(.enabled)
            //         }
            // }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                showContent = true
            }
            // backgroundAnimator.startAnimation() // ⚠️ DÉSACTIVÉ - CPU KILLER
            badgeManager.checkForNewBadges(zenloopManager: zenloopManager)

            // Synchroniser l'état des sessions en arrière-plan
            Task {
                await synchronizeBackgroundSessions()
            }

            // Démarrer la synchronisation périodique
            startPeriodicSync()

            // Vérifier si on doit afficher la card des top apps (après un délai pour que la vue soit prête)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("🎯 [HOMEVIEW] Déclenchement vérification TopAppsCard")
                topAppsDisplayManager.checkIfShouldShow()
            }
            
            // Désactivé: Vérification du rapport quotidien
            // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //     dailyReportManager.checkShouldShowReport()
            // }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-synchroniser quand l'app devient active
            Task {
                await synchronizeBackgroundSessions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TopAppsCardDismissRequested"))) { _ in
            // L'extension a demandé de fermer la card
            print("📡 [HOMEVIEW] Réception demande de fermeture de la TopAppsCard")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                topAppsDisplayManager.dismissCard()
            }
        }
        .onDisappear {
            // backgroundAnimator.stopAnimation() // ⚠️ DÉSACTIVÉ - CPU KILLER
            stopPeriodicSync()
        }
        .onChange(of: zenloopManager.currentState) { newValue in
            // Badge checking différé pour éviter les appels trop fréquents
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                badgeManager.checkForNewBadges(zenloopManager: zenloopManager)
            }
            
            // Feedback haptique léger seulement pour les transitions importantes
            if newValue == .active || newValue == .completed {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        // Désactivé: Affichage du rapport quotidien
        // .sheet(isPresented: $dailyReportManager.shouldShowReport) {
        //     DailyReportModal(
        //         isPresented: $dailyReportManager.shouldShowReport,
        //         timeOfDay: convertTimeOfDay(dailyReportManager.currentTimeOfDay)
        //     )
        //     .onDisappear {
        //         dailyReportManager.markReportAsShown()
        //     }
        // }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var primarySection: some View {
        HeroSection(
            currentState: zenloopManager.currentState,
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        .padding(.top, 10)
    }
    
    @ViewBuilder
    private var idleSections: some View {
        EmptyView()
    }
    
    @ViewBuilder
    private var activeSections: some View {
        ActiveChallengeSection(
            zenloopManager: zenloopManager,
            showContent: showContent
        )
        .padding(.top, 30)
    }
    
    @ViewBuilder
    private var commonSections: some View {
        StatsInsightsSection(
            badgeManager: badgeManager,
            zenloopManager: zenloopManager,
            showContent: showContent
        )
    }
    
    // MARK: - Helper Functions
    
    private func convertTimeOfDay(_ timeOfDay: DailyReportManager.TimeOfDay) -> DailyTimeOfDay {
        switch timeOfDay {
        case .morning: return .morning
        case .afternoon: return .afternoon  
        case .evening: return .evening
        }
    }
    
    // MARK: - Safe Area helpers
    
    private func getSafeAreaTop() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.top
    }
    
    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
    
    private func getTabBarHeight() -> CGFloat {
        // Hauteur standard de la tab bar iOS (49pt + safe area)
        return 49
    }
    
    // MARK: - Background Session Synchronization
    
    @MainActor
    private func synchronizeBackgroundSessions() async {
        print("🔄 [HOMEVIEW] Synchronisation des sessions en arrière-plan...")
        
        // 1. Forcer la mise à jour du statut des sessions programmées
        zenloopManager.updateScheduledSessionsStatus()
        
        // 2. Vérifier s'il y a une session active en arrière-plan qui n'est pas reflétée dans l'UI
        await checkAndRestoreActiveSession()
        
        // 3. Nettoyer les sessions expirées
        cleanupExpiredSessions()
        
        // 4. Synchroniser avec l'extension Device Activity
        await syncWithDeviceActivityExtension()
        
        print("✅ [HOMEVIEW] Synchronisation terminée - État: \(zenloopManager.currentState)")
    }
    
    @MainActor
    private func checkAndRestoreActiveSession() async {
        // Si l'état local indique que nous sommes idle mais qu'une session pourrait être active
        if zenloopManager.currentState == ZenloopState.idle {
            // Vérifier avec le challenge actuel
            if let challenge = zenloopManager.currentChallenge,
               challenge.isActive && !isExpired(challenge) {
                
                print("🔄 [HOMEVIEW] Session active détectée, restoration de l'état UI...")
                
                // Restaurer l'état dans l'interface
                zenloopManager.currentState = ZenloopState.active
                zenloopManager.currentTimeRemaining = challenge.timeRemaining
                zenloopManager.currentProgress = challenge.safeProgress
                
                // Les restrictions seront appliquées automatiquement par le ZenloopManager
                // quand l'état change à .active
                
                print("✅ [HOMEVIEW] État restauré - Temps restant: \(challenge.timeRemaining)s")
            }
        }
    }
    
    @MainActor
    private func syncWithDeviceActivityExtension() async {
        // Lire les événements de l'extension via DeviceActivityCoordinator
        // Ceci implémente le polling décrit dans la documentation
        
        print("🔄 [HOMEVIEW] Lecture des événements de l'extension...")
        
        // Lire directement les événements de l'extension depuis App Groups
        checkExtensionEvents()
        
        print("✅ [HOMEVIEW] Événements de l'extension traités")
    }
    
    // MARK: - Extension Events Processing
    
    private func checkExtensionEvents() {
        guard let suite = UserDefaults(suiteName: "group.com.app.zenloop") else {
            print("❌ [HOMEVIEW] Cannot access App Group")
            return
        }
        
        // Lire les événements de l'extension (comme dans DeviceActivityCoordinator)
        if let events = suite.array(forKey: "device_activity_events") as? [[String: Any]], !events.isEmpty {
            print("📡 [HOMEVIEW] \(events.count) événements reçus de l'extension")
            
            for event in events {
                if let eventType = event["event"] as? String,
                   let activity = event["activity"] as? String,
                   let timestamp = event["timestamp"] as? TimeInterval {
                    processExtensionEvent(type: eventType, activity: activity, timestamp: timestamp)
                }
            }
            
            // Nettoyer les événements après traitement
            suite.removeObject(forKey: "device_activity_events")
            suite.synchronize()
        }
        
        // Vérifier la queue d'activation des sessions
        if let activationQueue = suite.array(forKey: "extension_activation_queue") as? [[String: Any]], !activationQueue.isEmpty {
            print("🔄 [HOMEVIEW] \(activationQueue.count) sessions en queue d'activation")
            // Déléguer au ZenloopManager pour traiter les sessions activées
            // (La méthode existe déjà dans le timer de ZenloopManager)
        }
    }
    
    private func processExtensionEvent(type: String, activity: String, timestamp: TimeInterval) {
        print("📨 [HOMEVIEW] Event reçu: \(type) pour activité: \(activity)")
        
        switch type {
        case "intervalDidStart":
            handleSessionStartedByExtension(activity: activity)
        case "intervalDidEnd":
            handleSessionEndedByExtension(activity: activity)
        case "thresholdReached":
            handleThresholdReached(activity: activity)
        default:
            print("❓ [HOMEVIEW] Type d'événement inconnu: \(type)")
        }
    }
    
    private func handleSessionStartedByExtension(activity: String) {
        print("🚀 [HOMEVIEW] Session démarrée par l'extension: \(activity)")
        
        // Mise à jour de l'UI pour refléter que la session est active
        Task { @MainActor in
            await synchronizeBackgroundSessions()
            
            // Afficher une notification à l'utilisateur
            showSessionStartedAlert(activity: activity)
        }
    }
    
    private func handleSessionEndedByExtension(activity: String) {
        print("🏁 [HOMEVIEW] Session terminée par l'extension: \(activity)")
        
        // Mise à jour de l'UI 
        Task { @MainActor in
            await synchronizeBackgroundSessions()
            
            // Afficher une notification de fin
            showSessionCompletedAlert(activity: activity)
        }
    }
    
    private func handleThresholdReached(activity: String) {
        print("⚠️ [HOMEVIEW] Seuil atteint pour: \(activity)")
        // Potentiellement afficher une alerte ou notification
    }
    
    private func showSessionStartedAlert(activity: String) {
        // TODO: Implémenter une alerte/banner pour informer que la session programmée a démarré
        print("🎯 [HOMEVIEW] Affichage: Session active - \(activity)")
    }
    
    private func showSessionCompletedAlert(activity: String) {
        // TODO: Implémenter une alerte/banner de félicitations pour session terminée
        print("🎉 [HOMEVIEW] Affichage: Session complétée - \(activity)")
    }
    
    // MARK: - Helper Methods
    
    private func isExpired(_ challenge: ZenloopChallenge) -> Bool {
        guard let startTime = challenge.startTime else { return false }
        let endTime = startTime.addingTimeInterval(challenge.duration)
        return Date() > endTime
    }
    
    private func cleanupExpiredSessions() {
        // Nettoyer les sessions programmées expirées
        zenloopManager.cleanupExpiredSessions()
        
        // Si la session actuelle est expirée, la terminer
        if let challenge = zenloopManager.currentChallenge,
           challenge.isActive && isExpired(challenge) {
            print("🧹 [HOMEVIEW] Session expirée détectée, nettoyage...")
            // La session sera automatiquement marquée comme complétée par le timer interne
        }
    }
    
    // MARK: - Periodic Sync Management
    
    private func startPeriodicSync() {
        // Arrêter le timer existant s'il y en a un
        stopPeriodicSync()
        
        // Créer un nouveau timer qui se déclenche toutes les 8 secondes (selon documentation)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            Task { @MainActor in
                // Ne synchroniser que si l'app est active et visible
                if UIApplication.shared.applicationState == .active {
                    // Polling des événements de l'extension (priorité haute)
                    checkExtensionEvents()
                    
                    // Synchronisation complète moins fréquemment
                    if Int(Date().timeIntervalSince1970) % 30 == 0 { // Toutes les 30s pour la sync complète
                        await synchronizeBackgroundSessions()
                    }
                }
            }
        }
        
        print("⏰ [HOMEVIEW] Timer de polling démarré (8s selon documentation)")
    }
    
    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("⏰ [HOMEVIEW] Timer de synchronisation périodique arrêté")
    }

}

// MARK: - Top Apps Bottom Sheet

struct TopAppsBottomSheet: View {
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header avec bouton fermer
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps les Plus Utilisées")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("Aujourd'hui")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button {
                    onDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Contenu: DeviceActivityReport
            ScrollView {
                TopAppToastContainer(isShowing: Binding.constant(true))
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }

            Spacer()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(ZenloopManager.shared)
}
