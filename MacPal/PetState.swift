import Foundation

enum PetState: Equatable {
    case idle
    case walking(direction: WalkDirection)
    case walkingHome(direction: WalkDirection)
    case approachingEnemy(direction: WalkDirection)
    case fighting
    case sleeping
    case happy
    case dragged

    var isWalkingLike: Bool {
        switch self {
        case .walking, .walkingHome, .approachingEnemy:
            return true
        case .idle, .fighting, .sleeping, .happy, .dragged:
            return false
        }
    }
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

enum PetDisplaySize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 96, height: 96)
        case .medium: return CGSize(width: 128, height: 128)
        case .large: return CGSize(width: 176, height: 176)
        }
    }
}
