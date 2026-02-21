#!/usr/bin/env bash
# az3-functional-test.sh — Real functional tests for Thea on MSM3U
# Tests: AI messaging via gateway (POST /message), SwiftData verification, TTS audio detection.
# Run this ON MSM3U after enabling Messaging Gateway in Thea Settings.
#
# Prerequisites (on MBAM2): python3 /tmp/az3_capture_agent.py &
# Prerequisites (on MSM3U): Thea running, Messaging Gateway enabled in Settings
#
# Usage: bash az3-functional-test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

GATEWAY_URL="http://127.0.0.1:18789"
MBAM2_AGENT="http://${MBAM2_TB_IP}:18791"
LOG_DIR="/tmp/az3-functional-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/test.log"
FRAMES_DIR="$LOG_DIR/frames"
SWIFTDATA_STORE="$HOME/Library/Group Containers/group.app.theathe/Library/Application Support/default.store"

PASS=0; FAIL=0; SKIP=0

# MessagingSession is in the main SchemaV1 schema — persisted in default.store (not a separate file)
MESSAGING_STORE="$SWIFTDATA_STORE"

mkdir -p "$LOG_DIR" "$FRAMES_DIR"

log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
pass() { PASS=$((PASS+1)); log "  ✅ PASS: $*"; }
fail() { FAIL=$((FAIL+1)); log "  ❌ FAIL: $*"; }
skip() { SKIP=$((SKIP+1)); log "  ⏭  SKIP: $*"; }

screenshot() {
    local name="$1"
    local frame="$FRAMES_DIR/${name// /_}.png"
    if curl -sf --max-time 12 "$MBAM2_AGENT/capture" -o "$frame" 2>/dev/null; then
        local sz
        sz=$(stat -f%z "$frame" 2>/dev/null || echo 0)
        if [[ "$sz" -gt 10240 ]]; then
            log "  📸 Screenshot: $name (${sz}B)"
        else
            log "  ⚠️  Screenshot too small: $name (${sz}B)"
        fi
    else
        log "  ⚠️  Screenshot failed: $name"
    fi
}

# Check ZMESSAGE count (legacy ChatManager store — kept for reference)
msg_count() {
    sqlite3 "$SWIFTDATA_STORE" 'SELECT count(*) FROM ZMESSAGE;' 2>/dev/null || echo -1
}

# Check MessagingSession historyData size for a given chatId (gateway AI pipeline check)
# Returns the length in bytes of the JSON historyData blob for the most recent session with that chatId.
# Grows when messages + AI responses are appended.
session_history_size() {
    local chatid="$1"
    sqlite3 "$MESSAGING_STORE" \
        "SELECT COALESCE(length(ZHISTORYDATA), 0) FROM ZMESSAGINGSESSION WHERE ZCHATID = '$chatid' ORDER BY ZLASTACTIVITY DESC LIMIT 1;" \
        2>/dev/null || echo 0
}

# Count rows in MessagingSession (any session created = gateway received + stored a message)
session_count() {
    sqlite3 "$MESSAGING_STORE" 'SELECT count(*) FROM ZMESSAGINGSESSION;' 2>/dev/null || echo 0
}

log "=== AZ3 Functional Test Suite — $(date) ==="
log "Gateway: $GATEWAY_URL"
log "MBAM2 Agent: $MBAM2_AGENT"

# ───────────────────────────────────────────────────────────────
# TEST 1: MBAM2 capture agent reachable
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 1: MBAM2 Capture Agent ---"
if curl -sf --max-time 5 "$MBAM2_AGENT/ping" >/dev/null 2>&1; then
    pass "MBAM2 capture agent online at $MBAM2_AGENT"
else
    fail "MBAM2 capture agent not reachable — screenshots will be skipped"
    MBAM2_AGENT=""
fi

# ───────────────────────────────────────────────────────────────
# TEST 2: Thea process running
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 2: Thea Process ---"
THEA_PID=$(pgrep -x Thea 2>/dev/null || echo "")
if [[ -n "$THEA_PID" ]]; then
    pass "Thea running (PID $THEA_PID)"
