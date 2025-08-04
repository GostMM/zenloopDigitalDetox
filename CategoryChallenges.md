# Category Challenges - Défis par Catégories

## 🎯 Concept

Créer des défis thématiques pré-configurés basés sur des catégories d'applications spécifiques : **0 IA**, **0 Réseaux Sociaux**, **0 Games**, etc.

L'utilisateur configure une seule fois ses apps par catégorie, puis peut lancer des défis instantanés ciblés.

---

## 📱 Catégories Proposées

### 🤖 **0 IA**
- ChatGPT, Claude, Perplexity, Notion AI
- GitHub Copilot, Cursor, Replit
- Midjourney, DALL-E, Stable Diffusion
- Otter.ai, Grammarly, etc.

### 📱 **0 Réseaux Sociaux**
- Instagram, TikTok, Twitter/X, Facebook
- LinkedIn, Snapchat, Pinterest
- Reddit, Discord, Clubhouse

### 🎮 **0 Games**
- Tous les jeux mobile/desktop
- Steam, Epic Games, App Store games
- Browser games, casual games

### 🛒 **0 Shopping**
- Amazon, eBay, AliExpress
- Vinted, Leboncoin, Marketplace
- Apps de e-commerce

### 📺 **0 Entertainment**
- Netflix, YouTube, Twitch
- Spotify, Apple Music, Podcasts
- TikTok, Instagram Reels

### 💼 **0 Procrastination**
- Mix des catégories ci-dessus
- Apps identifiées comme "time-wasters"

---

## 🏗️ Architecture Technique

### **1. Modèle de Données**

```swift
struct AppCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let description: String
    var selectedApps: FamilyActivitySelection
    var isConfigured: Bool = false
}

struct CategoryChallenge: Identifiable, Codable {
    let id: String
    let category: AppCategory
    let title: String        // "0 IA Aujourd'hui"
    let duration: TimeInterval
    let difficulty: DifficultyLevel
    let badge: String        // Badge spécial à débloquer
}
```

### **2. Manager de Catégories**

```swift
class CategoryManager: ObservableObject {
    @Published var categories: [AppCategory] = []
    @Published var availableChallenges: [CategoryChallenge] = []
    
    // Configuration initiale
    func setupCategories()
    
    // Sauvegarde des sélections
    func saveCategory(_ category: AppCategory)
    
    // Génération des défis
    func generateChallengesForCategory(_ category: AppCategory) -> [CategoryChallenge]
    
    // Lancement rapide
    func startCategoryChallenge(_ challenge: CategoryChallenge)
}
```

### **3. Stockage des Tokens**

```swift
// UserDefaults avec sérialisation JSON
private let categoryKey = "zenloop_app_categories"

func saveCategories() {
    if let data = try? JSONEncoder().encode(categories) {
        UserDefaults.standard.set(data, forKey: categoryKey)
    }
}

func loadCategories() {
    if let data = UserDefaults.standard.data(forKey: categoryKey),
       let categories = try? JSONDecoder().decode([AppCategory].self, from: data) {
        self.categories = categories
    }
}
```

---

## 🎨 Interface Utilisateur

### **Phase 1 : Configuration (One-time setup)**

```
┌─────────────────────────────────────┐
│ 🎯 Configurez vos Catégories        │
├─────────────────────────────────────┤
│                                     │
│ 🤖 IA & Productivité              │
│ Tapez pour sélectionner vos apps   │
│ [Configurer] ──────────────────► │
│                                     │
│ 📱 Réseaux Sociaux                │
│ Tapez pour sélectionner vos apps   │
│ [Configurer] ──────────────────► │
│                                     │
│ 🎮 Jeux & Entertainment           │
│ [Configurer] ──────────────────► │
│                                     │
└─────────────────────────────────────┘
```

### **Phase 2 : Défis par Catégorie**

```
┌─────────────────────────────────────┐
│ ⚡ Défis Rapides par Catégorie       │
├─────────────────────────────────────┤
│                                     │
│ [🤖 0 IA - 4h] [📱 0 Social - 2h]  │
│                                     │
│ [🎮 0 Games - 6h] [🛒 0 Shop - 1h] │
│                                     │
│ [📺 0 Stream - 3h] [💼 Focus - 8h] │
│                                     │
└─────────────────────────────────────┘
```

### **Phase 3 : Interface de Configuration**

```
┌─────────────────────────────────────┐
│ 🤖 Configuration - IA & Productivité│
├─────────────────────────────────────┤
│                                     │
│ Sélectionnez vos apps IA :          │
│                                     │
│ ✅ [💬] ChatGPT                     │
│ ✅ [🧠] Claude                      │
│ ⬜ [🔍] Perplexity                  │
│ ✅ [📝] Notion                      │
│ ✅ [👨‍💻] GitHub Copilot               │
│                                     │
│         [Sauvegarder]               │
└─────────────────────────────────────┘
```

---

## 🎮 Gamification

### **Badges Spéciaux**
- 🤖 **AI Detox** - 24h sans IA
- 📱 **Social Free** - Week-end sans réseaux sociaux  
- 🎮 **Game Over** - 7 jours sans jeux
- 💼 **Pure Focus** - 8h de travail sans distractions
- 🧘 **Digital Monk** - Toutes catégories bloquées

### **Statistiques**
- Temps économisé par catégorie
- Streaks par type de défi
- Classement des catégories les plus bloquées
- Impact sur la productivité

---

## 🔧 Implémentation Progressive

### **MVP (v1)**
1. **3 catégories de base** : IA, Social, Games
2. **Configuration simple** : Sélection d'apps par catégorie
3. **Défis fixes** : 1h, 4h, 8h par catégorie
4. **Boutons rapides** : Lancement instantané

### **v2 - Enrichissement**
1. **6 catégories complètes**
2. **Défis personnalisés** : Durées variables
3. **Smart suggestions** : Apps populaires pré-cochées
4. **Statistiques détaillées**

### **v3 - Avancé**
1. **Catégories personnalisées** : Créées par l'utilisateur
2. **Défis combinés** : 0 Social + 0 Games
3. **Programmation** : Défis récurrents (ex: "0 Social" tous les weekends)
4. **Social features** : Partage de défis, challenges entre amis

---

## 💡 Avantages

### **Pour l'Utilisateur**
- ⚡ **Lancement ultra-rapide** : 1 tap = défi configuré
- 🎯 **Défis ciblés** : Focus sur une addiction spécifique
- 📊 **Conscience** : Visualisation de l'usage par catégorie
- 🏆 **Motivation** : Badges et achievements spécialisés

### **Pour l'App**
- 📈 **Engagement** : Défis plus variés et pertinents
- 🎨 **UX simplifiée** : Moins de configuration répétitive
- 📱 **Modernité** : Répond aux enjeux actuels (IA, réseaux sociaux)
- 🔄 **Rétention** : Nouvelles raisons de revenir dans l'app

---

## 🚀 Call to Action

Cette fonctionnalité positionnerait Zenloop comme **l'app de digital wellness la plus moderne** en adressant les nouvelles addictions numériques (IA, réseaux sociaux, etc.).

**Implémentation recommandée** : Commencer par MVP avec 3 catégories, puis itérer selon les retours utilisateurs.

---

*"Dans un monde hyper-connecté, les défis par catégories permettent un digital detox précis et efficace."*