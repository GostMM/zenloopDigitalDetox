# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Zenloop**, an iOS digital wellness application built with SwiftUI that helps users block apps, create focus challenges, and reduce distractions using Apple's Screen Time APIs. The app is designed to be a comprehensive digital wellness solution with multiple extensions and targets.

## Build Commands

### Build and Run
```bash
# Build main app (Debug)
xcodebuild -project zenloop.xcodeproj -scheme zenloop -configuration Debug

# Build for device (Release)
xcodebuild -project zenloop.xcodeproj -scheme zenloop -configuration Release -sdk iphoneos

# Build specific extension targets
xcodebuild -project zenloop.xcodeproj -scheme zenloopmonitor -configuration Debug
xcodebuild -project zenloop.xcodeproj -scheme zenloopactivity -configuration Debug

# Clean build folder
xcodebuild clean -project zenloop.xcodeproj -scheme zenloop
```

### Testing
```bash
# Run tests for main app
xcodebuild test -project zenloop.xcodeproj -scheme zenloop -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Test specific extension (if tests exist)
xcodebuild test -project zenloop.xcodeproj -scheme zenloopmonitor -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Available Schemes
The project has three schemes corresponding to its targets:
- `zenloop` (main app)
- `zenloopmonitor` (Device Activity Monitor Extension)
- `zenloopactivity` (Device Activity Report Extension)

## Project Architecture

### Target Structure
The project uses a multi-target architecture with the following implemented targets:

- **Main App Target (`zenloop`)**: Core SwiftUI application
  - Entry point: `zenloopApp.swift` - Standard SwiftUI app structure
  - Comprehensive digital wellness interface with focus sessions, challenges, and insights
  - Full notification system and daily reporting capabilities

- **Device Activity Monitor Extension (`zenloopmonitor`)**: 
  - Complete DeviceActivityMonitor implementation (`zenloopmonitor.swift`)
  - Background monitoring of focus sessions and app blocking
  - Real-time notification system for session events and threshold alerts
  - Statistics tracking and App Group communication

- **Device Activity Report Extension (`zenloopactivity`)**:
  - Proper DeviceActivity implementation in `TotalActivityReport.swift`
  - Custom SwiftUI view in `TotalActivityView.swift`
  - Calculates and formats total activity duration from device data

### Key Directories (Planned)
```
zenloop/
├── Views/
│   ├── Onboarding/
│   ├── Dashboard/
│   ├── Challenges/
│   └── Profile/
├── Models/
├── ViewModels/
├── Managers/
│   ├── ScreenTimeManager.swift
│   └── FirebaseManager.swift
└── Extensions/
```

### Core Technologies
- **SwiftUI**: Primary UI framework
- **Screen Time API**: App blocking and monitoring capabilities
- **Device Activity Framework**: Background activity monitoring
- **Firebase**: Backend services (Authentication, Firestore)
- **App Intents**: Siri and system integration

## Key Configuration Details

### Bundle Identifier
- Main app: `com.app.zenloop`
- Development Team: `BJN2XLBCFS`

### Platform Support
- iOS 18.2+
- macOS 15.2+
- visionOS 2.2+
- Supports iPhone, iPad, and Vision Pro

### Required Entitlements
The app requires specific entitlements for Screen Time functionality:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.developer.screen-time-management</key>
<true/>
<key>com.apple.developer.device-activity-monitoring</key>
<true/>
```

### Current Implementation Status
The project is in active development with:
- ✅ Complete SwiftUI app with comprehensive digital wellness features
- ✅ Three essential target extensions created and configured
- ✅ Device Activity Report extension fully implemented with modern UI
- ✅ Device Activity Monitor extension with complete session monitoring
- ✅ Full notification system for sessions, daily tips, and motivational reminders
- ✅ Daily usage reports shown 3x per day (morning, afternoon, evening)
- ✅ Screen Time API integration with proper entitlements
- 📋 Enhanced architecture documented

## Development Workflow

### Screen Time API Access
This app requires special approval from Apple to use Screen Time APIs. The approval process is outlined in the setup documentation.

### Firebase Integration
The project is designed to integrate with Firebase for:
- User authentication (email + Apple)
- Firestore database for user data
- Backend services for challenge tracking

### Testing Environment
- Requires iOS Simulator (iPhone 15 Pro recommended)
- Screen Time must be enabled in simulator settings
- Device Activity permissions must be granted for testing

## Development Notes

### Key Implementation Details
- **Device Activity Framework**: The `zenloopactivity` extension properly implements `DeviceActivityReportScene` with data processing
- **Monitor Extension**: `zenloopmonitor` provides complete session tracking, threshold monitoring, and real-time notifications
- **Extension Architecture**: Each extension serves a specific purpose in the digital wellness ecosystem
- **SwiftUI Integration**: Modern UI throughout with consistent design system and animations
- **Notification System**: Comprehensive notification management for sessions, tips, and daily reports

### Next Steps for Development
1. Test complete notification system end-to-end
2. Implement Firebase integration for user data synchronization
3. Add premium features and in-app purchase system
4. Optimize performance for larger datasets
5. Add advanced analytics and insights

### Special Requirements
- Requires Apple approval for Screen Time API access
- Must test on iOS Simulator with Screen Time enabled
- Device Activity permissions must be granted for proper testing
- Firebase setup required for backend integration (authentication, data storage)