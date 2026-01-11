// pages/PostListPage/PostListPage.tsx
import { Header } from '../../components/common/Header/Header';
import styles from './PostListPage.module.css';

export function PostListPage() {
  return (
    <div className={styles.container}>
      <Header activeTab="posts" />

      <main className={styles.main}>
        <section aria-labelledby="stats-heading" className={styles.statsSection}>
          <h2 id="stats-heading" className="visually-hidden">統計情報</h2>
          <div className={styles.statsGrid}>
            {/* TODO: Phase 3 で StatsCard コンポーネントを実装 */}
            <div className={styles.statsPlaceholder}>統計カード（未実装）</div>
          </div>
        </section>

        <section aria-labelledby="posts-heading" className={styles.postsSection}>
          <h2 id="posts-heading" className={styles.sectionTitle}>記事一覧</h2>
          {/* TODO: Phase 3 で PostTable コンポーネントを実装 */}
          <div className={styles.tablePlaceholder}>記事テーブル（未実装）</div>
        </section>

        {/* TODO: Phase 3 で Pagination コンポーネントを実装 */}
      </main>
    </div>
  );
}
