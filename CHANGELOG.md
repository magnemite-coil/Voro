# Changelog

All notable changes to the Voro project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed - Remove Duplicate Code in Handler Layer

#### Middleware Enhancement
- **src/middleware/session.lisp**: Added `get-current-user-id` function
  - Extracts user_id from request session cookie
  - Returns user_id (integer) or NIL (unauthenticated)
  - Takes `request` as argument (Caveman2-independent design)
  - Added to package exports

#### Handler Refactoring
- **src/handler/auth.lisp**: Removed duplicate code
  - Deleted `get-request-body-param` wrapper function
  - Use `get-body-param` from `voro.util.request` directly
  - No changes to external API behavior
- **src/handler/post.lisp**: Removed duplicate code
  - Deleted `get-request-body-param` wrapper function
  - Deleted `get-current-user-id` local function
  - Changed import from `get-session-user-id` to `get-current-user-id`
  - Use `get-body-param` from `voro.util.request` directly
  - Updated comments to reflect consolidation

#### Design Principles
- Layer structure compliance: handler → service → model
- Separation of concerns: common logic in appropriate layers
- No breaking changes: existing behavior preserved

#### Test Coverage
- All 6 backend test suites passing
- Manual API testing verified:
  - Authentication flow (register/login/logout)
  - Post CRUD operations
  - Error cases (401/400/403/404)

### Commits

- Branch: `refactor/remove-duplicate-code`
- `0db29c3` refactor: Remove duplicate code in handler layer

## [0.3.1] - 2025-12-03

### Fixed - Post Editor Bugs and UX Improvements

#### Navigation and Form State
- **useNavigationBlocker.ts**: Skip navigation blocker during save operations
  - Prevents false warning dialog when saving/publishing posts
  - Uses `skipBlockerRef` to temporarily disable blocker during API calls
- **PostEditorPage.tsx**: Reset form when switching to create mode
  - Clears title, content, and errors when navigating from edit to create
  - Prevents stale data from previous edits appearing in new post form

#### New Post Creation Flow
- **Header.tsx**: Added `onNewPostClick` handler for same-page navigation warning
  - Shows confirmation modal when clicking "新規作成" with unsaved changes
  - Properly integrates with existing unsaved changes detection
- **PostEditorPage.tsx**: Improved publish button logic
  - Publish button now disabled in create mode (must save as draft first)
  - Only active when editing a saved draft (not yet published)
  - Prevents confusing UX where publish was available before first save

#### Backend Authentication
- **src/handler/auth.lisp**: Trim whitespace from login inputs
  - Username and password are trimmed before validation
  - Prevents login failures due to accidental leading/trailing spaces

### Changed - Test Updates

- **PostEditorPage.test.tsx**: Updated tests for new publish button behavior
  - Publish button is now disabled in create mode
  - Added test for publishing draft post in edit mode
  - 11 test cases (was 10)

### Commits

- Branch: `fix/post-editor-bug`
- `1c205fb` fix: Fix post editor bugs and login input trimming
- `60558cc` fix: Add new post confirmation and improve publish button logic
- `fd31ec9` test: Update PostEditorPage tests for new publish button behavior

## [0.3.0] - 2025-12-02

### Added - Post Editor UI (Frontend Phase 4.5)

#### Project Setup
- **Vite + React 19 + TypeScript**: Modern frontend stack
  - Vite 7.2 with React 19 support
  - TypeScript with strict mode
  - React Router v7 for client-side routing
  - Vitest + MSW for testing

#### Design System
- **Synthwave '84 Theme**: Cyberpunk-inspired design tokens
  - CSS Variables for colors, typography, spacing
  - Global styles and CSS reset
  - CSS Modules for component styling

