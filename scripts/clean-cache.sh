#!/usr/bin/env bash
#
# clean-cache.sh - プロジェクトのキャッシュをクリーンアップ
#
# このスクリプトは、プロジェクト内の .cache/ ディレクトリを
# 安全に削除します。ホームディレクトリには一切触れません。
#
# キャッシュ構成:
#   .cache/
#   ├── fasl/  - Common Lisp コンパイル済みファイル
#   └── vite/  - Vite 開発サーバーキャッシュ
#
# 使い方:
#   ./scripts/clean-cache.sh
#
# 推奨: make clean-cache を使用してください

set -e  # エラーが発生したら即座に終了

# プロジェクトディレクトリを動的に算出
# 環境変数 VORO_PROJECT_DIR が設定されていればそれを使用
# そうでなければスクリプトの位置から親ディレクトリを算出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${VORO_PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
CACHE_DIR="${PROJECT_DIR}/.cache"

echo "========================================="
echo "  Voro Cache Cleanup"
echo "========================================="
echo ""

# カレントディレクトリを確認
if [ "$(pwd)" != "$PROJECT_DIR" ]; then
  echo "⚠️  Warning: Not in project directory"
  echo "   Current: $(pwd)"
  echo "   Expected: $PROJECT_DIR"
  echo ""
  echo "   Changing directory to project root..."
  cd "$PROJECT_DIR"
fi

# キャッシュディレクトリの存在確認
if [ ! -d "$CACHE_DIR" ]; then
  echo "✅ Cache directory does not exist. Nothing to clean."
  exit 0
fi

# キャッシュの内容を表示
echo "📁 Cache directory: $CACHE_DIR"
echo ""
echo "Contents:"
du -sh "$CACHE_DIR"
echo ""
FASL_COUNT=$(find "$CACHE_DIR" -name "*.fasl" 2>/dev/null | wc -l | tr -d ' ')
echo "   FASL files: $FASL_COUNT"
echo ""

# 確認（オプション: -y フラグで自動削除）
if [ "$1" != "-y" ]; then
  read -p "Delete cache directory? [y/N]: " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

# 削除実行（安全チェック付き）
# 条件:
#   1. CACHE_DIR が PROJECT_DIR/.cache と一致
#   2. PROJECT_DIR に .git が存在（プロジェクトルートの確認）
#   3. PROJECT_DIR がルート(/)やホームディレクトリでない
safe_to_delete=false

if [[ "$CACHE_DIR" == "$PROJECT_DIR/.cache" ]] && \
   [[ -d "$PROJECT_DIR/.git" ]] && \
   [[ "$PROJECT_DIR" != "/" ]] && \
   [[ "$PROJECT_DIR" != "$HOME" ]] && \
   [[ "$PROJECT_DIR" != "$HOME/" ]]; then
  safe_to_delete=true
fi

if [[ "$safe_to_delete" == "true" ]]; then
  echo "🗑️  Removing cache directory..."
  rm -rf "$CACHE_DIR"
  echo "✅ Cache cleaned successfully!"
  echo ""
  echo "   Next run will regenerate the cache."
  echo ""
  echo "   Tip: Use 'make clean-cache' for convenience."
else
  echo "❌ Error: Safety check failed!"
  echo "   Cache directory path does not look safe: $CACHE_DIR"
  echo ""
  echo "   Safety requirements:"
  echo "   - CACHE_DIR must be PROJECT_DIR/.cache"
  echo "   - PROJECT_DIR must contain .git directory"
  echo "   - PROJECT_DIR must not be / or \$HOME"
  exit 1
fi
