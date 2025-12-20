import { render, screen, renderHook, act } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  NotificationProvider,
  useNotification,
  type Notification,
} from './NotificationContext';

/**
 * NotificationProvider でラップしてレンダリング
 * showNotification / removeNotification / notifications を返す
 *
 * 重要: notifications はスナップショット変数で管理し、
 * 各レンダーで最新値に更新する（クロージャ問題を回避）
 */
function renderWithNotification() {
  let showFn!: (type: Notification['type'], message: string) => void;
  let removeFn!: (id: string) => void;

  // スナップショット変数: 各レンダーで最新の notifications を保持
  // クロージャで古い値をキャプチャする問題を回避
  let notificationsSnapshot: Notification[] = [];

  const TestConsumer = () => {
    const { showNotification, removeNotification, notifications } = useNotification();

    // 関数参照を外部に公開（テスト用パターン）
    showFn = showNotification;
    removeFn = removeNotification;

    // 各レンダーでスナップショットを更新
    notificationsSnapshot = notifications;

    return (
      <div>
        <span data-testid="count">{notifications.length}</span>
        {notifications.map((n) => (
          <div key={n.id} data-testid={`notification-${n.id}`}>
            <span data-testid={`type-${n.id}`}>{n.type}</span>
            <span data-testid={`message-${n.id}`}>{n.message}</span>
          </div>
        ))}
      </div>
    );
  };

  const result = render(
    <NotificationProvider>
      <TestConsumer />
    </NotificationProvider>
  );

  return {
    ...result,
    // await act(async () => { ... }) パターンで統一
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
    // スナップショットから最新値を返す
    getNotifications: () => notificationsSnapshot,
  };
}

