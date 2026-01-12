// components/common/ConfirmModal/ConfirmModal.test.tsx
import type { ComponentProps } from 'react';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ConfirmModal } from './ConfirmModal';

// コンポーネントのprops型を推論で取得
type ConfirmModalProps = ComponentProps<typeof ConfirmModal>;

/**
 * テスト用のデフォルトpropsを生成する
 * モック関数を毎回新しく生成し、テスト間の状態共有を防ぐ
 */
function createProps(overrides: Partial<ConfirmModalProps> = {}): ConfirmModalProps {
  return {
    isOpen: true,
    title: 'テストタイトル',
    message: 'テストメッセージ',
    onConfirm: vi.fn(),
    onCancel: vi.fn(),
    ...overrides,
  };
}

/**
 * ConfirmModal をレンダリングするヘルパー関数
 */
function renderConfirmModal(overrides: Partial<ConfirmModalProps> = {}) {
  const props = createProps(overrides);
  const result = render(<ConfirmModal {...props} />);
  return {
    ...result,
    props,
  };
}

// =============================================================================
// Phase 1: 基本レンダリング（CM-1〜CM-4）
// =============================================================================
describe('ConfirmModal - Basic Rendering', () => {
  it('does not render when isOpen is false (CM-1)', () => {
    const props = createProps({ isOpen: false });
    render(<ConfirmModal {...props} />);

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByText(props.title)).not.toBeInTheDocument();
  });

  it('renders when isOpen is true (CM-2)', () => {
    const { props } = renderConfirmModal();

    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByText(props.title)).toBeInTheDocument();
    expect(screen.getByText(props.message)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '離れる' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'キャンセル' })).toBeInTheDocument();
  });

  it('displays custom labels (CM-3)', () => {
    renderConfirmModal({
      confirmLabel: '削除する',
      cancelLabel: '戻る',
    });

    expect(screen.getByRole('button', { name: '削除する' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '戻る' })).toBeInTheDocument();
  });

  it('displays default labels (CM-4)', () => {
    renderConfirmModal();

    expect(screen.getByRole('button', { name: '離れる' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'キャンセル' })).toBeInTheDocument();
  });
});

// =============================================================================
// Phase 2: ボタン操作（CM-5〜CM-7, CM-7b）
// =============================================================================
describe('ConfirmModal - Button Actions', () => {
  it('calls onConfirm when confirm button is clicked (CM-5)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal();

    await user.click(screen.getByRole('button', { name: '離れる' }));

    expect(props.onConfirm).toHaveBeenCalledTimes(1);
    expect(props.onCancel).not.toHaveBeenCalled();
  });

  it('calls onCancel when cancel button is clicked (CM-6)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal();

    await user.click(screen.getByRole('button', { name: 'キャンセル' }));

    expect(props.onCancel).toHaveBeenCalledTimes(1);
    expect(props.onConfirm).not.toHaveBeenCalled();
  });

  it('focuses cancel button when modal opens (CM-7)', async () => {
    // Arrange: 最初は閉じた状態でレンダリング
    const props = createProps({ isOpen: false });
    const { rerender } = render(<ConfirmModal {...props} />);

    // Act: モーダルを開く
    rerender(<ConfirmModal {...props} isOpen={true} />);

    // Assert: キャンセルボタンにフォーカスが当たる
    await waitFor(() => {
      const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
      expect(document.activeElement).toBe(cancelButton);
    });
  });

  it('focuses cancel button on initial mount with isOpen true (CM-7b)', async () => {
    // Arrange & Act: isOpen: true で直接マウント
    const props = createProps({ isOpen: true });
    render(<ConfirmModal {...props} />);

    // Assert: キャンセルボタンにフォーカスが当たる
    await waitFor(() => {
      const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
      expect(document.activeElement).toBe(cancelButton);
    });
  });
});

// =============================================================================
// Phase 4: オーバーレイ操作（CM-12〜CM-13）
// =============================================================================
describe('ConfirmModal - Overlay Actions', () => {
  it('calls onCancel when overlay is clicked (CM-12)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal();

    // dialog の親要素がオーバーレイ
    const dialog = screen.getByRole('dialog');
    const overlay = dialog.parentElement!;
    await user.click(overlay);

    expect(props.onCancel).toHaveBeenCalledTimes(1);
    expect(props.onConfirm).not.toHaveBeenCalled();
  });

  it('does not propagate click from modal to overlay (CM-13)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal();

    // モーダル本体（role="dialog"）をクリック
    const dialog = screen.getByRole('dialog');
    await user.click(dialog);

    // どちらのコールバックも呼ばれない
    expect(props.onCancel).not.toHaveBeenCalled();
    expect(props.onConfirm).not.toHaveBeenCalled();
  });
});

