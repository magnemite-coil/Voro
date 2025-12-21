// pages/PostEditorPage/PostEditorPage.test.tsx
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  afterEach,
  beforeEach,
} from 'vitest';
import { http, HttpResponse } from 'msw';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { PostEditorPage } from './PostEditorPage';
import { AuthProvider } from '../../contexts/AuthContext';
import { NotificationProvider } from '../../contexts/NotificationContext';
import { Toast } from '../../components/common/Toast/Toast';
import { server } from '../../test/mocks/server';

// 共通ハンドラーで初期化されたサーバーを使用
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// テスト前後のクリーンアップ
beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  localStorage.clear();
});

// 認証状態モック用のデフォルト値
const mockAuthState = {
  isAuthenticated: true,
  userId: 1,
  username: 'testuser',
  isLoading: false,
};

// テストヘルパー
interface RenderOptions {
  authState?: Partial<typeof mockAuthState>;
  route?: string;
}

function renderWithProviders(
  ui: React.ReactElement,
  options: RenderOptions = {}
) {
  const { authState = {}, route = '/' } = options;

  // 認証状態をマージ
  const finalAuthState = { ...mockAuthState, ...authState };

  // localStorageに認証情報をセット（AuthProviderの初期化用）
  if (finalAuthState.isAuthenticated) {
    localStorage.setItem(
      'voro_auth',
      JSON.stringify({
        userId: finalAuthState.userId,
        username: finalAuthState.username,
      })
    );
  }

  // 未認証状態をテストする場合は API を 401 に変更
  if (!finalAuthState.isAuthenticated) {
    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Unauthorized' },
          { status: 401 }
        );
      })
    );
  }

  // Data Router を使用（useBlocker をテストするために必須）
  const router = createMemoryRouter(
    [
      {
        path: '*',
        element: ui,
      },
    ],
    {
      initialEntries: [route],
    }
  );

  return render(
    <AuthProvider>
      <NotificationProvider>
        <RouterProvider router={router} />
        <Toast />
      </NotificationProvider>
    </AuthProvider>
  );
}

// ===================================================================
// 編集モード・新規作成モード用ヘルパー関数
// ===================================================================

// デフォルトの投稿データ（mockPost 未指定時に使用）
const DEFAULT_MOCK_POST = {
  title: 'Test Post Title',
  content: 'Test post content',
  published: false,
};

interface RenderEditModeOptions {
  postId: string;
  mockPost?: {
    title: string;
    content: string;
    published: boolean;
  };
  skipApiMock?: boolean;
}

