import WatchConnectivity
import Foundation
import SwiftUI

@Observable
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    var currentHeartRate: Double = 0.0
    var isWorkoutActive: Bool = false
    var isStressMeasurementActive: Bool = false
    var isWatchConnected: Bool = false
    var statusMessage: String = ""
    var measurementTimestamp: Date? = nil

    /// Last application context payload sent to Watch (sleep + stress keys kept separate).
    private var watchApplicationContext: [String: Any] = [:]
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func startWorkout() {
        guard WCSession.default.isReachable else {
            statusMessage = "Apple Watch not reachable"
            return
        }

        syncStressMeasurementActive(true)

        WCSession.default.sendMessage(["action": "startWorkout"]) { _ in
        } errorHandler: { error in
            DispatchQueue.main.async {
                self.statusMessage = "Failed to start workout: \(error.localizedDescription)"
                self.syncStressMeasurementActive(false)
            }
        }
    }

    func stopWorkout() {
        guard WCSession.default.isReachable else {
            statusMessage = "Apple Watch not reachable"
            syncStressMeasurementActive(false)
            return
        }

        syncStressMeasurementActive(false)

        WCSession.default.sendMessage(["action": "stopWorkout"]) { _ in
        } errorHandler: { error in
            DispatchQueue.main.async {
                self.statusMessage = "Failed to stop workout: \(error.localizedDescription)"
            }
        }
    }

    /// Stress measurement flag — separate from sleep context keys on Watch.
    private func syncStressMeasurementActive(_ active: Bool) {
        isStressMeasurementActive = active
        isWorkoutActive = active
        watchApplicationContext["stressMeasurementActive"] = active
        pushWatchApplicationContext()
    }

    private func pushWatchApplicationContext() {
        guard WCSession.default.activationState == .activated else { return }
        do {
            try WCSession.default.updateApplicationContext(watchApplicationContext)
        } catch {
            print("Error updating watch application context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sleep Data Sending
    
    /// Send sleep debt data to Apple Watch
    func sendSleepDebtData(_ sleepDebtResult: AutomatedSleepDebtResult) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let efficiencyColor = efficiencyColorString(for: sleepDebtResult.baseResult.efficiency)
        let dataQualityColor = dataQualityColorString(for: sleepDebtResult.dataQuality.grade)
        
        let sleepDebtDict: [String: Any] = [
            "totalDebt": sleepDebtResult.baseResult.formattedTotalDebt,
            "severity": sleepDebtResult.baseResult.severity.rawValue,
            "efficiency": Int(sleepDebtResult.baseResult.efficiency),
            "efficiencyColor": efficiencyColor,
            "dataQualityGrade": sleepDebtResult.dataQuality.grade,
            "dataQualityColor": dataQualityColor,
            "missingDaysCount": sleepDebtResult.baseResult.missingDays.count
        ]

        watchApplicationContext["sleepDebt"] = sleepDebtDict
        pushWatchApplicationContext()
        print("Sleep debt data sent to watch")
    }
    
    /// Send sleep quality data to Apple Watch
    func sendSleepQualityData(duration: String?, quality: String?) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let sleepQualityDict: [String: Any] = [
            "duration": duration ?? "N/A",
            "quality": quality ?? "N/A"
        ]
        
        watchApplicationContext["sleepQuality"] = sleepQualityDict
        pushWatchApplicationContext()
        print("Sleep quality data sent to watch")
    }
    
    /// Send both sleep debt and quality data together
    func sendAllSleepData(_ sleepDebtResult: AutomatedSleepDebtResult, duration: String?, quality: String?) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let efficiencyColor = efficiencyColorString(for: sleepDebtResult.baseResult.efficiency)
        let dataQualityColor = dataQualityColorString(for: sleepDebtResult.dataQuality.grade)
        
        let sleepDebtDict: [String: Any] = [
            "totalDebt": sleepDebtResult.baseResult.formattedTotalDebt,
            "severity": sleepDebtResult.baseResult.severity.rawValue,
            "efficiency": Int(sleepDebtResult.baseResult.efficiency),
            "efficiencyColor": efficiencyColor,
            "dataQualityGrade": sleepDebtResult.dataQuality.grade,
            "dataQualityColor": dataQualityColor,
            "missingDaysCount": sleepDebtResult.baseResult.missingDays.count
        ]
        
        let sleepQualityDict: [String: Any] = [
            "duration": duration ?? "N/A",
            "quality": quality ?? "N/A"
        ]
        
        watchApplicationContext["sleepDebt"] = sleepDebtDict
        watchApplicationContext["sleepQuality"] = sleepQualityDict
        pushWatchApplicationContext()
        print("All sleep data sent to watch")
    }
    
    // MARK: - Helper Methods
    
    private func efficiencyColorString(for efficiency: Double) -> String {
        switch efficiency {
        case 90...: return "green"
        case 70..<90: return "blue"
        case 50..<70: return "orange"
        default: return "red"
        }
    }
    
    private func dataQualityColorString(for grade: String) -> String {
        switch grade {
        case "A": return "green"
        case "B": return "blue"
        case "C": return "orange"
        case "D": return "red"
        default: return "gray"
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated && session.isWatchAppInstalled)
            if let error = error {
                self.statusMessage = "Watch connection error: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Watch connected: \(self.isWatchConnected)"
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let heartRate = message["heartRate"] as? Double {
                self.currentHeartRate = heartRate
                self.measurementTimestamp = Date.now
                
                // Post notification for stress collector
                NotificationCenter.default.post(
                    name: NSNotification.Name("HeartRateUpdated"),
                    object: nil,
                    userInfo: ["heartRate": heartRate]
                )
            }
            
            if let workoutActive = message["workoutActive"] as? Bool {
                self.isWorkoutActive = workoutActive
            }

            if let stressActive = message["stressMeasurementActive"] as? Bool {
                self.isStressMeasurementActive = stressActive
                self.isWorkoutActive = stressActive
            }
            
            if let status = message["status"] as? String {
                self.statusMessage = status
            }
        }
    }
}

// MARK: - Usage Examples
/*
 // Send sleep debt data when it updates
 watchConnectivityManager.sendSleepDebtData(sleepDebtResult)
 
 // Send sleep quality data when it updates
 watchConnectivityManager.sendSleepQualityData(duration: "8h 0m", quality: "Good")
 
 // Send both at once
 watchConnectivityManager.sendAllSleepData(
     sleepDebtResult,
     duration: "8h 0m",
     quality: "Good"
 )
 */
