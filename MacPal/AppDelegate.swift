import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = PetController()
    lazy var houseWindow = HouseWindowController(controller: controller)
    private var petWindow: PetWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let window = PetWindow(controller: controller)
        let host = NSHostingView(rootView: PetView(controller: controller))
        host.frame = NSRect(origin: .zero, size: PetController.petSize)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        petWindow = window

        controller.bind(window: window)
        controller.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
