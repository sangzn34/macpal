import SwiftUI

struct PetView: View {
    @Bindable var controller: PetController
    @State private var bobPhase: Double = 0
    @State private var walkToggle = false
    @State private var sparklePhase: Double = 0
    @State private var sparkleActive = false

    private let pixel: CGFloat = PetController.petSize.width / CGFloat(PixelSprite.size)

    var body: some View {
        ZStack {
            spriteCanvas
            if sparkleActive {
                sparkleOverlay
                    .allowsHitTesting(false)
            }
        }
        .frame(width: PetController.petSize.width,
               height: PetController.petSize.height)
        .contentShape(Rectangle())
        .onAppear { startTicker() }
        .onChange(of: controller.levelUpFlashTrigger) { _, _ in
            playLevelUpSparkle()
        }
    }

    private var sparkleOverlay: some View {
        Canvas { ctx, size in
            let stars: [(CGFloat, CGFloat)] = [
                (0.2, 0.15), (0.8, 0.2), (0.5, 0.05),
                (0.15, 0.55), (0.85, 0.5), (0.1, 0.85),
                (0.9, 0.85), (0.5, 0.95)
            ]
            for (i, (fx, fy)) in stars.enumerated() {
                let phase = sparklePhase + Double(i) * 0.4
                let s = abs(sin(phase)) * 6 + 2
                let cx = size.width * fx
                let cy = size.height * fy
                let rect = CGRect(x: cx - s/2, y: cy - s/2, width: s, height: s)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.yellow.opacity(0.85))
                )
            }
        }
    }

    private func playLevelUpSparkle() {
        sparkleActive = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            sparkleActive = false
        }
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
                sparklePhase += 0.5
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            MainActor.assumeIsolated {
                walkToggle.toggle()
            }
        }
    }
}
