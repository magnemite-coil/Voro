// types/post.ts

// APIレスポンスの型（snake_case）
export interface Post {
  id: number;
  user_id: number;
  title: string;
  content: string;
  published: boolean;
  created_at: string;
  updated_at: string;
}

// リクエストボディの型（snake_case）
export interface CreatePostData {
  title: string;
  content: string;
  published: boolean;
}

export interface UpdatePostData {
  title?: string;
  content?: string;
  published?: boolean;
}

// 一覧取得レスポンス（ページネーション付き）
export interface PostListResponse {
  posts: Post[];
  pagination: import('./api').Pagination;
}

// 統計取得レスポンス
export interface PostStatsResponse {
  stats: import('./api').PostStats;
}
