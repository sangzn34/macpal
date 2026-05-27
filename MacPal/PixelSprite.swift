import SwiftUI

enum PixelPalette {
    static let map: [Character: Color] = [
        ".": .clear,
        "K": Color(red: 0.14, green: 0.10, blue: 0.12),   // soft dark outline / pupils
        "k": Color(red: 0.30, green: 0.24, blue: 0.28),   // mid outline (anti-alias hint)
        "W": Color(red: 1.00, green: 1.00, blue: 1.00),   // white
        "w": Color(red: 0.92, green: 0.92, blue: 0.96),   // off-white (shadow on white)
        "Y": Color(red: 1.00, green: 0.92, blue: 0.68),   // soft cream
        "y": Color(red: 0.92, green: 0.78, blue: 0.55),   // cream shadow
        "P": Color(red: 1.00, green: 0.75, blue: 0.82),   // soft pink
        "p": Color(red: 0.88, green: 0.55, blue: 0.65),   // pink shadow
        "R": Color(red: 0.95, green: 0.40, blue: 0.45),   // soft red (mouth)
        "G": Color(red: 0.45, green: 0.82, blue: 0.55),   // cat eye green
        "g": Color(red: 0.25, green: 0.55, blue: 0.30),   // dark green
        "C": Color(red: 0.55, green: 0.90, blue: 0.95),   // cyan (robot eye)

        // Cat orange tabby — 3 shades
        "L": Color(red: 1.00, green: 0.82, blue: 0.55),   // highlight (light orange-cream)
        "O": Color(red: 0.97, green: 0.62, blue: 0.32),   // main orange
        "o": Color(red: 0.80, green: 0.42, blue: 0.18),   // shadow
        "D": Color(red: 0.55, green: 0.28, blue: 0.10),   // deep shadow (stripes)

        // Dog brown puppy — 3 shades
        "N": Color(red: 0.80, green: 0.62, blue: 0.42),   // highlight
        "B": Color(red: 0.62, green: 0.45, blue: 0.28),   // main brown
        "b": Color(red: 0.42, green: 0.28, blue: 0.16),   // shadow

        // Slime green — 3 shades
        "M": Color(red: 0.70, green: 0.95, blue: 0.70),   // highlight
        "S": Color(red: 0.50, green: 0.85, blue: 0.55),   // main green
        "s": Color(red: 0.28, green: 0.62, blue: 0.32),   // shadow

        // Ghost white spirit — 3 shades
        "H": Color(red: 1.00, green: 1.00, blue: 1.00),   // brightest
        "F": Color(red: 0.92, green: 0.93, blue: 0.98),   // main soft white
        "f": Color(red: 0.72, green: 0.76, blue: 0.85),   // shadow lavender-gray

        // Octopus purple — 3 shades
        "V": Color(red: 0.82, green: 0.65, blue: 0.95),   // highlight
        "U": Color(red: 0.68, green: 0.45, blue: 0.85),   // main
        "u": Color(red: 0.42, green: 0.22, blue: 0.55),   // shadow

        // Alien lime — 3 shades
        "Q": Color(red: 0.78, green: 0.98, blue: 0.65),   // highlight
        "A": Color(red: 0.62, green: 0.88, blue: 0.45),   // main
        "a": Color(red: 0.35, green: 0.62, blue: 0.22),   // shadow

        // Robot metallic — 3 shades
        "I": Color(red: 0.92, green: 0.93, blue: 0.96),   // chrome highlight
        "E": Color(red: 0.72, green: 0.76, blue: 0.82),   // main metal
        "e": Color(red: 0.42, green: 0.46, blue: 0.55),   // shadow

        // Dino teal — 3 shades
        "J": Color(red: 0.55, green: 0.85, blue: 0.72),   // highlight
        "T": Color(red: 0.35, green: 0.68, blue: 0.58),   // main
        "t": Color(red: 0.18, green: 0.40, blue: 0.32),   // shadow

        // Fish goldfish reuses cat oranges (O/o/L/D)

        // Background/accent
        "X": Color(red: 0.95, green: 0.45, blue: 0.30),   // accent red (sleep z arc, decorations)
        "Z": Color(red: 0.55, green: 0.85, blue: 1.00),   // sky blue (sparkle, water hint)
    ]

    static func color(for char: Character) -> Color {
        map[char] ?? .clear
    }
}

struct PixelSprite {
    let size: Int
    let rows: [String]

    init(_ rows: [String]) {
        let n = rows.count
        precondition(n > 0, "sprite must have at least one row")
        precondition(rows.allSatisfy { $0.count == n }, "sprite must be square; got \(n) rows with mixed widths")
        self.size = n
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
