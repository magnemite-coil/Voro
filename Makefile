.PHONY: test test-backend test-watch test-coverage clean logs shell-test help

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
	@echo "  make test-coverage   - Run tests with coverage report"
	@echo "  make clean           - Clean up Docker containers and volumes"
	@echo "  make logs            - Show test runner logs"
	@echo "  make shell-test      - Open shell in test runner container"
	@echo "  make help            - Show this help message"

# フルテスト実行
test: test-backend

# バックエンドテスト（Docker）
test-backend:
	@echo "========== Running backend tests in Docker =========="
	@export HOST_UID=$$(id -u) HOST_GID=$$(id -g); \
	docker compose -f docker-compose.test.yml up --build --abort-on-container-exit; \
	EXIT_CODE=$$?; \
	docker compose -f docker-compose.test.yml down -v; \
	exit $$EXIT_CODE

# Watch mode（開発時）
test-watch:
	@echo "========== Starting test watcher (press Ctrl+C to stop) =========="
	docker compose -f docker-compose.test.yml up --build test-watcher

# カバレッジ測定（CI用）
test-coverage:
	@echo "========== Running tests with coverage =========="
	./scripts/run-coverage.sh

# クリーンアップ
clean:
	@echo "========== Cleaning up Docker resources =========="
	docker compose -f docker-compose.test.yml down -v --remove-orphans
	rm -rf var/tmp/*.log coverage-report/
	@echo "Cleanup complete"

# ログ表示
logs:
	docker compose -f docker-compose.test.yml logs -f test-runner

# デバッグ用シェル
shell-test:
	@echo "========== Opening shell in test runner container =========="
	docker compose -f docker-compose.test.yml run --rm test-runner /bin/bash
