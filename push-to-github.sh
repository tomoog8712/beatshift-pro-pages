#!/bin/bash
set -euo pipefail
cd /Users/tomoog8712/Desktop/voicetest-3
OUT="/Users/tomoog8712/Desktop/voicetest-3/.git-push-log.txt"
{
  echo "=== STATUS ==="
  git status -sb
  echo "=== REMOTE ==="
  git remote -v
  echo "=== LOG ==="
  git log -5 --oneline
  echo "=== DIFF STAT ==="
  git diff --stat
  echo "=== ADD ==="
  git add -A
  # unstage build artifacts if any
  git reset HEAD -- ios/build 2>/dev/null || true
  git status -sb
  echo "=== COMMIT ==="
  if git diff --cached --quiet; then
    echo "Nothing to commit"
  else
    git commit -m "$(cat <<'EOF'
Ship BeatShift Pro iOS release updates

Add AdMob/IAP/review prompt, expand SEQ BPM to 1–500, and store docs for App Store listing.
EOF
)"
  fi
  echo "=== PUSH ==="
  git push -u origin main
  echo "=== FINAL ==="
  git status -sb
  git log -1 --oneline
} > "$OUT" 2>&1
echo DONE >> "$OUT"
