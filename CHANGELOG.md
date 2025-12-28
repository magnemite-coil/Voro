# Changelog

All notable changes to the Voro project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Infrastructure Layer Test Coverage Enhancement (db.lisp, redis.lisp)

#### Updated Test Files
- **test/db-test.lisp**: Added disconnect failure error handling tests (+2 test cases)
  - `test-try-connect-db-disconnect-failure`: Tests error suppression when old connection disconnect fails (L77-82)
  - `test-db-health-check-mito-disconnect-failure`: Tests mito disconnect failure handling during health check (L205-209)
- **test/redis-test.lisp**: Added disconnect failure error handling test (+1 test case)
  - `test-try-connect-redis-disconnect-failure`: Tests error suppression when old connection disconnect fails (L72-77)

#### Updated Documentation
- **.claude/rules/testing.md**: Added Infrastructure layer exception note
- **docs/testing/README.md**: Added Infrastructure layer exception note with reference to design document

#### Test Coverage Results
| File | Target Branches | Status |
|------|-----------------|--------|
| db.lisp:77-82 | Old connection disconnect failure | ✅ Covered |
| db.lisp:205-209 | Mito disconnect failure in health check | ✅ Covered |
| redis.lisp:72-77 | Old connection disconnect failure | ✅ Covered |

#### Test Results
- All backend tests passed (`make test` exit code 0)
- Phase 1 (db.lisp) and Phase 2 (redis.lisp) completed
- Phase 3 (main.lisp) deferred to separate PR (requires implementation changes)

#### Design Document
- `docs/design/infrastructure-coverage-design.md`: Implementation complete

#### Branch
- `test/infrastructure-coverage-2025-12-27`

#### Commits
- `651633c` test(db): add try-connect-db disconnect failure test
- `ff479ae` test(db): add db-health-check mito disconnect failure test
- `2c445a6` test(redis): add try-connect-redis disconnect failure test
- `945deda` docs(testing): add Infrastructure layer exception note

---

### Added - Model Post Branch Coverage Tests for 100% Coverage (model/post.lisp)

#### Updated Test File
- **test/model/post-test.lisp**: Added branch coverage tests (+2 test cases)
  - `test-create-post-with-user-object`: Tests `create-post` with user object parameter (L150 TRUE branch)
  - `test-format-timestamp-nil`: Defensive test for nil timestamp handling

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Branch | 83.3% (5/6) | 100.0% (6/6) | 100% | ✅ Achieved |
| Expression | 93.0% (133/143) | 93.0% (133/143) | 90%+ | ✅ Maintained |

#### Key Test Scenarios
- `create-post`: User object parameter (previously only integer ID was tested)
- `format-timestamp`: Nil input defensive test (optional, for code robustness)

#### Test Results
- All backend tests passed
- Coverage measurement completed

#### Design Document
- `docs/design/model-post-branch-coverage-expansion.md`: Implementation complete

#### Branch
- `test/model-post-branch-coverage-2025-12-25`

#### Commits
- `cd86544` test(model): add post branch coverage tests for 100% coverage
- `320d1d9` docs(changelog): add model post branch coverage tests entry

---

### Added - JSON Branch Coverage Tests for 100% Coverage (util/json.lisp)

#### Updated Test File
- **test/util-test.lisp**: Added JSON branch coverage tests (+5 test cases)
  - `json-alist-string-key-test`: String key alist conversion (L28, L55 FALSE branches)
  - `json-alist-non-alist-input-test`: Simple list → vector conversion (L50 FALSE, L62 TRUE branches)
  - `json-alist-primitive-input-test`: Primitive value pass-through (L62 FALSE, L65 t branches)
  - `json-alist-list-key-test`: List key data → vector conversion (L52 FALSE branch)
  - `json-plist-string-key-test`: String key plist conversion (L73 FALSE branch)

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Branch | 71.4% (20/28) | 100.0% (28/28) | 100% | ✅ Achieved |
| Expression | 90.2% (83/92) | 97.8% (90/92) | 90%+ | ✅ Achieved |

#### Key Test Scenarios
- `alist-to-hash-table-recursive`: String keys, simple lists, primitives, list keys
- `alist-value-to-jzon`: Nested alist with string key handling
- `plist-to-hash-table`: String key plist handling
- Jzon `nil`/`null`/`false` distinction compatibility

#### Test Results
- 16 backend tests passed
- Coverage measurement completed

#### Design Document
- `docs/design/json-branch-coverage-improvement.md`: Implementation complete (v1.0)

#### Branch
- `test/json-branch-coverage-2025-12-25`

#### Commit
- `d31cb63`

---

### Added - Frontend Coverage Improvement Option A (Header, Toast, App, api.ts)

#### New Test Files
- **frontend/src/components/common/Header/Header.test.tsx**: Header component tests (129 lines)
  - HD-1~HD-7: Logo, navigation, active tab styling, actions, click handlers
  - CSS Modules compatible assertions
- **frontend/src/components/common/Toast/Toast.test.tsx**: Toast component tests (168 lines)
  - TO-1~TO-5: Empty state, notifications, close button, multiple notifications, notification types
  - NotificationContext integration testing

#### Updated Test Files
- **frontend/src/App.test.tsx**: Added APP-7 direct mount test
  - Tests App component mounting with createBrowserRouter
  - Verifies redirect flow from / → /posts/new → /login (unauthenticated)
- **frontend/src/services/api.test.ts**: Added AbortSignal support tests
  - api.post, api.put, api.delete now tested with AbortController
  - Branch coverage improved: 82.35% → 100%
- **frontend/src/components/common/ProtectedRoute/ProtectedRoute.test.tsx**: Fixed act() warnings
  - PR-7, PR-8: login(), logout(), router.navigate() wrapped in act()

#### Test Coverage Results
| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Functions | 90%+ | 93.33% | ✅ Achieved |
| Branch | 98%+ | 98.88% | ✅ Achieved |
| Lines | 99%+ | 99.5% | ✅ Achieved |

#### Test Cases Summary
| File | Test IDs | Count | Status |
|------|----------|-------|--------|
| Header.test.tsx | HD-1~HD-7 | 7 | ✅ |
| Toast.test.tsx | TO-1~TO-5 | 5 | ✅ |
| App.test.tsx | APP-7 | 1 | ✅ |
| api.test.ts | AbortSignal tests | 3 | ✅ |

#### Test Results
- 212 tests passed, 3 todo (215 total)
- TypeScript type check passed
- ESLint: no warnings
- Frontend build successful

#### Design Document
- `docs/design/frontend-coverage-improvement-option-a.md`: All tasks completed (v1.6)

