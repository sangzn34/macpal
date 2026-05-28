import Foundation
import SwiftUI

enum SkillEffectKind: String, Codable {
    case bite       // quick lunge w/ yellow burst
    case slash      // diagonal white slash line
    case pounce     // pet dashes forward dramatically
    case fireball   // orange projectile flies to monster
    case spin       // spin attack rotating
}

struct PetSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let damage: ClosedRange<Int>
    let cooldown: TimeInterval
    let levelRequired: Int
    let effect: SkillEffectKind
    let castDuration: TimeInterval
    let color: Color

    static func == (lhs: PetSkill, rhs: PetSkill) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PetSkills {
    static let bite = PetSkill(
        id: "bite", name: "Bite",
        damage: 3...6, cooldown: 0.0, levelRequired: 1,
        effect: .bite, castDuration: 0.4,
        color: .yellow
    )

    static let slash = PetSkill(
        id: "slash", name: "Slash",
        damage: 7...12, cooldown: 2.5, levelRequired: 3,
        effect: .slash, castDuration: 0.5,
        color: .white
    )

    static let pounce = PetSkill(
        id: "pounce", name: "Pounce!",
        damage: 10...16, cooldown: 4.0, levelRequired: 5,
        effect: .pounce, castDuration: 0.6,
        color: .orange
    )

    static let fireball = PetSkill(
        id: "fireball", name: "Fireball!",
        damage: 15...24, cooldown: 7.0, levelRequired: 7,
        effect: .fireball, castDuration: 0.8,
        color: Color(red: 1.0, green: 0.55, blue: 0.20)
    )

    static let spin = PetSkill(
        id: "spin", name: "Spin Attack!",
        damage: 20...32, cooldown: 12.0, levelRequired: 10,
        effect: .spin, castDuration: 1.0,
        color: .cyan
    )

    static let all: [PetSkill] = [bite, slash, pounce, fireball, spin]

    static func unlocked(at level: Int) -> [PetSkill] {
        all.filter { level >= $0.levelRequired }
    }
}

struct ActiveSkillCast: Equatable {
    let skill: PetSkill
    let startedAt: Date
    var progress: Double {
        let elapsed = Date.now.timeIntervalSince(startedAt)
        return min(1, max(0, elapsed / skill.castDuration))
    }
    var isFinished: Bool {
        Date.now.timeIntervalSince(startedAt) >= skill.castDuration
    }
}
