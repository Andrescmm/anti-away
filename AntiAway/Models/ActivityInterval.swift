import Foundation

enum ActivityInterval: Int, CaseIterable, Identifiable, Codable {
    case every30Seconds = 30
    case every60Seconds = 60
    case every120Seconds = 120
    case every240Seconds = 240

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .every30Seconds: "Every 30 seconds"
        case .every60Seconds: "Every minute"
        case .every120Seconds: "Every 2 minutes"
        case .every240Seconds: "Every 4 minutes"
        }
    }

    var shortTitle: String {
        switch self {
        case .every30Seconds: "30 sec"
        case .every60Seconds: "1 min"
        case .every120Seconds: "2 min"
        case .every240Seconds: "4 min"
        }
    }
}
