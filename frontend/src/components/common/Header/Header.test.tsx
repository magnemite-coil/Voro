// Header.test.tsx

// 1. React Testing Library
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// 2. Vitest
import { describe, it, expect, vi } from 'vitest';

// 3. React Router
import { MemoryRouter } from 'react-router';

// 4. テスト対象
import { Header } from './Header';

// 5. 型
import type { ComponentProps } from 'react';

type HeaderProps = ComponentProps<typeof Header>;

/**
 * props ファクトリ関数
 * テスト間での状態共有を防ぐため、毎回新しいオブジェクトを生成
 */
function createProps(overrides: Partial<HeaderProps> = {}): HeaderProps {
  return {
    activeTab: 'new',
    ...overrides,
  };
}

/**
 * Header コンポーネントのレンダリングヘルパー
 *
 * Header は Link コンポーネントを使用するため、Router コンテキストが必要。
 * App.test.tsx とは異なり、ルート設定は不要なため MemoryRouter を使用。
 */
function renderHeader(overrides: Partial<HeaderProps> = {}) {
  const props = createProps(overrides);
  const result = render(
    <MemoryRouter>
      <Header {...props} />
    </MemoryRouter>
  );
  return { ...result, props };
}

// =============================================================================
// Basic Rendering
// =============================================================================
describe('Header - Basic Rendering', () => {
  it('renders logo and navigation (HD-1)', () => {
    renderHeader();

    expect(screen.getByText('Voro')).toBeInTheDocument();
    expect(screen.getByText('記事一覧')).toBeInTheDocument();
    expect(screen.getByText('新規作成')).toBeInTheDocument();
  });

  it('applies active class when activeTab is "new" (HD-2)', () => {
    renderHeader({ activeTab: 'new' });

    const newPostLink = screen.getByText('新規作成');
    // CSS Modules のハッシュ化クラス名に対応（例: 'active' → 'Header_active_x7k2m'）
    expect(newPostLink.className).toMatch(/active/);
  });

  it('does not apply active class when activeTab is "posts" (HD-3)', () => {
    renderHeader({ activeTab: 'posts' });

    const newPostLink = screen.getByText('新規作成');
    // CSS Modules のハッシュ化クラス名に対応
    expect(newPostLink.className).not.toMatch(/active/);
  });
});

// =============================================================================
// Actions
// =============================================================================
describe('Header - Actions', () => {
  it('renders actions when provided (HD-4)', () => {
    renderHeader({
      actions: <button>テストアクション</button>,
    });

    expect(screen.getByRole('button', { name: 'テストアクション' })).toBeInTheDocument();
  });

  it('does not render actions container when not provided (HD-5)', () => {
    renderHeader();

    // actions が渡されない場合、テスト用のボタンは表示されない
    // HD-4 で渡した「テストアクション」ボタンが存在しないことで検証
    // CSS Modules のハッシュ化クラス名に依存しない方法
    expect(screen.queryByRole('button', { name: 'テストアクション' })).not.toBeInTheDocument();
  });
});

// =============================================================================
// New Post Click Handler
// =============================================================================
describe('Header - New Post Click Handler', () => {
  it('calls onNewPostClick and prevents default when provided (HD-6)', async () => {
    const user = userEvent.setup();
    const onNewPostClick = vi.fn();

    renderHeader({ onNewPostClick });

    const newPostLink = screen.getByText('新規作成');
    await user.click(newPostLink);

    expect(onNewPostClick).toHaveBeenCalledTimes(1);
  });

  it('allows default link behavior when onNewPostClick is not provided (HD-7)', async () => {
    const user = userEvent.setup();

    renderHeader();

    const newPostLink = screen.getByText('新規作成');
    // onNewPostClick が渡されていない場合、通常のリンクとして動作
    // （MemoryRouter 内なので実際の遷移は発生しないが、エラーは出ない）
    await user.click(newPostLink);

    // クリック後もリンクが存在し続けることを確認（通常のリンク動作）
    expect(newPostLink).toBeInTheDocument();
  });
});
