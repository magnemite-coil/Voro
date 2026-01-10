// pages/SignupPage/SignupPage.test.tsx
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
import { SignupPage } from './SignupPage';
import { AuthProvider } from '../../contexts/AuthContext';
import { NotificationProvider } from '../../contexts/NotificationContext';
import { Toast } from '../../components/common/Toast/Toast';
import { server } from '../../test/mocks/server';
import { errorResponse } from '../../test/mocks/handlers';
import { setupAuthenticatedUser } from '../../test/utils';

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

// テストヘルパー
function renderSignupPage(options: RenderOptions = {}) {
  const { route = '/signup', initialEntries = [route], setupAuth = false } = options;

  if (setupAuth) {
    setupAuthenticatedUser();
  }

  const router = createMemoryRouter(
    [
      { path: '/signup', element: <SignupPage /> },
      { path: '/login', element: <div data-testid="login-page">Login</div> },
      { path: '/posts/new', element: <div data-testid="new-post-page">PostEditor</div> },
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
let capturedSignupRequest: { username: string; email: string; password: string } | null = null;

beforeEach(() => {
  capturedSignupRequest = null;
});

// ============================================================================
// Phase 1: 基本的なレンダリングとフォーム入力（#1-8）
// ============================================================================

describe('SignupPage - Initial Render', () => {
  // #1: フォーム要素（4つのフィールド + ボタン + トグルボタン2つ）が表示される
  it('renders signup form elements', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });
    expect(screen.getByLabelText('メールアドレス')).toBeInTheDocument();
    expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    expect(screen.getByLabelText('パスワード（確認）')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'サインアップ' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'パスワードを表示' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '確認パスワードを表示' })).toBeInTheDocument();
  });

  // #2: 初期状態でボタンがdisabled
  it('disables signup button initially when fields are empty', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: 'サインアップ' })).toBeDisabled();
    });
  });

  // #3: プレースホルダーが正しく表示される
  it('displays correct placeholders', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByPlaceholderText('英字で始まる3文字以上（英数字と_のみ）')).toBeInTheDocument();
    });
    expect(screen.getByPlaceholderText('example@email.com')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('8文字以上（英字と数字を含む）')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('パスワードを再入力')).toBeInTheDocument();
  });
});

describe('SignupPage - Form Input', () => {
  // #4: ユーザー名のみ入力でボタンはdisabledのまま
  it('keeps button disabled when only username is entered', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');

    expect(screen.getByRole('button', { name: 'サインアップ' })).toBeDisabled();
  });

  // #5: メールのみ入力でボタンはdisabledのまま
  it('keeps button disabled when only email is entered', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('メールアドレス')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');

    expect(screen.getByRole('button', { name: 'サインアップ' })).toBeDisabled();
  });

  // #6: パスワードのみ入力でボタンはdisabledのまま
  it('keeps button disabled when only password is entered', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');

    expect(screen.getByRole('button', { name: 'サインアップ' })).toBeDisabled();
  });

  // #7: すべて入力するとボタンが有効化
  it('enables button when all fields have value', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');

    expect(screen.getByRole('button', { name: 'サインアップ' })).toBeEnabled();
  });

  // #8: 空白のみの入力ではボタンはdisabledのまま
  it('keeps button disabled when inputs contain only whitespace', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    const usernameInput = screen.getByLabelText('ユーザー名');
    const emailInput = screen.getByLabelText('メールアドレス');
    const passwordInput = screen.getByLabelText('パスワード');
    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');
    const submitButton = screen.getByRole('button', { name: 'サインアップ' });

    // 初期状態: disabled
    expect(submitButton).toBeDisabled();

    // 空白のみ入力
    await userEvent.type(usernameInput, '   ');
    await userEvent.type(emailInput, '   ');
    await userEvent.type(passwordInput, '   ');
    await userEvent.type(confirmPasswordInput, '   ');

    // 空白のみでは disabled のまま
    expect(submitButton).toBeDisabled();
  });
});

// ============================================================================
// Phase 2: パスワード一致チェック（onBlur）（#9-12）
// ============================================================================

