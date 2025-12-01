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

export interface PostsResponse {
  posts: import('./post').Post[];
}

export interface PostResponse {
  post: import('./post').Post;
}