describe('NotificationContext', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    // 残タイマーを明示的にクリア（次のテストへの持ち越しを防止）
    vi.clearAllTimers();
    // リアルタイマーに戻す
    vi.useRealTimers();
  });

  describe('Phase 1: 初期状態と useNotification フック', () => {
    it('throws error when useNotification is used outside NotificationProvider (NC-1)', () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      try {
        expect(() => {
          renderHook(() => useNotification());
        }).toThrow('useNotification must be used within NotificationProvider');
      } finally {
        // テスト失敗時も確実にスパイを復元（後続テストへの漏れを防止）
        consoleSpy.mockRestore();
      }
    });

    it('has empty notifications array initially (NC-2)', () => {
      const { getNotifications } = renderWithNotification();

      expect(getNotifications()).toEqual([]);
      expect(screen.getByTestId('count')).toHaveTextContent('0');
    });

    it('provides showNotification and removeNotification functions (NC-3)', () => {
      // 注意: NotificationContextValue は内部型のため、直接参照しない
      let contextValue: ReturnType<typeof useNotification> | null = null;

      const TestConsumer = () => {
        contextValue = useNotification();
        return null;
      };

      render(
        <NotificationProvider>
          <TestConsumer />
        </NotificationProvider>
      );

      expect(contextValue).not.toBeNull();
      expect(typeof contextValue!.showNotification).toBe('function');
      expect(typeof contextValue!.removeNotification).toBe('function');
      expect(Array.isArray(contextValue!.notifications)).toBe(true);
    });

    it('maintains stable function references across re-renders (NC-3A)', async () => {
      // 関数参照を記録するための変数
      const showFnRefs: Array<(type: Notification['type'], message: string) => void> = [];
      const removeFnRefs: Array<(id: string) => void> = [];
      let renderCount = 0;

      const TestConsumer = () => {
        const { showNotification, removeNotification } = useNotification();

        // 各レンダーで関数参照を記録
        renderCount++;
        showFnRefs.push(showNotification);
        removeFnRefs.push(removeNotification);

        return <button onClick={() => showNotification('info', 'trigger re-render')}>trigger</button>;
      };

      render(
        <NotificationProvider>
          <TestConsumer />
        </NotificationProvider>
      );

      // 初回レンダー
      expect(renderCount).toBe(1);

      // 通知を追加して再レンダーを発生させる
      const button = screen.getByRole('button');
      await act(async () => {
        button.click();
      });

      // 再レンダーが発生したことを確認（2回以上）
      expect(renderCount).toBeGreaterThanOrEqual(2);

      // 参照配列に複数の要素があることを確認（forループが実行されることを保証）
      expect(showFnRefs.length).toBeGreaterThanOrEqual(2);
      expect(removeFnRefs.length).toBeGreaterThanOrEqual(2);

      // 全てのレンダーで同一参照であることを確認
      for (let i = 1; i < showFnRefs.length; i++) {
        expect(showFnRefs[i]).toBe(showFnRefs[0]);
        expect(removeFnRefs[i]).toBe(removeFnRefs[0]);
      }
    });
  });

  describe('Phase 2: showNotification - 通知追加', () => {
    it('adds notification when showNotification is called (NC-4)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      expect(getNotifications()).toHaveLength(0);

      await showNotification('success', 'テスト成功');

      expect(getNotifications()).toHaveLength(1);
      expect(screen.getByTestId('count')).toHaveTextContent('1');
    });

    it('sets id, type, message correctly on notification (NC-5)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('error', 'エラーが発生しました');

      const notifications = getNotifications();
      expect(notifications).toHaveLength(1);
      expect(notifications[0].id).toBeDefined();
      expect(typeof notifications[0].id).toBe('string');
      expect(notifications[0].id.length).toBeGreaterThan(0);
      expect(notifications[0].type).toBe('error');
      expect(notifications[0].message).toBe('エラーが発生しました');
    });

    it('accumulates multiple notifications in array (NC-6)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');
      await showNotification('error', '通知2');
      await showNotification('info', '通知3');

      const notifications = getNotifications();
      expect(notifications).toHaveLength(3);
      expect(notifications[0].message).toBe('通知1');
      expect(notifications[1].message).toBe('通知2');
      expect(notifications[2].message).toBe('通知3');
    });

    it('assigns unique id to each notification (NC-7)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');
      await showNotification('success', '通知2');

      const notifications = getNotifications();
      expect(notifications[0].id).not.toBe(notifications[1].id);
    });

    it('supports all notification types: success, error, info (NC-8)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', 'Success');
      await showNotification('error', 'Error');
      await showNotification('info', 'Info');

      const notifications = getNotifications();
      expect(notifications[0].type).toBe('success');
      expect(notifications[1].type).toBe('error');
      expect(notifications[2].type).toBe('info');
    });
  });

  describe('Phase 3: removeNotification - 通知削除', () => {
    it('removes notification by id (NC-9)', async () => {
      const { showNotification, removeNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');
      await showNotification('error', '通知2');

      const notifications = getNotifications();
      const idToRemove = notifications[0].id;

      await removeNotification(idToRemove);

      const remaining = getNotifications();
      expect(remaining).toHaveLength(1);
      expect(remaining[0].message).toBe('通知2');
    });

    it('clears timer when notification is manually removed (NC-10)', async () => {
      const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout');

      try {
        const { showNotification, removeNotification, getNotifications } = renderWithNotification();

        // スパイをリセット（renderWithNotification 内での呼び出しを除外）
        clearTimeoutSpy.mockClear();

        await showNotification('success', 'テスト');
        expect(getNotifications()).toHaveLength(1);

        const id = getNotifications()[0].id;
        await removeNotification(id);

        // clearTimeout が呼ばれたことを確認（タイマーがクリアされた証拠）
        expect(clearTimeoutSpy).toHaveBeenCalled();

        // 通知が削除されたことを確認
        expect(getNotifications()).toHaveLength(0);
      } finally {
        // テスト失敗時も確実にスパイを復元（後続テストへの漏れを防止）
        clearTimeoutSpy.mockRestore();
      }
    });

    it('does not affect other notifications when removing non-existent id (NC-11)', async () => {
      const { showNotification, removeNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');
      await showNotification('error', '通知2');

      await removeNotification('non-existent-id');

      expect(getNotifications()).toHaveLength(2);
    });

    it('does not throw error when removing same id twice (NC-12)', async () => {
      const { showNotification, removeNotification, getNotifications } = renderWithNotification();

      await showNotification('success', 'テスト');
      const id = getNotifications()[0].id;

      // 1回目の削除
      await removeNotification(id);
      expect(getNotifications()).toHaveLength(0);

      // 2回目の削除（エラーが発生すればテストが失敗する）
      await removeNotification(id);

      // 状態が変わっていないことを確認
      expect(getNotifications()).toHaveLength(0);
    });
  });

  describe('Phase 4: 自動消去タイマー', () => {
    it('auto-removes notification after 3 seconds (NC-13)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', 'テスト');
      expect(getNotifications()).toHaveLength(1);

      // 3秒進める
      await act(async () => {
        vi.advanceTimersByTime(3000);
      });

      expect(getNotifications()).toHaveLength(0);
    });

    it('does not remove notification before 3 seconds (NC-14)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', 'テスト');

      // 2.9秒進める（3秒未満）
      await act(async () => {
        vi.advanceTimersByTime(2999);
      });

      expect(getNotifications()).toHaveLength(1);

      // 残り1ms進めると削除される
      await act(async () => {
        vi.advanceTimersByTime(1);
      });

      expect(getNotifications()).toHaveLength(0);
    });

    it('manages multiple notifications with individual timers (NC-15)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');

      // 1秒後に2つ目を追加
      await act(async () => {
        vi.advanceTimersByTime(1000);
      });
      await showNotification('error', '通知2');

      expect(getNotifications()).toHaveLength(2);

      // さらに2秒後（通知1の追加から3秒後）
      await act(async () => {
        vi.advanceTimersByTime(2000);
      });

      // 通知1のみ削除、通知2は残る
      const remaining = getNotifications();
      expect(remaining).toHaveLength(1);
      expect(remaining[0].message).toBe('通知2');

      // さらに1秒後（通知2の追加から3秒後）
      await act(async () => {
        vi.advanceTimersByTime(1000);
      });

      expect(getNotifications()).toHaveLength(0);
    });

    it('continues to work correctly after auto-removal cycles (NC-15A)', async () => {
      const { showNotification, getNotifications } = renderWithNotification();

      // 1つ目の通知を追加
      await showNotification('success', '通知1');
      expect(getNotifications()).toHaveLength(1);

      // 3秒経過で自動消去
      await act(async () => {
        vi.advanceTimersByTime(3000);
      });
      expect(getNotifications()).toHaveLength(0);

      // 新しい通知を追加
      await showNotification('info', '通知2');
      expect(getNotifications()).toHaveLength(1);

      // 3秒経過で自動消去
      await act(async () => {
        vi.advanceTimersByTime(3000);
      });
      expect(getNotifications()).toHaveLength(0);

      // さらに新しい通知を追加して、正常に動作することを確認
      await showNotification('error', '通知3');
      expect(getNotifications()).toHaveLength(1);
      expect(getNotifications()[0].message).toBe('通知3');

      // 3秒経過で自動消去
      await act(async () => {
        vi.advanceTimersByTime(3000);
      });
      expect(getNotifications()).toHaveLength(0);
    });

    it('does not auto-remove after manual removal (NC-16)', async () => {
      const { showNotification, removeNotification, getNotifications } = renderWithNotification();

      await showNotification('success', '通知1');

      // 1秒後に通知2を追加
      await act(async () => {
        vi.advanceTimersByTime(1000);
      });
      await showNotification('error', '通知2');

      const id1 = getNotifications()[0].id;

      // 通知1を手動削除
      await removeNotification(id1);
      expect(getNotifications()).toHaveLength(1);

      // さらに2秒後（元の通知1のタイマーが発火するタイミング = t=3000ms）
      await act(async () => {
        vi.advanceTimersByTime(2000);
      });

      // 通知2はまだ残っている（通知1のタイマーは無効化済み、通知2は t=1000ms に追加されたので t=4000ms まで消えない）
      expect(getNotifications()).toHaveLength(1);
      expect(getNotifications()[0].message).toBe('通知2');
    });

    it('ignores timer callback for already removed notification (NC-17)', async () => {
      // setTimeout のコールバックをキャプチャするためのスパイ
      const setTimeoutSpy = vi.spyOn(global, 'setTimeout');

      try {
        const { showNotification, removeNotification, getNotifications } = renderWithNotification();

        // スパイをリセット（renderWithNotification 内での呼び出しを除外）
        // showNotification 呼び出し直前にリセットすることで、
        // 他のタイマー（RTL/jsdom 内部）との混同を防止
        setTimeoutSpy.mockClear();

        await showNotification('success', 'テスト');
        expect(getNotifications()).toHaveLength(1);

        // setTimeout が呼ばれたことを確認し、コールバックをキャプチャ
        // 注意: 回数は RTL/jsdom 内部で変動し得るため、呼び出し有無のみ検証
        expect(setTimeoutSpy).toHaveBeenCalled();

        // showNotification 呼び出し直後の最後のコールを取得
        // mockClear() 直後に showNotification を呼んでいるため、
        // 最後のコールが確実に showNotification によるものとなる
        // これにより、将来 3000ms の別タイマーが増えても誤キャプチャを防止
        const calls = setTimeoutSpy.mock.calls;
        const timerCall = calls[calls.length - 1];
        expect(timerCall).toBeDefined();
        const timerCallback = timerCall[0] as () => void;

        const id = getNotifications()[0].id;

        // 手動で削除（clearTimeout が呼ばれ、timerIdsRef から id が削除される）
        await removeNotification(id);
        expect(getNotifications()).toHaveLength(0);

        // キャプチャしたコールバックを直接実行
        // 実装: if (!timerIdsRef.current.has(id)) return; ← この true 分岐が実行される
        await act(async () => {
          timerCallback();
        });

        // ガード節により状態は変更されない（0のまま）
        expect(getNotifications()).toHaveLength(0);
      } finally {
        setTimeoutSpy.mockRestore();
      }
    });
  });

  describe('Phase 5: クリーンアップ', () => {
    it('clears all timers on unmount (NC-18)', async () => {
      const clearTimeoutSpy = vi.spyOn(global, 'clearTimeout');
      // mockImplementation なし: 本当のエラーはコンソールに出力され、デバッグが容易になる
      const consoleErrorSpy = vi.spyOn(console, 'error');

      try {
        const { showNotification, getNotifications, unmount } = renderWithNotification();

        // スパイをリセット（初期化時の呼び出しを除外）
        clearTimeoutSpy.mockClear();

        await showNotification('success', '通知1');
        await showNotification('error', '通知2');
        await showNotification('info', '通知3');

        // 3つの通知が追加されたことを確認
        expect(getNotifications()).toHaveLength(3);

        // アンマウント
        unmount();

        // clearTimeout が呼ばれたことを確認（タイマーがクリアされた証拠）
        // 注意: 回数は StrictMode や内部実装で変動し得るため、呼び出し有無のみ検証
        expect(clearTimeoutSpy).toHaveBeenCalled();

        // 残存タイマーの取りこぼし検知:
        // アンマウント後に全タイマーを発火させ、React の警告が出ないことを確認
        await act(async () => {
          vi.runAllTimers();
        });

        // React バージョン間で警告メッセージが変わる可能性があるため、複数パターンに対応
        const isUnmountWarning = (arg: unknown): boolean => {
          if (typeof arg !== 'string') return false;
          return (
            arg.includes('unmounted component') ||
            arg.includes('unmounted') ||
            arg.includes('no longer mounted')
          );
        };

        const reactWarnings = consoleErrorSpy.mock.calls.filter((call) =>
          call.some(isUnmountWarning)
        );
        expect(reactWarnings).toHaveLength(0);
      } finally {
        // テスト失敗時も確実にスパイを復元（後続テストへの漏れを防止）
        clearTimeoutSpy.mockRestore();
        consoleErrorSpy.mockRestore();
      }
    });

    it('does not throw error when unmounting with no notifications (NC-19)', () => {
      const { unmount, getNotifications } = renderWithNotification();

      expect(getNotifications()).toHaveLength(0);

      // エラーなくアンマウントできる
      expect(() => unmount()).not.toThrow();
    });
  });
});
