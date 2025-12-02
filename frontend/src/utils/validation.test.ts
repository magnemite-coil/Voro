// utils/validation.test.ts
import { describe, it, expect } from 'vitest';
import { validatePost, validateTitleOnly, validateContentOnly } from './validation';

describe('validateTitleOnly', () => {
  it('returns error when title is empty', () => {
    expect(validateTitleOnly('')).toBe('Title cannot be empty or whitespace only');
  });

  it('returns error when title is whitespace only', () => {
    expect(validateTitleOnly('   ')).toBe('Title cannot be empty or whitespace only');
  });

  it('returns error when title exceeds 200 characters', () => {
    const longTitle = 'a'.repeat(201);
    expect(validateTitleOnly(longTitle)).toBe('Title must not exceed 200 characters');
  });

  it('returns undefined for valid title', () => {
    expect(validateTitleOnly('Valid Title')).toBeUndefined();
  });

  it('returns undefined for title at 200 characters', () => {
    const maxTitle = 'a'.repeat(200);
    expect(validateTitleOnly(maxTitle)).toBeUndefined();
  });
});

describe('validateContentOnly', () => {
  it('returns error when content is empty', () => {
    expect(validateContentOnly('')).toBe('Content cannot be empty or whitespace only');
  });

  it('returns error when content is whitespace only', () => {
    expect(validateContentOnly('   ')).toBe('Content cannot be empty or whitespace only');
  });

  it('returns error when content exceeds 100000 characters', () => {
    const longContent = 'a'.repeat(100001);
    expect(validateContentOnly(longContent)).toBe(
      'Content must not exceed 100000 characters'
    );
  });

  it('returns undefined for valid content', () => {
    expect(validateContentOnly('Valid content')).toBeUndefined();
  });
});

describe('validatePost', () => {
  it('returns isValid false when title is empty', () => {
    const result = validatePost('', 'content');
    expect(result.isValid).toBe(false);
    expect(result.errors.title).toBe('Title cannot be empty or whitespace only');
  });

  it('returns isValid false when content is empty', () => {
    const result = validatePost('title', '');
    expect(result.isValid).toBe(false);
    expect(result.errors.content).toBe('Content cannot be empty or whitespace only');
  });

  it('returns isValid false when both are invalid', () => {
    const result = validatePost('', '');
    expect(result.isValid).toBe(false);
    expect(result.errors.title).toBe('Title cannot be empty or whitespace only');
    expect(result.errors.content).toBe('Content cannot be empty or whitespace only');
  });

  it('returns isValid true when both fields are valid', () => {
    const result = validatePost('Valid Title', 'Valid content');
    expect(result.isValid).toBe(true);
    expect(result.errors).toEqual({});
  });
});
