// hooks/usePosts.test.ts
import { renderHook, waitFor, act } from '@testing-library/react';
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { createElement } from 'react';
import { usePosts } from './usePosts';
import { NotificationProvider } from '../contexts/NotificationContext';
import { server } from '../test/mocks/server';

// MSWセットアップ
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// テストヘルパー: RouterProviderでラップ
function createWrapper(route: string = '/posts') {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    const router = createMemoryRouter(
      [
        {
          path: '/posts',
          element: children,
        },
        {
          path: '/login',
          element: createElement('div', null, 'Login Page'),
        },
      ],
      {
        initialEntries: [route],
      }
    );

    return createElement(
      NotificationProvider,
      null,
      createElement(RouterProvider, { router })
    );
  };
}

describe('usePosts', () => {
  describe('Initial Fetch', () => {
    it('fetches posts and stats on mount', async () => {
      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      // 初期状態はローディング中
      expect(result.current.isLoading).toBe(true);
      expect(result.current.isStatsLoading).toBe(true);

      // データ取得完了を待つ
      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // 投稿データが取得されていること
      expect(result.current.posts.length).toBeGreaterThan(0);
      expect(result.current.posts[0].title).toBe('テスト投稿 1');

      // ページネーション情報が取得されていること
      expect(result.current.pagination).not.toBeNull();
      expect(result.current.pagination?.total_count).toBe(42);

      // 統計情報が取得されていること
      await waitFor(() => {
        expect(result.current.isStatsLoading).toBe(false);
      });
      expect(result.current.stats).not.toBeNull();
      expect(result.current.stats?.total).toBe(42);
    });

    it('handles API error', async () => {
      server.use(
        http.get('/api/me/posts', () => {
          return HttpResponse.json(
            { success: false, error: 'Server error', error_id: 'test-123' },
            { status: 500 }
          );
        })
      );

      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // エラーが設定されていること
      expect(result.current.error).not.toBeNull();
      expect(result.current.posts).toEqual([]);
    });
  });

  describe('Pagination', () => {
    it('fetches correct page from URL params', async () => {
      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper('/posts?page=2'),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // 2ページ目のデータが取得されていること
      expect(result.current.pagination?.page).toBe(2);
    });
  });

  describe('Delete Post', () => {
    it('deletes post successfully', async () => {
      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // 削除を実行
      let deleteResult: boolean;
      await act(async () => {
        deleteResult = await result.current.deletePost(1);
      });

      expect(deleteResult!).toBe(true);
      expect(result.current.isDeleting).toBe(false);
    });

    it('handles delete error', async () => {
      server.use(
        http.delete('/api/posts/:id', () => {
          return HttpResponse.json(
            { success: false, error: 'Not found' },
            { status: 404 }
          );
        })
      );

      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // 削除を実行
      let deleteResult: boolean;
      await act(async () => {
        deleteResult = await result.current.deletePost(999);
      });

      expect(deleteResult!).toBe(false);
    });

    it('sets isDeleting during delete operation', async () => {
      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // 削除を開始
      let deletePromise: Promise<boolean>;
      act(() => {
        deletePromise = result.current.deletePost(1);
      });

      // 削除中はisDeletingがtrue
      expect(result.current.isDeleting).toBe(true);

      // 完了を待つ
      await act(async () => {
        await deletePromise;
      });

      expect(result.current.isDeleting).toBe(false);
    });
  });

  describe('Refetch', () => {
    it('refetches posts and stats', async () => {
      const { result } = renderHook(() => usePosts(), {
        wrapper: createWrapper(),
      });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // APIレスポンスを変更
      server.use(
        http.get('/api/me/posts', () => {
          return HttpResponse.json({
            success: true,
            data: {
              posts: [
                {
                  id: 100,
                  user_id: 1,
                  title: 'Refetched Post',
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

      // refetchを呼び出し
      act(() => {
        result.current.refetch();
      });

      // 新しいデータが取得されること
      await waitFor(() => {
        expect(result.current.posts[0]?.title).toBe('Refetched Post');
      });
    });
  });
});
