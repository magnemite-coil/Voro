// hooks/useNavigationBlocker.test.tsx

// =============================================================================
// Import 文
// =============================================================================

// React（StateToggleComponent で使用）
import { useState } from 'react';

// Testing Library
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Vitest
import { describe, it, expect } from 'vitest';

// React Router（Data Router API）
import { createMemoryRouter, RouterProvider, Link } from 'react-router';

// テスト対象
import { useNavigationBlocker } from './useNavigationBlocker';

// =============================================================================
// テストヘルパー
// =============================================================================

/**
 * useNavigationBlocker をテストするためのコンポーネント
 * ルーティング環境内でhookを使用し、状態を外部に公開
 */
interface TestComponentProps {
  isDirty: boolean;
  skipBlock?: boolean;
}

function TestComponent({ isDirty, skipBlock }: TestComponentProps) {
  const { isBlocked, proceed, reset } = useNavigationBlocker(isDirty, skipBlock);
  return (
    <div>
      <span data-testid="isBlocked">{String(isBlocked)}</span>
      <button data-testid="proceed" onClick={proceed}>
        Proceed
      </button>
      <button data-testid="reset" onClick={reset}>
        Reset
      </button>
      <Link data-testid="navigate" to="/other">
        Navigate
      </Link>
    </div>
  );
}

/**
 * isDirty/skipBlock を内部 state で管理し、ボタンで切り替え可能にする
 * NB-4, NB-5, NB-10, NB-11 の状態変更テストに使用
 */
interface StateToggleComponentProps {
  initialIsDirty: boolean;
  initialSkipBlock?: boolean;
}

function StateToggleComponent({
  initialIsDirty,
  initialSkipBlock = false,
}: StateToggleComponentProps) {
  const [isDirty, setIsDirty] = useState(initialIsDirty);
  const [skipBlock, setSkipBlock] = useState(initialSkipBlock);

  const { isBlocked, proceed, reset } = useNavigationBlocker(isDirty, skipBlock);

  return (
    <div>
      <span data-testid="isBlocked">{String(isBlocked)}</span>
      <span data-testid="isDirty">{String(isDirty)}</span>
      <span data-testid="skipBlock">{String(skipBlock)}</span>

      {/* 状態切り替えボタン */}
      <button data-testid="toggle-dirty" onClick={() => setIsDirty((v) => !v)}>
        Toggle Dirty
      </button>
      <button data-testid="toggle-skip" onClick={() => setSkipBlock((v) => !v)}>
        Toggle Skip
      </button>

      {/* hook 操作ボタン */}
      <button data-testid="proceed" onClick={proceed}>
        Proceed
      </button>
      <button data-testid="reset" onClick={reset}>
        Reset
      </button>
      <Link data-testid="navigate" to="/other">
        Navigate
      </Link>
    </div>
  );
}

/**
 * 静的な isDirty/skipBlock でテスト（NB-1〜NB-3, NB-6〜NB-9 用）
 */
function renderWithRouter(isDirty: boolean, skipBlock = false) {
  const router = createMemoryRouter(
    [
      {
        path: '/current',
        element: <TestComponent isDirty={isDirty} skipBlock={skipBlock} />,
      },
      {
        path: '/other',
        element: <div data-testid="other-page">Other Page</div>,
      },
    ],
    { initialEntries: ['/current'] }
  );

  const result = render(<RouterProvider router={router} />);

  return { router, ...result };
}

/**
 * 状態変更テスト用（NB-4, NB-5, NB-10, NB-11 用）
 */
function renderWithStateToggle(initialIsDirty: boolean, initialSkipBlock = false) {
  const router = createMemoryRouter(
    [
      {
        path: '/current',
        element: (
          <StateToggleComponent
            initialIsDirty={initialIsDirty}
            initialSkipBlock={initialSkipBlock}
          />
        ),
      },
      {
        path: '/other',
        element: <div data-testid="other-page">Other Page</div>,
      },
    ],
    { initialEntries: ['/current'] }
  );

  const result = render(<RouterProvider router={router} />);

  return { router, ...result };
}

