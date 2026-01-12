// pages/PostListPage/PostListPage.test.tsx
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
import { PostListPage } from './PostListPage';
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

// テストヘルパー
interface RenderOptions {
  route?: string;
  isAuthenticated?: boolean;
}

function renderPostListPage(options: RenderOptions = {}) {
  const { route = '/posts', isAuthenticated = true } = options;

  // localStorageに認証情報をセット
  if (isAuthenticated) {
    localStorage.setItem(
      'voro_auth',
      JSON.stringify({ userId: 1, username: 'testuser' })
    );
  }

  // 未認証状態をテストする場合はAPIを401に変更
  if (!isAuthenticated) {
    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Unauthorized' },
          { status: 401 }
        );
      }),
      http.get('/api/me/posts/stats', () => {
        return HttpResponse.json(
          { success: false, error: 'Unauthorized' },
          { status: 401 }
        );
      })
    );
  }

  // Data Router を使用
  const router = createMemoryRouter(
    [
      {
        path: '/posts',
        element: <PostListPage />,
      },
      {
        path: '/posts/:id/edit',
        element: <div data-testid="edit-page">Edit Page</div>,
      },
      {
        path: '/posts/new',
        element: <div data-testid="new-page">New Page</div>,
      },
      {
        path: '/login',
        element: <div data-testid="login-page">Login Page</div>,
      },
    ],
    {
      initialEntries: [route],
    }
  );

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

// ===================================================================
// 初回表示テスト
// ===================================================================
describe('PostListPage - Initial Display', () => {
  it('displays loading state initially', () => {
    renderPostListPage();

    expect(screen.getByText('読み込み中...')).toBeInTheDocument();
  });

  it('displays posts and stats after loading', async () => {
    renderPostListPage();

    // 統計データが表示されるのを待つ
    await waitFor(() => {
      expect(screen.getByText('42')).toBeInTheDocument(); // total
    });

    // 統計カードの値を確認
    expect(screen.getByText('38')).toBeInTheDocument(); // published
    expect(screen.getByText('4')).toBeInTheDocument(); // draft
    expect(screen.getByText('7')).toBeInTheDocument(); // this_month

    // 記事一覧が表示されることを確認
    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // ページネーションが表示されることを確認（42件 / 20件 = 3ページ）
    expect(screen.getByLabelText('ページナビゲーション')).toBeInTheDocument();
  });

  it('displays section headings for accessibility', async () => {
    renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // セクションタイトル（h2要素）
    expect(screen.getByRole('heading', { name: '記事一覧', level: 2 })).toBeInTheDocument();
  });
});

// ===================================================================
// ページネーションテスト
// ===================================================================
describe('PostListPage - Pagination', () => {
  it('changes page when pagination button is clicked', async () => {
    const { router } = renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 2ページ目のボタンをクリック
    await userEvent.click(screen.getByRole('button', { name: '2' }));

    // URLが更新されることを確認
    await waitFor(() => {
      expect(router.state.location.search).toBe('?page=2');
    });
  });

  it('navigates to next page', async () => {
    const { router } = renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 「次へ」ボタンをクリック
    await userEvent.click(screen.getByLabelText('次のページへ'));

    // URLが更新されることを確認
    await waitFor(() => {
      expect(router.state.location.search).toBe('?page=2');
    });
  });

  it('disables previous button on first page', async () => {
    renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 「前へ」ボタンがdisabledであることを確認
    expect(screen.getByLabelText('前のページへ')).toBeDisabled();
  });
});

// ===================================================================
// 記事削除テスト
// ===================================================================
describe('PostListPage - Delete Post', () => {
  it('opens delete confirmation modal', async () => {
    renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 削除ボタンをクリック（aria-labelで特定）
    await userEvent.click(screen.getByLabelText('「テスト投稿 1」を削除'));

    // モーダルが表示されることを確認
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });

    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByText('記事の削除')).toBeInTheDocument();
    expect(
      within(dialog).getByText(/「テスト投稿 1」を削除しますか？/)
    ).toBeInTheDocument();
  });

  it('closes modal when cancel is clicked', async () => {
    renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 削除ボタンをクリック
    await userEvent.click(screen.getByLabelText('「テスト投稿 1」を削除'));

    // モーダルが表示されるのを待つ
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });

    // キャンセルボタンをクリック
    const dialog = screen.getByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'キャンセル' }));

    // モーダルが閉じることを確認
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });

    // 記事がまだ存在することを確認
    expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
  });

  it('deletes post when confirm is clicked', async () => {
    renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 削除ボタンをクリック
    await userEvent.click(screen.getByLabelText('「テスト投稿 1」を削除'));

    // モーダルが表示されるのを待つ
    await waitFor(() => {
      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });

    // 削除ボタンをクリック
    const dialog = screen.getByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: '削除' }));

    // モーダルが閉じることを確認
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });

    // 成功通知が表示されることを確認
    await waitFor(() => {
      expect(screen.getByText('記事を削除しました')).toBeInTheDocument();
    });
  });
});

