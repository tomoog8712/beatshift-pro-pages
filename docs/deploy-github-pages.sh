#!/bin/bash
# BeatShift Pro — GitHub Pages 公開スクリプト
# 使い方:
#   1. GitHub CLI をインストール: brew install gh
#   2. ログイン: gh auth login   （ブラウザ認証。パスワードはターミナルに入力しない）
#   3. 実行: ./docs/deploy-github-pages.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO_NAME="${1:-beatshift-pro-pages}"
VISIBILITY="${2:-public}"  # public | private

echo "==> リポジトリ名: $REPO_NAME"

if ! command -v gh >/dev/null 2>&1; then
  echo "エラー: GitHub CLI (gh) がありません。"
  echo "  brew install gh"
  echo "  gh auth login"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "エラー: GitHub にログインしていません。"
  echo "  gh auth login"
  echo "  （Google アカウント連携の GitHub でも、gh auth login でブラウザ認証してください）"
  exit 1
fi

# git 初期化
if [ ! -d .git ]; then
  git init
  git branch -M main
fi

# .gitignore（なければ追加）
if [ ! -f .gitignore ]; then
  cat > .gitignore <<'EOF'
.DS_Store
*.xcuserstate
xcuserdata/
DerivedData/
build/
*.ipa
*.dSYM.zip
.cursor/
EOF
fi

git add docs/
git add .gitignore 2>/dev/null || true

if git diff --cached --quiet; then
  echo "==> コミットする変更がありません（docs は既に最新）"
else
  git commit -m "$(cat <<'EOF'
Add GitHub Pages support and privacy policy

Publish support and privacy policy pages for App Store Connect.
EOF
)"
fi

# リモート作成 or 取得
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "==> GitHub リポジトリを作成: $REPO_NAME"
  gh repo create "$REPO_NAME" --"${VISIBILITY}" --source=. --remote=origin --push
else
  echo "==> origin へ push"
  git push -u origin main
fi

OWNER="$(gh repo view --json owner -q .owner.login)"
FULL="$OWNER/$REPO_NAME"

echo "==> GitHub Pages を有効化 (/docs)"
gh api "repos/${FULL}/pages" -X POST \
  -f build_type=legacy \
  -f source[branch]=main \
  -f source[path]=/docs 2>/dev/null || \
gh api "repos/${FULL}/pages" -X PUT \
  -f build_type=legacy \
  -f source[branch]=main \
  -f source[path]=/docs

echo ""
echo "=========================================="
echo "  公開完了（反映まで 1〜2 分）"
echo "=========================================="
echo "  サポート URL:"
echo "    https://${OWNER}.github.io/${REPO_NAME}/support.html"
echo ""
echo "  プライバシーポリシー URL:"
echo "    https://${OWNER}.github.io/${REPO_NAME}/privacy.html"
echo ""
echo "  App Store Connect に上記 URL を入力してください。"
echo "=========================================="
