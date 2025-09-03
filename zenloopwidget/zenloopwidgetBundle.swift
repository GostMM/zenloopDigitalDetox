//
//  zenloopwidgetBundle.swift
//  zenloopwidget
//
//  Created by MROIVILI MOUSTOIFA on 28/08/2025.
//

import WidgetKit
import SwiftUI

@main
struct zenloopwidgetBundle: WidgetBundle {
    var body: some Widget {
        zenloopwidget()
        zenloopwidgetControl()
        zenloopwidgetLiveActivity()
        InteractiveZenloopWidget() // New interactive widget
    }
}
