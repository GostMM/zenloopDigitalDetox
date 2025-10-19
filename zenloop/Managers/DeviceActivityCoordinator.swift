//  DeviceActivityCoordinator.swift
//  zenloop
//
//  Created by MROIVILI MOUSTOIFA on 23/08/2025.
//  Extracted from ZenloopManager.swift for better maintainability

import Foundation
import FamilyControls
import DeviceActivity
import os

// MARK: - Device Activity Management

protocol DeviceActivityCoordinatorDelegate: AnyObject {
    func deviceActivityEventReceived(type: String, activity: String, timestamp: TimeInterval)
    func challengeShouldComplete()
    func appThresholdReached()
}

@MainActor
final class DeviceActivityCoordinator: ObservableObject {
    
    // MARK: - Private Properties
    private let activityCenter = DeviceActivityCenter()
    private var lastEventsCheck: TimeInterval = 0
    
    weak var delegate: DeviceActivityCoordinatorDelegate?
    
    #if DEBUG
    private let logger = Logger(subsystem: "com.app.zenloop", category: "DeviceActivity")
    #endif
    
    // MARK: - Public Interface
    
    var isAuthorized: Bool = false
    
    // MARK: - Challenge Monitoring
    
    func startMonitoring(for challenge: ZenloopChallenge) {
        guard isAuthorized else {
            #if DEBUG
            logger.warning("⚠️ [DeviceActivity] Cannot start monitoring - not authorized")
            #endif
            return
        }
        
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        let startDate = challenge.startTime ?? Date()
        let endDate = startDate.addingTimeInterval(challenge.duration)
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: Calendar.current.component(.hour, from: startDate),
                minute: Calendar.current.component(.minute, from: startDate)
            ),
            intervalEnd: DateComponents(
                hour: Calendar.current.component(.hour, from: endDate),
                minute: Calendar.current.component(.minute, from: endDate)
            ),
            repeats: false
        )
        
        do {
            try activityCenter.startMonitoring(activityName, during: schedule)
            #if DEBUG
            logger.debug("🎯 [DeviceActivity] Started monitoring for challenge: \(challenge.id)")
            #endif
        } catch {
            #if DEBUG
            logger.error("❌ [DeviceActivity] Failed to start monitoring: \(error.localizedDescription)")
            #endif
        }
    }
    
    func stopMonitoring(for challenge: ZenloopChallenge) {
        let activityName = DeviceActivityName("zenloop-challenge-\(challenge.id)")
        activityCenter.stopMonitoring([activityName])
        
        #if DEBUG
        logger.debug("⏹️ [DeviceActivity] Stopped monitoring for challenge: \(challenge.id)")
        #endif
    }
    
    // MARK: - Event Processing
    
    func checkDeviceActivityEvents() {
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard

        #if DEBUG
        logger.debug("🔍 [DeviceActivity] Checking for pending events...")
        #endif

        if let events = defaults.array(forKey: "device_activity_events") as? [[String: Any]] {
            #if DEBUG
            logger.debug("📬 [DeviceActivity] Found \(events.count) pending event(s)")
            #endif

            for event in events {
                if let eventType = event["event"] as? String,
                   let activity = event["activity"] as? String,
                   let timestamp = event["timestamp"] as? TimeInterval {
                    #if DEBUG
                    logger.debug("📨 [DeviceActivity] Processing event: \(eventType) for \(activity)")
                    #endif
                    processDeviceActivityEvent(type: eventType, activity: activity, timestamp: timestamp)
                }
            }

            // Nettoyer les événements traités
            defaults.removeObject(forKey: "device_activity_events")
            defaults.synchronize()

            #if DEBUG
            logger.debug("✅ [DeviceActivity] All events processed and cleared")
            #endif
        } else {
            #if DEBUG
            logger.debug("📭 [DeviceActivity] No pending events found")
            #endif
        }
    }
    
    private func processDeviceActivityEvent(type: String, activity: String, timestamp: TimeInterval) {
        #if DEBUG
        logger.debug("📱 [DeviceActivity] Processing event: \(type) for activity: \(activity)")
        #endif
        
        switch type {
        case "intervalDidEnd":
            delegate?.challengeShouldComplete()
            #if DEBUG
            logger.debug("⏰ [DeviceActivity] Challenge interval ended")
            #endif
            
        case "thresholdReached":
            delegate?.appThresholdReached()
            #if DEBUG
            logger.debug("⚠️ [DeviceActivity] App usage threshold reached")
            #endif
            
        case "warningStart":
            #if DEBUG
            logger.debug("🔔 [DeviceActivity] Warning started")
            #endif
            
        case "warningEnd":
            #if DEBUG
            logger.debug("🔕 [DeviceActivity] Warning ended")
            #endif
            
        default:
            #if DEBUG
            logger.debug("❓ [DeviceActivity] Unknown event type: \(type)")
            #endif
        }
        
        delegate?.deviceActivityEventReceived(type: type, activity: activity, timestamp: timestamp)
    }
    
    // MARK: - Throttled Event Checking
    
    func checkEventsThrottled() {
        let now = Date().timeIntervalSince1970
        if now - lastEventsCheck >= 8 { // Throttle to every 8 seconds
            lastEventsCheck = now
            checkDeviceActivityEvents()
        }
    }
    
    // MARK: - Authorization
    
    func updateAuthorizationStatus(_ isAuthorized: Bool) {
        self.isAuthorized = isAuthorized
    }
    
    // MARK: - App Group Communication
    
    func writeEventToAppGroup(eventType: String, challengeId: String, timestamp: Date = Date()) {
        let defaults = UserDefaults(suiteName: "group.com.app.zenloop") ?? UserDefaults.standard
        let eventData: [String: Any] = [
            "event": eventType,
            "activity": "zenloop-challenge-\(challengeId)",
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        var existingEvents = defaults.array(forKey: "device_activity_events") as? [[String: Any]] ?? []
        existingEvents.append(eventData)
        defaults.set(existingEvents, forKey: "device_activity_events")
        
        #if DEBUG
        logger.debug("📝 [DeviceActivity] Event written to App Group: \(eventType)")
        #endif
    }
    
    // MARK: - Schedule Management
    
    func createSchedule(for challenge: ZenloopChallenge) -> DeviceActivitySchedule? {
        guard let startTime = challenge.startTime else { return nil }
        
        let endTime = startTime.addingTimeInterval(challenge.duration)
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: Calendar.current.component(.hour, from: startTime),
                minute: Calendar.current.component(.minute, from: startTime)
            ),
            intervalEnd: DateComponents(
                hour: Calendar.current.component(.hour, from: endTime),
                minute: Calendar.current.component(.minute, from: endTime)
            ),
            repeats: false
        )
        
        return schedule
    }
    
    // MARK: - Activity Names Management
    
    func createActivityName(for challengeId: String) -> DeviceActivityName {
        return DeviceActivityName("zenloop-challenge-\(challengeId)")
    }
    
    func extractChallengeId(from activityName: DeviceActivityName) -> String? {
        let nameString = activityName.rawValue
        if nameString.hasPrefix("zenloop-challenge-") {
            return String(nameString.dropFirst("zenloop-challenge-".count))
        }
        return nil
    }
    
    // MARK: - Monitoring Status
    
    func getActiveMonitoringSessions() -> [DeviceActivityName] {
        // Note: DeviceActivityCenter doesn't provide direct access to active sessions
        // This would need to be tracked internally if needed
        return []
    }
    
    // MARK: - Diagnostics
    
    func getDiagnosticsInfo() -> [String: Any] {
        return [
            "isAuthorized": isAuthorized,
            "lastEventsCheck": lastEventsCheck,
            "currentTimestamp": Date().timeIntervalSince1970
        ]
    }
    
    // MARK: - Cleanup
    
    func stopAllMonitoring() {
        // Stop all zenloop-related monitoring sessions
        // Note: This is a best-effort approach since we can't enumerate active sessions
        #if DEBUG
        logger.debug("🧹 [DeviceActivity] Stopping all monitoring sessions")
        #endif
        
        // In practice, this would require maintaining a list of active sessions
        // or following a naming convention to stop relevant sessions
    }
}