import SwiftUI

struct PetView: View {
    @Bindable var controller: PetController
    @State private var bobPhase: Double = 0
    @State private var walkToggle = false

    private let pixel: CGFloat = PetController.petSize.width / CGFloat(PixelSprite.size)

    var body: some View {
        spriteCanvas
            .frame(width: PetController.petSize.width,
                   height: PetController.petSize.height)
            .contentShape(Rectangle())
            .onAppear { startTicker() }
    }

    private var spriteCanvas: some View {
        let (sprite, flipX, yOffset, rotation) = renderSpec(for: controller.state)
        return Canvas { ctx, size in
            for y in 0..<PixelSprite.size {
                for x in 0..<PixelSprite.size {
                    let color = sprite.color(x: x, y: y)
                    let rect = CGRect(
                        x: CGFloat(x) * pixel,
                        y: CGFloat(y) * pixel,
                        width: pixel,
                        height: pixel
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
            _ = size
        }
        .scaleEffect(x: flipX ? -1 : 1, y: 1)
        .offset(y: yOffset)
        .rotationEffect(.degrees(rotation))
        .animation(.easeInOut(duration: 0.12), value: yOffset)
        .animation(.easeInOut(duration: 0.12), value: rotation)
        .shadow(
            color: controller.state == .dragged ? .black.opacity(0.35) : .clear,
            radius: 8, x: 0, y: 6
        )
    }

    private func renderSpec(for state: PetState) -> (PixelSprite, Bool, CGFloat, Double) {
        let character = controller.character
        switch state {
        case .idle:
            let bob = sin(bobPhase * 0.5) * 1.0
            return (character.idle, false, CGFloat(bob), 0)
        case .walking(let direction):
            let sprite = walkToggle ? character.walkA : character.walkB
            let bob = abs(sin(bobPhase)) * 2.0
            return (sprite, direction.flipped, CGFloat(-bob), 0)
        case .sleeping:
            let bob = sin(bobPhase * 0.4) * 0.6
            return (character.sleep, false, CGFloat(bob), 0)
        case .happy:
            let bounce = abs(sin(bobPhase * 3)) * 4.0
            let tilt = sin(bobPhase * 4) * 5
            return (character.happy, false, CGFloat(-bounce), tilt)
        case .dragged:
            return (character.happy, false, 0, 0)
        }
    }

    private func startTicker() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                bobPhase += 0.4
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            MainActor.assumeIsolated {
                walkToggle.toggle()
            }
        }
    }
}
