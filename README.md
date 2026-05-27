# MacPal

Tiny 2D desktop pet for macOS. Floats on top of every Space, walks around the bottom of the screen, naps after 30s idle, bounces when you click, can be dragged with the mouse, and lives in the menu bar.

## Build

Requires Xcode 16+ and `xcodegen` (`brew install xcodegen`).

```bash
xcodegen generate
xcodebuild -project MacPal.xcodeproj -scheme MacPal -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/MacPal.app
```

## Controls

| Action | Effect |
| --- | --- |
| Click pet | Happy bounce |
| Drag pet | Move window |
| Idle 30s | Pet falls asleep |
| Menu bar → Wake / Sleep | Force state |
| Menu bar → Speed | Walking speed |
| Menu bar → Reset position | Re-center pet |
| Menu bar → Quit | Exit app |

## Tech

- Swift 6.0, SwiftUI + AppKit (`NSWindow` overlay)
- Borderless transparent floating window, joins all Spaces
- `@Observable PetController` drives a state machine on a 30Hz timer
- `LSUIElement = true` — menu bar only, no Dock icon
- macOS 14+
