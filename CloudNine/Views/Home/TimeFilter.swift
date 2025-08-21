import Foundation

enum HeartFilter: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

enum SleepFilter: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}
