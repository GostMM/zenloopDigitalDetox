//
//  zenloopactivity.swift
//  zenloopactivity
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//  Restructured for StatsView.swift compatibility
//

import DeviceActivity
import SwiftUI

@main
struct zenloopactivity: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Main report for global activity (used by invisible DeviceActivityReport in StatsView)
        TotalActivityReport { activityReport in
            TotalActivityView(activityReport: activityReport)
        }

        // Stats report for HomeView usage chart (NEW)
        StatsActivityReport { reportData in
            StatsActivityView(reportData: reportData)
        }

        // Header metrics widget (used in StatsView modernHeader)
        MetricsWidget { metricsData in
            MetricsView(metricsData: metricsData)
        }
        
        // Apps section widgets (used in StatsView appsSection)
        TopAppsWidget { topAppsData in
            TopAppsView(topAppsData: topAppsData)
        }
        
        AppSummaryWidget { appSummaryData in
            AppSummaryView(appSummaryData: appSummaryData)
        }
        
        // Categories section widgets (used in StatsView categoriesSection)
        CategoryDistributionWidget { categoryDistributionData in
            CategoryDistributionView(categoryDistributionData: categoryDistributionData)
        }
        
        TopCategoriesCompactWidget { topCategoriesCompactData in
            TopCategoriesCompactView(topCategoriesCompactData: topCategoriesCompactData)
        }
        
        // Patterns section widgets (used in StatsView patternsSection)
        DailyUsageWidget { dailyUsageData in
            DailyUsageView(dailyUsageData: dailyUsageData)
        }
        
        TimeComparisonWidget { timeComparisonData in
            TimeComparisonView(timeComparisonData: timeComparisonData)
        }

        // Toast pour l'app la plus utilisée (avec vraie icône)
        TopAppToastReport { topAppData in
            TopAppToastReportView(data: topAppData)
        }

        // Full Stats Page - Opal-style full-screen stats (NEW)
        FullStatsPageReport { activityReport in
            FullStatsPageView(reportData: activityReport)
        }

        // Quick Block Category Reports - liste des apps par catégorie
        QuickBlockSocialReport { reportData in
            CategoryAppsListView(reportData: reportData)
        }

        QuickBlockProductivityReport { reportData in
            CategoryAppsListView(reportData: reportData)
        }

        QuickBlockGamingReport { reportData in
            CategoryAppsListView(reportData: reportData)
        }

        QuickBlockAdultReport { reportData in
            CategoryAppsListView(reportData: reportData)
        }
    }
}
