// components/post/TitleInput/TitleInput.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { TitleInput } from './TitleInput';

describe('TitleInput', () => {
  it('displays placeholder text', () => {
    render(<TitleInput value="" onChange={() => {}} />);
    expect(screen.getByPlaceholderText('記事のタイトル')).toBeInTheDocument();
  });

  it('displays the value', () => {
    render(<TitleInput value="Test Title" onChange={() => {}} />);
    expect(screen.getByDisplayValue('Test Title')).toBeInTheDocument();
  });

  it('calls onChange when user types', async () => {
    const handleChange = vi.fn();
    render(<TitleInput value="" onChange={handleChange} />);

    const input = screen.getByPlaceholderText('記事のタイトル');
    await userEvent.type(input, 'Test');

    expect(handleChange).toHaveBeenCalledTimes(4); // T, e, s, t
  });

  it('displays error message when error prop is provided', () => {
    render(
      <TitleInput
        value=""
        onChange={() => {}}
        error="Title cannot be empty or whitespace only"
      />
    );
    expect(
      screen.getByText('Title cannot be empty or whitespace only')
    ).toBeInTheDocument();
  });

  it('applies error class when error is present', () => {
    render(
      <TitleInput value="" onChange={() => {}} error="Error message" />
    );
    const input = screen.getByPlaceholderText('記事のタイトル');
    // CSS Modules でクラス名がハッシュ化されるため、部分一致でチェック
    expect(input.className).toMatch(/hasError/);
  });

  it('calls onValidate when input loses focus', async () => {
    const handleValidate = vi.fn();
    render(
      <TitleInput value="" onChange={() => {}} onValidate={handleValidate} />
    );

    const input = screen.getByPlaceholderText('記事のタイトル');
    await userEvent.click(input);
    await userEvent.tab(); // blur

    expect(handleValidate).toHaveBeenCalledTimes(1);
  });

  it('is readonly when isLoading is true', () => {
    render(<TitleInput value="" onChange={() => {}} isLoading={true} />);
    const input = screen.getByPlaceholderText('記事のタイトル');
    expect(input).toHaveAttribute('readonly');
  });

  it('applies loading class when isLoading is true', () => {
    render(<TitleInput value="" onChange={() => {}} isLoading={true} />);
    const input = screen.getByPlaceholderText('記事のタイトル');
    // CSS Modules でクラス名がハッシュ化されるため、部分一致でチェック
    expect(input.className).toMatch(/loading/);
  });
});
