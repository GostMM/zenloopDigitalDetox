//
//  ShieldConfigurationExtension.swift
//  zenloopshieldconfig
//
//  Created by MROIVILI MOUSTOIFA on 02/08/2025.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Configuration personnalisée pour les applications
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "flame.fill"),
            title: ShieldConfiguration.Label(
                text: "DÉFI EN COURS 🔥", 
                color: UIColor.systemOrange
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Tu peux le faire ! Reste focus et atteins tes objectifs 💪", 
                color: UIColor.label
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Continuer", 
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.systemOrange,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Pause 5min", 
                color: UIColor.systemOrange
            )
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Configuration pour les catégories d'applications
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "target"),
            title: ShieldConfiguration.Label(
                text: "FOCUS MODE 🎯", 
                color: UIColor.systemBlue
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Tu es plus fort que tes distractions ! Keep going 🚀", 
                color: UIColor.label
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Strong", 
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Break 5min", 
                color: UIColor.systemBlue
            )
        )
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Configuration pour les domaines web
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "safari.fill"),
            title: ShieldConfiguration.Label(
                text: "SITE BLOQUÉ 🌐", 
                color: UIColor.systemPurple
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Choisis la productivité plutôt que la procrastination ⚡", 
                color: UIColor.label
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Back to Work", 
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.systemPurple,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Quick Break", 
                color: UIColor.systemPurple
            )
        )
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Configuration pour les domaines web dans une catégorie
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "shield.fill"),
            title: ShieldConfiguration.Label(
                text: "ZONE FOCUS 🛡️", 
                color: UIColor.systemGreen
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Bravo ! Tu respectes ton engagement. Continue comme ça ! 🌟", 
                color: UIColor.label
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Let's Go!", 
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.systemGreen,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Pause", 
                color: UIColor.systemGreen
            )
        )
    }
}
