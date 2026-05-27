import SwiftUI

@main
struct MacPalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("MacPal", systemImage: "pawprint.circle.fill") {
            MenuBarContent(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @Bindable var controller: PetController

    var body: some View {
        Button(controller.isSleeping ? "Wake up" : "Sleep") {
            controller.toggleSleep()
        }
        Divider()
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
