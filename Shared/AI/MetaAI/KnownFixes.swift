import Foundation

// MARK: - Known Swift Fixes
// Pre-populated fixes for common Swift 6 concurrency and compilation errors

public let knownSwiftFixes: [ErrorKnowledgeBase.KnownFix] = [
    // MARK: - Sendable Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot be sent to.*actor-isolated",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Add 'Sendable' conformance to the type to allow it to cross actor boundaries",
        confidence: 0.9
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "non-sendable type.*cannot cross actor boundary",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Make the type conform to Sendable protocol",
        confidence: 0.9
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "type.*does not conform to.*sendable",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Add ': Sendable' to the type declaration",
        confidence: 0.95
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "stored property.*of.*sendable.*references non-sendable",
        category: .sendable,
        fixStrategy: .addSendable,
        fixDescription: "Make the stored property's type Sendable",
        confidence: 0.85
    ),

    // MARK: - MainActor Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "main actor-isolated.*cannot be referenced",
        category: .mainActor,
        fixStrategy: .addMainActor,
        fixDescription: "Add '@MainActor' attribute to the calling context",
        confidence: 0.85
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "call to main actor-isolated.*from non-isolated",
        category: .mainActor,
        fixStrategy: .addMainActor,
        fixDescription: "Mark the function with '@MainActor' or use Task { @MainActor in ... }",
        confidence: 0.8
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "property.*is isolated to.*main actor",
        category: .mainActor,
        fixStrategy: .addMainActor,
        fixDescription: "Access the property from a MainActor-isolated context",
        confidence: 0.85
    ),

    // MARK: - Visibility Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "is inaccessible due to.*protection level",
        category: .visibility,
        fixStrategy: .addPublicModifier,
        fixDescription: "Change the access level to 'public' or 'internal'",
        confidence: 0.95
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "'.*' is not accessible",
        category: .visibility,
        fixStrategy: .addPublicModifier,
        fixDescription: "Increase the access level of the declaration",
        confidence: 0.9
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot be used in.*because.*is private",
        category: .visibility,
        fixStrategy: .addPublicModifier,
        fixDescription: "Make the declaration public or internal",
        confidence: 0.92
    ),

    // MARK: - Type Not Found Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot find type.*in scope",
        category: .typeNotFound,
        fixStrategy: .fixImport,
        fixDescription: "Add the required import statement or check if the type is defined",
        confidence: 0.7
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot find.*in scope",
        category: .typeNotFound,
        fixStrategy: .fixImport,
        fixDescription: "Import the module containing the type or define it",
        confidence: 0.65
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "use of unresolved identifier",
        category: .typeNotFound,
        fixStrategy: .fixImport,
        fixDescription: "Check imports or define the missing identifier",
        confidence: 0.7
    ),

    // MARK: - Missing Import Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "no such module",
        category: .missingImport,
        fixStrategy: .fixImport,
        fixDescription: "Add the module to package dependencies or check the module name",
        confidence: 0.95
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "could not build module",
        category: .missingImport,
        fixStrategy: .fixImport,
        fixDescription: "Ensure the module is correctly configured in Package.swift",
        confidence: 0.8
    ),

    // MARK: - Async/Await Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "'async' call in a function that does not support concurrency",
        category: .asyncAwait,
        fixStrategy: .addAsyncAwait,
        fixDescription: "Mark the function as 'async' and use 'await' when calling",
        confidence: 0.9
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "expression is 'async' but is not marked with 'await'",
        category: .asyncAwait,
        fixStrategy: .addAsyncAwait,
        fixDescription: "Add 'await' before the async call",
        confidence: 0.95
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "cannot call.*async.*from.*non-async",
        category: .asyncAwait,
        fixStrategy: .addAsyncAwait,
        fixDescription: "Make the calling function async or wrap in Task { }",
        confidence: 0.85
    ),

    // MARK: - Initializer Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "missing argument for parameter",
        category: .missingInitializer,
        fixStrategy: .addInitializer,
        fixDescription: "Add the missing parameter to the initializer call",
        confidence: 0.9
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "extra argument.*in call",
        category: .missingInitializer,
        fixStrategy: .addInitializer,
        fixDescription: "Remove the extra argument or update the initializer signature",
        confidence: 0.85
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "argument passed to call that takes no arguments",
        category: .missingInitializer,
        fixStrategy: .addInitializer,
        fixDescription: "Remove arguments or update the initializer to accept them",
        confidence: 0.9
    ),

    // MARK: - Data Concurrency Errors

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "data race",
        category: .dataConcurrency,
        fixStrategy: .addIsolatedAttribute,
        fixDescription: "Use actor isolation or synchronization primitives",
        confidence: 0.75
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "concurrent access to",
        category: .dataConcurrency,
        fixStrategy: .addIsolatedAttribute,
        fixDescription: "Protect shared mutable state with actor or locks",
        confidence: 0.7
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "mutation of captured var.*in concurrently-executing code",
        category: .dataConcurrency,
        fixStrategy: .useTaskDetached,
        fixDescription: "Use Task.detached or move mutation outside concurrent context",
        confidence: 0.75
    ),

    ErrorKnowledgeBase.KnownFix(
        errorPattern: "reference to captured var.*in concurrently-executing code",
        category: .dataConcurrency,
        fixStrategy: .useTaskDetached,
        fixDescription: "Capture value types or use Sendable references",
        confidence: 0.7
    ),

    // MARK: - Generic Fallback

    ErrorKnowledgeBase.KnownFix(
        errorPattern: ".*",
        category: .unknown,
        fixStrategy: .useAIGeneration,
        fixDescription: "Use AI to analyze and generate a fix for this error",
        confidence: 0.5
    )
]
