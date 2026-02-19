import Foundation

// MARK: - Swift Best Practices Library

// Curated library of Swift 6.0 best practices for code generation

final class SwiftBestPracticesLibrary: Sendable {
    // periphery:ignore - Reserved: SwiftBestPracticesLibrary type reserved for future feature activation
    static let shared = SwiftBestPracticesLibrary()

    private let practices: [SwiftBestPractice]

    private init() {
        practices = Self.createBestPractices()
    }

    // MARK: - Practice Retrieval

    // periphery:ignore - Reserved: getPracticesForContext(_:) instance method — reserved for future feature activation
    func getPracticesForContext(_ code: String) -> [SwiftBestPractice] {
        var relevant: [SwiftBestPractice] = []

        // Concurrency practices
        if code.contains("Task {") || code.contains("async") || code.contains("await") ||
            code.contains("@MainActor") || code.contains("actor")
        {
            relevant.append(contentsOf: getPracticesByCategory(.concurrency))
        }

        // SwiftUI practices
        if code.contains("View") || code.contains("@Observable") || code.contains("@State") {
            relevant.append(contentsOf: getPracticesByCategory(.swiftUI))
        }

        // Protocol practices
        if code.contains("protocol") {
            relevant.append(contentsOf: getPracticesByCategory(.protocols))
        }

        // Error handling
        if code.contains("throw") || code.contains("try") || code.contains("catch") {
            relevant.append(contentsOf: getPracticesByCategory(.errorHandling))
        }

        // Memory management
        if code.contains("weak") || code.contains("unowned") || code.contains("closure") {
            relevant.append(contentsOf: getPracticesByCategory(.memoryManagement))
        }

        // Return all critical practices if no specific context
        if relevant.isEmpty {
            relevant = practices.filter { $0.priority == .critical }
        }

        return Array(Set(relevant)).sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // periphery:ignore - Reserved: getPracticesByCategory(_:) instance method — reserved for future feature activation
    func getPracticesByCategory(_ category: SwiftBestPractice.Category) -> [SwiftBestPractice] {
        practices.filter { $0.category == category }
    }

    // periphery:ignore - Reserved: formatForPrompt(_:) instance method — reserved for future feature activation
    func formatForPrompt(_ practices: [SwiftBestPractice]) -> String {
        guard !practices.isEmpty else { return "" }

        var formatted = "\n📚 SWIFT BEST PRACTICES TO FOLLOW:\n\n"

        for (index, practice) in practices.enumerated() {
            formatted += "\(index + 1). [\(practice.category)] \(practice.pattern)\n"
            formatted += "   ✓ Good: \(practice.goodExample)\n"
            formatted += "   ✗ Bad:  \(practice.badExample)\n\n"
        }

        return formatted
    }

    // periphery:ignore - Reserved: searchPractices(query:) instance method — reserved for future feature activation
    func searchPractices(query: String) -> [SwiftBestPractice] {
        let lowercased = query.lowercased()

        return practices.filter {
            $0.pattern.lowercased().contains(lowercased) ||
                $0.explanation.lowercased().contains(lowercased)
        }
    }

    // MARK: - Best Practices Database

    private static func createBestPractices() -> [SwiftBestPractice] {
        var practices: [SwiftBestPractice] = []
        practices.append(contentsOf: createConcurrencyPractices())
        practices.append(contentsOf: createSwiftUIPractices())
        practices.append(contentsOf: createOptionalPractices())
        practices.append(contentsOf: createProtocolPractices())
        practices.append(contentsOf: createErrorHandlingPractices())
        practices.append(contentsOf: createMemoryManagementPractices())
        practices.append(contentsOf: createGenericsPractices())
        practices.append(contentsOf: createModernSwiftPractices())
        practices.append(contentsOf: createNamingPractices())
        practices.append(contentsOf: createArchitecturePractices())
        practices.append(contentsOf: createPerformancePractices())
        practices.append(contentsOf: createSecurityPractices())
        return practices
    }

    private static func createConcurrencyPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .concurrency, pattern: "Always use @MainActor for UI code",
                explanation: "UI updates must happen on the main thread. Mark view models, SwiftUI views, and UI-related properties with @MainActor.",
                goodExample: "@MainActor class ViewModel: ObservableObject { @Published var data: String }",
                badExample: "class ViewModel: ObservableObject { @Published var data: String }", priority: .critical),
            SwiftBestPractice(
                category: .concurrency, pattern: "Make types Sendable for cross-actor usage",
                explanation: "Types passed across actor boundaries must be Sendable. Use actors, value types, or explicit conformance.",
                goodExample: "struct User: Sendable { let id: UUID; let name: String }",
                badExample: "class User { var id: UUID; var name: String }", priority: .critical),
            SwiftBestPractice(
                category: .concurrency, pattern: "Use async/await instead of completion handlers",
                explanation: "Modern Swift prefers async/await for better readability and error handling.",
                goodExample: "func fetchData() async throws -> Data { try await URLSession.shared.data(from: url).0 }",
                badExample: "func fetchData(completion: @escaping (Result<Data, Error>) -> Void) { }", priority: .recommended),
            SwiftBestPractice(
                category: .concurrency, pattern: "Avoid @unchecked Sendable unless absolutely necessary",
                explanation: "Only use @unchecked Sendable when you've manually verified thread safety.",
                goodExample: "struct SafeWrapper: Sendable { let value: Int }",
                badExample: "class UnsafeWrapper: @unchecked Sendable { var value: Int }", priority: .critical),
            SwiftBestPractice(
                category: .concurrency, pattern: "Use actor for mutable shared state",
                explanation: "Actors provide automatic synchronization for mutable state accessed from multiple contexts.",
                goodExample: "actor DataCache { private var cache: [String: Data] = [:] }",
                badExample: "class DataCache { private var cache: [String: Data] = [:] }", priority: .critical)
        ]
    }

    private static func createSwiftUIPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .swiftUI, pattern: "Use @Observable instead of ObservableObject",
                explanation: "In iOS 17+/macOS 14+, @Observable provides better performance and simpler syntax.",
                goodExample: "@Observable class ViewModel { var count: Int = 0 }",
                badExample: "class ViewModel: ObservableObject { @Published var count: Int = 0 }", priority: .recommended),
            SwiftBestPractice(
                category: .swiftUI, pattern: "Never use @State with @Observable objects",
                explanation: "@Observable objects don't need @State. Use the object directly.",
                goodExample: "var viewModel = ViewModel()",
                badExample: "@State var viewModel = ViewModel()", priority: .critical),
            SwiftBestPractice(
                category: .swiftUI, pattern: "Use @Environment for dependency injection",
                explanation: "Pass dependencies through the environment rather than initializers.",
                goodExample: "@Environment(\\. modelContext) private var modelContext",
                badExample: "init(modelContext: ModelContext) { self.modelContext = modelContext }", priority: .recommended),
            SwiftBestPractice(
                category: .swiftUI, pattern: "Extract complex views into separate components",
                explanation: "Keep view bodies simple by extracting complex sections.",
                goodExample: "var body: some View { VStack { HeaderView(); ContentView() } }",
                badExample: "var body: some View { VStack { /* 100 lines of code */ } }", priority: .recommended)
        ]
    }

    private static func createOptionalPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .optionals, pattern: "Use guard let for early returns",
                explanation: "Guard statements keep the happy path un-indented and make code more readable.",
                goodExample: "guard let user = user else { return }; print(user.name)",
                badExample: "if let user = user { print(user.name) }", priority: .recommended),
            SwiftBestPractice(
                category: .optionals, pattern: "Avoid force unwrapping (!)",
                explanation: "Force unwrapping crashes at runtime. Use optional binding or nil coalescing instead.",
                goodExample: "let value = optional ?? defaultValue",
                badExample: "let value = optional!", priority: .critical),
            SwiftBestPractice(
                category: .optionals, pattern: "Use optional chaining for safe property access",
                explanation: "Optional chaining safely accesses properties without force unwrapping.",
                goodExample: "let count = user?.posts?.count ?? 0",
                badExample: "let count = user!.posts!.count", priority: .recommended)
        ]
    }

    private static func createProtocolPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .protocols, pattern: "Prefer protocol-oriented design",
                explanation: "Protocols with extensions provide flexibility and testability.",
                goodExample: "protocol DataProvider { func fetchData() async throws -> Data }",
                badExample: "class DataProvider { func fetchData() async throws -> Data }", priority: .recommended),
            SwiftBestPractice(
                category: .protocols, pattern: "Use protocol extensions for default implementations",
                explanation: "Provide default behavior in protocol extensions.",
                goodExample: "extension DataProvider { func fetchData() async throws -> Data { /*default*/ } }",
                badExample: "Make every conforming type implement the same boilerplate", priority: .recommended)
        ]
    }

    private static func createErrorHandlingPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .errorHandling, pattern: "Define custom error types",
                explanation: "Custom errors provide better context and error handling.",
                goodExample: "enum NetworkError: Error { case invalidURL, noData, decodingFailed }",
                badExample: "throw NSError(domain: \"Error\", code: -1, userInfo: nil)", priority: .recommended),
            SwiftBestPractice(
                category: .errorHandling, pattern: "Handle errors at appropriate levels",
                explanation: "Don't silently catch and ignore errors. Handle them appropriately.",
                goodExample: "do { try saveData() } catch { logger.error(\"Save failed: \\(error)\") }",
                badExample: "try? saveData()", priority: .recommended),
            SwiftBestPractice(
                category: .errorHandling, pattern: "Use Result type for async operations without async/await",
                explanation: "Result type encapsulates success or failure explicitly.",
                goodExample: "func loadData(completion: @escaping (Result<Data, Error>) -> Void)",
                badExample: "func loadData(completion: @escaping (Data?, Error?) -> Void)", priority: .recommended)
        ]
    }

    private static func createMemoryManagementPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .memoryManagement, pattern: "Use [weak self] in closures to avoid retain cycles",
                explanation: "Prevent memory leaks by using weak references in closures.",
                goodExample: "task = Task { [weak self] in await self?.loadData() }",
                badExample: "task = Task { await self.loadData() }", priority: .critical),
            SwiftBestPractice(
                category: .memoryManagement, pattern: "Understand value vs reference semantics",
                explanation: "Structs are copied, classes are referenced. Choose appropriately.",
                goodExample: "struct ImmutableData { let values: [Int] } // Value type",
                badExample: "class ImmutableData { let values: [Int] } // Should be struct", priority: .recommended)
        ]
    }

    private static func createGenericsPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .generics, pattern: "Use generics to avoid code duplication",
                explanation: "Generic code is reusable and type-safe.",
                goodExample: "func transform<T>(_ value: T, with: (T) -> T) -> T",
                badExample: "func transformInt(_ value: Int, with: (Int) -> Int) -> Int", priority: .recommended),
            SwiftBestPractice(
                category: .generics, pattern: "Constrain generics appropriately",
                explanation: "Add constraints to ensure generic types have required capabilities.",
                goodExample: "func sort<T: Comparable>(_ items: [T]) -> [T]",
                badExample: "func sort<T>(_ items: [T]) -> [T]", priority: .recommended)
        ]
    }

    private static func createModernSwiftPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .modernSwift, pattern: "Use property wrappers for common patterns",
                explanation: "Property wrappers eliminate boilerplate and enforce patterns.",
                goodExample: "@UserDefault(\"key\", defaultValue: 0) var count: Int",
                badExample: "var count: Int { get { UserDefaults.standard.integer(...) } }", priority: .stylistic),
            SwiftBestPractice(
                category: .modernSwift, pattern: "Leverage Swift's type inference",
                explanation: "Don't specify types when they can be inferred clearly.",
                goodExample: "let numbers = [1, 2, 3]",
                badExample: "let numbers: [Int] = [1, 2, 3]", priority: .stylistic),
            SwiftBestPractice(
                category: .modernSwift, pattern: "Use trailing closure syntax",
                explanation: "Trailing closures improve readability for closure arguments.",
                goodExample: "items.map { $0 * 2 }",
                badExample: "items.map({ $0 * 2 })", priority: .stylistic),
            SwiftBestPractice(
                category: .modernSwift, pattern: "Prefer let over var",
                explanation: "Immutability prevents bugs and makes code easier to reason about.",
                goodExample: "let constant = 42",
                badExample: "var constant = 42 // Never modified", priority: .recommended)
        ]
    }

    private static func createNamingPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .naming, pattern: "Use clear, descriptive names",
                explanation: "Names should explain what, not how. Avoid abbreviations.",
                goodExample: "func fetchUserProfile(for userID: UUID) async throws -> UserProfile",
                badExample: "func getUP(id: UUID) async throws -> UP", priority: .critical),
            SwiftBestPractice(
                category: .naming, pattern: "Follow Swift API naming guidelines",
                explanation: "Use verb phrases for functions, nouns for types and properties.",
                goodExample: "func calculateTotalPrice() -> Decimal",
                badExample: "func totalPrice() -> Decimal", priority: .recommended),
            SwiftBestPractice(
                category: .naming, pattern: "Boolean properties should read as assertions",
                explanation: "Use is/has/can prefixes for boolean properties.",
                goodExample: "var isLoading: Bool; var hasData: Bool",
                badExample: "var loading: Bool; var data: Bool", priority: .recommended)
        ]
    }

    private static func createArchitecturePractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .architecture, pattern: "Separate concerns with MVVM or similar patterns",
                explanation: "Keep views, business logic, and data separate.",
                goodExample: "struct ContentView: View { @State var viewModel = ViewModel() }",
                badExample: "All logic, UI, and data access in one massive view", priority: .recommended),
            SwiftBestPractice(
                category: .architecture, pattern: "Use dependency injection",
                explanation: "Pass dependencies explicitly rather than using singletons.",
                goodExample: "init(apiClient: APIClient) { self.apiClient = apiClient }",
                badExample: "let apiClient = APIClient.shared", priority: .recommended)
        ]
    }

    private static func createPerformancePractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .performance, pattern: "Use lazy var for expensive computations",
                explanation: "Defer expensive work until actually needed.",
                goodExample: "lazy var expensiveData: Data = { computeExpensiveData() }()",
                badExample: "var expensiveData: Data = computeExpensiveData()", priority: .recommended),
            SwiftBestPractice(
                category: .performance, pattern: "Avoid creating excessive temporary objects",
                explanation: "Reuse objects and use value types appropriately.",
                goodExample: "let result = items.reduce(0, +)",
                badExample: "var result = 0; for item in items { result += item }", priority: .stylistic)
        ]
    }

    private static func createSecurityPractices() -> [SwiftBestPractice] {
        [
            SwiftBestPractice(
                category: .security, pattern: "Never hardcode secrets or API keys",
                explanation: "Use environment variables, Keychain, or secure configuration.",
                goodExample: "let apiKey = ProcessInfo.processInfo.environment[\"API_KEY\"]",
                badExample: "let apiKey = \"sk_live_1234567890abcdef\"", priority: .critical),
            SwiftBestPractice(
                category: .security, pattern: "Validate and sanitize user input",
                explanation: "Never trust user input. Always validate and sanitize.",
                goodExample: "guard isValidEmail(input) else { throw ValidationError.invalidEmail }",
                badExample: "let email = userInput // Used directly", priority: .critical)
        ]
    }
}

// MARK: - Data Structures

struct SwiftBestPractice: Hashable, Identifiable {
    let id = UUID()
    let category: Category
    let pattern: String
    let explanation: String
    let goodExample: String
    let badExample: String
    // periphery:ignore - Reserved: swiftVersion property reserved for future feature activation
    let swiftVersion: String = "6.0"
    let priority: Priority

    enum Category: String {
        case concurrency = "Concurrency"
        case memoryManagement = "Memory Management"
        case optionals = "Optionals"
        case protocols = "Protocols"
        case swiftUI = "SwiftUI"
        case errorHandling = "Error Handling"
        case generics = "Generics"
        case modernSwift = "Modern Swift"
        case naming = "Naming"
        case architecture = "Architecture"
        case performance = "Performance"
        case security = "Security"
    }

    enum Priority: Int {
        case critical = 3
        case recommended = 2
        case stylistic = 1
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SwiftBestPractice, rhs: SwiftBestPractice) -> Bool {
        lhs.id == rhs.id
    }
}
