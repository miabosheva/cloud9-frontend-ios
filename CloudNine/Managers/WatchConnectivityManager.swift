import WatchConnectivity
import Foundation
import SwiftUI

@Observable
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    var currentHeartRate: Double = 0.0
    var isWorkoutActive: Bool = false
    var isWatchConnected: Bool = false
    var statusMessage: String = ""
    var measurementTimestamp: Date? = nil
    
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
        
        WCSession.default.sendMessage(["action": "startWorkout"]) { response in
            // Handle response if needed
        } errorHandler: { error in
            DispatchQueue.main.async {
                self.statusMessage = "Failed to start workout: \(error.localizedDescription)"
            }
        }
    }
    
    func stopWorkout() {
        guard WCSession.default.isReachable else {
            statusMessage = "Apple Watch not reachable"
            return
        }
        
        WCSession.default.sendMessage(["action": "stopWorkout"]) { response in
            // Handle response if needed
        } errorHandler: { error in
            DispatchQueue.main.async {
                self.statusMessage = "Failed to stop workout: \(error.localizedDescription)"
            }
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
        
        let context: [String: Any] = ["sleepDebt": sleepDebtDict]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Sleep debt data sent to watch")
        } catch {
            print("Error sending sleep debt data: \(error.localizedDescription)")
        }
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
        
        let context: [String: Any] = ["sleepQuality": sleepQualityDict]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Sleep quality data sent to watch")
        } catch {
            print("Error sending sleep quality data: \(error.localizedDescription)")
        }
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
        
        let context: [String: Any] = [
            "sleepDebt": sleepDebtDict,
            "sleepQuality": sleepQualityDict
        ]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("All sleep data sent to watch")
        } catch {
            print("Error sending sleep data: \(error.localizedDescription)")
        }
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
            }
            
            if let workoutActive = message["workoutActive"] as? Bool {
                self.isWorkoutActive = workoutActive
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
