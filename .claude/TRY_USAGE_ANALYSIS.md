# Try? Usage Analysis - Thea Codebase

## Summary
- **Total occurrences**: 1807
- **Source files**: ~400 files
- **Tests excluded**: Focus on source code only

## Top 20 Files (Most Critical)

| File | Count | Category | Priority |
|------|-------|----------|----------|
| AppConfiguration.swift | 35 | Configuration | HIGH |
| MCPServerManager.swift | 21 | Integrations | HIGH |
| SecurityScanner.swift | 19 | Security | HIGH |
| TheaPrintFriendly.swift | 17 | Extensions | MEDIUM |
| FinderSync.swift | 17 | Extensions | MEDIUM |
| NotificationPreferences.swift | 16 | System | MEDIUM |
| ActivityLogger.swift | 15 | Monitoring | MEDIUM |
| SystemCleaner.swift | 13 | System | MEDIUM |
| SafariWebExtensionHandler.swift | 13 | Extensions | MEDIUM |
| PhysicalMailChannel.swift | 12 | Messaging | LOW |
| EventStore.swift | 12 | Core | MEDIUM |
| ConversationMemory.swift | 12 | AI | MEDIUM |
| CallDirectoryHandler.swift | 12 | Extensions | LOW |
| PIISanitizer.swift | 11 | Privacy | HIGH |
| FocusOrchestrator.swift | 11 | Features | MEDIUM |
| ShareViewController.swift | 11 | Extensions | LOW |
| BackupManager.swift | 10 | Backup | MEDIUM |
| SafariExtensionActions.swift | 10 | Extensions | LOW |
| IntentHandler.swift | 10 | Extensions | LOW |
| TheamacOSApp.swift | 9 | App | HIGH |

## Recommended Order

### Phase 1: Critical Security/Config (HIGH priority) - 95 occurrences
1. AppConfiguration.swift (35)
2. MCPServerManager.swift (21)
3. SecurityScanner.swift (19)
4. PIISanitizer.swift (11)
5. TheamacOSApp.swift (9)

### Phase 2: Core Systems (MEDIUM priority) - 89 occurrences
6. NotificationPreferences.swift (16)
7. ActivityLogger.swift (15)
8. SystemCleaner.swift (13)
9. EventStore.swift (12)
10. ConversationMemory.swift (12)
11. FocusOrchestrator.swift (11)
12. BackupManager.swift (10)

### Phase 3: Extensions (LOW-MEDIUM priority) - ~100 occurrences
13. TheaPrintFriendly.swift (17)
14. FinderSync.swift (17)
15. SafariWebExtensionHandler.swift (13)
16. Remaining extensions

### Phase 4: Remaining Files - ~1523 occurrences
17. All other files with <9 occurrences

## Categories by Type

- **Security/Privacy**: 30 occurrences (HIGH)
- **Configuration**: 35 occurrences (HIGH)
- **Integrations**: 21 occurrences (HIGH)
- **Core Systems**: 75 occurrences (MEDIUM)
- **Extensions**: ~100 occurrences (MEDIUM-LOW)
- **Features**: ~150 occurrences (MEDIUM)
- **Other**: ~1600 occurrences (LOW)

## Estimated Effort
- **Total**: 1807 replacements
- **Per file average**: 4.5 occurrences
- **Phase 1 time**: 2-3 hours (95 occurrences)
- **Phase 2 time**: 2-3 hours (89 occurrences)
- **Total estimated time**: 10-15 hours of systematic work
- **Automation potential**: Medium (pattern-based replacements possible)

## Replacement Strategy

### Pattern 1: Simple Property Access
```swift
// Before
let value = try? decoder.decode(Type.self, from: data)

// After
do {
    let value = try decoder.decode(Type.self, from: data)
    // use value
} catch {
    logger.error("Failed to decode: \(error)")
    // proper fallback
}
```

### Pattern 2: Optional Chaining
```swift
// Before
_ = try? fileManager.removeItem(at: url)

// After
do {
    try fileManager.removeItem(at: url)
} catch {
    logger.error("Failed to remove item at \(url): \(error)")
}
```

### Pattern 3: Guard Statements
```swift
// Before
guard let data = try? Data(contentsOf: url) else { return }

// After
let data: Data
do {
    data = try Data(contentsOf: url)
} catch {
    logger.error("Failed to load data from \(url): \(error)")
    return
}
```

## Next Steps
1. Start with Phase 1 (HIGH priority files)
2. Test after each file modification
3. Commit after each file or small group
4. Move to Phase 2, then 3, then 4
5. Consider automation for Phase 4 (simple patterns)
