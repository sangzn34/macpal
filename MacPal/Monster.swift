import Foundation
import Observation

enum MonsterKind: String, CaseIterable, Identifiable {
    case bat, goblin, skeleton
    var id: String { rawValue }

    var name: String {
        switch self {
        case .bat: return "Bat"
        case .goblin: return "Goblin"
        case .skeleton: return "Skeleton"
        }
    }

    var maxHP: Int {
        switch self {
        case .bat: return 18
        case .goblin: return 32
        case .skeleton: return 50
        }
    }

    var attack: Int {
        switch self {
        case .bat: return 3
        case .goblin: return 5
        case .skeleton: return 8
        }
    }

    var xpReward: Int {
        switch self {
        case .bat: return 12
        case .goblin: return 22
        case .skeleton: return 38
        }
    }

    var idle: PixelSprite {
        switch self {
        case .bat: return MonsterSprites.bat
        case .goblin: return MonsterSprites.goblin
        case .skeleton: return MonsterSprites.skeleton
        }
    }
}

@MainActor
@Observable
final class Monster: Identifiable {
    let id = UUID()
    let kind: MonsterKind
    var hp: Int
    var hurtFlash: Int = 0
    var isDead: Bool { hp <= 0 }

    init(kind: MonsterKind) {
        self.kind = kind
        self.hp = kind.maxHP
    }
}
