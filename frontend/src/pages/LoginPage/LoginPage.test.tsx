// pages/LoginPage/LoginPage.test.tsx
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
import { http, HttpResponse } from 'msw';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { LoginPage } from './LoginPage';
import { AuthProvider } from '../../contexts/AuthContext';
import { NotificationProvider } from '../../contexts/NotificationContext';
import { Toast } from '../../components/common/Toast/Toast';
import { server } from '../../test/mocks/server';
import { errorResponse } from '../../test/mocks/handlers';

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

// ルートエントリの型（state を含む場合に対応）
type RouteEntry = string | { pathname: string; state?: unknown };

// テストオプション
interface RenderOptions {
  route?: string;
  initialEntries?: RouteEntry[];
  setupAuth?: boolean;
}

// 認証済みユーザーをセットアップ
function setupAuthenticatedUser(userId: number = 1, username: string = 'testuser') {
  localStorage.setItem(
    'voro_auth',
    JSON.stringify({ userId, username })
  );
}

// テストヘルパー
function renderLoginPage(options: RenderOptions = {}) {
  const { route = '/login', initialEntries = [route], setupAuth = false } = options;

  if (setupAuth) {
    setupAuthenticatedUser();
  }

  const router = createMemoryRouter(
    [
      { path: '/login', element: <LoginPage /> },
      { path: '/posts/new', element: <div data-testid="new-post-page">PostEditorPage</div> },
      { path: '/posts/:id/edit', element: <div data-testid="edit-page">EditPage</div> },
    ],
    { initialEntries }
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

// リクエストボディをキャプチャするための変数
let capturedLoginRequest: { username: string; password: string } | null = null;

beforeEach(() => {
  capturedLoginRequest = null;
});

// ============================================================================
// Phase 1: 基本的なレンダリングとフォーム入力（#1-7）
// ============================================================================

describe('LoginPage - Initial Render', () => {
  // #1: フォーム要素が表示される
  it('renders login form elements', async () => {
    renderLoginPage();

    // AuthProvider の初期化を待つ
    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });
    expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'ログイン' })).toBeInTheDocument();
  });

  // #2: ログインボタンが初期状態で disabled
  it('disables login button initially when fields are empty', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: 'ログイン' })).toBeDisabled();
    });
  });

  // #3: プレースホルダーが正しく表示される
  it('displays correct placeholders', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByPlaceholderText('ユーザー名を入力')).toBeInTheDocument();
    });
    expect(screen.getByPlaceholderText('パスワードを入力')).toBeInTheDocument();
  });
});

describe('LoginPage - Form Input', () => {
  // #4: ユーザー名のみ入力でボタンは disabled
  it('keeps button disabled when only username is entered', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');

    expect(screen.getByRole('button', { name: 'ログイン' })).toBeDisabled();
  });

  // #5: パスワードのみ入力でボタンは disabled
  it('keeps button disabled when only password is entered', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');

    expect(screen.getByRole('button', { name: 'ログイン' })).toBeDisabled();
  });

  // #6: 両方入力でボタンが有効化
  it('enables button when both fields have value', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');

    expect(screen.getByRole('button', { name: 'ログイン' })).toBeEnabled();
  });

  // #7: 空白のみの入力ではボタンは disabled のまま
  it('keeps button disabled when inputs contain only whitespace', async () => {
    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    const usernameInput = screen.getByLabelText('ユーザー名');
    const passwordInput = screen.getByLabelText('パスワード');
    const submitButton = screen.getByRole('button', { name: 'ログイン' });

    // 初期状態: disabled
    expect(submitButton).toBeDisabled();

    // 空白のみ入力
    await userEvent.type(usernameInput, '   ');
    await userEvent.type(passwordInput, '   ');

    // 空白のみでは disabled のまま
    expect(submitButton).toBeDisabled();

    // 有効な値を入力すると有効化
    await userEvent.clear(usernameInput);
    await userEvent.clear(passwordInput);
    await userEvent.type(usernameInput, 'testuser');
    await userEvent.type(passwordInput, 'password123');

    expect(submitButton).toBeEnabled();
  });
});

// ============================================================================
// Phase 2: ログイン成功フロー（#8-10）
// ============================================================================