#### Branch
- `test/frontend-coverage-option-a-2025-12-23`

---

### Added - usePost Non-API Error Handling Test Coverage (Frontend)

#### Updated Test File
- **frontend/src/hooks/usePost.test.ts**: Added non-API error handling tests for 100% coverage (+2 test cases)
  - Network error test for `fetchPost` using `HttpResponse.error()`
  - Non-403 API error test for `updatePost` (500 Internal Server Error)

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Statements | 97.05% | 100% | 100% | ✅ Achieved |
| Branch | 94.11% | 100% | 100% | ✅ Achieved |
| Functions | 100% | 100% | 100% | ✅ Achieved |
| Lines | 97.05% | 100% | 100% | ✅ Achieved |

#### Test Cases Summary
| Test Name | Target Lines | Description |
|-----------|--------------|-------------|
| `should set error to "Failed to load post" on network error` | 42-43 | Simulates network error via `HttpResponse.error()`, verifies error message |
| `should re-throw error on non-403 API error` | 75-76 | Simulates 500 error, verifies error is re-thrown |

#### Key Test Scenarios
- MSW `HttpResponse.error()` simulates network-level errors (TypeError, not ApiError)
- Non-ApiError errors trigger generic "Failed to load post" message in `fetchPost`
- Non-403 errors in `updatePost` are re-thrown to caller

#### Test Results
- 196 tests passed, 3 todo (199 total)
- TypeScript type check passed
- Frontend build successful

#### Design Document
- `docs/design/usepost-non-api-error-test.md`: Implementation complete with results section

#### Commits
- Branch: `test/usepost-non-api-error-2025-12-23`
- Commit: `4a41efc`

---

### Added - App.tsx Routing Test Coverage (Frontend)

#### New Test File
- **frontend/src/App.test.tsx**: Comprehensive routing tests for App.tsx
  - 7 test cases (all implemented)
  - Phase 1: Routing (APP-1~APP-4b) - 5 tests
  - Phase 2: NotFoundPage (APP-5~APP-6) - 2 tests

#### Test Coverage Results
| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| Statements | 81.25% | 80%+ | ✅ Achieved |
| Branch | 100% | 80%+ | ✅ Exceeded |
| Functions | 50% | 50% | ✅ Achieved (design constraint) |
| Lines | 81.25% | 80%+ | ✅ Achieved |

#### Test Cases Summary
| ID | Test Case | Description |
|----|-----------|-------------|
| APP-1 | /login route | Shows LoginPage correctly |
| APP-2 | /posts/new (authenticated) | Shows PostEditorPage via ProtectedRoute |
| APP-3 | /posts/:id/edit (authenticated) | Shows edit page via ProtectedRoute |
| APP-4a | / redirect (authenticated) | Redirects to /posts/new |
| APP-4b | / redirect (unauthenticated) | Redirects to /login |
| APP-5 | Unknown routes | Shows NotFoundPage |
| APP-6 | 404 page link | Navigates to /posts/new |

#### Configuration Changes
- **frontend/vitest.config.ts**: Added coverage exclusion settings
  - `coverage.include`: `['src/**']`
  - `coverage.exclude`: `['src/main.tsx', 'src/types/**', 'src/test/**']`
  - Uses `coverageConfigDefaults` to preserve Vitest defaults
- **frontend/src/App.tsx**: Added export to NotFoundPage component

#### Test Helper
- `renderApp()`: Custom helper for routing tests
  - Uses `createMemoryRouter` for test environment
  - Reproduces App.tsx route configuration and provider hierarchy
  - Supports `initialPath` and `setupAuth` options

#### Technical Notes
- Functions coverage at 50% due to test strategy using `createMemoryRouter`
- `App()` function not directly called, but provider hierarchy reproduced in `renderApp`
- This is a design constraint, not a quality issue

#### Test Results
- 194 tests passed, 3 todo (197 total)
- TypeScript type check passed
- Frontend build successful

#### Design Document
- `docs/design/app-component-test-design.md`: Implementation complete with Section 11 (results and remaining tasks)

#### Commits
- Branch: `test/app-component-coverage-2025-12-22`
- Commit: `53ff5ed`

---

### Added - AuthContext Edge Case Test Coverage (Frontend)

#### Updated Test File
- **frontend/src/contexts/AuthContext.test.tsx**: Added edge case tests for 100% coverage (+3 test cases)
  - AC-9b: localStorage corrupted to invalid JSON during API call
  - AC-9c: localStorage structure becomes incomplete during API call
  - AC-18c: localStorage corruption + unmount abort handling

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Statements | 93.97% | 100% | 100% | ✅ Achieved |
| Branch | 93.18% | 100% | 100% | ✅ Achieved |
| Functions | 100% | 100% | 100% | ✅ Achieved |
| Lines | 100% | 100% | 100% | ✅ Achieved |

#### Test Cases Summary
| Test ID | Target Line | Description |
|---------|-------------|-------------|
| AC-9b | 131 | Clears auth when localStorage is corrupted to invalid JSON during API call |
| AC-9c | 131 | Clears auth when localStorage structure becomes incomplete during API call |
| AC-18c | 132 | Does not update state when unmounted after localStorage corruption |

#### Key Test Scenarios
- Simulates cross-tab localStorage manipulation (corruption by browser extensions or other tabs)
- Invalid JSON corruption (`'invalid-json{'`) triggers auth state clear
- Incomplete structure (`{ userId: 1 }` without username) triggers auth state clear
- AbortSignal early return on unmount prevents memory leaks and state updates

#### Technical Notes
- AC-9b/AC-9c: Uses MSW (`server.use`) to modify localStorage before API response
- AC-18c: Uses `vi.spyOn(api, 'get')` for AbortSignal access and corruption simulation
- Console.error suppression only required for AC-18c (mock throws error)

#### Test Results
- 187 tests passed, 3 todo (190 total)
- TypeScript type check passed
- ESLint: no warnings
- Frontend build successful

#### Design Document
- `docs/design/authcontext-edge-cases-test.md`: Implementation complete with 100% coverage

#### Commits
- Branch: `test/authcontext-edge-cases-2025-12-22`
- Commit: `9a3623c`

---

### Added - useNavigationBlocker Test Coverage (Frontend)

#### New Test File
- **frontend/src/hooks/useNavigationBlocker.test.tsx**: Comprehensive unit tests for useNavigationBlocker hook
  - 11 test cases (all implemented)
  - Phase 1: Initial State (NB-1~NB-2)
  - Phase 2: Blocking Behavior (NB-3~NB-5)
  - Phase 3: proceed() and reset() (NB-6~NB-9)
  - Phase 4: Edge Cases (NB-10~NB-11)

