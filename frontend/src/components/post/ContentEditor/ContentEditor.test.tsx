// components/post/ContentEditor/ContentEditor.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ContentEditor } from './ContentEditor';

describe('ContentEditor', () => {
  it('displays placeholder text', () => {
    render(<ContentEditor value="" onChange={() => {}} />);
    expect(
      screen.getByPlaceholderText('Markdownで本文を書く...')
    ).toBeInTheDocument();
  });

  it('displays the value', () => {
    render(<ContentEditor value="Test content" onChange={() => {}} />);
    expect(screen.getByDisplayValue('Test content')).toBeInTheDocument();
  });

  it('calls onChange when user types', async () => {
    const handleChange = vi.fn();
    render(<ContentEditor value="" onChange={handleChange} />);

    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    await userEvent.type(textarea, 'Hello');

    expect(handleChange).toHaveBeenCalledTimes(5); // H, e, l, l, o
  });

  it('displays error message when error prop is provided', () => {
    render(
      <ContentEditor
        value=""
        onChange={() => {}}
        error="Content cannot be empty or whitespace only"
      />
    );
    expect(
      screen.getByText('Content cannot be empty or whitespace only')
    ).toBeInTheDocument();
  });

  it('applies error class when error is present', () => {
    render(
      <ContentEditor value="" onChange={() => {}} error="Error message" />
    );
    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    // CSS Modules でクラス名がハッシュ化されるため、部分一致でチェック
    expect(textarea.className).toMatch(/hasError/);
  });

  it('calls onValidate when textarea loses focus', async () => {
    const handleValidate = vi.fn();
    render(
      <ContentEditor value="" onChange={() => {}} onValidate={handleValidate} />
    );

    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    await userEvent.click(textarea);
    await userEvent.tab(); // blur

    expect(handleValidate).toHaveBeenCalledTimes(1);
  });

  it('is readonly when isLoading is true', () => {
    render(<ContentEditor value="" onChange={() => {}} isLoading={true} />);
    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    expect(textarea).toHaveAttribute('readonly');
  });

  it('applies loading class when isLoading is true', () => {
    render(<ContentEditor value="" onChange={() => {}} isLoading={true} />);
    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    // CSS Modules でクラス名がハッシュ化されるため、部分一致でチェック
    expect(textarea.className).toMatch(/loading/);
  });

  it('has correct number of rows', () => {
    render(<ContentEditor value="" onChange={() => {}} />);
    const textarea = screen.getByPlaceholderText('Markdownで本文を書く...');
    expect(textarea).toHaveAttribute('rows', '20');
  });
});
