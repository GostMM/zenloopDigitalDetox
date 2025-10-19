# Modes de Difficulté et Types de Restrictions

## Vue d'ensemble

L'application Zenloop propose maintenant **deux modes de restrictions** basés sur le niveau de difficulté choisi :

### 1. Mode Shield (Facile & Moyen) 🛡️
- **Comportement** : Les apps sont bloquées avec un overlay (shield)
- **Visibilité** : Les apps restent visibles sur l'écran d'accueil
- **Interaction** : Un écran de blocage s'affiche quand on essaie de lancer l'app
- **Difficulté** : Facile à contourner si vraiment nécessaire
- **Utilisation** : Sessions focus modérées, réduction progressive

### 2. Mode Hide (Difficile) 🚫
- **Comportement** : Les apps sont complètement masquées
- **Visibilité** : Les apps disparaissent de l'écran d'accueil
- **Interaction** : Impossible de lancer l'app (invisible)
- **Difficulté** : Maximum - l'app est totalement inaccessible
- **Utilisation** : Sessions focus intensives, déconnexion totale

## Architecture Technique

### Enums

```swift
// ZenloopManager.swift
enum DifficultyLevel: String, CaseIterable {
    case easy = "Facile"
    case medium = "Moyen"
    case hard = "Difficile"

    var restrictionMode: RestrictionMode {
        switch self {
        case .easy, .medium:
            return .shield  // Blocage avec overlay
        case .hard:
            return .hide    // Masquage complet
        }
    }
}

enum RestrictionMode: String, Codable {
    case shield  // ManagedSettings: shield.applications
    case hide    // ManagedSettings: application.blockedApplications
}
```

### Fichiers Modifiés

1. **ZenloopManager.swift**
   - Ajout de `RestrictionMode` enum
   - Mapping `DifficultyLevel` → `RestrictionMode`
   - Mise à jour `SelectionPayload` avec `restrictionMode`
   - Fonction `saveSelectionForExtension` prend maintenant le mode

2. **AppRestrictionCoordinator.swift**
   - `applyRestrictions(mode:)` gère les deux modes
   - Mode Shield : `store.shield.applications`
   - Mode Hide : `store.application.blockedApplications`
   - `removeRestrictions(mode:)` nettoie les deux modes

3. **zenloopmonitor.swift** (Extension)
   - Ajout de `RestrictionMode` enum (dupliqué pour l'extension)
   - `SelectionPayload` inclut `restrictionMode`
   - `applyShield()` applique le bon mode selon le payload
   - `removeShield()` nettoie les deux modes

## Limitations Connues

### Catégories d'Apps
⚠️ **Important** : Le mode Hide ne supporte QUE les apps individuelles.

Pour les **catégories** (ex: Social, Games), même en mode "Difficile", on utilise `shield.applicationCategories` car :
- `application.blockedApplicationCategories` n'existe pas dans l'API Apple
- Les catégories seront donc bloquées avec shield même en mode Hard

### Compatibilité
- Mode Shield : iOS 15+
- Mode Hide : iOS 16+
- L'app détecte automatiquement et utilise shield en fallback

## Utilisation

### Pour l'Utilisateur

#### 1. Sessions Timer (TimerCard)

Quand vous créez une session avec le Timer :

1. Sélectionnez la durée et les apps à bloquer
2. Appuyez sur "Démarrer la Session"
3. **Une modal s'ouvre** avec 3 options :
   - **Facile** 🍃 (vert) : Shield mode - Apps bloquées avec overlay
   - **Moyen** 🔥 (orange) : Shield mode - Apps bloquées avec overlay
   - **Difficile** ⚡ (rouge) : Hide mode - Apps complètement masquées
4. La difficulté **suggérée automatiquement** est marquée "Auto" :
   - ≤ 20 min → Facile
   - ≤ 60 min → Moyen
   - > 60 min → Difficile
5. Vous pouvez choisir manuellement ou utiliser la suggestion
6. Appuyez sur "Démarrer la Session" pour confirmer

#### 2. Sessions Prédéfinies (ModernChallengesView)

Les challenges prédéfinis ont déjà une difficulté intégrée :
- "Morning Focus" (30 min) → Facile (Shield)
- "Deep Work" (90 min) → Difficile (Hide)
- "Study Break" (45 min) → Moyen (Shield)

#### 3. Comportement des Modes

**Mode Shield (Facile/Moyen)** :
- Les apps restent visibles sur l'écran d'accueil
- Un overlay de blocage apparaît si vous essayez de les ouvrir
- Plus flexible, permet quelques exceptions

**Mode Hide (Difficile)** :
- Les apps disparaissent complètement de l'écran
- Impossible de les trouver ou lancer
- Maximum de concentration, zéro distraction
- Elles réapparaissent automatiquement à la fin

### Pour les Développeurs

```swift
// Démarrer une session avec mode spécifique
let challenge = ZenloopChallenge(
    difficulty: .hard  // Utilisera automatiquement Hide mode
)

// Ou explicitement
appRestrictionCoordinator.applyRestrictions(mode: .hide)

// Programmer une session
try BlockScheduler.shared.scheduleSession(
    title: "Focus intense",
    duration: 3600,
    startTime: Date(),
    selection: mySelection,
    difficulty: .hard  // → Hide mode
)
```

## Tests

### Test Manuel

1. **Mode Shield (Facile/Moyen)**
   ```
   1. Créer session avec difficulté "Facile" ou "Moyen"
   2. Sélectionner Instagram, TikTok
   3. Démarrer la session
   4. Vérifier : Apps visibles mais bloquées avec overlay
   ```

2. **Mode Hide (Difficile)**
   ```
   1. Créer session avec difficulté "Difficile"
   2. Sélectionner Instagram, TikTok
   3. Démarrer la session
   4. Vérifier : Apps INVISIBLES sur l'écran d'accueil
   5. Attendre fin de session
   6. Vérifier : Apps réapparaissent automatiquement
   ```

### Logs de Debug

Les logs indiquent clairement le mode utilisé :

```
🛡️ [AppRestriction] Applying restrictions with mode: shield
🚫 [AppRestriction] Applying restrictions with mode: hide
🔓 [AppRestriction] Clearing application.blockedApplications...
✅ [AppRestriction] Apps should now be accessible/visible
```

## FAQ

**Q: Pourquoi les catégories ne sont pas masquées en mode Hide ?**
A: L'API Apple `ApplicationSettings.blockedApplications` ne supporte que les apps individuelles. Les catégories utilisent toujours `shield.applicationCategories`.

**Q: Les apps réapparaissent-elles automatiquement ?**
A: Oui, quand la session se termine (intervalDidEnd), l'extension nettoie `application.blockedApplications` et les apps redeviennent visibles.

**Q: Que se passe-t-il si l'app crash pendant une session Hide ?**
A: Au prochain lancement, l'app détecte l'état et retire les restrictions. Les apps réapparaissent.

**Q: Peut-on forcer le mode Shield même en Difficile ?**
A: Oui, appeler `applyRestrictions(mode: .shield)` explicitement.

## Évolutions Futures

- [ ] Ajouter un niveau "Extrême" avec restrictions système additionnelles
- [ ] Permettre mix Shield/Hide dans une même session
- [ ] Statistiques : comparer efficacité Shield vs Hide
- [ ] Mode "Progressive" : commence Shield, devient Hide après 3 tentatives

## Références

- [Apple ManagedSettings Documentation](https://developer.apple.com/documentation/managedsettings)
- [FamilyControls Framework](https://developer.apple.com/documentation/familycontrols)
- [Screen Time API Guide](https://developer.apple.com/documentation/screentime)
