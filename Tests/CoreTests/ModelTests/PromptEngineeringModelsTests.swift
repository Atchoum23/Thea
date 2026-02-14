@testable import TheaModels
import XCTest

/// Tests for PromptEngineering models — templates, preferences, error records,
/// corrections, few-shot examples, and configuration types.
final class PromptEngineeringModelsTests: XCTestCase {

    // MARK: - PromptTemplate

    func testTemplateCreation() {
        let template = PromptTemplate(
            name: "Code Review",
            category: "code",
            templateText: "Review the following code:\n{{INSTRUCTION}}"
        )
        XCTAssertEqual(template.name, "Code Review")
        XCTAssertEqual(template.category, "code")
        XCTAssertTrue(template.templateText.contains("{{INSTRUCTION}}"))
    }

    func testTemplateDefaults() {
        let template = PromptTemplate(name: "T", category: "C", templateText: "Text")
        XCTAssertEqual(template.version, 1)
        XCTAssertEqual(template.successCount, 0)
        XCTAssertEqual(template.failureCount, 0)
        XCTAssertEqual(template.averageConfidence, 0, accuracy: 0.001)
        XCTAssertNil(template.lastUsed)
        XCTAssertTrue(template.isActive)
    }

    func testTemplateSuccessRate() {
        let template = PromptTemplate(
            name: "T", category: "C", templateText: "T",
            successCount: 8, failureCount: 2
        )
        XCTAssertEqual(template.successRate, 0.8, accuracy: 0.001)
    }

    func testTemplateSuccessRateZeroDivision() {
        let template = PromptTemplate(name: "T", category: "C", templateText: "T")
        XCTAssertEqual(template.successRate, 0, "Should handle 0/0 without crash")
    }

    func testTemplateSuccessRatePerfect() {
        let template = PromptTemplate(
            name: "T", category: "C", templateText: "T",
            successCount: 100, failureCount: 0
        )
        XCTAssertEqual(template.successRate, 1.0, accuracy: 0.001)
    }

    func testTemplateVersioning() {
        let template = PromptTemplate(
            name: "T", category: "C", templateText: "T", version: 5
        )
        XCTAssertEqual(template.version, 5)
    }

    func testTemplateActiveState() {
        let template = PromptTemplate(
            name: "T", category: "C", templateText: "T", isActive: false
        )
        XCTAssertFalse(template.isActive)
        template.isActive = true
        XCTAssertTrue(template.isActive)
    }

    func testTemplateUniqueIDs() {
        let t1 = PromptTemplate(name: "T", category: "C", templateText: "T")
        let t2 = PromptTemplate(name: "T", category: "C", templateText: "T")
        XCTAssertNotEqual(t1.id, t2.id)
    }

    // MARK: - UserPromptPreference

    func testPreferenceCreation() {
        let pref = UserPromptPreference(
            category: "style",
            preferenceKey: "verbosity",
            preferenceValue: "concise"
        )
        XCTAssertEqual(pref.category, "style")
        XCTAssertEqual(pref.preferenceKey, "verbosity")
        XCTAssertEqual(pref.preferenceValue, "concise")
    }

    func testPreferenceDefaultConfidence() {
        let pref = UserPromptPreference(
            category: "style",
            preferenceKey: "tone",
            preferenceValue: "professional"
        )
        XCTAssertEqual(pref.confidence, 0.5, accuracy: 0.001)
    }

    func testPreferenceCustomConfidence() {
        let pref = UserPromptPreference(
            category: "code",
            preferenceKey: "language",
            preferenceValue: "swift",
            confidence: 0.95
        )
        XCTAssertEqual(pref.confidence, 0.95, accuracy: 0.001)
    }

    func testPreferenceConfidenceMutation() {
        let pref = UserPromptPreference(
            category: "test",
            preferenceKey: "k",
            preferenceValue: "v"
        )
        pref.confidence = 0.9
        XCTAssertEqual(pref.confidence, 0.9, accuracy: 0.001)
    }

    // MARK: - CodeErrorRecord

    func testErrorRecordCreation() {
        let record = CodeErrorRecord(
            errorMessage: "Type 'Foo' has no member 'bar'",
            errorPattern: "no_member",
            codeContext: "let x = Foo().bar",
            solution: "Use 'baz' instead of 'bar'"
        )
        XCTAssertEqual(record.errorMessage, "Type 'Foo' has no member 'bar'")
        XCTAssertEqual(record.solution, "Use 'baz' instead of 'bar'")
    }

    func testErrorRecordDefaults() {
        let record = CodeErrorRecord(
            errorMessage: "E",
            errorPattern: "P",
            codeContext: "C",
            solution: "S"
        )
        XCTAssertEqual(record.language, "swift")
        XCTAssertEqual(record.occurrenceCount, 1)
        XCTAssertEqual(record.preventionRule, "")
        XCTAssertEqual(record.successRate, 0, accuracy: 0.001)
        XCTAssertTrue(record.relatedErrorIDs.isEmpty)
    }

