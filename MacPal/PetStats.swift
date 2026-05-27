import Foundation

struct PetStats: Codable, Equatable {
    var level: Int = 1
    var xp: Int = 0
    var hunger: Int = 80
    var happiness: Int = 80

    var xpToNextLevel: Int { 50 + (level - 1) * 25 }

    mutating func decay() {
        hunger = max(0, hunger - 1)
        happiness = max(0, happiness - 1)
    }

    @discardableResult
    mutating func feed() -> FeedResult {
        guard hunger < 100 else { return .full }
        hunger = min(100, hunger + 25)
        happiness = min(100, happiness + 5)
        let leveled = addXP(3)
        return leveled ? .leveledUp : .ate
    }

    @discardableResult
    mutating func play() -> PlayResult {
        let leveled = addXP(2)
        happiness = min(100, happiness + 10)
        return leveled ? .leveledUp : .played
    }

    @discardableResult
    mutating func addXP(_ amount: Int) -> Bool {
        xp += amount
        var leveledUp = false
        while xp >= xpToNextLevel {
            xp -= xpToNextLevel
            level += 1
            leveledUp = true
        }
        return leveledUp
    }
}

enum FeedResult { case ate, leveledUp, full }
enum PlayResult { case played, leveledUp }

extension PetStats {
    static let defaultsKey = "MacPal.stats.v1"

    static func load() -> PetStats {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let stats = try? JSONDecoder().decode(PetStats.self, from: data)
        else {
            return PetStats()
        }
        return stats
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
