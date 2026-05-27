import AppKit
import Observation

@MainActor
@Observable
final class PetController {
    static let petSize = NSSize(width: 96, height: 96)
    static let tickInterval: TimeInterval = 1.0 / 30.0
    static let idleSecondsBeforeSleep: TimeInterval = 30

    private(set) var state: PetState = .idle
    var speed: PetSpeed = .medium
    var isSleeping: Bool { state == .sleeping }

    private weak var window: NSWindow?
    private var timer: Timer?
    private var lastStateChange: Date = .now
    private var nextBehaviorChange: Date = .now
    private var sleepLockedByUser = false

    func bind(window: NSWindow) {
        self.window = window
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduleNextBehavior(in: 2...5)
    }

    static func initialOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        return NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 40)
    }

    func resetPosition() {
        guard let window else { return }
        let origin = Self.initialOrigin(for: Self.petSize)
        window.setFrameOrigin(origin)
        transition(to: .idle)
    }

    func toggleSleep() {
        if state == .sleeping {
            sleepLockedByUser = false
            transition(to: .idle)
            scheduleNextBehavior(in: 1...3)
        } else {
            sleepLockedByUser = true
            transition(to: .sleeping)
        }
    }

    func handleClick() {
        guard !sleepLockedByUser else {
            transition(to: .sleeping)
            return
        }
        transition(to: .happy)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self else { return }
            if self.state == .happy {
                self.transition(to: .idle)
                self.scheduleNextBehavior(in: 1...3)
            }
        }
    }

    func beginDrag() {
        transition(to: .dragged)
    }

    func didDrag(to _: NSPoint) {}

    func endDrag() {
        transition(to: .idle)
        scheduleNextBehavior(in: 1...3)
    }

    private func tick() {
        switch state {
        case .walking(let direction):
            stepWalk(direction: direction)
        case .idle:
            if !sleepLockedByUser,
               Date.now.timeIntervalSince(lastStateChange) > Self.idleSecondsBeforeSleep {
                transition(to: .sleeping)
                return
            }
            if Date.now >= nextBehaviorChange {
                pickRandomBehavior()
            }
        case .sleeping, .happy, .dragged:
            break
        }
    }

    private func stepWalk(direction: WalkDirection) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var origin = window.frame.origin
        origin.x += direction.sign * speed.pixelsPerTick

        if origin.x <= visible.minX {
            origin.x = visible.minX
            transition(to: .walking(direction: .right))
        } else if origin.x + Self.petSize.width >= visible.maxX {
            origin.x = visible.maxX - Self.petSize.width
            transition(to: .walking(direction: .left))
        }

        window.setFrameOrigin(origin)

        if Date.now >= nextBehaviorChange {
            transition(to: .idle)
            scheduleNextBehavior(in: 2...5)
        }
    }

    private func pickRandomBehavior() {
        if Bool.random() {
            let direction: WalkDirection = Bool.random() ? .left : .right
            transition(to: .walking(direction: direction))
            scheduleNextBehavior(in: 3...7)
        } else {
            scheduleNextBehavior(in: 2...5)
        }
    }

    private func scheduleNextBehavior(in range: ClosedRange<Double>) {
        let seconds = Double.random(in: range)
        nextBehaviorChange = Date.now.addingTimeInterval(seconds)
    }

    private func transition(to newState: PetState) {
        guard state != newState else { return }
        state = newState
        lastStateChange = .now
    }
}