#### Common Components
- **frontend/src/components/common/**:
  - `Button`: Primary/secondary variants with loading state
  - `Spinner`: Loading indicator
  - `Toast`: Success/error/info notifications with auto-dismiss
  - `ConfirmModal`: Unsaved changes confirmation dialog
  - `Header`: Navigation with auth state
  - `ProtectedRoute`: Auth-required route wrapper

#### Post Editor
- **frontend/src/components/post/**:
  - `TitleInput`: Title field with character count (max 200)
  - `ContentEditor`: Textarea with character count (max 100,000)
- **frontend/src/pages/PostEditorPage/**:
  - Create/Edit modes with dynamic routing
  - Form validation (onBlur + submit)
  - Unsaved changes warning (beforeunload + React Router blocker)

#### Authentication
- **frontend/src/contexts/AuthContext.tsx**:
  - Login/logout functionality
  - Session persistence with localStorage
  - Auth state management
- **frontend/src/contexts/NotificationContext.tsx**:
  - Toast notification system
  - Auto-dismiss with timer cleanup

#### Custom Hooks
- **frontend/src/hooks/**:
  - `usePost`: Post CRUD operations with API integration
  - `useNavigationBlocker`: React Router navigation blocking
  - `useUnsavedChangesWarning`: Combined beforeunload + blocker

#### Services
- **frontend/src/services/api.ts**:
  - Type-safe API client
  - Error handling with ApiError class
  - Credentials included for session cookies

#### Validation
- **frontend/src/utils/validation.ts**:
  - Title validation (1-200 chars, not whitespace-only)
  - Content validation (1-100,000 chars)
  - Field-level error messages

#### Testing
- **Vitest + MSW**: Comprehensive test setup
  - Mock Service Worker for API mocking
  - Test helper with window.scrollTo mock for jsdom
- **test/mocks/handlers.ts**: Common MSW handlers for API mocking
- **test/mocks/server.ts**: MSW server setup

### Added - Component and Integration Tests (2025-12-02)

#### Component Tests
- **TitleInput.test.tsx**: 8 test cases
  - Placeholder and value display
  - onChange callback
  - Error message display and styling
  - onValidate callback on blur
  - Loading state (readonly, loading class)
- **ContentEditor.test.tsx**: 9 test cases
  - Same coverage as TitleInput
  - Additional rows attribute test

#### Integration Tests
- **PostEditorPage.test.tsx**: 10 test cases
  - Create Mode: UI render, button states, validation, create/publish
  - Edit Mode: Load existing post, 404 handling, update
  - API Error Handling: Server error notification

#### Test Infrastructure
- **test/setup.ts**: Added window.scrollTo mock for jsdom compatibility

**Test Summary**: 40 tests total (all passing)
- validation.test.ts: 13 tests
- TitleInput.test.tsx: 8 tests
- ContentEditor.test.tsx: 9 tests
- PostEditorPage.test.tsx: 10 tests

### Fixed - ESLint Warnings in Context Hooks

- **AuthContext.tsx**: Added eslint-disable comments for intentional patterns
  - `react-hooks/set-state-in-effect`: Initial auth check is intentional
  - `react-refresh/only-export-components`: useAuth hook export
- **NotificationContext.tsx**: Fixed useEffect cleanup
  - Capture ref value before cleanup function
  - Prevents stale ref access on unmount
  - Added `react-refresh/only-export-components` disable

### Verified - All Tests Passing

Frontend test suite fully operational (2025-12-02):

- ✅ **Frontend tests**: 40/40 passed
  - validation.test.ts: 13 tests
  - TitleInput.test.tsx: 8 tests
  - ContentEditor.test.tsx: 9 tests
  - PostEditorPage.test.tsx: 10 tests
- ✅ **ESLint**: No errors
- ✅ **TypeScript**: No type errors
- ✅ **Build**: Successful (dist/ output)
  - `index.html`: 0.46 kB
  - `index.css`: 10.32 kB (gzip: 2.57 kB)
  - `index.js`: 293.62 kB (gzip: 94.44 kB)

### Commits

- Branch: `feat/post-editor-ui`
- `fbae2ba` feat(frontend): Add post editor UI with React 19 + Vite
- `86db17b` fix(frontend): Fix ESLint warnings in context hooks
- `6985cc9` test(frontend): Add component and integration tests for post editor

## [0.2.1] - 2025-11-30

### Added - Published Parameter Test Coverage

#### New Test Cases
- **test/handler/post-test.lisp**: Added 2 test cases for comprehensive published parameter coverage
  - `post-update-unpublish-test`: Verify changing published from true to false
  - `post-update-no-publish-change-test`: Verify published remains unchanged when not included in request body

These tests ensure the three states of published parameter (`t`, `nil`, `:not-specified`) are properly handled during post updates.

#### Design Document Update
- **docs/design/post-crud-api.md**: Updated to v2.4
  - Changed `:keys` to `:indexes` for Mito index definition (matches implementation)
  - Updated SXQL column references to underscore format (`:user_id`, `:created_at`)
  - Updated `count-user-posts` to use `mito:count-dao` for `:all` case (optimization)
  - Marked remaining tasks as completed

### Verified - All Tests Passing

- ✅ **20/20 post handler test cases** (was 18)
- ✅ All 6 test suites passing

### Commits

- Branch: `docs/update-design-v2.4`
- `40c3468` test(post): Add missing published parameter tests

## [0.2.0] - 2025-11-30

### Added - Post CRUD API (Phase 4)

#### Post Model and Service
- **src/model/post.lisp**: Post model with Mito ORM
  - `post` table with `user_id`, `title`, `content`, `published` columns
  - Index on `user_id` for efficient user-based queries
  - Query functions: `find-post-by-id`, `find-posts-by-user-id`, `find-published-posts`
  - Count functions: `count-published-posts`, `count-user-posts`
  - `post-to-alist` for JSON serialization
- **src/service/post.lisp**: Business logic layer
  - `create-new-post`: Create post with validation
  - `get-post`: Get post with permission check (public/owner access)
  - `update-post`: Update post with ownership verification
  - `delete-post`: Delete post with ownership verification
  - `list-published-posts`: Paginated public post listing
  - `list-user-posts`: User's public posts
  - `list-my-posts`: User's own posts (including drafts)
  - Title validation (1-200 chars, no whitespace-only)
  - Content validation (1-100,000 chars, DoS protection)
  - Pagination normalization (page max: 10,000, per_page max: 100)

#### REST API Endpoints
- **src/handler/post.lisp**: HTTP handlers
  - `POST /api/posts` - Create post (auth required, 201 Created)
  - `GET /api/posts` - List published posts (no auth)
  - `GET /api/posts/:id` - Get post details (conditional auth)
  - `PUT /api/posts/:id` - Update post (owner only)
  - `DELETE /api/posts/:id` - Delete post (owner only)
  - `GET /api/users/:user_id/posts` - User's public posts
  - `GET /api/me/posts` - Own posts with filter (auth required)

#### Error Types
- **src/util/validation.lisp**: Added new error conditions
  - `authorization-error`: 403 Forbidden (not owner)
  - `not-found-error`: 404 Not Found (resource missing)

#### Comprehensive Test Suite
- **test/model-test.lisp**: Post model tests (12 test cases)
  - CRUD operations, queries, filtering, counting
- **test/service-test.lisp**: Post service tests (9 test cases)
  - Authorization, validation, error handling
- **test/handler/post-test.lisp**: HTTP integration tests (20 test cases)
  - All endpoints, success/error scenarios
  - Published/draft access control
  - Pagination, filtering

### Fixed - Makefile Test Runner Issue

- **Makefile**: Fixed concurrent test runner conflict
  - Problem: `make test` ran both `test-runner` and `test-watcher` simultaneously
  - Cause: Same database used by both runners, causing duplicate key errors
  - Solution: Run only `test-runner` service for `make test`
  - `test-watcher` remains available via `make test-watch`

### Verified - All Tests Passing

Docker test suite fully operational (2025-11-30):

- ✅ **6/6 test suites successful**
  - voro.test.util
  - voro.test.model (including Post)
  - voro.test.service (including Post)
  - voro.test.handler
  - voro.test.handler.auth
  - voro.test.handler.post (20 test cases)
- ✅ **All Post API endpoints working**
- ✅ **Authorization and permission checks verified**
- ✅ **Pagination and filtering working**

### Documentation

- **docs/design/post-crud-api.md**: Updated to v2.4
  - Complete API specification
  - Implementation patterns documented
  - Test plan with 20 handler test cases

### Commits

- Branch: `feature/post-crud-api`
- `c6db949` feat: implement Post CRUD API

## [0.1.9] - 2025-11-26

### Changed - JSON Library Migration (Jonathan → Jzon)

#### Migration Reason
- Jonathan has non-standard extensions (not fully RFC 8259 compliant)
- Jzon provides "sane defaults" with safety-first design
- Jzon is actively maintained

#### Files Changed
- **src/util/json.lisp**: New wrapper module for Jzon
  - `to-json`: Convert alist to JSON string
  - `to-json-plist`: Convert plist to JSON string
  - `parse-json`: Parse JSON string to hash-table
  - `alist-to-hash-table-recursive`: Recursive alist conversion (handles nested structures)
  - `alist-value-to-jzon`: Handle nil as false in alist values
  - `plist-to-hash-table`: Plist to hash-table conversion
- **voro.asd**: Changed dependency from `:jonathan` to `:com.inuoe.jzon`
- **src/util/response.lisp**: Use `voro.util.json:to-json` instead of `jonathan:to-json`
- **src/util/log.lisp**: Use `voro.util.json:to-json-plist` instead of `jonathan:to-json`
- **test/http-helper.lisp**: Use `jzon:stringify` and `jzon:parse` instead of Jonathan functions
- **test/util-test.lisp**: Added comprehensive tests for JSON conversion functions (5 new test cases)

#### Breaking Changes
- `:false` keyword is no longer supported for JSON `false` - use `nil` instead
- JSON parsing returns hash-tables by default (not alists)

#### Verified
- ✅ System loads successfully
- ✅ JSON conversion (alist/plist) works correctly
- ✅ Boolean output (true/false) correct
- ✅ Nested alist conversion works
- ✅ All unit tests pass (voro.test.util: 69 test cases)

### Documentation Updates

- **docs/testing/troubleshooting.md**: Updated sample code to use Jzon
  - `jonathan:parse` → `jzon:parse`
  - `jonathan:to-json` → `jzon:stringify`
- **docs/design/jonathan-to-jzon-migration.md**: Added troubleshooting.md to documentation update checklist

### Commits

- Branch: `refactor/jonathan-to-jzon`
- `0ed0c75` refactor: migrate JSON library from Jonathan to Jzon

## [0.1.8] - 2025-11-26

### Fixed - Docker Test Infrastructure Improvements

#### Dockerfile.test Dependency Loading
- **Problem**: `voro.asd`-based dependency loading failed during Docker build
  - `voro.asd` references `src/` directory which isn't available during build time
  - Only mounted as volume at runtime, not during `docker build`
- **Solution**: Changed to individual package loading
  - Explicitly load: `:caveman2`, `:mito`, `:cl-redis`, `:rove`, `:dexador`
  - Ensures dependencies are cached in Docker image layer
  - Maintains fast subsequent builds

#### FASL Cache Volume Path
- **Problem**: FASL cache volume mounted to wrong path
  - Was: `/home/lispuser/quicklisp` (Quicklisp installation directory)
  - FASL files are compiled to `~/.cache/common-lisp/`, not Quicklisp dir
- **Solution**: Corrected volume mount path
  - Now: `/home/lispuser/.cache/common-lisp`
  - Properly caches compiled FASL files across container runs

#### Test Watcher Command Syntax
- **Problem**: `test-watcher` service command failed with shell parsing errors
  - YAML multi-line string `>` folded newlines incorrectly
  - `sbcl --eval` arguments parsed as separate shell commands
  - Error: `sh: 4: --eval: not found`
- **Solution**: Changed to explicit array format with proper escaping
  - Used `command: [sh, -c, |...]` syntax
  - Proper backslash continuation for sbcl arguments
  - Watch mode now works correctly with 5-second polling

### Verified - All Tests Passing

Docker test suite fully operational (2025-11-26):

- ✅ **5/5 test suites successful** (62 test cases)
- ✅ **test-runner**: Exit code 0, all tests pass
- ✅ **test-watcher**: Continuous test execution working
- ✅ **FASL caching**: Persistent across container restarts
- ✅ **Volume cleanup**: No more "file exists" errors

### Commits

- Branch: `fix/hook-exit-code`
- `6fe5c89` fix(docker): improve dependency loading and FASL cache path

## [0.1.7] - 2025-11-25

### Added - Comprehensive Testing Documentation (Phase 5)

#### Testing Documentation Suite
- **docs/testing/README.md**: Test execution quick start guide
  - Quick start for running tests with Docker
  - Test suite overview (62 test cases across 5 suites)
  - 8-layer defense system explanation
  - Coverage goals by layer (Util: 90%+, Model/Service: 80%+, Handler: 70%+)
  - Development workflow and troubleshooting tips

- **docs/testing/backend-guide.md**: Comprehensive backend test development guide
  - Test writing patterns for each layer (Util/Model/Service/Handler)
  - HTTP integration testing with http-helper
  - Test fixtures usage (create-test-user, create-test-session)
  - Best practices (Arrange-Act-Assert pattern, test independence)
  - Common testing patterns and anti-patterns
  - Debugging tips with REPL and log output

- **docs/testing/troubleshooting.md**: Troubleshooting guide
  - Environment issues (Docker, Quicklisp, environment variables)
  - Database issues (8-layer defense, connection errors, transaction rollback)
  - Redis connection problems
  - HTTP integration test debugging
  - Performance optimization tips
  - Comprehensive debugging techniques

#### Documentation Benefits
- Clear testing strategy for new contributors
- Reduced onboarding time with practical examples
- Troubleshooting guide for common issues

## [0.1.6] - 2025-11-25

### Added - CI/CD Integration (Phase 4)

#### GitHub Actions Workflow
- **.github/workflows/ci-backend.yml**: Automated testing pipeline
  - **Service Containers**: PostgreSQL 15 and Redis 7 with health checks
  - **SBCL Installation**: Automated Common Lisp environment setup
  - **Quicklisp Management**: Dependency installation with caching
  - **Multi-layer Caching Strategy**:
    - SBCL binaries (`/usr/local/bin/sbcl`, `/usr/local/lib/sbcl`)
    - Quicklisp libraries (`~/quicklisp`)
    - Compiled FASL files (`~/.cache/common-lisp`)
    - Cache key includes `voro.asd` hash for invalidation
  - **Timeout Protection**: 10 minutes for Quicklisp, 15 minutes for tests
  - **Test Result Artifacts**: Failed test logs uploaded for debugging
  - **Trigger Events**: Pull requests and pushes to main branch

#### CI/CD Benefits
- Automated test execution on every PR
- Fast feedback with comprehensive caching
- Test result preservation for debugging
- Prevents merging broken code to main branch

### Added - Git Ignore Protection (Security Enhancement)

#### Pre-commit Hook Enhancement
- **.git/hooks/pre-commit**: Enhanced with .gitignore violation detection
  - Check 1: Prevent direct commits to main/master branch
  - Check 2: Prevent committing .gitignore violations
    - Dynamic verification with `git check-ignore`
    - Explicit pattern matching for critical files
    - Detailed error messages with remediation steps

#### Claude Code Tool Hook Enhancement
- **.claude/hooks/tool-call.sh**: Block git add -f for ignored files
  - Detects `git add -f` commands targeting ignored patterns
  - Prevents accidental commits of:
    - `.claude/` - Claude Code configuration
    - `CLAUDE.md`, `PROGRESS.md` - Project-specific documentation
    - `docs/design/` - Design documents (may contain security info)
    - `*.fasl`, `*.log`, `*.env` - Generated/temporary files
  - Clear error messages explaining why files are ignored

#### Protection Benefits
- Multi-layer defense against .gitignore violations
- Prevents leaking sensitive design documents
- Protects project-specific configuration from being committed
- Claude Code self-enforcement of repository rules

## [0.1.5] - 2025-11-25

### Added - HTTP Integration Test Infrastructure (Phase 3)

#### HTTP Test Helper System
- **test/http-helper.lisp**: Comprehensive HTTP testing utilities
  - **Server Management**: `start-test-server`, `stop-test-server`, `wait-for-server-ready`
    - Clack/Woo integration with proper lifecycle management
    - Health check with retry logic (404-tolerant for undefined routes)
    - Automatic cleanup with `with-test-server` macro
  - **HTTP Request Helpers**: `http-post`, `http-get`, `http-put`, `http-delete`
    - Dexador-based real HTTP requests
    - JSON request body support with Jonathan encoding
    - Cookie management with `make-cookie-header`
    - Automatic error handling for 4xx/5xx responses
  - **Response Validation**: `assert-status`, `assert-json-response`, `assert-cookie`
    - Status code verification
    - Nested JSON path validation with hash-table traversal
    - Cookie header inspection (list-wrapped values supported)
  - **Authentication Helper**: `with-authenticated-user` macro
    - Automatic user registration and session cookie extraction
    - Simplifies authenticated endpoint testing

#### Authentication API Tests
- **test/handler/auth-test.lisp**: 9 comprehensive test cases
  - **Registration Tests** (4 cases):
    - Success with session cookie validation
    - Missing username error (400)
    - Missing password error (400)
    - Duplicate username error (400)
  - **Login Tests** (4 cases):
    - Success with cookie and JSON validation
    - Invalid username error (401)
    - Invalid password error (401)
    - Missing field errors (400)
  - **Logout Test** (1 case):
    - Success with Max-Age=0 cookie verification

### Fixed - Jonathan Encoding and Set-Cookie Header Issues

#### Jonathan JSON Encoding
- **Problem**: Type errors when encoding plist data
  - `TYPE-ERROR: The value "testuser" is not of type LIST`
  - Jonathan's `:from :plist` option has bugs with keyword symbols
  - `jonathan.util:my-plist-p` incorrectly validates cons cells as plists
- **Solution**: Convert plist to hash-table before encoding
  - `test/http-helper.lisp`: Added `plist-to-hash-table` helper function (lines 137-149)
  - Updated `http-post` and `http-put` to use hash-table conversion (lines 176, 198)
  - Properly converts keyword symbols to lowercase string keys
  - Example: `(:|username| "user")` → `{"username": "user"}`

#### JSON Response Parsing
- **Problem**: `assert-json-response` failed to traverse nested JSON
  - Loop-based approach didn't handle nested hash-tables correctly
- **Solution**: Refactored to use `reduce` with `gethash`
  - Changed `:as :plist` to `:as :hash-table` for Jonathan parsing
  - Recursive hash-table traversal for key path validation
  - Properly extracts nested values (e.g., `data.user.username`)

#### Set-Cookie Header Handling
- **Problem**: Response headers mutated via `*response*` were lost
  - `set-session-cookie` modified global state
  - `json-response` returned new response, discarding headers
- **Solution**: Functional header passing approach
  - `src/util/response.lisp`: Added `:headers` parameter to response functions
    - `json-response`: Accepts `:additional-headers` parameter
    - `response-success`: Accepts `:headers` parameter
    - `response-error`: Accepts `:headers` parameter
  - `src/handler/auth.lisp`: Refactored cookie generation
    - Replaced `set-session-cookie` with `make-session-cookie-header`
    - Replaced `clear-session-cookie` with `make-clear-cookie-header`
    - Pass headers directly to response functions

#### Cookie Value Extraction
- **Problem**: Clack/Lack returns `set-cookie` values as lists
  - `(gethash "set-cookie" headers)` returned `("session_id=...;")`
  - String search failed on list values
- **Solution**: Handle list-wrapped cookie values
  - `test/http-helper.lisp`: `assert-cookie` extracts first element from list
  - `test/handler/auth-test.lisp`: Logout test updated for list extraction

### Verified - Complete HTTP Test Suite

All integration tests passing in Docker environment (2025-11-25):

- ✅ **5/5 test suites successful**
  - voro.test.util - 32 test cases
  - voro.test.model - 7 test cases
  - voro.test.service - 13 test cases
  - voro.test.handler - 1 test case (placeholder)
  - voro.test.handler.auth - 9 test cases (NEW)
- ✅ **HTTP integration tests working**
  - Real Woo server lifecycle management
  - Dexador HTTP client requests
  - JSON request/response validation
  - Cookie-based session management
- ✅ **All endpoints validated**
  - POST /api/auth/register (success + 3 error cases)
  - POST /api/auth/login (success + 3 error cases)
  - POST /api/auth/logout (success with cookie clear)

### Technical Details

#### Test Execution Flow
1. `with-test-environment` - Setup DB/Redis connections
2. `with-test-server` - Start Woo server on port 18080
3. `wait-for-server-ready` - Health check with 404 tolerance
4. `with-test-db` - Transaction-wrapped test execution
5. Automatic server stop and connection cleanup

#### Jonathan Best Practices
- Use `:from :plist` for encoding plist data
- Use `:as :hash-table` for parsing JSON responses
- Prefer plist over alist for test data (keyword symbols)

### Commits

- Branch: `feature/phase3-http-test-infrastructure`
- `350cf0e` feat: Implement Phase3 HTTP integration test infrastructure
- `d0d6fc0` fix: Resolve Jonathan encoding and Set-Cookie header issues in HTTP tests

### Next Steps (Remaining Phases)

- **Phase 4**: CI/CD integration
  - GitHub Actions workflow
  - Automated testing on push/PR
- **Phase 5**: Documentation
  - Testing guide with examples
  - Troubleshooting documentation

## [0.1.4] - 2025-11-24

### Added - 8-Layer Defense for Test Database Protection (Phase 2)

#### 8-Layer Defense Implementation

Comprehensive multi-layer validation system to prevent accidental production database access:

**Layer 1: Environment Variable Enforcement**
- Requires `APP_ENV=test` and `TEST_MODE=true`
- Blocks test execution if environment variables are not set correctly

**Layer 2: Explicit DB Name Specification**
- Validates `voro.config:*app-env*` is "test"
- Ensures config.lisp auto-switching works correctly

**Layer 3: Whitelist Validation**
- Only allows connection to `voro_test` database
- Rejects any database not in whitelist

**Layer 4: Blacklist Validation**
- Explicitly blocks production/system databases: `voro`, `postgres`, `template0`, `template1`
- Double protection against accidental production access

**Layer 5: Post-Connection Re-verification**
- Executes `SELECT current_database()` after connection
- Validates actual connected database matches whitelist
- Uses `dbi:prepare`, `dbi:execute`, `dbi:fetch` for reliable query execution

**Layer 6: Table Existence Check**
- Ensures test tables exist via `mito:ensure-table-exists`

**Layer 7: Transaction Isolation**
- `with-test-db` macro wraps tests in transactions
- Each test runs in isolated transaction context

**Layer 8: Guaranteed Rollback**
- Always rolls back via `test-rollback-condition`
- Ensures no data persists even on test success

#### Test Fixtures System

- **test/fixtures.lisp**: Comprehensive test data helpers
  - `create-test-user`: Auto-incrementing unique usernames (testuser1, testuser2, ...)
  - `create-test-users`: Bulk user creation
  - `create-test-session`: Session fixture with automatic user creation
  - Default values with keyword parameter overrides
  - `*test-user-counter*` for unique username generation

#### Transaction-Based Test Isolation

- **with-test-db macro**: Transaction wrapper for tests
  - Uses `dbi:with-transaction` with `mito.connection:*connection*`
  - Automatically rolls back all database changes after test
  - Works seamlessly with existing Mito ORM setup
  - Verified with Phase0 PoC scripts

#### Improved Test Data Cleanup

- **Dynamic table cleanup**: Model-based approach
  - Iterates through known Mito model classes
  - Uses `mito.class:table-name` to get actual table names
  - No hardcoded table names for better maintainability
  - Graceful error handling for missing tables

### Modified

- **test/setup.lisp**: Enhanced with 8-layer defense
  - `verify-test-database`: Multi-layer validation function
  - `with-test-db`: Transaction-based test isolation macro
  - `test-rollback-condition`: Custom condition for guaranteed rollback
  - `cleanup-test-data`: Dynamic model-based cleanup
  - Whitelist/blacklist parameters for database validation

- **voro.asd**: Added test/fixtures.lisp to build system
  - Proper dependency ordering (fixtures depends on setup)
  - All test files now depend on fixtures

### Verified - Complete 8-Layer Defense

All tests passing with 8-layer defense active (2025-11-24):

- ✅ **4/4 test suites successful**
  - voro.test.util - 32 test cases
  - voro.test.model - 7 test cases
  - voro.test.service - 13 test cases
  - voro.test.handler - 1 test case
- ✅ **8-layer defense operational**
  - All layers verify correctly
  - Production database access blocked
  - Whitelist/blacklist validation working
  - Transaction isolation confirmed
- ✅ **Test fixtures functional**
  - Auto-incrementing usernames working
  - Session creation successful
  - Default value overrides working

### Benefits

- **Production Safety**: Multiple layers prevent accidental production DB access
- **No Single Point of Failure**: Each layer provides independent protection
- **Fast Tests**: Transaction-based isolation (no TRUNCATE needed per test)
- **Data Isolation**: Tests can run in parallel without interference
- **Maintainability**: Dynamic model-based cleanup reduces maintenance burden

### Commits

- Branch: `feature/phase0-poc-verification`
- `41743b4` feat: Implement Phase2 8-layer defense for test database protection

### Next Steps (Remaining Phases)

- **Phase 3**: HTTP integration test framework
  - `test/http-helper.lisp` for endpoint testing
  - Handler layer coverage target: 70%+
  - Dexador-based real HTTP requests
- **Phase 4**: CI/CD integration
  - GitHub Actions workflow
  - Automated testing on push/PR
- **Phase 5**: Documentation
  - Testing guide
  - Troubleshooting documentation

## [0.1.3] - 2025-11-24

### Added - Docker Test Infrastructure (Phase 0-1)

#### Phase 0: PoC Verification
- **Transaction Testing**: Mito transaction rollback verification
  - `scripts/poc-transaction-test.lisp` - Validates rollback behavior
  - Confirms test data isolation through transactions
- **HTTP Server Testing**: Caveman2 server lifecycle verification
  - `scripts/poc-http-server-test.lisp` - Server start/stop/health check
  - Validates server control for integration tests

#### Phase 1: Docker Test Environment
- **Dockerfile.test**: SBCL-based test container
  - Official SBCL image (2.2.4) with Quicklisp
  - Pre-loaded dependencies (Caveman2, Mito, cl-redis, Rove, Dexador)
  - UID/GID matching for macOS/Linux compatibility
  - Non-root user execution for security
- **docker-compose.test.yml**: Multi-container test orchestration
  - PostgreSQL 15 (alpine) with health checks
  - Redis 7 (alpine) with health checks
  - Test runner with dependency wait conditions
  - Environment variable configuration (APP_ENV=test, TEST_DB_*, TEST_REDIS_DB=1)
  - Quicklisp cache volume (`sbcl-cache`) for faster builds
- **Test Automation**: Makefile with common commands
  - `make test` - Run all tests in Docker
  - `make clean` - Clean up Docker resources
  - `make shell-test` - Debug shell in test container
  - `make logs` - View test runner logs
- **Database Initialization**: `scripts/init-test-db.sql`
  - User permissions (GRANT ALL ON SCHEMA public)
  - Default privileges for future tables/sequences
  - UTC timezone configuration
- **Test Execution**: `scripts/run-tests.sh`
  - Environment validation (APP_ENV=test, TEST_MODE=true)
  - Database/Redis connection wait logic
  - SBCL test execution with proper exit codes

### Fixed
- **.gitignore**: Allow `Dockerfile.test` to be tracked
  - Added `!Dockerfile.test` exception to `*.test` ignore pattern
  - Ensures Docker configuration is version controlled

### Verified - Docker Test Suite

All tests passing in Docker environment (2025-11-24):

- ✅ **4/4 test suites successful**
  - voro.test.util - 32 test cases
  - voro.test.model - 7 test cases
  - voro.test.service - 13 test cases
  - voro.test.handler - 1 test case
- ✅ **PostgreSQL connection**: test-db:5432/voro_test
- ✅ **Redis connection**: test-redis:6379 DB 1
- ✅ **Health checks**: Working correctly
- ✅ **Data cleanup**: Automatic TRUNCATE CASCADE
- ✅ **Quicklisp cache**: Persistent across runs

### Performance
- Docker build time: ~85 seconds (with dependency caching)
- Test execution time: ~40 seconds (including container startup)
- Subsequent runs: Faster due to cached layers and Quicklisp volume

### Infrastructure Improvements
- Environment reproducibility through Docker
- Isolation from host system dependencies
- Consistent test results across development machines
- Foundation for CI/CD integration (Phase 4)

### Commits
- Branch: `feature/phase0-poc-verification`
- `a5f7eb1` feat: Implement Phase1 Docker test infrastructure

### Next Steps (Remaining Phases)
- **Phase 2**: Test setup enhancement (8-layer defense)
  - Production database protection
  - Transaction-based test isolation
  - `with-test-db` macro for automatic rollback
- **Phase 3**: HTTP integration test framework
  - `test/http-helper.lisp` for endpoint testing
  - Handler layer coverage target: 70%+
- **Phase 4**: CI/CD integration
  - GitHub Actions workflow
  - Automated testing on push/PR
- **Phase 5**: Documentation
  - Testing guide
  - Troubleshooting documentation

## [0.1.2] - 2025-11-22

### Fixed - Email Validation & Test Suite

#### Email Validation Improvements
- **Email is now required**: Changed from optional to mandatory field
  - Added NIL check in `validate-email` function
  - Returns validation error if email is not provided
  - Design decision: Reject OAuth registration if email cannot be obtained
- **Stricter email validation**: Improved local part validation
  - Split email into local and domain parts for separate validation
  - Detects dots at start/end of local part (e.g., `user.@example.com`)
  - Detects consecutive dots in local part (e.g., `user..name@example.com`)
  - Fixed regex pattern to properly validate email structure

#### Test Suite Fixes
- **Updated test expectations**: Changed NIL handling test
  - Before: `"NILは許可される（オプショナル項目）"` - Expected success
  - After: `"NILは拒否される（必須項目）"` - Expected validation error
- **Added email parameters**: Updated all service tests
  - `test/service-test.lisp`: Added `:email` parameter to all `register-user` calls
  - Ensures tests match new email requirement

#### Development Process Improvements
- **Git pre-commit hook**: Prevent direct commits to main branch
  - Location: `.git/hooks/pre-commit`
  - Blocks commits to `main` or `master` branches
  - Provides helpful error message with branch naming examples
  - Ensures all changes go through feature branches

### Verified - Complete Test Suite Passing

All tests executed successfully (2025-11-22):

- ✅ **voro.test.util** - 32 test cases passed
  - Password validation (5 cases)
  - Username validation (11 cases)
  - Email validation (12 cases) - Including new NIL rejection test
  - Password hashing (4 cases)
- ✅ **voro.test.model** - 7 test cases passed
  - User creation and queries
  - Username search
  - Password verification
- ✅ **voro.test.service** - 13 test cases passed
  - User registration (success and error cases)
  - User authentication (login success and failure)
- ✅ **voro.test.handler** - 1 test case passed
  - Placeholder test

**Summary**: 4 test suites, 53 test cases, 0 failures

#### Research: Google OAuth Email Availability

Investigation into whether email addresses can always be obtained via Google OAuth:

**Findings:**
- Email scope (`https://www.googleapis.com/auth/userinfo.email`) is optional
- Users or organizations can refuse to share email addresses
- `userinfo` endpoint does not guarantee email will be returned
- Even with `email` scope requested, email may not be available

**Design Decision:**
- Treat email as a required field for user registration
- Reject OAuth-based registration if email cannot be obtained
- This ensures all users have a valid email address for notifications

### Commits

- Branch: `fix/email-validation-required`
- Hook implementation in `.git/hooks/pre-commit`

## [0.1.1] - 2025-11-21

### Fixed - Caveman2 Integration & Cache Management

#### Caveman2 Routing and Application Definition
- **Fixed defroute usage**: Changed from `(<app> "/path")` to `(*app* "/path")`
  - Issue: `defroute` requires application instance, not class
  - Solution: Import `*app*` instead of `<app>` in handler packages
- **Fixed application class definition**: Replaced non-existent `defapp` macro
  - Changed: `(defapp <app>)` → `(defclass <web> (<app>) ())`
  - Changed: `(defparameter *app* ...)` → `(defvar *app* ...)`
  - Added: `(clear-routing-rules *app*)` for clean routing state
- **Resolved UNBOUND-VARIABLE error**: Fixed class inheritance issue
  - Problem: `(defclass <app> (<app>) ())` created circular reference
  - Solution: Use unique class name `<web>` inheriting from caveman2's `<app>`

#### FASL Cache Management
- **Project-local cache system**: No more `~/.cache` pollution
  - Added `scripts/setup-cache.lisp` for automatic cache configuration
  - Cache location: `_build/fasl/` (gitignored)
  - Prevents stale FASL issues between code changes
- **Cache cleanup script**: Safe, project-scoped cleanup
  - Added `scripts/clean-cache.sh` with safety checks
  - Automatic cache size reporting
  - Confirmation prompt (override with `-y` flag)
- **Developer convenience**: Easy server startup
  - Added `start-server.lisp` for one-command development
  - Automatically loads cache config before Quicklisp

#### Database Permissions
- **Fixed PostgreSQL schema access**: Granted `voro_user` proper permissions
  - `GRANT ALL ON SCHEMA public TO voro_user`
  - Required for Mito table creation

### Verified - API Endpoints Working

All authentication endpoints tested and operational:

- ✅ `POST /api/auth/register` - User registration (HTTP 200)
  ```json
  {"success":true,"data":["user",["id",1,"username","testuser"]]}
  ```
- ✅ `POST /api/auth/login` - Authentication (HTTP 200)
  ```json
  {"success":true,"data":["user",["id",1,"username","testuser"]]}
  ```
- ✅ `POST /api/auth/login` - Invalid credentials (HTTP 401)
  ```json
  {"success":false,"error":"Invalid username or password"}
  ```
- ✅ `POST /api/auth/logout` - Session termination (HTTP 200)
  ```json
  {"success":true,"data":["message","Logged out successfully"]}
  ```

### Commits

- `974b6a6` fix: Correct Caveman2 defroute usage to use *app* instance
- `c610564` feat: Add project-local FASL cache management and fix Caveman2 app definition

## [0.1.0] - 2025-11-21

### Added - Backend Foundation (Phase 1-3)

#### Phase 1: Project Foundation
- **ASDF System**: Complete system definition with proper dependency management
- **Configuration Management**: Type-safe environment variable loading with validation
  - Support for development/test/production environments
  - Automatic test DB/Redis selection
  - Configurable retry/health-check parameters
- **Logging System**: Structured logging with ISO-8601 timestamps and error ID tracking
- **Response Utilities**: Unified JSON response generation
- **Password Security**: PBKDF2 hashing with 100,000 iterations (configurable)
- **Input Validation**: Comprehensive validation for passwords, usernames, and emails
  - Custom `validation-error` condition type
  - Clear, user-friendly error messages

#### Phase 2: Database Connections
- **PostgreSQL Connection**: Robust connection management with exponential backoff retry
  - 3 retries (dev/test) to 5 retries (production)
  - Health check with 60-second caching
  - Auto-reconnect on connection loss
  - Docker and RDS compatible
- **Redis Connection**: Session storage with similar resilience features
  - Wrapped commands with automatic health check
  - Environment-specific DB selection (DB 0: dev, DB 1: test)

#### Phase 3: Authentication System
- **User Model**: Mito ORM-based user management
  - Username (unique, 3-50 chars, alphanumeric + underscore)
  - Password (PBKDF2 hashed, never exposed)
  - Email (optional, RFC 5321 compliant)
  - Timestamps (created_at, updated_at)
- **Session Management**: Redis-based sessions
  - 128-bit cryptographically secure session IDs
  - 7-day TTL (configurable)
  - Redis Hash storage for session data
- **Authentication Service**: User registration and login
  - Input validation with detailed error messages
  - Duplicate username detection
  - Secure password verification
- **REST API Handlers**: Caveman2-based HTTP endpoints
  - `POST /api/auth/register` - User registration
  - `POST /api/auth/login` - User authentication
  - `POST /api/auth/logout` - Session termination
  - HttpOnly, SameSite=Strict cookies for CSRF protection

#### Testing Infrastructure
- **Test Environment**: Automatic setup/teardown with database isolation
  - Separate test databases (PostgreSQL: `voro_test`, Redis: DB 1)
  - Data cleanup before and after each test
  - `with-test-environment` macro for easy test writing
- **Unit Tests**: Comprehensive test coverage
  - Validation functions (password, username, email)
  - Crypto functions (hash, verify)
  - User model operations
  - Authentication service (registration, login, errors)

#### Infrastructure
- **Database Setup**: PostgreSQL databases and users created
  - Development: `voro` (user: `voro_user`)
  - Test: `voro_test` (user: `voro_test_user`)
- **Redis**: Confirmed operational with PING test
- **Environment File**: `.env` created from template

### Fixed

#### Dependency Management
- **Load Order**: Moved `util` module before `db`/`redis` to resolve import errors
- **Web/Handler**: Reordered `web` before `handler` to allow route definitions

#### Caveman2 Integration (Partial)
- **App Definition**: Changed from `(defapp *app*)` to `(defapp <app>)` with instance creation
- **Route Definition**: Updated `defroute` to use `<app>` class instead of `*app*` variable
- **Control Flow**: Replaced `return-from route` with `if/else` structure

### Technical Details

#### Dependencies
- **Language**: SBCL 2.5.9
- **Web**: Caveman2, Clack, Lack, Woo
- **Database**: Mito, SXQL, DBI, cl-redis
- **JSON**: Jonathan
- **Crypto**: Ironclad, flexi-streams
- **Utils**: Alexandria, split-sequence, local-time, cl-ppcre
- **Testing**: Rove

#### Security Features
- PBKDF2 password hashing (SHA-256, 100,000 iterations)
- Cryptographically secure session IDs (128-bit)
- HttpOnly cookies (prevents XSS)
- SameSite=Strict (prevents CSRF)
- Input validation with sanitization
- No password logging or exposure

#### Performance Features
- Connection pooling ready (Mito)
- Health check caching (60s interval)
- Exponential backoff for retries
- Efficient Redis Hash storage

### Known Limitations

- Handler tests are placeholder only (no HTTP integration tests)
- PBKDF2 iterations set to 100,000 (OWASP recommends 600,000+ for production)
- No rate limiting
- No HTTPS enforcement (deployment configuration needed)
- No email verification
- Session storage in Redis (no persistence across Redis restarts without RDB/AOF)

### Commits

- `7802b62` Initial commit: Add project documentation and gitignore
- `bb91f79` feat: Implement backend foundation (Phase 1-3)
- `f976a7f` fix: Correct Caveman2 app definition and dependency order

---

## Development Notes

### Branch: feature/backend-foundation
All Phase 1-3 work is on this feature branch. All routing issues resolved and APIs verified working.

### Next Steps
1. ~~Resolve Caveman2 routing issue~~ ✅
2. ~~Complete application startup verification~~ ✅
3. ~~Test API endpoints with curl/Postman~~ ✅
4. ~~Run test suite~~ ✅ (2025-11-22)
5. ~~Fix email validation issues~~ ✅ (2025-11-22)
6. Review and merge PR to main

### Reference
- Design Document: `docs/design/backend-foundation.md`
- Progress Tracking: `PROGRESS.md`
- Project Overview: `CLAUDE.md`, `README.md`