describe('SignupPage - Password Mismatch Check', () => {
  // #9: 確認パスワードからフォーカスアウト時、不一致ならエラー表示
  it('shows mismatch error on blur when passwords do not match', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'different456');
    await userEvent.tab(); // フォーカスアウト

    expect(screen.getByText('Passwords do not match')).toBeInTheDocument();
  });

  // #10: パスワードが一致している場合はエラー非表示
  it('does not show error when passwords match', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.tab(); // フォーカスアウト

    expect(screen.queryByText('Passwords do not match')).not.toBeInTheDocument();
  });

  // #11: エラー表示後、パスワードを修正するとエラーがクリア
  it('clears mismatch error when password is fixed', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const passwordInput = screen.getByLabelText('パスワード');
    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');

    // 不一致状態にする
    await userEvent.type(passwordInput, 'password123');
    await userEvent.type(confirmPasswordInput, 'different456');
    await userEvent.tab();
    expect(screen.getByText('Passwords do not match')).toBeInTheDocument();

    // パスワードを修正
    await userEvent.clear(passwordInput);
    await userEvent.type(passwordInput, 'different456');

    expect(screen.queryByText('Passwords do not match')).not.toBeInTheDocument();
  });

  // #12: エラー表示後、確認パスワードを修正するとエラーがクリア
  it('clears mismatch error when confirm password is fixed', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const passwordInput = screen.getByLabelText('パスワード');
    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');

    // 不一致状態にする
    await userEvent.type(passwordInput, 'password123');
    await userEvent.type(confirmPasswordInput, 'different456');
    await userEvent.tab();
    expect(screen.getByText('Passwords do not match')).toBeInTheDocument();

    // 確認パスワードを修正
    await userEvent.clear(confirmPasswordInput);
    await userEvent.type(confirmPasswordInput, 'password123');

    expect(screen.queryByText('Passwords do not match')).not.toBeInTheDocument();
  });
});

// ============================================================================
// Phase 3: サインアップ成功フロー（#13-15）
// ============================================================================

describe('SignupPage - Signup Success', () => {
  // #13: サインアップ成功で通知表示 + localStorage保存 + signup引数検証
  it('verifies signup arguments and localStorage storage on success', async () => {
    // リクエストボディをキャプチャするハンドラーに差し替え
    server.use(
      http.post('/api/auth/register', async ({ request }) => {
        const body = (await request.json()) as { username: string; email: string; password: string };
        capturedSignupRequest = body;
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 42, username: body.username },
          },
        });
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // 入力値
    const inputUsername = 'newuser';
    const inputEmail = 'test@example.com';
    const inputPassword = 'securepassword123';

    await userEvent.type(screen.getByLabelText('ユーザー名'), inputUsername);
    await userEvent.type(screen.getByLabelText('メールアドレス'), inputEmail);
    await userEvent.type(screen.getByLabelText('パスワード'), inputPassword);
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), inputPassword);
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    // 1. 通知が表示されることを確認
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('アカウントを作成しました');
    });

    // 2. signup引数検証: リクエストボディが入力値と一致することを確認
    expect(capturedSignupRequest).toEqual({
      username: inputUsername,
      email: inputEmail,
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

  // #13.5: 送信前トリム処理の検証（ユーザー名・メールのみ、パスワードはそのまま）
  it('trims username and email before sending request', async () => {
    let capturedBody: { username: string; email: string; password: string } | null = null;

    server.use(
      http.post('/api/auth/register', async ({ request }) => {
        capturedBody = (await request.json()) as typeof capturedBody;
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 99, username: capturedBody!.username },
          },
        });
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // 先頭/末尾に空白を含む入力
    await userEvent.type(screen.getByLabelText('ユーザー名'), '  spaceduser  ');
    await userEvent.type(screen.getByLabelText('メールアドレス'), '  spaced@example.com  ');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('アカウントを作成しました');
    });

    // リクエストボディがトリム済みであることを確認
    expect(capturedBody).not.toBeNull();
    expect(capturedBody!.username).toBe('spaceduser');
    expect(capturedBody!.email).toBe('spaced@example.com');
    // パスワードはトリムされない
    expect(capturedBody!.password).toBe('password123');
  });

  // #14: サインアップ成功で /posts/new にリダイレクト（replace: true）
  it('redirects to /posts/new with history replacement on signup success', async () => {
    const { router } = renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'newuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    expect(router.state.historyAction).toBe('REPLACE');
    expect(router.state.location.pathname).toBe('/posts/new');
  });

  // #15: location.state.from があればそちらへリダイレクト（replace: true）
  it('redirects to location.state.from with history replacement', async () => {
    const { router } = renderSignupPage({
      initialEntries: [
        { pathname: '/signup', state: { from: { pathname: '/posts/1/edit' } } },
      ],
    });

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'newuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      expect(screen.getByTestId('edit-page')).toBeInTheDocument();
    });

    expect(router.state.historyAction).toBe('REPLACE');
    expect(router.state.location.pathname).toBe('/posts/1/edit');
  });
});

