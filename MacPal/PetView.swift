import SwiftUI

struct PetView: View {
    @Bindable var controller: PetController
    @State private var blink = false
    @State private var bobPhase: Double = 0

    var body: some View {
        ZStack {
            body(for: controller.state)
                .frame(width: PetController.petSize.width,
                       height: PetController.petSize.height)
        }
        .frame(width: PetController.petSize.width,
               height: PetController.petSize.height)
        .contentShape(Circle())
        .onAppear { startTicker() }
    }

    @ViewBuilder
    private func body(for state: PetState) -> some View {
        switch state {
        case .idle:
            petBody(scaleX: 1, scaleY: blink ? 0.92 : 1.0, rotation: 0)
        case .walking(let direction):
            petBody(
                scaleX: direction.flipped ? -1 : 1,
                scaleY: CGFloat(1.0 + sin(bobPhase) * 0.04),
                rotation: sin(bobPhase) * 4
            )
        case .sleeping:
            ZStack(alignment: .topTrailing) {
                petBody(scaleX: 1, scaleY: 0.85, rotation: -8)
                Text("z")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                    .offset(x: -6, y: 4)
                    .opacity(0.7 + sin(bobPhase) * 0.3)
            }
        case .happy:
            petBody(
                scaleX: 1,
                scaleY: CGFloat(1 + abs(sin(bobPhase * 3)) * 0.15),
                rotation: sin(bobPhase * 4) * 6
            )
        case .dragged:
            petBody(scaleX: 1, scaleY: 1.05, rotation: 0)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 6)
        }
    }

    private func petBody(scaleX: CGFloat, scaleY: CGFloat, rotation: Double) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.orange, Color.pink.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)

            HStack(spacing: 14) {
                Capsule()
                    .fill(.black.opacity(0.85))
                    .frame(width: 8, height: controller.state == .sleeping || blink ? 2 : 12)
                Capsule()
                    .fill(.black.opacity(0.85))
                    .frame(width: 8, height: controller.state == .sleeping || blink ? 2 : 12)
            }
            .offset(y: -6)

            mouthShape
                .offset(y: 16)

            Triangle()
                .fill(LinearGradient(
                    colors: [Color.orange, Color.pink.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 18, height: 22)
                .offset(x: -22, y: -30)
                .rotationEffect(.degrees(-25))

            Triangle()
                .fill(LinearGradient(
                    colors: [Color.orange, Color.pink.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 18, height: 22)
                .offset(x: 22, y: -30)
                .rotationEffect(.degrees(25))
        }
        .scaleEffect(x: scaleX, y: scaleY)
        .rotationEffect(.degrees(rotation))
        .animation(.easeInOut(duration: 0.15), value: scaleY)
        .animation(.easeInOut(duration: 0.15), value: rotation)
    }

    @ViewBuilder
    private var mouthShape: some View {
        switch controller.state {
        case .happy:
            Arc(startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                .stroke(.black.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 22, height: 14)
        case .sleeping:
            Capsule()
                .fill(.black.opacity(0.7))
                .frame(width: 14, height: 3)
        default:
            Arc(startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                .stroke(.black.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 16, height: 8)
        }
    }

    private func startTicker() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                bobPhase += 0.2
            }
        }
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            MainActor.assumeIsolated {
                withAnimation(.easeInOut(duration: 0.12)) { blink = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation(.easeInOut(duration: 0.12)) { blink = false }
                }
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        return p
    }
}
