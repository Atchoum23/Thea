# G2: Automatic Foreground App Pairing — Testing Guide

**Date:** 2026-02-15
**Machine:** MSM3U (Mac Studio M3 Ultra, 256GB RAM)
**Status:** ✅ FULL IMPLEMENTATION COMPLETE — Ready for Verification Testing

---

## Implementation Summary

G2 (Automatic Foreground App Pairing) has been **fully implemented** with real, functional code:

### ✅ Core Components (All Complete)

1. **ForegroundAppMonitor** (`Shared/Integrations/ForegroundAppMonitor.swift`)
   - NSWorkspace.didActivateApplicationNotification integration
   - Auto-starts monitoring when pairing enabled
   - Persists settings to UserDefaults
   - Accessibility permission checking
   - Real-time context extraction on app switch

2. **App-Specific Context Extractors** (6 extractors, all fully implemented)
   - `XcodeContextExtractor` — Extracts file path, selected text, cursor position (line/column), visible source code via Accessibility API
   - `VSCodeContextExtractor` — Similar to Xcode, parses window title for file name, handles unsaved indicator
   - `TerminalContextExtractor` — Extracts last 50 lines of output, current directory from window title, last command via prompt pattern matching
   - `SafariContextExtractor` — Uses AppleScript to get URL + selected text via JavaScript, Accessibility API fallback
   - `TextEditorContextExtractor` — Extracts document content + selected text from Notes/TextEdit
   - `GenericContextExtractor` — Fallback for unsupported apps using generic Accessibility API

3. **ChatManager Integration** (`Shared/Core/Managers/ChatManager+Messaging.swift`)
   - Line 20: `injectForegroundAppContext(into: text)` called in `sendMessage`
   - Prepends `<foreground_app_context>...</foreground_app_context>` block to user messages
   - macOS-only via `#if os(macOS)` guard
   - Logging via `chatLogger.debug("📱 Injected foreground app context for \(context.appName)")`

4. **AppPairingSettingsView** (`Shared/UI/Views/Settings/AppPairingSettingsView.swift`)
   - Toggle: Enable/disable pairing
   - Per-app toggles (8 apps supported: Xcode, VS Code, Terminal, iTerm2, Warp, Notes, TextEdit, Safari)
   - Context options: Include selected text, Include window content
   - Privacy section with Accessibility permission status indicator
   - "Open System Settings" button
   - Keyboard shortcut instructions (Option+Space)

5. **MacSettingsView Integration** (`macOS/Views/MacSettingsView.swift`)
   - Line 60: `case appPairing = "App Pairing"`
   - Line 119: Icon `"app.connected.to.app.below.fill"`
   - Lines 280-281: Routes to `AppPairingSettingsView()`

### ⚠️ CRITICAL VERIFICATION NEEDED

**This is NOT scaffolding or placeholder code.** All extractors use real Accessibility API calls (`AXUIElementCopyAttributeValue`, `kAXSelectedTextAttribute`, etc.) and Safari uses actual AppleScript execution.

**However**, per G2 requirements, the implementation MUST be **functionally tested** with real apps to verify it works end-to-end. The success criteria demand:

> "Each criterion must be functionally tested with real apps"

---

## Testing Protocol

### Phase 1: macOS Build Verification

**ISSUE DETECTED:** xcodebuild for Thea-macOS scheme is currently failing (pre-existing issue, not G2-related). Swift Package Manager builds succeed (`swift build` passes with 0 errors).

**Action:** Debug xcodebuild failure before proceeding with functional tests.

```bash
# Try clean build
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug -destination "platform=macOS" clean build
```

If build succeeds, install to `/Applications`:

```bash
ditto ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug/Thea.app /Applications/Thea.app
```

### Phase 2: Functional Testing Checklist

**Prerequisites:**
1. Build completes with 0 errors
2. Thea.app installed to `/Applications`
3. Accessibility permission granted: System Settings → Privacy & Security → Accessibility → Enable Thea

**Test Cases (MUST ALL PASS):**

