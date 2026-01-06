.PHONY: test test-backend test-watch test-coverage test-coverage-local clean clean-cache logs shell-test help

# デフォルトターゲット
.DEFAULT_GOAL := help

# ヘルプ表示
help:
	@echo "Voro Test Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test            - Run all tests (backend)"
	@echo "  make test-backend    - Run backend tests in Docker"
	@echo "  make test-watch      - Run tests in watch mode (auto-rerun)"
	@echo "  make test-coverage   - Run tests with coverage report (Docker)"
	@echo "  make test-coverage-local - Run tests with coverage report (local)"
	@echo "  make clean           - Clean up Docker containers and volumes"
	@echo "  make clean-cache     - Clear all project caches (FASL, Vite)"
	@echo "  make logs            - Show test runner logs"
	@echo "  make shell-test      - Open shell in test runner container"
	@echo "  make help            - Show this help message"

# フルテスト実行
test: test-backend

# バックエンドテスト（Docker）
test-backend:
	@echo "========== Running backend tests in Docker =========="
	@export HOST_UID=$$(id -u) HOST_GID=$$(id -g); \
	docker compose -f docker-compose.test.yml up --build --abort-on-container-exit test-runner; \
	EXIT_CODE=$$?; \
	docker compose -f docker-compose.test.yml down -v; \
	exit $$EXIT_CODE

# Watch mode（開発時）
test-watch:
	@echo "========== Starting test watcher (press Ctrl+C to stop) =========="
	docker compose -f docker-compose.test.yml up --build test-watcher

# カバレッジ測定（Docker環境）
# 注意: docker compose up を使用して depends_on の service_healthy を待機する
test-coverage:
	@echo "========== Running tests with coverage =========="
	@mkdir -p coverage-report
	@export HOST_UID=$$(id -u) HOST_GID=$$(id -g); \
	docker compose -f docker-compose.test.yml up --build --abort-on-container-exit test-coverage-runner; \
	EXIT_CODE=$$?; \
	docker compose -f docker-compose.test.yml down -v; \
	echo "Coverage report: coverage-report/cover-index.html"; \
	exit $$EXIT_CODE

# ローカル環境でのカバレッジ測定（Docker不要）
test-coverage-local:
	@echo "========== Running tests with coverage (local) =========="
	@mkdir -p coverage-report
	sbcl --non-interactive \
	     --load scripts/run-coverage.lisp
	@echo "Coverage report: coverage-report/cover-index.html"

# クリーンアップ
clean:
	@echo "========== Cleaning up Docker resources =========="
	docker compose -f docker-compose.test.yml down -v --remove-orphans
	rm -rf var/tmp/*.log coverage-report/
	@echo "Cleanup complete"

# キャッシュクリア（FASL, Vite）
# scripts/clean-cache.sh に処理を委譲（-y オプションで確認なし）
clean-cache:
	@./scripts/clean-cache.sh -y

# ログ表示
logs:
	docker compose -f docker-compose.test.yml logs -f test-runner

# デバッグ用シェル
shell-test:
	@echo "========== Opening shell in test runner container =========="
	docker compose -f docker-compose.test.yml run --rm test-runner /bin/bash