describe('LoginPage - Login Success', () => {
  // #8: ログイン成功で通知表示 + localStorage保存 + login引数検証
  it('verifies login arguments and localStorage storage on success', async () => {
    // リクエストボディをキャプチャするハンドラーに差し替え
    server.use(
      http.post('/api/auth/login', async ({ request }) => {
        const body = (await request.json()) as { username: string; password: string };
        capturedLoginRequest = body;
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 42, username: body.username },
          },
        });
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // 入力値
    const inputUsername = 'testuser';
    const inputPassword = 'securepassword123';

    await userEvent.type(screen.getByLabelText('ユーザー名'), inputUsername);
    await userEvent.type(screen.getByLabelText('パスワード'), inputPassword);
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // 1. 通知が表示されることを確認
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('ログインしました');
    });

    // 2. login引数検証: リクエストボディが入力値と一致することを確認
    expect(capturedLoginRequest).toEqual({
      username: inputUsername,
      password: inputPassword,
    });

    // 3. localStorage保存検証: voro_auth が期待構造で保存されることを確認
    const storedAuth = localStorage.getItem('voro_auth');
    expect(storedAuth).not.toBeNull();
    const parsedAuth = JSON.parse(storedAuth!);
    expect(parsedAuth).toEqual({
      userId: 42,
      username: inputUsername,
    });
  });

  // #9: ログイン成功でリダイレクト（replace: true）
  it('redirects to /posts/new with history replacement on login success', async () => {
    const { router } = renderLoginPage();

    // 初期状態
    expect(router.state.location.pathname).toBe('/login');

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    // replace: true により履歴が置換されている
    expect(router.state.historyAction).toBe('REPLACE');
    // リダイレクト先を確認
    expect(router.state.location.pathname).toBe('/posts/new');
  });

  // #10: location.state.from があればそちらへリダイレクト（replace: true）
  it('redirects to location.state.from with history replacement', async () => {
    const { router } = renderLoginPage({
      initialEntries: [
        { pathname: '/login', state: { from: { pathname: '/posts/1/edit' } } },
      ],
    });

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('edit-page')).toBeInTheDocument();
    });

    // replace: true により履歴が置換されている
    expect(router.state.historyAction).toBe('REPLACE');
    // リダイレクト先を確認
    expect(router.state.location.pathname).toBe('/posts/1/edit');
  });
});

// ============================================================================
// Phase 3: エラーハンドリング（#11-15）
// ============================================================================

describe('LoginPage - Login Failure', () => {
  // #11: API バリデーションエラー（400）でメッセージ表示
  it('shows error message on 400 validation error', async () => {
    const initialLocalStorage = localStorage.getItem('voro_auth');

    server.use(
      http.post('/api/auth/login', () => {
        return errorResponse.validationError('Invalid credentials');
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'wrongpassword');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // エラーメッセージが表示される
    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
    });

    // localStorage が変更されていないこと
    expect(localStorage.getItem('voro_auth')).toBe(initialLocalStorage);

    // 成功トーストが表示されないこと（alert がない、または「ログインしました」を含まない）
    const alert = screen.queryByRole('alert');
    if (alert) {
      expect(alert).not.toHaveTextContent('ログインしました');
    }
  });

  // #12: 認証エラー（401）でメッセージ表示
  it('shows error message on 401 unauthorized', async () => {
    const initialLocalStorage = localStorage.getItem('voro_auth');

    server.use(
      http.post('/api/auth/login', () => {
        return errorResponse.unauthorized();
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'wrongpassword');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // エラーメッセージが表示される
    await waitFor(() => {
      expect(screen.getByText('Unauthorized')).toBeInTheDocument();
    });

    // localStorage が変更されていないこと
    expect(localStorage.getItem('voro_auth')).toBe(initialLocalStorage);

    // 成功トーストが表示されないこと（alert がない、または「ログインしました」を含まない）
    const alert = screen.queryByRole('alert');
    if (alert) {
      expect(alert).not.toHaveTextContent('ログインしました');
    }
  });

  // #13: サーバーエラー（500）で汎用メッセージ表示
  it('shows error message on 500 server error', async () => {
    const initialLocalStorage = localStorage.getItem('voro_auth');

    server.use(
      http.post('/api/auth/login', () => {
        return errorResponse.serverError('test-error-id');
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // サーバーエラーメッセージが表示される
    await waitFor(() => {
      expect(screen.getByText('Internal server error')).toBeInTheDocument();
    });

    // localStorage が変更されていないこと
    expect(localStorage.getItem('voro_auth')).toBe(initialLocalStorage);

    // 成功トーストが表示されないこと（alert がない、または「ログインしました」を含まない）
    const alert = screen.queryByRole('alert');
    if (alert) {
      expect(alert).not.toHaveTextContent('ログインしました');
    }
  });

  // #14: ネットワークエラーでデフォルトメッセージ表示
  // NOTE: MSW v2 の HttpResponse.networkError() は Vitest + jsdom 環境では
  // 正しく動作しないため、このテストは todo として残しています。
  // 実際のブラウザ環境での E2E テストで検証することを推奨します。
  // LoginPage.tsx:42-44 の else ブランチ（ApiError 以外のエラー処理）は
  // コードレビューで確認済みです。
  it.todo('shows default error message on network error');
});

describe('LoginPage - Error Recovery', () => {
  // #15: エラー後の再送信でエラーがクリア
  it('clears error message after successful retry', async () => {
    // 最初は失敗、2回目は成功
    let callCount = 0;
    server.use(
      http.post('/api/auth/login', async ({ request }) => {
        callCount++;
        if (callCount === 1) {
          return errorResponse.unauthorized();
        }
        const body = (await request.json()) as { username: string; password: string };
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 1, username: body.username },
          },
        });
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // 最初のログイン試行（失敗）
    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'wrongpassword');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // エラーメッセージが表示される
    await waitFor(() => {
      expect(screen.getByText('Unauthorized')).toBeInTheDocument();
    });

    // パスワードを修正して再試行
    const passwordInput = screen.getByLabelText('パスワード');
    await userEvent.clear(passwordInput);
    await userEvent.type(passwordInput, 'correctpassword');
    await userEvent.click(screen.getByRole('button', { name: 'ログイン' }));

    // エラーメッセージが消えて成功通知が表示される
    await waitFor(() => {
      expect(screen.queryByText('Unauthorized')).not.toBeInTheDocument();
    });
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('ログインしました');
    });
  });
});

// ============================================================================
// Phase 4: ローディング状態、自動リダイレクト、認証状態検証（#16-20）
// ============================================================================

describe('LoginPage - Loading State', () => {
  // #16: 送信中はボタンが disabled かつ isLoading 状態
  it('shows loading state during submission', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });

    let resolveDelay!: () => void;
    const delayPromise = new Promise<void>((resolve) => {
      resolveDelay = resolve;
    });

    server.use(
      http.post('/api/auth/login', async () => {
        await delayPromise;
        return errorResponse.unauthorized();
      })
    );

    renderLoginPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('パスワード'), 'wrongpassword');

    const submitButton = screen.getByRole('button', { name: 'ログイン' });
    await userEvent.click(submitButton);

    // 即座に検証（レスポンス待ち中）
    expect(submitButton).toBeDisabled();
    expect(screen.getByLabelText('読み込み中')).toBeInTheDocument();

    // 遅延を解決してレスポンスを返す
    resolveDelay();

    // レスポンス完了後（失敗なので画面は残る）
    await waitFor(() => {
      expect(screen.queryByLabelText('読み込み中')).not.toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'ログイン' })).toBeEnabled();
      expect(screen.getByText('Unauthorized')).toBeInTheDocument();
    });

    vi.useRealTimers();
  });
});