// =============================================================================
// Phase 3: キーボード操作（CM-8〜CM-11, CM-19）
// =============================================================================
describe('ConfirmModal - Keyboard Actions', () => {
  it('calls onCancel when Escape is pressed (CM-8)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal();

    await user.keyboard('{Escape}');

    expect(props.onCancel).toHaveBeenCalledTimes(1);
    expect(props.onConfirm).not.toHaveBeenCalled();
  });

  it('keydown handler ignores keys other than Escape and Tab (CM-11)', () => {
    const { props } = renderConfirmModal();

    // document レベルで keydown イベントを発火
    fireEvent.keyDown(document, { key: 'Enter' });
    fireEvent.keyDown(document, { key: 'a' });
    fireEvent.keyDown(document, { key: 'ArrowDown' });
    fireEvent.keyDown(document, { key: ' ' });

    expect(props.onConfirm).not.toHaveBeenCalled();
    expect(props.onCancel).not.toHaveBeenCalled();
  });

  it('removes keyboard listener when modal closes (CM-19)', async () => {
    const user = userEvent.setup();
    const props = createProps({ isOpen: true });
    const { rerender } = render(<ConfirmModal {...props} />);

    // モーダルを閉じる
    rerender(<ConfirmModal {...props} isOpen={false} />);

    // Escape キーを押す
    await user.keyboard('{Escape}');

    // onCancel が呼ばれていないことを確認
    expect(props.onCancel).not.toHaveBeenCalled();
  });
});

// =============================================================================
// Phase 3: フォーカストラップ（CM-9〜CM-10）
// =============================================================================
describe('ConfirmModal - Focus Trap', () => {
  let dummyButton: HTMLButtonElement;

  beforeEach(() => {
    // モーダル外にフォーカス可能なダミー要素を配置
    dummyButton = document.createElement('button');
    dummyButton.textContent = 'Outside Button';
    dummyButton.setAttribute('data-testid', 'outside-button');
    document.body.appendChild(dummyButton);
  });

  afterEach(() => {
    // クリーンアップ: ダミー要素を削除
    if (dummyButton && document.body.contains(dummyButton)) {
      document.body.removeChild(dummyButton);
    }
  });

  it('traps focus - Tab from last to first element (CM-9)', async () => {
    const user = userEvent.setup();
    renderConfirmModal();

    // Arrange: 確認ボタン（最後の要素）に明示的にフォーカスを置く
    const confirmButton = screen.getByRole('button', { name: '離れる' });
    confirmButton.focus();
    expect(document.activeElement).toBe(confirmButton);

    // Act: Tab キーを押す
    await user.tab();

    // Assert: キャンセルボタン（最初の要素）にフォーカスが移動
    const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
    expect(document.activeElement).toBe(cancelButton);

    // 追加検証: モーダル外のボタンにフォーカスが移動していないこと
    expect(document.activeElement).not.toBe(dummyButton);
  });

  it('traps focus - Shift+Tab from first to last element (CM-10)', async () => {
    const user = userEvent.setup();
    renderConfirmModal();

    // Arrange: キャンセルボタン（最初の要素）に明示的にフォーカスを置く
    const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
    cancelButton.focus();
    expect(document.activeElement).toBe(cancelButton);

    // Act: Shift+Tab キーを押す
    await user.tab({ shift: true });

    // Assert: 確認ボタン（最後の要素）にフォーカスが移動
    const confirmButton = screen.getByRole('button', { name: '離れる' });
    expect(document.activeElement).toBe(confirmButton);

    // 追加検証: モーダル外のボタンにフォーカスが移動していないこと
    expect(document.activeElement).not.toBe(dummyButton);
  });
});

// =============================================================================
// Phase 6: アクセシビリティ（CM-16〜CM-18）
// =============================================================================
describe('ConfirmModal - Accessibility', () => {
  it('has role="dialog" (CM-16)', () => {
    renderConfirmModal();

    const dialog = screen.getByRole('dialog');
    expect(dialog).toBeInTheDocument();
  });

  it('has aria-modal="true" (CM-17)', () => {
    renderConfirmModal();

    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveAttribute('aria-modal', 'true');
  });

  it('has aria-labelledby and aria-describedby correctly linked (CM-18)', () => {
    renderConfirmModal({
      title: 'テストタイトル',
      message: 'テストメッセージ',
    });

    const dialog = screen.getByRole('dialog');

    // aria-labelledby の検証
    expect(dialog).toHaveAttribute('aria-labelledby', 'confirm-modal-title');
    const titleElement = document.getElementById('confirm-modal-title');
    expect(titleElement).toBeInTheDocument();
    expect(titleElement).toHaveTextContent('テストタイトル');

    // aria-describedby の検証
    expect(dialog).toHaveAttribute('aria-describedby', 'confirm-modal-message');
    const messageElement = document.getElementById('confirm-modal-message');
    expect(messageElement).toBeInTheDocument();
    expect(messageElement).toHaveTextContent('テストメッセージ');
  });
});

