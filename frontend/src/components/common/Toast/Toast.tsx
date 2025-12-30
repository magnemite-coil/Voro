// components/common/Toast/Toast.tsx
import clsx from 'clsx';
import { useNotification } from '../../../contexts/NotificationContext';
import styles from './Toast.module.css';

export function Toast() {
  const { notifications, removeNotification } = useNotification();

  if (notifications.length === 0) return null;

  return (
    <div className={styles.toastContainer} aria-live="polite" aria-atomic="true">
      {notifications.map((notification) => (
        <div
          key={notification.id}
          className={clsx(styles.toast, styles[notification.type])}
          role="alert"
        >
          <span className={styles.message}>{notification.message}</span>
          <button
            className={styles.closeButton}
            onClick={() => removeNotification(notification.id)}
            aria-label="通知を閉じる"
          >
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
