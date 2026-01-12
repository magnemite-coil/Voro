// hooks/usePosts.ts
import { useState, useCallback, useEffect } from 'react';
import { useSearchParams, useNavigate } from 'react-router';
import { api, ApiError, formatErrorMessage } from '../services/api';
import { useNotification } from '../contexts/NotificationContext';
import type { Post, PostListResponse, PostStatsResponse } from '../types/post';
import type { Pagination, PostStats } from '../types/api';

interface UsePostsReturn {
  // データ
  posts: Post[];
  pagination: Pagination | null;
  stats: PostStats | null;

  // 状態
  isLoading: boolean;
  isStatsLoading: boolean;
  isDeleting: boolean;
  error: string | null;

  // 操作
  deletePost: (id: number) => Promise<boolean>;
  refetch: () => void;
}

export function usePosts(): UsePostsReturn {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { showNotification } = useNotification();
  const page = Number(searchParams.get('page')) || 1;

  const [posts, setPosts] = useState<Post[]>([]);
  const [pagination, setPagination] = useState<Pagination | null>(null);
  const [stats, setStats] = useState<PostStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isStatsLoading, setIsStatsLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 認証エラー処理（共通）
  const handleAuthError = useCallback(() => {
    navigate('/login', { replace: true });
  }, [navigate]);

  // 投稿一覧取得
  const fetchPosts = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // per_page を明示的に指定（バックエンドのデフォルトに依存しない）
      const data = await api.get<PostListResponse>(`/me/posts?page=${page}&per_page=20`);
      setPosts(data.posts);
      setPagination(data.pagination);
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.statusCode === 401) {
          handleAuthError();
          return;
        }
        // formatErrorMessage を使用して500エラー時のerror_idを表示
        setError(formatErrorMessage(e));
      } else {
        setError('投稿の取得に失敗しました');
      }
    } finally {
      setIsLoading(false);
    }
  }, [page, handleAuthError]);

  // 統計情報取得
  const fetchStats = useCallback(async () => {
    setIsStatsLoading(true);
    try {
      const data = await api.get<PostStatsResponse>('/me/posts/stats');
      setStats(data.stats);
    } catch (e) {
      if (e instanceof ApiError && e.statusCode === 401) {
        // 認証切れ: ログインページへリダイレクト
        handleAuthError();
        return;
      }
      // その他のエラー: 統計取得失敗は致命的ではないのでログのみ
      console.error('Failed to fetch stats:', e);
    } finally {
      setIsStatsLoading(false);
    }
  }, [handleAuthError]);

  // 投稿一覧取得（ページ変更時も再取得）
  useEffect(() => {
    fetchPosts();
  }, [fetchPosts]);

  // 統計情報取得（初回のみ、ページ変更では再取得しない）
  // 注意: 削除後の統計更新は deletePost 内で明示的に fetchStats() を呼び出す
  //
  // eslint-disable の理由:
  // - fetchStats は handleAuthError に依存するが、認証状態は初回レンダリング後に
  //   ユーザー操作なしで変化しないため、依存配列から除外しても安全
  // - 統計情報はページ遷移で再取得する必要がないため、初回のみ実行
  //
  // 将来の改善オプション（React 19.2+）:
  // - useEffectEvent フックが安定版となった（React 19.2）
  // - handleAuthError を useEffectEvent でラップすることで、依存配列から除外可能に
  // - 参考: https://react.dev/reference/react/useEffectEvent
  useEffect(() => {
    fetchStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 削除処理
  const deletePost = useCallback(async (id: number): Promise<boolean> => {
    setIsDeleting(true);
    try {
      await api.delete(`/posts/${id}`);
      showNotification('success', '記事を削除しました');
      // 削除後にリストと統計を再取得
      await Promise.all([fetchPosts(), fetchStats()]);
      return true;
    } catch (e) {
      if (e instanceof ApiError) {
        if (e.statusCode === 401) {
          handleAuthError();
          return false;
        }
        if (e.statusCode === 403) {
          showNotification('error', 'この記事を削除する権限がありません');
        } else if (e.statusCode === 404) {
          showNotification('error', '記事が見つかりませんでした');
        } else {
          // formatErrorMessage を使用して500エラー時のerror_idを表示
          showNotification('error', formatErrorMessage(e));
        }
      } else {
        showNotification('error', '記事の削除に失敗しました');
      }
      return false;
    } finally {
      setIsDeleting(false);
    }
  }, [fetchPosts, fetchStats, handleAuthError, showNotification]);

  // 再取得
  const refetch = useCallback(() => {
    fetchPosts();
    fetchStats();
  }, [fetchPosts, fetchStats]);

  return {
    posts,
    pagination,
    stats,
    isLoading,
    isStatsLoading,
    isDeleting,
    error,
    deletePost,
    refetch,
  };
}
