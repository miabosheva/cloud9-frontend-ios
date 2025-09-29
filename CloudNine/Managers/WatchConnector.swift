import WatchConnectivity
import Foundation

@Observable
class WatchConnector: NSObject, WCSessionDelegate {
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
