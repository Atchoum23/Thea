# Thea UI/UX Implementation Plan

**Created:** January 30, 2026
**Updated:** January 30, 2026
**Based on:** Research of Claude Desktop, Cursor.app, ChatGPT, and AI chat best practices 2025-2026

---

## Executive Summary

This plan outlines UI/UX improvements for Thea based on research of leading AI assistants. The improvements are prioritized by impact and implementation complexity. **Version 2.0** adds comprehensive view-by-view enhancement proposals with platform adaptation strategies.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [View-by-View Enhancement Proposals (macOS)](#view-by-view-enhancement-proposals-macos)
3. [Cross-Platform Adaptation](#cross-platform-adaptation)
4. [Implementation Phases](#implementation-phases)
5. [Technical Decisions](#technical-decisions)
6. [Design System](#design-system)
7. [Success Metrics](#success-metrics)

---

## Current State Analysis

### Strengths
- Clean MVVM architecture with SwiftUI + SwiftData
- Working streaming implementation via ChatManager
- Multi-platform support (macOS, iOS, watchOS, tvOS)
- Good separation of concerns (Managers, Views, Components)
- 80+ views already implemented

### Gaps Identified
1. **No markdown rendering** ✅ Fixed - Messages now use MarkdownUI
2. **No code syntax highlighting** ✅ Fixed - Highlightr integration added
3. **Basic streaming display** ✅ Improved - StreamingIndicator.swift added
4. **No conversation branching** - Can't fork or edit messages
5. **No artifacts panel** - No dual-panel layout for generated content
6. **Limited input tools** - No @ mentions, limited attachment options
7. **No task/plan visualization** - Multi-step operations not shown

---

## View-by-View Enhancement Proposals (macOS)

### 1. ContentView.swift (Main Layout)

**Current:** NavigationSplitView with 3-column layout (sidebar, list, detail)

**Proposed Enhancements (Based on Claude Desktop):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Artifacts panel | None | Add 4th column for artifacts/generated content | High |
| Quick Entry | None | Double-tap Option key to open quick entry from anywhere | High |
| Keyboard navigation | Basic | Full Cmd+K command palette | Medium |
| Window memory | None | Remember window position/size per project | Low |

**Implementation Notes:**
- Use `HSplitView` for resizable artifacts panel
- Register global keyboard shortcut for Quick Entry via NSEvent.addGlobalMonitorForEvents
- Store window state in UserDefaults keyed by project ID

**Suggested Additions:**
- Command palette (Cmd+K) for quick actions like Claude Desktop
- Project switcher in toolbar
- "Focus mode" that hides sidebar/list

---

### 2. macOSChatDetailView (Chat Conversation)

**Current:** Simple message list with input area at bottom

**Proposed Enhancements (Based on Claude Desktop):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Message branching | None | Edit user message → creates branch, navigate between branches | High |
| Extended thinking | Basic indicator | Expandable "Thinking" section showing thought process | High |
| Message actions | Copy only | Copy, Edit, Regenerate, Fork as hover actions | Medium |
| Scroll behavior | Jump to bottom | Smart scroll: auto-follow during streaming, pause on user scroll | Medium |
| Read aloud | None | TTS button on assistant messages | Low |

**Implementation Notes:**
- Add `parentMessageId: UUID?` and `branchIndex: Int` to Message model
- Show branch navigation UI when message has siblings
- Extended thinking requires API support for streaming thought tokens

**Suggested Additions:**
- "Continue" button when response is cut off
- Inline reactions (thumbs up/down for feedback)
- Share conversation button

---

### 3. ChatInputView (Message Input)

**Current:** TextField with model selector and send button

**Proposed Enhancements (Based on Claude Desktop + ChatGPT):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| @ Mentions | None | @file: @web: @project: with autocomplete | High |
| Drag-drop files | Image only | PDF, DOCX, CSV, code files (30MB limit) | High |
| Screenshot capture | macOS only | "Drag to screenshot" like Claude Quick Entry | Medium |
| Voice input toggle | Button | Caps Lock toggle with visual feedback | Medium |
| Slash commands | None | /clear /branch /export etc. | Medium |
| Templates | None | Saved prompt templates | Low |

**Implementation Notes:**
- Parse input for @ triggers, show autocomplete popover
- Use NSFilePromiseReceiver for drag-drop
- Integrate with VoiceActivationManager for voice toggle

**Suggested Additions:**
- Token counter showing context usage
- "Attach from project" quick picker
- Recent files/attachments chip bar

---

### 4. SidebarView (Conversation List)

**Current:** List with pinned/recent sections, search

**Proposed Enhancements (Based on Claude Desktop):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Search across conversations | Title only | Full-text search of message content | High |
| Projects section | Via navigation | Inline project folders in sidebar | Medium |
| Recent models | None | Show which model was used per conversation | Low |
| Conversation preview | None | First few words of last message | Low |

**Implementation Notes:**
- Implement FTS using SwiftData's `.contains()` or add dedicated search index
- Group conversations by project with disclosure triangles

**Suggested Additions:**
- "Today", "Yesterday", "This Week" temporal grouping
- Bulk selection for archive/delete
- Conversation tags/labels

---

### 5. MessageBubble.swift (Message Display)

**Current:** Markdown rendering with code highlighting, hover actions

**Proposed Enhancements:**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Image display | None | Inline image rendering from attachments | High |
| Artifact extraction | None | Detect code blocks → "Open in Artifact Panel" | High |
| File cards | None | Show attached files as inline cards | Medium |
| Thought blocks | None | Collapsible "Thinking" section for extended thinking | Medium |
| Citations | None | Numbered citations with hover preview | Low |

**Implementation Notes:**
- Parse message for `![image](url)` patterns
- Detect ```language blocks and offer extraction
- Use DisclosureGroup for collapsible thought sections

**Suggested Additions:**
- Diff view for code modifications
- Mermaid diagram rendering
- LaTeX math equation support

---

### 6. StreamingIndicator.swift (Progress Display)

**Current:** Thinking/generating states with shimmer animation

**Proposed Enhancements (Based on Claude Desktop):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Thinking timer | None | Show elapsed time during thinking | High |
| Tool usage display | Status text | Show active tool with icon | Medium |
| Cancel with feedback | Stop button | Cancel + show partial response | Medium |
| Multi-step progress | None | Numbered steps for complex tasks | Medium |

**Implementation Notes:**
- Add `startTime: Date` to track elapsed thinking time
- Create `ToolUsageView` component for displaying active tools

**Suggested Additions:**
- Progress percentage for known-length tasks
- Estimated time remaining

---

### 7. MacSettingsView.swift (Settings)

**Current:** 13 tabbed sections with form-based inputs

**Proposed Enhancements (Based on Claude Desktop):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Styles/presets | None | Create custom response styles (Formal, Concise, etc.) | High |
| MCP Extensions | Basic | One-click install from curated gallery | High |
| Personalization | None | "About me" context that persists across chats | Medium |
| Sync indicator | None | Show iCloud sync status in real-time | Low |

**Implementation Notes:**
- Styles stored as JSON with custom instructions
- MCP gallery fetches from central registry
- Personalization stored in UserDefaults with opt-in

**Suggested Additions:**
- Settings search/filter
- "Reset to defaults" per section
- Import/export settings

---

### 8. TerminalView.swift (Terminal Emulator)

**Current:** HSplitView with output, history, windows tabs

**Proposed Enhancements (Based on Cursor.app):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Inline suggestions | None | Ghost text for command completion | High |
| AI command help | None | "Explain this command" button | Medium |
| Session persistence | Manual | Auto-save/restore terminal sessions | Medium |
| Split panes | None | Horizontal/vertical terminal splits | Low |

**Implementation Notes:**
- Use Shell GPT or similar for command suggestions
- Persist session state to UserDefaults

**Suggested Additions:**
- Command history search (Ctrl+R style)
- Clickable file paths
- Error detection with "Fix with AI" button

---

### 9. CoworkView.swift (Agentic Assistant)

**Current:** HSplitView with 5 tabs (Progress, Artifacts, Context, Queue, Skills)

**Proposed Enhancements (Based on Claude Cowork):**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Plan preview | Sheet | Inline plan display with edit capability | High |
| Folder picker | Basic | Recent folders + favorites | Medium |
| Parallel tasks | Queue | Visual task dependency graph | Medium |
| Approval workflow | None | "Approve before executing" toggle | High |

**Implementation Notes:**
- Plan displayed as editable checklist
- Approval gate before destructive operations
- Show task dependencies as mini-DAG

**Suggested Additions:**
- "Rollback to checkpoint" button
- Time estimate per step
- Resource usage monitoring (CPU, disk)

---

### 10. UnifiedDashboardView.swift (Integration Hub)

**Current:** Module sidebar with status indicators

**Proposed Enhancements:**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Quick glance cards | List only | Grid of module summary cards | Medium |
| Health check | None | System-wide integration status | Medium |
| Onboarding flow | None | Guided setup for each module | Low |

**Implementation Notes:**
- Create `ModuleCard` component showing key metrics
- Health check pings each integration service

---

### 11. Health/Financial/Career Dashboard Views

**Current:** Basic placeholder or simple lists

**Proposed Enhancements:**

| Feature | Current | Proposed | Priority |
|---------|---------|----------|----------|
| Charts | None | Swift Charts for trends and metrics | High |
| AI insights | None | AI-generated summaries and recommendations | High |
| Goal tracking | Basic | Visual progress bars with milestones | Medium |
| Export | None | PDF/CSV export of data | Low |

**Implementation Notes:**
- Use Swift Charts for data visualization
- Generate insights via ChatManager.sendMessage with context
- Create reusable `MetricCard` component

---

## Cross-Platform Adaptation

### Design Philosophy

**Shared (100%):**
- Color palette and brand identity
- Typography hierarchy (relative)
- Data models and business logic
- API communication layer

**Platform-Adaptive:**
- Navigation patterns
- Input mechanisms
- Information density
- Gesture interactions

### iOS Adaptation

| macOS Feature | iOS Equivalent |
|---------------|----------------|
| Sidebar | Tab bar + Navigation stack |
| Toolbar actions | Navigation bar buttons |
| Right-click menus | Long-press context menus |
| Keyboard shortcuts | None (remove) |
| Hover actions | Swipe actions |
| Multi-column | Single column with drill-down |
| Artifacts panel | Modal sheet or tab |

**iOS-Specific Additions:**
- Haptic feedback on actions
- Pull-to-refresh on conversation list
- Share sheet integration
- Widget for quick questions
- Siri Shortcuts integration

### watchOS Adaptation

**What to Include:**
- Voice input (primary)
- Last response display (2-3 lines)
- Quick reply suggestions
- Complication for quick access
- Haptic alerts for responses

**What to Exclude:**
- Long conversations
- Code display
- File attachments
- Complex settings
- Multi-step workflows

**watchOS-Specific View:**
```swift
struct TheaWatchView: View {
    var body: some View {
        VStack {
            // Latest AI response (truncated)
            Text(lastResponse)
                .lineLimit(3)

            // Voice input button (prominent)
            Button("Ask THEA") {
                startVoiceInput()
            }
            .font(.headline)

            // Quick suggestions
            ScrollView(.horizontal) {
                HStack {
                    ForEach(suggestions) { suggestion in
                        Button(suggestion.short) { ... }
                    }
                }
            }
        }
    }
}
```

### tvOS Adaptation

**Design for 10-foot Experience:**
- Minimum 40pt font size
- Voice as primary input (Siri Remote)
- Focus-based navigation
- Card-based response display
- Large, clear action buttons

**tvOS-Specific Features:**
- "Hey Siri, ask THEA" integration
- Ambient mode with contextual suggestions
- Media-focused queries (finding content)
- Smart home integration

**What to Exclude:**
- Complex text input
- Code editing
- File management
- Terminal/cowork features

---

## Implementation Phases

### Phase 1: Core Chat Enhancements (Week 1-2)
- [x] Markdown rendering
- [x] Code syntax highlighting
- [x] Streaming indicators
- [x] Welcome placeholder
- [x] Message branching (BranchNavigator.swift, Message model updated)
- [x] Extended thinking UI (ExtendedThinkingView.swift)
- [x] @ mentions system (MentionAutocomplete.swift)

### Phase 2: Input & Navigation (Week 2-3)
- [ ] File drag-drop improvements
- [x] Command palette (Cmd+K) - CommandPalette.swift
- [x] Quick Entry (Option+Option) - QuickEntryWindow.swift
- [ ] Full-text conversation search
- [ ] Keyboard shortcuts guide

### Phase 3: Artifacts Panel (Week 3-4)
- [x] 4th column layout for artifacts (ArtifactPanel.swift)
- [x] Code block extraction (ArtifactExtractor utility)
- [x] Version history in artifacts
- [x] Export/save artifacts

### Phase 4: Advanced Features (Week 4-5)
- [ ] Response styles
- [ ] MCP Extensions gallery
- [ ] Personalization system
- [ ] Plan preview in Cowork

### Phase 5: Cross-Platform Polish (Week 5-6)
- [ ] iOS view adaptation
- [ ] watchOS minimal interface
- [ ] tvOS voice-first design
- [ ] Shared design system components

### Phase 6: Accessibility & QA (Ongoing)
- [ ] VoiceOver full support
- [ ] Reduce Motion compliance
- [ ] High contrast mode
- [ ] Keyboard navigation audit

---

## Design System

### Colors (Semantic)
```swift
extension Color {
    // Primary brand colors
    static let theaPrimary = Color("TheaPrimary")
    static let theaSecondary = Color("TheaSecondary")

    // Message bubbles
    static let userBubble = Color.theaPrimary
    static let assistantBubble = Color(nsColor: .controlBackgroundColor)

    // Status colors
    static let thinking = Color.orange
    static let generating = Color.blue
    static let error = Color.red
    static let success = Color.green
}
```

### Typography
```swift
extension Font {
    static let theaHeadline = Font.headline
    static let theaBody = Font.body
    static let theaCaption = Font.caption
    static let theaCode = Font.system(.body, design: .monospaced)
}
```

### Spacing
```swift
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}
```

### Component Library
- `MessageBubble` - Message display with markdown
- `StreamingIndicator` - Progress feedback
- `CodeBlockView` - Syntax-highlighted code
- `SuggestionChip` - Quick action buttons
- `MetricCard` - Dashboard metric display
- `FileCard` - Attachment preview
- `BranchNavigator` - Conversation branch UI

---

## Technical Decisions

### Markdown Rendering
**Chosen:** `swift-markdown-ui` (MarkdownUI)
- Native SwiftUI
- Customizable themes
- Handles streaming gracefully

### Syntax Highlighting
**Chosen:** `Highlightr` (highlight.js wrapper)
- 180+ languages
- Multiple themes
- Good performance

### Charts
**Recommended:** Swift Charts (Apple native)
- Built into SwiftUI
- Consistent with platform
- Accessible by default

### State Management
**Pattern:** ObservableObject managers with @StateObject
- Already established in codebase
- Works well with SwiftUI
- Testable

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| macOS build | 0 errors, 0 warnings | CI/CD |
| iOS build | 0 errors, 0 warnings | CI/CD |
| Test pass rate | 100% | swift test |
| VoiceOver audit | No issues | Manual testing |
| Message render time | < 100ms | Instruments |
| App launch time | < 2s | Time to first interaction |
| User satisfaction | 4+ stars | App Store reviews |

---

## Notes

- Keep changes incremental and testable
- Run QA phases after each major change
- Document new patterns in CLAUDE.md
- Ensure all 4 platform schemes build
- Commit after each completed phase

---

*Last Updated: January 30, 2026*
*Version: 2.1 - Phase 1-3 components implemented*
