// components/common/Header/Header.tsx
import { type ReactNode } from 'react';
import { Link } from 'react-router';
import styles from './Header.module.css';

interface HeaderProps {
  actions?: ReactNode;
  activeTab?: 'posts' | 'new';
}

export function Header({ actions, activeTab = 'new' }: HeaderProps) {
  return (
    <header className={styles.header}>
      <div className={styles.left}>
        <Link to="/" className={styles.logo}>
          Voro
        </Link>
        <nav className={styles.nav}>
          <span
            className={`${styles.navTab} ${styles.disabled}`}
            aria-disabled="true"
          >
            記事一覧
          </span>
          <Link
            to="/posts/new"
            className={`${styles.navTab} ${activeTab === 'new' ? styles.active : ''}`}
          >
            新規作成
          </Link>
        </nav>
      </div>
      {actions && <div className={styles.actions}>{actions}</div>}
    </header>
  );
}
