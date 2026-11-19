import WatchConnectivity
import Foundation
import SwiftUI

@Observable
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    var currentHeartRate: Double = 0.0
    var isWorkoutActive: Bool = false
    var isStressMeasurementActive: Bool = false
    var isWatchConnected: Bool = false
    var isPaired: Bool = false
    var isWatchAppInstalled: Bool = false
    var readiness: WatchReadiness = .unavailable(reason: "Connecting to Apple Watch…")
    var statusMessage: String = ""
    var measurementTimestamp: Date? = nil

    private var watchApplicationContext: [String: Any] = [:]

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        refreshReadiness()
    }

    func refreshReadiness() {
        let session = WCSession.default
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isWatchConnected = session.activationState == .activated && session.isWatchAppInstalled
        readiness = WatchReadiness.evaluate(session: session)
    }

    // MARK: - Stress measurement (context-first)

    /// Starts a Watch workout via application context; uses sendMessage when reachable.
    @discardableResult
    func requestStressMeasurementStart() -> WatchMeasurementStartResult? {
        refreshReadiness()
        guard readiness.canStartMeasurement else {
            statusMessage = readiness.statusLabel
            return nil
        }

        syncStressMeasurementActive(true)

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "startWorkout"]) { _ in
            } errorHandler: { error in
                DispatchQueue.main.async {
                    print("⚠️ sendMessage startWorkout failed: \(error.localizedDescription)")
                }
            }
        }

        return .workoutStarted
    }

    /// Waits until the Watch confirms a workout or times out.
    func waitForWorkoutStart(timeout: TimeInterval = 10) async -> WatchMeasurementStartResult {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isStressMeasurementActive || isWorkoutActive {
                return .workoutStarted
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return .timedOut
    }

    func stopWorkout() {
        syncStressMeasurementActive(false)

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "stopWorkout"]) { _ in
            } errorHandler: { error in
                DispatchQueue.main.async {
                    print("⚠️ sendMessage stopWorkout failed: \(error.localizedDescription)")
                }
            }
        }
    }

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
    }

    func sendSleepQualityData(duration: String?, quality: String?) {
        guard WCSession.default.activationState == .activated else { return }

        watchApplicationContext["sleepQuality"] = [
            "duration": duration ?? "N/A",
            "quality": quality ?? "N/A"
        ]
        pushWatchApplicationContext()
    }

    func sendAllSleepData(_ sleepDebtResult: AutomatedSleepDebtResult, duration: String?, quality: String?) {
        guard WCSession.default.activationState == .activated else { return }

        let efficiencyColor = efficiencyColorString(for: sleepDebtResult.baseResult.efficiency)
        let dataQualityColor = dataQualityColorString(for: sleepDebtResult.dataQuality.grade)

        watchApplicationContext["sleepDebt"] = [
            "totalDebt": sleepDebtResult.baseResult.formattedTotalDebt,
            "severity": sleepDebtResult.baseResult.severity.rawValue,
            "efficiency": Int(sleepDebtResult.baseResult.efficiency),
            "efficiencyColor": efficiencyColor,
            "dataQualityGrade": sleepDebtResult.dataQuality.grade,
            "dataQualityColor": dataQualityColor,
            "missingDaysCount": sleepDebtResult.baseResult.missingDays.count
        ]

        watchApplicationContext["sleepQuality"] = [
            "duration": duration ?? "N/A",
            "quality": quality ?? "N/A"
        ]
        pushWatchApplicationContext()
    }

    // MARK: - Helpers

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
            self.refreshReadiness()
            if let error {
                self.statusMessage = "Watch connection error: \(error.localizedDescription)"
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refreshReadiness()
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refreshReadiness()
        }
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refreshReadiness()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let heartRate = message["heartRate"] as? Double {
                self.currentHeartRate = heartRate
                self.measurementTimestamp = Date.now
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
