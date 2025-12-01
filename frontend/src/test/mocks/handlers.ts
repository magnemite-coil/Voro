// test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  // 認証検証（デフォルト: 認証済み）
  http.get('/api/me/posts', () => {
    return HttpResponse.json({
      success: true,
      data: { posts: [] },
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
