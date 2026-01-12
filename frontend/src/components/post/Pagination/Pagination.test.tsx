// components/post/Pagination/Pagination.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { Pagination } from './Pagination';

describe('Pagination', () => {
  it('renders page numbers', () => {
    render(
      <Pagination
        currentPage={1}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    expect(screen.getByRole('button', { name: '1' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '2' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '5' })).toBeInTheDocument();
  });

  it('highlights current page', () => {
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    const currentButton = screen.getByRole('button', { name: '3' });
    expect(currentButton).toHaveAttribute('aria-current', 'page');
  });

  it('disables current page button', () => {
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    const currentButton = screen.getByRole('button', { name: '3' });
    expect(currentButton).toBeDisabled();
  });

  it('calls onPageChange when page button is clicked', async () => {
    const onPageChange = vi.fn();
    render(
      <Pagination
        currentPage={1}
        totalPages={5}
        onPageChange={onPageChange}
      />
    );

    await userEvent.click(screen.getByRole('button', { name: '2' }));

    expect(onPageChange).toHaveBeenCalledWith(2);
  });

  it('disables previous button on first page', () => {
    render(
      <Pagination
        currentPage={1}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText('前のページへ')).toBeDisabled();
  });

  it('disables next button on last page', () => {
    render(
      <Pagination
        currentPage={5}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText('次のページへ')).toBeDisabled();
  });

  it('enables navigation buttons when not on boundary pages', () => {
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText('前のページへ')).not.toBeDisabled();
    expect(screen.getByLabelText('次のページへ')).not.toBeDisabled();
  });

  it('navigates to previous page', async () => {
    const onPageChange = vi.fn();
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={onPageChange}
      />
    );

    await userEvent.click(screen.getByLabelText('前のページへ'));

    expect(onPageChange).toHaveBeenCalledWith(2);
  });

  it('navigates to next page', async () => {
    const onPageChange = vi.fn();
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={onPageChange}
      />
    );

    await userEvent.click(screen.getByLabelText('次のページへ'));

    expect(onPageChange).toHaveBeenCalledWith(4);
  });

  it('shows ellipsis for many pages', () => {
    render(
      <Pagination
        currentPage={5}
        totalPages={10}
        onPageChange={vi.fn()}
      />
    );

    // 省略記号が表示されることを確認
    const ellipses = screen.getAllByText('…');
    expect(ellipses.length).toBeGreaterThan(0);
  });

  it('disables all buttons when disabled prop is true', () => {
    render(
      <Pagination
        currentPage={3}
        totalPages={5}
        onPageChange={vi.fn()}
        disabled={true}
      />
    );

    expect(screen.getByLabelText('前のページへ')).toBeDisabled();
    expect(screen.getByLabelText('次のページへ')).toBeDisabled();
    expect(screen.getByRole('button', { name: '2' })).toBeDisabled();
  });

  it('has accessible navigation label', () => {
    render(
      <Pagination
        currentPage={1}
        totalPages={5}
        onPageChange={vi.fn()}
      />
    );

    expect(screen.getByLabelText('ページナビゲーション')).toBeInTheDocument();
  });
});
