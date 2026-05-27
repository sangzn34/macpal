import AppKit
import Observation

@MainActor
@Observable
final class PetController {
    static let petSize = NSSize(width: 96, height: 96)
    static let tickInterval: TimeInterval = 1.0 / 30.0
    static let idleSecondsBeforeSleep: TimeInterval = 30
    static let decayInterval: TimeInterval = 30

    private(set) var state: PetState = .idle
    var speed: PetSpeed = .medium
    var character: PixelCharacter = PetCharacters.character(
        withId: UserDefaults.standard.string(forKey: "MacPal.character") ?? "cat"
    ) {
        didSet { UserDefaults.standard.set(character.id, forKey: "MacPal.character") }
    }
    var stats: PetStats = PetStats.load()
    var levelUpFlashTrigger: Int = 0
    var isSleeping: Bool { state == .sleeping }

    private weak var window: NSWindow?
    private var timer: Timer?
    private var decayTimer: Timer?
    private var lastStateChange: Date = .now
    private var nextBehaviorChange: Date = .now
    private var sleepLockedByUser = false
    private var homeOrigin: NSPoint?
    var openStatusPanel: (() -> Void)?

    func bind(window: NSWindow) {
        self.window = window
    }

    func houseDidMove(_ origin: NSPoint) {
        homeOrigin = origin
    }

    func houseDidTap() {
        openStatusPanel?()
    }

    func goHome() {
        guard let homeOrigin, let window else { return }
        let petCenterX = window.frame.origin.x + Self.petSize.width / 2
        let targetX = homeOrigin.x + PetHouse.doorCenterOffset.x
        let direction: WalkDirection = targetX < petCenterX ? .left : .right
        transition(to: .walkingHome(direction: direction))
        nextBehaviorChange = Date.distantFuture
    }

    private var houseDoorScreenX: CGFloat? {
        guard let homeOrigin else { return nil }
        return homeOrigin.x + PetHouse.doorCenterOffset.x
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

        decayTimer?.invalidate()
        let decay = Timer(timeInterval: Self.decayInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stats.decay()
                self.stats.save()
            }
        }
        RunLoop.main.add(decay, forMode: .common)
        self.decayTimer = decay
    }

    func feed() -> FeedResult {
        let result = stats.feed()
        stats.save()
        switch result {
        case .ate:
            triggerHappy(duration: 0.8)
        case .leveledUp:
            triggerLevelUp()
        case .full:
            break
        }
        return result
    }

    func play() -> PlayResult {
        let result = stats.play()
        stats.save()
        switch result {
        case .played:
            triggerHappy(duration: 0.6)
        case .leveledUp:
            triggerLevelUp()
        }
        return result
    }

    private func triggerHappy(duration: TimeInterval) {
        guard !sleepLockedByUser else { return }
        transition(to: .happy)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self else { return }
            if self.state == .happy {
                self.transition(to: .idle)
                self.scheduleNextBehavior(in: 1...3)
            }
        }
    }

    private func triggerLevelUp() {
        levelUpFlashTrigger &+= 1
        triggerHappy(duration: 1.5)
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
        _ = play()
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
        case .walkingHome(let direction):
            stepWalkHome(direction: direction)
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

    private func stepWalkHome(direction: WalkDirection) {
        guard let window, let targetX = houseDoorScreenX else {
            transition(to: .idle)
            scheduleNextBehavior(in: 2...5)
            return
        }
        let petCenterX = window.frame.origin.x + Self.petSize.width / 2
        let distance = abs(targetX - petCenterX)

        if distance < speed.pixelsPerTick + 1 {
            // arrived — sit/sleep at home, restore happiness slowly via decay-pass
            transition(to: .sleeping)
            stats.happiness = min(100, stats.happiness + 15)
            stats.save()
            scheduleNextBehavior(in: 4...8)
            return
        }

        let newDirection: WalkDirection = targetX < petCenterX ? .left : .right
        if newDirection != direction {
            transition(to: .walkingHome(direction: newDirection))
        }
        var origin = window.frame.origin
        origin.x += newDirection.sign * speed.pixelsPerTick
        window.setFrameOrigin(origin)
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
        let homeUrge = shouldGoHome()
        if homeUrge {
            goHome()
            return
        }
        if Bool.random() {
            let direction: WalkDirection = Bool.random() ? .left : .right
            transition(to: .walking(direction: direction))
            scheduleNextBehavior(in: 3...7)
        } else {
            scheduleNextBehavior(in: 2...5)
        }
    }

    private func shouldGoHome() -> Bool {
        guard homeOrigin != nil else { return false }
        // Higher chance when hunger or happiness low; 15% baseline otherwise.
        if stats.hunger < 25 || stats.happiness < 25 { return Double.random(in: 0...1) < 0.6 }
        if stats.hunger < 50 || stats.happiness < 50 { return Double.random(in: 0...1) < 0.30 }
        return Double.random(in: 0...1) < 0.15
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
