#\!/bin/bash
# MSM3U Autonomous QA Execution - Parallel Phases

cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== MSM3U QA Batch Execution Started: $(date) ===" | tee -a ~/.claude/msm3u-qa.log

# Launch parallel QA phases via tmux sessions
tmux new-session -d -s qa-phase1 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 0-2 (Environment + SwiftLint + Package Tests): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phases 0, 0.5, 1, 2 autonomously. Fix all issues. Commit results.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 50 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase1.log 2>&1"

sleep 2

tmux new-session -d -s qa-phase2 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 3-4 (Sanitizers + Debug Builds): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phases 3, 4 autonomously. Build all 4 platforms in Debug. Fix all issues. Commit results.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 50 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase2.log 2>&1"

sleep 2

tmux new-session -d -s qa-phase3 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 5 (Release Builds): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phase 5 autonomously. Build all 4 platforms in Release. Fix all issues. Commit results.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 50 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase3.log 2>&1"

sleep 2

tmux new-session -d -s qa-phase4 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 5.5 (Xcode GUI Builds): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phase 5.5 autonomously. Build all 4 platforms via Xcode. Fix all issues. Commit results.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 50 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase4.log 2>&1"

sleep 2

tmux new-session -d -s qa-phase5 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 6-7 (Memory + Security): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phases 6, 7 autonomously. Run memory/runtime verification and security audit. Fix all issues. Commit results.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 50 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase5.log 2>&1"

sleep 2

tmux new-session -d -s qa-phase6 "cd ~/Documents/IT\ \&\ Tech/MyApps/Thea && echo 'Execute Phase 8-11 (Final): Read .claude/COMPREHENSIVE_QA_PLAN.md and execute phases 8, 9, 10, 11, 11.5 autonomously. Verify, commit, update docs, monitor CI/CD. Fix all issues.' | claude --dangerously-skip-permissions -p - --verbose --max-turns 75 --model claude-opus-4-6 --output-format stream-json > ~/.claude/qa-phase6.log 2>&1"

echo "=== All 6 QA phase sessions launched ===" | tee -a ~/.claude/msm3u-qa.log
echo "Monitor with: tmux ls" | tee -a ~/.claude/msm3u-qa.log
echo "View logs: tail -f ~/.claude/qa-phase*.log" | tee -a ~/.claude/msm3u-qa.log
