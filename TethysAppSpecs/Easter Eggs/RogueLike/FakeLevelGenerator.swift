@testable import Tethys

final class FakeLevelGenerator: LevelGenerator {
    var level: Level? = nil
    var generateCalls: [(number: Int, bounds: CGRect)] = []
    func generate(level number: Int, bounds: CGRect) -> Level {
        generateCalls.append((number, bounds))
        return self.level!
    }
}
