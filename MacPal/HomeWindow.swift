import AppKit
import SwiftUI

@MainActor
final class HomeWindow: NSWindow {
    private weak var controller: PetController?
    private var dragStart: NSPoint?

    init(controller: PetController) {
        self.controller = controller
        let size = NSSize(width: PetHouse.displaySize, height: PetHouse.displaySize)
        let origin = PetHouse.initialOrigin
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let mouse = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: mouse.x - start.x, y: mouse.y - start.y))
        controller?.houseDidMove(frame.origin)
    }

    override func mouseUp(with event: NSEvent) {
        let distance: CGFloat
        if let start = dragStart {
            let end = event.locationInWindow
            distance = hypot(end.x - start.x, end.y - start.y)
        } else {
            distance = 0
        }
        dragStart = nil
        if distance < 4 {
            controller?.houseDidTap()
        }
    }
}

struct HomeView: View {
    var body: some View {
        PixelSpriteView(sprite: PetHouse.sprite, size: PetHouse.displaySize)
            .frame(width: PetHouse.displaySize, height: PetHouse.displaySize)
    }
}
