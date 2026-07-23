#!/usr/bin/env bash
# Sync the HTML app into the iOS bundle folder (excludes demo / Windows helpers).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/app"
DST="$ROOT/ios/BeatShiftPro/WebRoot"

mkdir -p "$DST"
rsync -a --delete \
  --exclude 'svg-notes-demo' \
  --exclude '.DS_Store' \
  "$SRC/" "$DST/"

echo "Synced WebRoot ← app ($(find "$DST" -type f | wc -l | tr -d ' ') files)"