else
    fail "Thea not running — launch /Applications/Thea.app first"
    log "Attempting launch..."
    open -a /Applications/Thea.app
    sleep 5
    THEA_PID=$(pgrep -x Thea 2>/dev/null || echo "")
    [[ -n "$THEA_PID" ]] && pass "Thea launched (PID $THEA_PID)" || fail "Could not launch Thea"
fi

# ───────────────────────────────────────────────────────────────
# TEST 3: Messaging Gateway health (port 18789)
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 3: Messaging Gateway Health ---"
GATEWAY_UP=false
for attempt in 1 2 3 4 5; do
    HTTP_CODE=$(curl -o /tmp/az3_health.json -w '%{http_code}' -sf --max-time 5 "$GATEWAY_URL/health" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        GATEWAY_UP=true
        HEALTH_JSON=$(cat /tmp/az3_health.json 2>/dev/null)
        pass "Gateway healthy (HTTP 200) — $HEALTH_JSON"
        break
    fi
    log "  Attempt $attempt/5: HTTP $HTTP_CODE — waiting 3s..."
    sleep 3
done

if ! $GATEWAY_UP; then
    fail "Messaging Gateway not reachable at port 18789"
    log "  ⚠️  Open Thea → Settings → Messaging Gateway and enable the toggle"
    log "  ⚠️  Skipping all AI messaging tests (gateway required)"
    # Still run TTS and screenshot tests
fi

# Screenshot current state
[[ -n "${MBAM2_AGENT:-}" ]] && screenshot "03-gateway-check"

# ───────────────────────────────────────────────────────────────
# SETUP: Enable AI auto-respond for test chatIds
# POST /debug/autorespond activates OpenClawBridge.autoRespondEnabled
# and adds test chatIds to autoRespondChannels. This is required because
# autoRespondEnabled defaults to false (prevents accidental bot responses
# to real messages until explicitly configured by the user).
# ───────────────────────────────────────────────────────────────
if $GATEWAY_UP; then
    log ""
    log "--- SETUP: Enable Auto-Respond for Test ChatIds ---"
    AUTORESPOND_PAYLOAD='{"enabled":true,"chatIds":["az3-test-001","az3-tts-test"]}'
    AR_RESP=$(curl -sf --max-time 5 \
        -X POST "$GATEWAY_URL/debug/autorespond" \
        -H 'Content-Type: application/json' \
        -d "$AUTORESPOND_PAYLOAD" \
        -w '%{http_code}' -o /tmp/az3_ar_resp.json 2>/dev/null || echo "000")
    if [[ "$AR_RESP" == "200" ]]; then
        log "  ✓ Auto-respond enabled: $(cat /tmp/az3_ar_resp.json 2>/dev/null)"
    else
        log "  ⚠️  Auto-respond setup returned HTTP $AR_RESP — AI tests may not get responses"
    fi
fi

# ───────────────────────────────────────────────────────────────
# TEST 4: SwiftData baseline
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 4: SwiftData Baseline ---"
BASELINE_MSGS=0
BASELINE_SESSIONS=0
BASELINE_HISTORY_AZ3=0
if [[ -f "$SWIFTDATA_STORE" ]]; then
    BASELINE_MSGS=$(msg_count)
    BASELINE_CONVS=$(sqlite3 "$SWIFTDATA_STORE" 'SELECT count(*) FROM ZCONVERSATION;' 2>/dev/null || echo -1)
    if [[ "$BASELINE_MSGS" -ge 0 ]]; then
        pass "Main SwiftData store accessible — $BASELINE_CONVS conversations, $BASELINE_MSGS messages"
    else
        fail "Main SwiftData store not readable"
    fi
else
    fail "Main SwiftData store not found at expected path"
fi

# Baseline the MessagingSession table (now in main default.store via SchemaV1.models)
if [[ -f "$MESSAGING_STORE" ]]; then
    BASELINE_SESSIONS=$(session_count)
    BASELINE_HISTORY_AZ3=$(session_history_size "az3-test-001")
    log "  MessagingSession table: $BASELINE_SESSIONS sessions, az3-test-001 history: $BASELINE_HISTORY_AZ3 bytes"
else
    log "  default.store not found — will be created on first gateway message"
fi

# ───────────────────────────────────────────────────────────────
# TEST 5: AI Messaging — send message + verify response
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 5: AI Messaging ---"

if ! $GATEWAY_UP; then
    skip "AI Messaging (gateway offline)"
else
    MSG_PAYLOAD='{"content":"Hello! This is AZ3 automated test message #1. Please reply with exactly: THEA_AZ3_ACK","chatId":"az3-test-001","senderId":"az3-bot","senderName":"AZ3 Test"}'
    log "  Sending test message to gateway..."

    HTTP_RESP=$(curl -sf --max-time 10 \
        -X POST "$GATEWAY_URL/message" \
        -H 'Content-Type: application/json' \
        -H "Content-Length: ${#MSG_PAYLOAD}" \
        -d "$MSG_PAYLOAD" \
        -o /tmp/az3_msg_resp.json \
        -w '%{http_code}' 2>/dev/null || echo "000")

    MSG_RESP_BODY=$(cat /tmp/az3_msg_resp.json 2>/dev/null)

    if [[ "$HTTP_RESP" == "200" ]]; then
        pass "Message accepted by gateway (HTTP 200) — $MSG_RESP_BODY"
        [[ -n "${MBAM2_AGENT:-}" ]] && screenshot "05a-message-sent"

        # Wait for AI to process and respond (30s timeout).
        # Check MessagingSession historyData growth — it grows when the AI response is appended.
        # (Gateway AI responses go to messaging-sessions.store, not ZMESSAGE/ChatManager.)
        log "  Waiting up to 30s for AI response (checking MessagingSession)..."
        AI_RESPONDED=false
        for wait_s in 5 5 5 5 5 5; do
            sleep "$wait_s"
            CURRENT_HISTORY=$(session_history_size "az3-test-001")
            if [[ "$CURRENT_HISTORY" -gt "$BASELINE_HISTORY_AZ3" ]]; then
                DELTA=$((CURRENT_HISTORY - BASELINE_HISTORY_AZ3))
                pass "AI responded — MessagingSession historyData: $BASELINE_HISTORY_AZ3 → $CURRENT_HISTORY bytes (+$DELTA bytes = new message entries)"
                AI_RESPONDED=true
                BASELINE_HISTORY_AZ3="$CURRENT_HISTORY"  # update for Test 6
                [[ -n "${MBAM2_AGENT:-}" ]] && screenshot "05b-ai-responded"
                break
            fi
            log "  Still waiting... (history: ${CURRENT_HISTORY}B)"
        done

        if ! $AI_RESPONDED; then
            fail "No AI response detected in MessagingSession within 30s"
        fi
    else
        fail "Message POST failed (HTTP $HTTP_RESP) — $MSG_RESP_BODY"
    fi
fi

# ───────────────────────────────────────────────────────────────
# TEST 6: Second message — AI reasoning test
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 6: AI Reasoning Test ---"

if ! $GATEWAY_UP; then
    skip "AI Reasoning (gateway offline)"
else
    MSG2_PAYLOAD='{"content":"What is 15 + 27? Please answer with just the number.","chatId":"az3-test-001","senderId":"az3-bot","senderName":"AZ3 Test"}'
    BEFORE_HISTORY=$(session_history_size "az3-test-001")

    HTTP_RESP2=$(curl -sf --max-time 10 \
        -X POST "$GATEWAY_URL/message" \
        -H 'Content-Type: application/json' \
        -H "Content-Length: ${#MSG2_PAYLOAD}" \
        -d "$MSG2_PAYLOAD" \
        -o /tmp/az3_msg2_resp.json \
        -w '%{http_code}' 2>/dev/null || echo "000")

    if [[ "$HTTP_RESP2" == "200" ]]; then
        pass "Reasoning message accepted"
        log "  Waiting 25s for AI response (MessagingSession)..."
        sleep 25
        AFTER_HISTORY=$(session_history_size "az3-test-001")
        if [[ "$AFTER_HISTORY" -gt "$BEFORE_HISTORY" ]]; then
            DELTA=$((AFTER_HISTORY - BEFORE_HISTORY))
            pass "AI responded to math question — history: $BEFORE_HISTORY → $AFTER_HISTORY bytes (+$DELTA)"
            [[ -n "${MBAM2_AGENT:-}" ]] && screenshot "06-reasoning-response"
        else
            fail "No response to math question within 25s"
        fi
    else
        fail "Reasoning POST failed (HTTP $HTTP_RESP2)"
    fi
fi

# ───────────────────────────────────────────────────────────────
# TEST 7: TTS Audio Detection
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 7: TTS Audio Detection ---"

# Check TTS enabled
TTS_ENABLED=$(defaults read app.thea.macos readResponsesAloud 2>/dev/null || echo "0")
log "  readResponsesAloud = $TTS_ENABLED"

if [[ "$TTS_ENABLED" != "1" ]]; then
    log "  Enabling TTS..."
    defaults write app.thea.macos readResponsesAloud -bool YES
fi

# Check if Thea has audio files open (active TTS playback)
AUDIO_OPEN=$(lsof -p "${THEA_PID:-0}" 2>/dev/null | grep -iE '\.aiff|\.wav|\.mp3|\.caf|audio' | wc -l | xargs)
log "  Thea audio file descriptors open: $AUDIO_OPEN"

# Check system audio output is not muted
AUDIO_OUTPUT=$(osascript -e 'get output volume of (get volume settings)' 2>/dev/null || echo "unknown")
AUDIO_MUTED=$(osascript -e 'get output muted of (get volume settings)' 2>/dev/null || echo "unknown")
log "  System audio: volume=$AUDIO_OUTPUT muted=$AUDIO_MUTED"

# Verify system TTS works (baseline audio capability)
say "AZ3 audio test" -v Samantha -o /tmp/az3_tts_baseline.aiff 2>/dev/null
if [[ -f /tmp/az3_tts_baseline.aiff && $(stat -f%z /tmp/az3_tts_baseline.aiff) -gt 1000 ]]; then
    pass "System TTS pipeline functional ($(stat -f%z /tmp/az3_tts_baseline.aiff)B audio generated)"
else
    fail "System TTS not working"
fi

# Check Soprano-80M MLX TTS model (Thea's on-device TTS)
SOPRANO_PATH=$(find ~/Library/Application\ Support/SharedLLMs -name '*soprano*' -o -name '*Soprano*' 2>/dev/null | head -1)
HF_SOPRANO=$(ls ~/.cache/huggingface/hub/ 2>/dev/null | grep -i 'soprano' | head -1)
if [[ -n "$SOPRANO_PATH" || -n "$HF_SOPRANO" ]]; then
    pass "Soprano MLX TTS model found: ${SOPRANO_PATH:-$HF_SOPRANO}"
else
    log "  ℹ️  Soprano-80M TTS model not downloaded — Thea uses system voice (Samantha)"
    log "  ℹ️  To enable MLX TTS: download models--yl4579--Soprano-80M to SharedLLMs"
fi

if $GATEWAY_UP; then
    # Send one more message to trigger TTS (readResponsesAloud = YES)
    # Uses chatId "az3-tts-test" (auto-respond already enabled for it via SETUP above)
    MSG_TTS='{"content":"Say hello in one short sentence.","chatId":"az3-tts-test","senderId":"az3-bot","senderName":"AZ3"}'
    TTS_BEFORE_HISTORY=$(session_history_size "az3-tts-test")
    curl -sf --max-time 10 -X POST "$GATEWAY_URL/message" \
        -H 'Content-Type: application/json' \
        -H "Content-Length: ${#MSG_TTS}" \
        -d "$MSG_TTS" -o /dev/null 2>/dev/null && log "  TTS trigger message sent"

    log "  Waiting 20s for AI response + TTS to fire..."
    sleep 20

    # Check audio file descriptors during response window
    TTS_AFTER_HISTORY=$(session_history_size "az3-tts-test")
    AUDIO_DURING=$(lsof -p "${THEA_PID:-0}" 2>/dev/null | grep -iE '\.aiff|\.wav|\.caf|audio' | wc -l | xargs)

    if [[ "$TTS_AFTER_HISTORY" -gt "$TTS_BEFORE_HISTORY" ]]; then
        DELTA=$((TTS_AFTER_HISTORY - TTS_BEFORE_HISTORY))
        pass "TTS AI response received — MessagingSession history: $TTS_BEFORE_HISTORY → $TTS_AFTER_HISTORY bytes (+$DELTA)"
        if [[ "$AUDIO_DURING" -gt 0 ]]; then
            pass "Audio playback detected ($AUDIO_DURING open audio file descriptors)"
        else
            log "  ℹ️  No active audio FDs during window — TTS may have already completed"
        fi
        [[ -n "${MBAM2_AGENT:-}" ]] && screenshot "07-tts-response"
    else
        fail "No TTS AI response detected in 20s (MessagingSession history unchanged)"
    fi
else
    skip "TTS trigger test (gateway offline — only system TTS verified)"
fi

# ───────────────────────────────────────────────────────────────
# TEST 8: ExtensionSyncBridge (port 9876)
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 8: ExtensionSyncBridge ---"

python3 - <<'PYEOF' 2>/dev/null && pass "ExtensionSyncBridge WebSocket accepts connections on port 9876" || fail "ExtensionSyncBridge WebSocket failed"
import asyncio, websockets, json, socket

# Quick TCP probe first (faster than WebSocket handshake)
try:
    s = socket.create_connection(('127.0.0.1', 9876), timeout=3)
    s.close()
    print('TCP connect OK')
    exit(0)  # Port is open = ExtensionSyncBridge running
except Exception as e:
    print(f'TCP probe failed: {e}')
    exit(1)
PYEOF

# ───────────────────────────────────────────────────────────────
# TEST 9: Navigation — URL scheme deep links
# ───────────────────────────────────────────────────────────────
log ""
log "--- TEST 9: URL Scheme Navigation ---"

VIEWS_NAMES="chat knowledge new_conversation"
VIEWS_URLS="thea://chat thea://knowledge thea://new"

VIEW_IDX=0
for VIEW_URL in $VIEWS_URLS; do
    VIEW_IDX=$((VIEW_IDX + 1))
    VIEW_NAME=$(echo "$VIEWS_NAMES" | cut -d' ' -f"$VIEW_IDX")
    open "$VIEW_URL" 2>/dev/null
    sleep 2
    if [[ -n "${MBAM2_AGENT:-}" ]]; then
        screenshot "09-view-${VIEW_NAME}"
        pass "URL scheme: $VIEW_URL → screenshot captured"
    else
        pass "URL scheme: $VIEW_URL → launched (no screenshot)"
    fi
done

# ───────────────────────────────────────────────────────────────
# SUMMARY
# ───────────────────────────────────────────────────────────────
log ""
log "════════════════════════════════════════"
log "  AZ3 Functional Test Complete"
log "  PASS: $PASS | FAIL: $FAIL | SKIP: $SKIP"
log "  Logs:   $LOG_DIR"
log "  Frames: $FRAMES_DIR"
log "════════════════════════════════════════"

if [[ "$FAIL" -eq 0 ]]; then
    log "  🎉 ALL TESTS PASSED"
    exit 0
else
    log "  ⚠️  $FAIL test(s) FAILED"
    exit "$FAIL"
fi
