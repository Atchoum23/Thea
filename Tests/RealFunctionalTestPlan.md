# Real Functional Test Plan for Thea macOS

## Philosophy

**THE DIFFERENCE BETWEEN GOOD AND BAD TESTING:**

### BAD (What we did before):
```
- Check if "Chat" button exists ✅
- Test passes!
```
This only verifies the button EXISTS. It tells us nothing about whether clicking it WORKS.

### GOOD (What we do now):
```
1. Screenshot BEFORE clicking Chat
2. Click Chat
3. Screenshot AFTER clicking Chat
4. VERIFY: Did the content area change?
5. VERIFY: Is "Conversations" title now visible?
6. VERIFY: Is the welcome message or conversation list shown?
7. If ANY verification fails → TEST FAILS
```

---

## Test Execution Protocol

### For EVERY test:
1. **Capture baseline state** (screenshot or element state)
2. **Execute the action** (click, type, shortcut)
3. **Wait for UI to settle** (0.3-1s depending on complexity)
4. **Capture result state** (screenshot or element state)
5. **VERIFY the expected outcome** (not just that something happened, but THE RIGHT thing)
6. **Log pass/fail with evidence**

---

## Core Functional Tests

### L01: App Launches with Correct Structure
**Action:** Launch app
**Verifications:**
- [ ] Main window appears
- [ ] Sidebar shows: Chat, Projects, Knowledge, Financial, Code, Migration
- [ ] Three-column layout is visible
- [ ] No error dialogs
- [ ] No Keychain prompts (NOW, after our fix)

### L04: Settings Opens
**Action:** Press Cmd+,
**Verifications:**
- [ ] Settings window opens
- [ ] ALL 9 tabs are visible: General, AI Providers, Models, Local Models, Orchestrator, Voice, Sync, Privacy, Advanced
- [ ] "You have unsaved changes" is NOT visible initially
- [ ] No Keychain prompt appears

---

### N01: Chat Navigation Works
**Action:** Click "Chat" in sidebar
**Verifications:**
- [ ] Middle column shows "Conversations" title
- [ ] Either shows conversation list OR "Welcome to THEA" placeholder
- [ ] New Conversation button/toolbar item is visible
- [ ] Detail pane shows appropriate content

### N07: Sidebar Toggle Actually Toggles
**Action:** Press Cmd+Ctrl+S
**Verifications:**
- [ ] BEFORE: Sidebar items (Chat, Projects) visible
- [ ] AFTER FIRST TOGGLE: Sidebar items NOT visible or collapsed
- [ ] AFTER SECOND TOGGLE: Sidebar items visible again
- [ ] ONLY ONE toggle button exists (we fixed duplicate)

---

### C01: Create Conversation
**Action:** Press Cmd+Shift+N
**Verifications:**
- [ ] New conversation appears in list
- [ ] Conversation title is "New Conversation"
- [ ] Message input field appears
- [ ] Focus moves to input field
- [ ] Detail pane shows the chat view

### C03: Send Message with Enter Key
**Prerequisites:** Conversation created
**Action:** Type "Hello" then press Return/Enter
**Verifications:**
- [ ] Message appears in chat as user bubble
- [ ] Input field clears
- [ ] NO Keychain prompt appears (we fixed this)
- [ ] If API configured: AI response starts streaming
- [ ] If API not configured: Appropriate error shown

---

### S-G02: Theme Actually Changes
**Action:** Open Settings → General → Change Theme
**Verifications:**
- [ ] Click "Dark": Window appearance darkens
- [ ] Click "Light": Window appearance lightens
- [ ] Click "System": Follows system setting
- [ ] Close settings → Theme persists
- [ ] Restart app → Theme still persisted

### S-G03: Font Size Actually Changes
**Action:** Open Settings → General → Change Font Size
**Verifications:**
- [ ] Click "Small": Text in app becomes smaller
- [ ] Click "Large": Text in app becomes noticeably larger
- [ ] Click "Medium": Text returns to default
- [ ] Change persists after closing settings

