# Email de demande à Apple pour l'utilisation d'APIs privées

---

**To:** app-review-support@apple.com  
**Subject:** Request for LSApplicationWorkspace API Usage - Digital Wellness App Zenloop  
**From:** [Votre email]

---

Dear Apple App Review Team,

I am writing to request guidance and potential approval for the usage of private APIs in my digital wellness application **Zenloop** (Bundle ID: com.app.zenloop).

## Application Overview

**Zenloop** is a digital wellness application designed to help users reduce screen time and increase focus through app blocking challenges. The app uses Apple's Family Controls framework and Screen Time APIs to provide users with tools to limit their access to distracting applications.

### Key Features:
- Focus challenges with customizable durations
- App blocking using Screen Time APIs
- Progress tracking and statistics
- User-friendly interface for digital wellness

## API Usage Request

I am requesting permission to use **LSApplicationWorkspace** private APIs specifically for the following legitimate purposes:

### Purpose:
To display the actual names and icons of user-selected applications in our digital wellness interface, enhancing user experience and providing clear visibility of which apps are being blocked during focus sessions.

### Specific APIs and Entitlements Requested:

**Private APIs:**
- `LSApplicationWorkspace.defaultWorkspace()`
- `allApplications()` method
- `localizedName()` property
- Application icon retrieval methods

**Private Entitlements:**
- `com.apple.developer.application-enumeration` - To enumerate installed applications
- `com.apple.private.LaunchServices.ApplicationEnumeration` - To access LaunchServices for app discovery
- `com.apple.private.security.storage.ApplicationBundles` - To access bundle information for app names and icons

**REQUIRED Entitlement for Core Functionality (AWAITING APPROVAL):**
- `com.apple.developer.family-controls` - **THE ONLY ENTITLEMENT NEEDED** for complete Screen Time API access (FamilyControls, ManagedSettings, DeviceActivity frameworks)

**REQUESTED Entitlements for Enhanced UX:**
- `com.apple.developer.application-enumeration` - To enumerate installed applications
- `com.apple.private.LaunchServices.ApplicationEnumeration` - To access LaunchServices for app discovery
- `com.apple.private.security.storage.ApplicationBundles` - To access bundle information for app names and icons

### Technical Context:
Currently, the `FamilyActivitySelection` provided by Apple's Family Controls framework returns encrypted tokens (`ApplicationToken`) that cannot be converted to human-readable app names for privacy reasons. While we understand and respect this privacy approach, it creates a suboptimal user experience where users cannot see which specific apps they have selected for blocking.

### User Experience Impact:
Without access to app names, users see generic text like "5 apps selected" instead of "Instagram, TikTok, Twitter, Facebook, YouTube". This significantly impacts the usability and effectiveness of our digital wellness tool.

## Privacy and Security Considerations

We are committed to maintaining the highest privacy and security standards:

1. **Local Processing Only**: All app information will be processed locally on the device
2. **No Data Collection**: We will not collect, store, or transmit any application usage data
3. **User Consent**: Users explicitly consent to app blocking through the Family Controls framework
4. **Sandboxed Environment**: All operations remain within the app's sandbox
5. **Legitimate Use Case**: This is exclusively for digital wellness purposes to help users manage their screen time

## Similar Apps in the App Store

Several approved digital wellness applications currently use similar APIs:
- **Opal** - Screen Time for Focus
- **Freedom** - Block Websites & Apps
- **RescueTime** - Time Management
- **Moment** - Screen Time Control

These apps successfully display app names and icons, indicating that such usage can be approved for legitimate digital wellness purposes.

## Implementation Details

Our implementation includes:
- Filtering of system apps to show only user-installed applications
- Graceful fallback to generic display if APIs are unavailable
- Compliance with all Family Controls framework requirements
- Proper error handling and edge case management

## Specific Requests

### 1. **Screen Time Entitlements Approval (PRIORITY 1 - ESSENTIAL)**
We are requesting approval for the essential Screen Time entitlements without which our digital wellness app cannot function:
- `com.apple.developer.screen-time-management`
- `com.apple.developer.device-activity-monitoring`

**Justification**: These are absolutely required for any digital wellness application to block apps and monitor device activity. Without these, Zenloop cannot fulfill its core purpose.

### 2. **Application Enumeration Entitlements (PRIORITY 2 - UX Enhancement)**
We are requesting approval for enhanced user experience entitlements:
- `com.apple.developer.application-enumeration`
- `com.apple.private.LaunchServices.ApplicationEnumeration`
- `com.apple.private.security.storage.ApplicationBundles`

**Justification**: These would allow us to display actual app names instead of generic "X apps selected", significantly improving user experience.

## Request for Guidance

We would appreciate guidance on:

1. **Screen Time Approval Process**: What is the formal process for Screen Time entitlements approval?
2. **Documentation Requirements**: What documentation is needed to prove legitimate digital wellness use case?
3. **Timeline**: What is the typical approval timeline for Screen Time entitlements?
4. **App Store Review**: How should we handle App Store submission while waiting for entitlements approval?

## App Store Submission Timeline

We plan to submit **Zenloop** to the App Store within the next 4-6 weeks and would greatly appreciate clarity on this matter before submission to ensure compliance with all App Store guidelines.

## Contact Information

**Developer:** [Votre nom]  
**Email:** [Votre email]  
**Phone:** [Votre téléphone]  
**App Bundle ID:** com.app.zenloop  
**Development Team ID:** BJN2XLBCFS

## Supporting Documentation

I am happy to provide any additional documentation, including:
- Detailed technical implementation
- Privacy policy draft
- User interface mockups
- Code samples demonstrating responsible usage

Thank you for your time and consideration. I look forward to your guidance on this matter and am committed to working with Apple to ensure our digital wellness app meets all guidelines while providing the best possible user experience.

Best regards,

[Votre nom]  
[Votre titre]  
Zenloop Development Team

---

## Informations supplémentaires à personnaliser:

1. **Remplacez [Votre nom]** par votre nom complet
2. **Remplacez [Votre email]** par votre adresse email professionnelle
3. **Remplacez [Votre téléphone]** par votre numéro de téléphone (optionnel)
4. **Remplacez [Votre titre]** par votre titre (ex: Lead Developer, CTO, etc.)

## Conseils pour l'envoi:

1. **Timing**: Envoyez cet email 2-3 semaines avant de soumettre l'app
2. **Follow-up**: Si pas de réponse dans 1 semaine, faire un follow-up poli
3. **Documentation**: Préparez les documents supplémentaires mentionnés
4. **Alternative**: Préparez aussi une version de l'app sans les APIs privées en cas de refus

## Contact Apple Developer Support:

- **Email principal**: app-review-support@apple.com
- **Formulaire web**: https://developer.apple.com/contact/app-store/?topic=review
- **Phone**: Numéro disponible sur votre compte développeur Apple