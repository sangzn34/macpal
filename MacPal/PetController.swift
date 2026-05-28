import AppKit
import Observation

@MainActor
@Observable
final class PetController {
    static let baselineTickInterval: TimeInterval = 1.0 / 30.0
    static let activeTickInterval: TimeInterval = 1.0 / 20.0
    static let relaxedTickInterval: TimeInterval = 0.25
    static let idleSecondsBeforeSleep: TimeInterval = 30
    static let decayInterval: TimeInterval = 30
    static let monsterSpawnIntervalRange: ClosedRange<Double> = 60...120
    static let combatTickSeconds: TimeInterval = 1.0
    static let combatRangePx: CGFloat = 80

    private(set) var state: PetState = .idle
    var speed: PetSpeed = .medium
    var displaySize: PetDisplaySize = PetDisplaySize(
        rawValue: UserDefaults.standard.string(forKey: "MacPal.displaySize") ?? ""
    ) ?? .medium {
        didSet {
            UserDefaults.standard.set(displaySize.rawValue, forKey: "MacPal.displaySize")
            resizePetWindow(from: oldValue.size)
        }
    }
    var petSize: NSSize { NSSize(width: displaySize.size.width, height: displaySize.size.height) }
    var character: PixelCharacter = PetCharacters.character(
        withId: UserDefaults.standard.string(forKey: "MacPal.character") ?? "cat"
    ) {
        didSet { UserDefaults.standard.set(character.id, forKey: "MacPal.character") }
    }
    var stats: PetStats = PetStats.load()
    var levelUpFlashTrigger: Int = 0
    var lastDamageDealt: (amount: Int, at: Date)?
    var lastDamageTaken: (amount: Int, at: Date)?
    var activeSkillCast: ActiveSkillCast?
    private(set) var monster: Monster?
    private(set) var monsterOriginX: CGFloat?
    private var skillCooldowns: [String: Date] = [:]
    var isSleeping: Bool { state == .sleeping }
    var isInCombat: Bool {
        if case .fighting = state { return true }
        if case .approachingEnemy = state { return true }
        return false
    }
    var monsterDidSpawn: ((Monster, NSPoint) -> Void)?
    var monsterDidDespawn: ((UUID) -> Void)?

    private weak var window: NSWindow?
    private var timer: Timer?
    private var currentTickInterval: TimeInterval?
    private var movementScale: CGFloat {
        CGFloat((currentTickInterval ?? Self.baselineTickInterval) / Self.baselineTickInterval)
    }
    private var decayTimer: Timer?
    private var monsterSpawnTimer: Timer?
    private var combatTimer: Timer?
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
        let petCenterX = window.frame.origin.x + petSize.width / 2
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
        scheduleTickTimer(interval: tickInterval(for: state))
        scheduleNextBehavior(in: 2...5)

