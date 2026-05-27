import SwiftUI

struct HouseView: View {
    @Bindable var controller: PetController
    @State private var feedFlash = false
    @State private var playFlash = false
    @State private var fullMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            roomScene
                .frame(height: 160)

            Divider()

            actions
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        let stats = controller.stats
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(controller.character.name)
                    .font(.title2.bold())
                Spacer()
                Text("Lvl \(stats.level)")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }

            StatBar(
                label: "XP",
                value: stats.xp,
                max: stats.xpToNextLevel,
                tint: .accentColor,
                icon: "star.fill"
            )
            StatBar(
                label: "Hunger",
                value: stats.hunger,
                max: 100,
                tint: hungerTint(stats.hunger),
                icon: "fork.knife"
            )
            StatBar(
                label: "Happiness",
                value: stats.happiness,
                max: 100,
                tint: .pink,
                icon: "heart.fill"
            )
        }
    }

    private var roomScene: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.88, blue: 0.78),
                         Color(red: 0.85, green: 0.74, blue: 0.62)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Wood floor band
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.38, blue: 0.22),
                             Color(red: 0.40, green: 0.25, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(height: 40)
                .frame(maxHeight: .infinity, alignment: .bottom)

            HStack(spacing: 24) {
                PixelSpriteView(sprite: PixelSprite([
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........YYYY............",
                    ".......YYOOYY...........",
                    "......YOOYYOOY..........",
                    ".....YOYYYYYYOY.........",
                    ".....YOOYYYYOOY.........",
                    "...KKKKKKKKKKKKKKK......",
                    "..KBBBBBBBBBBBBBBBK.....",
                    ".KBBBBBBBBBBBBBBBBBK....",
                    ".KbbbbbbbbbbbbbbbbbK....",
                    ".KbbbbbbbbbbbbbbbbbK....",
                    "..KbbbbbbbbbbbbbbbK.....",
                    "...KKbbbbbbbbbbbKK......",
                    ".....KKKKKKKKKKKK.......",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................"
                ]), size: 80)
                .scaleEffect(feedFlash ? 1.15 : 1)
                .animation(.spring(duration: 0.3), value: feedFlash)

                PixelSpriteView(
                    sprite: controller.character.sprite(
                        for: controller.state,
                        walkToggle: false
                    ),
                    size: 96
                )

                PixelSpriteView(sprite: PixelSprite([
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........KKKKKK..........",
                    ".......KRRRRRRK.........",
                    "......KRRWWWRRRK........",
                    ".....KRRWWWWRRRRK.......",
                    ".....KRWWWRRRRRRK.......",
                    ".....KRRRRRRRRRRK.......",
                    ".....KRRRRRRRRRRK.......",
                    ".....KRRRRRRRRRRK.......",
                    "......KRRRRRRRRK........",
                    ".......KRRRRRRK.........",
                    "........KKKKKK..........",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................",
                    "........................"
                ]), size: 70)
                .scaleEffect(playFlash ? 1.2 : 1)
                .rotationEffect(.degrees(playFlash ? 25 : 0))
                .animation(.spring(duration: 0.3), value: playFlash)
            }
        }
        .clipped()
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    feedAction()
                } label: {
                    Label("Feed (+25 hunger)", systemImage: "fork.knife")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    playAction()
                } label: {
                    Label("Play (+10 happy)", systemImage: "tennisball.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }

            if let msg = fullMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func feedAction() {
        let result = controller.feed()
        switch result {
        case .full:
            fullMessage = "\(controller.character.name) is full."
        case .ate, .leveledUp:
            fullMessage = result == .leveledUp ? "Level up!" : nil
            feedFlash.toggle()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            fullMessage = nil
        }
    }

    private func playAction() {
        let result = controller.play()
        if result == .leveledUp {
            fullMessage = "Level up!"
        }
        playFlash.toggle()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            fullMessage = nil
        }
    }

    private func hungerTint(_ hunger: Int) -> Color {
        if hunger > 60 { return .green }
        if hunger > 30 { return .orange }
        return .red
    }
}

struct StatBar: View {
    let label: String
    let value: Int
    let max: Int
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value) / \(max)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(tint)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(min(value, max)) / CGFloat(max) : 0)
                        .animation(.easeInOut(duration: 0.25), value: value)
                }
            }
            .frame(height: 8)
        }
    }
}

struct PixelSpriteView: View {
    let sprite: PixelSprite
    let size: CGFloat

    var body: some View {
        let pixel = size / CGFloat(PixelSprite.size)
        Canvas { ctx, _ in
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
        }
        .frame(width: size, height: size)
    }
}
