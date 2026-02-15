# G1: Live Screen Monitoring + Interactive Voice Guidance - Testing Guide

**Phase:** G1 (Priority G)  
**Platform:** macOS only (requires ScreenCaptureKit, Accessibility API, NSWorkspace)  
**Machine:** MSM3U (Mac Studio M3 Ultra, 256GB RAM) - REQUIRED for Qwen2-VL 7B  
**Date:** 2026-02-15  

---

## Overview

This guide provides step-by-step testing procedures to verify all components of the G1 Live Screen Monitoring + Interactive Voice Guidance implementation.

**Key Components:**
1. ScreenCaptureManager — Screen/window/region capture via ScreenCaptureKit
2. PointerTracker — Mouse pointer tracking via CGEvent
3. ActionExecutor — Action simulation (click, type, keys) via CGEvent
4. LocalVisionGuidance — Orchestrator with Qwen2-VL 7B + Soprano-80M TTS
5. LiveGuidanceSettingsView — Full UI with all controls

**Success Criteria (from ADDENDA.md):**
- ✅ Screen capture works (full screen, window, region)
- ✅ Qwen2-VL analyzes screenshots on-device
- ✅ Voice instructions spoken via Soprano-80M
- ✅ No Claude Vision API calls (all local)
- ✅ Control handoff works (Thea can click/type)
- ✅ User can reclaim control at any time
- ✅ Works end-to-end for complex multi-step tasks

---

## Phase 0: Pre-Testing Setup (5 minutes)

**Goal:** Verify environment and build

### Steps:

1. **Verify machine:**
   ```bash
   hostname -s  # Should output: MSM3U
   ```

2. **Verify RAM:**
   ```bash
   sysctl hw.memsize | awk '{print $2 / 1024^3 " GB"}'
   # Should show ~256GB
   ```

