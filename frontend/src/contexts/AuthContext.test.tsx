// contexts/AuthContext.test.tsx
import { render, screen, waitFor, renderHook, act } from '@testing-library/react';
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
import { AuthProvider, useAuth } from './AuthContext';
import { server } from '../test/mocks/server';
import { errorResponse } from '../test/mocks/handlers';
import { setupAuthenticatedUser } from '../test/utils';
import { api, ApiError } from '../services/api';

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

/**
 * AuthProviderでラップしてレンダリング
 * 返り値の login/logout/checkAuth 関数を使って、任意の引数でテスト可能
 */
function renderWithAuth() {
  let loginFn!: (username: string, password: string) => Promise<void>;
  let logoutFn!: () => Promise<void>;
  let checkAuthFn!: () => Promise<void>;

  const TestConsumer = () => {
    const auth = useAuth();

    // 関数参照を外部に公開（テスト用パターン）
    /* eslint-disable react-hooks/globals -- テストヘルパー内での意図的な参照公開 */
    loginFn = auth.login;
    logoutFn = auth.logout;
    checkAuthFn = auth.checkAuth;
    /* eslint-enable react-hooks/globals */

    return (
      <div>
        <span data-testid="isLoading">{String(auth.isLoading)}</span>
        <span data-testid="isAuthenticated">{String(auth.isAuthenticated)}</span>
        <span data-testid="userId">{auth.userId ?? 'null'}</span>
        <span data-testid="username">{auth.username ?? 'null'}</span>
      </div>
    );
  };

  const result = render(
    <AuthProvider>
      <TestConsumer />
    </AuthProvider>
  );

  return {
    ...result,
    login: (username: string, password: string) => loginFn(username, password),
    logout: () => logoutFn(),
    checkAuth: () => checkAuthFn(),
  };
}

// =============================================================================
// Phase 1: 初期状態と useAuth フック（AC-1〜AC-3a）
// =============================================================================
describe('AuthContext - Initial State and useAuth Hook', () => {
  // AC-1: useAuth を AuthProvider 外で使用するとエラー
  it('throws error when useAuth is used outside AuthProvider (AC-1)', () => {
    // React の console.error を抑制
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    expect(() => {
      renderHook(() => useAuth());
    }).toThrow('useAuth must be used within AuthProvider');

    consoleSpy.mockRestore();
  });

  // AC-2: 初期状態は isLoading: true（API遅延時）
  // Note: フェイクタイマーとMSWの相性問題があるため、実時間待ちを使用
  it('has isLoading: true initially when localStorage exists and API is pending (AC-2)', async () => {
    // Arrange: localStorage を設定（checkAuth が API を呼ぶ条件）
    setupAuthenticatedUser();

    // API を遅延させる（delayオプション使用）
    server.use(
      http.get('/api/me/posts', async () => {
        // 短い遅延でAPIペンディング状態を作成
        await new Promise((r) => setTimeout(r, 50));
        return HttpResponse.json({ success: true, data: { posts: [] } });
      })
    );

    // Act
    renderWithAuth();

    // Assert: マウント直後は isLoading: true（同期的に検証）
    expect(screen.getByTestId('isLoading')).toHaveTextContent('true');

    // 完了後は false
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });
  });

  // AC-3: localStorage なしで isLoading: false, isAuthenticated: false
  it('sets isLoading: false and isAuthenticated: false when no localStorage (AC-3)', async () => {
    // Arrange: localStorage は空（beforeEach でクリア済み）

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');
  });

  // AC-3a: checkAuth再実行時にlocalStorageが削除されていた場合 → 未認証にリセット
  it('resets to unauthenticated when localStorage is cleared during session (AC-3a)', async () => {
    // Arrange: 認証済み状態をシミュレート
    setupAuthenticatedUser(1, 'testuser');

    const { checkAuth } = renderWithAuth();

    // 初期化完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 認証済み状態を確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('1');

    // Act: localStorage を削除（コンポーネントはアンマウントしない）
    localStorage.removeItem('voro_auth');

    // Act: 同一インスタンスで checkAuth() を再呼び出し
    await act(async () => {
      await checkAuth();
    });

    // Assert: isLoading が false になるまで待機
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // Assert: 未認証にリセットされること
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');
  });
});

