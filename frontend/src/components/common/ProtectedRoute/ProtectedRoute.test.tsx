// components/common/ProtectedRoute/ProtectedRoute.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  afterEach,
  beforeEach,
  vi,
} from 'vitest';
import { http, HttpResponse } from 'msw';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { ProtectedRoute } from './ProtectedRoute';
import { AuthProvider, useAuth } from '../../../contexts/AuthContext';
import { server } from '../../../test/mocks/server';
import { errorResponse } from '../../../test/mocks/handlers';
import { setupAuthenticatedUser } from '../../../test/utils';

// MSW ライフサイクル
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  server.resetHandlers();
  vi.useRealTimers();
});
afterAll(() => server.close());

// localStorage クリーンアップ
beforeEach(() => {
  localStorage.clear();
});

interface RenderOptions {
  initialPath?: string;
  setupAuth?: boolean;
}

/**
 * ProtectedRoute をテストするためのヘルパー関数
 */
function renderProtectedRoute(options: RenderOptions = {}) {
  const { initialPath = '/protected', setupAuth = false } = options;

  if (setupAuth) {
    setupAuthenticatedUser();
  }

  // login/logout 関数を外部に公開するための参照
  let loginFn!: (username: string, password: string) => Promise<void>;
  let logoutFn!: () => Promise<void>;

  // AuthContext の関数を露出するためのコンシューマーコンポーネント
  const AuthFunctionExposer = () => {
    const { login, logout } = useAuth();
    loginFn = login;
    logoutFn = logout;
    return null;
  };

  const router = createMemoryRouter(
    [
      { path: '/login', element: <div data-testid="login-page">Login Page</div> },
      {
        path: '/protected',
        element: (
          <ProtectedRoute>
            <div data-testid="protected-content">Protected Content</div>
          </ProtectedRoute>
        ),
      },
    ],
    { initialEntries: [initialPath] }
  );

  const result = render(
    <AuthProvider>
      <AuthFunctionExposer />
      <RouterProvider router={router} />
    </AuthProvider>
  );

  return {
    ...result,
    router,
    login: (username: string, password: string) => loginFn(username, password),
    logout: () => logoutFn(),
  };
}

// =============================================================================
// Phase 1: ローディング状態（PR-1〜PR-2）
// =============================================================================
describe('ProtectedRoute - Loading State', () => {
  // PR-1, PR-2: isLoading: true → Spinner表示、children非表示
  it('shows spinner and hides children when loading (PR-1, PR-2)', async () => {
    // Arrange: localStorage を設定（checkAuth が API を呼ぶ条件）
    setupAuthenticatedUser();

    // API を遅延させる
    server.use(
      http.get('/api/me/posts', async () => {
        await new Promise((r) => setTimeout(r, 50));
        return HttpResponse.json({ success: true, data: { posts: [] } });
      })
    );

    // Act
    renderProtectedRoute({ initialPath: '/protected' });

    // Assert PR-1: Spinner が表示される
    expect(screen.getByLabelText('読み込み中')).toBeInTheDocument();

    // Assert PR-2: children は表示されない
    expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument();

    // ローディング完了後
    await waitFor(() => {
      expect(screen.queryByLabelText('読み込み中')).not.toBeInTheDocument();
    });

    // children が表示される
    expect(screen.getByTestId('protected-content')).toBeInTheDocument();
  });
});

// =============================================================================
// Phase 2: 未認証時のリダイレクト（PR-3〜PR-5）
// =============================================================================
describe('ProtectedRoute - Redirect when Unauthenticated', () => {
  // PR-3: isAuthenticated: false → /login へリダイレクト
  it('redirects to /login when not authenticated (PR-3)', async () => {
    // Arrange: localStorage なし（未認証状態）
    const { router } = renderProtectedRoute({ initialPath: '/protected' });

    // Assert: /login へリダイレクトされる
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });

    // login-page が表示される
    expect(screen.getByTestId('login-page')).toBeInTheDocument();

    // protected-content は表示されない
    expect(screen.queryByTestId('protected-content')).not.toBeInTheDocument();
  });

  // PR-4: リダイレクト時に state.from が Locationオブジェクトで設定される
  it('passes from location in state when redirecting (PR-4)', async () => {
    // Arrange: localStorage なし（未認証状態）
    const { router } = renderProtectedRoute({ initialPath: '/protected' });

    // Assert: /login へリダイレクトされる
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });

    // state.from に元のパスが含まれている
    expect(router.state.location.state).toEqual({
      from: expect.objectContaining({
        pathname: '/protected',
      }),
    });
  });

  // PR-5: リダイレクトは replace: true
  it('redirects with replace: true (PR-5)', async () => {
    // 未認証状態でマウント
    const { router } = renderProtectedRoute({ initialPath: '/protected' });

    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });

    // HistoryAction が REPLACE であることを検証
    expect(router.state.historyAction).toBe('REPLACE');
  });
});

// =============================================================================
// Phase 3: 認証済み時（PR-6）
// =============================================================================
describe('ProtectedRoute - Authenticated Access', () => {
  // PR-6: isAuthenticated: true → children表示
  it('shows children when authenticated (PR-6)', async () => {
    // Arrange: 認証済み状態
    const { router } = renderProtectedRoute({
      initialPath: '/protected',
      setupAuth: true,
    });

    // Assert: 保護コンテンツが表示される
    await waitFor(() => {
      expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    });

    // /login にリダイレクトされていない
    expect(router.state.location.pathname).toBe('/protected');

    // Spinner は表示されていない
    expect(screen.queryByLabelText('読み込み中')).not.toBeInTheDocument();
  });
});

// =============================================================================
// Phase 4: 統合テスト（PR-7〜PR-9）
// =============================================================================
describe('ProtectedRoute - Integration Tests', () => {
  // PR-7: 未認証 → ログイン → 保護ルートアクセス可能
  it('allows access to protected route after login (PR-7)', async () => {
    const { router, login } = renderProtectedRoute({ initialPath: '/protected' });

    // 未認証状態 → /login へリダイレクト
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });

    // ログイン実行
    await login('testuser', 'password123');

    // 保護ルートへ遷移
    await router.navigate('/protected');

    await waitFor(() => {
      expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    });
  });

  // PR-8: 認証済み → ログアウト → 保護ルートからリダイレクト
  it('redirects from protected route after logout (PR-8)', async () => {
    const { router, logout } = renderProtectedRoute({
      initialPath: '/protected',
      setupAuth: true,
    });

    // 保護コンテンツが表示される
    await waitFor(() => {
      expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    });

    // ログアウト実行
    await logout();

    // /login へリダイレクト
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });
  });

  // PR-9: 認証検証中(500) → 楽観的に保護ルート表示
  it('shows protected content optimistically on 500 error (PR-9)', async () => {
    // Arrange: localStorage を設定（認証済み状態をシミュレート）
    setupAuthenticatedUser(1, 'testuser');

    // console.error を抑制（楽観的復元時のログ出力）
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    // API が 500 エラーを返す
    server.use(
      http.get('/api/me/posts', () => errorResponse.serverError())
    );

    // Act
    const { router } = renderProtectedRoute({
      initialPath: '/protected',
    });

    // Assert: isLoading 完了を待つ
    await waitFor(() => {
      // 保護コンテンツが表示される（楽観的認証）
      expect(screen.getByTestId('protected-content')).toBeInTheDocument();
    });

    // /login にリダイレクトされていない
    expect(router.state.location.pathname).toBe('/protected');

    // localStorage は維持されている
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    consoleSpy.mockRestore();
  });
});
