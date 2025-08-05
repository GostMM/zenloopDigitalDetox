//
//  zenloopactivity.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import DeviceActivity
import SwiftUI

@main
struct zenloopactivity: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { activityReport in
            TotalActivityView(activityReport: activityReport)
        }
        // Add more reports here...
    }
}