function renderEditMode(options: RenderEditModeOptions) {
  const { postId, mockPost = DEFAULT_MOCK_POST, skipApiMock = false } = options;

  // 1. localStorageに認証情報セット
  localStorage.setItem(
    'voro_auth',
    JSON.stringify({ userId: 1, username: 'testuser' })
  );

  // 2. APIモックをセットアップ（skipApiMockがfalseの場合のみ）
  if (!skipApiMock) {
    server.use(
      http.get(`/api/posts/${postId}`, () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: Number(postId),
              user_id: 1,
              title: mockPost.title,
              content: mockPost.content,
              published: mockPost.published,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );
  }

  // 3. ルーター作成（新規作成ページへのリダイレクト先も含む）
  const router = createMemoryRouter(
    [
      {
        path: '/posts/:id/edit',
        element: <PostEditorPage mode="edit" />,
      },
      {
        path: '/posts/new',
        element: <div data-testid="new-post-page">New Post Page</div>,
      },
    ],
    { initialEntries: [`/posts/${postId}/edit`] }
  );

  // 4. レンダリング
  const result = render(
    <AuthProvider>
      <NotificationProvider>
        <RouterProvider router={router} />
        <Toast />
      </NotificationProvider>
    </AuthProvider>
  );

  return { router, ...result };
}

function renderCreateMode() {
  // 1. localStorageに認証情報セット
  localStorage.setItem(
    'voro_auth',
    JSON.stringify({ userId: 1, username: 'testuser' })
  );

  // 2. ルーター作成
  const router = createMemoryRouter(
    [
      {
        path: '/posts/new',
        element: <PostEditorPage mode="create" />,
      },
    ],
    { initialEntries: ['/posts/new'] }
  );

  // 3. レンダリング
  const result = render(
    <AuthProvider>
      <NotificationProvider>
        <RouterProvider router={router} />
        <Toast />
      </NotificationProvider>
    </AuthProvider>
  );

  return { router, ...result };
}

async function makeFormDirty(options?: { title?: string; content?: string }) {
  const { title = 'Modified Title', content } = options ?? {};

  // タイトルに入力（これだけで isDirty=true になる）
  const titleInput = screen.getByPlaceholderText('記事のタイトル');
  await userEvent.type(titleInput, title);

  // 必要に応じてコンテンツも入力
  if (content) {
    const contentInput = screen.getByPlaceholderText('Markdownで本文を書く...');
    await userEvent.type(contentInput, content);
  }
}

describe('PostEditorPage - Create Mode', () => {
  it('renders create mode UI', async () => {
    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });
    expect(
      screen.getByPlaceholderText('Markdownで本文を書く...')
    ).toBeInTheDocument();
    expect(screen.getByText('下書き保存')).toBeInTheDocument();
    expect(screen.getByText('公開する')).toBeInTheDocument();
  });

  it('disables buttons when form is empty', async () => {
    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByText('下書き保存')).toBeDisabled();
    });
    expect(screen.getByText('公開する')).toBeDisabled();
  });

  it('enables draft save button when form has content (publish stays disabled in create mode)', async () => {
    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    await userEvent.type(
      screen.getByPlaceholderText('記事のタイトル'),
      'Test Post'
    );
    await userEvent.type(
      screen.getByPlaceholderText('Markdownで本文を書く...'),
      'Test content'
    );

    expect(screen.getByText('下書き保存')).not.toBeDisabled();
    // 新規作成モードでは公開ボタンは常に非アクティブ（下書き保存後に有効になる）
    expect(screen.getByText('公開する')).toBeDisabled();
  });

  it('shows validation error when submitting empty title', async () => {
    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    // 本文のみ入力
    await userEvent.type(
      screen.getByPlaceholderText('Markdownで本文を書く...'),
      'Test content'
    );

    await userEvent.click(screen.getByText('下書き保存'));

    await waitFor(() => {
      expect(
        screen.getByText('Title cannot be empty or whitespace only')
      ).toBeInTheDocument();
    });
  });

  it('creates a new post when form is submitted', async () => {
    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    // フォーム入力
    await userEvent.type(
      screen.getByPlaceholderText('記事のタイトル'),
      'Test Post'
    );
    await userEvent.type(
      screen.getByPlaceholderText('Markdownで本文を書く...'),
      'Test content'
    );

    // 下書き保存ボタンをクリック
    await userEvent.click(screen.getByText('下書き保存'));

    // 成功通知を確認
    await waitFor(() => {
      expect(screen.getByText('下書きを保存しました')).toBeInTheDocument();
    });
  });

  it('publishes a draft post when publish button is clicked in edit mode', async () => {
    // 下書き状態の投稿データを返すようにモック
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Draft Post',
              content: 'Draft content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      }),
      http.put('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Draft Post',
              content: 'Draft content',
              published: true,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: <PostEditorPage mode="edit" />,
        },
      ],
      {
        initialEntries: ['/posts/1/edit'],
      }
    );

    localStorage.setItem(
      'voro_auth',
      JSON.stringify({
        userId: 1,
        username: 'testuser',
      })
    );

    render(
      <AuthProvider>
        <NotificationProvider>
          <RouterProvider router={router} />
          <Toast />
        </NotificationProvider>
      </AuthProvider>
    );

    // 投稿データが読み込まれるのを待つ
    await waitFor(() => {
      expect(screen.getByDisplayValue('Draft Post')).toBeInTheDocument();
    });

    // 下書き状態で変更なしなら公開ボタンがアクティブ
    await waitFor(() => {
      expect(screen.getByText('公開する')).not.toBeDisabled();
    });

    await userEvent.click(screen.getByText('公開する'));

    await waitFor(() => {
      expect(screen.getByText('記事を公開しました')).toBeInTheDocument();
    });
  });
});