// =============================================================================
// Phase 2: checkAuth - localStorage からの復元（AC-4〜AC-10）
// =============================================================================
describe('AuthContext - checkAuth and localStorage Restoration', () => {
  // AC-4: localStorage あり + API成功(200) → 認証状態復元
  it('restores auth state when localStorage exists and API succeeds (AC-4)', async () => {
    // Arrange
    setupAuthenticatedUser(42, 'myuser');

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('42');
    expect(screen.getByTestId('username')).toHaveTextContent('myuser');
  });

  // AC-5: localStorage あり + API失敗(401) → 未認証 + localStorage削除
  it('clears auth when API returns 401 (AC-5)', async () => {
    // Arrange
    setupAuthenticatedUser(1, 'testuser');

    server.use(
      http.get('/api/me/posts', () => {
        return errorResponse.unauthorized();
      })
    );

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');

    // localStorage が削除されている
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });

  // AC-6: localStorage あり + API失敗(500) → 楽観的に認証維持
  it('maintains auth state optimistically when API returns 500 (AC-6)', async () => {
    // Arrange
    setupAuthenticatedUser(1, 'testuser');

    // console.error を抑制（楽観的復元時のログ出力）
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    server.use(
      http.get('/api/me/posts', () => {
        return errorResponse.serverError();
      })
    );

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('1');
    expect(screen.getByTestId('username')).toHaveTextContent('testuser');

    // localStorage は維持されている
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    consoleSpy.mockRestore();
  });

  // AC-7: localStorage あり + API失敗(403) → 楽観的に認証維持
  it('maintains auth state optimistically when API returns 403 (AC-7)', async () => {
    // Arrange
    setupAuthenticatedUser(1, 'testuser');

    // console.error を抑制
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    server.use(
      http.get('/api/me/posts', () => {
        return errorResponse.forbidden();
      })
    );

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');

    consoleSpy.mockRestore();
  });

  // AC-8: localStorage が不正なJSON → localStorage削除 + 未認証
  it('clears auth when localStorage contains invalid JSON (AC-8)', async () => {
    // Arrange: 不正なJSONをセット
    localStorage.setItem('voro_auth', 'not-valid-json{');

    // Act
    renderWithAuth();

    // Assert
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');

    // localStorage が削除されている
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });

  // AC-9: API検証中にlocalStorageが削除された場合 → 未認証
  it('clears auth state when localStorage is removed during API call (AC-9)', async () => {
    // Arrange: localStorage に有効なJSONをセット
    setupAuthenticatedUser();

    // MSWハンドラー内でlocalStorageを削除してからエラーを返す
    server.use(
      http.get('/api/me/posts', async () => {
        // APIレスポンスを返す前にlocalStorageを削除
        // （別タブでのログアウトをシミュレート）
        localStorage.removeItem('voro_auth');
        return errorResponse.serverError();
      })
    );

    // Act
    renderWithAuth();

    // Assert: isLoading が false になるまで待機
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 未認証状態になることを確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
  });

  // AC-10a: localStorage の構造が不完全（userIdのみ）→ 未認証
  it('clears auth when localStorage structure is incomplete (userId only) (AC-10)', async () => {
    // Arrange: userIdのみ（usernameなし）
    localStorage.setItem('voro_auth', JSON.stringify({ userId: 1 }));

    // Act
    renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // Assert: 未認証状態になること
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');

    // localStorage は削除されている
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });

  // AC-10b: localStorage の構造が不完全（usernameのみ）→ 未認証
  it('clears auth when userId is missing (AC-10)', async () => {
    localStorage.setItem('voro_auth', JSON.stringify({ username: 'test' }));
    renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
  });

  // AC-10c: userId の型が不正（文字列）→ 未認証
  it('clears auth when userId is not a number (AC-10)', async () => {
    localStorage.setItem('voro_auth', JSON.stringify({ userId: 'not-a-number', username: 'test' }));
    renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
  });
});

