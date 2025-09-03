# Quick Actions Deep Linking Configuration

## URL Scheme Configuration

Pour que les Quick Actions fonctionnent correctement quand l'app est fermée, il faut configurer le URL scheme dans le projet Xcode.

### 1. Configuration dans Xcode

Ajouter dans le fichier `Info.plist` ou dans la configuration Xcode :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.app.zenloop.quickactions</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zenloop</string>
        </array>
        <key>CFBundleURLIconFile</key>
        <string></string>
    </dict>
</array>
```

### 2. URLs Deep Link Supportées

| Quick Action | URL Deep Link | Description |
|--------------|---------------|-------------|
| 🚀 Quick Focus | `zenloop://quickfocus` | Lance session 25 min |
| ⏰ Start Scheduled | `zenloop://startscheduled` | Démarre session programmée |
| 📊 View Stats | `zenloop://stats` | Navigue vers stats |
| 🛟 Emergency Break | `zenloop://emergency` | Pause d'urgence |
| 🫢 Don't Delete | `zenloop://retention` | Modal de rétention |

### 3. Flux de Fonctionnement

#### Quand l'App est Ouverte :
1. Quick Action → `QuickActionsBridge`
2. Traitement direct → `QuickActionsManager`
3. Exécution immédiate de l'action

#### Quand l'App est Fermée :
1. Quick Action → `ZenloopAppDelegate`
2. URL Deep Link généré → `zenloop://action`
3. App démarre → `ContentView.onOpenURL`
4. URL traitée → `QuickActionsManager`
5. Action exécutée après chargement complet

### 4. Gestion des Erreurs

- ✅ Retry automatique si ZenloopManager pas prêt
- ✅ Logs détaillés pour debugging
- ✅ Fallback vers traitement normal si deep link échoue
- ✅ Timeout de 10 secondes pour éviter boucles infinies

### 5. Test

Pour tester les deep links :

```bash
# Simulateur iOS
xcrun simctl openurl booted "zenloop://quickfocus"

# Device physique via Safari
zenloop://retention
```