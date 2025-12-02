// pages/PostEditorPage/PostEditorPage.test.tsx
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