// =============================================================================
// Phase 3: login 関数（AC-11〜AC-14）
// =============================================================================
describe('AuthContext - login Function', () => {
  // AC-11, AC-12: ログイン成功 → 状態更新 + localStorage保存 + 引数がAPIに正しく渡される
  it('updates state, saves to localStorage, and passes correct arguments on successful login (AC-11, AC-12)', async () => {
    // Arrange: リクエストボディをキャプチャするハンドラー
    let capturedRequest: { username: string; password: string } | null = null;

    server.use(
      http.post('/api/auth/login', async ({ request }) => {
        capturedRequest = (await request.json()) as { username: string; password: string };
        return HttpResponse.json({
          success: true,
          data: {
            user: { id: 42, username: capturedRequest.username },
          },
        });
      })
    );

    const { login } = renderWithAuth();

    // 初期化完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // Act: ログイン実行
    await act(async () => {
      await login('myuser', 'mypassword');
    });

    // Assert AC-12: リクエストボディが入力値と一致
    expect(capturedRequest).toEqual({
      username: 'myuser',
      password: 'mypassword',
    });

    // Assert AC-11: 状態が更新される
    await waitFor(() => {
      expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    });
    expect(screen.getByTestId('userId')).toHaveTextContent('42');
    expect(screen.getByTestId('username')).toHaveTextContent('myuser');

    // Assert AC-11: localStorage が保存される
    const storedAuth = localStorage.getItem('voro_auth');
    expect(storedAuth).not.toBeNull();
    const parsedAuth = JSON.parse(storedAuth!);
    expect(parsedAuth).toEqual({
      userId: 42,
      username: 'myuser',
    });
  });

  // AC-13: ログイン失敗(401) → エラーがスロー、状態変化なし
  it('throws error and does not change state on 401 (AC-13)', async () => {
    server.use(
      http.post('/api/auth/login', () => {
        return errorResponse.unauthorized();
      })
    );

    const { login } = renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // Assert: エラーがスローされる
    await expect(login('user', 'wrongpass')).rejects.toThrow();

    // Assert: 状態は変化しない
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });

  // AC-14: ログイン失敗(500) → エラーがスロー、状態変化なし
  it('throws error and does not change state on 500 (AC-14)', async () => {
    server.use(
      http.post('/api/auth/login', () => {
        return errorResponse.serverError();
      })
    );

    const { login } = renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    await expect(login('user', 'pass')).rejects.toThrow();

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });
});

// =============================================================================
// Phase 4: logout 関数（AC-15〜AC-17）
// =============================================================================
describe('AuthContext - logout Function', () => {
  // AC-15: ログアウト成功 → 状態クリア + localStorage削除 + API呼び出し確認
  it('clears state, removes localStorage, and calls API on successful logout (AC-15)', async () => {
    // Arrange: API呼び出しを確認するためのフラグ
    let logoutApiCalled = false;

    server.use(
      http.post('/api/auth/logout', () => {
        logoutApiCalled = true;
        return HttpResponse.json({ success: true });
      })
    );

    // 認証済み状態でレンダリング
    setupAuthenticatedUser(1, 'testuser');
    const { logout } = renderWithAuth();

    // 初期化完了を待つ
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 認証済み状態を確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('1');
    expect(screen.getByTestId('username')).toHaveTextContent('testuser');

    // Act: ログアウト実行
    await act(async () => {
      await logout();
    });

    // Assert: API呼び出し確認
    expect(logoutApiCalled).toBe(true);

    // Assert: 状態がクリアされる
    await waitFor(() => {
      expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    });
    expect(screen.getByTestId('userId')).toHaveTextContent('null');
    expect(screen.getByTestId('username')).toHaveTextContent('null');

    // Assert: localStorage が削除される
    expect(localStorage.getItem('voro_auth')).toBeNull();
  });

  // AC-16: ログアウトAPI失敗 → エラーがスロー + localStorage維持
  it('throws error and maintains localStorage on logout failure (AC-16)', async () => {
    server.use(
      http.post('/api/auth/logout', () => errorResponse.serverError())
    );

    // Arrange: 認証済み状態でレンダリング
    setupAuthenticatedUser(1, 'testuser');
    const { logout } = renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 認証済み状態を確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');

    // Act & Assert: エラーがスローされる
    await expect(logout()).rejects.toThrow();

    // Assert: 認証状態は維持される（変化しない）
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('1');
    expect(screen.getByTestId('username')).toHaveTextContent('testuser');

    // Assert: localStorage は維持される（削除されない）
    expect(localStorage.getItem('voro_auth')).not.toBeNull();
  });

  // AC-17: 未認証状態でlogout呼び出し → APIは呼ばれる
  it('calls logout API even when not authenticated (AC-17)', async () => {
    // Arrange: API呼び出しを確認するためのフラグ
    let logoutApiCalled = false;

    server.use(
      http.post('/api/auth/logout', () => {
        logoutApiCalled = true;
        return HttpResponse.json({ success: true });
      })
    );

    // localStorage なし（未認証状態）でレンダリング
    const { logout } = renderWithAuth();

    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 未認証状態を確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');

    // Act: ログアウト実行
    await act(async () => {
      await logout();
    });

    // Assert: API は呼ばれる
    expect(logoutApiCalled).toBe(true);

    // Assert: 状態は未認証のまま
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
  });
});

