# Claude Code - Global Guidelines

## ⚠️ CRITICAL SAFETY RULES (ALWAYS APPLY)

### Mandatory Git Commits

**After EVERY file edit in ANY project, immediately commit:**
```bash
git add -A && git commit -m "Auto-save: <brief description>"
```

**Before ANY destructive command, ALWAYS commit first:**
```bash
git add -A && git commit -m "Checkpoint before cleanup"
```

### 🚫 FORBIDDEN Commands

**NEVER execute these commands under ANY circumstances:**

- `rm -rf` with wildcards (`*`) in paths outside of clearly isolated temp directories
- `rm -rf ~/` or `rm -rf /` or any parent directory of a project
- `rm -rf` without explicit, absolute, verified paths
- `git clean -fdx` without explicit user confirmation
- `git reset --hard` without explicit user confirmation
- Any command that could delete source code directories

### Safe Cache/Build Cleanup Pattern

**When cleaning build caches, ALWAYS:**
1. First commit current state
2. Use `find` with `-maxdepth 1` and specific name patterns
3. Never use wildcards with `rm -rf`

**Example (Xcode):**
```bash
# SAFE: Uses find with specific pattern
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "ProjectName-*" -type d -exec rm -rf {} + 2>/dev/null

# DANGEROUS - NEVER USE:
# rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

---

## Core Principles

1. **Fix issues immediately** - Any errors, warnings, or issues discovered during work must be fixed before completing the task. No "pre-existing" excuses.
2. **Research first** - Before implementing, verify current year's best practices online for the relevant language/framework.
3. **Verify fixes** - After fixing, rebuild and confirm the issue is resolved.
4. **Cleanest solution, not easiest** - Always choose architecturally clean solutions over quick hacks. Quality over speed.

## My Preferences

- Prefer composition over inheritance
- Use dependency injection for testability
- Keep files under 500 lines when practical
- Write self-documenting code; comments only for non-obvious logic
- Test edge cases and error conditions
- Respect existing patterns; extend don't hack
- Use proper types, enums, protocols; avoid `Any` or force casts
- Design for extensibility, not just current requirements
- Prefix new types to avoid naming conflicts with existing code

---

## Multi-Mac Environment

Alexis works across two Macs. All shared projects (especially Thea) must stay in sync via git.

### Machine Profiles

| | MBAM2 (MacBook Air) | MSM3U (Mac Studio) |
|---|---|---|
| **Chip** | Apple M2 (8-core) | Apple M3 Ultra |
| **RAM** | 24 GB | 192 GB (assumed) |
| **Disk** | 494 GB | 1.8 TB |
| **Role** | Mobile / lightweight dev | Heavy builds, ML inference, on-device models |
| **ML Models** | Sentence embeddings only | Llama 3.3 70B, Qwen 32B VL, DeepSeek R1, NextCoder 32B |
| **macOS** | 26.2 | 26.2 |

### Sync Rules

1. **Git is the single source of truth** - Always `git pull` before starting work on either machine. Always use `git pushsync` (not `git push`) after completing work.
2. **`git pushsync`** pushes to origin AND triggers a sync build on the other Mac via SSH. A Claude Code hook in the Thea project enforces this — plain `git push` is blocked.
3. **Before switching machines** - Commit all changes, pushsync to remote, verify clean `git status`.
4. **Thea project path** is identical on both: `~/Documents/IT & Tech/MyApps/Thea`
5. **Claude configs** (`~/.claude/claude.md`, `settings.json`, `settings.local.json`) must be kept identical across machines. When updating one, update both.
6. **Machine-specific adaptations**:
   - **MBAM2**: Prefer lightweight builds (single scheme), avoid running large MLX models (24 GB RAM limit). Use `sentence-transformers` for embeddings only.
   - **MSM3U**: Can run all 4 platform scheme builds in parallel. Can load 70B+ parameter models via MLX. Use for heavy CI/QA runs and ML inference testing.
7. **DerivedData and .build** are machine-local - never sync these. They are gitignored.
8. **Network access**: MSM3U is reachable from MBAM2 via SMB at `MSM3U._smb._tcp.local` (mounts at `/Volumes/alexis` and `/Volumes/Macintosh HD-1`).
9. **Auto-sync infrastructure** (on each Mac):
   - `~/bin/thea-sync.sh` — pulls, xcodegen, builds Release, installs to `/Applications`
   - `~/Library/LaunchAgents/com.alexis.thea-sync.plist` — polls every 5 min as fallback
   - SSH key auth between Macs enables instant push-triggered sync