// =============================================================================
// Phase 1: 初期状態（NB-1〜NB-2）
// =============================================================================
describe('useNavigationBlocker - Initial State', () => {
  it('does not block when isDirty is false (NB-1)', async () => {
    // Arrange: isDirty=false でレンダリング
    renderWithRouter(false);

    // Assert: 初期状態で isBlocked=false
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');

    // Act: 別パスへナビゲーション
    await userEvent.click(screen.getByTestId('navigate'));

    // Assert: ブロックされずに別ページへ遷移
    await waitFor(() => {
      expect(screen.getByTestId('other-page')).toBeInTheDocument();
    });
  });

  it('does not block navigation when skipBlock is true (NB-2)', async () => {
    // Arrange: isDirty=true, skipBlock=true でレンダリング
    renderWithRouter(true, true);

    // 初期状態: isBlocked=false
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');

    // Act: 別パスへナビゲーション
    await userEvent.click(screen.getByTestId('navigate'));

    // Assert: ブロックされずに別ページへ遷移
    await waitFor(() => {
      expect(screen.getByTestId('other-page')).toBeInTheDocument();
    });
  });
});

// =============================================================================
// Phase 2: ブロック動作（NB-3〜NB-5）
// =============================================================================
describe('useNavigationBlocker - Blocking Behavior', () => {
  it('blocks navigation when isDirty is true (NB-3)', async () => {
    // Arrange: isDirty=true でレンダリング
    renderWithRouter(true);

    // 初期状態: isBlocked=false（まだナビゲーションしていない）
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');

    // Act: 別パスへナビゲーション
    await userEvent.click(screen.getByTestId('navigate'));

    // Assert: ブロックされる
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });
    // 遷移先ページは表示されない
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();
  });

  it('blocks after isDirty changes from false to true (NB-4)', async () => {
    // Arrange: isDirty=false で開始
    renderWithStateToggle(false);

    // 初期状態: isBlocked=false, isDirty=false
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    expect(screen.getByTestId('isDirty')).toHaveTextContent('false');

    // Act 1: isDirty を true に変更
    await userEvent.click(screen.getByTestId('toggle-dirty'));
    expect(screen.getByTestId('isDirty')).toHaveTextContent('true');

    // Act 2: 別パスへナビゲーション
    await userEvent.click(screen.getByTestId('navigate'));

    // Assert: ブロックされる
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });
    // 遷移先ページは表示されない
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();
  });

  it('does not block after isDirty changes from true to false (NB-5)', async () => {
    // Arrange: isDirty=true で開始
    renderWithStateToggle(true);

    // Act 1: 別パスへナビゲーション → ブロックされる
    await userEvent.click(screen.getByTestId('navigate'));
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });

    // Act 2: reset() でブロックを解除
    await userEvent.click(screen.getByTestId('reset'));
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    });

    // Act 3: isDirty を false に変更
    await userEvent.click(screen.getByTestId('toggle-dirty'));
    expect(screen.getByTestId('isDirty')).toHaveTextContent('false');

    // Act 4: 再度ナビゲーション → ブロックされない
    await userEvent.click(screen.getByTestId('navigate'));
    await waitFor(() => {
      expect(screen.getByTestId('other-page')).toBeInTheDocument();
    });
  });
});