#### Test Coverage Results
| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| Statements | 100% | 100% | ✅ Achieved |
| Branch | 100% | 100% | ✅ Achieved |
| Functions | 100% | 100% | ✅ Achieved |
| Lines | 100% | 100% | ✅ Achieved |

#### Test Helper Components
- `TestComponent`: Static isDirty/skipBlock props for basic tests
- `StateToggleComponent`: Internal state management for dynamic state change tests
- `renderWithRouter`: Helper for static prop tests (NB-1~NB-3, NB-6~NB-9)
- `renderWithStateToggle`: Helper for state change tests (NB-4, NB-5, NB-10, NB-11)

#### Key Test Scenarios
- Navigation blocking when isDirty is true
- Skip blocking when skipBlock is true
- proceed() continues blocked navigation
- reset() cancels blocked navigation
- Safe no-op when calling proceed()/reset() while not blocked
- Function stability after state changes (re-render safety)
- Blocked state maintained when skipBlock changes mid-block

#### Technical Notes
- Uses React Router v7 Data Router API (`createMemoryRouter`, `RouterProvider`)
- Tests actual navigation behavior, not mock implementations
- Validates `useBlocker` hook integration with proper routing context

#### Test Results
- 182 tests passed, 3 todo (185 total)
- Frontend build successful
- TypeScript type check passed

#### Design Document
- `docs/design/use-navigation-blocker-test-design.md`: Implementation complete with 100% coverage

#### Commits
- Branch: `test/use-navigation-blocker-coverage`
- Commit: `a8e5b71`

---

### Added - PostEditorPage Test Coverage (Frontend)

#### Updated Test File
- **frontend/src/pages/PostEditorPage/PostEditorPage.test.tsx**: Expanded PostEditorPage tests (+11 test cases)
  - Phase 1: Invalid ID Handling (PE-INV-1/2), Navigation (PE-NAV-1/2), Confirmation Modal (PE-CONF-1/2/3)
  - Phase 2: Publish Error Handling (PE-PUB-1/2/3)
  - Phase 3: Draft Save Error Handling (PE-SAVE-1)
  - Total: 21 test cases (10 existing + 11 new)

#### Test Helper Functions
- `renderEditMode`: Helper for rendering in edit mode with customizable post data
- `renderCreateMode`: Helper for rendering in create mode
- `makeFormDirty`: Helper for setting up form dirty state

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Statements | 85.65% | 100% | 95%+ | Exceeded |
| Branch | 86.27% | 98.38% | 95%+ | Achieved |
| Functions | 60% | 60% | 80%+ | Tolerated (v8 coverage characteristics) |
| Lines | 85.65% | 100% | 95%+ | Exceeded |

#### Code Quality Improvements
- **PostEditorPage.tsx**: Removed unreachable code
  - Deleted `mode === 'create'` branch from `handlePublish` function
  - This code path was unreachable because publish button is always disabled in create mode

#### Test Cases Summary
| Phase | Test IDs | Description | Lines Covered |
|-------|----------|-------------|---------------|
| 1 | PE-INV-1/2 | Invalid ID redirect | 43 |
| 1 | PE-NAV-1/2 | New post navigation | 182 |
| 1 | PE-CONF-1/2/3 | Confirmation modal operations | 186-200 |
| 2 | PE-PUB-1/2/3 | Publish error handling | 167-171 |
| 3 | PE-SAVE-1 | Draft save error handling | 140-141 |

#### Commits
- Branch: `test/post-editor-page-coverage`
- Commits: `7bb590a`, `46f5e22`, `490e939`
- Design document: `docs/design/post-editor-page-test-coverage.md`

---

### Added - NotificationContext Test Coverage (Frontend)

#### New Test File
- **frontend/src/contexts/NotificationContext.test.tsx**: Comprehensive unit tests for NotificationContext
  - 21 test cases (all implemented)
  - Phase 1: Initial State & useNotification Hook (NC-1~NC-3A)
  - Phase 2: showNotification - Add Notifications (NC-4~NC-8)
  - Phase 3: removeNotification - Remove Notifications (NC-9~NC-12)
  - Phase 4: Auto-dismiss Timer (NC-13~NC-17)
  - Phase 5: Cleanup (NC-18~NC-19)

#### Test Coverage Results
| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| Statements | 100% | 100% | ✅ Achieved |
| Branch | 100% | 100% | ✅ Achieved |
| Functions | 100% | 100% | ✅ Achieved |
| Lines | 100% | 100% | ✅ Achieved |

#### Test Cases Summary
| Phase | Description | Count |
|-------|-------------|-------|
| Phase 1 | Initial State, useNotification Hook | 4 |
| Phase 2 | showNotification - Add Notifications | 5 |
| Phase 3 | removeNotification - Remove Notifications | 4 |
| Phase 4 | Auto-dismiss Timer (3 seconds) | 6 |
| Phase 5 | Cleanup on Unmount | 2 |

#### Key Test Scenarios
- Provider boundary error handling (throws when used outside provider)
- useCallback function reference stability across re-renders
- Multiple notifications with individual timers
- Timer cleanup on manual removal
- Full timer cleanup on unmount
- Auto-dismiss after 3 seconds

#### ESLint Configuration
- Added `eslint-disable react-hooks/globals` directive
  - Required for test pattern where external variables capture hook values
  - Standard practice for React testing with hook value inspection

#### Test Results
- 163 tests passed, 3 todo (166 total)
- Frontend build successful
- Backend tests passed (16 tests)

#### Design Document
- `docs/design/notification-context-test-design.md`: Comprehensive test specification with Phase 1~5 breakdown (v13 - Implementation Complete)

#### Commits
- Branch: `test/notification-context-coverage`
- Commits: `95967b5`, `e361d40`

---

### Added - ConfirmModal Test Coverage (Frontend)

#### New Test File
- **frontend/src/components/common/ConfirmModal/ConfirmModal.test.tsx**: Comprehensive unit tests for ConfirmModal
  - 21 test cases (all implemented)
  - Phase 1: Basic Rendering (CM-1~CM-4)
  - Phase 2: Button Actions (CM-5~CM-7, CM-7b)
  - Phase 3: Keyboard Actions (CM-8~CM-11, CM-19)
  - Phase 4: Overlay Actions (CM-12~CM-13)
  - Phase 5: Scroll Lock (CM-14~CM-15, CM-20)
  - Phase 6: Accessibility (CM-16~CM-18)

