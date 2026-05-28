import AppKit

final class PetWindow: NSWindow {
    private weak var controller: PetController?
    private var dragStart: NSPoint?

    init(controller: PetController) {
        self.controller = controller
        let size = controller.petSize
        let origin = PetController.initialOrigin(for: size)
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
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        controller?.beginDrag()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let mouseScreen = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: mouseScreen.x - start.x,
            y: mouseScreen.y - start.y
        )
        setFrameOrigin(newOrigin)
        controller?.didDrag(to: newOrigin)
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
            controller?.handleClick()
        } else {
            controller?.endDrag()
        }
    }
}