describe('PostEditorPage - Edit Mode', () => {
  it('loads existing post data', async () => {
    // 特定の投稿データを返すようにモック
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Existing Post',
              content: 'Existing content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: (
            <AuthProvider>
              <NotificationProvider>
                <PostEditorPage mode="edit" />
              </NotificationProvider>
            </AuthProvider>
          ),
        },
      ],
      {
        initialEntries: ['/posts/1/edit'],
      }
    );

    // localStorageに認証情報をセット
    localStorage.setItem(
      'voro_auth',
      JSON.stringify({
        userId: 1,
        username: 'testuser',
      })
    );

    render(<RouterProvider router={router} />);

    // 投稿データが読み込まれるのを待つ
    await waitFor(() => {
      expect(screen.getByDisplayValue('Existing Post')).toBeInTheDocument();
    });
    expect(screen.getByDisplayValue('Existing content')).toBeInTheDocument();
  });

  it('shows error when post is not found', async () => {
    server.use(
      http.get('/api/posts/999', () => {
        return HttpResponse.json(
          { success: false, error: 'Post not found' },
          { status: 404 }
        );
      })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: (
            <AuthProvider>
              <NotificationProvider>
                <PostEditorPage mode="edit" />
              </NotificationProvider>
            </AuthProvider>
          ),
        },
      ],
      {
        initialEntries: ['/posts/999/edit'],
      }
    );

    localStorage.setItem(
      'voro_auth',
      JSON.stringify({
        userId: 1,
        username: 'testuser',
      })
    );

    render(<RouterProvider router={router} />);

    await waitFor(() => {
      expect(screen.getByText('Post not found')).toBeInTheDocument();
    });
  });

  it('updates post successfully', async () => {
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Original Title',
              content: 'Original content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: <PostEditorPage mode="edit" />,
        },
      ],
      {
        initialEntries: ['/posts/1/edit'],
      }
    );

    localStorage.setItem(
      'voro_auth',
      JSON.stringify({
        userId: 1,
        username: 'testuser',
      })
    );

    render(
      <AuthProvider>
        <NotificationProvider>
          <RouterProvider router={router} />
          <Toast />
        </NotificationProvider>
      </AuthProvider>
    );

    await waitFor(() => {
      expect(screen.getByDisplayValue('Original Title')).toBeInTheDocument();
    });

    // タイトルを変更（末尾に追加してisDirtyをtrueにする）
    const titleInput = screen.getByDisplayValue('Original Title');
    await userEvent.type(titleInput, ' Updated');

    // ボタンが有効になるのを待つ
    await waitFor(() => {
      expect(screen.getByText('下書き保存')).not.toBeDisabled();
    });

    // 下書き保存
    await userEvent.click(screen.getByText('下書き保存'));

    await waitFor(() => {
      expect(screen.getByText('下書きを保存しました')).toBeInTheDocument();
    });
  });
});

describe('PostEditorPage - API Error Handling', () => {
  it('shows error notification on server error', async () => {
    server.use(
      http.post('/api/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Internal server error', error_id: 'test-123' },
          { status: 500 }
        );
      })
    );

    renderWithProviders(<PostEditorPage mode="create" />);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    await userEvent.type(
      screen.getByPlaceholderText('記事のタイトル'),
      'Test Post'
    );
    await userEvent.type(
      screen.getByPlaceholderText('Markdownで本文を書く...'),
      'Test content'
    );

    await userEvent.click(screen.getByText('下書き保存'));

    await waitFor(() => {
      // formatErrorMessage が error_id を含むメッセージを返す（日本語表示）
      expect(
        screen.getByText(/サーバーエラーが発生しました/)
      ).toBeInTheDocument();
    });
  });
});

// ===================================================================
// Invalid ID Handling テスト（43行目カバー）
// ===================================================================
describe('PostEditorPage - Invalid ID Handling', () => {
  it('should redirect to new post page when ID is not a number (PE-INV-1)', async () => {
    // Arrange: 文字列IDで編集ページにアクセス（APIモック不要 - postIdがundefinedになるため）
    const { router } = renderEditMode({ postId: 'abc', skipApiMock: true });

    // Assert: エラー通知が表示される
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Invalid post ID');
    });

    // Assert: /posts/new へリダイレクト
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });
    expect(router.state.location.pathname).toBe('/posts/new');
  });

  it('should redirect to new post page when ID is zero (PE-INV-2)', async () => {
    // Arrange: ゼロIDで編集ページにアクセス（APIモック不要 - postIdがundefinedになるため）
    const { router } = renderEditMode({ postId: '0', skipApiMock: true });

    // Assert: エラー通知が表示される
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('Invalid post ID');
    });

    // Assert: /posts/new へリダイレクト
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });
    expect(router.state.location.pathname).toBe('/posts/new');
  });
});

