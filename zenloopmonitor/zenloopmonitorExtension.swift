//
//  zenloopmonitorExtension.swift
//  zenloopmonitor
//
//  Created by MROIVILI MOUSTOIFA on 01/08/2025.
//

import Foundation

// Point d'entrée pour l'extension DeviceActivity Monitor
// Le vrai monitoring est géré dans zenloopmonitor.swift

@main
struct ZenloopMonitorExtension {
    static func main() {
        // Les extensions DeviceActivity n'ont pas besoin de point d'entrée manuel
        // Le système iOS gère automatiquement l'activation de ZenloopDeviceActivityMonitor
        print("🚀 [DeviceActivity Extension] Extension initialisée")
    }
}