// ============================================================================
// Phase 4: エラーハンドリング（#16-19）
// ============================================================================

describe('SignupPage - Signup Failure', () => {
  // #16: バリデーションエラー（400）でメッセージ表示
  it('shows error message on 400 validation error', async () => {
    const initialLocalStorage = localStorage.getItem('voro_auth');

    server.use(
      http.post('/api/auth/register', () => {
        return errorResponse.validationError('Username must be at least 3 characters');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'ab');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    // エラーメッセージがユーザー名フィールド下に表示される
    await waitFor(() => {
      expect(screen.getByText('Username must be at least 3 characters')).toBeInTheDocument();
    });

    // localStorage が変更されていないこと
    expect(localStorage.getItem('voro_auth')).toBe(initialLocalStorage);
  });

  // #17: 重複ユーザー名エラーでメッセージ表示
  it('shows error message on duplicate username', async () => {
    server.use(
      http.post('/api/auth/register', () => {
        return errorResponse.validationError('Username already exists');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'existinguser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      expect(screen.getByText('Username already exists')).toBeInTheDocument();
    });
  });

  // #18: サーバーエラー（500）でメッセージ表示
  it('shows error message on 500 server error', async () => {
    server.use(
      http.post('/api/auth/register', () => {
        return errorResponse.serverError('test-error-id');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'newuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    // サーバーエラーメッセージが表示される（error_id を含む）
    await waitFor(() => {
      expect(screen.getByText(/サーバーエラーが発生しました/)).toBeInTheDocument();
    });
  });

  // #19: パスワード不一致で送信するとエラー表示（onBlur未発火の場合）
  it('shows mismatch error on submit when passwords do not match', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'newuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'different456');
    // タブを押さずに直接送信
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    expect(screen.getByText('Passwords do not match')).toBeInTheDocument();
  });
});

// ============================================================================
// Phase 5: エラー回復（#20）
// ============================================================================

describe('SignupPage - Error Recovery', () => {
  // #20: エラー後の再送信でサーバーエラーがクリア
  it('clears error message after successful retry', async () => {
    // 最初は失敗、2回目は成功
    let callCount = 0;
    server.use(
      http.post('/api/auth/register', async ({ request }) => {
        callCount++;
        if (callCount === 1) {
          return errorResponse.validationError('Username already exists');
        }
        const body = (await request.json()) as { username: string; email: string; password: string };
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 1, username: body.username },
          },
        });
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    // 最初のサインアップ試行（失敗）
    await userEvent.type(screen.getByLabelText('ユーザー名'), 'existinguser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    // エラーメッセージが表示される
    await waitFor(() => {
      expect(screen.getByText('Username already exists')).toBeInTheDocument();
    });

    // ユーザー名を修正して再試行
    const usernameInput = screen.getByLabelText('ユーザー名');
    await userEvent.clear(usernameInput);
    await userEvent.type(usernameInput, 'newuser');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    // エラーメッセージが消えて成功通知が表示される
    await waitFor(() => {
      expect(screen.queryByText('Username already exists')).not.toBeInTheDocument();
    });
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('アカウントを作成しました');
    });
  });
});

// ============================================================================
// Phase 6: ローディング状態と自動リダイレクト（#21-22）
// ============================================================================

describe('SignupPage - Loading State', () => {
  // #21: 送信中はボタンがdisabled + Spinner表示
  it('shows loading state during submission', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    // fake timers 使用時は userEvent を advanceTimers オプションでセットアップ
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });

    let resolveDelay!: () => void;
    const delayPromise = new Promise<void>((resolve) => {
      resolveDelay = resolve;
    });

    server.use(
      http.post('/api/auth/register', async () => {
        await delayPromise;
        return errorResponse.validationError('Test error');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await user.type(screen.getByLabelText('ユーザー名'), 'newuser');
    await user.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await user.type(screen.getByLabelText('パスワード'), 'password123');
    await user.type(screen.getByLabelText('パスワード（確認）'), 'password123');

    const submitButton = screen.getByRole('button', { name: 'サインアップ' });
    await user.click(submitButton);

    // 即座に検証（レスポンス待ち中）
    expect(submitButton).toBeDisabled();
    expect(screen.getByLabelText('読み込み中')).toBeInTheDocument();

    // 遅延を解決してレスポンスを返す
    resolveDelay();

    // レスポンス完了後
    await waitFor(() => {
      expect(screen.queryByLabelText('読み込み中')).not.toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'サインアップ' })).toBeEnabled();
    });

    vi.useRealTimers();
  });
});

