To: app-review-support@apple.com  
From: [Votre email]  
Subject: Request for Screen Time Entitlements and Application Enumeration – Zenloop (com.app.zenloop)

Dear Apple App Review Team,

I hope this message finds you well.

I’m reaching out to request guidance and approval for essential entitlements for our digital wellness application **Zenloop** (Bundle ID: com.app.zenloop), which is currently under development.

---

🔹 **About the App**  
Zenloop is a screen time reduction and digital wellness app designed to help users regain control of their attention through voluntary app blocking sessions, focus challenges, and device activity tracking.

Our key features include:  
- Customizable focus sessions (e.g., 30 min, 60 min)  
- App blocking using Screen Time APIs  
- Progress tracking and session statistics  
- A simple and friendly interface focused on mental clarity

---

🔹 **Entitlements Requested**

**1. Essential Functionality – Required for Core Features (PRIORITY 1):**
We request the following public entitlements to support our app’s core functionality:

- `com.apple.developer.screen-time-management`  
- `com.apple.developer.device-activity-monitoring`

These enable Screen Time-based app blocking and local activity monitoring. Without them, our app cannot fulfill its fundamental purpose.

---

**2. User Experience Enhancement – Optional but Highly Valuable (PRIORITY 2):**
We also respectfully request access to the following entitlement:

- `com.apple.developer.application-enumeration`

This would allow us to display the actual names of the apps the user voluntarily selects for blocking, rather than showing a generic message like "5 apps selected." This greatly enhances clarity, trust, and usability.

---

🔹 **Privacy and Security Commitments**

We are committed to user privacy and fully aligned with Apple’s platform values:

- ✅ All app selection is done explicitly by the user via Apple’s FamilyControls framework  
- ✅ All app data stays 100% local – no collection, no storage, no analytics  
- ✅ No system apps are displayed – only user-installed apps  
- ✅ All functionality remains within our app's sandbox

We do **not** request access to sensitive private entitlements like:  
- `com.apple.private.LaunchServices.ApplicationEnumeration`  
- `com.apple.private.security.storage.ApplicationBundles`  
We understand their restricted nature and will only use entitlements explicitly approved by Apple.

---

🔹 **Request for Guidance**

We would greatly appreciate your feedback on the following:
1. What is the approval process for the above entitlements?  
2. Are there specific documentation requirements or forms to complete?  
3. Can we proceed with TestFlight or App Store submission while approval is pending?

---

🔹 **Planned Timeline**

We aim to submit Zenloop for App Store review within the next 4–6 weeks. Receiving clarity and guidance now will help us ensure full compliance with App Store policies and avoid unnecessary rejections.

---

📞 Contact Information:  
Developer: [Votre nom]  
Email: [Votre email]  
Team ID: BJN2XLBCFS  
Phone (optional): [Votre numéro]

I’m happy to provide mockups, technical documentation, or additional details upon request. Thank you in advance for your consideration. We look forward to building a compliant, respectful, and helpful wellness experience on iOS.

Warm regards,  
[Votre nom]  
Lead Developer – Zenloop
