@testable import TheaCore
import XCTest

@MainActor
final class SkillDefinitionTests: XCTestCase {

    // MARK: - Skill Creation Tests

    func testSkillCreation() {
        let skill = SkillDefinition(
            name: "Test Skill",
            description: "A test skill",
            instructions: "Do something useful",
            scope: .workspace,
            triggers: [
                SkillTrigger(type: .keyword, pattern: "test")
            ]
        )

        XCTAssertEqual(skill.name, "Test Skill")
        XCTAssertEqual(skill.description, "A test skill")
        XCTAssertEqual(skill.instructions, "Do something useful")
        XCTAssertEqual(skill.scope, .workspace)
        XCTAssertEqual(skill.triggers.count, 1)
        XCTAssertEqual(skill.id, "test-skill") // Auto-generated from name
    }

    func testSkillWithCustomId() {
        let skill = SkillDefinition(
            id: "custom-id",
            name: "Test Skill",
            description: "A test skill",
            instructions: "Instructions"
        )

        XCTAssertEqual(skill.id, "custom-id")
    }

    // MARK: - Trigger Type Tests

    func testSlashCommandTrigger() {
        let trigger = SkillTrigger(type: .slashCommand, pattern: "review")
        XCTAssertEqual(trigger.type, .slashCommand)
        XCTAssertEqual(trigger.pattern, "review")
    }

    func testKeywordTrigger() {
        let trigger = SkillTrigger(type: .keyword, pattern: "code review")
        XCTAssertEqual(trigger.type, .keyword)
        XCTAssertEqual(trigger.pattern, "code review")
    }

    func testTaskTypeTrigger() {
        let trigger = SkillTrigger(type: .taskType, pattern: "codeGeneration")
        XCTAssertEqual(trigger.type, .taskType)
        XCTAssertEqual(trigger.pattern, "codeGeneration")
    }

    func testFilePatternTrigger() {
        let trigger = SkillTrigger(type: .filePattern, pattern: "*.swift")
        XCTAssertEqual(trigger.type, .filePattern)
        XCTAssertEqual(trigger.pattern, "*.swift")
    }

    func testAlwaysTrigger() {
        let trigger = SkillTrigger(type: .always, pattern: "")
        XCTAssertEqual(trigger.type, .always)
    }

    // MARK: - Skill Registry Tests

    func testSkillRegistrySharedInstance() {
        let registry = SkillRegistry.shared
        XCTAssertNotNil(registry)
        XCTAssertTrue(registry === SkillRegistry.shared) // Same instance
    }

    func testBuiltinSkillsLoaded() async throws {
        let registry = SkillRegistry.shared

        // Built-in skills should be loaded
        let codeReview = registry.skill(forCommand: "review")
        XCTAssertNotNil(codeReview)
        XCTAssertEqual(codeReview?.name, "Code Review")

        let explain = registry.skill(forCommand: "explain")
        XCTAssertNotNil(explain)
        XCTAssertEqual(explain?.name, "Explain Code")

        let test = registry.skill(forCommand: "test")
        XCTAssertNotNil(test)
        XCTAssertEqual(test?.name, "Generate Tests")
    }

    func testRegisterCustomSkill() {
        let registry = SkillRegistry.shared

        let customSkill = SkillDefinition(
            id: "custom-test-skill",
            name: "Custom Test Skill",
            description: "For testing",
            instructions: "Test instructions",
            scope: .global,
            triggers: [SkillTrigger(type: .slashCommand, pattern: "customtest")]
        )

        registry.register(customSkill)

        let retrieved = registry.skill(id: "custom-test-skill")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Custom Test Skill")
    }

    // MARK: - Skill Matching Tests

    func testFindSkillsBySlashCommand() {
        let registry = SkillRegistry.shared

        let matches = registry.findMatchingSkills(for: "/review code")
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.name == "Code Review" })
    }

    func testFindSkillsByKeyword() {
        let registry = SkillRegistry.shared

        let matches = registry.findMatchingSkills(for: "please review code for bugs")
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.name == "Code Review" })
    }

    func testFindSkillsByTaskType() {
        let registry = SkillRegistry.shared

        let matches = registry.findMatchingSkills(for: .codeRefactoring)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.name == "Refactor Code" })
    }

    func testFindSkillsForQuery() {
        let registry = SkillRegistry.shared

        let matches = registry.findMatchingSkills(forQuery: "how does this work")
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.name == "Explain Code" })
    }

    func testNoMatchesForUnrelatedQuery() {
        let registry = SkillRegistry.shared

        let matches = registry.findMatchingSkills(for: "what is the weather today")
        // Should return empty or only always-active skills
        let nonAlwaysSkills = matches.filter { skill in
            !skill.triggers.contains { $0.type == .always }
        }
        XCTAssertTrue(nonAlwaysSkills.isEmpty)
    }

    // MARK: - Usage Tracking Tests

    func testRecordSkillUsage() {
        let registry = SkillRegistry.shared

        let skillId = "code-review"
        let originalSkill = registry.skill(id: skillId)
        let originalCount = originalSkill?.usageCount ?? 0

        registry.recordUsage(skillId: skillId)

        let updatedSkill = registry.skill(id: skillId)
        XCTAssertNotNil(updatedSkill?.lastUsed)
        XCTAssertEqual(updatedSkill?.usageCount, originalCount + 1)
    }

    // MARK: - Skill Resource Tests

    func testSkillResourceCreation() {
        let resource = SkillResource(
            type: .script,
            path: "/path/to/script.sh",
            description: "A helper script"
        )

        XCTAssertEqual(resource.type, .script)
        XCTAssertEqual(resource.path, "/path/to/script.sh")
        XCTAssertEqual(resource.description, "A helper script")
    }

    func testSkillWithResources() {
        let skill = SkillDefinition(
            name: "Skill With Resources",
            description: "Has resources",
            instructions: "Use the resources",
            resources: [
                SkillResource(type: .script, path: "/scripts/run.sh"),
                SkillResource(type: .template, path: "/templates/template.txt"),
                SkillResource(type: .example, path: "/examples/example.swift")
            ]
        )

        XCTAssertEqual(skill.resources.count, 3)
        XCTAssertTrue(skill.resources.contains { $0.type == .script })
        XCTAssertTrue(skill.resources.contains { $0.type == .template })
        XCTAssertTrue(skill.resources.contains { $0.type == .example })
    }

    // MARK: - Scope Tests

    func testSkillScopes() {
        let workspaceSkill = SkillDefinition(
            name: "Workspace Skill",
            description: "Local to workspace",
            instructions: "...",
            scope: .workspace
        )

        let globalSkill = SkillDefinition(
            name: "Global Skill",
            description: "Available everywhere",
            instructions: "...",
            scope: .global
        )

        let builtinSkill = SkillDefinition(
            name: "Builtin Skill",
            description: "Provided by Thea",
            instructions: "...",
            scope: .builtin
        )

        XCTAssertEqual(workspaceSkill.scope, .workspace)
        XCTAssertEqual(globalSkill.scope, .global)
        XCTAssertEqual(builtinSkill.scope, .builtin)
    }
}
