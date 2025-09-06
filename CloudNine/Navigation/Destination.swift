import Foundation

enum Destination: Hashable {
    case profile
    case editLog(logId: String)
}
