# Thea UI/UX Implementation Plan

**Created:** January 30, 2026
**Based on:** Research of Claude Desktop, Cursor.app, ChatGPT, and AI chat best practices 2025-2026

---

## Executive Summary

This plan outlines UI/UX improvements for Thea based on research of leading AI assistants. The improvements are prioritized by impact and implementation complexity.

---

## Current State Analysis

### Strengths
- Clean MVVM architecture with SwiftUI
- Working streaming implementation via ChatManager
- Multi-platform support (macOS, iOS, watchOS, tvOS)
- Good separation of concerns (Managers, Views, Components)

### Gaps Identified
1. **No markdown rendering** - Messages display as plain text
2. **No code syntax highlighting** - Code blocks lack formatting
3. **No rich content support** - Images, artifacts not rendered
4. **Basic streaming display** - Just text accumulation, no thinking indicators
5. **No conversation branching** - Can't fork or edit messages
6. **Limited input tools** - No @ mentions, limited attachment options
7. **No task/plan visualization** - Multi-step operations not shown

---

## Implementation Phases

### Phase 1: Enhanced Message Rendering (HIGH PRIORITY)
**Estimated effort:** 2-3 days

#### 1.1 Markdown Rendering
- Integrate a SwiftUI markdown renderer (e.g., `swift-markdown-ui`)
- Support: Headers, bold, italic, lists, blockquotes, links
- Handle streaming markdown gracefully (incomplete syntax)

#### 1.2 Code Block Syntax Highlighting
- Use Shiki-style highlighting via native Swift highlighter
- Support 20+ common languages (Swift, Python, JS, etc.)
- Add copy button with accessibility label
- Show language indicator on code blocks

#### 1.3 Message Actions
- Add hover actions: Copy, Regenerate, Edit (user messages only)
- Show "Regenerate" button on assistant messages
- Copy full message or just code blocks

**Files to modify:**
- `Shared/UI/Components/MessageBubble.swift` - Add markdown/code rendering
- Create `Shared/UI/Components/CodeBlockView.swift` - Syntax highlighting
- Create `Shared/UI/Components/MarkdownRenderer.swift` - Markdown parsing

---

### Phase 2: Streaming & Progress Indicators (HIGH PRIORITY)
**Estimated effort:** 1-2 days

#### 2.1 Thinking Indicators
- Show contextual status: "Thinking...", "Searching...", "Planning..."
- Add subtle shimmer animation (like Claude Code)
- Display current tool/action when applicable

#### 2.2 Enhanced Streaming Display
- Show cursor/typing indicator at end of streaming text
- Progressive disclosure for long responses
- Cancel button during generation

#### 2.3 Task Progress Visualization
- For multi-step tasks, show numbered progress
- Expandable/collapsible step details
- Completion checkmarks

**Files to modify:**
- `Shared/UI/Views/ChatView.swift` - Add progress indicators
- `Shared/Core/Managers/ChatManager.swift` - Add status states
- Create `Shared/UI/Components/StreamingIndicator.swift`
- Create `Shared/UI/Components/TaskProgressView.swift`

---

### Phase 3: Input Field Enhancements (MEDIUM PRIORITY)
**Estimated effort:** 2-3 days

#### 3.1 @ Mentions System
- `@file:` - Reference files from projects
- `@web:` - Trigger web search
- Support autocomplete dropdown for mentions

#### 3.2 Attachment Improvements
- Drag-and-drop files into input
- Support images, PDFs, documents
- Show attachment previews/chips

#### 3.3 Input Field Polish
- Auto-expanding multi-line input (1-10 lines)
- Better keyboard shortcuts (Cmd+Enter to send)
- Voice input button (use existing iOS/macOS speech recognition)

**Files to modify:**
- `Shared/UI/Components/ChatInputView.swift` - Add mentions, attachments
- Create `Shared/UI/Components/MentionAutocomplete.swift`
- Create `Shared/UI/Components/AttachmentChip.swift`

---

### Phase 4: Conversation Management (MEDIUM PRIORITY)
**Estimated effort:** 2-3 days

#### 4.1 Conversation Branching
- Edit user messages to create forks
- Show branch indicator/navigation
- Support viewing/switching between branches

#### 4.2 Enhanced Sidebar
- Search within conversations
- Pinned conversations section (already exists)
- Recently used models section
- Better visual hierarchy

#### 4.3 New Conversation Behavior
- New windows open directly to new conversation (per user request)
- **Updated:** Welcome placeholder appears ABOVE the input field (not replacing the chat view)
- Input field always visible at bottom, ready for typing
- Welcome content shows when conversation has no messages
- Quick conversation creation keyboard shortcut
- Template conversations for common tasks

