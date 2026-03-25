# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zenloop is an iOS digital wellbeing app that helps users reduce screen time and distractions through app blocking, focus sessions (called "challenges"), and screen time tracking. Built with SwiftUI and leverages Apple's Screen Time APIs (FamilyControls, DeviceActivity, ManagedSettings).

**Bundle ID:** `com.app.zenloop`
**Team ID:** BJN2XLBCFS

## Build & Development Commands

### Building
```bash
xcodebuild -project zenloop.xcodeproj -scheme zenloop -configuration Debug
```

### Running Tests (if available)
```bash
xcodebuild test -project zenloop.xcodeproj -scheme zenloop -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Localization Check
```bash
# View localization status for all supported languages (de, es, it, ar, ja, zh, en, fr)
for lang in de es it ar ja zh en fr; do
  file="zenloop/$lang.lproj/Localizable.strings"
  if [ -f "$file" ]; then
    echo "=== $lang ==="
    wc -l "$file"
  fi
done
```

## Architecture

### Core Structure

The app uses a **centralized manager pattern** with distinct separation between the main app and various iOS extensions:

```
Main App (zenloop/)
├── ZenloopManager.swift          # Primary state manager (1700+ lines, core logic)
├── Managers/                     # 30+ specialized managers
├── Views/                        # SwiftUI views organized by feature
├── Models/                       # Data models and business logic
└── ContentView.swift             # Main entry point

Extensions (separate targets):
├── zenloopmonitor/               # DeviceActivity Monitor Extension
├── zenloopactivity/              # DeviceActivity Report Extension
├── zenloopshieldaction/          # Shield Action Extension
├── zenloopshieldconfig/          # Shield Configuration Extension
└── zenloopwidgetExtension/       # Widget & Live Activities
```

### Key Architectural Patterns

#### 1. App Blocking System (Critical Architecture)

The app blocking system uses a **unified default ManagedSettingsStore** for persistence. This is critical to understand:

- **GlobalShieldManager**: Single source of truth for all blocks, uses DEFAULT ManagedSettingsStore (not named stores)
- **BlockManager**: Persists block metadata to App Group (`group.com.app.zenloop`) using dual storage (UserDefaults + FileManager)
- **BlockController**: Coordinates block operations from main app
- **ActiveBlock**: Model with computed properties for remaining time, progress, expiration

**Why default store?** Named stores don't persist across app launches. The DEFAULT store (created without a name) persists automatically.

#### 2. DeviceActivity Integration

The app uses DeviceActivity API for scheduled monitoring:

- **zenloopmonitor.swift**: `ZenloopDeviceActivityMonitor` class handles `intervalDidStart` and `intervalDidEnd` callbacks
- **Minimum duration**: 16 minutes (Apple requirement for DeviceActivity)
- **Fallback**: For durations < 16min, uses local Timer (doesn't work when app is terminated)

#### 3. App Group Communication

Everything shares data via **App Group**: `group.com.app.zenloop`

Key shared data:
- `active_blocks_v2`: JSON array of ActiveBlock objects
- `blockId_for_activity_{activityName}`: Maps DeviceActivity names to block IDs
- `deviceActivityReport`: Serialized usage statistics
- `pending_*` keys: Cross-extension communication

Extensions communicate with main app via:
- Darwin notifications (`CFNotificationCenter`)
- URL schemes (`zenloop://save-block`, `zenloop://unblock`, etc.)
- App Group UserDefaults

#### 4. State Management

**ZenloopState** enum defines app states:
- `idle`: No active session
- `active`: Focus session running
- `paused`: Session paused
- `completed`: Session finished

**ZenloopManager** is a singleton `@MainActor` ObservableObject that coordinates:
- Session lifecycle (start/pause/resume/stop)
- App blocking via GlobalShieldManager
- DeviceActivity scheduling
- Statistics tracking
- Widget/Live Activity updates

### Key Managers (zenloop/Managers/)

Critical managers to understand:

- **GlobalShieldManager**: Manages ManagedSettingsStore blocks (THE key to persistence)
- **ChallengeStateManager**: Handles challenge/session state transitions
- **DeviceActivityCoordinator**: Schedules/manages DeviceActivity monitoring
- **SessionCoordinator**: Coordinates focus sessions end-to-end
- **BlockSyncManager**: Restores blocks on app launch
- **FirebaseManager**: Backend sync (Firestore for user data, challenges, community features)
- **PurchaseManager**: In-app purchases and premium features
- **ScreenTimeManager**: Requests FamilyControls authorization
- **CategoryManager**: Pre-defined app categories for quick blocking
- **OnboardingManager**: Multi-step onboarding flow

### Data Flow for App Blocking

1. **User taps "Block App" in DeviceActivityReport extension**
2. Extension cannot write to ManagedSettings (permission issue)
3. Extension saves block request to App Group (`pending_block_*` keys)
4. Extension opens URL scheme: `zenloop://save-block?appName=...&duration=...&tokenData=...`
5. Main app receives URL in `handleURL()` → calls `handleSaveBlockRequest()`
6. Main app saves to BlockManager (App Group persistence)
7. Main app applies shield via GlobalShieldManager (DEFAULT store)
8. Main app schedules DeviceActivity for auto-unblock
9. When DeviceActivity interval ends, Monitor extension calls `intervalDidEnd()`
10. Monitor reads `blockId_for_activity_{activityName}` mapping
11. Monitor calls main app via URL scheme to remove block
12. Main app removes from GlobalShieldManager and BlockManager

