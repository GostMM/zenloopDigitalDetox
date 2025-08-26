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
        
        // Specialized full reports
        AppListReport { appListData in
            AppListView(appListData: appListData)
        }
        
        ScreenTimeReport { screenTimeData in
            ScreenTimeView(screenTimeData: screenTimeData)
        }
        
        CategoryReport { categoryData in
            CategoryView(categoryData: categoryData)
        }
        
        // Modular App Widgets
        TopAppsWidget { topAppsData in
            TopAppsView(topAppsData: topAppsData)
        }
        
        AppSummaryWidget { appSummaryData in
            AppSummaryView(appSummaryData: appSummaryData)
        }
        
        // Modular Time Widgets  
        DailyUsageWidget { dailyUsageData in
            DailyUsageView(dailyUsageData: dailyUsageData)
        }
        
        TimeComparisonWidget { timeComparisonData in
            TimeComparisonView(timeComparisonData: timeComparisonData)
        }
        
        // Modular Category Widgets
        CategoryDistributionWidget { categoryDistributionData in
            CategoryDistributionView(categoryDistributionData: categoryDistributionData)
        }
        
        TopCategoriesCompactWidget { topCategoriesCompactData in
            TopCategoriesCompactView(topCategoriesCompactData: topCategoriesCompactData)
        }
        
        // Metrics Widget (pour les 3 métriques principales)
        MetricsWidget { metricsData in
            MetricsView(metricsData: metricsData)
        }
    }
}