// =============================================================================
// Phase 3: proceed() と reset()（NB-6〜NB-9）
// =============================================================================
describe('useNavigationBlocker - Proceed and Reset', () => {
  it('proceeds with navigation when proceed() is called while blocked (NB-6)', async () => {
    // Arrange: isDirty=true でレンダリング
    renderWithRouter(true);

    // Act 1: 別パスへナビゲーション → ブロックされる
    await userEvent.click(screen.getByTestId('navigate'));
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });

    // Act 2: proceed() を呼び出し
    await userEvent.click(screen.getByTestId('proceed'));

    // Assert: ナビゲーションが進み、別ページに遷移
    await waitFor(() => {
      expect(screen.getByTestId('other-page')).toBeInTheDocument();
    });
  });

  it('cancels navigation when reset() is called while blocked (NB-7)', async () => {
    // Arrange: isDirty=true でレンダリング
    renderWithRouter(true);

    // Act 1: 別パスへナビゲーション → ブロックされる
    await userEvent.click(screen.getByTestId('navigate'));
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });

    // Act 2: reset() を呼び出し
    await userEvent.click(screen.getByTestId('reset'));

    // Assert: ブロックが解除され、元のページに留まる
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    });
    // other-page が表示されていないことを確認
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();
    // TestComponent が引き続き表示されている
    expect(screen.getByTestId('proceed')).toBeInTheDocument();
  });

  it('does nothing when proceed() is called while not blocked (NB-8)', async () => {
    // Arrange: isDirty=false でレンダリング（非ブロック状態）
    renderWithRouter(false);

    // 初期状態: isBlocked=false
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');

    // Act: 非ブロック中に proceed() を呼び出し
    await userEvent.click(screen.getByTestId('proceed'));

    // Assert: 何も起きない
    // 1. エラーが発生しない（テストがここまで到達すればOK）
    // 2. isBlocked は false のまま
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    // 3. 遷移しない（other-page が表示されない）
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();
    // 4. 元のページに留まっている
    expect(screen.getByTestId('proceed')).toBeInTheDocument();
  });

  it('does nothing when reset() is called while not blocked (NB-9)', async () => {
    // Arrange: isDirty=false でレンダリング（非ブロック状態）
    renderWithRouter(false);

    // 初期状態: isBlocked=false
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');

    // Act: 非ブロック中に reset() を呼び出し
    await userEvent.click(screen.getByTestId('reset'));

    // Assert: 何も起きない
    // 1. エラーが発生しない（テストがここまで到達すればOK）
    // 2. isBlocked は false のまま
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    // 3. 遷移しない（other-page が表示されない）
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();
    // 4. 元のページに留まっている
    expect(screen.getByTestId('reset')).toBeInTheDocument();
  });
});

// =============================================================================
// Phase 4: エッジケース（NB-10〜NB-11）
// =============================================================================
describe('useNavigationBlocker - Edge Cases', () => {
  it('proceed and reset remain stable after state change (NB-10)', async () => {
    // Arrange: 初期状態
    renderWithStateToggle(false);

    // Act 1: 状態変更で再レンダーを発生させる
    await userEvent.click(screen.getByTestId('toggle-dirty'));
    expect(screen.getByTestId('isDirty')).toHaveTextContent('true');

    // Act 2: 再レンダー後に proceed/reset を呼び出し（クラッシュしないことを確認）
    // 非ブロック状態なので動作は NB-8/NB-9 と同様だが、再レンダー後の安定性を検証
    await userEvent.click(screen.getByTestId('proceed'));
    await userEvent.click(screen.getByTestId('reset'));

    // Assert: コンポーネントがクラッシュせず、状態が維持されている
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('false');
    expect(screen.getByTestId('isDirty')).toHaveTextContent('true');
  });

  it('maintains blocked state when skipBlock changes to true while blocked (NB-11)', async () => {
    // Arrange: isDirty=true, skipBlock=false で開始
    renderWithStateToggle(true, false);

    // Act 1: 別パスへナビゲーション → ブロックされる
    await userEvent.click(screen.getByTestId('navigate'));
    await waitFor(() => {
      expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    });

    // Act 2: skipBlock を true に変更
    await userEvent.click(screen.getByTestId('toggle-skip'));
    expect(screen.getByTestId('skipBlock')).toHaveTextContent('true');

    // Assert: ブロックは維持される（自動的には解除されない）
    expect(screen.getByTestId('isBlocked')).toHaveTextContent('true');
    // 遷移先ページは表示されない
    expect(screen.queryByTestId('other-page')).not.toBeInTheDocument();

    // Act 3: proceed() でブロックを解除すると遷移する
    await userEvent.click(screen.getByTestId('proceed'));
    await waitFor(() => {
      expect(screen.getByTestId('other-page')).toBeInTheDocument();
    });
  });
});
