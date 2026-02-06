//
//  QuickBlockModesSection.swift
//  zenloop
//
//  Section avec 4 modes de blocage rapide (Social, AI, Gaming, Adult)
//  Chaque mode permet de sélectionner des apps via FamilyActivityPicker
//  et de les bloquer instantanément ou de scheduler le blocage
//

import SwiftUI
import FamilyControls

struct QuickBlockModesSection: View {
    @StateObject private var viewModel = QuickBlockViewModel()
    @State private var showingPicker = false
    @State private var selectedCategoryType: QuickBlockCategoryType?
    let showContent: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Divider subtil
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)

            // Grid de 4 modes
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(QuickBlockCategoryType.allCases) { categoryType in
                    QuickBlockModeCard(
                        categoryType: categoryType,
                        category: viewModel.categories[categoryType],
                        onTap: {
                            selectedCategoryType = categoryType
                            showingPicker = true
                        },
                        onBlockNow: {
                            Task {
                                await viewModel.blockNow(categoryType: categoryType)
                            }
                        },
                        onSchedule: {
                            // TODO: Implémenter la sheet de scheduling
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: showContent)
        .familyActivityPicker(
            isPresented: $showingPicker,
            selection: Binding(
                get: {
                    guard let type = selectedCategoryType else { return FamilyActivitySelection() }
                    return viewModel.categories[type]?.selection ?? FamilyActivitySelection()
                },
                set: { newSelection in
                    guard let type = selectedCategoryType else { return }
                    viewModel.updateSelection(for: type, selection: newSelection)
                }
            )
        )
    }
}

// MARK: - Quick Block Card
struct QuickBlockModeCard: View {
    let categoryType: QuickBlockCategoryType
    let category: QuickBlockCategory?
    let onTap: () -> Void
    let onBlockNow: () -> Void
    let onSchedule: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Image de fond avec texte
            ZStack(alignment: .top) {
                GeometryReader { geometry in
                    Image(categoryType.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 140)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.2),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 140)

                // Texte au-dessus de l'image
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: categoryType.systemIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                            Text(categoryType.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                .frame(height: 140)
            }
            .onTapGesture {
                onTap()
            }

            // Pile des apps sélectionnées
            if let category = category, category.hasAppsSelected {
                VStack(spacing: 8) {
                    // Preview des apps (max 4 tokens en pile)
                    HStack(spacing: -10) {
                        ForEach(Array(category.selection.applicationTokens.prefix(4)), id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }

                        if category.appsCount > 4 {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )

                                Text("+\(category.appsCount - 4)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.top, 10)

                    Text("\(category.appsCount) app\(category.appsCount > 1 ? "s" : "") sélectionnée\(category.appsCount > 1 ? "s" : "")")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))

                    // Boutons d'action
                    HStack(spacing: 8) {
                        Button(action: onBlockNow) {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 10))
                                Text("Bloquer")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.8), Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(8)
                        }

                        Button(action: onSchedule) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - ViewModel
@MainActor
class QuickBlockViewModel: ObservableObject {
    @Published var categories: [QuickBlockCategoryType: QuickBlockCategory] = [:]

    private let sharedDefaults = UserDefaults(suiteName: "group.com.app.zenloop")

    init() {
        // Initialiser les 4 catégories
        for type in QuickBlockCategoryType.allCases {
            categories[type] = QuickBlockCategory(type: type)
        }

        // Charger les sélections sauvegardées
        loadSelections()
    }

    func updateSelection(for type: QuickBlockCategoryType, selection: FamilyActivitySelection) {
        categories[type]?.selection = selection
        saveSelection(for: type)
    }

    func blockNow(categoryType: QuickBlockCategoryType) async {
        guard let category = categories[categoryType], category.hasAppsSelected else {
            print("❌ [QUICK_BLOCK] No apps selected for \(categoryType.displayName)")
            return
        }

        print("🛡️ [QUICK_BLOCK] Blocking \(category.appsCount) apps for \(categoryType.displayName)")

        // Bloquer via GlobalShieldManager
        let selection = category.selection
        for token in selection.applicationTokens {
            let blockId = "quick_block_\(categoryType.rawValue)_\(UUID().uuidString)"
            GlobalShieldManager.shared.addBlock(
                token: token,
                blockId: blockId,
                appName: categoryType.displayName
            )
        }

        // Marquer comme actif
        categories[categoryType]?.isActive = true
        saveSelection(for: categoryType)
    }

    // MARK: - Persistence
    private func saveSelection(for type: QuickBlockCategoryType) {
        guard let category = categories[type] else { return }

        do {
            let data = try JSONEncoder().encode(category.selection)
            sharedDefaults?.set(data, forKey: "quick_block_\(type.rawValue)_selection")
            sharedDefaults?.synchronize()
            print("💾 [QUICK_BLOCK] Saved selection for \(type.displayName)")
        } catch {
            print("❌ [QUICK_BLOCK] Failed to save: \(error)")
        }
    }

    private func loadSelections() {
        for type in QuickBlockCategoryType.allCases {
            guard let data = sharedDefaults?.data(forKey: "quick_block_\(type.rawValue)_selection"),
                  let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                continue
            }

            categories[type]?.selection = selection
            print("📖 [QUICK_BLOCK] Loaded selection for \(type.displayName)")
        }
    }
}

// MARK: - Helper pour corner radius spécifiques
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    QuickBlockModesSection(showContent: true)
        .background(Color.black)
}
