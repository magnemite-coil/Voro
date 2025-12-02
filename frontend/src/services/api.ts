// services/api.ts
const API_BASE = '/api';

export class ApiError extends Error {
  errorId?: string;
  statusCode?: number;

  constructor(message: string, errorId?: string, statusCode?: number) {
    super(message);
    this.name = 'ApiError';
    this.errorId = errorId;
    this.statusCode = statusCode;
  }
}

interface RequestOptions {
  signal?: AbortSignal;
}

async function request<T>(
  endpoint: string,
  options: RequestInit & RequestOptions = {}
): Promise<T> {
  const { signal, ...fetchOptions } = options;

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...fetchOptions,
    headers: {
      'Content-Type': 'application/json',
      ...fetchOptions.headers,
    },
    credentials: 'include',
    signal,
  });

  const data = await response.json();

  if (!data.success) {
    throw new ApiError(data.error, data.error_id, response.status);
  }

  return data.data;
}

export const api = {
  get: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>(endpoint, { signal: options?.signal }),
  post: <T>(endpoint: string, body: unknown, options?: RequestOptions) =>
    request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(body),
      signal: options?.signal,
    }),
  put: <T>(endpoint: string, body: unknown, options?: RequestOptions) =>
    request<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(body),
      signal: options?.signal,
    }),
  delete: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>(endpoint, { method: 'DELETE', signal: options?.signal }),
};

/**
 * APIエラーをユーザー向けメッセージに変換
 * 500エラーの場合は error_id を含めて表示（問い合わせ用）
 */
export function formatErrorMessage(error: ApiError): string {
  if (error.statusCode === 500 && error.errorId) {
    return `サーバーエラーが発生しました (ID: ${error.errorId})`;
  }
  return error.message;
}