    func testErrorRecordOccurrenceTracking() {
        let record = CodeErrorRecord(
            errorMessage: "E", errorPattern: "P",
            codeContext: "C", solution: "S",
            occurrenceCount: 15
        )
        XCTAssertEqual(record.occurrenceCount, 15)
        record.occurrenceCount += 1
        XCTAssertEqual(record.occurrenceCount, 16)
    }

    func testErrorRecordRelatedErrors() {
        let id1 = UUID()
        let id2 = UUID()
        let record = CodeErrorRecord(
            errorMessage: "E", errorPattern: "P",
            codeContext: "C", solution: "S",
            relatedErrorIDs: [id1, id2]
        )
        XCTAssertEqual(record.relatedErrorIDs.count, 2)
        XCTAssertTrue(record.relatedErrorIDs.contains(id1))
    }

    func testErrorRecordLanguages() {
        let languages = ["swift", "python", "javascript", "rust"]
        for lang in languages {
            let record = CodeErrorRecord(
                errorMessage: "E", errorPattern: "P",
                codeContext: "C", solution: "S",
                language: lang
            )
            XCTAssertEqual(record.language, lang)
        }
    }

    // MARK: - CodeCorrection

    func testCorrectionCreation() {
        let errorID = UUID()
        let correction = CodeCorrection(
            originalCode: "let x: Int = \"hello\"",
            correctedCode: "let x: String = \"hello\"",
            errorID: errorID,
            modelUsed: "claude-opus-4-6"
        )
        XCTAssertEqual(correction.originalCode, "let x: Int = \"hello\"")
        XCTAssertEqual(correction.correctedCode, "let x: String = \"hello\"")
        XCTAssertEqual(correction.errorID, errorID)
        XCTAssertEqual(correction.modelUsed, "claude-opus-4-6")
    }

    func testCorrectionDefaults() {
        let correction = CodeCorrection(
            originalCode: "O", correctedCode: "C",
            errorID: UUID(), modelUsed: "gpt-4"
        )
        XCTAssertFalse(correction.wasSuccessful)
    }

    func testCorrectionSuccessTracking() {
        let correction = CodeCorrection(
            originalCode: "O", correctedCode: "C",
            errorID: UUID(), wasSuccessful: true,
            modelUsed: "gpt-4"
        )
        XCTAssertTrue(correction.wasSuccessful)
    }

    // MARK: - CodeFewShotExample

    func testFewShotExampleCreation() {
        let example = CodeFewShotExample(
            taskType: "debugging",
            inputExample: "Fix: index out of range",
            outputExample: "guard index < array.count else { return }"
        )
        XCTAssertEqual(example.taskType, "debugging")
        XCTAssertFalse(example.inputExample.isEmpty)
        XCTAssertFalse(example.outputExample.isEmpty)
    }

    func testFewShotExampleDefaults() {
        let example = CodeFewShotExample(
            taskType: "test",
            inputExample: "I",
            outputExample: "O"
        )
        XCTAssertEqual(example.quality, 1.0, accuracy: 0.001)
        XCTAssertEqual(example.usageCount, 0)
    }

    func testFewShotExampleUsageTracking() {
        let example = CodeFewShotExample(
            taskType: "test",
            inputExample: "I",
            outputExample: "O",
            usageCount: 50
        )
        XCTAssertEqual(example.usageCount, 50)
        example.usageCount += 1
        XCTAssertEqual(example.usageCount, 51)
    }

    func testFewShotExampleQualityRange() {
        let low = CodeFewShotExample(taskType: "t", inputExample: "I", outputExample: "O", quality: 0.0)
        let high = CodeFewShotExample(taskType: "t", inputExample: "I", outputExample: "O", quality: 1.0)
        XCTAssertEqual(low.quality, 0.0, accuracy: 0.001)
        XCTAssertEqual(high.quality, 1.0, accuracy: 0.001)
    }

    // MARK: - Cross-Model Unique IDs

    func testAllModelsHaveUniqueIDs() {
        let template = PromptTemplate(name: "T", category: "C", templateText: "X")
        let pref = UserPromptPreference(category: "C", preferenceKey: "K", preferenceValue: "V")
        let error = CodeErrorRecord(errorMessage: "E", errorPattern: "P", codeContext: "C", solution: "S")
        let correction = CodeCorrection(originalCode: "O", correctedCode: "C", errorID: UUID(), modelUsed: "M")
        let example = CodeFewShotExample(taskType: "T", inputExample: "I", outputExample: "O")

        let ids: Set<UUID> = [template.id, pref.id, error.id, correction.id, example.id]
        XCTAssertEqual(ids.count, 5, "All model IDs should be unique")
    }
}
