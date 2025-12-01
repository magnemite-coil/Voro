// contexts/NotificationContext.tsx
import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  useRef,
  type ReactNode,
} from 'react';

export interface Notification {
  id: string;
  type: 'success' | 'error' | 'info';
  message: string;
}

interface NotificationContextValue {
  notifications: Notification[];
  showNotification: (type: Notification['type'], message: string) => void;
  removeNotification: (id: string) => void;
}

const NotificationContext = createContext<NotificationContextValue | null>(null);

const NOTIFICATION_DURATION = 3000; // 3秒後に自動消去

export function NotificationProvider({ children }: { children: ReactNode }) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const timerIdsRef = useRef<Map<string, NodeJS.Timeout>>(new Map());

  // アンマウント時に全タイマーをクリア
  useEffect(() => {
    return () => {
      timerIdsRef.current.forEach((timerId) => clearTimeout(timerId));
      timerIdsRef.current.clear();
    };
  }, []);

  const removeNotification = useCallback((id: string) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
    const timerId = timerIdsRef.current.get(id);
    if (timerId) {
      clearTimeout(timerId);
      timerIdsRef.current.delete(id);
    }
  }, []);

  const showNotification = useCallback(
    (type: Notification['type'], message: string) => {
      const id = crypto.randomUUID();
      setNotifications((prev) => [...prev, { id, type, message }]);

      const timerId = setTimeout(() => {
        if (!timerIdsRef.current.has(id)) return;
        setNotifications((prev) => prev.filter((n) => n.id !== id));
        timerIdsRef.current.delete(id);
      }, NOTIFICATION_DURATION);
      timerIdsRef.current.set(id, timerId);
    },
    []
  );

  return (
    <NotificationContext.Provider
      value={{ notifications, showNotification, removeNotification }}
    >
      {children}
    </NotificationContext.Provider>
  );
}

export function useNotification() {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotification must be used within NotificationProvider');
  }
  return context;
}
