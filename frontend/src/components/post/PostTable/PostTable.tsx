// components/post/PostTable/PostTable.tsx
import type { Post } from '../../../types/post';
import { formatDate } from '../../../utils/formatDate';
import styles from './PostTable.module.css';

interface PostTableProps {
  posts: Post[];
  onEdit: (id: number) => void;
  onDelete: (post: Post) => void;
}

export function PostTable({ posts, onEdit, onDelete }: PostTableProps) {
  return (
    <div className={styles.tableContainer}>
      <table className={styles.table}>
        <caption className="visually-hidden">
          投稿記事の一覧。タイトル、ステータス、作成日、操作列を含む。
        </caption>
        <thead>
          <tr className={styles.headerRow}>
            <th scope="col" className={styles.headerCell}>
              タイトル
            </th>
            <th scope="col" className={styles.headerCell}>
              ステータス
            </th>
            <th scope="col" className={styles.headerCell}>
              作成日
            </th>
            <th scope="col" className={styles.headerCell}>
              操作
            </th>
          </tr>
        </thead>
        <tbody>
          {posts.map((post) => (
            <tr
              key={post.id}
              className={styles.row}
              onClick={() => onEdit(post.id)}
            >
              <td className={styles.cell}>
                <span className={styles.title}>{post.title}</span>
              </td>
              <td className={styles.cell}>
                <span
                  className={
                    post.published ? styles.badgePublished : styles.badgeDraft
                  }
                >
                  {post.published ? '公開中' : '下書き'}
                </span>
              </td>
              <td className={styles.cell}>
                <span className={styles.date}>
                  {formatDate(post.created_at)}
                </span>
              </td>
              <td className={styles.cell}>
                <div className={styles.actions}>
                  <button
                    type="button"
                    className={styles.editButton}
                    onClick={(e) => {
                      e.stopPropagation();
                      onEdit(post.id);
                    }}
                  >
                    編集
                  </button>
                  <button
                    type="button"
                    className={styles.deleteButton}
                    onClick={(e) => {
                      e.stopPropagation();
                      onDelete(post);
                    }}
                  >
                    削除
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
