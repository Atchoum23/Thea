import Foundation

/// Service for focus forest gamification
public actor FocusForestService: FocusForestServiceProtocol {
    private var forest: FocusForest
    private var currentTree: FocusTree?
    private var longestStreak: Int = 0

    public init() {
        self.forest = FocusForest()
    }

    // MARK: - Tree Management

    public func plantTree(type: FocusTree.TreeType) async throws -> FocusTree {
        guard currentTree == nil else {
            throw CognitiveError.treeAlreadyPlanted
        }

        let tree = FocusTree(
            plantedAt: Date(),
            minutesGrown: 0,
            treeType: type
        )

        currentTree = tree
        return tree
    }

    public func updateTreeGrowth(minutes: Int) async throws {
        guard var tree = currentTree else {
            throw CognitiveError.taskBreakdownFailed("No tree is currently planted")
        }

        let newMinutes = tree.minutesGrown + minutes

        if newMinutes >= tree.treeType.minutesToGrow {
            // Tree is fully grown
            tree = FocusTree(
                id: tree.id,
                plantedAt: tree.plantedAt,
                grownAt: Date(),
                minutesGrown: newMinutes,
                treeType: tree.treeType,
                isDead: false
            )

            forest.trees.append(tree)
            currentTree = nil

            // Update streak
            let currentStreak = forest.currentStreak
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
        } else {
            // Tree is still growing
            tree = FocusTree(
                id: tree.id,
                plantedAt: tree.plantedAt,
                grownAt: tree.grownAt,
                minutesGrown: newMinutes,
                treeType: tree.treeType,
                isDead: tree.isDead
            )

            currentTree = tree
        }
    }

    public func killCurrentTree() async throws {
        guard var tree = currentTree else {
            throw CognitiveError.taskBreakdownFailed("No tree is currently planted")
        }

        tree = FocusTree(
            id: tree.id,
            plantedAt: tree.plantedAt,
            grownAt: nil,
            minutesGrown: tree.minutesGrown,
            treeType: tree.treeType,
            isDead: true
        )

        forest.trees.append(tree)
        currentTree = nil
    }

    public func getForest() async -> FocusForest {
        forest
    }

    public func getForestStats() async -> ForestStats {
        let totalTrees = forest.totalTreesGrown
        let totalMinutes = forest.totalMinutesFocused
        let currentStreak = forest.currentStreak

        // Calculate favorite tree type
        let treeTypeCounts = forest.trees
            .filter(\.isFullyGrown)
            .reduce(into: [FocusTree.TreeType: Int]()) { counts, tree in
                counts[tree.treeType, default: 0] += 1
            }

        let favoriteType = treeTypeCounts.max { $0.value < $1.value }?.key

        return ForestStats(
            totalTrees: totalTrees,
            totalMinutesFocused: totalMinutes,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            favoriteTreeType: favoriteType
        )
    }

    // MARK: - Helper Methods

    public func getCurrentTree() async -> FocusTree? {
        currentTree
    }

    public func getTreesGrownToday() async -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return forest.trees.filter { tree in
            guard let grownAt = tree.grownAt else { return false }
            return calendar.isDate(grownAt, inSameDayAs: today)
        }.count
    }
}