// ===================================================================
// エラー表示テスト
// ===================================================================
describe('PostListPage - Error Handling', () => {
  it('displays error message when API fails', async () => {
    // APIエラーをモック
    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Server error', error_id: 'test-123' },
          { status: 500 }
        );
      })
    );

    renderPostListPage();

    // エラーメッセージが表示されることを確認
    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });

    // 再試行ボタンが表示されることを確認
    expect(screen.getByRole('button', { name: '再試行' })).toBeInTheDocument();
  });

  it('retries fetching when retry button is clicked', async () => {
    let callCount = 0;

    // 最初はエラー、2回目は成功
    server.use(
      http.get('/api/me/posts', () => {
        callCount++;
        if (callCount === 1) {
          return HttpResponse.json(
            { success: false, error: 'Server error' },
            { status: 500 }
          );
        }
        return HttpResponse.json({
          success: true,
          data: {
            posts: [
              {
                id: 1,
                user_id: 1,
                title: 'Recovered Post',
                content: 'Content',
                published: true,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              },
            ],
            pagination: {
              page: 1,
              per_page: 20,
              total_count: 1,
              total_pages: 1,
            },
          },
        });
      })
    );

    renderPostListPage();

    // エラーが表示されるのを待つ
    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });

    // 再試行ボタンをクリック
    await userEvent.click(screen.getByRole('button', { name: '再試行' }));

    // データが表示されることを確認
    await waitFor(() => {
      expect(screen.getByText('Recovered Post')).toBeInTheDocument();
    });
  });
});

// ===================================================================
// 空状態テスト
// ===================================================================
describe('PostListPage - Empty State', () => {
  it('displays empty state when no posts exist', async () => {
    // 空のレスポンスを返すようにモック
    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.json({
          success: true,
          data: {
            posts: [],
            pagination: {
              page: 1,
              per_page: 20,
              total_count: 0,
              total_pages: 0,
            },
          },
        });
      }),
      http.get('/api/me/posts/stats', () => {
        return HttpResponse.json({
          success: true,
          data: {
            stats: {
              total: 0,
              published: 0,
              draft: 0,
              this_month: 0,
            },
          },
        });
      })
    );

    renderPostListPage();

    // 空状態メッセージが表示されることを確認
    await waitFor(() => {
      expect(screen.getByText('まだ記事がありません')).toBeInTheDocument();
    });

    // 新規作成リンクが表示されることを確認
    expect(screen.getByText('最初の記事を作成する')).toBeInTheDocument();
  });

  it('navigates to new post page from empty state', async () => {
    server.use(
      http.get('/api/me/posts', () => {
        return HttpResponse.json({
          success: true,
          data: {
            posts: [],
            pagination: {
              page: 1,
              per_page: 20,
              total_count: 0,
              total_pages: 0,
            },
          },
        });
      }),
      http.get('/api/me/posts/stats', () => {
        return HttpResponse.json({
          success: true,
          data: {
            stats: { total: 0, published: 0, draft: 0, this_month: 0 },
          },
        });
      })
    );

    const { router } = renderPostListPage();

    // 空状態が表示されるのを待つ
    await waitFor(() => {
      expect(screen.getByText('まだ記事がありません')).toBeInTheDocument();
    });

    // 新規作成リンクをクリック
    await userEvent.click(screen.getByText('最初の記事を作成する'));

    // /posts/new へ遷移することを確認
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/posts/new');
    });
  });
});

// ===================================================================
// 編集画面遷移テスト
// ===================================================================
describe('PostListPage - Navigation', () => {
  it('navigates to edit page when edit button is clicked', async () => {
    const { router } = renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 編集ボタンをクリック
    const editButtons = screen.getAllByRole('button', { name: '編集' });
    await userEvent.click(editButtons[0]);

    // /posts/1/edit へ遷移することを確認
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/posts/1/edit');
    });
  });

  it('navigates to edit page when row is clicked', async () => {
    const { router } = renderPostListPage();

    await waitFor(() => {
      expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    });

    // 行をクリック（タイトルをクリック）
    await userEvent.click(screen.getByText('テスト投稿 1'));

    // /posts/1/edit へ遷移することを確認
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/posts/1/edit');
    });
  });
});
