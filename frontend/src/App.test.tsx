// App.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

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

import { createMemoryRouter, RouterProvider, Navigate } from 'react-router';

import App, { NotFoundPage } from './App';
import { AuthProvider } from './contexts/AuthContext';
import { NotificationProvider } from './contexts/NotificationContext';
import { LoginPage } from './pages/LoginPage/LoginPage';
import { PostEditorPage } from './pages/PostEditorPage/PostEditorPage';
import { ProtectedRoute } from './components/common/ProtectedRoute/ProtectedRoute';
import { Toast } from './components/common/Toast/Toast';

import { server } from './test/mocks/server';
import { setupAuthenticatedUser } from './test/utils';

interface RenderOptions {
  initialPath?: string;
  setupAuth?: boolean;
}

/**
 * App のルート設定をテストするためのヘルパー関数
 *
 * createBrowserRouter を createMemoryRouter に置換して実行します。
 * App.tsx と同じルート構成・プロバイダー階層を再現します。
 *
 * @param options - レンダリングオプション
 * @param options.initialPath - 初期パス（デフォルト: '/'）
 * @param options.setupAuth - 認証済み状態でセットアップするか（デフォルト: false）
 * @returns {{ router: ReturnType<typeof createMemoryRouter> } & ReturnType<typeof render>}
 *          render結果 + routerインスタンス（URL検証用）
 *
 * @example
 * // 認証済みで /posts/new へアクセス
 * const { router } = renderApp({ initialPath: '/posts/new', setupAuth: true });
 *
 * @note App.tsx のルート変更時は、このヘルパー内のルート構成も同期すること
 */
function renderApp(options: RenderOptions = {}) {
  const { initialPath = '/', setupAuth = false } = options;

  if (setupAuth) {
    setupAuthenticatedUser();
  }

  // App.tsx と同じルート構成を createMemoryRouter で再現
  // NOTE: App.tsx のルート変更時は同期を維持すること
  const router = createMemoryRouter(
    [
      { path: '/login', element: <LoginPage /> },
      {
        path: '/posts/new',
        element: (
          <ProtectedRoute>
            <PostEditorPage mode="create" />
          </ProtectedRoute>
        ),
      },
      {
        path: '/posts/:id/edit',
        element: (
          <ProtectedRoute>
            <PostEditorPage mode="edit" />
          </ProtectedRoute>
        ),
      },
      { path: '/', element: <Navigate to="/posts/new" replace /> },
      { path: '*', element: <NotFoundPage /> },
    ],
    { initialEntries: [initialPath] }
  );

  const result = render(
    <AuthProvider>
      <NotificationProvider>
        <RouterProvider router={router} />
        <Toast />
      </NotificationProvider>
    </AuthProvider>
  );

  return { ...result, router };
}

// MSW lifecycle
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  server.resetHandlers();
  vi.useRealTimers();
});
afterAll(() => server.close());

// localStorage cleanup
beforeEach(() => {
  localStorage.clear();
});

describe('App - Routing', () => {
  it('shows LoginPage on /login route (APP-1)', async () => {
    renderApp({ initialPath: '/login' });

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });
    expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'ログイン' })).toBeInTheDocument();
  });

  it('shows PostEditorPage on /posts/new when authenticated (APP-2)', async () => {
    const { router } = renderApp({ initialPath: '/posts/new', setupAuth: true });

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    expect(router.state.location.pathname).toBe('/posts/new');
  });

  it('shows PostEditorPage in edit mode on /posts/:id/edit when authenticated (APP-3)', async () => {
    const { router } = renderApp({ initialPath: '/posts/1/edit', setupAuth: true });

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    expect(router.state.location.pathname).toBe('/posts/1/edit');
  });

  it('redirects from / to /posts/new when authenticated (APP-4a)', async () => {
    const { router } = renderApp({ initialPath: '/', setupAuth: true });

    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/posts/new');
    });

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });
  });

  it('redirects from / to /login when not authenticated (APP-4b)', async () => {
    const { router } = renderApp({ initialPath: '/' });

    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/login');
    });

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });
  });
});

describe('App - NotFoundPage', () => {
  it('shows NotFoundPage for unknown routes (APP-5)', async () => {
    const { router } = renderApp({ initialPath: '/unknown-path' });

    await waitFor(() => {
      expect(screen.getByText('404')).toBeInTheDocument();
    });
    expect(screen.getByText('ページが見つかりません')).toBeInTheDocument();

    expect(router.state.location.pathname).toBe('/unknown-path');
  });

  it('navigates to /posts/new from 404 page link (APP-6)', async () => {
    const { router } = renderApp({ initialPath: '/unknown-path', setupAuth: true });

    await waitFor(() => {
      expect(screen.getByText('404')).toBeInTheDocument();
    });

    await userEvent.click(screen.getByText('新規作成ページへ'));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/posts/new');
    });

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });
  });
});

// =============================================================================
// App - Direct Mount
// =============================================================================
describe('App - Direct Mount', () => {
  /**
   * App コンポーネントを直接マウントしてカバレッジを確保
   *
   * 注意: createBrowserRouter は jsdom 環境でも動作するが、
   * 一部のブラウザ API（history.pushState など）が制限される。
   * このテストでは「マウントできること」と「初期画面の表示」を検証。
   */
  it('mounts App component and renders initial route (APP-7)', async () => {
    // jsdom 環境での createBrowserRouter の制限によるエラーを抑制
    // React Router が history API を使用する際に警告が出る場合があるため
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      render(<App />);

      // App がマウントされると、以下のフローが発生:
      // 1. / へアクセス
      // 2. /posts/new へリダイレクト（Navigate）
      // 3. 未認証なので /login へリダイレクト（ProtectedRoute）
      // 4. LoginPage が表示される
      await waitFor(
        () => {
          expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
        },
        { timeout: 3000 }
      );

      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'ログイン' })).toBeInTheDocument();
    } finally {
      // テスト失敗時も確実にスパイを復元
      consoleSpy.mockRestore();
    }
  });
});
