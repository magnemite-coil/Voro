// services/api.test.ts
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { api, ApiError, formatErrorMessage } from './api';

const server = setupServer();

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('ApiError', () => {
  it('should store message, errorId, and statusCode', () => {
    const error = new ApiError('Test error', 'err-123', 400);
    expect(error.message).toBe('Test error');
    expect(error.errorId).toBe('err-123');
    expect(error.statusCode).toBe(400);
    expect(error.name).toBe('ApiError');
  });

  it('should work without optional parameters', () => {
    const error = new ApiError('Simple error');
    expect(error.message).toBe('Simple error');
    expect(error.errorId).toBeUndefined();
    expect(error.statusCode).toBeUndefined();
  });

  it('should be an instance of Error', () => {
    const error = new ApiError('Test error');
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(ApiError);
  });
});

describe('formatErrorMessage', () => {
  it('should include error_id for 500 errors', () => {
    const error = new ApiError('Server error', 'abc-123', 500);
    expect(formatErrorMessage(error)).toBe('サーバーエラーが発生しました (ID: abc-123)');
  });

  it('should return message for non-500 errors', () => {
    const error = new ApiError('Validation failed', undefined, 400);
    expect(formatErrorMessage(error)).toBe('Validation failed');
  });

  it('should return message for 500 error without error_id', () => {
    const error = new ApiError('Internal error', undefined, 500);
    expect(formatErrorMessage(error)).toBe('Internal error');
  });

  it('should return message for errors without statusCode', () => {
    const error = new ApiError('Unknown error');
    expect(formatErrorMessage(error)).toBe('Unknown error');
  });
});

describe('api.get', () => {
  it('should return data on success', async () => {
    server.use(
      http.get('/api/test', () => {
        return HttpResponse.json({ success: true, data: { value: 'test' } });
      })
    );
    const result = await api.get<{ value: string }>('/test');
    expect(result.value).toBe('test');
  });

  it('should throw ApiError on 404', async () => {
    server.use(
      http.get('/api/test', () => {
        return HttpResponse.json(
          { success: false, error: 'Not found' },
          { status: 404 }
        );
      })
    );
    await expect(api.get('/test')).rejects.toThrow(ApiError);
    try {
      await api.get('/test');
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(404);
      expect((e as ApiError).message).toBe('Not found');
    }
  });

  it('should throw ApiError on 401', async () => {
    server.use(
      http.get('/api/test', () => {
        return HttpResponse.json(
          { success: false, error: 'Unauthorized' },
          { status: 401 }
        );
      })
    );
    try {
      await api.get('/test');
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(401);
    }
  });

  it('should include error_id in ApiError when present', async () => {
    server.use(
      http.get('/api/test', () => {
        return HttpResponse.json(
          { success: false, error: 'Server error', error_id: 'err-abc-123' },
          { status: 500 }
        );
      })
    );
    try {
      await api.get('/test');
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).errorId).toBe('err-abc-123');
    }
  });

  it('should support AbortSignal', async () => {
    server.use(
      http.get('/api/test', async () => {
        // Simulate slow response
        await new Promise((resolve) => setTimeout(resolve, 100));
        return HttpResponse.json({ success: true, data: { value: 'test' } });
      })
    );

    const controller = new AbortController();
    const promise = api.get('/test', { signal: controller.signal });
    controller.abort();

    await expect(promise).rejects.toThrow();
  });
});

describe('api.post', () => {
  it('should send POST request with body', async () => {
    let receivedBody: unknown;
    server.use(
      http.post('/api/posts', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(
          { success: true, data: { id: 1 } },
          { status: 201 }
        );
      })
    );

    const result = await api.post<{ id: number }>('/posts', {
      title: 'Test',
      content: 'Content',
    });

    expect(result.id).toBe(1);
    expect(receivedBody).toEqual({ title: 'Test', content: 'Content' });
  });

  it('should throw ApiError on validation error (400)', async () => {
    server.use(
      http.post('/api/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Title is required' },
          { status: 400 }
        );
      })
    );

    try {
      await api.post('/posts', { content: 'Content' });
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(400);
      expect((e as ApiError).message).toBe('Title is required');
    }
  });

  it('should throw ApiError on server error (500)', async () => {
    server.use(
      http.post('/api/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Internal server error', error_id: 'srv-123' },
          { status: 500 }
        );
      })
    );

    try {
      await api.post('/posts', { title: 'Test', content: 'Content' });
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(500);
      expect((e as ApiError).errorId).toBe('srv-123');
    }
  });

  it('should support AbortSignal', async () => {
    server.use(
      http.post('/api/posts', async () => {
        // Simulate slow response
        await new Promise((resolve) => setTimeout(resolve, 100));
        return HttpResponse.json({ success: true, data: { id: 1 } });
      })
    );

    const controller = new AbortController();
    const promise = api.post('/posts', { title: 'Test' }, { signal: controller.signal });
    controller.abort();

    await expect(promise).rejects.toThrow();
  });
});

describe('api.put', () => {
  it('should send PUT request with body', async () => {
    let receivedBody: unknown;
    server.use(
      http.put('/api/posts/1', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({
          success: true,
          data: { id: 1, title: 'Updated' },
        });
      })
    );

    const result = await api.put<{ id: number; title: string }>('/posts/1', {
      title: 'Updated',
    });

    expect(result.title).toBe('Updated');
    expect(receivedBody).toEqual({ title: 'Updated' });
  });

  it('should throw ApiError on 403 forbidden', async () => {
    server.use(
      http.put('/api/posts/1', () => {
        return HttpResponse.json(
          { success: false, error: 'Forbidden' },
          { status: 403 }
        );
      })
    );

    try {
      await api.put('/posts/1', { title: 'Updated' });
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(403);
    }
  });

  it('should support AbortSignal', async () => {
    server.use(
      http.put('/api/posts/1', async () => {
        // Simulate slow response
        await new Promise((resolve) => setTimeout(resolve, 100));
        return HttpResponse.json({ success: true, data: { id: 1, title: 'Updated' } });
      })
    );

    const controller = new AbortController();
    const promise = api.put('/posts/1', { title: 'Updated' }, { signal: controller.signal });
    controller.abort();

    await expect(promise).rejects.toThrow();
  });
});

describe('api.delete', () => {
  it('should send DELETE request', async () => {
    server.use(
      http.delete('/api/posts/1', () => {
        return HttpResponse.json({ success: true, data: null });
      })
    );

    const result = await api.delete('/posts/1');
    expect(result).toBeNull();
  });

  it('should throw ApiError on 404', async () => {
    server.use(
      http.delete('/api/posts/999', () => {
        return HttpResponse.json(
          { success: false, error: 'Post not found' },
          { status: 404 }
        );
      })
    );

    try {
      await api.delete('/posts/999');
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError);
      expect((e as ApiError).statusCode).toBe(404);
    }
  });

  it('should support AbortSignal', async () => {
    server.use(
      http.delete('/api/posts/1', async () => {
        // Simulate slow response
        await new Promise((resolve) => setTimeout(resolve, 100));
        return HttpResponse.json({ success: true, data: null });
      })
    );

    const controller = new AbortController();
    const promise = api.delete('/posts/1', { signal: controller.signal });
    controller.abort();

    await expect(promise).rejects.toThrow();
  });
});
