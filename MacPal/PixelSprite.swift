import SwiftUI

enum PixelPalette {
    static let map: [Character: Color] = [
        ".": .clear,
        "K": Color(red: 0.10, green: 0.07, blue: 0.05),   // dark outline / pupils
        "W": Color(red: 1.00, green: 1.00, blue: 1.00),   // white (eye glint, z, ghost)
        "Y": Color(red: 1.00, green: 0.85, blue: 0.50),   // cream / belly
        "P": Color(red: 1.00, green: 0.65, blue: 0.75),   // pink (nose, ear inside, cheek)
        "R": Color(red: 0.95, green: 0.25, blue: 0.35),   // red (mouth)
        "G": Color(red: 0.30, green: 0.80, blue: 0.40),   // green (cat eyes)

        // Cat (orange tabby)
        "O": Color(red: 0.95, green: 0.55, blue: 0.20),
        "o": Color(red: 0.78, green: 0.40, blue: 0.10),

        // Dog (brown puppy)
        "B": Color(red: 0.55, green: 0.35, blue: 0.20),
        "b": Color(red: 0.38, green: 0.22, blue: 0.10),

        // Slime (green)
        "S": Color(red: 0.45, green: 0.85, blue: 0.50),
        "s": Color(red: 0.25, green: 0.60, blue: 0.30),

        // Ghost (white spirit + light shadow)
        "F": Color(red: 0.97, green: 0.97, blue: 1.00),
        "f": Color(red: 0.75, green: 0.78, blue: 0.85),

        // Octopus (purple)
        "U": Color(red: 0.65, green: 0.35, blue: 0.85),
        "u": Color(red: 0.40, green: 0.18, blue: 0.55),

        // Alien (lime green)
        "A": Color(red: 0.55, green: 0.90, blue: 0.45),
        "a": Color(red: 0.30, green: 0.60, blue: 0.20),

        // Robot (metallic gray)
        "E": Color(red: 0.78, green: 0.80, blue: 0.85),
        "e": Color(red: 0.45, green: 0.48, blue: 0.55),

        // Dino (teal-green)
        "T": Color(red: 0.30, green: 0.65, blue: 0.55),
        "t": Color(red: 0.15, green: 0.40, blue: 0.30),

        // Cyan (robot eye, alien details)
        "C": Color(red: 0.35, green: 0.85, blue: 0.95),
    ]

    static func color(for char: Character) -> Color {
        map[char] ?? .clear
    }
}

struct PixelSprite {
    static let size = 24
    let rows: [String]

    init(_ rows: [String]) {
        precondition(rows.count == PixelSprite.size, "expect \(PixelSprite.size) rows")
        self.rows = rows
    }

    func color(x: Int, y: Int) -> Color {
        let row = rows[y]
        let idx = row.index(row.startIndex, offsetBy: x)
        return PixelPalette.color(for: row[idx])
    }
}

enum PetEcosystem: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case ocean = "Ocean"
    case space = "Space"
    case prehistoric = "Prehistoric"
    var id: String { rawValue }
}

struct PixelCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let ecosystem: PetEcosystem
    let idle: PixelSprite
    let walkA: PixelSprite
    let walkB: PixelSprite
    let sleep: PixelSprite
    let happy: PixelSprite

    func sprite(for state: PetState, walkToggle: Bool) -> PixelSprite {
        switch state {
        case .idle, .fighting: return walkToggle ? happy : idle
        case .walking, .walkingHome, .approachingEnemy: return walkToggle ? walkA : walkB
        case .sleeping: return sleep
        case .happy, .dragged: return happy
        }
    }

    static func == (lhs: PixelCharacter, rhs: PixelCharacter) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
