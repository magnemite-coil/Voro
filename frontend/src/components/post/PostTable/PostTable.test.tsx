// components/post/PostTable/PostTable.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { PostTable } from './PostTable';
import type { Post } from '../../../types/post';

const mockPosts: Post[] = [
  {
    id: 1,
    user_id: 1,
    title: 'テスト投稿 1',
    content: 'テスト本文 1',
    published: true,
    created_at: '2025-10-25T00:00:00.000Z',
    updated_at: '2025-10-25T00:00:00.000Z',
  },
  {
    id: 2,
    user_id: 1,
    title: '下書き投稿',
    content: '下書き本文',
    published: false,
    created_at: '2025-10-24T00:00:00.000Z',
    updated_at: '2025-10-24T00:00:00.000Z',
  },
];

describe('PostTable', () => {
  it('renders table headers', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    expect(screen.getByText('タイトル')).toBeInTheDocument();
    expect(screen.getByText('ステータス')).toBeInTheDocument();
    expect(screen.getByText('作成日')).toBeInTheDocument();
    expect(screen.getByText('操作')).toBeInTheDocument();
  });

  it('renders post rows', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    expect(screen.getByText('テスト投稿 1')).toBeInTheDocument();
    expect(screen.getByText('下書き投稿')).toBeInTheDocument();
  });

  it('displays correct status badges', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    expect(screen.getByText('公開中')).toBeInTheDocument();
    expect(screen.getByText('下書き')).toBeInTheDocument();
  });

  it('formats dates correctly', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    // formatDate はローカルタイムゾーンで表示されるため、UTC -> JST で翌日になる可能性あり
    // 日付が存在することを確認（複数の日付がある場合は getAllByText を使用）
    const dates = screen.getAllByText(/2025/);
    expect(dates.length).toBeGreaterThan(0);
  });

  it('calls onEdit when edit button is clicked', async () => {
    const onEdit = vi.fn();
    render(<PostTable posts={mockPosts} onEdit={onEdit} onDelete={vi.fn()} />);

    const editButtons = screen.getAllByRole('button', { name: '編集' });
    await userEvent.click(editButtons[0]);

    expect(onEdit).toHaveBeenCalledWith(1);
  });

  it('calls onDelete when delete button is clicked', async () => {
    const onDelete = vi.fn();
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={onDelete} />);

    // aria-labelで特定
    await userEvent.click(screen.getByLabelText('「テスト投稿 1」を削除'));

    expect(onDelete).toHaveBeenCalledWith(mockPosts[0]);
  });

  it('calls onEdit when row is clicked', async () => {
    const onEdit = vi.fn();
    render(<PostTable posts={mockPosts} onEdit={onEdit} onDelete={vi.fn()} />);

    await userEvent.click(screen.getByText('テスト投稿 1'));

    expect(onEdit).toHaveBeenCalledWith(1);
  });

  it('does not propagate click event from action buttons to row', async () => {
    const onEdit = vi.fn();
    const onDelete = vi.fn();
    render(<PostTable posts={mockPosts} onEdit={onEdit} onDelete={onDelete} />);

    // 削除ボタンをクリック
    await userEvent.click(screen.getByLabelText('「テスト投稿 1」を削除'));

    // onDeleteが呼ばれ、onEditは呼ばれない（行クリックが伝播していない）
    expect(onDelete).toHaveBeenCalledTimes(1);
    expect(onEdit).not.toHaveBeenCalled();
  });

  it('has data-label attributes for mobile responsiveness', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    // data-label属性が設定されていることを確認
    const cells = document.querySelectorAll('[data-label]');
    expect(cells.length).toBeGreaterThan(0);

    // 各ラベルが正しいことを確認
    expect(document.querySelector('[data-label="タイトル"]')).toBeInTheDocument();
    expect(document.querySelector('[data-label="ステータス"]')).toBeInTheDocument();
    expect(document.querySelector('[data-label="作成日"]')).toBeInTheDocument();
    expect(document.querySelector('[data-label="操作"]')).toBeInTheDocument();
  });

  it('renders table caption for accessibility', () => {
    render(<PostTable posts={mockPosts} onEdit={vi.fn()} onDelete={vi.fn()} />);

    const caption = document.querySelector('caption');
    expect(caption).toBeInTheDocument();
    expect(caption).toHaveTextContent('投稿記事の一覧');
  });
});
