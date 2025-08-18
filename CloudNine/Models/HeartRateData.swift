import Foundation

struct HeartRateData: Identifiable {
    let id = UUID()
    let date: Date
    let heartRate: Double
    let timestamp: String
}
