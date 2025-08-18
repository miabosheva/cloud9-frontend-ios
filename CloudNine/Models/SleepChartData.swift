import Foundation

struct SleepChartData: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Double 
    let quality: String
    let timestamp: String
}