#### Test Coverage Results
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| Statements | 24.71% | 100% | 95%+ | ✅ Exceeded |
| Branch | 50% | 95.65% | 85-90% | ✅ Exceeded |
| Functions | 33.33% | 100% | 100% | ✅ Achieved |
| Lines | 24.71% | 100% | 95%+ | ✅ Exceeded |

#### Test Cases Summary
| Phase | Description | Count |
|-------|-------------|-------|
| Phase 1 | Basic Rendering (isOpen, labels) | 4 |
| Phase 2 | Button Actions (confirm, cancel, focus) | 4 |
| Phase 3 | Keyboard (Escape, Tab, focus trap) | 5 |
| Phase 4 | Overlay (click, propagation) | 2 |
| Phase 5 | Scroll Lock (apply, restore, no side effects) | 3 |
| Phase 6 | Accessibility (ARIA attributes) | 3 |

#### Bug Fix
- **ConfirmModal.test.tsx**: Fixed TypeScript import for `ComponentProps`
  - Changed: `import { ComponentProps }` → `import type { ComponentProps }`
  - Required for `verbatimModuleSyntax` in TypeScript build

#### Test Results
- 139 tests passed, 3 todo (142 total)
- Frontend build successful
- TypeScript type check passed

#### Design Document
- `docs/design/confirm-modal-test-design.md`: Comprehensive test specification with Phase 1~6 breakdown

#### Commits
- Branch: `test/confirm-modal-coverage`
- Commits: `14eae08`, `0545eb0`, `a660c2c`

---

### Added - Vitest Coverage Tooling

#### Package Updates
- **frontend/package.json**: Added coverage tooling
  - New script: `test:coverage` for generating coverage reports
  - New devDependency: `@vitest/coverage-v8`

#### Configuration
- **.gitignore**: Added `frontend/coverage/` to excluded files

#### Usage
```bash
npm run test:coverage -- --run  # Generate coverage report
```

#### Commits
- `0545eb0` chore(test): add vitest coverage tooling

---

### Added - AuthContext & ProtectedRoute Test Coverage (Frontend)

#### New Test Files
- **frontend/src/contexts/AuthContext.test.tsx**: Comprehensive unit tests for AuthContext
  - 23 test cases (22 implemented, 1 todo)
  - Phase 1: Initial State (AC-1~AC-3a)
  - Phase 2: localStorage & API Verification (AC-4~AC-10)
  - Phase 3: Login Operations (AC-11~AC-14)
  - Phase 4: Logout Operations (AC-15~AC-17)
  - Phase 5: Abort & Network Error Handling (AC-18~AC-20)

- **frontend/src/components/common/ProtectedRoute/ProtectedRoute.test.tsx**: Comprehensive unit tests for ProtectedRoute
  - 8 test cases
  - Phase 1: Loading State (PR-1~PR-2)
  - Phase 2: Redirect when Unauthenticated (PR-3~PR-5)
  - Phase 3: Authenticated Access (PR-6)
  - Phase 4: Integration Tests (PR-7~PR-9)

- **frontend/src/test/utils.ts**: Shared test utilities
  - `setupAuthenticatedUser()`: Helper function for setting up authenticated user state in tests

#### Implementation Changes (Phase 0 Bug Fixes)
- **frontend/src/contexts/AuthContext.tsx**: Enhanced robustness
  - Added `parseAuthData()` helper function for safe JSON parsing
  - Added structure validation (userId: number, username: string)
  - Fixed localStorage branch to reset to unauthenticated state
  - Added `signal?.aborted` guards in all catch blocks to prevent memory leaks

#### Test Cases Summary
| Component | Test Cases | Status |
|-----------|------------|--------|
| AuthContext | AC-1~AC-20 (23 cases) | ✅ 22 implemented, 1 todo |
| ProtectedRoute | PR-1~PR-9 (8 cases) | ✅ All implemented |
| **Total** | **31 cases** | **30 implemented, 1 todo** |

#### Shared Utility Migration (Phase 0.5)
- Extracted `setupAuthenticatedUser()` from `LoginPage.test.tsx` to `test/utils.ts`
- Updated imports in `LoginPage.test.tsx`, `AuthContext.test.tsx`, `ProtectedRoute.test.tsx`

#### Test Results
- 118 tests passed, 3 todo (121 total)
- Frontend build successful
- TypeScript type check passed
- Backend tests passed (16 tests)

#### Design Document
- `docs/design/auth-context-test-design.md`: Comprehensive test specification with Phase 0~5 breakdown

#### Commits
- Branch: `test/auth-context-coverage`
- Commit: `7905883`

---

### Added - LoginPage Test Coverage (Frontend)

