//
//  DailyReportDebugView.swift
//  zenloop
//
//  Debug view pour tester le système de rapport quotidien
//

import SwiftUI

struct DailyReportDebugView: View {
    @StateObject private var dailyReportManager = DailyReportManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showReportModal = false
    @State private var selectedTimeOfDay: DailyReportManager.TimeOfDay = .morning
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dailyReportManager.getDebugInfo())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Test Actions") {
                    ForEach(DailyReportManager.TimeOfDay.allCases, id: \.rawValue) { timeOfDay in
                        Button("Show \(timeOfDay.rawValue.capitalized) Report") {
                            selectedTimeOfDay = timeOfDay
                            dailyReportManager.forceShowReport(timeOfDay: timeOfDay)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Manual Controls") {
                    Button("Check Should Show Report") {
                        dailyReportManager.checkShouldShowReport()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset All Reports") {
                        dailyReportManager.resetAllReports()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Mark Onboarding Complete") {
                        dailyReportManager.setOnboardingCompleted()
                    }
                    .foregroundColor(.green)
                }
                
                Section("Data Info") {
                    HStack {
                        Text("Activity Data Available:")
                        Spacer()
                        Text(onboardingManager.dailyActivityData != nil ? "✅" : "❌")
                    }
                    
                    if let data = onboardingManager.dailyActivityData {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total: \(data.formattedTotalTime)")
                            Text("Daily Avg: \(data.formattedDailyAverage)")
                            Text("Categories: \(data.topCategories.count)")
                            Text("Updated: \(Date(timeIntervalSince1970: data.updatedAt).formatted(.dateTime))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Daily Report Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $dailyReportManager.shouldShowReport) {
            DailyReportModal(
                isPresented: $dailyReportManager.shouldShowReport,
                timeOfDay: convertTimeOfDay(dailyReportManager.currentTimeOfDay)
            )
        }
        .onAppear {
            onboardingManager.loadDailyActivityData()
        }
    }
    
    // MARK: - Helper Functions
    
    private func convertTimeOfDay(_ timeOfDay: DailyReportManager.TimeOfDay) -> DailyTimeOfDay {
        switch timeOfDay {
        case .morning: return .morning
        case .afternoon: return .afternoon  
        case .evening: return .evening
        }
    }
}

#Preview {
    DailyReportDebugView()
}