// =============================================================================
// Phase 5a: isConfirmLoading（CM-LOAD-1〜CM-LOAD-5）
// =============================================================================
describe('ConfirmModal - Loading State', () => {
  it('shows spinner on confirm button when isConfirmLoading is true (CM-LOAD-1)', () => {
    renderConfirmModal({ isConfirmLoading: true });

    // Button コンポーネントの isLoading=true により、Spinner が表示される
    // Spinner は aria-label="読み込み中" を持つ span 要素
    const spinner = screen.getByLabelText('読み込み中');
    expect(spinner).toBeInTheDocument();
  });

  it('disables both buttons when isConfirmLoading is true (CM-LOAD-2)', () => {
    renderConfirmModal({ isConfirmLoading: true });

    // キャンセルボタンが disabled
    const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
    expect(cancelButton).toBeDisabled();

    // 確認ボタンも disabled（isLoading=true により、ボタン名は「読み込み中」になる）
    const confirmButton = screen.getByRole('button', { name: '読み込み中' });
    expect(confirmButton).toBeDisabled();
  });

  it('does not call onCancel when Escape is pressed during loading (CM-LOAD-3)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal({ isConfirmLoading: true });

    await user.keyboard('{Escape}');

    expect(props.onCancel).not.toHaveBeenCalled();
  });

  it('does not call onCancel when overlay is clicked during loading (CM-LOAD-4)', async () => {
    const user = userEvent.setup();
    const { props } = renderConfirmModal({ isConfirmLoading: true });

    const dialog = screen.getByRole('dialog');
    const overlay = dialog.parentElement!;
    await user.click(overlay);

    expect(props.onCancel).not.toHaveBeenCalled();
  });

  it('has backward compatibility when isConfirmLoading is not specified (CM-LOAD-5)', () => {
    // isConfirmLoading を指定しない場合、デフォルトで false として動作
    renderConfirmModal();

    const cancelButton = screen.getByRole('button', { name: 'キャンセル' });
    const confirmButton = screen.getByRole('button', { name: '離れる' });

    // 両方のボタンが有効
    expect(cancelButton).not.toBeDisabled();
    expect(confirmButton).not.toBeDisabled();

    // Spinner が表示されていない
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });
});

// =============================================================================
// Phase 5: スクロールロック（CM-14〜CM-15, CM-20）
// =============================================================================
describe('ConfirmModal - Scroll Lock', () => {
  // 元の window.scrollTo を保存
  const originalScrollTo = window.scrollTo;
  // 元の scrollY のプロパティ記述子を保存
  const originalScrollYDescriptor = Object.getOwnPropertyDescriptor(window, 'scrollY');

  beforeEach(() => {
    // 各テスト前に scrollTo をモック化
    window.scrollTo = vi.fn();
    // document.body スタイルをリセット
    document.body.style.overflow = '';
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.width = '';
  });

  afterEach(() => {
    // 元の scrollTo を復元
    window.scrollTo = originalScrollTo;
    // 元の scrollY を復元
    if (originalScrollYDescriptor) {
      Object.defineProperty(window, 'scrollY', originalScrollYDescriptor);
    }
  });

  it('locks scroll when modal opens (CM-14)', () => {
    // Arrange: スクロール位置を設定
    Object.defineProperty(window, 'scrollY', {
      value: 120,
      writable: true,
      configurable: true,
    });

    // Act: モーダルを開く
    const props = createProps({ isOpen: true });
    render(<ConfirmModal {...props} />);

    // Assert: すべてのスタイルが正しく設定される
    expect(document.body.style.overflow).toBe('hidden');
    expect(document.body.style.position).toBe('fixed');
    expect(document.body.style.top).toBe('-120px');
    expect(document.body.style.width).toBe('100%');

    // Assert: スクロールロック適用時には scrollTo は呼ばれない
    expect(window.scrollTo).not.toHaveBeenCalled();
  });

  it('restores scroll position when modal closes (CM-15)', () => {
    // Arrange: スクロール位置を設定
    Object.defineProperty(window, 'scrollY', {
      value: 120,
      writable: true,
      configurable: true,
    });

    const props = createProps({ isOpen: true });
    const { rerender } = render(<ConfirmModal {...props} />);

    // スクロールロックが適用されていることを確認
    expect(document.body.style.overflow).toBe('hidden');
    expect(document.body.style.top).toBe('-120px');

    // Act: モーダルを閉じる
    rerender(<ConfirmModal {...props} isOpen={false} />);

    // Assert: すべてのスタイルが復元される
    expect(document.body.style.overflow).toBe('');
    expect(document.body.style.position).toBe('');
    expect(document.body.style.top).toBe('');
    expect(document.body.style.width).toBe('');

    // Assert: 正しい座標で scrollTo が呼ばれる
    expect(window.scrollTo).toHaveBeenCalledWith(0, 120);
  });

  it('does not apply scroll lock when isOpen is false (CM-20)', () => {
    // Arrange: document.body のスタイルが初期状態であることを確認
    expect(document.body.style.overflow).toBe('');
    expect(document.body.style.position).toBe('');
    expect(document.body.style.top).toBe('');
    expect(document.body.style.width).toBe('');

    // Act: isOpen: false で初期マウント
    const props = createProps({ isOpen: false });
    render(<ConfirmModal {...props} />);

    // Assert: スタイルが変更されていないこと
    expect(document.body.style.overflow).toBe('');
    expect(document.body.style.position).toBe('');
    expect(document.body.style.top).toBe('');
    expect(document.body.style.width).toBe('');

    // Assert: scrollTo が呼ばれていないこと
    expect(window.scrollTo).not.toHaveBeenCalled();
  });
});
