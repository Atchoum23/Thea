import Foundation

// MARK: - User Directive Preferences System
// Allows users to define persistent behavioral preferences for Meta-AI

public struct UserDirective: Codable, Identifiable, Sendable {
    public let id: UUID
    public var directive: String
    public var isEnabled: Bool
    public var category: DirectiveCategory
    public var createdAt: Date
    public var lastModified: Date
    
    public init(
        id: UUID = UUID(),
        directive: String,
        isEnabled: Bool = true,
        category: DirectiveCategory,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.directive = directive
        self.isEnabled = isEnabled
        self.category = category
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

public enum DirectiveCategory: String, Codable, CaseIterable, Sendable {
    case quality = "Quality Standards"
    case behavior = "Behavior Preferences"
    case communication = "Communication Style"
    case safety = "Safety & Boundaries"
    
    public var icon: String {
        switch self {
        case .quality: return "star.fill"
        case .behavior: return "brain"
        case .communication: return "bubble.left.and.bubble.right"
        case .safety: return "shield.fill"
        }
    }
    
    public var description: String {
        switch self {
        case .quality:
            return "Standards for code quality, completeness, and thoroughness"
        case .behavior:
            return "How the AI should approach tasks and problems"
        case .communication:
            return "Preferred communication and explanation styles"
        case .safety:
            return "Safety guardrails and operational boundaries"
        }
    }
}

// MARK: - User Directives Configuration

@MainActor
@Observable
public final class UserDirectivesConfiguration {
    public static let shared = UserDirectivesConfiguration()
    
    public private(set) var directives: [UserDirective] = []
    
    private let storageKey = "com.thea.user.directives"
    
    private init() {
        loadDirectives()
        
        // Add default directives if none exist
        if directives.isEmpty {
            addDefaultDirectives()
        }
    }
    
    // MARK: - Default Directives
    
    private func addDefaultDirectives() {
        directives = [
            UserDirective(
                directive: "Never cut corners or skip steps",
                category: .quality
            ),
            UserDirective(
                directive: "Always address all parts of prompts completely",
                category: .quality
            ),
            UserDirective(
                directive: "Verify completion before moving on",
                category: .quality
            ),
            UserDirective(
                directive: "Prefer thorough explanations over brevity",
                category: .communication
            ),
            UserDirective(
                directive: "Ask for clarification when requirements are ambiguous",
                category: .behavior
            )
        ]
        
        saveDirectives()
    }
    
    // MARK: - Public API
    
    public func addDirective(_ directive: UserDirective) {
        directives.append(directive)
        saveDirectives()
    }
    
    public func updateDirective(_ directive: UserDirective) {
        if let index = directives.firstIndex(where: { $0.id == directive.id }) {
            var updated = directive
            updated.lastModified = Date()
            directives[index] = updated
            saveDirectives()
        }
    }
    
    public func deleteDirective(id: UUID) {
        directives.removeAll { $0.id == id }
        saveDirectives()
    }
    
    public func toggleDirective(id: UUID) {
        if let index = directives.firstIndex(where: { $0.id == id }) {
            directives[index].isEnabled.toggle()
            directives[index].lastModified = Date()
            saveDirectives()
        }
    }
    
    public func getActiveDirectives() -> [UserDirective] {
        return directives.filter { $0.isEnabled }
    }
    
    public func getDirectives(for category: DirectiveCategory) -> [UserDirective] {
        return directives.filter { $0.category == category }
    }
    
    public func getActiveDirectivesForPrompt() -> String {
        let active = getActiveDirectives()
        guard !active.isEmpty else { return "" }
        
        var prompt = "\n## User Directives (Always Follow)\n"
        
        for category in DirectiveCategory.allCases {
            let categoryDirectives = active.filter { $0.category == category }
            if !categoryDirectives.isEmpty {
                prompt += "\n### \(category.rawValue)\n"
                for directive in categoryDirectives {
                    prompt += "- \(directive.directive)\n"
                }
            }
        }
        
        return prompt
    }
    
    // MARK: - Persistence
    
    private func saveDirectives() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(directives)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save directives: \(error)")
        }
    }
    
    private func loadDirectives() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            directives = try decoder.decode([UserDirective].self, from: data)
        } catch {
            print("Failed to load directives: \(error)")
        }
    }
    
    // MARK: - Import/Export
    
    public func exportDirectives() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(directives)
    }
    
    public func importDirectives(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([UserDirective].self, from: data)
        
        // Add imported directives, avoiding duplicates
        for directive in imported {
            if !directives.contains(where: { $0.directive == directive.directive }) {
                directives.append(directive)
            }
        }
        
        saveDirectives()
    }
    
    public func resetToDefaults() {
        directives = []
        addDefaultDirectives()
    }
}