describe('SignupPage - Auto Redirect', () => {
  // #22: 認証済みユーザーは自動リダイレクト
  it('redirects authenticated user with history replacement', async () => {
    const { router } = renderSignupPage({ setupAuth: true });

    // リダイレクト完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });

    expect(router.state.historyAction).toBe('REPLACE');
    expect(router.state.location.pathname).toBe('/posts/new');

    // サインアップフォームが表示されていないことを確認
    expect(screen.queryByLabelText('ユーザー名')).not.toBeInTheDocument();
  });
});

// ============================================================================
// Phase 7: ナビゲーション（#23）
// ============================================================================

describe('SignupPage - Navigation', () => {
  // #23: ログインへのリンクが機能する
  it('navigates to login page when clicking login link', async () => {
    const { router } = renderSignupPage();

    await waitFor(() => {
      expect(screen.getByRole('link', { name: 'ログイン' })).toBeInTheDocument();
    });

    await userEvent.click(screen.getByRole('link', { name: 'ログイン' }));

    await waitFor(() => {
      expect(screen.getByTestId('login-page')).toBeInTheDocument();
    });

    expect(router.state.location.pathname).toBe('/login');
  });
});

// ============================================================================
// Phase 8: パスワード表示トグル（#24-29）
// ============================================================================

describe('SignupPage - Password Toggle', () => {
  // #24: パスワードトグルボタンクリックでtype属性がpassword→textに切り替わる
  it('toggles password visibility from password to text', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const passwordInput = screen.getByLabelText('パスワード');
    const toggleButton = screen.getByRole('button', { name: 'パスワードを表示' });

    expect(passwordInput).toHaveAttribute('type', 'password');

    await userEvent.click(toggleButton);

    expect(passwordInput).toHaveAttribute('type', 'text');
    expect(toggleButton).toHaveAttribute('aria-label', 'パスワードを隠す');
  });

  // #25: 再クリックでtype属性がtext→passwordに戻る
  it('toggles password visibility from text back to password', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const passwordInput = screen.getByLabelText('パスワード');
    const toggleButton = screen.getByRole('button', { name: 'パスワードを表示' });

    await userEvent.click(toggleButton);
    expect(passwordInput).toHaveAttribute('type', 'text');

    await userEvent.click(toggleButton);
    expect(passwordInput).toHaveAttribute('type', 'password');
    expect(toggleButton).toHaveAttribute('aria-label', 'パスワードを表示');
  });

  // #26: 確認パスワードトグルボタンも同様に動作する
  it('toggles confirm password visibility', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード（確認）')).toBeInTheDocument();
    });

    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');
    const toggleButton = screen.getByRole('button', { name: '確認パスワードを表示' });

    expect(confirmPasswordInput).toHaveAttribute('type', 'password');

    await userEvent.click(toggleButton);

    expect(confirmPasswordInput).toHaveAttribute('type', 'text');
    expect(toggleButton).toHaveAttribute('aria-label', '確認パスワードを隠す');
  });

  // #27: トグルボタンに適切なaria-labelが設定されている
  it('has correct aria-labels on toggle buttons', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByRole('button', { name: 'パスワードを表示' })).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: '確認パスワードを表示' })).toBeInTheDocument();
  });

  // #28: 各トグルボタンは独立して動作する
  it('toggle buttons work independently', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const passwordInput = screen.getByLabelText('パスワード');
    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');
    const passwordToggle = screen.getByRole('button', { name: 'パスワードを表示' });
    const confirmPasswordToggle = screen.getByRole('button', { name: '確認パスワードを表示' });

    // パスワードのみ表示
    await userEvent.click(passwordToggle);

    expect(passwordInput).toHaveAttribute('type', 'text');
    expect(confirmPasswordInput).toHaveAttribute('type', 'password');

    // 確認パスワードも表示
    await userEvent.click(confirmPasswordToggle);

    expect(passwordInput).toHaveAttribute('type', 'text');
    expect(confirmPasswordInput).toHaveAttribute('type', 'text');
  });

  // #29: トグルボタンにaria-pressed属性が正しく設定される
  it('sets aria-pressed correctly on toggle buttons', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const toggleButton = screen.getByRole('button', { name: 'パスワードを表示' });

    // 初期状態: false
    expect(toggleButton).toHaveAttribute('aria-pressed', 'false');

    // クリック後: true
    await userEvent.click(toggleButton);
    expect(toggleButton).toHaveAttribute('aria-pressed', 'true');

    // 再クリック後: false
    await userEvent.click(toggleButton);
    expect(toggleButton).toHaveAttribute('aria-pressed', 'false');
  });
});

