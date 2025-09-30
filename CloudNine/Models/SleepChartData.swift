import Foundation
import Charts

struct SleepChartData: Identifiable, Plottable {
    typealias PrimitivePlottable = Date
    
    let id = UUID()
    let date: Date
    let duration: Double 
    let quality: String
    let timestamp: String
    
    var primitivePlottable: Date {
        date
    }
    
    init(date: Date, duration: Double, quality: String, timestamp: String) {
        self.date = date
        self.duration = duration
        self.quality = quality
        self.timestamp = timestamp
    }
    
    init?(primitivePlottable: Date) {
        return nil
    }
}