3. **Clean build:**
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   xcodegen generate
   xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Release clean build
   ```

4. **Install to /Applications:**
   ```bash
   RELEASE_APP=~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release/Thea.app
   ditto "$RELEASE_APP" /Applications/Thea.app
   ls -la /Applications/Thea.app/Contents/MacOS/Thea
   # Verify timestamp matches build time
   ```

5. **Launch Thea.app:**
   ```bash
   open /Applications/Thea.app
   ```

**Expected Result:**
- Thea launches without crashes
- Settings window opens
- No console errors

---

## Phase 1: UI Verification (5 minutes)

**Goal:** Verify Live Guidance UI is complete and accessible

### Steps:

1. Open Thea Settings (Cmd+,)

2. Verify "Live Guidance" appears in sidebar under Intelligence group

3. Click "Live Guidance" tab

4. **Verify ALL UI elements are present:**

   **Status Section:**
   - [ ] Status indicator (eye icon)
   - [ ] "Live Guidance Inactive" text
   - [ ] "Models Not Loaded" warning

   **Permissions Section:**
   - [ ] Screen Recording permission status
   - [ ] "Grant Permission" button (if not granted)
   - [ ] Accessibility permission status (when control handoff enabled)

   **Configuration Section:**
   - [ ] "Enable live screen monitoring" toggle
   - [ ] "Enable voice guidance" toggle
   - [ ] "Capture mode" dropdown (Full Screen, Active Window, Selected Region)
   - [ ] "Allow control handoff" toggle
   - [ ] Warning text about control handoff

   **Current Task Section:**
   - [ ] Task description text field
   - [ ] "Start Guidance" button
   - [ ] "Load Models" button

   **Advanced Section:**
   - [ ] "Guidance interval" slider (1-10 seconds)
   - [ ] Interval value display

   **Models Section:**
   - [ ] Vision Model status (Qwen2-VL 7B)
   - [ ] Voice Model status (Soprano-80M)
   - [ ] "All processing happens on-device" text

**Expected Result:**
- All UI elements present and styled correctly
- No layout issues or overlapping text
- Form is scrollable if content exceeds window height

---

## Phase 2: Screen Recording Permission (10 minutes)

**Goal:** Verify Screen Recording permission flow works correctly

### Steps:

1. In Live Guidance settings, check Screen Recording permission status

2. **If permission NOT granted:**
   - Click "Grant Permission" button
   - System Settings should open to Privacy & Security → Screen Recording
   - Enable permission for Thea
   - Return to Thea
   - Verify permission status updates to green checkmark

3. **If permission already granted:**
   - Verify green checkmark shows
   - Skip to Phase 3

4. **Verify permission detection:**
   ```bash
   # In Terminal, check console logs
   log stream --predicate 'subsystem == "com.apple.TCC"' --info --debug | grep Thea
   ```

5. Enable "Enable live screen monitoring" toggle

6. Verify no permission errors appear in UI

**Expected Result:**
- Permission request opens System Settings
- Permission status updates in real-time
- Green checkmark appears when granted
- Console shows: `[ScreenCaptureManager] Permission granted` or similar

---

## Phase 3: Model Loading (15-20 minutes)

**Goal:** Verify Qwen2-VL 7B and Soprano-80M load successfully

### Steps:

1. In Live Guidance settings, click "Load Models" button

2. **Monitor progress:**
   - Loading indicator should appear
   - This may take 30-60 seconds on first load (model download)

3. **Watch Activity Monitor:**
   ```bash
   # In separate Terminal window
   top -pid $(pgrep Thea)
   ```
   - Verify RAM usage increases as models load
   - Should stabilize around 8-15GB for Qwen2-VL 7B
   - Total Thea memory usage should stay < 100GB

4. **Check console logs:**
   ```bash
   log show --predicate 'process == "Thea"' --last 5m | grep -E "(MLXVisionEngine|MLXAudioEngine|Qwen|Soprano)"
   ```

5. **Verify Model Info section:**
   - [ ] Vision Model: Green checkmark "Qwen2-VL 7B"
   - [ ] Voice Model: Green checkmark "Soprano-80M"
   - [ ] Status section shows "Models Ready"

**Expected Console Output:**
```
✅ MLXVisionEngine: Loaded VLM mlx-community/Qwen2-VL-7B-Instruct-4bit
MLXAudioEngine: Loaded TTS model mlx-community/Soprano-80M-bf16
[LocalVisionGuidance] All models ready
```

**Expected Result:**
- Models load without errors
- RAM usage < 100GB
- Both models show green checkmark
- No crashes or freezes

---

## Phase 4: Voice Synthesis Test (5 minutes)

**Goal:** Verify Soprano-80M TTS produces voice output

### Steps:

1. Ensure "Enable voice guidance" toggle is ON

2. Ensure models are loaded (Phase 3 complete)

3. Enter task: "Test voice synthesis"

4. Click "Start Guidance"

5. **Listen for voice output:**
   - Should hear: "Starting live guidance for: Test voice synthesis"
   - Voice should be clear and audible
   - No distortion or artifacts

6. Measure latency:
   - Start timer when clicking "Start Guidance"
   - Stop timer when voice begins
   - Latency should be < 3 seconds

7. Click "Stop Guidance"

8. Should hear: "Guidance stopped"

**Expected Result:**
- Voice output works
- Speech is clear and natural-sounding
- Latency < 3 seconds
- No audio glitches

---

## Phase 5: Screen Capture Test (10 minutes)

**Goal:** Verify screen capture works for all modes

### Test 5.1: Full Screen Capture

1. Set capture mode to "Full Screen"
2. Enter task: "Capture full screen"
3. Click "Start Guidance"
4. Wait 3-5 seconds
5. Check console logs for:
   ```
   [ScreenCaptureManager] Captured display <ID>: <width>x<height>
   ```

### Test 5.2: Active Window Capture

1. Open Safari (or any other app)
2. Bring Safari to foreground
3. In Thea, set capture mode to "Active Window"
4. Enter task: "Capture active window"
5. Click "Start Guidance"
6. Wait 3-5 seconds
7. Check console logs for:
   ```
   [ScreenCaptureManager] Captured window 'Safari': <width>x<height>
   ```

### Test 5.3: Pointer Tracking

1. While guidance is running, move mouse around screen
2. Check console logs (LocalVisionGuidance should receive pointer position)
3. Verify guidance updates based on pointer location

**Expected Result:**
- All capture modes work without errors
- Captured image dimensions are correct
- No permission errors
- Console logs show successful captures

---

## Phase 6: Vision Analysis Test (15 minutes)

**Goal:** Verify Qwen2-VL analyzes screenshots correctly

### Steps:

1. **Create test scenario:**
   - Open System Settings
   - Navigate to any pane (e.g., General)

2. **In Thea Live Guidance:**
   - Set capture mode to "Active Window"
   - Enter task: "Describe what settings are visible"
   - Click "Start Guidance"

3. **Wait for analysis:**
   - Guidance interval is 3 seconds by default
   - Vision model should analyze screenshot
   - Should hear voice instructions describing the screen

4. **Check console logs:**
   ```bash
   log show --predicate 'process == "Thea"' --last 2m | grep -E "(LocalVisionGuidance|analyze|OBSERVATION|NEXT_STEP)"
   ```

5. **Verify instruction updates:**
   - Instructions should change as you navigate System Settings
   - Voice should speak new instructions when they change

6. **Test pointer awareness:**
   - Move mouse over different UI elements
   - Instructions should mention what you're hovering over

**Expected Console Output:**
```
[LocalVisionGuidance] Loaded Qwen2-VL vision model
[LocalVisionGuidance] Captured screen for analysis
OBSERVATION: [Description of what's visible]
NEXT_STEP: [Suggested next action]
```

**Expected Result:**
- Vision model analyzes screenshots
- Instructions are relevant to what's on screen
- Pointer position affects analysis
- Voice updates when instructions change

---

## Phase 7: Control Handoff Test (15 minutes)

**Goal:** Verify ActionExecutor can perform actions

### Pre-requisite: Grant Accessibility Permission

1. Enable "Allow control handoff" toggle
2. If Accessibility permission not granted:
   - Click "Grant Permission"
   - System Settings should open to Privacy & Security → Accessibility
   - Enable permission for Thea
   - Return to Thea

### Test 7.1: Click Action

1. **Setup:**
   - Open Notes.app
   - Position Notes window at known location (e.g., top-left of screen)

2. **In Thea:**
   - Enable "Allow control handoff"
   - Enter task: "Click the new note button"
   - Click "Start Guidance"

3. **Observe:**
   - Thea should analyze screen
   - If vision model identifies clickable element, it may simulate click
   - Check console logs for:
     ```
     [ActionExecutor] Clicked at (<x>, <y>) with left button
     ```

### Test 7.2: Typing Action

1. **Setup:**
   - Ensure Notes.app has a new note open
   - Click into the note to focus text field

2. **Test typing simulation:**
   ```bash
   # In Swift REPL or test script
   let executor = ActionExecutor.shared
   try await executor.type("Hello from Thea")
   ```

3. **Verify:**
   - Text appears in Notes
   - Console shows:
     ```
     [ActionExecutor] Typed text: 'Hello from Thea'
     ```

### Test 7.3: Key Press Action

1. **Test Enter key:**
   ```bash
   try await executor.pressKey(.returnKey)
   ```

2. **Verify:**
   - New line created in Notes
   - Console shows:
     ```
     [ActionExecutor] Pressed key: returnKey with modifiers: []
     ```

**Expected Result:**
- Accessibility permission flow works
- Actions execute successfully
- Mouse clicks at correct coordinates
- Text typing works
- Key presses work

---

## Phase 8: End-to-End Test — Apple Developer Portal Scenario (30 minutes)

**Goal:** Verify complete guidance workflow for complex multi-step task

### Scenario: Clean up expired certificates in Apple Developer Portal

This is the real-world scenario that inspired G1.

### Pre-Test Setup:

1. Open Safari
2. Navigate to https://developer.apple.com/account/resources/certificates/list
3. Log in to Apple Developer account (if not already logged in)
4. Ensure there are some certificates visible (expired or not)

### Test Execution:

1. **In Thea Live Guidance:**
   - Set capture mode to "Active Window"
   - Enable voice guidance: ON
   - Allow control handoff: ON (optional - can do manually)
   - Guidance interval: 3 seconds
   - Task: "Guide me through cleaning up expired signing certificates in Apple Developer Portal"

2. **Click "Start Guidance"**

3. **Observe multi-step guidance:**

   **Step 1:** Thea should identify the certificates list
   - Voice: "I see the certificates list. Looking for expired certificates..."
   - Should describe what's visible

   **Step 2:** Thea should guide to identify expired certs
   - Voice: "Hover over the expiration date column to find expired certificates"
   - Instructions should update based on pointer position

   **Step 3:** Thea should guide clicking on an expired cert
   - Voice: "Click on the expired certificate at [coordinates] to select it"
   - If control handoff ON, may click automatically
   - If control handoff OFF, user clicks manually

   **Step 4:** Thea should guide to delete action
   - Voice: "Click the Revoke button to remove this certificate"
   - Should identify the correct button location

   **Step 5:** Thea should guide through confirmation dialog
   - Voice: "A confirmation dialog appeared. Click Revoke to confirm."

4. **Monitor throughout:**
   - Voice instructions should be timely and accurate
   - Analysis should update every 3 seconds
   - Instructions should adapt to UI changes
   - No crashes or freezes
   - RAM usage stays < 100GB

5. **User can stop at any time:**
   - Click "Stop Guidance" in Thea
   - Voice: "Guidance stopped"
   - No further actions executed

### Success Metrics:

- [ ] Vision model correctly identifies UI elements (certificates, buttons, dialogs)
- [ ] Voice instructions match what's on screen
- [ ] Pointer position awareness works (mentions hovered elements)
- [ ] Multi-step workflow navigation works
- [ ] Control handoff actions execute correctly (if enabled)
- [ ] User can take over control at any point
- [ ] No Claude Vision API calls (all local — verify with network monitor)
- [ ] Total time for multi-step task < 5 minutes
- [ ] RAM usage < 100GB throughout
- [ ] No crashes or memory leaks

**Expected Console Output:**
```
[LocalVisionGuidance] Started guidance for task: Guide me through cleaning up expired signing certificates in Apple Developer Portal
[ScreenCaptureManager] Captured window 'Safari': 1920x1080
[MLXVisionEngine] Analyzing screenshot...
OBSERVATION: I see the Apple Developer certificates list with 5 certificates. 2 appear to be expired based on the expiration date column.
NEXT_STEP: Hover over the expiration date column to identify which certificates are expired.
[ActionExecutor] Moved pointer to (542, 387)
NEXT_STEP: Click on the expired certificate "iOS Development" expiring on 2025-01-15 to select it.
ACTION: Click(542, 387)
[ActionExecutor] Clicked at (542, 387) with left button
... (continued guidance) ...
```

**Pass Criteria:**
- All 7 success metrics met
- Complete task from start to finish with no manual intervention (if control handoff ON)
- OR complete with accurate voice guidance (if control handoff OFF)
- No errors or crashes

---

## Phase 9: Performance & Resource Verification (10 minutes)

**Goal:** Verify performance meets specifications

### Steps:

1. **Run guidance for 5 minutes continuously:**
   - Start guidance with a simple task
   - Let it run for 5 minutes

2. **Monitor RAM usage:**
   ```bash
   # Check peak memory
   top -pid $(pgrep Thea) -stats pid,mem,cpu -l 60 | awk '{print $2}' | sort -n | tail -1
   ```
   - Should stay < 100GB

3. **Monitor CPU usage:**
   - Should be reasonable (not 100% continuously)
   - Vision inference spikes are expected every 3 seconds

4. **Check voice latency:**
   - Measure time from instruction generation to voice output
   - Should be < 3 seconds

5. **Verify no memory leaks:**
   - Run Instruments (Leaks template)
   - OR check with:
     ```bash
     leaks Thea | grep LEAK
     ```

**Expected Result:**
- Peak RAM < 100GB
- CPU usage reasonable
- Voice latency < 3 seconds
- No memory leaks

---

## Phase 10: Regression & Edge Cases (15 minutes)

**Goal:** Test error handling and edge cases

### Test 10.1: Permission Denial

1. Disable Screen Recording permission in System Settings
2. Try to start guidance
3. Should show clear error: "Screen Recording permission required..."
4. Should NOT crash

### Test 10.2: Model Load Failure

1. Unload models (if possible via debug menu)
2. Disable internet connection
3. Try to load models
4. Should show clear error
5. Should NOT crash

### Test 10.3: Rapid Start/Stop

1. Click "Start Guidance"
2. Immediately click "Stop Guidance"
3. Repeat 5 times quickly
4. Should handle gracefully
5. No crashes or stuck states

### Test 10.4: Background App Capture

1. Set capture mode to "Active Window"
2. Enter task, start guidance
3. Immediately switch to another app (Cmd+Tab)
4. Verify Thea captures the NEW active window
5. No crashes

**Expected Result:**
- All error cases handled gracefully
- Clear error messages shown to user
- No crashes or undefined behavior

---

## Final Verification Checklist

Before marking G1 as COMPLETE, verify ALL items:

**Implementation:**
- [x] ScreenCaptureManager.swift exists and compiles
- [x] PointerTracker.swift exists and compiles
- [x] ActionExecutor.swift exists and compiles
- [x] LocalVisionGuidance.swift exists and compiles
- [x] LiveGuidanceSettingsView.swift exists and compiles
- [x] All files active in macOS build (not excluded in project.yml)
- [x] MacSettingsView has .liveGuidance tab wired

**Testing:**
- [ ] Phase 1: UI complete and accessible
- [ ] Phase 2: Screen Recording permission flow works
- [ ] Phase 3: Models load successfully (Qwen2-VL + Soprano-80M)
- [ ] Phase 4: Voice synthesis works, latency < 3s
- [ ] Phase 5: Screen capture works (all modes)
- [ ] Phase 6: Vision analysis provides relevant instructions
- [ ] Phase 7: Control handoff executes actions correctly
- [ ] Phase 8: End-to-end Apple Developer Portal scenario succeeds
- [ ] Phase 9: Performance within limits (RAM < 100GB)
- [ ] Phase 10: Edge cases handled gracefully

**Success Criteria:**
- [ ] Screen capture works (full screen, window, region)
- [ ] Qwen2-VL analyzes screenshots on-device
- [ ] Voice instructions spoken via Soprano-80M
- [ ] No Claude Vision API calls (all local)
- [ ] Control handoff works (Thea can click/type)
- [ ] User can reclaim control at any time
- [ ] Works end-to-end for complex multi-step tasks

---

## Completion

When ALL checkboxes above are checked:

```bash
# Commit final verification
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git add -A
git commit -m "G1 FULL IMPLEMENTATION VERIFIED - All success criteria met, end-to-end tested"
git pushsync origin main

# Notify
ntfy pub thea-runner "✅ G1 FULL IMPLEMENTATION COMPLETE - Screen capture + Qwen2-VL + Soprano-80M verified working"
ntfy pub thea-runner "▶️ Moving to G2 (Automatic Foreground App Pairing)"
```

**G1 is NOW COMPLETE. Proceed to G2.**
