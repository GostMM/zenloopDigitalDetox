//
//  OpalTabBar.swift
//  zenloop
//
//  Custom bottom navigation bar style Opal avec glassmorphism
//

import SwiftUI

struct OpalTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation

    let tabs: [OpalTabItem] = [
        OpalTabItem(icon: "house.fill", title: "Home", tag: 0),
        OpalTabItem(icon: "chart.xyaxis.line", title: "Screen Time", tag: 1),
        OpalTabItem(icon: "person.2.fill", title: "Social", tag: 2)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                OpalTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab.tag,
                    animation: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab.tag
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct OpalTabButton: View {
    let tab: OpalTabItem
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.gray.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OpalTabItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let tag: Int
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            OpalTabBar(selectedTab: .constant(0))
        }
    }
}
