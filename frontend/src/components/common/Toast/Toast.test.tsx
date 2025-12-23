// Toast.test.tsx
/* eslint-disable react-hooks/globals */
import { render, screen, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  NotificationProvider,
  useNotification,
  type Notification,
} from '../../../contexts/NotificationContext';
import { Toast } from './Toast';

/**
 * Toast コンポーネントをテストするためのラッパー
 *
 * Toast は NotificationContext に依存するため、
 * NotificationProvider と連携してテストする必要がある。
 *
 * このパターンは NotificationContext.test.tsx から流用。
 */
function renderToastWithNotifications() {
  let showFn!: (type: Notification['type'], message: string) => void;
  let removeFn!: (id: string) => void;
  let notificationsSnapshot: Notification[] = [];

  const TestController = () => {
    const { showNotification, removeNotification, notifications } = useNotification();
    showFn = showNotification;
    removeFn = removeNotification;
    notificationsSnapshot = notifications;
    return null;
  };

  const result = render(
    <NotificationProvider>
      <TestController />
      <Toast />
    </NotificationProvider>
  );

  return {
    ...result,
    showNotification: async (type: Notification['type'], message: string) => {
      await act(async () => {
        showFn(type, message);
      });
    },
    removeNotification: async (id: string) => {
      await act(async () => {
        removeFn(id);
      });
    },
    getNotifications: () => notificationsSnapshot,
  };
}

// =============================================================================
// Basic Rendering
// =============================================================================
describe('Toast - Basic Rendering', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.clearAllTimers();
    vi.useRealTimers();
  });

  it('renders nothing when there are no notifications (TO-1)', () => {
    const { container } = renderToastWithNotifications();

    // Toast が null を返す場合、aria-live 要素は存在しない
    // CSS Modules のハッシュ化クラス名に依存しない方法
    expect(container.querySelector('[aria-live="polite"]')).not.toBeInTheDocument();
  });

  it('renders notification with message and close button (TO-2)', async () => {
    const { showNotification } = renderToastWithNotifications();

    await showNotification('success', 'テスト通知');

    expect(screen.getByText('テスト通知')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '通知を閉じる' })).toBeInTheDocument();
  });
});

// =============================================================================
// Close Button (カバレッジ改善のメイン対象)
// =============================================================================
describe('Toast - Close Button', () => {
  it('removes notification when close button is clicked (TO-3)', async () => {
    // FakeTimers を使用しない - 自動消去タイマー（3秒）より前にクリックする
    // userEvent と FakeTimers の組み合わせでタイムアウトが発生するため
    const user = userEvent.setup();
    const { showNotification, getNotifications } = renderToastWithNotifications();

    await showNotification('success', 'テスト通知');
    expect(getNotifications()).toHaveLength(1);
    expect(screen.getByText('テスト通知')).toBeInTheDocument();

    const closeButton = screen.getByRole('button', { name: '通知を閉じる' });
    await user.click(closeButton);

    expect(getNotifications()).toHaveLength(0);
    expect(screen.queryByText('テスト通知')).not.toBeInTheDocument();
  });
});

// =============================================================================
// Multiple Notifications
// =============================================================================
describe('Toast - Multiple Notifications', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.clearAllTimers();
    vi.useRealTimers();
  });

  it('renders all notifications when multiple exist (TO-4)', async () => {
    const { showNotification, getNotifications } = renderToastWithNotifications();

    await showNotification('success', '通知1');
    await showNotification('error', '通知2');
    await showNotification('info', '通知3');

    expect(getNotifications()).toHaveLength(3);
    expect(screen.getByText('通知1')).toBeInTheDocument();
    expect(screen.getByText('通知2')).toBeInTheDocument();
    expect(screen.getByText('通知3')).toBeInTheDocument();
  });
});

// =============================================================================
// Notification Types
// =============================================================================
describe('Toast - Notification Types', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.clearAllTimers();
    vi.useRealTimers();
  });

  it('applies correct class for each notification type (TO-5)', async () => {
    const { showNotification, container } = renderToastWithNotifications();

    await showNotification('success', 'Success');
    await showNotification('error', 'Error');
    await showNotification('info', 'Info');

    const toasts = container.querySelectorAll('[role="alert"]');
    expect(toasts).toHaveLength(3);

    // 各通知に対応するクラスが適用されていることを確認
    // CSS Modules ではクラス名がハッシュ化されるため、部分一致で検証
    // 例: 'success' → 'success_abc123' のような形式になる
    expect(toasts[0].className).toMatch(/success/);
    expect(toasts[1].className).toMatch(/error/);
    expect(toasts[2].className).toMatch(/info/);
  });
});
