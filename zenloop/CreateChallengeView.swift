//
//  CreateChallengeView.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import SwiftUI
import FamilyControls

struct CreateChallengeView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var zenloopManager: ZenloopManager
    
    // Form state
    @State private var challengeTitle = ""
    @State private var selectedDuration: TimeInterval = 25 * 60 // 25 minutes par défaut
    @State private var selectedDifficulty: DifficultyLevel = .medium
    @State private var appSelection = FamilyActivitySelection()
    @State private var showingAppPicker = false
    @State private var isCreating = false
    
    // Animation states
    @State private var currentStep = 0
    @State private var showSteps = false
    
    private let maxSteps = 4
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Progress indicator
                        progressIndicator
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Current step content
                        stepContent
                            .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom action bar
                VStack {
                    Spacer()
                    bottomActionBar
                        .padding()
                        .background(Material.ultraThinMaterial)
                }
            }
            .navigationTitle("Nouveau Défi")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Annuler") {
                    isPresented = false
                },
                trailing: EmptyView()
            )
        }
        .sheet(isPresented: $showingAppPicker) {
            ModernFamilyActivityPicker(
                selection: $appSelection,
                isPresented: $showingAppPicker
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
                showSteps = true
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<maxSteps, id: \.self) { step in
                ZStack {
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.accentColor.opacity(0.2))
                        .frame(width: 30, height: 30)
                    
                    if step < currentStep {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(step + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(step == currentStep ? .white : .accentColor)
                    }
                }
                .scaleEffect(showSteps ? 1.0 : 0.5)
                .opacity(showSteps ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(step) * 0.1), value: showSteps)
                
                if step < maxSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? Color.accentColor : Color.accentColor.opacity(0.2))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            titleStep
        case 1:
            durationStep
        case 2:
            difficultyStep
        case 3:
            appSelectionStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Title
    
    private var titleStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "textformat",
                title: "Nomme ton défi",
                subtitle: "Donne-lui un nom motivant qui te donnera envie de le réussir"
            )
            
            VStack(spacing: 16) {
                TextField("Ex: Mode productivité", text: $challengeTitle)
                    .textFieldStyle(ModernTextFieldStyle())
                
                // Suggestions rapides
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(titleSuggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            challengeTitle = suggestion
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
            }
        }
    }
    
    private let titleSuggestions = [
        "Focus Mode", "Deep Work", "Productif", "Sans Distraction"
    ]
    
    // MARK: - Step 2: Duration
    
    private var durationStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "clock",
                title: "Choisis la durée",
                subtitle: "Combien de temps veux-tu rester concentré ?"
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(durationOptions.enumerated()), id: \.offset) { _, option in
                    DurationOptionCard(
                        title: option.0,
                        duration: option.1,
                        isSelected: selectedDuration == option.1
                    ) {
                        selectedDuration = option.1
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
    }
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 min", 15 * 60),
        ("25 min", 25 * 60),
        ("45 min", 45 * 60),
        ("1h", 60 * 60),
        ("1h30", 90 * 60),
        ("2h", 2 * 60 * 60)
    ]
    
    // MARK: - Step 3: Difficulty
    
    private var difficultyStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "slider.horizontal.3",
                title: "Niveau de défi",
                subtitle: "Jusqu'où veux-tu te challenger ?"
            )
            
            VStack(spacing: 16) {
                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyLevelCard(
                        level: level,
                        isSelected: selectedDifficulty == level
                    ) {
                        selectedDifficulty = level
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 4: App Selection
    
    private var appSelectionStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "apps.iphone",
                title: "Apps à bloquer",
                subtitle: "Sélectionne les apps qui te distraient le plus"
            )
            
            Button(action: {
                if !zenloopManager.isAuthorized {
                    Task {
                        await zenloopManager.requestAuthorization()
                        if zenloopManager.isAuthorized {
                            showingAppPicker = true
                        }
                    }
                } else {
                    showingAppPicker = true
                }
            }) {
                AppSelectionCard(
                    appCount: appSelection.applicationTokens.count,
                    hasApps: !appSelection.applicationTokens.isEmpty
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if !appSelection.applicationTokens.isEmpty {
                Text("\(appSelection.applicationTokens.count) apps sélectionnées")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Précédent") {
                    withAnimation(.spring()) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(actionButtonTitle) {
                handleActionButton()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCurrentStepInvalid || isCreating)
            .overlay(
                Group {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
            )
        }
    }
    
    private var actionButtonTitle: String {
        if isCreating {
            return "Création..."
        } else if currentStep < maxSteps - 1 {
            return "Suivant"
        } else {
            return "Créer le défi"
        }
    }
    
    private var isCurrentStepInvalid: Bool {
        switch currentStep {
        case 0: return challengeTitle.isEmpty
        case 1: return false // Durée toujours valide
        case 2: return false // Difficulté toujours valide
        case 3: return appSelection.applicationTokens.isEmpty
        default: return false
        }
    }
    
    // MARK: - Actions
    
    private func handleActionButton() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if currentStep < maxSteps - 1 {
            withAnimation(.spring()) {
                currentStep += 1
            }
        } else {
            createChallenge()
        }
    }
    
    private func createChallenge() {
        guard !challengeTitle.isEmpty, !appSelection.applicationTokens.isEmpty else { return }
        
        isCreating = true
        
        // Simuler un délai de création
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            zenloopManager.startCustomChallenge(
                title: challengeTitle,
                duration: selectedDuration,
                difficulty: selectedDifficulty,
                apps: appSelection
            )
            
            isCreating = false
            isPresented = false
            
            // Feedback de succès
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // MARK: - Helper Views
    
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom)
    }
}

