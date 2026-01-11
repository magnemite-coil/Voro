// types/api.ts

// 成功レスポンスの基本型
export interface ApiSuccessResponse<T> {
  success: true;
  data: T;
}

// エラーレスポンスの型
export interface ApiErrorResponse {
  success: false;
  error: string;
  error_id?: string;
}

// APIレスポンスの共通型
export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;

// 認証関連の型
export interface User {
  id: number;
  username: string;
}

export interface LoginResponse {
  user: User;
}

// SignupResponse を独立した interface として追加
// 現時点では LoginResponse と同一構造だが、将来的に拡張可能
// （例: email 確認フラグ、ウェルカムメッセージ等の追加）
export interface SignupResponse {
  user: User;
}

export interface PostsResponse {
  posts: import('./post').Post[];
}

export interface PostResponse {
  post: import('./post').Post;
}

// ページネーション情報
export interface Pagination {
  page: number;
  per_page: number;
  total_count: number;
  total_pages: number;
}

// 投稿統計情報
export interface PostStats {
  total: number;
  published: number;
  draft: number;
  this_month: number;
}
