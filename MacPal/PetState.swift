import Foundation

enum PetState: Equatable {
    case idle
    case walking(direction: WalkDirection)
    case walkingHome(direction: WalkDirection)
    case sleeping
    case happy
    case dragged
}

enum WalkDirection {
    case left
    case right

    var sign: CGFloat {
        switch self {
        case .left: return -1
        case .right: return 1
        }
    }

    var flipped: Bool { self == .left }
}

enum PetSpeed: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var pixelsPerTick: CGFloat {
        switch self {
        case .low: return 0.6
        case .medium: return 1.4
        case .high: return 2.6
        }
    }
}