describe('LoginPage - Auto Redirect', () => {
  // #17: 認証済みユーザーは自動的にリダイレクト（replace: true）
  it('redirects authenticated user with history replacement', async () => {
    const { router } = renderLoginPage({ setupAuth: true });

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    // replace: true により履歴が置換されている
    expect(router.state.historyAction).toBe('REPLACE');
    // リダイレクト先を確認
    expect(router.state.location.pathname).toBe('/posts/new');

    // ログインフォームが表示されていないことを確認
    expect(screen.queryByLabelText('ユーザー名')).not.toBeInTheDocument();
  });
});

describe('LoginPage - Auth State Verification', () => {
  // #18: 保存された資格情報が無効（/api/me/posts 401）でログインページが表示される
  it('clears localStorage and shows login form when stored credentials are invalid (401)', async () => {
    setupAuthenticatedUser(1, 'olduser');
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    server.use(
      http.get('/api/me/posts', () => {
        return errorResponse.unauthorized();
      })
    );

    renderLoginPage();

    // ログインフォームが表示されることを確認
    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // localStorage が削除されていることを確認
    expect(localStorage.getItem('voro_auth')).toBeNull();

    // リダイレクトが発生していないことを確認
    expect(screen.queryByTestId('new-post-page')).not.toBeInTheDocument();
  });

  // #19: /api/me/posts 500 で認証状態を楽観的に保持
  it('maintains authentication state when /api/me/posts returns 500', async () => {
    setupAuthenticatedUser(1, 'testuser');
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    server.use(
      http.get('/api/me/posts', () => {
        return errorResponse.serverError('test-error-id');
      })
    );

    renderLoginPage();

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    // localStorage が維持されていることを確認
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    // ログインフォームが表示されていないことを確認
    expect(screen.queryByLabelText('ユーザー名')).not.toBeInTheDocument();
  });

  // #20: /api/me/posts ネットワークエラーで認証状態を楽観的に保持
  it('maintains authentication state when /api/me/posts has network error', async () => {
    setupAuthenticatedUser(1, 'testuser');
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.networkError();
      })
    );

    renderLoginPage();

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    // localStorage が維持されていることを確認
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    // ログインフォームが表示されていないことを確認
    expect(screen.queryByLabelText('ユーザー名')).not.toBeInTheDocument();
  });
});