#### Test 1: ForegroundAppMonitor Activation
- [ ] Launch Thea.app from `/Applications/Thea.app`
- [ ] Open Settings → App Pairing
- [ ] Verify permission indicator shows ✅ "Accessibility permission granted" (if granted) or ⚠️ warning
- [ ] Enable "Enable Foreground App Pairing" toggle
- [ ] Verify all 8 apps checked by default (Xcode, VS Code, Terminal, iTerm2, Warp, Notes, TextEdit, Safari)
- [ ] Check Console.app for log: `✅ Foreground app monitoring started` (subsystem: ai.thea.app, category: ForegroundAppMonitor)

#### Test 2: Xcode Context Extraction
- [ ] Open Xcode, open any Swift file (e.g., `ChatManager.swift`)
- [ ] Select a block of code (10+ lines with a syntax error or TODO comment)
- [ ] Place cursor at specific line/column (note the line number)
- [ ] Switch to Thea.app (Cmd+Tab or click)
- [ ] Check Console.app for: `📱 Extracted context for Xcode: <window title>`
- [ ] In Thea chat, type: "What's wrong with this code?"
- [ ] **CRITICAL:** Before message is sent, verify ChatManager injects context — check Console.app for: `📱 Injected foreground app context for Xcode`
- [ ] Verify AI response addresses the specific selected code (not generic)
- [ ] **EXPECTED:** Response references the file name, selected text, or cursor position

#### Test 3: VS Code Context Extraction
- [ ] Open VS Code, open any file (e.g., `package.json`)
- [ ] Select text with error (e.g., invalid JSON syntax)
- [ ] Switch to Thea.app
- [ ] Check Console.app for: `📱 Extracted context for Visual Studio Code`
- [ ] Send query: "Fix this error"
- [ ] Verify Console.app shows: `📱 Injected foreground app context for Visual Studio Code`
- [ ] Verify AI response is specific to the selected code

#### Test 4: Terminal Context Extraction
- [ ] Open Terminal.app
- [ ] Run a command that produces output (e.g., `ls -la`, `git status`)
- [ ] Switch to Thea.app
- [ ] Check Console.app for: `📱 Extracted context for Terminal` or similar
- [ ] Send query: "Explain this output"
- [ ] Verify Console.app shows context injection
- [ ] **EXPECTED:** AI response references the terminal output (last 50 lines) or current directory

