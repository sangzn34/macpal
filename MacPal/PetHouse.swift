import Foundation
import AppKit

enum PetHouse {
    static let displaySize: CGFloat = 144

    static let sprite = PixelSprite([
        "........................",
        "........................",
        "...........KK...........",
        "..........KRRK..........",
        ".........KRRRRK.........",
        "........KRRRRRRK........",
        ".......KRRRRRRRRK.......",
        "......KRRRRRRRRRRK......",
        ".....KRRRRRRRRRRRRK.....",
        "....KRRRRRRRRRRRRRRK....",
        "...KRRRRRRRRRRRRRRRRK...",
        "..KKKKKKKKKKKKKKKKKKKK..",
        "..KBBBBBBBBBBBBBBBBBBK..",
        "..KBBBBBBBBBBBBBBBBBBK..",
        "..KBKKKKBBBKKKKKBBBBBK..",
        "..KBKWWKBBBKbbbKBBBBBK..",
        "..KBKWWKBBBKbbbKBBBBBK..",
        "..KBKKKKBBBKbbbKBBBBBK..",
        "..KBBBBBBBBKbbbKBBBBBK..",
        "..KBBBBBBBBKbbbKBBBBBK..",
        "..KBBBBBBBBKKKKKBBBBBK..",
        "..KbbbbbbbbbbbbbbbbbbK..",
        "..KKKKKKKKKKKKKKKKKKKK..",
        "........................"
    ])

    static var initialOrigin: NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        return NSPoint(x: frame.maxX - displaySize - 24, y: frame.minY + 24)
    }

    /// Approximate door center in window-local coords (used as walk-home target).
    static var doorCenterOffset: NSPoint {
        let pixel = displaySize / CGFloat(sprite.size)
        // Door column ~12-14, bottom row ~20 (origin at bottom-left in AppKit)
        let centerX = (CGFloat(13) + 0.5) * pixel
        // Vertical: door bottom row index 20 -> from top. Convert: y from bottom = (size - 20*pixel)
        let bottomY = displaySize - CGFloat(21) * pixel
        return NSPoint(x: centerX, y: bottomY)
    }
}