// ============================================================================
// Phase 9: アクセシビリティ（#30-34）
// ============================================================================

describe('SignupPage - Accessibility', () => {
  // #30: パスワード不一致時にaria-invalid="true"が設定される
  it('sets aria-invalid to true on password mismatch', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'different456');
    await userEvent.tab(); // フォーカスアウト

    expect(screen.getByLabelText('パスワード（確認）')).toHaveAttribute('aria-invalid', 'true');
  });

  // #31: パスワード不一致時にaria-describedbyがエラーメッセージIDを参照する
  it('sets aria-describedby to error message id on password mismatch', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'different456');
    await userEvent.tab();

    expect(screen.getByLabelText('パスワード（確認）')).toHaveAttribute('aria-describedby', 'confirmPassword-error');

    const errorMessage = screen.getByText('Passwords do not match');
    expect(errorMessage).toBeInTheDocument();
    expect(errorMessage).toHaveAttribute('aria-live', 'polite');
  });

  // #32: フィールド単位エラーにaria-live="polite"が設定されている
  it('sets aria-live to polite on field errors', async () => {
    server.use(
      http.post('/api/auth/register', () => {
        return errorResponse.validationError('Username must be at least 3 characters');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'ab');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      const errorMessage = screen.getByText('Username must be at least 3 characters');
      expect(errorMessage).toHaveAttribute('aria-live', 'polite');
    });
  });

  // #33: フォーム全体エラーにrole="alert"が設定されている
  it('sets role to alert on general errors', async () => {
    server.use(
      http.post('/api/auth/register', () => {
        // 複数フィールドに関連するエラーは general に分類される
        return errorResponse.validationError('Username and password are required');
      })
    );

    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('ユーザー名')).toBeInTheDocument();
    });

    await userEvent.type(screen.getByLabelText('ユーザー名'), 'testuser');
    await userEvent.type(screen.getByLabelText('メールアドレス'), 'test@example.com');
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(screen.getByLabelText('パスワード（確認）'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'サインアップ' }));

    await waitFor(() => {
      const errorMessage = screen.getByText('Username and password are required');
      expect(errorMessage.closest('[role="alert"]')).toBeInTheDocument();
    });
  });

  // #34: パスワード一致時にaria-invalid="false"に戻る
  it('sets aria-invalid to false when passwords match again', async () => {
    renderSignupPage();

    await waitFor(() => {
      expect(screen.getByLabelText('パスワード')).toBeInTheDocument();
    });

    const confirmPasswordInput = screen.getByLabelText('パスワード（確認）');

    // 不一致状態にする
    await userEvent.type(screen.getByLabelText('パスワード'), 'password123');
    await userEvent.type(confirmPasswordInput, 'different456');
    await userEvent.tab();
    expect(confirmPasswordInput).toHaveAttribute('aria-invalid', 'true');

    // 一致させる
    await userEvent.clear(confirmPasswordInput);
    await userEvent.type(confirmPasswordInput, 'password123');

    expect(confirmPasswordInput).toHaveAttribute('aria-invalid', 'false');
  });
});