// MARK: - Supporting Views

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1), in: Capsule())
                .foregroundColor(.accentColor)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DurationOptionCard: View {
    let title: String
    let duration: TimeInterval
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(durationDescription)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var durationDescription: String {
        if duration < 3600 {
            return "Sprint"
        } else if duration < 7200 {
            return "Focus"
        } else {
            return "Marathon"
        }
    }
}

struct DifficultyLevelCard: View {
    let level: DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: level.icon)
                        .font(.title2)
                        .foregroundColor(level.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Material.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.accentColor.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppSelectionCard: View {
    let appCount: Int
    let hasApps: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(height: 100)
                
                VStack(spacing: 8) {
                    Image(systemName: hasApps ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 40))
                        .foregroundColor(hasApps ? .green : .accentColor)
                    
                    Text(hasApps ? "Apps sélectionnées" : "Sélectionner des apps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            if hasApps {
                Text("\(appCount) apps seront bloquées pendant ton défi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct ModernFamilyActivityPicker: View {
    @Binding var selection: FamilyActivitySelection
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "apps.iphone")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    
                    Text("Sélectionne tes distractions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choisis les apps que tu veux bloquer pendant ton défi")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                FamilyActivityPicker(selection: $selection)
                    .frame(maxHeight: 400)
                    .onChange(of: selection) { oldValue, newValue in
                        logFamilyActivitySelection(oldValue: oldValue, newValue: newValue)
                    }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Confirmer") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    
                    Button("Annuler") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Apps à bloquer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Extensions

extension DifficultyLevel {
    var description: String {
        switch self {
        case .easy: return "Parfait pour commencer"
        case .medium: return "Un bon équilibre"
        case .hard: return "Pour les plus motivés"
        }
    }
}

// MARK: - Logging Functions

private func logFamilyActivitySelection(oldValue: FamilyActivitySelection, newValue: FamilyActivitySelection) {
    print("\n🔍 [FAMILY ACTIVITY SELECTION] ===================")
    print("📊 CHANGEMENT DE SÉLECTION DÉTECTÉ")
    
    // Logging de l'ancienne sélection
    print("\n📋 ANCIENNE SÉLECTION:")
    logSelectionDetails(selection: oldValue, prefix: "OLD")
    
    // Logging de la nouvelle sélection
    print("\n📋 NOUVELLE SÉLECTION:")
    logSelectionDetails(selection: newValue, prefix: "NEW")
    
    print("🔍 [FAMILY ACTIVITY SELECTION] ===================\n")
}

private func logSelectionDetails(selection: FamilyActivitySelection, prefix: String) {
    // Applications
    print("  \(prefix) Applications count: \(selection.applications.count)")
    print("  \(prefix) ApplicationTokens count: \(selection.applicationTokens.count)")
    
    if !selection.applications.isEmpty {
        print("  \(prefix) Applications détails:")
        for (index, app) in selection.applications.enumerated() {
            print("    [\(index)] localizedDisplayName: '\(app.localizedDisplayName ?? "nil")'")
            print("    [\(index)] bundleIdentifier: '\(app.bundleIdentifier ?? "nil")'")
            print("    [\(index)] token: \(app.token)")
            
            // Essayer d'extraire plus d'infos si disponibles
            let mirror = Mirror(reflecting: app)
            for child in mirror.children {
                if let label = child.label, label != "localizedDisplayName", 
                   label != "bundleIdentifier", label != "token" {
                    print("    [\(index)] \(label): \(child.value)")
                }
            }
            print("")
        }
    }
    
    // Catégories
    print("  \(prefix) Categories count: \(selection.categories.count)")
    print("  \(prefix) CategoryTokens count: \(selection.categoryTokens.count)")
    
    if !selection.categories.isEmpty {
        print("  \(prefix) Categories détails:")
        for (index, category) in selection.categories.enumerated() {
            print("    [\(index)] localizedDisplayName: '\(category.localizedDisplayName ?? "nil")'")
            print("    [\(index)] token: \(category.token)")
        }
    }
    
    // Web Domains
    print("  \(prefix) WebDomains count: \(selection.webDomains.count)")
    print("  \(prefix) WebDomainTokens count: \(selection.webDomainTokens.count)")
    
    if !selection.webDomains.isEmpty {
        print("  \(prefix) WebDomains détails:")
        for (index, domain) in selection.webDomains.enumerated() {
            print("    [\(index)] domain: '\(domain.domain ?? "nil")'")
            print("    [\(index)] token: \(domain.token)")
        }
    }
}

#Preview {
    CreateChallengeView(isPresented: .constant(true))
        .environmentObject(ZenloopManager.shared)
}