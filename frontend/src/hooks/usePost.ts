// hooks/usePost.ts
import { useState, useCallback, useEffect } from 'react';
import { api, ApiError } from '../services/api';
import type { Post, CreatePostData, UpdatePostData } from '../types/post';

interface UsePostOptions {
  postId?: number;
}

interface UsePostReturn {
  post: Post | null;
  isLoading: boolean;
  error: string | null;
  createPost: (data: CreatePostData) => Promise<Post>;
  updatePost: (data: UpdatePostData) => Promise<Post>;
  reset: () => void;
}

interface PostResponse {
  post: Post;
}

export function usePost(options: UsePostOptions = {}): UsePostReturn {
  const { postId } = options;
  const [post, setPost] = useState<Post | null>(null);
  const [isLoading, setIsLoading] = useState(!!postId);
  const [error, setError] = useState<string | null>(null);

  const fetchPost = useCallback(async (id: number) => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await api.get<PostResponse>(`/posts/${id}`);
      setPost(data.post);
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.statusCode === 404) {
          setError('Post not found');
        } else {
          setError(e.message);
        }
      } else {
        setError('Failed to load post');
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (postId) {
      fetchPost(postId);
    }
  }, [postId, fetchPost]);

  const createPost = useCallback(async (data: CreatePostData): Promise<Post> => {
    const result = await api.post<PostResponse>('/posts', data);
    setPost(result.post);
    return result.post;
  }, []);

  const updatePost = useCallback(
    async (data: UpdatePostData): Promise<Post> => {
      if (!postId) {
        throw new Error('Post ID is required for update');
      }
      try {
        const result = await api.put<PostResponse>(`/posts/${postId}`, data);
        setPost(result.post);
        return result.post;
      } catch (e) {
        if (e instanceof ApiError && e.statusCode === 403) {
          throw new Error('You do not have permission to edit this post');
        }
        throw e;
      }
    },
    [postId]
  );

  const reset = useCallback(() => {
    setPost(null);
    setError(null);
    setIsLoading(false);
  }, []);

  return {
    post,
    isLoading,
    error,
    createPost,
    updatePost,
    reset,
  };
}
