// pages/PostListPage/PostListPage.tsx
import { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { Header } from '../../components/common/Header/Header';
import { ConfirmModal } from '../../components/common/ConfirmModal/ConfirmModal';
import { Skeleton } from '../../components/common/Skeleton/Skeleton';
import { StatsCard } from '../../components/post/StatsCard/StatsCard';
import { PostTable } from '../../components/post/PostTable/PostTable';
import { Pagination } from '../../components/post/Pagination/Pagination';
import { usePosts } from '../../hooks/usePosts';
import type { Post } from '../../types/post';
import styles from './PostListPage.module.css';

export function PostListPage() {
  const navigate = useNavigate();
  const [, setSearchParams] = useSearchParams();
  const {
    posts,
    pagination,
    stats,
    isLoading,
    isStatsLoading,
    isDeleting,
    error,
    deletePost,
    refetch,
  } = usePosts();

  const [deleteTarget, setDeleteTarget] = useState<Post | null>(null);

  // 空ページ検出: 現在ページに投稿がないが、全体には投稿がある場合
  useEffect(() => {
    if (posts.length === 0 && pagination && pagination.total_count > 0) {
      const validPage = Math.max(1, pagination.total_pages);
      navigate(`/posts?page=${validPage}`, { replace: true });
    }
  }, [posts, pagination, navigate]);

  const handlePageChange = (newPage: number) => {
    setSearchParams((prev) => {
      prev.set('page', String(newPage));
      return prev;
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleEdit = (id: number) => {
    navigate(`/posts/${id}/edit`);
  };

  const handleDelete = (post: Post) => {
    setDeleteTarget(post);
  };

  const handleDeleteConfirm = async () => {
    if (!deleteTarget) return;
    const success = await deletePost(deleteTarget.id);
    if (success) {
      setDeleteTarget(null);
    }
  };

  const handleDeleteCancel = () => {
    setDeleteTarget(null);
  };

  // ローディング中
  if (isLoading && !pagination) {
    return (
      <div className={styles.container}>
        <Header activeTab="posts" />
        <main className={styles.main}>
          <div className={styles.loadingContainer}>
            <div className={styles.spinner} />
            <p>読み込み中...</p>
          </div>
        </main>
      </div>
    );
  }

  // エラー状態
  if (error) {
    return (
      <div className={styles.container}>
        <Header activeTab="posts" />
        <main className={styles.main}>
          <div className={styles.errorContainer} role="alert">
            <p className={styles.errorMessage}>{error}</p>
            <button
              type="button"
              className={styles.retryButton}
              onClick={refetch}
            >
              再試行
            </button>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <Header activeTab="posts" />

      <main className={styles.main}>
        {/* 統計セクション */}
        <section aria-labelledby="stats-heading" className={styles.statsSection}>
          <h2 id="stats-heading" className="visually-hidden">
            統計情報
          </h2>
          <div className={styles.statsGrid}>
            {isStatsLoading ? (
              <>
                <div className={styles.statsCardSkeleton}>
                  <Skeleton height="0.9rem" width="60%" />
                  <Skeleton height="2.5rem" width="80%" />
                </div>
                <div className={styles.statsCardSkeleton}>
                  <Skeleton height="0.9rem" width="60%" />
                  <Skeleton height="2.5rem" width="80%" />
                </div>
                <div className={styles.statsCardSkeleton}>
                  <Skeleton height="0.9rem" width="60%" />
                  <Skeleton height="2.5rem" width="80%" />
                </div>
                <div className={styles.statsCardSkeleton}>
                  <Skeleton height="0.9rem" width="60%" />
                  <Skeleton height="2.5rem" width="80%" />
                </div>
              </>
            ) : (
              <>
                <StatsCard label="総記事数" value={stats?.total ?? 0} />
                <StatsCard label="公開中" value={stats?.published ?? 0} />
                <StatsCard label="下書き" value={stats?.draft ?? 0} />
                <StatsCard label="今月の投稿" value={stats?.this_month ?? 0} />
              </>
            )}
          </div>
        </section>

        {/* 記事一覧セクション */}
        <section aria-labelledby="posts-heading" className={styles.postsSection}>
          <h2 id="posts-heading" className={styles.sectionTitle}>
            記事一覧
          </h2>

          {pagination?.total_count === 0 ? (
            <div className={styles.emptyState} role="status" aria-live="polite">
              <p>まだ記事がありません</p>
              <Link to="/posts/new" className={styles.createLink}>
                最初の記事を作成する
              </Link>
            </div>
          ) : isLoading && pagination ? (
            <div className={styles.tableLoadingContainer}>
              <div className={styles.spinner} />
              <p>読み込み中...</p>
            </div>
          ) : (
            <>
              <PostTable
                posts={posts}
                onEdit={handleEdit}
                onDelete={handleDelete}
              />
              {pagination && pagination.total_pages > 1 && (
                <Pagination
                  currentPage={pagination.page}
                  totalPages={pagination.total_pages}
                  onPageChange={handlePageChange}
                  disabled={isDeleting}
                />
              )}
            </>
          )}
        </section>
      </main>

      {/* 削除確認モーダル */}
      <ConfirmModal
        isOpen={!!deleteTarget}
        title="記事の削除"
        message={`「${deleteTarget?.title ?? ''}」を削除しますか？この操作は取り消せません。`}
        confirmLabel="削除"
        cancelLabel="キャンセル"
        isConfirmLoading={isDeleting}
        onConfirm={handleDeleteConfirm}
        onCancel={handleDeleteCancel}
      />
    </div>
  );
}
