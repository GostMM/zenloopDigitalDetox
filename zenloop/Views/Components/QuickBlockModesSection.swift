//
//  QuickBlockModesSection.swift
//  zenloop
//
//  Redesign v2: Larger icons, better card layout, clearer UX
//  11/04/2026
//

import SwiftUI
import FamilyControls
import ManagedSettings

#if os(iOS)

// MARK: - Quick Block Modes Section

struct QuickBlockModesSection: View {
    @EnvironmentObject var zenloopManager: ZenloopManager
    @StateObject private var viewModel = QuickBlockViewModel()
    @State private var showingPicker = false
    @State private var showingScheduleModal = false
    @State private var selectedCategoryType: QuickBlockCategoryType?
    let showContent: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            subtleDivider
                .padding(.vertical, 20)

            // Grid 2×2
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(QuickBlockCategoryType.allCases) { categoryType in
                    QuickBlockModeCard(
                        categoryType: categoryType,
                        category: viewModel.categories[categoryType],
                        onTap: {
                            selectedCategoryType = categoryType
                            showingPicker = true
                        },
                        onBlockNow: {
                            Task { await viewModel.blockNow(categoryType: categoryType) }
                        },
                        onSchedule: {
                            selectedCategoryType = categoryType
                            showingScheduleModal = true
                        },
                        onUnblock: {
                            Task { await viewModel.unblock(categoryType: categoryType) }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
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
        .sheet(isPresented: $showingScheduleModal) {
            if let categoryType = selectedCategoryType,
               let category = viewModel.categories[categoryType],
               category.hasAppsSelected {
                QuickBlockScheduleModal(
                    categoryType: categoryType,
                    selectedApps: category.selection,
                    zenloopManager: zenloopManager,
                    onSessionStarted: { startTime, duration in
                        viewModel.markSessionActive(
                            categoryType: categoryType,
                            startTime: startTime,
                            duration: duration
                        )
                    }
                )
            }
        }
    }

    private var subtleDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 40)
    }
}

// MARK: - Quick Block Card (Redesigned)

struct QuickBlockModeCard: View {
    let categoryType: QuickBlockCategoryType
    let category: QuickBlockCategory?
    let onTap: () -> Void
    let onBlockNow: () -> Void
    let onSchedule: () -> Void
    let onUnblock: () -> Void

    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var hasApps: Bool { category?.hasAppsSelected == true }
    private var isActive: Bool { category?.isActive == true }
    private var categoryColor: Color { categoryType.themeColor }

    // Fixed card height so all 4 cards align in the grid
    private let cardImageHeight: CGFloat = 140
    private let cardBottomHeight: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: image background + icon + name ──
            cardHeader

