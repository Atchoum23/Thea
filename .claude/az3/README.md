# AZ3 Cross-Mac Visual Regression Testing

A two-agent setup that captures screenshots of MSM3U's running Thea app as seen through Screen Sharing on MBAM2, coordinated over Thunderbolt Bridge for zero-latency frame delivery.

---

## What This Does

**Agent A** runs on **MSM3U** (Mac Studio). It executes test steps against the running Thea app — launching windows, triggering actions, typing input — then signals Agent B after each step.

**Agent B** runs on **MBAM2** (MacBook Air). It watches for capture requests and takes a screenshot of MBAM2's display, which shows MSM3U's screen through Screen Sharing. The PNG is sent back to MSM3U over Thunderbolt Bridge (169.254.x.x link-local) for review.

The result is a timestamped sequence of PNG frames, one per test step, allowing visual inspection of the Thea UI across a full interaction flow.

---

## 2 Manual Steps Required

Before the first run, complete these two steps once:

1. **On MBAM2**: Open System Settings → General → Sharing → Screen Sharing → Enable. This allows MSM3U (and the Screen Sharing app) to observe MBAM2's screen. Also enable "Remote Login" so MSM3U can SSH in.

2. **On MSM3U**: Open System Settings → Privacy & Security → Screen Recording → Enable Terminal (or the app running the scripts). This allows `screencapture` to capture full-screen content (not just app windows).

---

## One Command to Run

After completing the two manual steps above and connecting both Macs via Thunderbolt cable:

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && .claude/az3/setup.sh && .claude/az3/launch-az3.sh
```

`setup.sh` detects the Thunderbolt Bridge IPs and verifies SSH. `launch-az3.sh` deploys Agent B to MBAM2, runs the test steps, and collects all frames.

To start a Screen Sharing session on MBAM2 pointed at MSM3U before capturing, run this first:

```bash
.claude/az3/start-screen-sharing.sh
```

---

## What Gets Captured

Each test step produces one PNG screenshot saved to `/tmp/az3-frames/` on MSM3U. Frames are named:

```
frame_<unix_timestamp>_<step_name>.png
```

Open them all at once for visual comparison:

```bash
open /tmp/az3-frames
```

Agent A's pass/fail log is at `/tmp/az3-logs/agent-a-results.txt`. Agent B's capture log is at `/tmp/az3-logs/agent-b.log` (on MBAM2, and collected to MSM3U on completion).

---

## Customizing Test Steps

Edit `/tmp/az3-logs/test-steps.txt` (created automatically on first run with sample steps) before launching:

```
# Format: STEP_NAME | SHELL_COMMAND
# Lines starting with # are skipped.
# SHELL_COMMAND is optional — omit it to capture the current state without taking action.

launch-thea            | open -a Thea
wait-for-main-window   |
open-new-conversation  | osascript -e 'tell application "Thea" to activate'
type-test-message      | cliclick t:"Hello from AZ3"
verify-response        |
```

**STEP_NAME** is used in the PNG filename so you can identify which step each frame corresponds to.

**SHELL_COMMAND** can be any bash expression: `open`, `osascript`, `cliclick`, keyboard shortcuts via `osascript key code`, or custom scripts. Install `cliclick` with `brew install cliclick` for precise mouse/keyboard automation.

Agent A waits 2 seconds after each command before signaling Agent B to capture, giving the UI time to settle.

---

## Script Reference

| Script | Purpose |
|---|---|
| `config.env` | IP addresses and paths — written by `setup.sh` |
| `setup.sh` | Detects Thunderbolt Bridge IPs, verifies SSH, creates log dir |
| `start-screen-sharing.sh` | Opens Screen Sharing on MBAM2 pointing at MSM3U |
| `capture-msm3u.sh` | One-shot: capture MBAM2 screen and retrieve PNG to MSM3U |
| `agent-a-loop.sh` | MSM3U: executes test steps and coordinates with Agent B |
| `agent-b-loop.sh` | MBAM2: watches for capture requests, screenshots, sends back |
| `launch-az3.sh` | Orchestrator: deploys Agent B, runs Agent A, collects frames |

---

## Troubleshooting

**SSH fails**: Ensure Remote Login is enabled on MBAM2 (System Settings → General → Sharing → Remote Login) and that `ssh-copy-id alexis@mbam2.local` has been run from MSM3U.

**No Thunderbolt Bridge IP**: Both Macs must be connected with a Thunderbolt cable and bridge0 must be assigned a link-local address. Check with `ifconfig bridge0` on each Mac.

**screencapture produces blank PNGs**: Screen Recording permission must be granted to Terminal (or whichever app runs the script) on MBAM2. See Manual Step 2 above.

**Screen Sharing shows a black window**: MSM3U's display must be active (not in sleep). Nudge the mouse or press a key on MSM3U before running the test.

**Agent B stops immediately**: Check `/tmp/az3-agent-b.log` on MBAM2 for the error. Common cause: `$AZ3_LOG_DIR` not created before Agent B starts (launch-az3.sh handles this, but verify).