#### New Test File
- **frontend/src/pages/LoginPage/LoginPage.test.tsx**: Comprehensive unit tests for LoginPage
  - 20 test cases (18 implemented, 2 todo)
  - Phase 1: Initial Render (#1-3), Form Input (#4-7)
  - Phase 2: Login Success (#8-10)
  - Phase 3: Login Failure (#11-14), Error Recovery (#15)
  - Phase 4: Loading State (#16), Auto Redirect (#17), Auth State Verification (#18-20)

#### Test Cases
- **Initial Render**: Form elements, disabled button state, placeholders
- **Form Input**: Username/password validation, whitespace-only input rejection
- **Login Success**: Notification display, localStorage storage, redirect with history replacement
- **Login Failure**: 400/401/500 error handling, localStorage side-effect verification
- **Error Recovery**: Error clear after successful retry
- **Loading State**: Spinner display, button disabled during submission
- **Auto Redirect**: Authenticated user redirect with history replacement
- **Auth State Verification**: 401 → logout, 500/network error → optimistic auth preservation

#### Implementation Changes
- **frontend/src/pages/LoginPage/LoginPage.tsx**: Enhanced disabled condition
  - Changed: `disabled={!username || !password}`
  - To: `disabled={!username.trim() || !password.trim()}`
  - Prevents whitespace-only input from enabling login button

- **frontend/src/test/mocks/handlers.ts**: Added auth handlers
  - `POST /api/auth/login`: Default success response
  - `POST /api/auth/logout`: Success response

#### Test Results
- 88 tests passed, 2 todo (network error tests - MSW v2 limitation in jsdom)
- Network error tests (#14, #20) marked as todo due to `HttpResponse.networkError()` incompatibility with Vitest + jsdom

#### Design Document
- `docs/design/login-page-test-design.md`: Comprehensive test specification

---

### Added - Test Coverage Expansion (util/validation.lisp error type :report lambda)

#### Updated Test File
- **test/util-test.lisp**: Added error type `:report` lambda tests (+51 lines)
  - `test-validation-error-report`: Validate error string contains "Validation error:" prefix
  - `test-authorization-error-report`: Validate error string contains "Authorization error:" prefix
  - `test-not-found-error-report`: Validate error string contains "Not found:" prefix
  - Uses `format nil "~A"` to invoke `:report` lambda on condition objects
  - Added `authorization-error` and `not-found-error` to package imports

#### Test Coverage Results
| File | Expression Before | Expression After | Branch | Target | Status |
|------|-------------------|------------------|--------|--------|--------|
| util/validation.lisp | 88.2% (150/170) | 98.8% (168/170) | 100% (38/38) | 90% | ✅ Exceeded |

#### Technical Notes
- `:report` lambda in `define-condition` is invoked when condition is formatted to string
- Expected +6 expressions covered, actual result was +18 expressions
- Remaining 2 uncovered expressions are package definition (`defpackage`, `in-package`)

#### Commits
- Branch: `test/validation-coverage-improvement`
- Commit: `b0868a9`
- Design document: `docs/design/validation-test-coverage-design.md`

---

### Added - Model Layer Test Coverage Expansion

#### Coverage Results
| File | Expression | Branch | Target | Status |
|------|------------|--------|--------|--------|
| model/user.lisp | 92.3% (36/39) | - | 80% | ✅ Exceeded |
| model/post.lisp | 93.0% (133/143) | 83.3% (5/6) | 80% | ✅ Exceeded |

#### New Test Cases
- **test/model/user-test.lisp**: Added edge case tests
  - `test-create-user-empty-username`: Empty username validation at Model layer
  - `test-create-user-special-characters`: Special characters and Japanese username
  - `test-verify-user-password-nil-user`: NIL user error handling

- **test/model/post-test.lisp**: Added edge case tests
  - `test-create-post-nonexistent-user-id`: FK constraint validation
  - `test-create-post-empty-title`: Empty title validation at Model layer
  - `test-find-posts-by-nonexistent-user`: Non-existent user returns empty list
  - `test-count-user-posts-nonexistent-user`: Non-existent user returns 0
  - `test-create-post-very-long-content`: TEXT type unlimited content
  - `test-post-to-alist-published-false`: Unpublished post alist conversion

#### Infrastructure Improvements
- **scripts/run-coverage.lisp**: Added environment check function
  - DB/Redis connection validation before tests
  - Clear error messages for missing environment setup

- **docs/testing/README.md**: Added coverage measurement instructions
  - Docker environment commands
  - Local environment setup guide

#### Database Schema
- **src/model/post.lisp**: Added FK constraint for post.user_id
- **test/setup.lisp**: Added `ensure-fk-constraints` function
- **scripts/add-fk-constraint.sql**: Migration script for production

#### Commits
- Branch: `test/model-layer-coverage`
- Design document: `docs/design/model-layer-test-expansion.md`

---

### Added - Test Coverage Expansion (auth service/handler error handling)

#### New Test Files
- **test/helper/mock.lisp**: Mock utility for testing error scenarios
  - `with-mocked-function`: Temporarily replaces functions with mock implementations
  - Uses `unwind-protect` for safe cleanup

- **test/service/auth-test.lisp**: Service layer error handling tests
  - `test-register-user-db-error` (SA-01): DB connection error handling
  - `test-register-user-session-error` (SA-02): Redis session error handling
  - `test-authenticate-user-db-error` (SA-03): DB error returns NIL safely
  - `test-authenticate-user-session-error` (SA-04): Redis error returns NIL safely

#### Updated Test Files
- **test/handler/auth-test.lisp**: Added error handling tests
  - `auth-register-internal-error-test` (HA-01): 500 response with error_id
  - `auth-login-service-error-handling-test` (HA-02): Service layer error returns 401

- **test/http-helper.lisp**: Added `:worker-num 1` for mock test compatibility

- **voro.asd**: Added test modules (helper, service/auth)

#### Test Coverage Results
| File | Before | After | Target | Status |
|------|--------|-------|--------|--------|
| service/auth.lisp | 79.3% | 98.2% | 89% | Exceeded |
| handler/auth.lisp | 78.7% | 78.7% | 78.7% | Achieved (target revised) |

#### Notes
- Service layer tests (SA-01~SA-04) successfully improved coverage
- Handler layer coverage target revised to 78.7% due to sb-cover limitation with Woo threads
- HA-01/HA-02 tests work correctly (verified by response validation), but coverage not recorded by sb-cover

#### Commits
- Branch: `test/auth-coverage-expansion`
- PR: https://github.com/magnemite-coil/Voro/pull/33
- Design document: `docs/design/auth-test-coverage-expansion.md`

---

### Added - Test Coverage Expansion (config.lisp get-config validators)

#### Updated Test File
- **test/config-test.lisp**: Expanded config tests (+130 lines)
  - `test-get-config-validator-app-env`: APP_ENV valid/invalid value tests
  - `test-get-config-validator-log-level`: LOG_LEVEL valid/invalid value tests
  - `test-get-config-validator-redis-db`: REDIS_DB valid/invalid value tests
  - `test-get-config-unsupported-type`: Unsupported type error branch coverage
  - `test-get-config-validator-session-ttl`: SESSION_TTL range (1-2592000) validation
  - `test-get-config-validator-retry-settings`: Retry count and delay validation
  - `test-config-parameters-defined`: defparameter type/existence regression tests

#### Test Coverage by Phase
| Phase | Test Name | Description |
|-------|-----------|-------------|
| 1.1 | `test-get-config-unsupported-type` | Unsupported type error fallback |
| 2 | `test-get-config-validator-session-ttl` | TTL range validation (1-2592000) |
| 3 | `test-get-config-validator-retry-settings` | Retry/delay validation |
| 4 | `test-config-parameters-defined` | Regression tests for defparameter |

#### Additional Implementation (Beyond Design Doc)
- `test-get-config-validator-app-env`: Environment name validation
- `test-get-config-validator-log-level`: Log level validation
- `test-get-config-validator-redis-db`: Redis DB number validation

### Commits

- Branch: `test/config-coverage`
- Design document: `docs/design/config-test-coverage-expansion.md`

---

### Added - Test Coverage Expansion (handler/post PUT/DELETE error handling)

#### Updated Test File
- **test/handler/post-test.lisp**: Expanded handler/post tests (+110 lines)
  - `post-update-not-found-test`: PUT non-existent post returns 404
  - `post-update-validation-error-test`: PUT with validation error returns 400
  - `post-update-unauthorized-test`: PUT without authentication returns 401
  - `post-update-invalid-id-test`: PUT with invalid ID format returns 400
  - `post-delete-not-found-test`: DELETE non-existent post returns 404
  - `post-delete-unauthorized-test`: DELETE without authentication returns 401
  - `post-delete-invalid-id-test`: DELETE with invalid ID format returns 400
  - 7 new test cases total

#### Coverage Results
| File | Expression | Branch |
|------|------------|--------|
| handler/post.lisp | 72.4% (189/261) | 94.1% (16/17) |

Branch coverage target (90%) achieved. Expression coverage gap due to untested 500 error handlers (requires mock library).

### Commits

- Branch: `test/handler-post-coverage`
- Design document: `docs/design/handler-post-test-expansion.md`

---

### Added - Test Coverage Expansion (middleware/session error handling)

#### Updated Test File
- **test/middleware/session-test.lisp**: Expanded session middleware tests (+154 lines)
  - `test-create-session-redis-error`: Redis failure error handling (error message verification)
  - `test-create-session-created-at`: created_at field storage verification
  - `test-get-session-user-id-error-handling`: Redis failure returns NIL, parse-integer failure returns NIL
  - `test-delete-session-error-handling`: Redis failure returns NIL
  - `test-session-ttl`: TTL configuration verification (> 0, <= *session-ttl*, within 2 second margin)
  - 5 new test cases total

#### Source Code Addition
- **src/redis.lisp**: Added `red-ttl` wrapper function
  - TTL command with auto health check
  - Added to package exports

#### Test Helper Function
- **make-session-redis-key**: Generate Redis key for testing
  - Maintains same format as implementation's `session-key`

#### Coverage Results
| File | Expression | Branch |
|------|------------|--------|
| middleware/session.lisp | 98.2% (112/114) | 100.0% (4/4) |

Target was 75%, achieved **98.2%**.

### Commits

- Branch: `test/session-coverage`
- `86df5cb` test(session): expand test coverage for session middleware

---

### Added - SB-COVER Test Coverage Measurement

#### New Files
- **scripts/run-coverage.lisp**: SB-COVER integration script
  - Loads voro system with coverage instrumentation
  - Runs test suite and generates HTML report
  - Test code excluded from coverage measurement
  - Exit code 0 on success, 1 on failure (CI-ready)

#### Makefile Updates
- **test-coverage**: Run coverage in Docker environment
  - Uses `test-coverage-runner` service
  - Outputs report to `coverage-report/cover-index.html`
- **test-coverage-local**: Run coverage locally (requires PostgreSQL/Redis)

#### Docker Configuration
- **docker-compose.test.yml**: Added `test-coverage-runner` service
  - Same dependencies as test-runner (test-db, test-redis)
  - Mounts `coverage-report/` for report output
  - Uses SB-COVER for instrumentation

#### Coverage Report Features
- Expression coverage (% of expressions executed)
- Branch coverage (% of branches taken)
- Per-file HTML reports with line highlighting
- Green: executed, Red: not executed

#### Verification Results (2025-12-09)
- ✅ Docker: HTML report generated, all tests pass
- ✅ Local: HTML report generated (DB/Redis tests skipped as expected)

#### Sample Coverage (Main Files)
| File | Expression | Branch |
|------|------------|--------|
| db.lisp | 85.5% | 100.0% |
| model/post.lisp | 92.1% | 100.0% |
| service/post.lisp | 90.1% | 93.3% |
| util/validation.lisp | 88.2% | 100.0% |

### Commits

- Branch: `feat/sb-cover-integration`
- `fb931a5` feat: Add SB-COVER test coverage measurement

---

### Added - Test Coverage Expansion (model/post)

#### New Test File
- **test/model/post-test.lisp**: Comprehensive unit tests for Post model (separated from model-test.lisp)
  - `test-create-post`: Basic post creation
  - `test-create-post-published`: Creation with published flag
  - `test-find-post-by-id`: ID search (exists/not exists/invalid ID)
  - `test-find-posts-by-user-id-all`: Get all posts by user
  - `test-find-posts-by-user-id-published`: Get published only
  - `test-find-posts-by-user-id-draft`: Get draft only
  - `test-find-posts-by-user-id-pagination`: limit/offset behavior
  - `test-find-published-posts`: Public posts list with order verification (created_at DESC)
  - `test-find-published-posts-pagination`: limit/offset behavior
  - `test-count-published-posts`: Count published posts
  - `test-count-user-posts`: Count user posts
  - `test-post-to-alist`: alist conversion (all keys)
  - `test-post-to-alist-timestamp-format`: ISO8601 timestamp format
  - `test-post-accessors`: Accessor functions
  - `test-post-timestamps`: Auto-generated created_at/updated_at
  - `test-post-title-max-length`: Title max length (200 chars)
  - `test-post-content-empty`: Empty content allowed
  - 17 test cases total

#### Updated Test Files
- **test/fixtures.lisp**: Added post fixtures
  - `create-test-post`: Create test post with optional user/title/content/published
  - `create-test-posts`: Bulk post creation
  - `*default-test-post-title*`: Default test post title
  - `*default-test-post-content*`: Default test post content
- **test/model-test.lisp**: Minimized (only NOTE comment remains)
  - All post-related tests migrated to test/model/post-test.lisp

#### System Definition
- **voro.asd**: Added `post-test` to model module

### Commits

- Branch: `test/expand-coverage-web-post`
- `1a39786` test: Add comprehensive test coverage for post model

---

### Added - Test Coverage Expansion (web, main)

#### New Test Files
- **test/web-test.lisp**: Unit tests for web module (Caveman application definition)
  - `test-app-instance`: *app* existence, <web> class instance verification, Lack application conversion
  - `test-web-class-hierarchy`: <web> class definition, <app> inheritance verification
  - 5 test cases total

- **test/main-test.lisp**: Unit tests for main module (application lifecycle)
  - `test-initialize-tables`: Table initialization success, user table existence, idempotency
  - `test-server-state-management`: with-clean-server-state behavior, *server* definition
  - `test-stop-idempotent`: Double stop idempotency, *server* NIL after stop
  - `test-start-stop-cycle`: Start/stop verification with use-thread parameter
  - `test-start-db-failure-handling`: DB connection failure error re-throw, stop called
  - `test-start-redis-failure-handling`: Redis connection failure error re-throw, stop called
  - 12 test cases total

#### Source Code Changes
- **src/main.lisp**: Added `use-thread` parameter to `start` function
  - Enables background thread startup for testing
  - Suppresses console output when use-thread is true

#### System Definition
- **voro.asd**: Added test modules
  - `web-test` (depends on setup)
  - `main-test` (depends on setup, fixtures)

### Commits

- Branch: `test/expand-coverage-web-main`
- `3cb29a6` test: Add comprehensive test coverage for web and main modules

---

### Added - Test Coverage Expansion (service/auth, util/crypto, util/request)

#### Updated Test Files
- **test/service-test.lisp**: Added auth service edge case tests (+51 lines)
  - `test-logout-user`: Normal logout, idempotency with nonexistent session ID
  - `test-authenticate-user-edge-cases`: Login failure with nonexistent user
- **test/util-test.lisp**: Added crypto and request edge case tests (+130 lines)
  - `test-hash-password-edge-cases`: Empty, Japanese, special chars, long password, PBKDF2 format
  - `test-verify-password-edge-cases`: Empty, invalid format, empty hash, NIL hash, corrupted hash
  - `test-get-body-param-edge-cases`: Multibyte chars, special chars, empty key, NIL/empty values, duplicate keys
  - `test-validate-password-edge-cases`: 7/8 char boundary, 100 chars, special chars, spaces, Japanese
  - `test-validate-username-edge-cases`: 2/3/50/51 char boundary, underscore, hyphen, Japanese
  - `test-validate-email-edge-cases`: 254/255 char boundary, subdomains, @ position

#### Package Definition Updates
- **voro.test.service**: Added imports for `:logout-user`, `:session-exists-p`
- **voro.test.util**: Added import for `(:import-from :cl-ppcre :scan)`

#### Design Document Update
- **docs/design/test-expansion-auth-crypto-request.md**: Updated to v1.9
  - Status: "実装完了" (Implementation Complete)
  - Fixed SHA256 casing (ironclad outputs uppercase)
  - All approval items marked as completed

### Commits

- Branch: `test/expand-coverage-auth-crypto-request`
- `7afdb07` test: Add comprehensive test coverage for auth, crypto, and request modules

---

### Added - Test Coverage Expansion (redis)

#### New Test File
- **test/redis-test.lisp**: Comprehensive unit tests for Redis module
  - `test-calculate-retry-delay`: Exponential backoff calculation (7 assertions)
  - `test-connect-redis`: Normal connection with ping verification
  - `test-connect-redis-retry-failure`: Retry failure error, retry count verification
  - `test-disconnect-redis`: Normal disconnect, idempotency, error state cleanup
  - `test-redis-health-check-disabled`: Behavior when disabled
  - `test-redis-health-check-enabled`: Behavior when enabled
  - `test-redis-health-check-cache`: Cache behavior verification
  - `test-redis-health-check-failure`: Connection cleanup on ping failure
  - `test-ensure-redis-connected`: Reconnection behavior
  - `test-ensure-redis-connected-recovery`: Recovery after health check failure
  - `test-red-set-get`: SET/GET commands, overwrite, nonexistent key
  - `test-red-del`: DEL command, idempotency
  - `test-red-expire`: EXPIRE command, TTL decay, key expiration
  - `test-red-hash-commands`: HSET/HGET/HGETALL commands
  - `test-red-commands-auto-reconnect`: Auto-reconnect via command wrappers
  - 17 test cases total

#### Helper Macros
- **with-config-override**: Temporarily override config values for testing (same as db-test.lisp)
- **with-disconnected-redis**: Temporarily disconnect Redis for testing, with proper restoration

#### System Definition
- **voro.asd**: Added `redis-test` (depends on setup)

### Commits

- Branch: `test/expand-coverage-redis`

---

### Added - Test Coverage Expansion (db)

#### New Test File
- **test/db-test.lisp**: Comprehensive unit tests for database module
  - `test-calculate-retry-delay`: Exponential backoff calculation (7 assertions)
  - `test-build-connection-string`: Connection string format, URI reserved chars
  - `test-connect-db`: Normal connection, mito integration
  - `test-connect-db-retry-failure`: Retry failure error, retry count verification
  - `test-disconnect-db`: Normal disconnect, idempotency, error state cleanup
  - `test-db-health-check-disabled`: Behavior when disabled
  - `test-db-health-check-enabled`: Behavior when enabled
  - `test-db-health-check-cache`: Cache behavior verification
  - `test-db-health-check-failure`: Connection cleanup on failure
  - `test-db-health-check-failure-mito-state`: Mito connection cleared (post-fix behavior)
  - `test-ensure-db-connected`: Reconnection behavior
  - `test-ensure-db-connected-recovery`: Recovery after health check failure
  - 12 test cases total

#### Helper Macros
- **with-config-override**: Temporarily override config values for testing
- **with-disconnected-db**: Temporarily disconnect DB for testing, with proper restoration

#### System Definition
- **voro.asd**: Added `db-test` (depends on setup)

### Fixed - DB Health Check Mito Connection Cleanup

- **src/db.lisp**: Fixed `db-health-check` to also call `mito:disconnect-toplevel` on failure
  - Before: Only `*db-connection*` set to NIL, `mito.connection:*connection*` left dangling
  - After: Both connections properly cleaned up
  - Prevents exceptions when mito API called between failure and retry
  - Ensures consistency with `disconnect-db` behavior

### Commits

- Branch: `test/expand-coverage-db`
- `69cd976` test: Add comprehensive test coverage for db.lisp

---

### Added - Test Coverage Expansion (util/log, config, model/user)

#### New Test Files
- **test/util/log-test.lisp**: Unit tests for logging utilities
  - `generate-error-id`: Format validation (16-char alphanumeric), uniqueness
  - `log-level-priority`: Priority ordering (:debug < :info < :warn < :error)
  - `should-log-p`: Log level filtering tests
  - `format-log-message`: Basic format, with context, with error
  - `log-error`/`log-info`/`log-warn`/`log-debug`: File output verification
  - `log-level-filtering-integration`: End-to-end filter behavior tests
- **test/config-test.lisp**: Unit tests for configuration management
  - `valid-port-p`: Valid/invalid port numbers (1-65535 boundary)
  - `valid-env-p`: Valid/invalid environment names (development/test/production)
  - `valid-log-level-p`: Valid/invalid log levels
  - `valid-redis-db-p`: Valid/invalid Redis DB numbers (0-15)
  - `get-env`/`get-env-or-default`: Environment variable retrieval
  - `get-config`: Type conversion (:string/:integer/:keyword/:boolean), defaults, validators
  - Validator integration tests for APP_ENV, LOG_LEVEL, REDIS_DB
- **test/model/user-test.lisp**: Comprehensive user model tests (separated from model-test.lisp)
  - `create-user`: Basic creation, creation without email
  - `create-user-duplicate`: Duplicate username error handling
  - `find-user-by-id`: Existing/non-existing/invalid ID
  - `find-user-by-username`: Existing/non-existing/case-sensitivity
  - `user-email`: With/without email
  - `verify-user-password`: Correct/incorrect/empty password
  - `user-timestamps`: created_at/updated_at auto-generation
  - `user-id`: Positive integer, uniqueness

#### File Reorganization
- **test/model-test.lisp**: Removed `test-user-model` (migrated to model/user-test.lisp)
  - Only `test-post-model` remains
  - Added comment noting User tests migration

#### System Definition
- **voro.asd**: Updated voro/test system
  - Added `config-test` (depends on setup)
  - Added `util/log-test` in util module
  - Added new `model` module with `user-test`

#### Helper Macros
- **with-temp-log-file**: Temporary log file for testing file output
  - Suppresses stdout to prevent test noise
  - Auto-cleanup with unwind-protect
- **with-env-var**: Temporary environment variable setting (SBCL-only)
  - Proper restoration using sb-posix:unsetenv
  - Handles previously unset variables correctly

### Commits

- Branch: `test/expand-coverage-util-config-model`
- `ae9166c` test: Expand coverage for util/log, config, and model/user

---

### Added - Test Coverage Expansion

#### New Test File
- **test/util/response-test.lisp**: Unit tests for response utilities
  - `json-response`: Basic response, additional headers, nested alist, empty body
  - `response-success`: Basic success, custom status, headers, nested data, arrays, nil data
  - `response-error`: Basic error, error-id, no error-id, HTTP status codes, headers
  - 17 test cases total

#### Validation Boundary Tests (test/util-test.lisp)
- **test-validate-password-edge-cases**: 8 new test cases
  - 7/8 character boundary tests
  - 100 character long password
  - Special characters, spaces, Japanese characters
  - Numbers only (fail), letters only (fail)
- **test-validate-username-edge-cases**: 8 new test cases
  - 2/3/50/51 character boundary tests
  - Underscore (pass), hyphen (fail)
  - Japanese characters (fail), starting with number (fail)
- **test-validate-email-edge-cases**: 5 new test cases
  - 254/255 character boundary tests
  - Subdomains, @ position validation

#### Post Service Edge Case Tests (test/service-test.lisp)
- **test-create-new-post-edge-cases**: 10 new test cases
  - Title: empty/1/200/201 character boundaries, whitespace-only
  - Content: empty/1/10000/100000/100001 character boundaries
- **test-create-new-post-security**: 2 test cases
  - XSS script tag storage (stored as-is for frontend escaping)
  - SQL injection string storage (parameterized queries protect)
- **test-list-published-posts-pagination**: 5 test cases
  - page=0/-1 normalized to 1
  - per_page=0 normalized to 1, per_page=101 capped at 100
  - page=10001 capped at 10000

#### HTTP Integration Tests (test/handler/post-test.lisp)
- **post-list-pagination-edge-cases-test**: 4 test cases
  - page=0/10001 normalization, per_page=200 cap, empty array
- **post-get-invalid-id-test**: 3 test cases
  - String ID (400), decimal ID (400), large non-existent ID (404)
- **post-create-edge-cases-test**: 4 test cases
  - Title 1/200/201 character boundaries, XSS string storage

#### System Definition
- **voro.asd**: Added test/util module for response-test.lisp

### Fixed - Response Utility Bug

- **src/util/response.lisp**: Fixed `response-success` nil handling
  - Before: `(response-success nil)` → `{"success": true, "data": false}`
  - After: `(response-success nil)` → `{"success": true, "data": {}}`
  - Empty data now returns empty object instead of boolean false

### Fixed - Username Validation

- **src/util/validation.lisp**: Reject non-ASCII characters in username
  - Added check to ensure all characters are ASCII alphanumeric or underscore
  - Japanese characters and other non-ASCII now properly rejected

### Commits

- Branch: `test/expand-coverage-response-and-edge-cases`
- `0912f10` test: Expand coverage for response utilities and edge cases

### Added - Middleware Session Unit Tests

#### Test Infrastructure
- **test/middleware/session-test.lisp**: New unit test file for session management
  - 6 functions tested, 14 test cases total
  - Comprehensive coverage of session lifecycle

#### Test Cases
- **test-generate-session-id**: Session ID format and uniqueness validation
  - Verifies 32-character hexadecimal format
  - Confirms unique IDs on each generation
- **test-create-session**: Session creation and Redis storage
  - Validates session ID format
  - Confirms user_id retrieval from Redis
- **test-get-session-user-id**: Session to user_id retrieval
  - Valid session ID returns correct user_id
  - Invalid session ID returns NIL
  - NIL input returns NIL
- **test-get-current-user-id**: Request cookie to user_id extraction
  - Valid session cookie returns user_id
  - Invalid session cookie returns NIL
  - No cookies returns NIL
  - Other cookies only returns NIL
- **test-delete-session**: Session deletion
  - Successful deletion verified
  - Non-existent session deletion doesn't error
- **test-session-exists-p**: Session existence check
  - Returns T for existing session
  - Returns NIL for non-existent session

#### Technical Implementation
- **make-mock-request helper**: Dynamic symbol resolution for `lack.request:%make-request`
  - Avoids compile-time package dependency issues
  - Uses `find-symbol` + `funcall` for runtime resolution
- **cl-ppcre:scan**: Full package qualification instead of import-from
  - `scan` symbol not exported from cl-ppcre package

#### System Definition
- **voro.asd**: Added middleware test module
  - New `(:module "middleware" ...)` in voro/test system
  - Depends on setup and fixtures

#### Commits
- Branch: `test/middleware-session-unit-tests`
- `595b546` test: Add unit tests for middleware/session.lisp

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

#### Documentation Updates
- **.claude/project/patterns.md**: Fixed remaining outdated code examples
  - Line 91: Updated `(middleware:get-session-user-id)` to `(middleware:get-current-user-id *request*)`
  - Line 123: Updated `(middleware:get-session-user-id)` to `(middleware:get-current-user-id *request*)`
- **docs/design/refactor-remove-duplicate-code.md**: Added Section 10 "Remaining Tasks"
  - Documented implementation gaps found during design review
  - Marked as completed after fixes applied

#### Test Coverage
- All 6 backend test suites passing
- Manual API testing verified:
  - Authentication flow (register/login/logout)
  - Post CRUD operations
  - Error cases (401/400/403/404)

### Commits

- Branch: `refactor/remove-duplicate-code`
- `0db29c3` refactor: Remove duplicate code in handler layer
- (pending) docs: Fix remaining patterns.md outdated examples

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
