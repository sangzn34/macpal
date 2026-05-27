import SwiftUI

@main
struct MacPalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("MacPal", systemImage: "pawprint.circle.fill") {
            MenuBarContent(
                controller: appDelegate.controller,
                houseWindow: appDelegate.houseWindow
            )
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @Bindable var controller: PetController
    let houseWindow: HouseWindowController

    var body: some View {
        Text("\(controller.character.name) — Lvl \(controller.stats.level)")
        Text("XP \(controller.stats.xp) / \(controller.stats.xpToNextLevel)")
        Text("🍗 \(controller.stats.hunger)   ❤️ \(controller.stats.happiness)")
        Divider()
        Button("Open House…") {
            houseWindow.toggle()
        }
        .keyboardShortcut("h")
        Button("Feed") {
            _ = controller.feed()
        }
        .keyboardShortcut("f")
        Button("Play") {
            _ = controller.play()
        }
        .keyboardShortcut("p")
        Divider()
        Button(controller.isSleeping ? "Wake up" : "Sleep") {
            controller.toggleSleep()
        }
        Divider()
        Menu("Character") {
            ForEach(PetEcosystem.allCases) { eco in
                Section(eco.rawValue) {
                    ForEach(PetCharacters.characters(in: eco)) { character in
                        Button {
                            controller.character = character
                        } label: {
                            if controller.character.id == character.id {
                                Label(character.name, systemImage: "checkmark")
                            } else {
                                Text(character.name)
                            }
                        }
                    }
                }
            }
        }
        Menu("Speed") {
            ForEach(PetSpeed.allCases) { speed in
                Button {
                    controller.speed = speed
                } label: {
                    if controller.speed == speed {
                        Label(speed.label, systemImage: "checkmark")
                    } else {
                        Text(speed.label)
                    }
                }
            }
        }
        Button("Reset position") {
            controller.resetPosition()
        }
        Divider()
        Button("Quit MacPal") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
