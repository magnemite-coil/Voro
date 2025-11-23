#!/bin/bash
set -euo pipefail

# テスト実行スクリプト
# Docker内でテストを実行するためのヘルパースクリプト

echo "=========================================="
echo "Voro Test Runner"
echo "=========================================="

# 環境変数チェック
echo "[INFO] Checking environment variables..."
if [ "${APP_ENV:-}" != "test" ]; then
    echo "[ERROR] APP_ENV must be 'test', got: ${APP_ENV:-none}"
    exit 1
fi

if [ "${TEST_MODE:-}" != "true" ]; then
    echo "[ERROR] TEST_MODE must be 'true', got: ${TEST_MODE:-none}"
    exit 1
fi

echo "[OK] Environment variables validated"
echo ""

# データベース接続待機
echo "[INFO] Waiting for database connection..."
until psql -h "${DB_HOST}" -U "${TEST_DB_USER}" -d "${TEST_DB_NAME}" -c '\q' 2>/dev/null; do
    echo "[WAIT] Database not ready, retrying in 1 second..."
    sleep 1
done
echo "[OK] Database connection established"
echo ""

# Redis接続待機
echo "[INFO] Waiting for Redis connection..."
until redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping 2>/dev/null | grep -q PONG; do
    echo "[WAIT] Redis not ready, retrying in 1 second..."
    sleep 1
done
echo "[OK] Redis connection established"
echo ""

# SBCL情報表示
echo "[INFO] SBCL Version:"
sbcl --version
echo ""

# テスト実行
echo "=========================================="
echo "Running tests..."
echo "=========================================="
echo ""

sbcl --non-interactive \
     --eval "(push #P\"/app/\" asdf:*central-registry*)" \
     --eval "(ql:quickload :voro/test :silent t)" \
     --eval "(asdf:test-system :voro/test)" \
     --eval "(quit)"

EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ All tests passed"
else
    echo "✗ Tests failed with exit code: $EXIT_CODE"
fi
echo "=========================================="

exit $EXIT_CODE