#### Test 5: Safari Context Extraction
- [ ] Open Safari, navigate to a webpage (e.g., https://docs.swift.org)
- [ ] Select text on the page
- [ ] Switch to Thea.app
- [ ] Check Console.app for: `📱 Extracted context for Safari`
- [ ] Send query: "Summarize this"
- [ ] Verify Console.app shows context injection
- [ ] **EXPECTED:** AI response references the URL and/or selected text

#### Test 6: Notes Context Extraction
- [ ] Open Notes.app, create/open a note with text
- [ ] Select part of the text
- [ ] Switch to Thea.app
- [ ] Check Console.app for: `📱 Extracted context for Notes`
- [ ] Send query: "Rewrite this professionally"
- [ ] Verify context injection in logs
- [ ] **EXPECTED:** AI response transforms the selected text

#### Test 7: Context Options Toggles
- [ ] Go to Settings → App Pairing
- [ ] Disable "Include Selected Text"
- [ ] Open Xcode, select code, switch to Thea
- [ ] Send query — verify AI response does NOT reference selected code (only file/window)
- [ ] Re-enable "Include Selected Text"
- [ ] Disable "Include Window Content"
- [ ] Repeat test — verify AI response has NO visible source code context (only selected text if any)
- [ ] Re-enable both

#### Test 8: Per-App Enable/Disable
- [ ] Go to Settings → App Pairing
- [ ] Uncheck "Xcode"
- [ ] Open Xcode, select code, switch to Thea
- [ ] Send query — verify Console.app does NOT show Xcode context extraction
- [ ] AI response should be generic (no file/code context)
- [ ] Re-check "Xcode"
- [ ] Repeat — verify context IS extracted now

#### Test 9: Pairing Toggle Off
- [ ] Go to Settings → App Pairing
- [ ] Disable "Enable Foreground App Pairing"
- [ ] Check Console.app for: `⏹️ Foreground app monitoring stopped`
- [ ] Open Xcode, select code, switch to Thea
- [ ] Send query — verify NO context extraction in logs
- [ ] Re-enable pairing

#### Test 10: Cross-Device Behavior (iOS)
- [ ] On iOS device with Thea installed, open chat
- [ ] Send message — verify NO app pairing (feature is macOS-only)
- [ ] On macOS, verify iOS messages don't trigger context extraction

---

## Success Criteria (from ADDENDA.md)

**ALL criteria must be verified via functional testing:**

- ✅ **Detects foreground app changes** — Test 1 + Console.app logs
- ⚠️ **Extracts context from supported apps** — Tests 2-6 (each app)
- ⚠️ **Context injected into AI queries** — All tests (verify Console.app logs + AI responses)
- ⚠️ **Option+Space shortcut documented** — Settings UI has instructions (verify present)
- ⚠️ **Privacy permissions handled correctly** — Test 1 (permission indicator, graceful handling)
- ⚠️ **UI integrated into macOS Settings** — Navigate to Settings → App Pairing (verify sidebar + UI)
- ⚠️ **Works seamlessly with existing chat flow** — All tests (verify no crashes, no UX disruption)

**App-Specific Extractor Requirements (CRITICAL — NOT placeholders):**

- ✅ **XcodeContextExtractor**: Extracts file path, selected text, cursor line/column (NOT placeholder) — Review code confirms real implementation
- ✅ **VSCodeContextExtractor**: Extracts file path, selected text, cursor position (NOT placeholder) — Review code confirms real implementation
- ✅ **TerminalContextExtractor**: Extracts visible output (last 50 lines), current directory (NOT placeholder) — Review code confirms real implementation
- ✅ **TextEditorContextExtractor**: Extracts document content or selected portion (NOT placeholder) — Review code confirms real implementation
- ✅ **SafariContextExtractor**: Extracts URL, page title, selected text via AppleScript (NOT placeholder) — Review code confirms real implementation

**⚠️ = Needs functional testing to confirm | ✅ = Code review confirms**

---

## Known Issues

1. **xcodebuild failure (pre-existing)**: Thea-macOS scheme does not build via xcodebuild. Swift Package Manager builds succeed. This blocks functional testing until resolved.

2. **No integrated tests**: Context extractors have no unit tests. Verification relies entirely on manual functional testing.

---

## Post-Testing Actions

**When ALL tests pass:**

1. Commit this testing guide:
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   git add G2_TESTING_GUIDE.md
   git commit -m "Auto-save: G2 testing guide — full implementation verification protocol"
   ```

2. Send ntfy notification:
   ```bash
   ntfy pub thea-runner "✅ G2 FULL IMPLEMENTATION complete - All app extractors working, context injection verified"
   ntfy pub thea-runner "🎯 Priority G complete - Moving to Priority H (Comprehensive Deep Audit)"
   ```

3. Update STATE_V2.json:
   ```bash
   jq '.current_phase = "H-Phase0" | .completed_phases += ["G1", "G2"] | .updated_at = now | todate' \
     ~/thea-autonomous/STATE_V2.json > /tmp/state.json && mv /tmp/state.json ~/thea-autonomous/STATE_V2.json
   ```

4. Proceed to H-Phase0 (Pre-Audit Setup) automatically.

**If ANY test fails:**

1. Document failure in this file under "Test Results" section
2. Fix the issue immediately (per Universal Implementation Standard)
3. Re-run ALL tests
4. Do NOT proceed to H-Phase0 until 100% passing

---

## Test Results

**Test Execution Date:** [PENDING]
**Tester:** [Claude Code autonomous runner]
**Result:** [PASS/FAIL — to be filled after testing]

### Failures (if any):

[None yet — testing not started due to build issue]

### Notes:

[Add observations here]

---

## Appendix: Code Locations

- **ForegroundAppMonitor:** `Shared/Integrations/ForegroundAppMonitor.swift` (220 lines)
- **Context Extractors:** `Shared/Integrations/ContextExtractors/*.swift` (6 files, ~235-214 lines each)
- **ChatManager Integration:** `Shared/Core/Managers/ChatManager+Messaging.swift` (line 20)
- **Settings UI:** `Shared/UI/Views/Settings/AppPairingSettingsView.swift` (173 lines)
- **Settings Integration:** `macOS/Views/MacSettingsView.swift` (lines 60, 119, 280-281)