            // ── Bottom: apps + actions ──
            cardContent
                .frame(height: cardBottomHeight)
        }
        .frame(height: cardImageHeight + cardBottomHeight)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isActive ? Color.green.opacity(0.2) : Color.white.opacity(0.05),
                    lineWidth: 0.5
                )
        )
        .onReceive(timer) { _ in currentTime = Date() }
    }

    // MARK: - Card Header (image + icon + name)

    private var cardHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // ── Background image from asset catalog ──
            GeometryReader { geo in
                Image(categoryType.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: cardImageHeight)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Active overlay (if session running)
            if isActive, let endTime = activeEndTime, endTime > currentTime {
                activeSessionOverlay(endTime: endTime)
            }

            // Normal header content (hidden when active)
            if !isActive || activeEndTime == nil || (activeEndTime ?? .distantPast) <= currentTime {
                headerContent
            }

            // Select / Edit apps pill (top-right)
            if !isActive {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onTap) {
                            HStack(spacing: 4) {
                                Image(systemName: hasApps ? "pencil" : "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text(hasApps ? "Edit" : "Select")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(hasApps
                                          ? Color.white.opacity(0.2)
                                          : Color.white.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        }
                        .padding(10)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: cardImageHeight)
        .clipped()
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Icon in a frosted rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )

                Image(systemName: categoryType.systemIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }

            // Category name
            Text(categoryType.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 3, y: 2)
        }
        .padding(12)
    }

    // MARK: - Active Session Overlay

    private func activeSessionOverlay(endTime: Date) -> some View {
        let isPermanent = (category?.scheduledDuration ?? 0) >= 12 * 60 * 60

        return ZStack {
            // Dark overlay
            Rectangle()
                .fill(Color.black.opacity(0.8))

            // Green tint
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.green.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                // Shield icon
                Image(systemName: "shield.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.4), radius: 8)

                // Time or status
                if isPermanent {
                    Text(String(localized: "active_status"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(timeRemaining(until: endTime))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text(isPermanent
                     ? String(localized: "permanent_block")
                     : String(localized: "active_block"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // Unblock button
                Button(action: onUnblock) {
                    Text(String(localized: "unblock"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.red.opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .padding(.top, 2)
            }
        }
        .frame(height: cardImageHeight)
    }

    // MARK: - Card Content (bottom half)

    private var cardContent: some View {
        VStack(spacing: 0) {
            if hasApps {
                // Apps preview row
                appsPreviewRow
                    .padding(.top, 12)

                Spacer(minLength: 6)

                // Action buttons (only when not active)
                if !isActive {
                    actionButtons
                }
            } else {
                Spacer(minLength: 8)
                // Empty state: invite to select
                emptyStateButton
                Spacer(minLength: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    // MARK: - Apps Preview Row

    private var appsPreviewRow: some View {
        HStack(spacing: 0) {
            // App icons (stacked) — token types are iOS-only
            #if os(iOS)
            HStack(spacing: -6) {
                if let category = category {
                    ForEach(
                        Array(category.selection.applicationTokens.prefix(3)),
                        id: \.self
                    ) { token in
                        appTokenCircle(token: token)
                    }

                    ForEach(
                        Array(category.selection.categoryTokens.prefix(
                            max(0, 3 - category.selection.applicationTokens.count)
                        )),
                        id: \.self
                    ) { token in
                        categoryTokenCircle(token: token)
                    }

                    if category.appsCount > 3 {
                        overflowBadge(count: category.appsCount - 3)
                    }
                }
            }
            #endif

            Spacer()

            // Total count
            if let category = category {
                Text("\(category.appsCount) apps")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    #if os(iOS)
    private func appTokenCircle(token: ApplicationToken) -> some View {
        Label(token)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 28)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.black.opacity(0.7), lineWidth: 1.5)
            )
    }

    private func categoryTokenCircle(token: ActivityCategoryToken) -> some View {
        Label(token)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 28)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.black.opacity(0.7), lineWidth: 1.5)
            )
    }
    #endif

    private func overflowBadge(count: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(.white.opacity(0.35))
            .frame(width: 28, height: 28)
            .background(Circle().fill(Color.white.opacity(0.06)))
            .overlay(
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 6) {
            // Block now
            Button(action: onBlockNow) {
                HStack(spacing: 5) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 11, weight: .bold))

                    Text(String(localized: "block_now"))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.1))
                )
            }

            // Schedule
            Button(action: onSchedule) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                    )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateButton: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Plus icon
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }

                Text("Select apps to block")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
                    .foregroundColor(.white.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var activeEndTime: Date? {
        guard let startTime = category?.scheduledStartTime,
              let duration = category?.scheduledDuration else { return nil }
        return startTime.addingTimeInterval(duration)
    }

    private func timeRemaining(until endTime: Date) -> String {
        let remaining = endTime.timeIntervalSince(currentTime)
        guard remaining > 0 else { return "0:00" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Theme Color Extension

extension QuickBlockCategoryType {
    /// Color associated with each category for the card gradient & icon tint
    var themeColor: Color {
        switch self {
        case .social:  return Color(red: 0.71, green: 0.48, blue: 1.0)   // purple
        case .gaming:  return Color(red: 0.13, green: 0.77, blue: 0.37)  // green
        case .adult:   return Color(red: 0.89, green: 0.29, blue: 0.29)  // red
        default:       return Color(red: 0.05, green: 0.65, blue: 0.91)  // cyan-blue (AI, etc.)
        }
    }
}

// MARK: - ViewModel (unchanged logic, cleaned up)

@MainActor
class QuickBlockViewModel: ObservableObject {
    @Published var categories: [QuickBlockCategoryType: QuickBlockCategory] = [:]

    private let sharedDefaults = UserDefaults(suiteName: "group.com.app.zenloop")

    init() {
        for type in QuickBlockCategoryType.allCases {
            categories[type] = QuickBlockCategory(type: type)
        }
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

        let selection = category.selection
        let blockId = "quick_block_\(categoryType.rawValue)"

        print("🛡️ [QUICK_BLOCK] Blocking \(category.appsCount) tokens for \(categoryType.displayName)")

        for token in selection.applicationTokens {
            GlobalShieldManager.shared.addBlock(
                token: token, blockId: blockId, appName: categoryType.displayName
            )
        }
        for token in selection.categoryTokens {
            GlobalShieldManager.shared.addCategoryBlock(
                token: token, blockId: blockId, categoryName: categoryType.displayName
            )
        }

        let startTime = Date()
        let duration: TimeInterval = 24 * 60 * 60

        categories[categoryType]?.isActive = true
        categories[categoryType]?.scheduledStartTime = startTime
        categories[categoryType]?.scheduledDuration = duration
        saveSelection(for: categoryType)
    }

    func unblock(categoryType: QuickBlockCategoryType) async {
        guard let category = categories[categoryType] else { return }

        let selection = category.selection
        let blockId = "quick_block_\(categoryType.rawValue)"

        print("🔓 [QUICK_BLOCK] Unblocking \(categoryType.displayName)")

        for token in selection.applicationTokens {
            GlobalShieldManager.shared.removeBlock(
                token: token, blockId: blockId, appName: categoryType.displayName
            )
        }
        for token in selection.categoryTokens {
            GlobalShieldManager.shared.removeCategoryBlock(
                token: token, blockId: blockId, categoryName: categoryType.displayName
            )
        }

        categories[categoryType]?.isActive = false
        categories[categoryType]?.scheduledStartTime = nil
        categories[categoryType]?.scheduledDuration = nil
        saveSelection(for: categoryType)
    }

    func markSessionActive(
        categoryType: QuickBlockCategoryType,
        startTime: Date,
        duration: TimeInterval
    ) {
        categories[categoryType]?.isActive = true
        categories[categoryType]?.scheduledStartTime = startTime
        categories[categoryType]?.scheduledDuration = duration
        saveSelection(for: categoryType)
    }

    // MARK: Persistence

    private func saveSelection(for type: QuickBlockCategoryType) {
        guard let category = categories[type] else { return }
        do {
            let data = try JSONEncoder().encode(category)
            sharedDefaults?.set(data, forKey: "quick_block_\(type.rawValue)_category")
            sharedDefaults?.synchronize()
        } catch {
            print("❌ [QUICK_BLOCK] Save failed: \(error)")
        }
    }

    private func loadSelections() {
        for type in QuickBlockCategoryType.allCases {
            guard let data = sharedDefaults?.data(forKey: "quick_block_\(type.rawValue)_category"),
                  let category = try? JSONDecoder().decode(QuickBlockCategory.self, from: data)
            else { continue }
            categories[type] = category
        }
    }
}

// MARK: - Corner Radius Helper

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

#endif