import AppKit
import SwiftUI

@MainActor
final class HouseWindowController {
    private let controller: PetController
    private var window: NSWindow?

    init(controller: PetController) {
        self.controller = controller
    }

    func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: HouseView(controller: controller))
        let window = NSWindow(contentViewController: host)
        window.title = "MacPal House"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 360, height: 380))
        window.center()
        window.level = .normal
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