        decayTimer?.invalidate()
        let decay = Timer(timeInterval: Self.decayInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stats.decay()
                self.stats.save()
            }
        }
        decay.tolerance = Self.decayInterval * 0.2
        RunLoop.main.add(decay, forMode: .common)
        self.decayTimer = decay

        scheduleNextMonsterSpawn()
    }

    private func scheduleTickTimer(interval: TimeInterval) {
        guard currentTickInterval != interval else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        currentTickInterval = interval
    }

    private func tickInterval(for state: PetState) -> TimeInterval {
        switch state {
        case .walking, .walkingHome, .approachingEnemy:
            return Self.activeTickInterval
        case .idle, .fighting, .sleeping, .happy, .dragged:
            return Self.relaxedTickInterval
        }
    }

    // MARK: - Monsters

    var petAttack: Int { 4 + stats.level * 2 }

    private func scheduleNextMonsterSpawn() {
        monsterSpawnTimer?.invalidate()
        let delay = Double.random(in: Self.monsterSpawnIntervalRange)
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.spawnMonsterIfPossible()
            }
        }
        t.tolerance = min(delay * 0.1, 10)
        RunLoop.main.add(t, forMode: .common)
        monsterSpawnTimer = t
    }

    func spawnMonsterIfPossible() {
        defer { scheduleNextMonsterSpawn() }
        guard monster == nil else { return }
        guard !sleepLockedByUser else { return }
        spawnMonsterNow()
    }

    func spawnMonsterNow() {
        guard monster == nil else { return }
        let kind = MonsterKind.allCases.randomElement()!
        let m = Monster(kind: kind)
        monster = m

        guard let screen = NSScreen.main, let window else { return }
        let visible = screen.visibleFrame
        let leftSide = Bool.random()
        let x: CGFloat = leftSide
            ? visible.minX + 30
            : visible.maxX - MonsterWindow.size.width - 30
        let origin = NSPoint(x: x, y: window.frame.origin.y)
        monsterOriginX = origin.x
        monsterDidSpawn?(m, origin)

        startApproach()
    }

    private func startApproach() {
        guard let window, let mx = monsterCenterX() else { return }
        let petCenterX = window.frame.origin.x + petSize.width / 2
        let direction: WalkDirection = mx < petCenterX ? .left : .right
        transition(to: .approachingEnemy(direction: direction))
        nextBehaviorChange = Date.distantFuture
    }

    private func monsterCenterX() -> CGFloat? {
        guard let x = monsterOriginX else { return nil }
        return x + MonsterWindow.size.width / 2
    }

    private func stepApproach(direction: WalkDirection) {
        guard let window, let mx = monsterCenterX() else {
            endCombat(victory: false)
            return
        }
        let petCenterX = window.frame.origin.x + petSize.width / 2
        let distance = abs(mx - petCenterX)
        if distance <= Self.combatRangePx {
            transition(to: .fighting)
            startCombatLoop()
            return
        }
        let newDir: WalkDirection = mx < petCenterX ? .left : .right
        if newDir != direction {
            transition(to: .approachingEnemy(direction: newDir))
        }
        var origin = window.frame.origin
        origin.x += newDir.sign * speed.pixelsPerTick * 1.5 * movementScale
        window.setFrameOrigin(origin)
    }

    private func startCombatLoop() {
        combatTimer?.invalidate()
        let t = Timer(timeInterval: Self.combatTickSeconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.combatTick()
            }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        combatTimer = t
    }

    private func combatTick() {
        guard let monster else {
            stopCombatLoop()
            return
        }

        let skill = selectSkill()
        let baseDmg = Int.random(in: skill.damage)
        let dmg = max(1, baseDmg + stats.level)
        monster.hp = max(0, monster.hp - dmg)
        monster.hurtFlash &+= 1
        lastDamageDealt = (dmg, .now)
        skillCooldowns[skill.id] = .now.addingTimeInterval(skill.cooldown)
        activeSkillCast = ActiveSkillCast(skill: skill, startedAt: .now)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(skill.castDuration * 1_000_000_000))
            guard let self else { return }
            if self.activeSkillCast?.skill.id == skill.id {
                self.activeSkillCast = nil
            }
        }

        if monster.isDead {
            endCombat(victory: true)
            return
        }

        // Monster attacks back: small happiness/hunger drain
        let bite = max(1, monster.kind.attack + Int.random(in: -1...1))
        lastDamageTaken = (bite, .now)
        stats.happiness = max(0, stats.happiness - bite)
        stats.hunger = max(0, stats.hunger - max(1, bite / 2))
        stats.save()
    }

    /// Pick best ready skill. Prefer highest-damage skill that's off cooldown.
    private func selectSkill() -> PetSkill {
        let unlocked = PetSkills.unlocked(at: stats.level)
        let ready = unlocked.filter { skill in
            guard let until = skillCooldowns[skill.id] else { return true }
            return Date.now >= until
        }
        // Prefer highest expected damage among ready skills
        let best = ready.max(by: { lhs, rhs in
            (lhs.damage.upperBound + lhs.damage.lowerBound) <
            (rhs.damage.upperBound + rhs.damage.lowerBound)
        })
        return best ?? PetSkills.bite
    }

    private func endCombat(victory: Bool) {
        stopCombatLoop()
        if let m = monster {
            if victory {
                let leveled = stats.addXP(m.kind.xpReward)
                stats.save()
                if leveled { levelUpFlashTrigger &+= 1 }
            }
            monsterDidDespawn?(m.id)
        }
        monster = nil
        monsterOriginX = nil

        if victory {
            triggerHappy(duration: 1.0)
        } else {
            transition(to: .idle)
            scheduleNextBehavior(in: 2...4)
        }
    }

    private func stopCombatLoop() {
        combatTimer?.invalidate()
        combatTimer = nil
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
        let origin = Self.initialOrigin(for: petSize)
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
        if monster != nil {
            startApproach()
            return
        }
        _ = play()
    }

    func beginDrag() {
        stopCombatLoop()
        activeSkillCast = nil
        transition(to: .dragged)
    }

    func didDrag(to _: NSPoint) {}

    private func resizePetWindow(from previousSize: CGSize) {
        guard let window else { return }
        let oldFrame = window.frame
        let newSize = petSize
        let centerX = oldFrame.midX
        let bottomY = oldFrame.minY
        let newOrigin = NSPoint(
            x: centerX - newSize.width / 2,
            y: bottomY + (previousSize.height - newSize.height) / 2
        )
        window.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    func endDrag() {
        if monster != nil {
            startApproach()
        } else {
            transition(to: .idle)
            scheduleNextBehavior(in: 1...3)
        }
    }

    private func tick() {
        switch state {
        case .walking(let direction):
            stepWalk(direction: direction)
        case .walkingHome(let direction):
            stepWalkHome(direction: direction)
        case .approachingEnemy(let direction):
            stepApproach(direction: direction)
        case .fighting:
            break
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
        let petCenterX = window.frame.origin.x + petSize.width / 2
        let distance = abs(targetX - petCenterX)

        if distance < speed.pixelsPerTick * movementScale + 1 {
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
        origin.x += newDirection.sign * speed.pixelsPerTick * movementScale
        window.setFrameOrigin(origin)
    }

    private func stepWalk(direction: WalkDirection) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var origin = window.frame.origin
        origin.x += direction.sign * speed.pixelsPerTick * movementScale

        if origin.x <= visible.minX {
            origin.x = visible.minX
            transition(to: .walking(direction: .right))
        } else if origin.x + petSize.width >= visible.maxX {
            origin.x = visible.maxX - petSize.width
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
        scheduleTickTimer(interval: tickInterval(for: newState))
    }
}
