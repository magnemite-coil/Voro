// hooks/usePost.test.ts
import { renderHook, waitFor, act } from '@testing-library/react';
import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { usePost } from './usePost';

const server = setupServer();

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('usePost - Initial State', () => {
  it('should have initial state without postId', () => {
    const { result } = renderHook(() => usePost());

    expect(result.current.post).toBeNull();
    expect(result.current.isLoading).toBe(false);
    expect(result.current.error).toBeNull();
  });

  it('should set isLoading to true when postId is provided', () => {
    server.use(
      http.get('/api/posts/1', async () => {
        await new Promise((resolve) => setTimeout(resolve, 100));
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Test',
              content: 'Content',
              published: false,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
          },
        });
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    expect(result.current.isLoading).toBe(true);
  });
});

describe('usePost - fetchPost', () => {
  it('should fetch post successfully', async () => {
    const mockPost = {
      id: 1,
      user_id: 1,
      title: 'Test Post',
      content: 'Test content',
      published: false,
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    };

    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: { post: mockPost },
        });
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.post).toEqual(mockPost);
    expect(result.current.error).toBeNull();
  });

  it('should set error to "Post not found" on 404', async () => {
    server.use(
      http.get('/api/posts/999', () => {
        return HttpResponse.json(
          { success: false, error: 'Not found' },
          { status: 404 }
        );
      })
    );

    const { result } = renderHook(() => usePost({ postId: 999 }));

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.post).toBeNull();
    expect(result.current.error).toBe('Post not found');
  });

  it('should set error message from API on other errors', async () => {
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json(
          { success: false, error: 'Forbidden' },
          { status: 403 }
        );
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.error).toBe('Forbidden');
  });
});

describe('usePost - createPost', () => {
  it('should create post successfully', async () => {
    const createdPost = {
      id: 1,
      user_id: 1,
      title: 'New Post',
      content: 'New content',
      published: false,
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    };

    server.use(
      http.post('/api/posts', () => {
        return HttpResponse.json(
          { success: true, data: { post: createdPost } },
          { status: 201 }
        );
      })
    );

    const { result } = renderHook(() => usePost());

    let returnedPost;
    await act(async () => {
      returnedPost = await result.current.createPost({
        title: 'New Post',
        content: 'New content',
        published: false,
      });
    });

    expect(returnedPost).toEqual(createdPost);
    expect(result.current.post).toEqual(createdPost);
  });

  it('should throw error on API failure', async () => {
    server.use(
      http.post('/api/posts', () => {
        return HttpResponse.json(
          { success: false, error: 'Title is required' },
          { status: 400 }
        );
      })
    );

    const { result } = renderHook(() => usePost());

    let thrownError: Error | null = null;
    try {
      await act(async () => {
        await result.current.createPost({
          title: '',
          content: 'Content',
          published: false,
        });
      });
    } catch (e) {
      thrownError = e as Error;
    }

    expect(thrownError).not.toBeNull();
  });
});

describe('usePost - updatePost', () => {
  it('should update post successfully', async () => {
    const initialPost = {
      id: 1,
      user_id: 1,
      title: 'Original',
      content: 'Original content',
      published: false,
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    };

    const updatedPost = {
      ...initialPost,
      title: 'Updated',
      updated_at: '2025-01-02T00:00:00Z',
    };

    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: { post: initialPost },
        });
      }),
      http.put('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: { post: updatedPost },
        });
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    // Wait for initial fetch
    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    let returnedPost;
    await act(async () => {
      returnedPost = await result.current.updatePost({ title: 'Updated' });
    });

    expect(returnedPost).toEqual(updatedPost);
    expect(result.current.post).toEqual(updatedPost);
  });

  it('should throw error with custom message on 403', async () => {
    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: {
            post: {
              id: 1,
              user_id: 1,
              title: 'Test',
              content: 'Content',
              published: false,
              created_at: '2025-01-01T00:00:00Z',
              updated_at: '2025-01-01T00:00:00Z',
            },
          },
        });
      }),
      http.put('/api/posts/1', () => {
        return HttpResponse.json(
          { success: false, error: 'Forbidden' },
          { status: 403 }
        );
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    let thrownError: Error | null = null;
    try {
      await act(async () => {
        await result.current.updatePost({ title: 'Updated' });
      });
    } catch (e) {
      thrownError = e as Error;
    }

    expect(thrownError).not.toBeNull();
    expect(thrownError?.message).toBe('You do not have permission to edit this post');
  });

  it('should throw error when postId is not provided', async () => {
    const { result } = renderHook(() => usePost());

    let thrownError: Error | null = null;
    try {
      await act(async () => {
        await result.current.updatePost({ title: 'Updated' });
      });
    } catch (e) {
      thrownError = e as Error;
    }

    expect(thrownError).not.toBeNull();
    expect(thrownError?.message).toBe('Post ID is required for update');
  });
});

describe('usePost - reset', () => {
  it('should reset state', async () => {
    const mockPost = {
      id: 1,
      user_id: 1,
      title: 'Test',
      content: 'Content',
      published: false,
      created_at: '2025-01-01T00:00:00Z',
      updated_at: '2025-01-01T00:00:00Z',
    };

    server.use(
      http.get('/api/posts/1', () => {
        return HttpResponse.json({
          success: true,
          data: { post: mockPost },
        });
      })
    );

    const { result } = renderHook(() => usePost({ postId: 1 }));

    await waitFor(() => {
      expect(result.current.post).toEqual(mockPost);
    });

    act(() => {
      result.current.reset();
    });

    expect(result.current.post).toBeNull();
    expect(result.current.error).toBeNull();
    expect(result.current.isLoading).toBe(false);
  });
});