### S-X03: Unsaved Changes Indicator
**Action:** Open Settings (don't change anything)
**Verifications:**
- [ ] "You have unsaved changes" NOT visible initially
- [ ] Change any setting
- [ ] "You have unsaved changes" NOW visible
- [ ] Click Cancel → Changes discarded
- [ ] Reopen → Original values restored

---

## Settings Tab-by-Tab Verification

### AI Providers Tab
**Action:** Click "AI Providers" tab
**Verifications:**
- [ ] NO Keychain prompt on tab switch (we fixed lazy loading)
- [ ] Provider picker shows all 6 providers
- [ ] API key fields accept input
- [ ] Checkmark appears when key is entered
- [ ] Stream Responses toggle works

### Models Tab
**Action:** Click "Models" tab
**Verifications:**
- [ ] Tab content loads without error
- [ ] Model pickers show available models
- [ ] Selecting different model works

### Local Models Tab
**Action:** Click "Local Models" tab
**Verifications:**
- [ ] Ollama toggle works
- [ ] Browse button opens file picker
- [ ] Refresh scans for models

### Orchestrator Tab
**Action:** Click "Orchestrator" tab
**Verifications:**
- [ ] Enable toggle works
- [ ] Confidence slider moves and shows value
- [ ] Model preference picker works

### Voice Tab
**Action:** Click "Voice" tab
**Verifications:**
- [ ] Enable Voice toggle works
- [ ] When enabled: wake word field appears
- [ ] Test button is clickable
- [ ] Read Responses toggle works

### Sync Tab
**Action:** Click "Sync" tab
**Verifications:**
- [ ] iCloud toggle works
- [ ] Handoff toggle works
- [ ] Status text displays

### Privacy Tab
**Action:** Click "Privacy" tab
**Verifications:**
- [ ] Analytics toggle works
- [ ] Export button opens save dialog
- [ ] Clear All Data shows confirmation alert
- [ ] Cancel on alert dismisses without clearing

### Advanced Tab
**Action:** Click "Advanced" tab
**Verifications:**
- [ ] Debug Mode toggle works
- [ ] Performance Metrics toggle works
- [ ] Beta Features toggle works
- [ ] Clear Cache button responds

---

## Keyboard Shortcuts Verification

| Shortcut | Action | Verification |
|----------|--------|--------------|
| Cmd+, | Settings | Settings window opens with all tabs |
| Cmd+Shift+N | New Conversation | Conversation appears in list |
| Cmd+Shift+P | New Project | Project appears in list |
| Cmd+Ctrl+S | Toggle Sidebar | Sidebar visually hides/shows |
| Cmd+N | New Window | Second window appears |
| Return | Send Message | Message sent (if text entered) |
| Escape | Cancel/Close | Dialogs close, actions cancel |

---

## Data Persistence Verification

### Conversation Persistence
1. Create conversation
2. Type a message (don't send - just in input)
3. Quit app
4. Relaunch app
5. **Verify:** Conversation still exists in list
6. **Note:** Unsent message may or may not persist (implementation dependent)

### Settings Persistence
1. Change theme to Dark
2. Change font to Large
3. Click OK
4. Quit app
5. Relaunch app
6. Open Settings
7. **Verify:** Theme is Dark, Font is Large

---

## Bug Regression Tests

These tests specifically check for bugs we've already fixed:

### BUG-001: "You have unsaved changes" on Settings open (FIXED)
- Open Settings
- Don't change anything
- **Verify:** No unsaved changes indicator

### BUG-002: Theme/Font settings have no effect (FIXED)
- Change theme to Dark
- Click OK
- **Verify:** App window is now dark themed

### BUG-003: Keychain prompt on Settings open (FIXED - lazy loading)
- Open Settings → General tab
- **Verify:** No Keychain prompt
- Click AI Providers tab
- **Verify:** Keychain prompt appears NOW (expected - loading keys)

### BUG-004: Keychain prompt on first message send (FIXED - early init)
- Launch fresh app
- Create conversation
- Type message
- Press Enter
- **Verify:** No Keychain prompt (already happened at launch)

### BUG-005: Duplicate sidebar toggle buttons (FIXED)
- Look at toolbar area
- **Verify:** Only ONE sidebar toggle button (the native one)

### BUG-006: Enter key not sending message (FIXED)
- Type message in input field
- Press Enter/Return
- **Verify:** Message sends, appears in chat

---

## Test Result Logging Format

```
TEST: [ID] [Name]
DATE: [timestamp]
RESULT: PASS / FAIL
DURATION: [seconds]

STEPS:
1. [action] → [observed result]
2. [action] → [observed result]
...

VERIFICATIONS:
✅ [check that passed]
❌ [check that failed] - Expected: [x], Actual: [y]

SCREENSHOTS:
- before: [path]
- after: [path]
- failure: [path] (if applicable)

NOTES:
[any relevant observations]
```

---

## Certification Criteria

**CERTIFIED** when:
- ✅ 100% of bug regression tests pass
- ✅ 100% of core functional tests pass
- ✅ 95%+ of all tests pass
- ✅ No crashes during test run
- ✅ No data loss
- ✅ All keyboard shortcuts work
- ✅ Settings persist correctly

**CONDITIONAL** when:
- 90-94% tests pass
- Minor issues found that don't block core functionality

**FAILED** when:
- <90% tests pass
- Any core functionality broken
- Any data loss
- Crashes occur
