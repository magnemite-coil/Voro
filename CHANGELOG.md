# Changelog

All notable changes to the Voro project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
4. Run test suite
5. Review and merge PR to main

### Reference
- Design Document: `docs/design/backend-foundation.md`
- Progress Tracking: `PROGRESS.md`
- Project Overview: `CLAUDE.md`, `README.md`
