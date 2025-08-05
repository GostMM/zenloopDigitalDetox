//
//  DeviceActivityReportView.swift
//  zenloop
//
//  Created by Claude on 04/08/2025.
//

import SwiftUI
import DeviceActivity

// MARK: - DeviceActivityReport Context
// Note: Context défini dans TotalActivityReport.swift

// MARK: - DeviceActivityReportView

struct DeviceActivityReportView: View {
    @StateObject private var appUsageManager = AppUsageManager.shared
    @State private var context: DeviceActivityReport.Context = DeviceActivityReport.Context("Total Activity")
    
    // Filtre pour quotidien (journée actuelle) 
    @State private var dailyFilter = DeviceActivityFilter(
        segment: .daily(during: Calendar.current.dateInterval(of: .day, for: .now)!),
        users: .all,
        devices: .init([.iPhone])
    )
    
    // Filtre pour hebdomadaire (dernière semaine)
    @State private var weeklyFilter = DeviceActivityFilter(
        segment: .weekly(during: Calendar.current.dateInterval(of: .weekOfYear, for: .now)!),
        users: .all,
        devices: .init([.iPhone])
    )
    
    @State private var showDaily = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Sélecteur période
            Picker("Période", selection: $showDaily) {
                Text("Quotidien").tag(true)
                Text("Hebdomadaire").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // DeviceActivityReport pour les vraies données
            if appUsageManager.isAuthorized {
                DeviceActivityReport(context, filter: showDaily ? dailyFilter : weeklyFilter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Autorisation Screen Time requise")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Pour afficher vos données d'usage réelles")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button("Demander l'autorisation") {
                        Task {
                            await appUsageManager.requestAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Demander autorisation au chargement si pas encore accordée
            if !appUsageManager.isAuthorized {
                Task {
                    await appUsageManager.requestAuthorization()
                }
            }
        }
    }
}

#Preview {
    DeviceActivityReportView()
        .background(Color.black)
}