// =============================================================================
// Phase 5: エッジケース（AC-18〜AC-20）
// =============================================================================
describe('AuthContext - Edge Cases', () => {
  // AC-18: checkAuth中にAbortされた場合 → 状態・localStorage不変
  it('does not update state when unmounted during checkAuth (AC-18)', async () => {
    // Arrange: API呼び出しをスパイ
    const getSpyPromise = new Promise<AbortSignal | undefined>((resolve) => {
      vi.spyOn(api, 'get').mockImplementation(async (_url, options) => {
        resolve(options?.signal);
        await new Promise((r) => setTimeout(r, 100));
        return { success: true, data: { posts: [] } };
      });
    });

    // Arrange: localStorage に認証データを設定
    setupAuthenticatedUser(1, 'testuser');
    const originalLocalStorage = localStorage.getItem('voro_auth');

    const { unmount } = renderWithAuth();

    // 即座にアンマウント（checkAuth完了前）
    unmount();

    // Assert: signal.aborted が true になっていることを検証
    const signal = await getSpyPromise;
    expect(signal?.aborted).toBe(true);

    // Assert: localStorage が変化していないことを検証
    expect(localStorage.getItem('voro_auth')).toBe(originalLocalStorage);

    // クリーンアップ
    vi.restoreAllMocks();
  });

  // AC-18b: エラー応答＋unmountで状態が更新されない
  it('does not update state when unmounted during error response (AC-18b)', async () => {
    // Arrange: API呼び出しをスパイし、エラーを返す
    let signalRef: AbortSignal | undefined;
    vi.spyOn(api, 'get').mockImplementation(async (_url, options) => {
      signalRef = options?.signal;
      await new Promise((r) => setTimeout(r, 50));
      throw new ApiError('Unauthorized', undefined, 401);
    });

    // Arrange: localStorage に認証データを設定
    setupAuthenticatedUser(1, 'testuser');
    const originalLocalStorage = localStorage.getItem('voro_auth');

    // React の console.error を抑制
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    const { unmount } = renderWithAuth();

    // 即座にアンマウント（API応答前）
    unmount();

    // API呼び出しが完了するまで待機
    await new Promise((r) => setTimeout(r, 100));

    // Assert: signal.aborted が true
    expect(signalRef?.aborted).toBe(true);

    // Assert: localStorage が変化していない（401でも削除されない）
    expect(localStorage.getItem('voro_auth')).toBe(originalLocalStorage);

    // クリーンアップ
    consoleSpy.mockRestore();
    vi.restoreAllMocks();
  });

  // AC-19: ネットワークエラー時 → 楽観的に認証維持
  it('maintains auth state when non-ApiError occurs (network error simulation) (AC-19)', async () => {
    // Arrange: localStorage に有効なJSONをセット
    setupAuthenticatedUser(1, 'testuser');

    // console.error を抑制（楽観的復元時のログ出力）
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    // api.get をモックして通常の Error をスロー（非ApiError）
    vi.spyOn(api, 'get').mockRejectedValueOnce(new Error('Network request failed'));

    // Act: AuthProvider をマウント
    renderWithAuth();

    // Assert: isLoading が false になるまで待機
    await waitFor(() => {
      expect(screen.getByTestId('isLoading')).toHaveTextContent('false');
    });

    // 楽観的に認証維持されていることを確認
    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('true');
    expect(screen.getByTestId('userId')).toHaveTextContent('1');
    expect(screen.getByTestId('username')).toHaveTextContent('testuser');

    // localStorage は維持されている
    expect(localStorage.getItem('voro_auth')).not.toBeNull();

    consoleSpy.mockRestore();
    vi.restoreAllMocks();
  });

  // AC-20: 真のネットワークエラー（E2E推奨）
  it.todo('maintains auth state on true network error (E2E) (AC-20)');
});
