// test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

// モックデータ（42件を動的生成）
// 統計APIのモック値（total: 42, published: 38, draft: 4）と整合性を保つ
const mockPosts = Array.from({ length: 42 }, (_, i) => ({
  id: i + 1,
  user_id: 1,
  title: `テスト投稿 ${i + 1}`,
  content: `テスト本文 ${i + 1}`,
  published: i >= 4, // 最初の4件（i=0,1,2,3）が下書き、残り38件が公開
  created_at: new Date(2025, 9, 25 - Math.floor(i / 2)).toISOString(), // 日付をずらす
  updated_at: new Date(2025, 9, 25 - Math.floor(i / 2)).toISOString(),
}));

// 記事一覧用ハンドラー
const postListHandlers = [
  // 投稿一覧（ページネーション付き）
  http.get('/api/me/posts', ({ request }) => {
    const url = new URL(request.url);
    const page = Number(url.searchParams.get('page')) || 1;
    const perPage = 20;
    const totalCount = 42;

    return HttpResponse.json({
      success: true,
      data: {
        posts: mockPosts.slice((page - 1) * perPage, page * perPage),
        pagination: {
          page,
          per_page: perPage,
          total_count: totalCount,
          total_pages: Math.ceil(totalCount / perPage),
        },
      },
    });
  }),

  // 統計情報
  http.get('/api/me/posts/stats', () => {
    return HttpResponse.json({
      success: true,
      data: {
        stats: {
          total: 42,
          published: 38,
          draft: 4,
          this_month: 7,
        },
      },
    });
  }),

  // 削除
  http.delete('/api/posts/:id', () => {
    return HttpResponse.json({
      success: true,
      data: { message: 'Post deleted successfully' },
    });
  }),
];

export const handlers = [
  // 記事一覧用ハンドラー（先頭に配置して優先度を明確に）
  ...postListHandlers,

  // ログイン（デフォルト: 成功）
  http.post('/api/auth/login', async ({ request }) => {
    const body = (await request.json()) as {
      username: string;
      password: string;
    };
    return HttpResponse.json({
      success: true,
      data: {
        user: {
          id: 1,
          username: body.username,
        },
      },
    });
  }),

  // ユーザー登録（デフォルト: 成功）
  http.post('/api/auth/register', async ({ request }) => {
    const body = (await request.json()) as {
      username: string;
      email: string;
      password: string;
    };
    return HttpResponse.json({
      success: true,
      data: {
        user: { id: 1, username: body.username },
      },
    });
  }),

  // ログアウト
  http.post('/api/auth/logout', () => {
    return HttpResponse.json({
      success: true,
      data: null,
    });
  }),

  // 投稿作成
  http.post('/api/posts', async ({ request }) => {
    const body = (await request.json()) as {
      title: string;
      content: string;
      published: boolean;
    };
    return HttpResponse.json(
      {
        success: true,
        data: {
          post: {
            id: 1,
            user_id: 1,
            title: body.title,
            content: body.content,
            published: body.published,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        },
      },
      { status: 201 }
    );
  }),

  // 投稿取得
  http.get('/api/posts/:id', ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      success: true,
      data: {
        post: {
          id: Number(id),
          user_id: 1,
          title: 'Test Post',
          content: 'Test content',
          published: false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      },
    });
  }),

  // 投稿更新
  http.put('/api/posts/:id', async ({ params, request }) => {
    const { id } = params;
    const body = (await request.json()) as {
      title?: string;
      content?: string;
      published?: boolean;
    };
    return HttpResponse.json({
      success: true,
      data: {
        post: {
          id: Number(id),
          user_id: 1,
          title: body.title ?? 'Test Post',
          content: body.content ?? 'Test content',
          published: body.published ?? false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      },
    });
  }),
];

export const errorResponse = {
  unauthorized: () =>
    HttpResponse.json({ success: false, error: 'Unauthorized' }, { status: 401 }),
  notFound: () =>
    HttpResponse.json({ success: false, error: 'Post not found' }, { status: 404 }),
  forbidden: () =>
    HttpResponse.json({ success: false, error: 'Forbidden' }, { status: 403 }),
  validationError: (message: string) =>
    HttpResponse.json({ success: false, error: message }, { status: 400 }),
  serverError: (errorId?: string) =>
    HttpResponse.json(
      {
        success: false,
        error: 'Internal server error',
        error_id: errorId ?? 'test-error-id',
      },
      { status: 500 }
    ),
};
