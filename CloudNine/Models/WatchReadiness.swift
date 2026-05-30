import Foundation
import WatchConnectivity

/// Layered Apple Watch readiness for stress measurement.
enum WatchReadiness: Equatable {
    case unavailable(reason: String)
    case backgroundStartPossible
    case interactive

    var canStartMeasurement: Bool {
        switch self {
        case .unavailable: return false
        case .backgroundStartPossible, .interactive: return true
        }
    }

    var statusLabel: String {
        switch self {
        case .unavailable(let reason):
            return reason
        case .backgroundStartPossible:
            return "Open CloudNine on your Apple Watch, then tap Start Measuring."
        case .interactive:
            return "Watch connected — you're ready to measure."
        }
    }

    static func evaluate(session: WCSession = .default) -> WatchReadiness {
        guard session.activationState == .activated else {
            return .unavailable(reason: "Connecting to Apple Watch…")
        }
        guard session.isPaired else {
            return .unavailable(reason: "No Apple Watch paired")
        }
        guard session.isWatchAppInstalled else {
            return .unavailable(reason: "Install CloudNine on your Apple Watch")
        }
        if session.isReachable {
            return .interactive
        }
        return .backgroundStartPossible
    }
}

enum WatchMeasurementStartError: LocalizedError {
    case notReady(String)
    case workoutStartTimedOut
    case noHeartRateData

    var errorDescription: String? {
        switch self {
        case .notReady(let message):
            return message
        case .workoutStartTimedOut:
            return "Couldn't start a workout on your Apple Watch. Open CloudNine on your Watch and try again."
        case .noHeartRateData:
            return "No heart rate data from your Apple Watch. Open CloudNine on your Watch, wear it on your wrist, and try again."
        }
    }
}

enum WatchMeasurementStartResult {
    case workoutStarted
    case timedOut
}
