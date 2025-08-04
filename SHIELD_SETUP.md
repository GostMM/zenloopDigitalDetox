# 🛡️ Configuration des Extensions Shield - Zenloop

## Overview

Les extensions Shield permettent de personnaliser l'écran qui apparaît quand l'utilisateur tape sur une application bloquée pendant un défi.

## Extensions créées

### 1. Shield Configuration Extension (`zenloopshieldconfig`)
- **But**: Personnaliser l'apparence de l'écran de blocage
- **Fichiers**: 
  - `ShieldConfigurationExtension.swift`
  - `Info.plist`

### 2. Shield Action Extension (`zenloopshieldaction`)  
- **But**: Gérer les actions des boutons (continuer, pause, etc.)
- **Fichiers**:
  - `ShieldActionExtension.swift`
  - `Info.plist`

## Ajout des Targets dans Xcode

### Étape 1: Ajouter Shield Configuration Extension

1. Dans Xcode: `File > New > Target`
2. Choisir `Shield Configuration Extension`
3. Nom du produit: `zenloopshieldconfig`
4. Bundle Identifier: `com.app.zenloop.shieldconfig`
5. Remplacer le fichier généré par notre `ShieldConfigurationExtension.swift`

### Étape 2: Ajouter Shield Action Extension

1. Dans Xcode: `File > New > Target`
2. Choisir `Shield Action Extension`  
3. Nom du produit: `zenloopshieldaction`
4. Bundle Identifier: `com.app.zenloop.shieldaction`
5. Remplacer le fichier généré par notre `ShieldActionExtension.swift`

### Étape 3: Configuration des entitlements

Ajouter dans `zenloop.entitlements`:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.developer.screen-time-management</key>
<true/>
```

## Fonctionnalités des Shields

### Messages personnalisés selon le contexte:

1. **Applications individuelles**: 
   - Titre: "Moment de Focus 🔥"
   - Message: "Tu es en plein défi ! Reste concentré(e) 💪"

2. **Catégories d'apps**:
   - Titre: "Défi en Cours 🎯" 
   - Message: "Cette catégorie d'apps est bloquée pendant ton défi"

3. **Sites web**:
   - Titre: "Site Bloqué 🌐"
   - Message: "Ce site fait partie de tes distractions bloquées"

### Actions des boutons:

- **Bouton principal**: "Je reste concentré(e)" → Ferme le shield
- **Bouton secondaire**: "Prendre une pause (5 min)" → Accorde un break temporaire

## Intégration avec l'app principale

Le `ScreenTimeManager` applique automatiquement les shields via:
```swift
store.shield.applications = selection.applicationTokens
store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
```

## Test

1. Créer un défi avec des apps sélectionnées
2. Démarrer le défi
3. Essayer d'ouvrir une app bloquée
4. Vérifier que l'écran personnalisé apparaît avec les bons messages et boutons

## Personnalisation avancée

Pour modifier les messages ou l'apparence:
- Éditer `ShieldConfigurationExtension.swift` 
- Changer les couleurs, textes, icônes selon vos besoins
- Les actions des boutons se configurent dans `ShieldActionExtension.swift`

## Communication avec l'app principale

Les extensions peuvent communiquer avec l'app via:
- `UserDefaults` avec un group container
- Keychain partagé
- Notifications locales

Exemple dans `ShieldActionExtension.swift`:
```swift
let userDefaults = UserDefaults(suiteName: "group.com.app.zenloop")
userDefaults?.set(actionData, forKey: "lastShieldAction")
```