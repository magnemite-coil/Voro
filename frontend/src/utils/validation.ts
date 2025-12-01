// utils/validation.ts

// バリデーション定数（バックエンドと同期）
const TITLE_MAX_LENGTH = 200;
const CONTENT_MAX_LENGTH = 100000;

export interface ValidationResult {
  isValid: boolean;
  errors: {
    title?: string;
    content?: string;
  };
}

/**
 * タイトルのみをバリデーション（onBlur用）
 * @returns エラーメッセージ（エラーなしの場合は undefined）
 */
export function validateTitleOnly(title: string): string | undefined {
  const trimmed = title.trim();
  if (!trimmed) {
    return 'Title cannot be empty or whitespace only';
  }
  if (trimmed.length > TITLE_MAX_LENGTH) {
    return `Title must not exceed ${TITLE_MAX_LENGTH} characters`;
  }
  return undefined;
}

/**
 * 本文のみをバリデーション（onBlur用）
 * @returns エラーメッセージ（エラーなしの場合は undefined）
 */
export function validateContentOnly(content: string): string | undefined {
  const trimmed = content.trim();
  if (!trimmed) {
    return 'Content cannot be empty or whitespace only';
  }
  if (trimmed.length > CONTENT_MAX_LENGTH) {
    return `Content must not exceed ${CONTENT_MAX_LENGTH} characters`;
  }
  return undefined;
}

/**
 * タイトルと本文を一括バリデーション（送信時用）
 */
export function validatePost(title: string, content: string): ValidationResult {
  const errors: ValidationResult['errors'] = {};

  const titleError = validateTitleOnly(title);
  if (titleError) {
    errors.title = titleError;
  }

  const contentError = validateContentOnly(content);
  if (contentError) {
    errors.content = contentError;
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors,
  };
}