// ===================================================================
// New Post Navigation テスト（182行目カバー）
// ===================================================================
describe('PostEditorPage - New Post Navigation', () => {
  it('should navigate to new post page when in edit mode with no changes (PE-NAV-1)', async () => {
    // Arrange: 編集モードでレンダリング
    const { router } = renderEditMode({ postId: '1' });

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByDisplayValue('Test Post Title')).toBeInTheDocument();
    });

    // Act: 新規作成タブをクリック（isDirty=false, mode='edit' → navigate('/posts/new')）
    await userEvent.click(screen.getByRole('link', { name: '新規作成' }));

    // Assert: /posts/new へ遷移（モーダルなし）
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });
    expect(router.state.location.pathname).toBe('/posts/new');

    // モーダルが表示されていないことを確認
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('should not navigate when in create mode with no changes (PE-NAV-2)', async () => {
    // Arrange: 新規作成モードでレンダリング
    const { router } = renderCreateMode();
    const initialPath = router.state.location.pathname;

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    // Act: 新規作成タブをクリック
    await userEvent.click(screen.getByRole('link', { name: '新規作成' }));

    // Assert: クリック直後に同一パスであることを即時検証
    expect(router.state.location.pathname).toBe(initialPath);

    // モーダルが表示されないことを確認
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();

    // フォームが空のまま維持されていることを確認
    expect(screen.getByPlaceholderText('記事のタイトル')).toHaveValue('');
  });
});

// ===================================================================
// New Post Confirmation Modal テスト（186-196, 198-200行目カバー）
// ===================================================================
describe('PostEditorPage - New Post Confirmation Modal', () => {
  it('should reset form when confirm is clicked in create mode (PE-CONF-1)', async () => {
    // Arrange: 新規作成モードでレンダリング
    renderCreateMode();

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    // フォームに入力して isDirty=true にする
    const testTitle = 'Test Title for Reset';
    const testContent = 'Test content for reset';
    await makeFormDirty({ title: testTitle, content: testContent });

    // 入力されていることを確認
    expect(screen.getByPlaceholderText('記事のタイトル')).toHaveValue(testTitle);

    // Act 1: 新規作成タブをクリック → モーダル表示
    await userEvent.click(screen.getByRole('link', { name: '新規作成' }));

    // Assert 1: モーダルが表示される
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByText('新規作成')).toBeInTheDocument();
    expect(within(dialog).getByText('保存されていない変更があります。新しい記事を作成しますか？')).toBeInTheDocument();

    // Act 2: 「離れる」をクリック
    await userEvent.click(within(dialog).getByRole('button', { name: '離れる' }));

    // Assert 2: モーダルが閉じる
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });

    // Assert 3: フォームがクリアされている
    expect(screen.getByPlaceholderText('記事のタイトル')).toHaveValue('');
    expect(screen.getByPlaceholderText('Markdownで本文を書く...')).toHaveValue('');
  });

  it('should navigate to new post after confirming both modals in edit mode (PE-CONF-2)', async () => {
    // Arrange: 編集モードでレンダリング
    const { router } = renderEditMode({ postId: '1' });

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByDisplayValue('Test Post Title')).toBeInTheDocument();
    });

    // フォームを変更して isDirty=true にする
    await makeFormDirty({ title: ' - Modified' });

    // Act 1: 新規作成タブをクリック → 「新規作成」確認モーダル表示
    await userEvent.click(screen.getByRole('link', { name: '新規作成' }));

    // Assert 1: 「新規作成」モーダルが表示される
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });
    const firstDialog = screen.getByRole('dialog');
    expect(within(firstDialog).getByText('新規作成')).toBeInTheDocument();

    // Act 2: 「離れる」をクリック → 「未保存の変更」モーダル表示
    await userEvent.click(within(firstDialog).getByRole('button', { name: '離れる' }));

    // Assert 2: 「未保存の変更」モーダルが表示される
    await waitFor(() => {
      const dialog = screen.getByRole('dialog');
      expect(within(dialog).getByText('未保存の変更')).toBeInTheDocument();
    });
    const secondDialog = screen.getByRole('dialog');

    // Act 3: 2つ目のモーダルで「離れる」をクリック → 遷移
    await userEvent.click(within(secondDialog).getByRole('button', { name: '離れる' }));

    // Assert 3: /posts/new へ遷移
    await waitFor(() => {
      expect(screen.getByTestId('new-post-page')).toBeInTheDocument();
    });
    expect(router.state.location.pathname).toBe('/posts/new');
  });

  it('should close modal and keep form when cancel is clicked (PE-CONF-3)', async () => {
    // Arrange: 新規作成モードでレンダリング
    renderCreateMode();

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
    });

    // フォームに入力して isDirty=true にする
    const testTitle = 'Test Title for Cancel';
    await makeFormDirty({ title: testTitle });

    // Act 1: 新規作成タブをクリック → モーダル表示
    await userEvent.click(screen.getByRole('link', { name: '新規作成' }));

    // Assert 1: モーダルが表示される
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByText('新規作成')).toBeInTheDocument();

    // Act 2: 「キャンセル」をクリック
    await userEvent.click(within(dialog).getByRole('button', { name: 'キャンセル' }));

    // Assert 2: モーダルが閉じる
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });

    // Assert 3: フォームの値が維持されている
    expect(screen.getByPlaceholderText('記事のタイトル')).toHaveValue(testTitle);
  });
});

