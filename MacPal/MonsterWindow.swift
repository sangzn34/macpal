import AppKit
import SwiftUI

@MainActor
final class MonsterWindow: NSWindow {
    static let size = NSSize(width: 96, height: 96)
    let monster: Monster

    init(monster: Monster, origin: NSPoint) {
        self.monster = monster
        super.init(
            contentRect: NSRect(origin: origin, size: Self.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct MonsterView: View {
    @Bindable var monster: Monster
    @State private var bob: Double = 0
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            PixelSpriteView(sprite: monster.kind.idle, size: 96)
                .offset(x: shakeOffset, y: CGFloat(sin(bob) * 2))
                .opacity(monster.isDead ? 0 : 1)
                .scaleEffect(monster.isDead ? 0.6 : 1)
                .animation(.easeOut(duration: 0.4), value: monster.isDead)

            VStack(spacing: 2) {
                Text(monster.kind.name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.55)).frame(height: 5)
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 60 * CGFloat(monster.hp) / CGFloat(monster.kind.maxHP), height: 5)
                        .animation(.easeOut(duration: 0.2), value: monster.hp)
                }
                .frame(width: 60)
            }
            .padding(.top, 2)
        }
        .frame(width: 96, height: 96)
        .onAppear { startBob() }
        .onChange(of: monster.hurtFlash) { _, _ in
            triggerShake()
        }
    }

    private func startBob() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                bob += 0.4
            }
        }
    }

    private func triggerShake() {
        withAnimation(.linear(duration: 0.06)) { shakeOffset = -6 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.linear(duration: 0.06)) { shakeOffset = 6 }
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.spring(duration: 0.15)) { shakeOffset = 0 }
        }
    }
}
