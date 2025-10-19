# Design du Modal de Sélection de Difficulté

## Vue d'ensemble

Modal bottom sheet moderne et élégant pour choisir le niveau de restriction avant de démarrer une session focus.

## Spécifications du Design

### Dimensions
- **Hauteur** : 500pt
- **Coins arrondis** : 14pt
- **Padding horizontal** : 16pt
- **Espacement entre cards** : 10pt

### Couleurs
```swift
Background: LinearGradient(
    Color(0.10, 0.10, 0.12) → Color(0.08, 0.08, 0.10)
)

Cards non-sélectionnées:
    Background: white.opacity(0.06) → white.opacity(0.03)
    Border: white.opacity(0.1), 1pt

Cards sélectionnées:
    Background: difficulty.color.opacity(0.15) → 0.08
    Border: difficulty.color.opacity(0.5), 1.5pt
    Shadow: difficulty.color.opacity(0.2), radius 8
```

### Typographie
- **Titre principal** : 22pt, Bold
- **Sous-titre** : 14pt, Regular, 60% opacity
- **Nom difficulté** : 17pt, Bold
- **Badge "Suggéré"** : 10pt, Bold
- **Type de mode** : 13pt, Semibold
- **Description** : 12pt, Regular, 55% opacity

## Structure du Modal

```
┌─────────────────────────────────────────┐
│         ─── (drag indicator)            │
│                                          │
│      Niveau de Restriction               │ ← Titre
│  Choisissez l'intensité du blocage      │ ← Sous-titre
│                                          │
│  ┌─────────────────────────────────┐    │
│  │ 🟢 Facile        ✨ Suggéré  ✓ │    │ ← Card 1
│  │ 🛡️ Shield Mode                  │    │
│  │ Apps visibles mais bloquées...  │    │
│  └─────────────────────────────────┘    │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │ 🟠 Moyen                      ○ │    │ ← Card 2
│  │ 🛡️ Shield Mode Renforcé         │    │
│  │ Blocage strict avec notifs...   │    │
│  └─────────────────────────────────┘    │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │ 🔴 Difficile                  ○ │    │ ← Card 3
│  │ 👁️‍🗨️ Hide Mode                   │    │
│  │ Apps complètement masquées...    │    │
│  └─────────────────────────────────┘    │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │    ▶️  Démarrer la Session      │    │ ← Bouton CTA
│  └─────────────────────────────────┘    │
│            Annuler                       │ ← Bouton secondaire
└─────────────────────────────────────────┘
```

## Détails de chaque Card

### Structure
```swift
HStack {
    // Icône circulaire avec gradient
    Circle(48x48)
        + LinearGradient(difficulty.color)
        + SF Symbol icon (20pt)

    VStack(leading) {
        HStack {
            Text("Facile")               // Nom
            Badge("Suggéré") [optionnel] // Si auto
            Spacer()
            Checkmark / Circle           // État
        }

        HStack {
            SF Symbol(11pt)              // Icône mode
            Text("Shield Mode")          // Type
        }

        Text("Description...")           // Explication
    }
}
```

### Options de Difficulté

#### 1. Facile 🍃
- **Couleur** : Vert (#4ADE80)
- **Icône principale** : `leaf.fill`
- **Icône mode** : `shield.lefthalf.filled`
- **Type** : Shield Mode
- **Description** : "Apps restent visibles mais bloquées par un overlay"

#### 2. Moyen 🔥
- **Couleur** : Orange (#FB923C)
- **Icône principale** : `flame.fill`
- **Icône mode** : `shield.fill`
- **Type** : Shield Mode Renforcé
- **Description** : "Blocage strict avec notifications de rappel"

#### 3. Difficile ⚡
- **Couleur** : Rouge (#EF4444)
- **Icône principale** : `bolt.fill`
- **Icône mode** : `eye.slash.fill`
- **Type** : Hide Mode
- **Description** : "Apps complètement masquées de l'écran d'accueil"

## Badge "Suggéré"

Apparaît sur l'option recommandée automatiquement selon la durée :

```swift
HStack(3pt) {
    Image("sparkles") // 8pt
    Text("Suggéré")   // 10pt bold
}
.foregroundColor(.white)
.padding(.horizontal, 7)
.padding(.vertical, 3)
.background(difficulty.color.opacity(0.25))
.cornerRadius(6)
```

## Interactions

### Tap sur une Card
1. Haptic feedback (medium)
2. Animation de sélection (spring)
3. Changement de couleur/bordure
4. Apparition du checkmark

### Bouton Démarrer
1. Haptic feedback (heavy)
2. Fermeture du modal
3. Démarrage de la session avec difficulté choisie

### Bouton Annuler
1. Fermeture du modal
2. Pas de changement d'état

## États Visuels

### Card Non-sélectionnée
- Background : Blanc 6% → 3%
- Border : Blanc 10%, 1pt
- Checkmark : Cercle vide, Blanc 20%
- Ombre : Aucune

### Card Sélectionnée
- Background : Couleur 15% → 8%
- Border : Couleur 50%, 1.5pt
- Checkmark : `checkmark.circle.fill`, couleur pleine
- Ombre : Couleur 20%, radius 8, offset (0, 4)

### Card Suggérée (Auto)
- Même apparence que sélectionnée SI c'est le choix actuel
- Badge "✨ Suggéré" visible
- Animation subtile au premier affichage

## Animations

### Entrée du Modal
- Slide from bottom (native sheet)
- Duration : 0.3s, spring

### Sélection de Card
- Scale : 1.0 → 0.98 → 1.0
- Duration : 0.2s
- Haptic : medium impact

### Hover (iPad/Mac)
- Scale : 1.0 → 1.02
- Opacity : 1.0 → 0.95
- Duration : 0.15s

## Accessibilité

- **VoiceOver** : "Facile, Shield Mode, Apps restent visibles mais bloquées, suggéré, sélectionné"
- **Dynamic Type** : Toutes les tailles de police supportées
- **Contraste** : WCAG AA minimum
- **Touch targets** : 44pt minimum

## Code Source

Voir : `/Users/gostmm/SaaS/zenloop/zenloop/Views/Components/TimerCard.swift`
- Lines 903-999 : `DifficultySelectionModal`
- Lines 1001-1148 : `DifficultyOptionCard`

## Résultat Visuel

Le modal présente :
✅ Design moderne et épuré
✅ Hiérarchie visuelle claire
✅ Descriptions détaillées sans saturation
✅ Pas d'emojis (SF Symbols uniquement)
✅ Gradients subtils et élégants
✅ Suggestion intelligente mise en valeur
✅ Feedback tactile et visuel
✅ Animations fluides