### Screen Time Permissions

Required entitlements (in `.entitlements` files):
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.developer.screen-time-management</key>
<true/>
<key>com.apple.developer.device-activity-monitoring</key>
<true/>
```

User must grant authorization via Settings > Screen Time > Always Allow

## Important Patterns & Conventions

### Localization
- All user-facing strings use `String(localized: "key")` or `NSLocalizedString()`
- Localizable.strings files in `{lang}.lproj/` directories
- Supported languages: English, French, German, Spanish, Italian, Arabic, Japanese, Chinese

### Logging
Uses Apple's unified logging (`os.log`):
```swift
private let logger = Logger(subsystem: "com.app.zenloop", category: "FeatureName")
logger.critical("🔥 Important message")
logger.info("ℹ️ Info message")
logger.error("❌ Error message")
```

Emoji prefixes are consistently used for visual scanning in logs.

### Threading
- Most managers are `@MainActor` classes
- UI updates always on main thread
- Background work uses `Task { }` with explicit priorities

### Optimization Notes in Code
The codebase contains many optimization comments marked with:
- `// OPTIMIZATION:` - Performance improvements
- `// ✅ CRUCIAL:` - Critical architecture decisions
- `// ⚠️ WARNING:` - Important gotchas
- `// REMOVED:` - Removed debug/test code

## Firebase Integration

- **Authentication**: Email + Apple Sign In
- **Firestore**: User profiles, challenges, community features, analytics
- **Config**: `GoogleService-Info.plist` in main target
- **Initialization**: Async in `zenloopApp.swift` to avoid blocking first frame

Collections:
- `users/`: User profiles and stats
- `challenges/`: Community challenges
- `templates/`: Challenge templates

## Widget & Live Activities

**zenloopwidgetExtension** target provides:
- Home Screen widgets showing session state
- Lock Screen widgets
- Live Activities for active sessions
- Control Center widgets (iOS 18+)
- App Intents for Siri shortcuts

Updates via `WidgetKit.WidgetCenter.shared.reloadAllTimelines()`

## Testing on Simulator

1. Enable Screen Time in Settings > Screen Time
2. Grant permissions in Settings > Screen Time > Always Allow
3. DeviceActivity requires minimum 16-minute intervals
4. App Group sharing works on simulator but file persistence can be flaky
5. Named ManagedSettingsStore objects don't persist (use default store)

## Common Gotchas

1. **ManagedSettings persistence**: ONLY the default store persists. Named stores reset on app restart.
2. **DeviceActivity minimum duration**: 16 minutes. Shorter durations need Timer fallback.
3. **Extension permissions**: DeviceActivityReport extension cannot write to ManagedSettingsStore directly.
4. **App Group sync**: UserDefaults.synchronize() is critical after writes.
5. **Token encoding**: ApplicationToken must be wrapped in FamilyActivitySelection for Codable support.
6. **Onboarding optimization**: Skip expensive operations (block restoration, DeviceActivity checks) before onboarding completion.

## Code Comments Philosophy

The codebase uses extensive inline documentation with:
- French comments (original developer language)
- English technical terms
- Emoji prefixes for quick scanning (🔥 ✅ ⚠️ ❌ 🔍 etc.)
- DEBUG/OPTIMIZATION/CRITIQUE/NOUVEAU tags

When modifying code, maintain this style for consistency.

## Extension Architecture Details

### Monitor Extension (zenloopmonitor)
- Handles `intervalDidStart` and `intervalDidEnd` events
- Applies shields at interval start
- Removes shields at interval end
- Cannot directly communicate with main app (uses App Group + Darwin notifications)

### Report Extension (zenloopactivity)
- Displays custom UI for screen time reports
- Shows top apps, categories, usage graphs
- Provides "Block App" buttons (delegates to main app via URL scheme)
- Multiple report scenes: ScreenTimeReport, CategoryReport, AppListReport, TopAppToastReport

### Shield Extensions (zenloopshieldaction/zenloopshieldconfig)
- Customize shield appearance when blocked apps are accessed
- Shield Action: What happens when user tries to open blocked app
- Shield Config: Visual customization of shield overlay

## Main App Entry Point

`zenloopApp.swift` (1200+ lines):
- Sets up GlobalShieldManager on init
- Configures Firebase asynchronously
- Registers Darwin notification observers
- Handles URL schemes for extension communication
- Implements splash screen
- Manages app lifecycle (background/foreground)
- Processes pending blocks on app activation
- Handles Quick Actions and widget actions

## Performance Considerations

- Splash screen covers slow initialization
- Firebase configured async to avoid blocking first frame
- Block restoration skipped until onboarding complete
- App Group cleanup runs weekly (not every launch)
- Stats data preloaded in background
- GCD ticker in ZenloopManager uses single queue (not multiple timers)

## Dependencies

- Firebase SDK (Auth, Firestore, Analytics)
- No third-party dependency managers (CocoaPods/SPM) visible in root
- Uses native Apple frameworks exclusively for core features

## Premium Features

Managed by `PremiumGatekeeper` and `PurchaseManager`:
- Unlimited challenges
- Advanced statistics
- Custom challenge templates
- Community features
- Ad-free experience
