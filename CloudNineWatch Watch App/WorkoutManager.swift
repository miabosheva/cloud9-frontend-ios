import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI

class WorkoutManager: NSObject, ObservableObject {
    var selectedWorkout: HKWorkoutActivityType = .other
    
    @Published var showingSummaryView: Bool = false {
        didSet {
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    @Published var running = false
    @Published var heartRate: Double = 0
    @Published var statusMessage: String = ""
    
    // Sleep data from iPhone
    @Published var sleepDebtData: SleepDebtData?
    @Published var sleepQualityData: SleepQualityData?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = selectedWorkout
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            statusMessage = "Failed to create workout session"
            return
        }
        
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: configuration)
        
        session?.delegate = self
        builder?.delegate = self
        
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { (success, error) in
            DispatchQueue.main.async {
                self.running = success
                if success {
                    self.statusMessage = "Measuring started"
                    self.sendMessageToPhone(["workoutActive": true, "status": "Workout started"])
                } else {
                    self.statusMessage = "Failed to start workout"
                }
            }
        }
    }
    
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                if success {
                    self.statusMessage = "Health access granted"
                } else {
                    self.statusMessage = "Health access denied"
                }
            }
        }
    }
    
    func endWorkout() {
        session?.end()
        showingSummaryView = true
        sendMessageToPhone(["workoutActive": false, "status": "Workout ended"])
    }
    
    func resetWorkout() {
        selectedWorkout = .other
        builder = nil
        session = nil
        running = false
        heartRate = 0
        statusMessage = ""
    }
    
    private func sendMessageToPhone(_ message: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message: \(error.localizedDescription)")
            }
        }
    }
    
    // Parse sleep data from iPhone
    private func parseSleepData(from context: [String: Any]) {
        // Parse Sleep Debt Data
        if let debtDict = context["sleepDebt"] as? [String: Any] {
            self.sleepDebtData = SleepDebtData(
                totalDebt: debtDict["totalDebt"] as? String ?? "N/A",
                severity: debtDict["severity"] as? String ?? "Unknown",
                severityIcon: debtDict["severityIcon"] as? String ?? "moon.fill",
                severityColor: colorFromString(debtDict["severityColor"] as? String),
                efficiency: debtDict["efficiency"] as? Int ?? 0,
                efficiencyColor: colorFromString(debtDict["efficiencyColor"] as? String),
                dataQualityGrade: debtDict["dataQualityGrade"] as? String ?? "N/A",
                dataQualityColor: colorFromString(debtDict["dataQualityColor"] as? String),
                missingDaysCount: debtDict["missingDaysCount"] as? Int ?? 0
            )
        }
        
        // Parse Sleep Quality Data
        if let qualityDict = context["sleepQuality"] as? [String: Any] {
            self.sleepQualityData = SleepQualityData(
                duration: qualityDict["duration"] as? String ?? "N/A",
                quality: qualityDict["quality"] as? String ?? "N/A"
            )
        }
    }
    
    private func colorFromString(_ colorString: String?) -> Color {
        switch colorString {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.running = toState == .running
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Workout failed: \(error.localizedDescription)"
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return
            }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            updateForStatistics(statistics)
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                
                // Send heart rate to iPhone
                self.sendMessageToPhone(["heartRate": self.heartRate])
            default:
                return
            }
        }
    }
}

extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated successfully")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let action = message["action"] as? String {
            DispatchQueue.main.async {
                switch action {
                case "startWorkout":
                    self.startWorkout()
                    replyHandler(["status": "workout started"])
                case "stopWorkout":
                    self.endWorkout()
                    replyHandler(["status": "workout stopped"])
                default:
                    replyHandler(["status": "unknown action"])
                }
            }
        }
    }
    
    // NEW: Receive application context updates from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.parseSleepData(from: applicationContext)
            print("Received sleep data from iPhone")
        }
    }
}
