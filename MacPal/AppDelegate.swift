import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = PetController()
    lazy var statusPanel = HouseWindowController(controller: controller)
    private var petWindow: PetWindow?
    private var homeWindow: HomeWindow?
    private var monsterWindows: [UUID: MonsterWindow] = [:]

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
        host.frame = NSRect(origin: .zero, size: controller.petSize)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        petWindow = window

        controller.bind(window: window)
        controller.openStatusPanel = { [weak self] in
            self?.statusPanel.toggle()
        }
        controller.monsterDidSpawn = { [weak self] monster, origin in
            self?.spawnMonsterWindow(monster: monster, origin: origin)
        }
        controller.monsterDidDespawn = { [weak self] id in
            self?.despawnMonsterWindow(id: id)
        }
        controller.start()
    }

    private func spawnMonsterWindow(monster: Monster, origin: NSPoint) {
        let window = MonsterWindow(monster: monster, origin: origin)
        let host = NSHostingView(rootView: MonsterView(monster: monster))
        host.frame = NSRect(origin: .zero, size: MonsterWindow.size)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        monsterWindows[monster.id] = window
    }

    private func despawnMonsterWindow(id: UUID) {
        guard let window = monsterWindows.removeValue(forKey: id) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            window.orderOut(nil)
        }
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
