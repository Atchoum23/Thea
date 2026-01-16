#!/bin/bash
cd "$(dirname "$0")"
git add Tests/Info.plist
git commit -m 'chore: Add Tests/Info.plist for XcodeGen test target

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>' 2>/dev/null || echo "Already committed or no changes"
git push origin main
git status