**Files to modify:**
- `Shared/Core/Models/Message.swift` - Add branch support
- `Shared/UI/Views/SidebarView.swift` - Add search, branches
- `macOS/Views/ContentView.swift` - New window behavior
- `macOS/TheamacOSApp.swift` - Window initialization

---

### Phase 5: Artifacts Panel (LOWER PRIORITY)
**Estimated effort:** 3-4 days

#### 5.1 Dual-Panel Layout
- Main chat on left, artifacts on right
- Collapsible/resizable panels
- Auto-show when artifacts are generated

#### 5.2 Artifact Types
- Code with editing capability
- Documents with inline editing
- Visualizations (charts, diagrams)
- Interactive components (if WebView supported)

#### 5.3 Artifact Actions
- Save to file
- Copy to clipboard
- Open in external editor
- Version history

**Files to create:**
- `Shared/UI/Views/ArtifactPanel.swift`
- `Shared/UI/Components/ArtifactCard.swift`
- `Shared/Core/Models/Artifact.swift`

---

### Phase 6: Accessibility (ONGOING)
**Estimated effort:** 1-2 days (initial), ongoing

#### 6.1 Screen Reader Support
- ARIA-equivalent labels on all interactive elements
- Proper focus management
- Announce new messages and streaming updates

#### 6.2 Reduced Motion Support
- Respect `accessibilityReduceMotion` preference
- Replace scale/offset animations with opacity
- Disable shimmer effects when reduced motion enabled

#### 6.3 Color Contrast
- Ensure 4.5:1 contrast ratio for text
- Avoid pure black in dark mode (use #1E1E1E)
- Don't rely on color alone for meaning

**Files to modify:**
- All UI components - Add accessibility modifiers
- Theme/color definitions - Verify contrast

---

## Implementation Order (Optimal)

Based on user request and impact analysis:

```
Week 1:
├── Phase 1.1: Markdown rendering (highest impact)
├── Phase 1.2: Code syntax highlighting
└── Phase 2.1: Thinking indicators

Week 2:
├── Phase 2.2: Enhanced streaming display
├── Phase 4.3: New conversation behavior (user requested)
├── Phase 1.3: Message actions
└── Phase 3.2: Attachment improvements

Week 3:
├── Phase 4.1: Conversation branching
├── Phase 3.1: @ Mentions system
└── Phase 4.2: Enhanced sidebar

Week 4:
├── Phase 5: Artifacts panel (if time permits)
└── Phase 6: Accessibility audit
```

---

## Technical Decisions

### Markdown Rendering
**Recommended:** Use `swift-markdown-ui` or `MarkdownKit`
- Both support streaming updates
- Customizable styling
- SwiftUI native

### Syntax Highlighting
**Recommended:** Build custom using `Splash` or `Highlightr`
- Splash is Swift-native, lightweight
- Highlightr uses highlight.js themes (more languages)
- Include 10-15 themes (dracula, github-dark, monokai, nord, etc.)

### Conversation Branching Data Model
```swift
// Add to Message model
var parentMessageId: UUID? // For branching
var branchIndex: Int = 0   // Which branch (0 = main)
var isEdited: Bool = false // Was this message edited

// Add computed property
var hasBranches: Bool {
    // Query for sibling messages with same parent
}
```

### Streaming Status States
```swift
enum StreamingStatus: Equatable {
    case idle
    case thinking
    case searching(query: String)
    case generating
    case usingTool(name: String)
    case complete
    case error(String)
}
```

---

## Dependencies to Add

```swift
// Package.swift additions
.package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
.package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
```

---

## Key UI Patterns from Research

### From Claude Desktop
- Dual-panel: chat left, artifacts right
- Quick Entry via double-tap Option key
- Files created appear in Artifacts pane
- MCP integration for external services

### From Cursor.app
- Plan Mode: separate planning from execution
- Aggregated diff view for multi-file changes
- Checkpoint/rollback UI for safety
- Tiered autonomy (manual/agent/YOLO)

### From ChatGPT
- Dedicated spaces for specialized contexts (Health)
- Canvas for side-by-side document editing
- Memory with two tiers (explicit vs inferred)
- Project folders with custom instructions

### Best Practices
- Conversation branching like version control
- Copy button on code blocks (accessibility required)
- Respect Reduce Motion preference
- Stream markdown gracefully

---

## Success Metrics

1. **Message rendering** - All markdown renders correctly including during streaming
2. **Code blocks** - Syntax highlighted with working copy button
3. **Streaming** - Shows current status, no flickering, cancel works
4. **Branching** - Can edit messages and create/navigate forks
5. **Accessibility** - Passes basic VoiceOver testing
6. **New window** - Opens directly to new conversation

---

## Notes

- Keep changes incremental and testable
- Run QA phases after each major change
- Document any new patterns in CLAUDE.md
- Ensure all 4 platform schemes still build

---

*Last Updated: January 30, 2026*
