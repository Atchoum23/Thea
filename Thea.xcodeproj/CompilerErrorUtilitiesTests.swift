import Testing
@testable import YourAppModuleName

// Replace `YourAppModuleName` with the actual module name if needed.

enum TestHelpers {
    static func makeError(file: String, line: Int, column: Int, message: String, type: XcodeBuildRunner.CompilerError.ErrorType) -> XcodeBuildRunner.CompilerError {
        // If there's no public init available, this test file may need @testable access or to use a factory.
        // Placeholder assumes a memberwise init exists.
        return XcodeBuildRunner.CompilerError(file: file, line: line, column: column, message: message, errorType: type)
    }
}

@Suite("CompilerError Utilities")
struct CompilerErrorUtilitiesTests {
    @Test
    func testDeduplicated() {
        let e1 = TestHelpers.makeError(file: "A.swift", line: 1, column: 1, message: "M", type: .error)
        let e2 = TestHelpers.makeError(file: "A.swift", line: 1, column: 1, message: "M", type: .error)
        let e3 = TestHelpers.makeError(file: "B.swift", line: 2, column: 1, message: "N", type: .warning)
        let dedup = [e1, e2, e3].deduplicated()
        #expect(dedup.count == 2)
    }

    @Test
    func testSortedByLocation() {
        let e1 = TestHelpers.makeError(file: "B.swift", line: 10, column: 1, message: "", type: .error)
        let e2 = TestHelpers.makeError(file: "A.swift", line: 20, column: 1, message: "", type: .error)
        let e3 = TestHelpers.makeError(file: "A.swift", line: 10, column: 2, message: "", type: .error)
        let sorted = [e1, e2, e3].sortedByLocation()
        #expect(sorted.map { $0.file + ":\($0.line):\($0.column)" } == ["A.swift:10:2", "A.swift:20:1", "B.swift:10:1"])
    }

    @Test
    func testSortedByPriorityThenLocation() {
        let e1 = TestHelpers.makeError(file: "B.swift", line: 10, column: 1, message: "", type: .warning)
        let e2 = TestHelpers.makeError(file: "A.swift", line: 20, column: 1, message: "", type: .error)
        let e3 = TestHelpers.makeError(file: "A.swift", line: 10, column: 2, message: "", type: .note)
        let sorted = [e1, e2, e3].sortedByPriorityThenLocation()
        #expect(sorted.first?.errorType == .error)
        #expect(sorted[1].errorType == .warning || sorted[1].errorType == .note)
    }
}
