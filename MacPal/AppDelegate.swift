import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = PetController()
    lazy var statusPanel = HouseWindowController(controller: controller)
    private var petWindow: PetWindow?
    private var homeWindow: HomeWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let home = HomeWindow(controller: controller)
        let homeHost = NSHostingView(rootView: HomeView())
        homeHost.frame = NSRect(origin: .zero,
                                size: NSSize(width: PetHouse.displaySize,
                                             height: PetHouse.displaySize))
        home.contentView = homeHost
        home.makeKeyAndOrderFront(nil)
        homeWindow = home
        controller.houseDidMove(home.frame.origin)

        let window = PetWindow(controller: controller)
        let host = NSHostingView(rootView: PetView(controller: controller))
        host.frame = NSRect(origin: .zero, size: PetController.petSize)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        petWindow = window

        controller.bind(window: window)
        controller.openStatusPanel = { [weak self] in
            self?.statusPanel.toggle()
        }
        controller.start()
    }

    func toggleHomeWindow() {
        guard let homeWindow else { return }
        if homeWindow.isVisible {
            homeWindow.orderOut(nil)
        } else {
            homeWindow.makeKeyAndOrderFront(nil)
            controller.houseDidMove(homeWindow.frame.origin)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