// ===================================================================
// Publish Error Handling テスト（167-171行目カバー）
// ===================================================================
describe('PostEditorPage - Publish Error Handling', () => {
  it('should show error notification when publish API fails (PE-PUB-1)', async () => {
    // Arrange: 編集モードで下書き状態の投稿をセットアップ
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Draft Post',
              content: 'Draft content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      }),
      http.put('/api/posts/1', () => {
        return HttpResponse.json(
          { success: false, error: 'Internal server error', error_id: 'test-456' },
          { status: 500 }
        );
      })
    );

    // renderEditMode は skipApiMock=true で使用し、上記のモックを優先
    localStorage.setItem(
      'voro_auth',
      JSON.stringify({ userId: 1, username: 'testuser' })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: <PostEditorPage mode="edit" />,
        },
      ],
      { initialEntries: ['/posts/1/edit'] }
    );

    render(
      <AuthProvider>
        <NotificationProvider>
          <RouterProvider router={router} />
          <Toast />
        </NotificationProvider>
      </AuthProvider>
    );

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByDisplayValue('Draft Post')).toBeInTheDocument();
    });

    // 下書き状態で変更なしなら公開ボタンがアクティブ
    await waitFor(() => {
      expect(screen.getByText('公開する')).not.toBeDisabled();
    });

    // Act: 公開ボタンをクリック
    await userEvent.click(screen.getByText('公開する'));

    // Assert: エラー通知が表示される
    await waitFor(() => {
      expect(screen.getByText(/サーバーエラーが発生しました/)).toBeInTheDocument();
    });
  });

  it('should show validation error when publishing with invalid server data (PE-PUB-2)', async () => {
    // Arrange: サーバーから不正なデータ（空白タイトル）が返される特殊ケース
    // この場合、isDirty=false でも公開ボタンはクリック可能だが、バリデーションエラーになる
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: '   ',  // 空白のみ（不正なデータ）
              content: 'Valid content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );

    localStorage.setItem(
      'voro_auth',
      JSON.stringify({ userId: 1, username: 'testuser' })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: <PostEditorPage mode="edit" />,
        },
      ],
      { initialEntries: ['/posts/1/edit'] }
    );

    render(
      <AuthProvider>
        <NotificationProvider>
          <RouterProvider router={router} />
          <Toast />
        </NotificationProvider>
      </AuthProvider>
    );

    // フォームの読み込みを待機（空白タイトルがセットされる）
    await waitFor(() => {
      expect(screen.getByPlaceholderText('記事のタイトル')).toHaveValue('   ');
    });

    // isDirty=false なので公開ボタンはアクティブ
    await waitFor(() => {
      expect(screen.getByText('公開する')).not.toBeDisabled();
    });

    // Act: 公開ボタンをクリック
    await userEvent.click(screen.getByText('公開する'));

    // Assert: バリデーションエラーが表示される
    await waitFor(() => {
      expect(screen.getByText('Title cannot be empty or whitespace only')).toBeInTheDocument();
    });
  });

  it('should show generic error when publish throws non-ApiError (PE-PUB-3)', async () => {
    // Arrange: 編集モードで下書き状態の投稿をセットアップ
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Draft Post',
              content: 'Draft content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      }),
      http.put('/api/posts/1', () => {
        // ネットワークエラーをシミュレート（ApiError以外のエラー）
        return HttpResponse.error();
      })
    );

    localStorage.setItem(
      'voro_auth',
      JSON.stringify({ userId: 1, username: 'testuser' })
    );

    const router = createMemoryRouter(
      [
        {
          path: '/posts/:id/edit',
          element: <PostEditorPage mode="edit" />,
        },
      ],
      { initialEntries: ['/posts/1/edit'] }
    );

    render(
      <AuthProvider>
        <NotificationProvider>
          <RouterProvider router={router} />
          <Toast />
        </NotificationProvider>
      </AuthProvider>
    );

    // フォームの読み込みを待機
    await waitFor(() => {
      expect(screen.getByDisplayValue('Draft Post')).toBeInTheDocument();
    });

    // 下書き状態で変更なしなら公開ボタンがアクティブ
    await waitFor(() => {
      expect(screen.getByText('公開する')).not.toBeDisabled();
    });

    // Act: 公開ボタンをクリック
    await userEvent.click(screen.getByText('公開する'));

    // Assert: 汎用エラー通知が表示される
    await waitFor(() => {
      expect(screen.getByText('公開に失敗しました')).toBeInTheDocument();
    });
  });
});
