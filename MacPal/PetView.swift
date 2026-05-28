import SwiftUI

struct PetView: View {
    @Bindable var controller: PetController
    @State private var bobPhase: Double = 0
    @State private var walkToggle = false
    @State private var sparklePhase: Double = 0
    @State private var sparkleActive = false
    @State private var animationTimer: Timer?
    @State private var walkTimer: Timer?

    private var pixel: CGFloat {
        controller.petSize.width / CGFloat(controller.character.idle.size)
    }

    var body: some View {
        ZStack {
            spriteCanvas
                .offset(x: skillSpriteOffset.x, y: skillSpriteOffset.y)
            if sparkleActive {
                sparkleOverlay
                    .allowsHitTesting(false)
            }
            if let cast = controller.activeSkillCast {
                SkillEffectView(cast: cast)
                    .frame(width: controller.petSize.width, height: controller.petSize.height)
                    .allowsHitTesting(false)
                Text(cast.skill.name)
                    .font(.system(size: 12 * sizeScale, weight: .heavy, design: .rounded))
                    .foregroundStyle(cast.skill.color)
                    .shadow(color: .black, radius: 1)
                    .offset(y: -55 * sizeScale)
                    .opacity(1.0 - cast.progress * 0.6)
                    .allowsHitTesting(false)
            }
            if let dmg = controller.lastDamageTaken, Date.now.timeIntervalSince(dmg.at) < 0.8 {
                Text("-\(dmg.amount)")
                    .font(.system(size: 14 * sizeScale, weight: .heavy, design: .rounded))
                    .foregroundStyle(.red)
                    .shadow(color: .black, radius: 1)
                    .offset(y: -40 * sizeScale)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: controller.petSize.width,
               height: controller.petSize.height)
        .contentShape(Rectangle())
        .onAppear { startTicker() }
        .onDisappear { stopTicker() }
        .onChange(of: controller.state) { _, _ in
            startTicker()
        }
        .onChange(of: controller.levelUpFlashTrigger) { _, _ in
            playLevelUpSparkle()
        }
    }

    private var sizeScale: CGFloat {
        controller.petSize.width / 128
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

    private var skillSpriteOffset: CGPoint {
        guard let cast = controller.activeSkillCast else { return .zero }
        let p = cast.progress
        switch cast.skill.effect {
        case .pounce:
            // dash forward then back
            let curve = sin(p * .pi) * 16 * sizeScale
            return CGPoint(x: curve, y: 0)
        case .bite:
            let curve = sin(p * .pi) * 6 * sizeScale
            return CGPoint(x: curve, y: 0)
        case .slash:
            return CGPoint(x: sin(p * .pi) * 4 * sizeScale, y: 0)
        case .spin:
            return .zero
        case .fireball:
            return CGPoint(x: -sin(p * .pi) * 3 * sizeScale, y: -sin(p * .pi) * 2 * sizeScale)
        }
    }

    private var spriteCanvas: some View {
        let (sprite, flipX, yOffset, rotation) = renderSpec(for: controller.state)
        let pixelSize = controller.petSize.width / CGFloat(sprite.size)
        return Canvas { ctx, _ in
            for y in 0..<sprite.size {
                for x in 0..<sprite.size {
                    let color = sprite.color(x: x, y: y)
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize,
                        y: CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
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
        case .walking(let direction),
             .walkingHome(let direction),
             .approachingEnemy(let direction):
            let sprite = walkToggle ? character.walkA : character.walkB
            let bob = abs(sin(bobPhase)) * 2.0
            return (sprite, direction.flipped, CGFloat(-bob), 0)
        case .fighting:
            let lunge = sin(bobPhase * 4) * 6 * sizeScale
            return (character.happy, false, CGFloat(lunge), 0)
        case .sleeping:
            let bob = sin(bobPhase * 0.4) * 0.6
            return (character.sleep, false, CGFloat(bob), 0)
        case .happy:
            let bounce = abs(sin(bobPhase * 3)) * 4.0 * sizeScale
            let tilt = sin(bobPhase * 4) * 5
            return (character.happy, false, CGFloat(-bounce), tilt)
        case .dragged:
            return (character.happy, false, 0, 0)
        }
    }

    private func startTicker() {
        stopTicker()

        let timer = Timer(timeInterval: animationInterval, repeats: true) { _ in
            MainActor.assumeIsolated {
                bobPhase += 0.4
                sparklePhase += 0.5
            }
        }
        timer.tolerance = animationInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer

        guard controller.state.isWalkingLike else { return }
        let walk = Timer(timeInterval: 0.22, repeats: true) { _ in
            MainActor.assumeIsolated {
                walkToggle.toggle()
            }
        }
        walk.tolerance = 0.04
        RunLoop.main.add(walk, forMode: .common)
        walkTimer = walk
    }

    private func stopTicker() {
        animationTimer?.invalidate()
        animationTimer = nil
        walkTimer?.invalidate()
        walkTimer = nil
    }

    private var animationInterval: TimeInterval {
        switch controller.state {
        case .walking, .walkingHome, .approachingEnemy, .fighting, .happy, .dragged:
            return 1.0 / 12.0
        case .idle:
            return 0.25
        case .sleeping:
            return 0.5
        }
    }
}

struct SkillEffectView: View {
    let cast: ActiveSkillCast

    var body: some View {
        Canvas { ctx, size in
            let p = cast.progress
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            switch cast.skill.effect {
            case .bite:
                let r = 6 + p * 18
                ctx.fill(
                    Path(ellipseIn: CGRect(x: center.x - r/2, y: center.y - r/2, width: r, height: r)),
                    with: .color(cast.skill.color.opacity(1.0 - p))
                )
            case .slash:
                // Diagonal white slash from top-left to bottom-right
                var path = Path()
                let startX = size.width * 0.15 + p * 6
                let startY = size.height * 0.2
                let endX = size.width * 0.85
                let endY = size.height * 0.75 + p * 6
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
                ctx.stroke(path, with: .color(.white.opacity(1.0 - p)), lineWidth: 4)
                ctx.stroke(path, with: .color(cast.skill.color.opacity(1.0 - p)), lineWidth: 1.5)
            case .pounce:
                // motion lines behind the pet
                for i in 0..<4 {
                    var path = Path()
                    let y = size.height * (0.25 + Double(i) * 0.15)
                    path.move(to: CGPoint(x: size.width * 0.1 - p * 20, y: y))
                    path.addLine(to: CGPoint(x: size.width * 0.45 - p * 20, y: y))
                    ctx.stroke(path, with: .color(cast.skill.color.opacity(0.6 * (1.0 - p))), lineWidth: 2)
                }
            case .fireball:
                // Travel orange ball from pet center to the right edge
                let x = center.x + p * (size.width * 0.55)
                let y = center.y - p * 4
                let r: CGFloat = 14
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r/2, y: y - r/2, width: r, height: r)),
                    with: .color(cast.skill.color.opacity(1.0 - p * 0.3))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r/4, y: y - r/4, width: r/2, height: r/2)),
                    with: .color(.yellow.opacity(1.0 - p * 0.3))
                )
            case .spin:
                // Cyan spinning ring
                let angle = p * .pi * 4
                for i in 0..<6 {
                    let a = angle + Double(i) * .pi / 3
                    let r: CGFloat = 28
                    let x = center.x + cos(a) * r
                    let y = center.y + sin(a) * r
                    let dotR: CGFloat = 5
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - dotR/2, y: y - dotR/2, width: dotR, height: dotR)),
                        with: .color(cast.skill.color.opacity(1.0 - p))
                    )
                }
            }
        }
    }
}
